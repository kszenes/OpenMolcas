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
! Copyright (C) 1992,2002, Roland Lindh                                *
!***********************************************************************
!#define _DEBUGPRINT_
      SubRoutine RctFld(h1,TwoHam,D,RepNuc,nh1,First,Dff,NonEq)
!***********************************************************************
!                                                                      *
!     Driver for RctFld_                                               *
!                                                                      *
!***********************************************************************
      use stdalloc, only: mma_allocate, mma_deallocate
      use rctfld_module, only: lMax, MM
      Implicit None
      Integer nh1
      Real*8 h1(nh1), TwoHam(nh1), D(nh1), RepNuc
      Logical First, Dff, NonEq

      Integer nComp
      Real*8, Allocatable:: Vs(:,:), QV(:,:)
!
      nComp=(lMax+1)*(lMax+2)*(lMax+3)/6
      call mma_Allocate(Vs,nComp,2,Label='Vs')
      call mma_Allocate(QV,nComp,2,Label='QV')
!
      Call RctFld_Internal(MM,nComp)
!
      Call mma_deallocate(Vs)
      Call mma_deallocate(QV)
!
      Contains
      SubRoutine RctFld_Internal(Q_solute,nComp)
!***********************************************************************
!                                                                      *
! Object: to apply a modification to the one-electron hamiltonian due  *
!         the reaction field. The code here is direct!                 *
!         This subroutine works only if a call to GetInf has been      *
!         prior to calling this routine.                               *
!                                                                      *
!         h1: one-electron hamiltonian to be modified. Observe that    *
!             the contribution due to the reaction field is added to   *
!             this array, i.e. it should be set prior to calling this  *
!             routine.                                                 *
!                                                                      *
!         TwoHam: dito two-electron hamiltonian.                       *
!                                                                      *
!         D:  the first order density matrix                           *
!                                                                      *
!         h1, TwoHam and D are all in the SO basis.                    *
!                                                                      *
!         Observe the energy expression for the electric field -       *
!         charge distribution interaction!                             *
!                                                                      *
!         -1/2 Sum(nl) E(tot,nl)M(tot,nl)                              *
!                                                                      *
!     Author: Roland Lindh, Dept. of Theoretical Chemistry,            *
!             University of Lund, SWEDEN                               *
!             July '92                                                 *
!                                                                      *
!             Modified for nonequilibrum calculations January 2002 (RL)*
!***********************************************************************
#ifdef _DEBUGPRINT_
      use Basis_Info, only: nBas
      use Symmetry_Info, only: nIrrep
#endif
      use External_Centers, only: XF
      use Gateway_global, only: PrPrt
      use Gateway_Info, only: PotNuc
      use Constants, only: Half, One, Zero
      use rctfld_module, only: EPS, EPSINF, rds
      Implicit None
      Real*8 Origin(3)
#ifdef _DEBUGPRINT_
      Character(LEN=72) Label
      Integer lOff, iIrrep, n
#endif
      Integer nComp
      Real*8 Q_solute(nComp,2)

      Character(LEN=8) Label2
      Real*8 FactOp(1), E_0_NN
      Integer lOper(1), ixyz, iOff, nOrdOp, iMax, ip, ix, iy, iz,
     &                  iSymX, iSymY, iSymZ, iTemp, nOpr, iMltpl
      Integer, External:: IrrFnc, MltLbl
      Real*8, External:: DDot_
!
!-----Statement Functions
!
      iOff(ixyz) = ixyz*(ixyz+1)*(ixyz+2)/6
!
      lOper(1)=1
      nOrdOp=lMax
!-----Set flag so only the diagonal blocks are computed
      Prprt=.True.
      Origin(:)=Zero
!
!-----Generate local multipoles in the primitive basis and accumulate to
!     global multipoles.
!                                                                      *
!***********************************************************************
!                                                                      *
!                                                                      *
!***********************************************************************
!                                                                      *
!-----Add nuclear-nuclear contribution to the potential energy
!
      If (First) Then
!
         If (NonEq) Then
            Call Get_dArray('RCTFLD',QV,nComp*2)
            Call Get_dScalar('E_0_NN',E_0_NN)
         End If
!1)
!
!------- Compute M(nuc,nl), nuclear multipole moments
!
         Do iMax = 0, lMax
            ip = 1+iOff(iMax)
            Call RFNuc(Origin,Q_solute(ip,1),iMax)
         End Do

         if(Allocated(XF)) Then
