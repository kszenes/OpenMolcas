!***********************************************************************
! This file is part of OpenMolcas.                                     *
!                                                                      *
! OpenMolcas is free software; you can redistribute it and/or modify   *
! it under the terms of the GNU Lesser General Public License, v. 2.1. *
! OpenMolcas is distributed in the hope that it will be useful, but it *
! is provided "as is" and without any express or implied warranties.   *
! For more details see the full text of the license in the file        *
! LICENSE or in <http://www.gnu.org/licenses/>.                        *
!***********************************************************************
       subroutine fokunpck1 (fok,dp,dimfok)
!
!     this routine do Fok = Fok - dp
!     fok    - Fok matrix (I/O)
!     dp     - Diagonal part vector (I)
!     dimfok - dimension for Fok matrix - norb (I)
!
       integer dimfok
!
       real*8 fok(1:dimfok,1:dimfok)
       real*8 dp(1:dimfok)
!
!     help variables
!
       integer p
!
!1    substract dp from Fok
       do 100 p=1,dimfok
       fok(p,p)=fok(p,p)-dp(p)
 100    continue
!
       return
       end
