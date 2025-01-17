!***********************************************************************
! This file is part of OpenMolcas.                                     *
!                                                                      *
! OpenMolcas is free software; you can redistribute it and/or modify   *
! it under the terms of the GNU Lesser General Public License, v. 2.1. *
! OpenMolcas is distributed in the hope that it will be useful, but it *
! is provided "as is" and without any express or implied warranties.   *
! For more details see the full text of the license in the file        *
! LICENSE or in <http://www.gnu.org/licenses/>.                        *
!                                                                      *
! Copyright (C) 1990-1992,1999, Roland Lindh                           *
!               1990, IBM                                              *
!***********************************************************************
!#define _DEBUGPRINT_
      SubRoutine Drv1_PCM(FactOp,nTs,FD,nFD,CCoor,lOper,VTessera,nOrdOp)
!***********************************************************************
!                                                                      *
! Object: to compute the local multipole moment, desymmetrize the 1st  *
!         order density matrix and accumulate contributions to the     *
!         global multipole expansion.                                  *
!                                                                      *
!     Author: Roland Lindh, IBM Almaden Research Center, San Jose, CA  *
!             January '90                                              *
!             Modified for Hermite-Gauss quadrature November '90       *
!             Modified for Rys quadrature November '90                 *
!             Modified for multipole moments November '90              *
!                                                                      *
!             Roland Lindh, Dept. of Theoretical Chemistry, University *
!             of Lund, SWEDEN.                                         *
!             Modified for general kernel routines January  91         *
!             Modified for nonsymmetrical operators February  91       *
!             Modified for gradients October  91                       *
!             Modified for reaction field calculations July  92        *
!             Modified loop structure  99                              *
!***********************************************************************
      use Real_Spherical, only: ipSph, rSph
      use iSD_data, only: iSD
      use Basis_Info, only: Shells, DBSC, MolWgh
      use Center_Info, only: DC
      use Sizes_of_Seward, only: S
      use Symmetry_Info, only: nIrrep
      use Constants, only: Zero
      use stdalloc, only: mma_allocate, mma_deallocate
#ifdef _DEBUGPRINT_
      use define_af, only: Angtp
      use Symmetry_Info, only: ChOper
#endif
      Implicit None
      Integer nTs, nFD, nOrdOp
      Real*8 A(3), B(3), C(3), FD(nFD), FactOp(nTs), CCoor(4,nTs),
     &       RB(3), TRB(3), TA(3),
     &       VTessera((nOrdOp+1)*(nOrdOp+2)/2,2,nTs)
      Integer   lOper(nTs), iStabO(0:7),
     &          iDCRR(0:7), iDCRT(0:7), iStabM(0:7), nOp(3)

      Logical AeqB
      Integer ixyz, nElem, nSkal,
     &        iS, jS, iShll, jShll,
     &        iCmp, jCmp, iAng, jAng,
     &        iBas, jBas, iAO, jAO,
     &        iPrim, jPrim, iCnt, jCnt,
     &        iShell, jShell,
     &        iCnttp, jCnttp, mdci, mdcj,
     &        iSmLbl, nSO, MemKrn, MemKer, nComp, lFinal, nScr1, nScr2,
     &        nDAO, lDCRR, nDCRR, iTile, iuv, nStabO, LmbdT, LmbdR,
     &        lDCRT, nDCRT, kk, ipFnlC, iComp, nOrder,
     &        NrOpr, nStabM
      Integer, External :: n2Tri, MemSO1
      Real*8  FactND
      Real*8, External:: DDot_
      Real*8, Allocatable:: Zeta(:), ZI(:), Kappa(:), PCoor(:,:)
      Real*8, Allocatable:: Kern(:), Fnl(:), Scr1(:), Scr2(:),
     &                      DAO(:), DSOpr(:), DSO(:)
#ifdef _DEBUGPRINT_
      Integer i
#endif
!
!     Statement functions
      nElem(ixyz) = (ixyz+1)*(ixyz+2)/2
!
!     Auxiliary memory allocation.
!
      Call mma_allocate(Zeta,S%m2Max,Label='Zeta')
      Call mma_allocate(ZI,S%m2Max,Label='ZI')
      Call mma_allocate(Kappa,S%m2Max,Label='Kappa')
      Call mma_allocate(PCoor,S%m2Max,3,Label='PCoor')
