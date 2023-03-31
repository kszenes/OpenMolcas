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
       subroutine add43 (a,b,q,dimp,dimqr,dimr,fact)

!     this routine do:
!     B(p,qr) <-- fact * A(p,r) for given q
!
#include "ccsd1.fh"
       integer dimp,dimqr,dimr,q
       real*8 fact
       real*8 b(1:dimp,1:dimqr)
       real*8 a(1:dimp,1:dimr)
!
!     help variable
!
       integer p,qr,rq,r
!
       if (q.eq.1) goto 101
!
       qr=nshf(q)
       do 100 r=1,q-1
       qr=qr+1
!
       do 50 p=1,dimp
       b(p,qr)=b(p,qr)+fact*a(p,r)
 50     continue
!
 100    continue
!
 101    if (q.eq.dimr) then
       return
       end if
!
!
       do 200 r=q+1,dimr
       rq=nshf(r)+q
       do 150 p=1,dimp
       b(p,rq)=b(p,rq)-fact*a(p,r)
 150    continue
!
 200    continue
!
       return
       end
