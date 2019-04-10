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
* Copyright (C) 1991, Roland Lindh                                     *
*               2003, Hans-Joachim Werner                              *
************************************************************************
      SubRoutine Drv1_Pot(FD,CCoor,pot,ngrid,ncmp,nordop)
************************************************************************
*                                                                      *
* Object: to compute the potential on a grid using density FD (triang) *
*         Grid provided in CCoor(3,ngrid)                              *
*         Potential values returned in pot                             *
*                                                                      *
* Called from: Drvpot                                                  *
*                                                                      *
* Calling    : QEnter                                                  *
*              GetMem                                                  *
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
* Generated by modification of drv_rf.f, naint.f, sogthr.f             *
* H.-J. Werner, Jan 2003                                               *
************************************************************************
      use Real_Spherical
      use iSD_data
      Implicit Real*8 (A-H,O-Z)
#include "itmax.fh"
#include "info.fh"
#include "real.fh"
#include "WrkSpc.fh"
#include "lundio.fh"
#include "print.fh"
#include "nsd.fh"
#include "setup.fh"
      Real*8 A(3), B(3), FD(*), CCoor(3,ngrid),
     &       RB(3), TRB(3), TA(3), pot(ncmp,ngrid)
      Logical AeqB
      Character ChOper(0:7)*3
      Integer   iStabO(0:7),
     &          iDCRR(0:7), iDCRT(0:7), iStabM(0:7), nOp(3)
      Data ChOper/'E  ','x  ','y  ','xy ','z  ','xz ','yz ','xyz'/
*                                                                      *
************************************************************************
*                                                                      *
*
*     Statement functions
*
      nElem(ixyz) = (ixyz+1)*(ixyz+2)/2
*                                                                      *
************************************************************************
*                                                                      *
      iRout = 112
      iPrint = nPrint(iRout)
      Call qEnter('Drv1_Pot')
*
      iIrrep = 0
      loper = 2**nIrrep-1
      nComp = (nOrdOp+1)*(nOrdOp+2)/2
      if(ncomp.ne.ncmp) then
        Call WarningMessage(2,'Drv1_pot: ncmp.lt.ncomp')
        Write (6,*) 'ncmp.lt.ncomp:',ncmp,ncomp
        Call Abend()
      end if
      call fzero(pot,ncmp*ngrid)
*
*     Auxiliary memory allocation.
*
      Call GetMem('Zeta','ALLO','REAL',iZeta,m2Max)
      Call GetMem('Zeta','ALLO','REAL',ipZI ,m2Max)
      Call GetMem('Kappa','ALLO','REAL',iKappa,m2Max)
      Call GetMem('PCoor','ALLO','REAL',iPCoor,m2Max*3)
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
*---------- Call kernel routine to get memory requirement.
*
c           Call NAMem(nOrder,MemKer,iAng,jAng,nOrdOp)
            Call EFMmP(nOrder,MemKer,iAng,jAng,nOrdOp)
            MemKrn=MemKer*m2Max
            Call GetMem('Kernel','ALLO','REAL',iKern,MemKrn)

*           Allocate memory for the final integrals, all in the
*           primitive basis.
*
            lFinal=1
            if(nOrdOp.ne.0) then
              lFinal = MaxPrm(iAng) * MaxPrm(jAng)
     &               * nElem(iAng)*nElem(jAng)
     &               * nComp
            end if
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
            Call ZXia(Work(iZeta),Work(ipZI),
     &                iPrim,jPrim,Work(iExp),Work(jExp))
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
            Call GetMem('DSO ','Free','Real',ipDSO,nSO*iPrim*jPrim)
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
*-----------------Generate stabilizer of the operator.
*
                  Call SOS(iStabO,nStabO,lOper)
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
*
                  Do lDCRT = 0, nDCRT-1
                     nOp(1) = NrOpr(iDCRT(lDCRT),iOper,nIrrep)
                     nOp(2) = NrOpr(iEor(iDCRT(lDCRT),
     &                             iDCRR(lDCRR)),iOper,nIrrep)
                     nOp(3) = NrOpr(0,iOper,nIrrep)

                     TA(1) = DBLE(iPhase(1,iDCRT(lDCRT)))*A(1)
                     TA(2) = DBLE(iPhase(2,iDCRT(lDCRT)))*A(2)
                     TA(3) = DBLE(iPhase(3,iDCRT(lDCRT)))*A(3)
                     TRB(1) = DBLE(iPhase(1,iDCRT(lDCRT)))*RB(1)
                     TRB(2) = DBLE(iPhase(2,iDCRT(lDCRT)))*RB(2)
                     TRB(3) = DBLE(iPhase(3,iDCRT(lDCRT)))*RB(3)
                     If (iPrint.ge.49) Then
                        Write (6,'(A,/,3(3F6.2,2X))')
     &                  ' *** Centers A, B, C ***',
     &                  ( TA(i),i=1,3),
     &                  (TRB(i),i=1,3)
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
     &                   TA,TRB,Work(iKappa),Work(iPCoor),Work(ipZI))
