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
       subroutine mv0v1a3u                                              &
     & (rowa,cola,ddx,ddy,                                              &
     & nopi,nopj,incx,incy,                                             &
     & a,x,y)
!
!     Y(iy) = Y(iy) + A * X(ix)
!
#include "ccsd1.fh"
       integer rowa,cola
       integer ddx, ddy
       integer nopi, nopj, incx, incy
       real*8  a(1:rowa,1:cola)
       real*8  x(1:ddx), y(1:ddy)
!
!      help variables
!
       integer i, j, ix, iy
!
       if (mhkey.eq.1) then
!      ESSL
!      call  dgemx(nopi,nopj,1.0d0,a,rowa,x,incx,y,incy)
       call dgemv_('N',nopi,nopj,1.0d0,a,rowa,x,incx,1.0d0,y,incy)
!
       else
!      Fortran matrix handling
!
!
       if (incx.eq.1.and.incy.eq.1) then
!
!      Inc's = 1
!
       do 30 j = 1, nopj
       do 20 i = 1, nopi
!
       y(i) = y(i) + a(i,j)*x(j)
 20    continue
 30    continue
!
       else
!
!      Other type inc's
!
       ix = 1
       do 60 j = 1, nopj
       iy = 1
       do 50 i = 1, nopi
       y(iy) = a(i,j)*x(ix) + y(iy)
       iy = iy + incy
 50    continue
       ix = ix + incx
 60    continue
!
       end if
!
       end if
!
       return
       end
