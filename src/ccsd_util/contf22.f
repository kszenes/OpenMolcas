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
       subroutine contf22 (wrk,wrksize)
!
!     this routine do:
!     f2(m,i) <- 0.5 sum(m) [fok(m,e) . T1o(e,i)]
!
!     N.B. use and destroy : M1,M2
!
       use Para_Info, only: MyRank
#include "ccsd2.fh"
#include "parallel.fh"
#include "wrk.fh"
!
!     help variables
!
       integer posst,rc,ssc
!
!1    f2(m,i)aa <- 0.5 sum(e-a) [ fok(e,m)aa . t1o(e,i)aa]
!
!par
      if (myRank.eq.idbaab) then
!
!1.1  map M1(m,e) <= fok(e,m)aa
       call map (wrk,wrksize,                                           &
     & 2,2,1,0,0,mapdfk3,mapifk3,1,mapdm1,mapim1,possm10,               &
     &           posst,rc)
!
!1.2  mult M2(m,i) <= M1(m,e) . T1o(e,i)aa
       call mult (wrk,wrksize,                                          &
     & 2,2,2,1,mapdm1,mapim1,1,mapdt11,mapit11,1,mapdm2,                &
     &            mapim2,ssc,possm20,rc)
!
!1.3  add f2(m,i)aa <- 0.5 M2(m,i)
       call add (wrk,wrksize,                                           &
     & 2,2,0,0,0,0,1,1,0.5d0,mapdm2,1,mapdf21,mapif21,1,rc)
!
       end if
!
!
!2    f2(m,i)aa <- 0.5 sum(e-b) [ fok(e,m)bb . t1o(e,i)bb]
!
!par
      if (myRank.eq.idaabb) then
!
!2.1  map M1(m,e) <= fok(e,m)bb
       call map (wrk,wrksize,                                           &
     & 2,2,1,0,0,mapdfk4,mapifk4,1,mapdm1,mapim1,possm10,               &
     &           posst,rc)
!
!2.2  mult M2(m,i) <= M1(m,e) . T1o(e,i)bb
       call mult (wrk,wrksize,                                          &
     & 2,2,2,1,mapdm1,mapim1,1,mapdt12,mapit12,1,mapdm2,                &
     &            mapim2,ssc,possm20,rc)
!
!2.3  add f2(m,i)bb <- 0.5 M2(m,i)
       call add (wrk,wrksize,                                           &
     & 2,2,0,0,0,0,1,1,0.5d0,mapdm2,1,mapdf22,mapif22,1,rc)
!
        end if
!
       return
       end