*
*--------------------Compute primitive potential integrals and trace with density
*
                     Call potintd(Work(iExp),iPrim,Work(jExp),jPrim,
     &                   Work(iZeta),Work(ipZI),
     &                   Work(iKappa),Work(iPCoor),
     &                   iPrim*jPrim,iAng,jAng,TA,TRB,nOrder,
     &                   Work(iKern),MemKer,work(ipFnl),lFinal,nDAO,
     &                   Ccoor,pot,ngrid,ncmp,Work(ipDAO),nOrdOp)
*
                  End Do
            End Do
*
            Call GetMem('DSOpr ','Free','REAL',ipDSOp,nSO*iPrim*jPrim)
            Call GetMem(' DAO ','Free','Real',ipDAO,nDAO)
            Call GetMem('ScrSph','Free','Real',iScrt2,nScr2)
            Call GetMem('Scrtch','Free','Real',iScrt1,nScr1)
            Call GetMem('Final','Free','Real',ipFnl,lFinal)
            Call GetMem('Kernel','Free','Real',iKern,MemKrn)
 131        Continue
         End Do
      End Do
      If (nOrdOp.eq.2) Then
c... modifify field gradients to get traceless form
         ThreeI = One / Three
         Do igeo=1,ngrid
            XX = Two * pot(1,igeo)-pot(4,igeo)-pot(6,igeo)
            YY = Two * pot(4,igeo)-pot(1,igeo)-pot(6,igeo)
            ZZ = Two * pot(6,igeo)-pot(4,igeo)-pot(1,igeo)
            pot(1,igeo)=XX * ThreeI
            pot(4,igeo)=YY * ThreeI
            pot(6,igeo)=ZZ * ThreeI
         End Do
      End If
*
      Call GetMem('PCoor','FREE','REAL',iPCoor,m2Max*3)
      Call GetMem('Kappa','FREE','REAL',iKappa,m2Max)
      Call GetMem('Zeta','FREE','REAL',ipZI ,m2Max)
      Call GetMem('Zeta','FREE','REAL',iZeta,m2Max)
*
*
      Call qExit('Drv1_Pot')
      Return
      End
c----------------------------------------------------------------------
      SubRoutine PotIntd(Alpha,nAlpha,Beta, nBeta,
     &                  Zeta,ZInv,rKappa,P,
     &                  nZeta,la,lb,A,RB,nRys,
     &                  Array,nArr,Final,lFinal,nDAO,
     &                  CCoor,pot,ngrid,ncmp,DAO,nOrdOp)
c----------------------------------------------------------------------
************************************************************************
*                                                                      *
* Object: kernel routine for the computation of potential (nordop=0)   *
*         or electric field (nordop.gt.0) on a grid                    *
*                                                                      *
* Calling    : QEnter                                                  *
*              RecPrt                                                  *
*              DCopy   (ESSL)                                          *
*              mHrr                                                    *
*              DCR                                                     *
*              Rys                                                     *
*              Hrr                                                     *
*              DaXpY   (ESSL)                                          *
*              GetMem                                                  *
*              QExit                                                   *
*                                                                      *
*     Author: Roland Lindh, Dept. of Theoretical Chemistry, University *
*             of Lund, Sweden, January '91                             *
************************************************************************
      Implicit Real*8 (A-H,O-Z)
*     Used for normal nuclear attraction integrals
      External TNAI, Fake, XCff2D, XRys2D
#include "itmax.fh"
#include "info.fh"
#include "real.fh"
#include "k2.fh"
#include "WrkSpc.fh"
#include "oneswi.fh"

