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
       subroutine getmediate (wrk,wrksize,                              &
     & lun,poss0,mapd,mapi,rc)
!
!     this routine read required mediate from opened unformatted file
!     with number lun, and place it statring with the poss0
!     it also reads mapd and mapi of the given mediade, and reconstruct
!     mapd to actual possitions
!
!     lun   - Logical unit number of file, where mediate is stored (Input)
!     poss0 - initial possition in WRK, where mediate will be stored (Input)
!     mapd  - direct map matrix corresponding to given mediate (Output)
!     mapi  - inverse map matrix corresponding to given mediate (Output)
!     rc    - return (error) code (Output)
!
!     N.B.
!     all mediates are storred as follows
!     1 - mapd, mapi
!     2 - one record with complete mediate
!
#include "wrk.fh"
       integer lun,poss0,rc
       integer mapd(0:512,1:6)
       integer mapi(1:8,1:8,1:8)
!
!     help variables
!
       integer length,rc1
!
       rc=0
!
!1    read mapd
!
      call getmap (lun,poss0,length,mapd,mapi,rc1)
!
!2    read mediate in one block
!
       if (length.eq.0) then
!     RC=1 : there is nothing to read, length of mediate is 0
       rc=1
       return
       end if
!
       call rea (lun,length,wrk(poss0))
!
       return
       end
