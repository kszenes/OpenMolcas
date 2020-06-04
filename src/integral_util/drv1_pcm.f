************************************************************************
* This file is part of OpenMolcas.                                     *
*                                                                      *
* OpenMolcas is free software; you can redistribute it and/or modify   *
* it under the terms of the GNU Lesser General Public License, v. 2.1. *
* OpenMolcas is distributed in the hope that it will be useful, but it *
* is provided "as is" and without any express or implied warranties.   *
* For more details see the full text of the license in the file        *
* LICENSE or in <http://www.gnu.org/licenses/>.                        *
*                                                                      *
* Copyright (C) 1990-1992,1999, Roland Lindh                           *
*               1990, IBM                                              *
************************************************************************
      SubRoutine Drv1_PCM(FactOp,nTs,FD,nFD,CCoor,lOper,VTessera,nOrdOp)
************************************************************************
*                                                                      *
* Object: to compute the local multipole moment, desymmetrize the 1st  *
*         order density matrix and accumulate contributions to the     *
*         global multipole expansion.                                  *
*                                                                      *
* Called from: RctFld                                                  *
*                                                                      *
* Calling    : QEnter                                                  *
*              ZXia                                                    *
*              SetUp1                                                  *
*              MltInt                                                  *
*              DGeMV    (ESSL)                                         *
*              RecPrt                                                  *
*              DCopy    (ESSL)                                         *
*              DGEMM_   (ESSL)                                         *
*              CarSph                                                  *
*              DGeTMO   (ESSL)                                         *
*              DaXpY    (ESSL)                                         *
*              SOGthr                                                  *
*              DesymD                                                  *
*              DScal    (ESSL)                                         *
*              TriPrt                                                  *
*              QExit                                                   *
*                                                                      *
*     Author: Roland Lindh, IBM Almaden Research Center, San Jose, CA  *
*             January '90                                              *
*             Modified for Hermite-Gauss quadrature November '90       *
*             Modified for Rys quadrature November '90                 *
*             Modified for multipole moments November '90              *
*                                                                      *
*             Roland Lindh, Dept. of Theoretical Chemistry, University *
*             of Lund, SWEDEN.                                         *
*             Modified for general kernel routines January  91         *
*             Modified for nonsymmetrical operators February  91       *
*             Modified for gradients October  91                       *
*             Modified for reaction field calculations July  92        *
*             Modified loop structure  99                              *
************************************************************************
      use Real_Spherical
      use iSD_data
      Implicit Real*8 (A-H,O-Z)
#include "angtp.fh"
#include "info.fh"
#include "real.fh"
#include "WrkSpc.fh"
#include "stdalloc.fh"
#include "lundio.fh"
#include "print.fh"
#include "nsd.fh"
#include "setup.fh"
      Real*8 A(3), B(3), C(3), FD(nFD), FactOp(nTs), CCoor(4,nTs),
     &       RB(3), TRB(3), TA(3),
     &       VTessera((nOrdOp+1)*(nOrdOp+2)/2,2,nTs)
      Character ChOper(0:7)*3
      Integer   lOper(nTs), iStabO(0:7),
     &          iDCRR(0:7), iDCRT(0:7), iStabM(0:7), nOp(3)
      Logical AeqB
      Real*8, Allocatable:: Zeta(:), ZI(:), Kappa(:), PCoor(:,:)
      Data ChOper/'E  ','x  ','y  ','xy ','z  ','xz ','yz ','xyz'/
*
*     Statement functions
      nElem(ixyz) = (ixyz+1)*(ixyz+2)/2
*
      iRout = 112
      iPrint = nPrint(iRout)
      Call qEnter('Drv1_PCM')
*
      iIrrep = 0
*
*     Auxiliary memory allocation.
*
      Call mma_allocate(Zeta,m2Max,Label='Zeta')
      Call mma_allocate(ZI,m2Max,Label='ZI')
      Call mma_allocate(Kappa,m2Max,Label='Kappa')
      Call mma_allocate(PCoor,m2Max,3,Label='PCoor')
*                                                                      *
************************************************************************
*                                                                      *
      Call Nr_Shells(nSkal)
