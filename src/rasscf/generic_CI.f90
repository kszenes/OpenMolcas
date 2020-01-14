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
! Copyright (C) 2020, Oskar Weser                                      *
!***********************************************************************


module generic_CI
    use fciqmc, only: DoNECI, fciqmc_ctl, &
        fciqmc_init => init, fciqmc_cleanup => cleanup
    implicit none
    private
    public :: CI_init_t, CI_solver_t, CI_cleanup_t

    abstract interface
!>  @brief
!>      Interface for procedure pointers to CI-solvers
!>
!>  @author Oskar Weser
!>
!>  @paramin[in] actual_iter The actual iteration number starting at 0.
!>      This means 0 is 1A, 1 is 1B, 2 is 2 and so on.
!>  @paramin[in] CMO MO coefficients
!>  @paramin[in] DIAF DIAGONAL of Fock matrix useful for NECI
!>  @paramin[in] D1I_MO Inactive 1-dens matrix
!>  @paramin[in] TUVX Active 2-el integrals
!>  @paramin[inout] F_In Fock matrix from inactive density
!>  @paramin[inout] D1S_MO Average spin 1-dens matrix
!>  @paramin[out] DMAT Average 1 body density matrix
!>  @paramin[out] PSMAT Average symm. 2-dens matrix
!>  @paramin[out] PAMAT Average antisymm. 2-dens matrix
        subroutine CI_solver_t(actual_iter, CMO, DIAF, D1I_AO, D1A_AO, TUVX, &
                               F_IN, D1S_MO, DMAT, PSMAT, PAMAT)
            use general_data, only : ntot, ntot1, ntot2
            use rasscf_data, only : Nac, nAcPar, nAcpr2

            integer, intent(in) :: actual_iter
            real*8, intent(in) :: CMO(nTot2), DIAF(nTot), D1I_AO(nTot2), &
                                  D1A_AO(nTot2), TUVX(nAcpr2)
            real*8, intent(inout) :: F_In(nTot1), D1S_MO(nAcPar)
            real*8, intent(out) :: DMAT(nAcpar), PSMAT(nAcpr2), PAMAT(nAcpr2)
        end subroutine

!>  @brief
!>      Interface to init routine for CI-solvers
!>
!>  @author Oskar Weser
        subroutine CI_init_t()
        end subroutine

!>  @brief
!>      Interface to cleanup routine for CI-solvers
!>
!>  @author Oskar Weser
        subroutine CI_cleanup_t()
        end subroutine
    end interface

end module generic_CI
