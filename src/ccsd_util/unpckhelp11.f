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
       subroutine unpckhelp11(a,b,dimp,dimq,dime,dimf,eadd,noe,fadd,nof,&
     &                        bb,dimb)
!
!     this routine do:
!     b(e,f,_Bb) =  a(pf,qe)
!
       integer dimp,dimq,dime,dimf,eadd,noe,fadd,nof,bb,dimb
       real*8 a(1:dimp,1:dimq)
       real*8 b(1:dime,1:dimf,1:dimb)
!
!     help variables
       integer qe,pf,f
!
       do 100 pf=fadd+1,fadd+nof
       f=pf-fadd
       do 101 qe=eadd+1,eadd+noe
       b(qe-eadd,f,bb)=a(pf,qe)
 101    continue
 100    continue
!
       return
       end