*                                                                      *
************************************************************************
*                                                                      *
*-----Double loop over shells. These loops decide the integral type
*


      Do iS = 1, nSkal
         iShll  = iSD( 0,iS)
         If (AuxShell(iShll)) Go To 100
         iAng   = iSD( 1,iS)
         iCmp   = iSD( 2,iS)
         iBas   = iSD( 3,iS)
         iCff   = iSD( 4,iS)
         iPrim  = iSD( 5,iS)
         iExp   = iSD( 6,iS)
         iAO    = iSD( 7,iS)
         ixyz   = iSD( 8,iS)
         mdci   = iSD(10,iS)
         iShell = iSD(11,iS)
         call dcopy_(3,Work(ixyz),1,A,1)
         Do jS = 1, iS
            jShll  = iSD( 0,jS)
            jAng   = iSD( 1,jS)
            jCmp   = iSD( 2,jS)
            jBas   = iSD( 3,jS)
            jCff   = iSD( 4,jS)
            jPrim  = iSD( 5,jS)
            jExp   = iSD( 6,jS)
            jAO    = iSD( 7,jS)
            jxyz   = iSD( 8,jS)
            mdcj   = iSD(10,jS)
            jShell = iSD(11,jS)
            call dcopy_(3,Work(jxyz),1,B,1)
*
            iSmLbl = 1
            nSO = MemSO1(iSmLbl,iCmp,jCmp,iShell,jShell)
            If (nSO.eq.0) Go To 131
            If (iPrint.ge.19) Write (6,'(A,A,A,A,A)')
     &        ' ***** (',AngTp(iAng),',',AngTp(jAng),') *****'
*
*           Call kernel routine to get memory requirement.
*
            Call EFMmP(nOrder,MemKer,iAng,jAng,nOrdOp)
*           Write (*,*)nOrder,MemKer,iAng,jAng,nOrdOp
            MemKrn=MemKer*m2Max
            Call GetMem('Kernel','ALLO','REAL',iKern,MemKrn)
*
*           Allocate memory for the final integrals, all in the
*           primitive basis.
*
            nComp = (nOrdOp+1)*(nOrdOp+2)/2
            lFinal = MaxPrm(iAng) * MaxPrm(jAng)
     &             * nElem(iAng)*nElem(jAng)
     &             * nComp
            Call GetMem('Final','ALLO','REAL',ipFnl,lFinal)
*
*           Scratch area for contraction step
*
            nScr1 =  MaxPrm(iAng)*MaxPrm(jAng) *
     &               nElem(iAng)*nElem(jAng)
            Call GetMem('Scrtch','ALLO','REAL',iScrt1,nScr1)
*
*           Scratch area for the transformation to spherical gaussians
*
            nScr2=MaxPrm(iAng)*MaxPrm(jAng)*nElem(iAng)*nElem(jAng)
            Call GetMem('ScrSph','Allo','Real',iScrt2,nScr2)
*
            nDAO =iPrim*jPrim*nElem(iAng)*nElem(jAng)
            Call GetMem(' DAO ','Allo','Real',ipDAO,nDAO)
*
*           At this point we can compute Zeta.
*
            Call ZXia(Zeta,ZI,iPrim,jPrim,Work(iExp),Work(jExp))
*
            AeqB = iS.eq.jS
*
*           Find the DCR for A and B
*
            Call DCR(LmbdR,iOper,nIrrep,jStab(0,mdci),
     &               nStab(mdci),jStab(0,mdcj),
     &               nStab(mdcj),iDCRR,nDCRR)
            If (iPrint.ge.49) Write (6,'(10A)')
     &         ' {R}=(',(ChOper(iDCRR(i)),i=0,nDCRR-1),')'
*
*-----------Find the stabilizer for A and B
*
            Call Inter(jStab(0,mdci),nStab(mdci),
     &                 jStab(0,mdcj),nStab(mdcj),
     &                 iStabM,nStabM)
*
*           Allocate memory for the elements of the Fock or 1st order
*           denisty matrix which are associated with the current shell
*           pair.
*
            Call GetMem('DSOpr ','ALLO','REAL',ipDSOp,nSO*iPrim*jPrim)
            Call GetMem('DSO ','ALLO','REAL',ipDSO,nSO*iPrim*jPrim)
*
*           Gather the elements from 1st order density / Fock matrix.
*
            Call SOGthr(Work(ipDSO),iBas,jBas,nSO,FD,
     &                  n2Tri(iSmLbl),iSmLbl,
     &                  iCmp,jCmp,iShell,jShell,AeqB,iAO,jAO)