!
!------- Add contribution from XFIELD multipoles
!
!        Use Vs as temporary space, it will anyway be overwritten
            Call XFMoment(lMax,Q_solute,Vs,nComp,Origin)
         EndIf

#ifdef _DEBUGPRINT_
         Call RecPrt('Nuclear Multipole Moments',
     &                                 ' ',Q_solute(1,1),1,nComp)
#endif
!
!--------Solve dielectical equation(nuclear contribution), i.e.
!        M(nuc,nl) -> E(nuc,nl)
!
         call dcopy_(nComp,Q_solute(1,1),1,Vs(1,1),1)
         Call AppFld(Vs(1,1),rds,Eps,lMax,EpsInf,NonEq)
!
#ifdef _DEBUGPRINT_
         Call RecPrt('Nuclear Electric Field',
     &                                 ' ',Vs(1,1),1,nComp)
#endif
!
!--------Vnn = Vnn - 1/2 Sum(nl) E(nuc,nl)*M(nuc,nl)
!
         RepNuc = PotNuc -
     &            Half * DDot_(nComp,Q_solute(1,1),1,Vs(1,1),1)
!
!------- Add contributions due to slow counter charges
!
         If (NonEq) RepNuc=RepNuc+E_0_NN
#ifdef _DEBUGPRINT_
         Write (6,*) ' RepNuc=',RepNuc
#endif
!2)
!
!--------Compute contribution to the one-electron hamiltonian
!
!        hpq = hpq + Sum(nl) E(nuc,nl)*<p|M(nl)|q>
!
#ifdef _DEBUGPRINT_
         Write (6,*) 'h1'
         lOff = 1
         Do iIrrep = 0, nIrrep-1
            n = nBas(iIrrep)*(nBas(iIrrep)+1)/2
            If (n.gt.0) Then
               Write (Label,'(A,I1)')
     &          'Diagonal Symmetry Block ',iIrrep+1
               Call Triprt(Label,' ',h1(lOff),nBas(iIrrep))
               lOff = lOff + n
            End If
         End Do
#endif
!
!------- Add potential due to slow counter charges
!
         If (NonEq) Then
            call dcopy_(nComp,QV(1,1),1,QV(1,2),1)
            Call AppFld_NonEQ_2(QV(1,2),rds,Eps,lMax,EpsInf,NonEq)
            Call DaXpY_(nComp,One,QV(1,2),1,Vs(1,1),1)
         End If
!
         Call Drv2_RF(lOper(1),Origin,nOrdOp,Vs(1,1),lMax,h1,nh1)
!
#ifdef _DEBUGPRINT_
         Write (6,*) 'h1(mod)'
         lOff = 1
         Do iIrrep = 0, nIrrep-1
            n = nBas(iIrrep)*(nBas(iIrrep)+1)/2
            If (n.gt.0) Then
               Write (Label,'(A,I1)')
     &          'Diagonal Symmetry Block ',iIrrep+1
               Call Triprt(Label,' ',h1(lOff),nBas(iIrrep))
               lOff = lOff + n
            End If
         End Do
#endif
!
!------- Update h1 and RepNuc_save with respect to static contributions!
!
         Label2='PotNuc00'
         Call Put_Temp(Label2,[RepNuc],1)
         Label2='h1_raw  '
         Call Put_Temp(Label2,h1,nh1)
!
      End If
!                                                                      *
!***********************************************************************
!                                                                      *
!-----Compute the electronic contribution to the charge distribution.
!
!3)
!     M(el,nl) =  - Sum(p,q) Dpq <p|M(nl)|q>
!
      nOpr=1
      FactOp(1)=One
!-----Reset array for storage of multipole moment expansion
      call dcopy_(nComp,[Zero],0,Q_solute(1,2),1)
      Do iMltpl = 1, lMax
         Do ix = iMltpl, 0, -1
            If (Mod(ix,2).eq.0) Then
               iSymX=1
            Else
               ixyz=1
               iSymX=2**IrrFnc(ixyz)
               If (Origin(1).ne.Zero) iSymX = iOr(iSymX,1)
            End If
            Do iy = iMltpl-ix, 0, -1
               If (Mod(iy,2).eq.0) Then
                  iSymY=1
               Else
                  ixyz=2
                  iSymY=2**IrrFnc(ixyz)
                  If (Origin(2).ne.Zero) iSymY = iOr(iSymY,1)
               End If
               iz = iMltpl-ix-iy
               If (Mod(iz,2).eq.0) Then
                  iSymZ=1
               Else
                  ixyz=4
                  iSymZ=2**IrrFnc(ixyz)
                  If (Origin(3).ne.Zero) iSymZ = iOr(iSymZ,1)
               End If