c#include "print.fh"
      Real*8 Zeta(nZeta), ZInv(nZeta), Alpha(nAlpha), Beta(nBeta),
     &       rKappa(nZeta), P(nZeta,3), A(3), RB(3), CCoor(3,*),
     &       Array(nZeta*nArr),pot(ncmp,ngrid),DAO(*),Final(lfinal)
*-----Local arrys
C     Real*8 C(3), TC(3), Coori(3,4), CoorAC(3,2)
      Real*8 TC(3), Coori(3,4), CoorAC(3,2)
      Logical EQ, NoSpecial
      Integer iAnga(4)
C     Character ChOper(0:7)*3
C     Data ChOper/'E  ','x  ','y  ','xy ','z  ','xz ','yz ','xyz'/
*
*     Statement function for Cartesian index
*
      nElem(ixyz) = (ixyz+1)*(ixyz+2)/2
      nabSz(ixyz) = (ixyz+1)*(ixyz+2)*(ixyz+3)/6  - 1
*
      nComp = (nOrdOp+1)*(nOrdOp+2)/2
*
      iAnga(1) = la
      iAnga(2) = lb
      iAnga(3) = nOrdOp
      iAnga(4) = 0
      call dcopy_(3,A,1,Coori(1,1),1)
      call dcopy_(3,RB,1,Coori(1,2),1)
      mabMin = nabSz(Max(la,lb)-1)+1
      mabMax = nabSz(la+lb)
      If (EQ(A,RB)) mabMin=nabSz(la+lb-1)+1
      mcdMin=nabSz(nOrdOp-1)+1
      mcdMax=nabSz(nOrdOp)
      lab=(mabMax-mabMin+1)
      kab=nElem(la)*nElem(lb)
      lcd=(mcdMax-mcdMin+1)
      labcd=lab*lcd
*
*     Compute FLOP's and size of work array which Hrr will use.
*
      Call mHrr(la,lb,nFLOP,nMem)
*
*---- Distribute the work array
*
      ip1 = 1 + nZeta*Max(labcd,lcd*nMem)
      mArr = nArr - Max(labcd,lcd*nMem)
*
*     Find center to accumulate angular momentum on. (HRR)
*
      If (la.ge.lb) Then
       call dcopy_(3,A,1,CoorAC(1,1),1)
      Else
       call dcopy_(3,RB,1,CoorAC(1,1),1)
      End If
*
      nT = nZeta
      NoSpecial=.True.

      do 100 igeo=1,ngrid
        Do i=1,3
          TC(i)=CCoor(i,igeo)
          CoorAC(i,2)=TC(i)
          Coori(i,3)=TC(i)
          Coori(i,4)=TC(i)
        End Do
*
* Compute integrals with the Rys quadrature.
*
      Call Rys(iAnga,nT,Zeta,ZInv,nZeta,
     &         One,One,1,P,nZeta,
     &         TC,1,rKappa,One,Coori,Coori,CoorAC,
     &         mabMin,mabMax,mcdMin,mcdMax,Array(ip1),mArr*nZeta,
     &         TNAI,Fake,XCff2D,XRys2D,NoSpecial)
*
      if(nOrdOp.eq.0) then
*
*-------Use the HRR to compute the required primitive integrals.
*
        Call HRR(la,lb,A,RB,Array(ip1),nZeta,nMem,ipIn)
        ipc=ip1-1+ipin
*
*-------Trace primitive integrals with density
*
         pot(1,igeo)=pot(1,igeo)-ddot_(nDAO,Array(ipc),1,DAO,1)
      else
         Call DGetMO(Array(ip1),nZeta*lab,nZeta*lab,lcd,Array,lcd)
         Call HRR(la,lb,A,RB,Array,lcd*nZeta,nMem,ipIn)
         Call DGetMO(Array(ipIn),lcd,lcd,nZeta*kab,Final,nZeta*kab)
         ipc=1
         do icmp=1,ncomp
           pot(icmp,igeo)=pot(icmp,igeo)+ddot_(nDAO,Final(ipc),1,DAO,1)
           ipc=ipc+nDAO
         end do
      end if
100   Continue
*
      Return
c Avoid unused argument warnings
      If (.False.) Then
         Call Unused_real_array(Alpha)
         Call Unused_real_array(Beta)
         Call Unused_integer(nRys)
      End If
      End