*
*           Project the Fock/1st order density matrix in AO
*           basis on to the primitive basis.
*
            If (iPrint.ge.99) Then
               Call RecPrt(' Left side contraction',' ',
     &                     Work(iCff),iPrim,iBas)
               Call RecPrt(' Right side contraction',' ',
     &                     Work(jCff),jPrim,jBas)
            End If
*
*           Transform IJ,AB to J,ABi
            Call DGEMM_('T','T',
     &                  jBas*nSO,iPrim,iBas,
     &                  1.0d0,Work(ipDSO),iBas,
     &                  Work(iCff),iPrim,
     &                  0.0d0,Work(ipDSOp),jBas*nSO)
*           Transform J,ABi to AB,ij
            Call DGEMM_('T','T',
     &                  nSO*iPrim,jPrim,jBas,
     &                  1.0d0,Work(ipDSOp),jBas,
     &                  Work(jCff),jPrim,
     &                  0.0d0,Work(ipDSO),nSO*iPrim)
*           Transpose to ij,AB
            Call DGeTmO(Work(ipDSO),nSO,nSO,iPrim*jPrim,Work(ipDSOp),
     &                  iPrim*jPrim)
            Call GetMem('DSO ','Free','Real',ipDSO,nSO*iBas*jBas)
*
            If (iPrint.ge.99) Call
     &         RecPrt(' Decontracted 1st order density/Fock matrix',
     &                ' ',Work(ipDSOp),iPrim*jPrim,nSO)
*
*           Loops over symmetry operations.
*
            Do lDCRR = 0, nDCRR-1
               RB(1)  = DBLE(iPhase(1,iDCRR(lDCRR)))*B(1)
               RB(2)  = DBLE(iPhase(2,iDCRR(lDCRR)))*B(2)
               RB(3)  = DBLE(iPhase(3,iDCRR(lDCRR)))*B(3)
*
*--------------Loop over operators
*
               Do 5000 iTile = 1, nTs
                  If (FactOp(iTile).eq.Zero) Go To 5000
                  call dcopy_(3,Ccoor(1,iTile),1,C,1)
*
*-----------------Generate stabilizer of the operator.
*
                  Call SOS(iStabO,nStabO,lOper(iTile))
*
*-----------------Find the DCR for M and S
*
                  Call DCR(LmbdT,iOper,nIrrep,iStabM,nStabM,
     &                     iStabO,nStabO,iDCRT,nDCRT)
                  If (iPrint.ge.49) Then
                     Write (6,'(10A)') ' {M}=(',(ChOper(iStabM(i)),
     &                     i=0,nStabM-1),')'
                     Write (6,'(10A)') ' {O}=(',(ChOper(iStabO(i)),
     &                     i=0,nStabO-1),')'
                     Write (6,'(10A)') ' {T}=(',(ChOper(iDCRT(i)),
     &                     i=0,nDCRT-1),')'
                  End If
*
*-----------------Compute normalization factor due the DCR symmetrization
*                 of the two basis functions and the operator.
*
                  iuv = nStab(mdci)*nStab(mdcj)
                  FactNd = DBLE(iuv*nStabO) / DBLE(nIrrep**2*LmbdT)
                  If (MolWgh.eq.1) Then
                     FactNd = FactNd * DBLE(nIrrep)**2 / DBLE(iuv)
                  Else If (MolWgh.eq.2) Then
                     FactNd = Sqrt(DBLE(iuv))*DBLE(nStabO) /
     &                        DBLE(nIrrep*LmbdT)
                  End If
                  FactNd = FactNd * FactOp(iTile)
*
                  Do lDCRT = 0, nDCRT-1
                     nOp(1) = NrOpr(iDCRT(lDCRT),iOper,nIrrep)
                     nOp(2) = NrOpr(iEor(iDCRT(lDCRT),
     &                             iDCRR(lDCRR)),iOper,nIrrep)
                     nOp(3) = NrOpr(0,iOper,nIrrep)

                     TA(1) =  DBLE(iPhase(1,iDCRT(lDCRT)))*A(1)
                     TA(2) =  DBLE(iPhase(2,iDCRT(lDCRT)))*A(2)
                     TA(3) =  DBLE(iPhase(3,iDCRT(lDCRT)))*A(3)
                     TRB(1) = DBLE(iPhase(1,iDCRT(lDCRT)))*RB(1)
                     TRB(2) = DBLE(iPhase(2,iDCRT(lDCRT)))*RB(2)
                     TRB(3) = DBLE(iPhase(3,iDCRT(lDCRT)))*RB(3)
                     If (iPrint.ge.49) Then
                        Write (6,'(A,/,3(3F6.2,2X))')
     &                  ' *** Centers A, B, C ***',
     &                  ( TA(i),i=1,3),
     &                  (TRB(i),i=1,3),
     &                  (C(i),i=1,3)
                        Write (6,*) ' nOp=',nOp
                     End If
