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
! Copyright (C) 2021, Roland Lindh                                     *
!***********************************************************************
#define _NEWCODE_
#ifdef _NEWCODE_
      Subroutine DiracX(mGrid,nD,F_xc,Coeff)
      use xc_f03_lib_m
      use nq_Grid, only: Rho, vRho, l_casdft
      use KSDFT_Info, only: F_xca, F_xcb
      use libxc
      implicit none
      Real*8 :: F_xc(mGrid)
      Real*8 :: Coeff
      integer :: mgrid, nD, iGrid, nRho

      ! xc functional
      TYPE(xc_f03_func_t) :: xc_func
      ! xc functional info
      TYPE(xc_f03_func_info_t) :: xc_info

      ! Slater exchange
      integer*4, parameter :: func_id = 1

      ! Initialize memory
      func(:) = 0.0
      dfunc_drho(:,:) = 0.0

      nRho=SIZE(Rho,1)
      ! Initialize libxc functional: nRho = 2 means spin-polarized
      call xc_f03_func_init(xc_func, func_id, int(nRho, 4))

      ! Get the functional's information
      xc_info = xc_f03_func_get_info(xc_func)

      If (nD.eq.1) Rho(:,:)=2.0D0*Rho(:,:)

      ! Evaluate energy depending on the family
!     select case (xc_f03_func_info_get_family(xc_info))
!     case(XC_FAMILY_LDA)
         call xc_f03_lda_exc_vxc(xc_func, mGrid, Rho(1,1), func(1), dfunc_drho(1,1))
!     end select

      ! Libxc evaluates energy density per particle; multiply by
      ! density to get out what we really want
      ! Collect the potential
      If (nD.eq.1) Then
         Do iGrid = 1, mGrid
            F_xc(iGrid) = F_xc(iGrid) + Coeff*func(iGrid)*Rho(1, iGrid)
            vRho(1,iGrid) = vRho(1,iGrid) + Coeff*dfunc_drho(1, iGrid)
         End Do
      Else
         Do iGrid = 1, mGrid
            F_xc(iGrid) =F_xc(iGrid) +Coeff*func(iGrid)*(Rho(1, iGrid) + Rho(2, iGrid))
            vRho(1,iGrid) = vRho(1,iGrid) + Coeff*dfunc_drho(1, iGrid)
            vRho(2,iGrid) = vRho(2,iGrid) + Coeff*dfunc_drho(2, iGrid)
         End Do
         If (l_casdft) Then
            dFunc_dRho(:,:)=Rho(:,:)
            Rho(2,:)=0.0D0
            func(:)=0.0D0
            call xc_f03_lda_exc(xc_func, mGrid, Rho(1,1), func(1))
            Do iGrid = 1, mGrid
               F_xca(iGrid) = F_xca(iGrid) + Coeff*func(iGrid)*Rho(1, iGrid)
            End Do
            Rho(1,:)=0.0D0
            Rho(2,:)=dFunc_dRho(2,:)
            func(:)=0.0D0
            call xc_f03_lda_exc(xc_func, mGrid, Rho(1,1), func(1))
            Do iGrid = 1, mGrid
               F_xcb(iGrid) = F_xcb(iGrid) + Coeff*func(iGrid)*Rho(2, iGrid)
            End Do
            Rho(:,:)=dFunc_dRho(:,:)
         End If
      End If

      call xc_f03_func_end(xc_func)
      If (nD.eq.1) Rho(:,:)=0.5D0*Rho(:,:)
      Return

    End Subroutine DiracX
#else

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
! Copyright (C) 2000, Roland Lindh                                     *
!***********************************************************************
      Subroutine DiracX(mGrid,iSpin,F_xc,Coeff)
!***********************************************************************
!      Author:Roland Lindh, Department of Chemical Physics, University *
!             of Lund, SWEDEN. November 2000                           *
!***********************************************************************
!-Ajitha Modifying the kernel output structure
      use KSDFT_Info, only: F_xca, F_xcb
      use nq_Grid, only: Rho, l_casdft
      use nq_Grid, only: vRho
      Implicit Real*8 (A-H,O-Z)