!                                                                      *
!***********************************************************************
!                                                                      *
      Call Nr_Shells(nSkal)
!                                                                      *
!***********************************************************************
!                                                                      *
!-----Double loop over shells. These loops decide the integral type
!


      Do iS = 1, nSkal
         iShll  = iSD( 0,iS)
         If (Shells(iShll)%Aux) Go To 100
         iAng   = iSD( 1,iS)
         iCmp   = iSD( 2,iS)
         iBas   = iSD( 3,iS)
         iPrim  = iSD( 5,iS)
         iAO    = iSD( 7,iS)
         mdci   = iSD(10,iS)
         iShell = iSD(11,iS)
         iCnttp = iSD(13,iS)
         iCnt   = iSD(14,iS)
         A(1:3)=dbsc(iCnttp)%Coor(1:3,iCnt)
         Do jS = 1, iS
            jShll  = iSD( 0,jS)
            jAng   = iSD( 1,jS)
            jCmp   = iSD( 2,jS)
            jBas   = iSD( 3,jS)
            jPrim  = iSD( 5,jS)
            jAO    = iSD( 7,jS)
            mdcj   = iSD(10,jS)
            jShell = iSD(11,jS)
            jCnttp = iSD(13,jS)
            jCnt   = iSD(14,jS)
            B(1:3)=dbsc(jCnttp)%Coor(1:3,jCnt)
!
            iSmLbl = 1
            nSO = MemSO1(iSmLbl,iCmp,jCmp,iShell,jShell,iAO,jAO)
            If (nSO.eq.0) Go To 131
#ifdef _DEBUGPRINT_
            Write (6,'(A,A,A,A,A)')
     &        ' ***** (',AngTp(iAng),',',AngTp(jAng),') *****'
#endif
!
!           Call kernel routine to get memory requirement.
!
            Call EFMmP(nOrder,MemKer,iAng,jAng,nOrdOp)
!           Write (*,*)nOrder,MemKer,iAng,jAng,nOrdOp
            MemKrn=MemKer*S%m2Max
            Call mma_allocate(Kern,MemKrn,Label='Kern')
!
!           Allocate memory for the final integrals, all in the
!           primitive basis.
!
            nComp = (nOrdOp+1)*(nOrdOp+2)/2
            lFinal = S%MaxPrm(iAng) * S%MaxPrm(jAng)
     &             * nElem(iAng)*nElem(jAng)
     &             * nComp
            Call mma_allocate(Fnl,lFinal,Label='Fnl')
!
!           Scratch area for contraction step
!
            nScr1 =  S%MaxPrm(iAng)*S%MaxPrm(jAng) *
     &               nElem(iAng)*nElem(jAng)
            Call mma_allocate(Scr1,nScr1,Label='Scr1')
!
!           Scratch area for the transformation to spherical gaussians
!
            nScr2=S%MaxPrm(iAng)*S%MaxPrm(jAng)*nElem(iAng)*nElem(jAng)
            Call mma_allocate(Scr2,nScr2,Label='Scr2')
!
            nDAO =iPrim*jPrim*nElem(iAng)*nElem(jAng)
            Call mma_allocate(DAO,nDAO,Label='DAO')
!
!           At this point we can compute Zeta.
!
            Call ZXia(Zeta,ZI,iPrim,jPrim,Shells(iShll)%Exp,
     &                                    Shells(jShll)%Exp)
!
            AeqB = iS.eq.jS
!
!           Find the DCR for A and B
!
            Call DCR(LmbdR,dc(mdci)%iStab,dc(mdci)%nStab,
     &                     dc(mdcj)%iStab,dc(mdcj)%nStab,iDCRR,nDCRR)
#ifdef _DEBUGPRINT_
            Write (6,'(10A)')
     &         ' {R}=(',(ChOper(iDCRR(i)),i=0,nDCRR-1),')'
#endif
!
!-----------Find the stabilizer for A and B
!
            Call Inter(dc(mdci)%iStab,dc(mdci)%nStab,
     &                 dc(mdcj)%iStab,dc(mdcj)%nStab,
     &                 iStabM,nStabM)
