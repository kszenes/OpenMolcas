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
! Copyright (C) 2020, Roland Lindh                                     *
!***********************************************************************
Module Arrays
Implicit None
Private
Public :: Hss, FaMO_spinp, FaMO_spinm, SFock, G2mp, G2pp, G2mm, Fm, Fp, &
          G1p, G1m, CMO_Inv, CMO, DFTP, CFTP, DTOC, CNSM, INT1
#include "detdim.fh"
Real*8, Allocatable:: Hss(:)
Real*8, Allocatable:: FaMO_spinp(:), FaMO_spinm(:), SFock(:)
Real*8, Allocatable:: G2mp(:), G2pp(:), G2mm(:)
Real*8, Allocatable:: Fm(:), Fp(:)
Real*8, Allocatable:: G1p(:), G1m(:)
Real*8, Allocatable:: CMO_Inv(:)
Real*8, Allocatable:: CMO(:)


!     DFTP          :        OPEN SHELL DETERMINANTS OF PROTO TYPE
!     CFTP          :        BRANCHING DIAGRAMS FOR PROTO TYPES
!     DTOC          :        CSF-DET TRANSFORMATION FOR PROTO TYPES
!     CNSM(:)%ICONF :        NCNSM  CONFIGURATION EXPANSIONS
!     CNSM(I)%ICTS  :        adress of determinant I in STRING ordering for
!                            determinant I in CSF ordering
!                            reference symmetry IREFSM.
Integer, Allocatable:: DFTP(:)
Integer, Allocatable:: CFTP(:)
Real*8,  Allocatable:: DTOC(:)
Type Storage
  Integer, Allocatable:: ICONF(:)
  Integer, Allocatable:: ICTS(:)
End Type Storage
Type (Storage) :: CNSM(MXCNSM)
!         INT1        :  Core integrals
Real*8, Allocatable:: INT1(:)
End Module Arrays