#include "real.fh"
#include "ksdft.fh"
      Real*8 F_xc(mGrid)
      Real*8, Parameter:: T_X=1.0D-20
!                                                                      *
!***********************************************************************
!                                                                      *
!                                                                      *
!***********************************************************************
!                                                                      *
      THIRD =One/Three
      FTHIRD=Four/Three
      CVX   =(two**THIRD)*((three/Pi)**THIRD)
      Rho_min=T_X*1.0D-2
!                                                                      *
!***********************************************************************
!                                                                      *
!---- Compute value of energy and integrad on the grid
!                                                                      *
!***********************************************************************
!                                                                      *
!     iSpin=1
!
      If (iSpin.eq.1) Then
!                                                                      *
!***********************************************************************
!                                                                      *
      Do iGrid = 1, mGrid
         d_alpha =Rho(1,iGrid)
         DTot=Two*d_alpha
         If (DTot.lt.T_X) Go To 100
!
!------- Exchange contributions to energy
!
         functional=-Three/Two*CVX*d_alpha**FTHIRD
         F_xc(iGrid)=F_xc(iGrid)+Coeff*functional
!
!------- Exchange contributions to the AO integrals
!
         func_d_rho_alpha=-CVX*d_alpha**THIRD
!

         vRho(1,iGrid) = vRho(1,iGrid) + Coeff*func_d_rho_alpha
!
 100     Continue
!
      End Do
!                                                                      *
!***********************************************************************
!                                                                      *
!     iSpin=/=1
!
      Else
!                                                                      *
!***********************************************************************
!                                                                      *
      If (l_casdft) Then
      Do iGrid = 1, mGrid
         d_alpha =Max(Rho_Min,Rho(1,iGrid))
         d_beta  =Max(Rho_Min,Rho(2,iGrid))
         DTot=d_alpha+d_beta
         If (DTot.lt.T_X) Cycle
!------- Exchange contributions to energy
!
         functional =-Three/Four*CVX*(d_alpha**FTHIRD+d_beta**FTHIRD)
         functionala=-Three/Four*CVX*(d_alpha**FTHIRD)
         functionalb=-Three/Four*CVX*(                d_beta**FTHIRD)
         F_xc(iGrid) =F_xc(iGrid) +Coeff*functional
         F_xca(iGrid)=F_xca(iGrid)+Coeff*functionala
         F_xcb(iGrid)=F_xcb(iGrid)+Coeff*functionalb
!
!------- Exchange contributions to the AO integrals
!
         func_d_rho_alpha=-CVX*d_alpha**THIRD
         func_d_rho_beta =-CVX*d_beta **THIRD
!
         vRho(1,iGrid) = vRho(1,iGrid) + Coeff*func_d_rho_alpha
         vRho(2,iGrid) = vRho(2,iGrid) + Coeff*func_d_rho_beta
!
      End Do
      Else
      Do iGrid = 1, mGrid
         d_alpha =Max(Rho_Min,Rho(1,iGrid))
         d_beta  =Max(Rho_Min,Rho(2,iGrid))
         DTot=d_alpha+d_beta
         If (DTot.lt.T_X) Cycle
!------- Exchange contributions to energy
!
         functional =-Three/Four*CVX*(d_alpha**FTHIRD+d_beta**FTHIRD)
         F_xc(iGrid) =F_xc(iGrid) +Coeff*functional
!
!------- Exchange contributions to the AO integrals
!
         func_d_rho_alpha=-CVX*d_alpha**THIRD
         func_d_rho_beta =-CVX*d_beta **THIRD
!
         vRho(1,iGrid) = vRho(1,iGrid) + Coeff*func_d_rho_alpha
         vRho(2,iGrid) = vRho(2,iGrid) + Coeff*func_d_rho_beta
!
      End Do
      End If
!
      End If
!
      Return
      End
#endif