!
!           Allocate memory for the elements of the Fock or 1st order
!           denisty matrix which are associated with the current shell
!           pair.
!
            Call mma_allocate(DSOpr,nSO*iPrim*jPrim,Label='DSOpr')
            Call mma_allocate(DSO,nSO*iPrim*jPrim,Label='DSO')
!
!           Gather the elements from 1st order density / Fock matrix.
!
            Call SOGthr(DSO,iBas,jBas,nSO,FD,
     &                  n2Tri(iSmLbl),iSmLbl,
     &                  iCmp,jCmp,iShell,jShell,
     &                  AeqB,iAO,jAO)
!
!           Project the Fock/1st order density matrix in AO
!           basis on to the primitive basis.
!
#ifdef _DEBUGPRINT_
            Call RecPrt(' Left side contraction',' ',
     &                  Shells(iShll)%pCff,iPrim,iBas)
            Call RecPrt(' Right side contraction',' ',
     &                  Shells(jShll)%pCff,jPrim,jBas)
#endif
!
!           Transform IJ,AB to J,ABi
            Call DGEMM_('T','T',
     &                  jBas*nSO,iPrim,iBas,
     &                  1.0d0,DSO,iBas,
     &                        Shells(iShll)%pCff,iPrim,
     &                  0.0d0,DSOpr,jBas*nSO)
!           Transform J,ABi to AB,ij
            Call DGEMM_('T','T',
     &                  nSO*iPrim,jPrim,jBas,
     &                  1.0d0,DSOpr,jBas,
     &                        Shells(jShll)%pCff,jPrim,
     &                  0.0d0,DSO,nSO*iPrim)
!           Transpose to ij,AB
            Call DGeTmO(DSO,nSO,nSO,iPrim*jPrim,DSOpr,
     &                  iPrim*jPrim)
            Call mma_deallocate(DSO)
!
#ifdef _DEBUGPRINT_
            Call RecPrt(' Decontracted 1st order density/Fock matrix',
     &                ' ',DSOpr,iPrim*jPrim,nSO)
#endif
!
!           Loops over symmetry operations.
!
            Do lDCRR = 0, nDCRR-1
               Call OA(iDCRR(lDCRR),B,RB)
!
!--------------Loop over operators
!
               Do 5000 iTile = 1, nTs
                  If (FactOp(iTile).eq.Zero) Go To 5000
                  call dcopy_(3,Ccoor(1,iTile),1,C,1)
!
!-----------------Generate stabilizer of the operator.
!
                  Call SOS(iStabO,nStabO,lOper(iTile))
!
!-----------------Find the DCR for M and S
!
                  Call DCR(LmbdT,iStabM,nStabM,iStabO,nStabO,
     &                     iDCRT,nDCRT)
#ifdef _DEBUGPRINT_
                  Write (6,'(10A)') ' {M}=(',(ChOper(iStabM(i)),
     &                  i=0,nStabM-1),')'
                  Write (6,'(10A)') ' {O}=(',(ChOper(iStabO(i)),
     &                  i=0,nStabO-1),')'
                  Write (6,'(10A)') ' {T}=(',(ChOper(iDCRT(i)),
     &                  i=0,nDCRT-1),')'
#endif
!
!-----------------Compute normalization factor due the DCR symmetrization
!                 of the two basis functions and the operator.
!
                  iuv = dc(mdci)%nStab*dc(mdcj)%nStab
                  FactNd = DBLE(iuv*nStabO) / DBLE(nIrrep**2*LmbdT)
                  If (MolWgh.eq.1) Then
                     FactNd = FactNd * DBLE(nIrrep)**2 / DBLE(iuv)
                  Else If (MolWgh.eq.2) Then
                     FactNd = Sqrt(DBLE(iuv))*DBLE(nStabO) /
     &                        DBLE(nIrrep*LmbdT)
                  End If
                  FactNd = FactNd * FactOp(iTile)
!
                  Do lDCRT = 0, nDCRT-1
                     nOp(1) = NrOpr(iDCRT(lDCRT))
                     nOp(2) = NrOpr(iEor(iDCRT(lDCRT),iDCRR(lDCRR)))
                     nOp(3) = NrOpr(0)

                     Call OA(iDCRT(lDCRT),A,TA)
                     Call OA(iDCRT(lDCRT),RB,TRB)
