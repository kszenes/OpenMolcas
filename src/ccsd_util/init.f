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
       subroutine init (wrk,wrksize,                                    &
     & lunabij1,lunabij2,lunabij3)
!
!     this routine do FI1,FII1,FIII1,T11,T21
!     1) def F1(a,e) = fok(a,e)
!     2) def F2(m,i) = fok(m,i)
!     3) def F3(e,m) = fok(e,m)
!     4) def T1n(a,i) = fok(a,i)
!     5) def T2m(abij)= <ab||ij>
!
!     lunabij1 - lun of file, where <ab||ij>aaaa is stored (I)
!     lunabij2 - lun of file, where <ab||ij>bbbb is stored (I)
!     lunabij3 - lun of file, where <ab||ij>abab is stored (I)
!
!     N.B. this routine use and destry help files : none
!
       use Para_Info, only: MyRank
#include "ccsd1.fh"
#include "ccsd2.fh"
#include "wrk.fh"
       integer lunabij1,lunabij2,lunabij3
!
!     help variables
!
       integer posst,rc
!
!1.1  map fok(a,b)aa to f1(a,e)aa
       call map (wrk,wrksize,                                           &
     & 2,1,2,0,0,mapdfk1,mapifk1,1,mapdf11,mapif11,possf110,            &
     &           posst,rc)
!
!1.2  map fok(a,b)bb to f1(a,e)bb
       call map (wrk,wrksize,                                           &
     & 2,1,2,0,0,mapdfk2,mapifk2,1,mapdf12,mapif12,possf120,            &
     &           posst,rc)
!
!
!2.1  map fok(i,j)aa to f2(i,j)aa
       call map (wrk,wrksize,                                           &
     & 2,1,2,0,0,mapdfk5,mapifk5,1,mapdf21,mapif21,possf210,            &
     &           posst,rc)
!
!2.2  map fok(i,j)bb to f2(i,j)bb
       call map (wrk,wrksize,                                           &
     & 2,1,2,0,0,mapdfk6,mapifk6,1,mapdf22,mapif22,possf220,            &
     &           posst,rc)
!
!
!3.1  map fok(a,i)aa to f3(a,i)aa
       call map (wrk,wrksize,                                           &
     & 2,1,2,0,0,mapdfk3,mapifk3,1,mapdf31,mapif31,possf310,            &
     &           posst,rc)
!
!3.2  map fok(a,i)bb to f3(a,i)bb
       call map (wrk,wrksize,                                           &
     & 2,1,2,0,0,mapdfk4,mapifk4,1,mapdf32,mapif32,possf320,            &
     &           posst,rc)
!
!
        if (myRank.eq.0) then
!
!4.1  map fok(a,i)aa to t1n(a,i)aa
       call map (wrk,wrksize,                                           &
     & 2,1,2,0,0,mapdfk3,mapifk3,1,mapdt13,mapit13,posst130,            &
     &           posst,rc)
!
!4.2  map fok(a,i)bb to t1n(a,i)bb
       call map (wrk,wrksize,                                           &
     & 2,1,2,0,0,mapdfk4,mapifk4,1,mapdt14,mapit14,posst140,            &
     &           posst,rc)
!
        else
!
!4.3  set t1naa (t13) =0
        call set0 (wrk,wrksize,                                         &
     &             mapdt13,mapit13)
!
!4.4  set t1nbb (t14) =0
        call set0 (wrk,wrksize,                                         &
     &             mapdt14,mapit14)
!
        end if
!
!
        if (myRank.eq.0) then
!
!5.1  load <ab||ij>aaaa from lunabij1 to t2n(ab,ij)aaaa
       call filemanager (2,lunabij1,rc)
       call getmediate (wrk,wrksize,                                    &
     & lunabij1,posst210,mapdt21,mapit21,rc)
!
!5.2  load <ab||ij>bbbb from lunabij2 to t2n(ab,ij)bbbb
       call filemanager (2,lunabij2,rc)
       call getmediate (wrk,wrksize,                                    &
     & lunabij2,posst220,mapdt22,mapit22,rc)
!
!5.3  load <ab||ij>abab from lunabij3 to t2n(ab,ij)abab
       call filemanager (2,lunabij3,rc)
       call getmediate (wrk,wrksize,                                    &
     & lunabij3,posst230,mapdt23,mapit23,rc)
!
        else
!
!5.4  set t2naaaa (t21) =0
        call set0 (wrk,wrksize,                                         &
     &             mapdt21,mapit21)
!
!5.5  set t2nbbbb (t22) =0
        call set0 (wrk,wrksize,                                         &
     &             mapdt22,mapit22)
!
!5.6  set t2nabab (t23) =0
        call set0 (wrk,wrksize,                                         &
     &             mapdt23,mapit23)
!
        end if
!
!
       return
       end