*
*--------------------Desymmetrize the matrix with which we will
*                    contracte the trace.
*
                     Call DesymD(iSmLbl,iAng,jAng,iCmp,jCmp,
     &                           iShell,jShell,iShll,jShll,
     &                           Work(ipDAO),iPrim,jPrim,
     &                           Work(ipDSOp),nSO,nOp,FactNd)
*
*--------------------Project the spherical harmonic space onto the
*                    cartesian space.
*
                     kk = nElem(iAng)*nElem(jAng)
                     If (Transf(iShll).or.Transf(jShll)) Then
*
*-----------------------ij,AB --> AB,ij
                        Call DGeTmO(Work(ipDAO),iPrim*jPrim,iPrim*jPrim,
     &                              iCmp*jCmp,Work(iScrt1),iCmp*jCmp)
*-----------------------AB,ij --> ij,ab
                        Call SphCar(Work(iScrt1),iCmp*jCmp,iPrim*jPrim,
     &                              Work(iScrt2),nScr2,
     &                              RSph(ipSph(iAng)),
     &                              iAng,Transf(iShll),Prjct(iShll),
     &                              RSph(ipSph(jAng)),
     &                              jAng,Transf(jShll),Prjct(jShll),
     &                              Work(ipDAO),kk)
                     End If
                     If (iPrint.ge.99) Call RecPrt(
     &                        ' Decontracted FD in the cartesian space',
     &                        ' ',Work(ipDAO),iPrim*jPrim,kk)
*
*--------------------Compute kappa and P.
*
                     Call Setup1(Work(iExp),iPrim,Work(jExp),jPrim,
     &                           TA,TRB,Kappa,PCoor,ZI)
*
*
*--------------------Compute the potential at a tessera.
*
                     Call EFPrm(Work(iExp),iPrim,Work(jExp),jPrim,
     &                          Zeta,ZI,Kappa,Pcoor,
     &                          Work(ipFnl),iPrim*jPrim,nComp,
     &                          iAng,jAng,TA,TRB,nOrder,Work(iKern),
     &                          MemKer,C,nOrdOp)
                     If (iPrint.ge.49) Call RecPrt(' Final Integrals',
     &                                 ' ',Work(ipFnl),nDAO,nComp)
*
*--------------------Trace with 1st order density matrix and accumulate
*                    to the potenital at tessera iTile
*
                     If (iPrint.ge.49) Call RecPrt(
     &                        ' Decontracted FD in the cartesian space',
     &                        ' ',Work(ipDAO),nDAO,1)
                     ipFnlc=ipFnl
                     Do iComp = 1, nComp
                        If (iPrint.ge.49)
     &                     Call RecPrt('VTessera(iComp,2,iTile)',' ',
     &                                  VTessera(iComp,2,iTile),1,1)

                        VTessera(iComp,2,iTile)=
     &                      VTessera(iComp,2,iTile) +
     &                      DDot_(nDAO,Work(ipDAO),1,Work(ipFnlc),1)
                        If (iPrint.ge.49)
     &                     Call RecPrt('VTessera(iComp,2,iTile)',' ',
     &                                  VTessera(iComp,2,iTile),1,1)
                        ipFnlc=ipFnlc+nDAO
                     End Do
*
                  End Do
 5000          Continue
            End Do
*
            Call GetMem('DSOpr ','Free','REAL',ipDSOp,nSO*iPrim*jPrim)
            Call GetMem(' DAO ','Free','Real',ipDAO,iPrim*jPrim*
     &                  nElem(iAng)*nElem(jAng))
            Call GetMem('ScrSph','Free','Real',iScrt2,nScr2)
            Call GetMem('Scrtch','Free','Real',iScrt1,nScr1)
            Call GetMem('Final','Free','Real',ipFnl,lFinal)
            Call GetMem('Kernel','Free','Real',iKern,MemKrn)
 131        Continue
         End Do
      End Do
 100  Continue
*
      Call mma_deallocate(PCoor)
      Call mma_deallocate(Kappa)
      Call mma_deallocate(ZI)
      Call mma_deallocate(Zeta)
*
      Call qExit('Drv1_PCM')
      Return
      End