#ifdef _DEBUGPRINT_
                     Write (6,'(A,/,3(3F6.2,2X))')
     &               ' *** Centers A, B, C ***',
     &               ( TA(i),i=1,3),
     &               (TRB(i),i=1,3),
     &               (C(i),i=1,3)
                     Write (6,*) ' nOp=',nOp
#endif
!
!--------------------Desymmetrize the matrix with which we will
!                    contracte the trace.
!
                     Call DesymD(iSmLbl,iAng,jAng,iCmp,jCmp,
     &                           iShell,jShell,iShll,jShll,
     &                           iAO,jAO,DAO,iPrim,jPrim,
     &                           DSOpr,nSO,nOp,FactNd)
!
!--------------------Project the spherical harmonic space onto the
!                    cartesian space.
!
                     kk = nElem(iAng)*nElem(jAng)
                     If (Shells(iShll)%Transf.or.
     &                   Shells(jShll)%Transf) Then
!
!-----------------------ij,AB --> AB,ij
                        Call DGeTmO(DAO,iPrim*jPrim,iPrim*jPrim,
     &                              iCmp*jCmp,Scr1,iCmp*jCmp)
!-----------------------AB,ij --> ij,ab
                        Call SphCar(Scr1,iCmp*jCmp,iPrim*jPrim,
     &                              Scr2,nScr2,
     &                              RSph(ipSph(iAng)),
     &                              iAng,Shells(iShll)%Transf,
     &                                   Shells(iShll)%Prjct,
     &                              RSph(ipSph(jAng)),
     &                              jAng,Shells(jShll)%Transf,
     &                                   Shells(jShll)%Prjct,
     &                              DAO,kk)
                     End If
#ifdef _DEBUGPRINT_
                     Call RecPrt(
     &                     ' Decontracted FD in the cartesian space',
     &                     ' ',DAO,iPrim*jPrim,kk)
#endif
!
!--------------------Compute kappa and P.
!
                     Call Setup1(Shells(iShll)%Exp,iPrim,
     &                           Shells(jShll)%Exp,jPrim,
     &                           TA,TRB,Kappa,PCoor,ZI)
!
!
!--------------------Compute the potential at a tessera.
!
                     Call EFPrm(Shells(iShll)%Exp,iPrim,
     &                          Shells(jShll)%Exp,jPrim,
     &                          Zeta,ZI,Kappa,Pcoor,
     &                          Fnl,iPrim*jPrim,nComp,
     &                          iAng,jAng,TA,TRB,nOrder,Kern,
     &                          MemKer,C,nOrdOp)
#ifdef _DEBUGPRINT_
                     Call RecPrt(' Final Integrals',
     &                                 ' ',Fnl,nDAO,nComp)
#endif
!
!--------------------Trace with 1st order density matrix and accumulate
!                    to the potenital at tessera iTile
!
#ifdef _DEBUGPRINT_
                     Call RecPrt(
     &                        ' Decontracted FD in the cartesian space',
     &                        ' ',DAO,nDAO,1)
#endif
                     ipFnlc=1
                     Do iComp = 1, nComp
#ifdef _DEBUGPRINT_
                        Call RecPrt('VTessera(iComp,2,iTile)',' ',
     &                                  VTessera(iComp,2,iTile),1,1)
#endif

                        VTessera(iComp,2,iTile)=
     &                      VTessera(iComp,2,iTile) +
     &                      DDot_(nDAO,DAO,1,Fnl(ipFnlc),1)
#ifdef _DEBUGPRINT_
                        Call RecPrt('VTessera(iComp,2,iTile)',' ',
     &                               VTessera(iComp,2,iTile),1,1)
#endif
                        ipFnlc=ipFnlc+nDAO
                     End Do
!
                  End Do
 5000          Continue
            End Do
!
            Call mma_deallocate(DSOpr)
            Call mma_deallocate(DAO)
            Call mma_deallocate(Scr2)
            Call mma_deallocate(Scr1)
            Call mma_deallocate(Fnl)
            Call mma_deallocate(Kern)
 131        Continue
         End Do
      End Do
 100  Continue
!
      Call mma_deallocate(PCoor)
      Call mma_deallocate(Kappa)
      Call mma_deallocate(ZI)
      Call mma_deallocate(Zeta)
!
      Return
      End SubRoutine Drv1_PCM