!
               iTemp = MltLbl(iSymX,MltLbl(iSymY,iSymZ))
               lOper(1)=iOr(lOper(1),iTemp)
            End Do
         End Do
      End Do
#ifdef _DEBUGPRINT_
      Write (6,*) '1st order density'
      lOff = 1
      Do iIrrep = 0, nIrrep-1
         n = nBas(iIrrep)*(nBas(iIrrep)+1)/2
         Write (Label,'(A,I1)')
     &    'Diagonal Symmetry Block ',iIrrep+1
         Call Triprt(Label,' ',D(lOff),nBas(iIrrep))
         lOff = lOff + n
      End Do
#endif
!
      Call Drv1_RF(FactOp,nOpr,D,nh1,Origin,lOper,Q_solute(1,2),lMax)
!
#ifdef _DEBUGPRINT_
      Call RecPrt('Electronic Multipole Moments',
     &                              ' ',Q_solute(1,2),1,nComp)
#endif
!
!-----Solve dielectical equation(electronic contribution), i.e.
!     M(el,nl) -> E(el,nl)
!
      call dcopy_(nComp,Q_solute(1,2),1,Vs(1,2),1)
      Call AppFld(Vs(1,2),rds,Eps,lMax,EpsInf,NonEq)
#ifdef _DEBUGPRINT_
      Call RecPrt('Electronic Electric Field',
     &                              ' ',Vs(1,2),1,nComp)
#endif
!4)
!
!-----Compute contribution to the two-electron hamiltonian.
!
!     T(D)pq = T(D)pq + Sum(nl) E(el,nl)*<p|M(nl)|q>
!
      Call Drv2_RF(lOper(1),Origin,nOrdOp,Vs(1,2),lMax,TwoHam,nh1)
!
#ifdef _DEBUGPRINT_
      Write (6,*) 'h1(mod)'
      lOff = 1
      Do iIrrep = 0, nIrrep-1
         n = nBas(iIrrep)*(nBas(iIrrep)+1)/2
         If (n.gt.0) Then
            Write (Label,'(A,I1)')
     &       'Diagonal Symmetry Block ',iIrrep+1
            Call Triprt(Label,' ',h1(lOff),nBas(iIrrep))
            lOff = lOff + n
         End If
      End Do
      Write (6,*) 'TwoHam(mod)'
      lOff = 1
      Do iIrrep = 0, nIrrep-1
         n = nBas(iIrrep)*(nBas(iIrrep)+1)/2
         Write (Label,'(A,I1)')
     &    'Diagonal Symmetry Block ',iIrrep+1
         Call Triprt(Label,' ',TwoHam(lOff),nBas(iIrrep))
         lOff = lOff + n
      End Do
      Write (6,*) ' RepNuc=',RepNuc
#endif
!                                                                      *
!***********************************************************************
!                                                                      *
!---- Write information to be used for gradient calculations or for
!     non-equilibrium calculations
!
      If (.Not.NonEq) Then
!
!        Save total solute multipole moments and total potential
!        of the solution.
!
         call dcopy_(nComp,Q_solute(1,1),1,QV(1,1),1)
         call daxpy_(nComp,One,Q_solute(1,2),1,QV(1,1),1)
         call dcopy_(nComp,Vs(1,1),1,QV(1,2),1)
         call daxpy_(nComp,One,Vs(1,2),1,QV(1,2),1)
         Call Put_dArray('RCTFLD',QV,nComp*2)
!
!        Compute terms to be added to RepNuc for non-equilibrium
!        calculation.
!
         call dcopy_(nComp,QV(1,1),1,QV(1,2),1)
         Call AppFld_NonEQ_1(QV(1,2),rds,Eps,lMax,EpsInf,NonEq)
         E_0_NN=-Half*DDot_(nComp,QV(1,1),1,QV(1,2),1)
!
         call dcopy_(nComp,QV(1,1),1,QV(1,2),1)
         Call AppFld_NonEQ_2(QV(1,2),rds,Eps,lMax,EpsInf,NonEq)
         E_0_NN=E_0_NN+DDot_(nComp,Q_solute(1,1),1,QV(1,2),1)
         Call Put_dScalar('E_0_NN',E_0_NN)
!
      End If
!                                                                      *
!***********************************************************************
!                                                                      *
!
! Avoid unused argument warnings
      If (.False.) Call Unused_logical(Dff)
      End SubRoutine RctFld_Internal

      End SubRoutine RctFld
