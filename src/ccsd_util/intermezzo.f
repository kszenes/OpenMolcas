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
       subroutine intermezzo (wrk,wrksize,                              &
     & lunw3aaaa,lunw3bbbb,lunw3abba,                                   &
     & lunw3baab,lunw3aabb,lunw3bbaa,lunt2o1,lunt2o2,lunt2o3,           &
     & lunabij1,lunabij2,lunabij3)
!
!     this routine calculate contributions
!     WIII3, WIII4 and T26
!
!     assigment of spin combinations:
!
!     WIII(m,e,b,j)aaaa  - I
!     WIII(m,e,b,j)bbbb  - K
!     WIII(m,e,b,j)aabb  - L
!     WIII(m,e,b,j)abba  - M
!     WIII(m,e,b,j)baab  - N
!     WIII(m,e,b,j)bbaa  - J
!
!     WIII3
!     WIII(m,e,b,j)aaaa <- sum(n-a) [ <mn||je>aaaa . T1o(n,b)aa ]
!     WIII(m,e,b,j)bbbb <- sum(n-b) [ <mn||je>bbbb . T1o(n,b)bb ]
!     WIII(m,e,b,j)aabb <- sum(n-b) [ <mn||je>abba . T1o(n,b)bb ]
!     WIII(m,e,b,j)abba <- sum(n-b) [ <mn||je>abab . T1o(n,b)bb ]
!     WIII(m,e,b,j)baab <- -sum(n-a) [ <nm||je>abba . T1o(n,b)aa ]
!     WIII(m,e,b,j)bbaa <- -sum(n-a) [ <je||nm>abab . T1o(n,b)aa ]
!
!     WIII4
!     Q(f,b,j,n)aaaa   <= 0.5 T2o(f,b,j,n)aaaa + T1o(f,j)aa . T1o(b,n)aa
!     WIII(m,e,b,j)aaaa <- -sum(n,f-aa)     [ Q(f,b,j,n)aaaa   . <ef||mn>aaaa ]
!     <- 0.5 sum(n,f-bb)  [ T2o(b,f,j,n)abab . <ef||mn>abab ]
!     WIII(m,e,b,j)aabb <- 0.5 sum(n,f-aa)  [ T2o(f,b,n,j)abab . <ef||mn>aaaa ]
!     <- -sum(n,f-bb)     [ Q(f,b,j,n)bbbb   . <ef||mn>abab ]
!     Q(f,b,j,n)bbbb   <= 0.5 T2o(f,b,j,n)bbbb + T1o(f,j)nn . T1o(b,n)bb
!     WIII(m,e,b,j)bbbb <- -sum(n,f-bb)     [ Q(f,b,j,n)bbbb   . <ef||mn>bbbb ]
!     <- 0.5 sum(n,f-aa)  [ T2o(f,b,n,j)abab . <fe||nm>abab ]
!     WIII(m,e,b,j)bbaa <- 0.5 sum(n,f-bb)  [ T2o(b,f,j,n)abab . <ef||mn>bbbb ]
!     <- - sum(n,f-aa)    [ Q(f,b,j,n)aaaa   . <fe||nm>abab ]
!     Q(f,b,j,n)abab   <= 0.5 T2o(f,b,j,n)abab + T1o(f,j)aa . T1o(b,n)bb
!     WIII(m,e,b,j)abba <- sum(n,f-ba)      [ Q(f,b,j,n)abab   . <fe||mn>abab ]
!     Q(b,f,n,j)abab   <= 0.5 T2o(b,f,n,j)abab + T1o(b,n)aa . T1o(fmj)bb
!     WIII(m,e,b,j)baab <- sum(n,f-ab)      [ Q(b,f,n,j)abab   . <ef||nm>abab ]
!
!
!     T26
!     R1(a,i,b,j)aaaa <= sum(m,e-aa) [ T2o(a,e,i,m)aaaa . WIII(m,e,b,j)aaaa ]
!     <- sum(m,e-bb) [ T2o(a,e,i,m)abab . WIII(m,e,b,j)bbaa ]
!     T2n(ab,ij)aaaa   <= {1(a,i,b,j)-R1(b,i,a,j)-R1(a,j,b,i)+R1(b,j,a,i)}aaaa
!     R1(a,i,b,j)bbbb <= sum(m,e-bb) [ T2o(a,e,i,m)bbbb . WIII(m,e,b,j)bbbb ]
!     <- sum(m,e-aa) [ T2o(e,a,m,i)abab . WIII(m,e,b,j)aabb ]
!     T2n(ab,ij)bbbb   <= {1(a,i,b,j)-R1(b,i,a,j)-R1(a,j,b,i)+R1(b,j,a,i)}bbbb
!     T2n(a,b,i,j)abab <- sum(m,e-aa) [ T2o(a,e,i,m)aaaa . WIII(m,e,b,j)aabb ]
!     <- sum(m,e-aa) [ T2o(e,b,m,j)abab . WIII(m,e,a,i)aaaa ]
!     <- sum(m,e-bb) [ T2o(a,e,i,m)abab . WIII(m,e,b,j)bbbb ]
!     <- sum(m,e-bb) [ T2o(b,e,j,m)bbbb . WIII(m,e,a,i)bbaa ]
!     <- sum(m,e-ab) [ T2o(a,e,m,j)abab . WIII(m,e,b,i)abba ]
!     <- sum(m,e-ab) [ T2o(e,b,i,m)abab . WIII(m,e,a,j)baab ]
!
!     N.B. use and destry : V1,V2,V3,V4,M1,M2
!     N.B. # of read      : 30 + 6
!     # of write     : 2
!
        use Para_Info, only: MyRank
        implicit none
#include "ccsd2.fh"
#include "wrk.fh"
#include "parallel.fh"
!
       integer lunw3aaaa,lunw3bbbb,lunw3abba,lunw3baab,lunw3aabb,       &
     & lunw3bbaa
       integer lunt2o1,lunt2o2,lunt2o3,lunabij1,lunabij2,lunabij3
!
!     help variableas
!
       integer posst,rc,ssc,lunqaaaa,lunqbbbb
!
!
!A.1  rewind nw3 files
!par
        if (myRank.eq.idaaaa) then
       call filemanager (2,lunw3aaaa,rc)
        end if
!
        if (myRank.eq.idbaab) then
       call filemanager (2,lunw3baab,rc)
        end if
!
        if (myRank.eq.idbbaa) then
       call filemanager (2,lunw3bbaa,rc)
        end if
!
        if (myRank.eq.idbbbb) then
       call filemanager (2,lunw3bbbb,rc)
        end if
!
        if (myRank.eq.idabba) then
       call filemanager (2,lunw3abba,rc)
        end if
!
        if (myRank.eq.idaabb) then
       call filemanager (2,lunw3aabb,rc)
        end if
!
!0.1  map M1(i,a) <- T1o(a,i)aa
       call map (wrk,wrksize,                                           &
     & 2,2,1,0,0,mapdt11,mapit11,1,mapdm1,mapim1,possm10,               &
     &           posst,rc)
!0.2  map M2(i,a) <- T1o(a,i)bb
       call map (wrk,wrksize,                                           &
     & 2,2,1,0,0,mapdt12,mapit12,1,mapdm2,mapim2,possm20,               &
     &           posst,rc)
!
!
!     part I - W3aaaa
!par  all contributions are calculated for idaaaa only,
!     just Qaaaa is calculated both on idaaaa and idbbaa
!
!     par
      if (idaaaa.eq.myRank) then
!
!I.1  get V1(m,e,a,j) <- W3aaaa(m,e,a,j)
       call getw3 (wrk,wrksize,                                         &
     & lunw3aaaa,1)
!
!I.2  WIII(m,e,b,j)aaaa <- sum(n-a) [ <mn||je>aaaa . T1o(n,b)aa ]
!
!I.2.1expand V2(j,e,m,n) <- <je||mn>aaaa
       call expand (wrk,wrksize,                                        &
     & 4,3,mapdw11,mapiw11,1,possv20,mapdv2,mapiv2,rc)
!I.2.2map V3(m,e,j,n) <- V2(j,e,m,n)
       call map (wrk,wrksize,                                           &
     & 4,3,2,1,4,mapdv2,mapiv2,1,mapdv3,mapiv3,possv30,posst,           &
     &           rc)
!I.2.3mult V2(m,e,j,b) <- V3(m,e,j,n) . M1(n,b)
       call mult (wrk,wrksize,                                          &
     & 4,2,4,1,mapdv3,mapiv3,1,mapdm1,mapim1,1,mapdv2,mapiv2,           &
     &            ssc,possv20,rc)
!I.2.4map V3(m,e,b,j) <- V2(m,e,j,b)
       call map (wrk,wrksize,                                           &
     & 4,1,2,4,3,mapdv2,mapiv2,1,mapdv3,mapiv3,possv30,posst,           &
     &           rc)
!I.2.5add V1(m,e,b,j) <- 1.0d0 . V3(m,e,b,j)
       call add (wrk,wrksize,                                           &
     & 4,4,0,0,0,0,1,1,1.0d0,mapdv3,1,mapdv1,mapiv1,1,rc)
!parend
        end if
!
!I.3  WIII4
!     Q(f,b,j,n)aaaa   <= 0.5 T2o(f,b,j,n)aaaa + T1o(f,j)aa . T1o(b,n)aa
!     WIII(m,e,b,j)aaaa <- -sum(n,f-aa)     [ Q(f,b,j,n)aaaa   . <ef||mn>aaaa ]
!     <- 0.5 sum(n,f-bb)  [ T2o(b,f,j,n)abab . <ef||mn>abab ]
!
!par
        if ((myRank.eq.idaaaa).or.(myRank.eq.idbbaa)) then
!I.3.1get V3(fb,jn) <- T2o(fb,jn)aaaa
       call filemanager (2,lunt2o1,rc)
       call getmediate (wrk,wrksize,                                    &
     & lunt2o1,possv30,mapdv3,mapiv3,rc)
!I.3.2expand V2(f,b,j,n) <- V3(fb,jn)
       call expand (wrk,wrksize,                                        &
     & 4,4,mapdv3,mapiv3,1,possv20,mapdv2,mapiv2,rc)
!I.3.3mkQ V2(f,b,j,n) <- 0.5 V2(f,b,j,n) + T1o(f,j)aa . T1o(b,n)aa
       call mkq(wrk,wrksize,                                            &
     & mapdv2,mapiv2,mapdt11,mapit11,mapdt11,mapit11,0.5d0,rc)
!I.3.4map V3(f,n,b,j) <- V2(f,b,j,n)
       call map (wrk,wrksize,                                           &
     & 4,1,3,4,2,mapdv2,mapiv2,1,mapdv3,mapiv3,possv30,posst,           &
     &           rc)
!parend
        end if
!par
        if (myRank.eq.idbbaa) then
!I.3.5write V3(f,n,b,j) to lunqaaaa
       call filemanager (1,lunqaaaa,rc)
       call wrtmediate (wrk,wrksize,                                    &
     & lunqaaaa,mapdv3,mapiv3,rc)
        end if
!
!par
        if (myRank.eq.idaaaa) then
!I.3.6get V2(ef,mn) = <ef||mn>aaaa from luna file
       call filemanager (2,lunabij1,rc)
       call getmediate (wrk,wrksize,                                    &
     & lunabij1,possv20,mapdv2,mapiv2,rc)
!I.3.7expand V4(e,f,m,n) <- V2(ef,mn)
       call expand (wrk,wrksize,                                        &
     & 4,4,mapdv2,mapiv2,1,possv40,mapdv4,mapiv4,rc)
!I.3.8map V2(m,e,f,n) <- V4(e,f,m,n)
       call map (wrk,wrksize,                                           &
     & 4,2,3,1,4,mapdv4,mapiv4,1,mapdv2,mapiv2,possv20,posst,           &
     &           rc)
!I.3.9mult V4(m,e,b,j) <- V2(m,e,f,n) . V3(f,n,b,j)
       call mult (wrk,wrksize,                                          &
     & 4,4,4,2,mapdv2,mapiv2,1,mapdv3,mapiv3,1,mapdv4,mapiv4,           &
     &            ssc,possv40,rc)
!I.3.10 add V1(m,e,b,j) <- -1.0d0 . V4(m,e,b,j)
       call add (wrk,wrksize,                                           &
     & 4,4,0,0,0,0,1,1,-1.0d0,mapdv4,1,mapdv1,mapiv1,1,rc)
!I.3.11 get V2(e,f,m,n) <- <ef||mn>abab
       call filemanager (2,lunabij3,rc)
       call getmediate (wrk,wrksize,                                    &
     & lunabij3,possv20,mapdv2,mapiv2,rc)
!I.3.12 map V3(m,e,f,n) <- V2(e,f,m,n)
       call map (wrk,wrksize,                                           &
     & 4,2,3,1,4,mapdv2,mapiv2,1,mapdv3,mapiv3,possv30,posst,           &
     &           rc)
!I.3.13 get V2(b,f,j,n) <- T2o(b,f,j,n)abab
       call filemanager (2,lunt2o3,rc)
       call getmediate (wrk,wrksize,                                    &
     & lunt2o3,possv20,mapdv2,mapiv2,rc)
!I.3.14 map V4(f,n,b,j) <- V2(b,f,j,n)
       call map (wrk,wrksize,                                           &
     & 4,3,1,4,2,mapdv2,mapiv2,1,mapdv4,mapiv4,possv40,posst,           &
     &           rc)
!I.3.15 mult V2(m,e,b,j) <- V3(m,e,f,n) . V4(f,n,b,j)
       call mult (wrk,wrksize,                                          &
     & 4,4,4,2,mapdv3,mapiv3,1,mapdv4,mapiv4,1,mapdv2,mapiv2,           &
     &            ssc,possv20,rc)
!I.3.16 add V1(m,e,b,j) <- 0.5d0 . V2(m,e,b,j)
       call add (wrk,wrksize,                                           &
     & 4,4,0,0,0,0,1,1,0.5d0,mapdv2,1,mapdv1,mapiv1,1,rc)
!
!I.4  R1(a,i,b,j)aaaa <= sum(m,e-aa) [ T2o(a,e,i,m)aaaa . WIII(m,e,b,j)aaaa ]
!     T2n(ab,ij)aaaa   <= {1(a,i,b,j)-R1(b,i,a,j)-R1(a,j,b,i)+R1(b,j,a,i)}aaaa
!I.4.1get V2(ae,im) <- T2o(ae,im)aaaa
       call filemanager (2,lunt2o1,rc)
       call getmediate (wrk,wrksize,                                    &
     & lunt2o1,possv20,mapdv2,mapiv2,rc)
!I.4.2expand V3(a,e,i,m) <- V2(ae,im)
       call expand (wrk,wrksize,                                        &
     & 4,4,mapdv2,mapiv2,1,possv30,mapdv3,mapiv3,rc)
!I.4.3map V2(a,i,m,e) <- V3(a,e,i,m)
       call map (wrk,wrksize,                                           &
     & 4,1,4,2,3,mapdv3,mapiv3,1,mapdv2,mapiv2,possv20,posst,           &
     &           rc)
!I.4.4mult V4(a,i,b,j) <- V2(a,i,m,e) . V1(m,e,b,j)
       call mult (wrk,wrksize,                                          &
     & 4,4,4,2,mapdv2,mapiv2,1,mapdv1,mapiv1,1,mapdv4,mapiv4,           &
     &            ssc,possv40,rc)
!I.4.5map V3(a,b,i,j) <- V4(a,i,b,j)
       call map (wrk,wrksize,                                           &
     & 4,1,3,2,4,mapdv4,mapiv4,1,mapdv3,mapiv3,possv30,posst,           &
     &           rc)
!I.4.6pack V3(ab,ij) <- V2(ab,i,j) <- V3(a,b,i,j)
       call fack (wrk,wrksize,                                          &
     & 4,1,mapdv3,1,mapiv3,mapdv2,mapiv2,possv20,rc)
       call fack (wrk,wrksize,                                          &
     & 4,4,mapdv2,1,mapiv2,mapdv3,mapiv3,possv30,rc)
!I.4.7add T2n(ab,ij)aaaa <- 1.0d0 V3(ab,ij)
       call add (wrk,wrksize,                                           &
     & 4,4,0,0,0,0,1,1,1.0d0,mapdv3,1,mapdt21,mapit21,1,rc)
!
!I.5  T2n(a,b,i,j)abab <- sum(m,e-aa) [ T2o(e,b,m,j)abab . WIII(m,e,a,i)aaaa ]
!I.5.1get V4(e,b,m,j) <- T2o(e,b,m,j)abab
       call filemanager (2,lunt2o3,rc)
       call getmediate (wrk,wrksize,                                    &
     & lunt2o3,possv40,mapdv4,mapiv4,rc)
!I.5.2map V2(b,j,m,e) <- V4(e,b,m,j)
       call map (wrk,wrksize,                                           &
     & 4,4,1,3,2,mapdv4,mapiv4,1,mapdv2,mapiv2,possv20,posst,           &
     &           rc)
!I.5.3mult V4(b,j,a,i) <- V2(b,j,m,e) . V1(m,e,a,i)
       call mult (wrk,wrksize,                                          &
     & 4,4,4,2,mapdv2,mapiv2,1,mapdv1,mapiv1,1,mapdv4,mapiv4,           &
     &            ssc,possv40,rc)
!I.5.4map V3(a,b,i,j) <- V4(b,j,a,i)
       call map (wrk,wrksize,                                           &
     & 4,2,4,1,3,mapdv4,mapiv4,1,mapdv3,mapiv3,possv30,posst,           &
     &           rc)
!I.5.5add T2n(a,b,i,j)abab <- 1.0d0 . V3(a,b,i,j)
       call add (wrk,wrksize,                                           &
     & 4,4,0,0,0,0,1,1,1.0d0,mapdv3,1,mapdt23,mapit23,1,rc)
!parend
       end if
!
!
!     J part W3bbaa
!
!     par
      if (myRank.eq.idbbaa) then
!
!J.1  get V1(m,e,a,j) <- W3bbaa(m,e,a,j)
       call getw3 (wrk,wrksize,                                         &
     & lunw3bbaa,6)
!
!J.2  WIII(m,e,b,j)bbaa <- -sum(n-a) [ <je||nm>abab . T1o(n,b)aa ]
!J.2.1map V3(m,e,j,n) <- <j,e||n,m>abab
       call map (wrk,wrksize,                                           &
     & 4,3,2,4,1,mapdw13,mapiw13,1,mapdv3,mapiv3,possv30,               &
     &           posst,rc)
!J.2.2mult V4(m,e,j,b) <- V3(m,e,j,n) . M1(n,b)
       call mult (wrk,wrksize,                                          &
     & 4,2,4,1,mapdv3,mapiv3,1,mapdm1,mapim1,1,mapdv4,mapiv4,           &
     &            ssc,possv40,rc)
!J.2.3map V3(m,e,b,j) <- V4(m,e,j,b)
       call map (wrk,wrksize,                                           &
     & 4,1,2,4,3,mapdv4,mapiv4,1,mapdv3,mapiv3,possv30,posst,           &
     &           rc)
!J.2.4add V1(m,e,b,j) <- -1.0d0 V3(m,e,b,j)
       call add (wrk,wrksize,                                           &
     & 4,4,0,0,0,0,1,1,-1.0d0,mapdv3,1,mapdv1,mapiv1,1,rc)
!
!J.2  WIII(m,e,b,j)bbaa <- 0.5 sum(n,f-bb)  [ T2o(b,f,j,n)abab . <ef||mn>bbbb ]
!     <- - sum(n,f-aa)    [ Q(f,b,j,n)aaaa   . <fe||nm>abab ]
!J.2.1get V2(f,n,b,j) from lunqaaaa (produced in I step) and close it
       call filemanager (2,lunqaaaa,rc)
       call getmediate (wrk,wrksize,                                    &
     & lunqaaaa,possv20,mapdv2,mapiv2,rc)
       call filemanager (3,lunqaaaa,rc)
!J.2.2get V3(f,e,n,m) <- <fe||nm>abab
       call filemanager (2,lunabij3,rc)
       call getmediate (wrk,wrksize,                                    &
     & lunabij3,possv30,mapdv3,mapiv3,rc)
!J.2.3map V4(m,e,f,n) <- V3(f,e,n,m)
       call map (wrk,wrksize,                                           &
     & 4,3,2,4,1,mapdv3,mapiv3,1,mapdv4,mapiv4,possv40,posst,           &
     &           rc)
!J.2.4mult V3(m,e,b,j) <- V4(m,e,f,n) . V2(f,n,b,j)
       call mult (wrk,wrksize,                                          &
     & 4,4,4,2,mapdv4,mapiv4,1,mapdv2,mapiv2,1,mapdv3,mapiv3,           &
     &            ssc,possv30,rc)
!J.2.5add V1(m,e,b,j) <- -1.0d0 . V3(m,e,b,j)
       call add (wrk,wrksize,                                           &
     & 4,4,0,0,0,0,1,1,-1.0d0,mapdv3,1,mapdv1,mapiv1,1,rc)
!J.2.6get V2(b,f,j,n) <- T2o(b,f,j,n)abab
       call filemanager (2,lunt2o3,rc)
       call getmediate (wrk,wrksize,                                    &
     & lunt2o3,possv20,mapdv2,mapiv2,rc)
!J.2.7map V3(f,n,b,j) <- V2(b,f,j,n)
       call map (wrk,wrksize,                                           &
     & 4,3,1,4,2,mapdv2,mapiv2,1,mapdv3,mapiv3,possv30,posst,           &
     &           rc)
!J.3.8get V2(ef,mn) = <ef||mn>bbbb from lunb file
       call filemanager (2,lunabij2,rc)
       call getmediate (wrk,wrksize,                                    &
     & lunabij2,possv20,mapdv2,mapiv2,rc)
!J.3.9exp V4(e,f,m,n) <- V2(ef,mn)
       call expand (wrk,wrksize,                                        &
     & 4,4,mapdv2,mapiv2,1,possv40,mapdv4,mapiv4,rc)
!J.3.10        map V2(m,e,f,n) <- V4(e,f,m,n)
       call map (wrk,wrksize,                                           &
     & 4,2,3,1,4,mapdv4,mapiv4,1,mapdv2,mapiv2,possv20,posst,           &
     &           rc)
!J.3.11 mult V4(m,e,b,j) <- V2(m,e,f,n) . V3(f,n,b,j)
       call mult (wrk,wrksize,                                          &
     & 4,4,4,2,mapdv2,mapiv2,1,mapdv3,mapiv3,1,mapdv4,mapiv4,           &
     &            ssc,possv40,rc)
!J.3.12        add V1(m,e,b,j) <- 0.5d0 . V4(m,e,b,j)
       call add (wrk,wrksize,                                           &
     & 4,4,0,0,0,0,1,1,0.5d0,mapdv4,1,mapdv1,mapiv1,1,rc)
!
!J.4  R1(a,i,b,j)aaaa <= sum(m,e-bb) [ T2o(a,e,i,m)abab . WIII(m,e,b,j)bbaa ]
!     T2n(ab,ij)aaaa   <= {1(a,i,b,j)-R1(b,i,a,j)-R1(a,j,b,i)+R1(b,j,a,i)}aaaa
!J.4.1get V3(a,e,i,m) <- T2o(a,e,i,m)abab
       call filemanager (2,lunt2o3,rc)
       call getmediate (wrk,wrksize,                                    &
     & lunt2o3,possv30,mapdv3,mapiv3,rc)
!J.4.2map V2(a,i,m,e) <- V3(a,e,i,m)
       call map (wrk,wrksize,                                           &
     & 4,1,4,2,3,mapdv3,mapiv3,1,mapdv2,mapiv2,possv20,posst,           &
     &           rc)
!J.4.3mult V4(a,i,b,j) <- V2(a,i,m,e) . V1(m,e,b,j)
       call mult (wrk,wrksize,                                          &
     & 4,4,4,2,mapdv2,mapiv2,1,mapdv1,mapiv1,1,mapdv4,mapiv4,           &
     &            ssc,possv40,rc)
!J.4.4map V3(a,b,i,j) <- V4(a,i,b,j)
       call map (wrk,wrksize,                                           &
     & 4,1,3,2,4,mapdv4,mapiv4,1,mapdv3,mapiv3,possv30,posst,           &
     &           rc)
!J.4.5pack V3(ab,ij) <- V2(ab,i,j) <- V3(a,b,i,j)
       call fack (wrk,wrksize,                                          &
     & 4,1,mapdv3,1,mapiv3,mapdv2,mapiv2,possv20,rc)
       call fack (wrk,wrksize,                                          &
     & 4,4,mapdv2,1,mapiv2,mapdv3,mapiv3,possv30,rc)
!J.4.6add T2n(ab,ij)aaaa <- 1.0d0 V2(ab,ij)
       call add (wrk,wrksize,                                           &
     & 4,4,0,0,0,0,1,1,1.0d0,mapdv3,1,mapdt21,mapit21,1,rc)
!
!J.5  T2n(a,b,i,j)abab <- sum(m,e-aa) [ T2o(b,e,j,m)bbbb . WIII(m,e,a,i)bbaa ]
!J.5.1get V4(be,jm) <- T2o(be,jm)bbbb
       call filemanager (2,lunt2o2,rc)
       call getmediate (wrk,wrksize,                                    &
     & lunt2o2,possv40,mapdv4,mapiv4,rc)
!J.5.2expand V3(b,e,j,m) <-  V4(be,jm)
       call expand (wrk,wrksize,                                        &
     & 4,4,mapdv4,mapiv4,1,possv30,mapdv3,mapiv3,rc)
!J.5.2map V2(b,j,m,e) <- V3(b,e,j,m)
       call map (wrk,wrksize,                                           &
     & 4,1,4,2,3,mapdv3,mapiv3,1,mapdv2,mapiv2,possv20,posst,           &
     &           rc)
!J.5.3mult V3(b,j,a,i) <- V2(b,j,m,e) . V1(m,e,a,i)
       call mult (wrk,wrksize,                                          &
     & 4,4,4,2,mapdv2,mapiv2,1,mapdv1,mapiv1,1,mapdv3,mapiv3,           &
     &            ssc,possv30,rc)
!J.5.4map V2(a,b,i,j) <- V3(b,j,a,i)
       call map (wrk,wrksize,                                           &
     & 4,2,4,1,3,mapdv3,mapiv3,1,mapdv2,mapiv2,possv20,posst,           &
     &           rc)
!J.5.5add T2n(a,b,i,j)abab <- 1.0d0 . V2(a,b,i,j)
       call add (wrk,wrksize,                                           &
     & 4,4,0,0,0,0,1,1,1.0d0,mapdv2,1,mapdt23,mapit23,1,rc)
!parend
       end if
!
!
!     part K - W3bbbb
!par  all contributions are calculated for idbbbb only,
!     just Qbbbb is calculated both on idbbbb and idaabb
!
!par
      if (myRank.eq.idbbbb) then
!
!K.1  get V1(m,e,a,j) <- W3bbbb(m,e,a,j)
       call getw3 (wrk,wrksize,                                         &
     & lunw3bbbb,2)
!
!K.2  WIII(m,e,b,j)bbbb <- sum(n-b) [ <mn||je>bbbb . T1o(n,b)bb ]
!K.2.1expand V2(j,e,m,n) <- <je||mn>bbbb
       call expand (wrk,wrksize,                                        &
     & 4,3,mapdw12,mapiw12,1,possv20,mapdv2,mapiv2,rc)
!K.2.2map V3(m,e,j,n) <- V2(j,e,m,n)
       call map (wrk,wrksize,                                           &
     & 4,3,2,1,4,mapdv2,mapiv2,1,mapdv3,mapiv3,possv30,posst,           &
     &           rc)
!K.2.3mult V2(m,e,j,b) <- V3(m,e,j,n) . M2(n,b)
       call mult (wrk,wrksize,                                          &
     & 4,2,4,1,mapdv3,mapiv3,1,mapdm2,mapim2,1,mapdv2,mapiv2,           &
     &            ssc,possv20,rc)
!K.2.4map V3(m,e,b,j) <- V2(m,e,j,b)
       call map (wrk,wrksize,                                           &
     & 4,1,2,4,3,mapdv2,mapiv2,1,mapdv3,mapiv3,possv30,posst,           &
     &           rc)
!K.2.5add V1(m,e,b,j) <- 1.0d0 . V3(m,e,b,j)
       call add (wrk,wrksize,                                           &
     & 4,4,0,0,0,0,1,1,1.0d0,mapdv3,1,mapdv1,mapiv1,1,rc)
!parend
        end if
!
!K.3  WIII4
!     Q(f,b,j,n)bbbb   <= 0.5 T2o(f,b,j,n)bbbb + T1o(f,j)bb . T1o(b,n)bb
!     WIII(m,e,b,j)bbbb <- -sum(n,f-bb)     [ Q(f,b,j,n)bbbb   . <ef||mn>bbbb ]
!     <- 0.5 sum(n,f-aa)  [ T2o(f,b,n,j)abab . <fe||nm>abab ]
!
!par
        if ((myRank.eq.idbbbb).or.(myRank.eq.idaabb)) then
!K.3.1get V3(fb,jn) <- T2o(fb,jn)bbbb
       call filemanager (2,lunt2o2,rc)
       call getmediate (wrk,wrksize,                                    &
     & lunt2o2,possv30,mapdv3,mapiv3,rc)
!K.3.2expand V2(f,b,j,n) <- V3(fb,jn)
       call expand (wrk,wrksize,                                        &
     & 4,4,mapdv3,mapiv3,1,possv20,mapdv2,mapiv2,rc)
!K.3.3mkQ V2(f,b,j,n) <- 0.5 V2(f,b,j,n) + T1o(f,j)bb . T1o(b,n)bb
       call mkq(wrk,wrksize,                                            &
     & mapdv2,mapiv2,mapdt12,mapit12,mapdt12,mapit12,0.5d0,rc)
!K.3.4map V3(f,n,b,j) <- V2(f,b,j,n)
       call map (wrk,wrksize,                                           &
     & 4,1,3,4,2,mapdv2,mapiv2,1,mapdv3,mapiv3,possv30,posst,           &
     &           rc)
!parend
        end if
!par
        if (myRank.eq.idaabb) then
!K.3.5write V3(f,n,b,j) to lunqbbbb
       call filemanager (1,lunqbbbb,rc)
       call wrtmediate (wrk,wrksize,                                    &
     & lunqbbbb,mapdv3,mapiv3,rc)
        end if
!par
        if (myRank.eq.idbbbb) then
!K.3.6get V2(ef,mn) = <ef||mn>bbbb from luna file
       call filemanager (2,lunabij2,rc)
       call getmediate (wrk,wrksize,                                    &
     & lunabij2,possv20,mapdv2,mapiv2,rc)
!K.3.7expand V4(e,f,m,n) <- V2(ef,mn)
       call expand (wrk,wrksize,                                        &
     & 4,4,mapdv2,mapiv2,1,possv40,mapdv4,mapiv4,rc)
!K.3.8map V2(m,e,f,n) <- V4(e,f,m,n)
       call map (wrk,wrksize,                                           &
     & 4,2,3,1,4,mapdv4,mapiv4,1,mapdv2,mapiv2,possv20,posst,           &
     &           rc)
!K.3.9mult V4(m,e,b,j) <- V2(m,e,f,n) . V3(f,n,b,j)
       call mult (wrk,wrksize,                                          &
     & 4,4,4,2,mapdv2,mapiv2,1,mapdv3,mapiv3,1,mapdv4,mapiv4,           &
     &            ssc,possv40,rc)
!K.3.10 add V1(m,e,b,j) <- -1.0d0 . V4(m,e,b,j)
       call add (wrk,wrksize,                                           &
     & 4,4,0,0,0,0,1,1,-1.0d0,mapdv4,1,mapdv1,mapiv1,1,rc)
!K.3.11 get V2(f,e,n,m) <- <fe||nm>abab
       call filemanager (2,lunabij3,rc)
       call getmediate (wrk,wrksize,                                    &
     & lunabij3,possv20,mapdv2,mapiv2,rc)
!K.3.12 map V3(m,e,f,n) <- V2(f,e,n,m)
       call map (wrk,wrksize,                                           &
     & 4,3,2,4,1,mapdv2,mapiv2,1,mapdv3,mapiv3,possv30,posst,           &
     &           rc)
!K.3.13 get V2(f,b,n,j) <- T2o(f,b,n,j)abab
       call filemanager (2,lunt2o3,rc)
       call getmediate (wrk,wrksize,                                    &
     & lunt2o3,possv20,mapdv2,mapiv2,rc)
!K.3.14 map V4(f,n,b,j) <- V2(f,b,n,j)
       call map (wrk,wrksize,                                           &
     & 4,1,3,2,4,mapdv2,mapiv2,1,mapdv4,mapiv4,possv40,posst,           &
     &           rc)
!K.3.15 mult V2(m,e,b,j) <- V3(m,e,f,n) . V4(f,n,b,j)
       call mult (wrk,wrksize,                                          &
     & 4,4,4,2,mapdv3,mapiv3,1,mapdv4,mapiv4,1,mapdv2,mapiv2,           &
     &            ssc,possv20,rc)
!K.3.16 add V1(m,e,b,j) <- 0.5d0 . V2(m,e,b,j)
       call add (wrk,wrksize,                                           &
     & 4,4,0,0,0,0,1,1,0.5d0,mapdv2,1,mapdv1,mapiv1,1,rc)
!
!K.4  R1(a,i,b,j)bbbb <= sum(m,e-bb) [ T2o(a,e,i,m)bbbb . WIII(m,e,b,j)bbbb ]
!     T2n(ab,ij)bbbb   <= {1(a,i,b,j)-R1(b,i,a,j)-R1(a,j,b,i)+R1(b,j,a,i)}bbbb
!K.4.1get V2(ae,im) <- T2o(ae,im)bbbb
       call filemanager (2,lunt2o2,rc)
       call getmediate (wrk,wrksize,                                    &
     & lunt2o2,possv20,mapdv2,mapiv2,rc)
!K.4.2expand V3(a,e,i,m) <- V2(ae,im)
       call expand (wrk,wrksize,                                        &
     & 4,4,mapdv2,mapiv2,1,possv30,mapdv3,mapiv3,rc)
!K.4.3map V2(a,i,m,e) <- V3(a,e,i,m)
       call map (wrk,wrksize,                                           &
     & 4,1,4,2,3,mapdv3,mapiv3,1,mapdv2,mapiv2,possv20,posst,           &
     &           rc)
!K.4.4mult V4(a,i,b,j) <- V2(a,i,m,e) . V1(m,e,b,j)
       call mult (wrk,wrksize,                                          &
     & 4,4,4,2,mapdv2,mapiv2,1,mapdv1,mapiv1,1,mapdv4,mapiv4,           &
     &            ssc,possv40,rc)
!K.4.5map V3(a,b,i,j) <- V4(a,i,b,j)
       call map (wrk,wrksize,                                           &
     & 4,1,3,2,4,mapdv4,mapiv4,1,mapdv3,mapiv3,possv30,posst,           &
     &           rc)
!K.4.6pack V3(ab,ij) <- V2(ab,i,j) <- V3(a,b,i,j)
       call fack (wrk,wrksize,                                          &
     & 4,1,mapdv3,1,mapiv3,mapdv2,mapiv2,possv20,rc)
       call fack (wrk,wrksize,                                          &
     & 4,4,mapdv2,1,mapiv2,mapdv3,mapiv3,possv30,rc)
!K.4.7add T2n(ab,ij)bbbb <- 1.0d0 V3(ab,ij)
       call add (wrk,wrksize,                                           &
     & 4,4,0,0,0,0,1,1,1.0d0,mapdv3,1,mapdt22,mapit22,1,rc)
!
!
!K.5  T2n(a,b,i,j)abab <- sum(m,e-bb) [ T2o(a,e,i,m)abab . WIII(m,e,b,j)bbbb ]
!K.5.1get V4(a,e,i,m) <- T2o(a,e,i,m)abab
       call filemanager (2,lunt2o3,rc)
       call getmediate (wrk,wrksize,                                    &
     & lunt2o3,possv40,mapdv4,mapiv4,rc)
!K.5.2map V2(a,i,m,e) <- V4(a,e,i,m)
       call map (wrk,wrksize,                                           &
     & 4,1,4,2,3,mapdv4,mapiv4,1,mapdv2,mapiv2,possv20,posst,           &
     &           rc)
!K.5.3mult V4(a,i,b,j) <- V2(a,i,m,e) . V1(m,e,b,j)
       call mult (wrk,wrksize,                                          &
     & 4,4,4,2,mapdv2,mapiv2,1,mapdv1,mapiv1,1,mapdv4,mapiv4,           &
     &            ssc,possv40,rc)
!K.5.4map V3(a,b,i,j) <- V4(a,i,b,j)
       call map (wrk,wrksize,                                           &
     & 4,1,3,2,4,mapdv4,mapiv4,1,mapdv3,mapiv3,possv30,posst,           &
     &           rc)
!K.5.5add T2n(a,b,i,j)abab <- 1.0d0 . V3(a,b,i,j)
       call add (wrk,wrksize,                                           &
     & 4,4,0,0,0,0,1,1,1.0d0,mapdv3,1,mapdt23,mapit23,1,rc)
!parend
       end if
!
!
!     L part W3aabb
!
!par
      if (myRank.eq.idaabb) then
!
!L.1  get V1(m,e,a,j) <- W3aabb(m,e,a,j)
       call getw3 (wrk,wrksize,                                         &
     & lunw3aabb,3)
!
!L.2  WIII(m,e,b,j)aabb <- sum(n-b) [ <mn||je>abba . T1o(n,b)bb ]
!L.2.1map V3(m,e,j,n) <- <j,e||m,n>baab
       call map (wrk,wrksize,                                           &
     & 4,3,2,1,4,mapdw14,mapiw14,1,mapdv3,mapiv3,possv30,               &
     &           posst,rc)
!L.2.2mult V4(m,e,j,b) <- V3(m,e,j,n) . M2(n,b)
       call mult (wrk,wrksize,                                          &
     & 4,2,4,1,mapdv3,mapiv3,1,mapdm2,mapim2,1,mapdv4,mapiv4,           &
     &            ssc,possv40,rc)
!L.2.3map V3(m,e,b,j) <- V4(m,e,j,b)
       call map (wrk,wrksize,                                           &
     & 4,1,2,4,3,mapdv4,mapiv4,1,mapdv3,mapiv3,possv30,posst,           &
     &           rc)
!L.2.4add V1(m,e,b,j) <- 1.0d0 V3(m,e,b,j)
       call add (wrk,wrksize,                                           &
     & 4,4,0,0,0,0,1,1,1.0d0,mapdv3,1,mapdv1,mapiv1,1,rc)
!
!L.2  WIII(m,e,b,j)aabb <- 0.5 sum(n,f-aa)  [ T2o(f,b,n,j)abab . <ef||mn>aaaa ]
!     <- - sum(n,f-bb)    [ Q(f,b,j,n)bbbb   . <ef||mn>abab ]
!L.2.1get V2(f,n,b,j) from lunqbbbb (produced in K step) and close it
       call filemanager (2,lunqbbbb,rc)
       call getmediate (wrk,wrksize,                                    &
     & lunqbbbb,possv20,mapdv2,mapiv2,rc)
       call filemanager (3,lunqbbbb,rc)
!L.2.2get V3(e,f,m,n) <- <ef||mn>abab
       call filemanager (2,lunabij3,rc)
       call getmediate (wrk,wrksize,                                    &
     & lunabij3,possv30,mapdv3,mapiv3,rc)
!L.2.3map V4(m,e,f,n) <- V3(e,f,m,n)
       call map (wrk,wrksize,                                           &
     & 4,2,3,1,4,mapdv3,mapiv3,1,mapdv4,mapiv4,possv40,posst,           &
     &           rc)
!L.2.4mult V3(m,e,b,j) <- V4(m,e,f,n) . V2(f,n,b,j)
       call mult (wrk,wrksize,                                          &
     & 4,4,4,2,mapdv4,mapiv4,1,mapdv2,mapiv2,1,mapdv3,mapiv3,           &
     &            ssc,possv30,rc)
!L.2.5add V1(m,e,b,j) <- -1.0d0 . V3(m,e,b,j)
       call add (wrk,wrksize,                                           &
     & 4,4,0,0,0,0,1,1,-1.0d0,mapdv3,1,mapdv1,mapiv1,1,rc)
!L.2.6get V2(f,b,n,j) <- T2o(f,b,n,j)abab
       call filemanager (2,lunt2o3,rc)
       call getmediate (wrk,wrksize,                                    &
     & lunt2o3,possv20,mapdv2,mapiv2,rc)
!L.2.7map V3(f,n,b,j) <- V2(f,b,n,j)
       call map (wrk,wrksize,                                           &
     & 4,1,3,2,4,mapdv2,mapiv2,1,mapdv3,mapiv3,possv30,posst,           &
     &           rc)
!L.3.8get V2(ef,mn) = <ef||mn>aaaa from lunb file
       call filemanager (2,lunabij1,rc)
       call getmediate (wrk,wrksize,                                    &
     & lunabij1,possv20,mapdv2,mapiv2,rc)
!L.3.9exp V4(e,f,m,n) <- V2(ef,mn)
       call expand (wrk,wrksize,                                        &
     & 4,4,mapdv2,mapiv2,1,possv40,mapdv4,mapiv4,rc)
!L.3.10        map V2(m,e,f,n) <- V4(e,f,m,n)
       call map (wrk,wrksize,                                           &
     & 4,2,3,1,4,mapdv4,mapiv4,1,mapdv2,mapiv2,possv20,posst,           &
     &           rc)
!L.3.11 mult V4(m,e,b,j) <- V2(m,e,f,n) . V3(f,n,b,j)
       call mult (wrk,wrksize,                                          &
     & 4,4,4,2,mapdv2,mapiv2,1,mapdv3,mapiv3,1,mapdv4,mapiv4,           &
     &            ssc,possv40,rc)
!L.3.12        add V1(m,e,b,j) <- 0.5d0 . V4(m,e,b,j)
       call add (wrk,wrksize,                                           &
     & 4,4,0,0,0,0,1,1,0.5d0,mapdv4,1,mapdv1,mapiv1,1,rc)
!
!L.4  R1(a,i,b,j)bbbb <- sum(m,e-aa) [ T2o(e,a,m,i)abab . WIII(m,e,b,j)aabb ]
!     T2n(ab,ij)bbbb   <= {1(a,i,b,j)-R1(b,i,a,j)-R1(a,j,b,i)+R1(b,j,a,i)}bbbb
!L.4.1get V3(e,a,m,i) <- T2o(e,a,m,i)abab
       call filemanager (2,lunt2o3,rc)
       call getmediate (wrk,wrksize,                                    &
     & lunt2o3,possv30,mapdv3,mapiv3,rc)
!L.4.2map V2(a,i,m,e) <- V3(e,a,m,i)
       call map (wrk,wrksize,                                           &
     & 4,4,1,3,2,mapdv3,mapiv3,1,mapdv2,mapiv2,possv20,posst,           &
     &           rc)
!L.4.3mult V4(a,i,b,j) <- V2(a,i,m,e) . V1(m,e,b,j)
       call mult (wrk,wrksize,                                          &
     & 4,4,4,2,mapdv2,mapiv2,1,mapdv1,mapiv1,1,mapdv4,mapiv4,           &
     &            ssc,possv40,rc)
!L.4.4map V3(a,b,i,j) <- V4(a,i,b,j)
       call map (wrk,wrksize,                                           &
     & 4,1,3,2,4,mapdv4,mapiv4,1,mapdv3,mapiv3,possv30,posst,           &
     &           rc)
!L.4.5pack V3(ab,ij) <- V2(ab,i,j) <- V3(a,b,i,j)
       call fack (wrk,wrksize,                                          &
     & 4,1,mapdv3,1,mapiv3,mapdv2,mapiv2,possv20,rc)
       call fack (wrk,wrksize,                                          &
     & 4,4,mapdv2,1,mapiv2,mapdv3,mapiv3,possv30,rc)
!L.4.6add T2n(ab,ij)aaaa <- 1.0d0 V2(ab,ij)
       call add (wrk,wrksize,                                           &
     & 4,4,0,0,0,0,1,1,1.0d0,mapdv3,1,mapdt22,mapit22,1,rc)
!
!L.5  T2n(a,b,i,j)abab <- sum(m,e-aa) [ T2o(a,e,i,m)aaaa . WIII(m,e,b,j)aabb ]
!L.5.1get V4(ae,im) <- T2o(ae,im)aaaa
       call filemanager (2,lunt2o1,rc)
       call getmediate (wrk,wrksize,                                    &
     & lunt2o1,possv40,mapdv4,mapiv4,rc)
!L.5.2expand V3(a,e,i,m) <-  V4(ae,im)
       call expand (wrk,wrksize,                                        &
     & 4,4,mapdv4,mapiv4,1,possv30,mapdv3,mapiv3,rc)
!L.5.2map V2(a,i,m,e) <- V3(a,e,i,m)
       call map (wrk,wrksize,                                           &
     & 4,1,4,2,3,mapdv3,mapiv3,1,mapdv2,mapiv2,possv20,posst,           &
     &           rc)
!L.5.3mult V3(a,i,b,j) <- V2(a,i,m,e) . V1(m,e,b,j)
       call mult (wrk,wrksize,                                          &
     & 4,4,4,2,mapdv2,mapiv2,1,mapdv1,mapiv1,1,mapdv3,mapiv3,           &
     &            ssc,possv30,rc)
!L.5.4map V2(a,b,i,j) <- V3(a,i,b,j)
       call map (wrk,wrksize,                                           &
     & 4,1,3,2,4,mapdv3,mapiv3,1,mapdv2,mapiv2,possv20,posst,           &
     &           rc)
!L.5.5add T2n(a,b,i,j)abab <- 1.0d0 . V2(a,b,i,j)
       call add (wrk,wrksize,                                           &
     & 4,4,0,0,0,0,1,1,1.0d0,mapdv2,1,mapdt23,mapit23,1,rc)
!parend
       end if
!
!
!     M part W3abba
!
!par
      if (myRank.eq.idabba) then
!
!M.1  get V1(m,e,a,j) <- W3abba
       call getw3 (wrk,wrksize,                                         &
     & lunw3abba,4)
!
!M.2  WIII(m,e,b,j)abba <- sum(n-b) [ <mn||je>abab . T1o(n,b)bb ]
!M.2.1map V3(m,e,j,n) <- <j,e||m,n>abab
       call map (wrk,wrksize,                                           &
     & 4,3,2,1,4,mapdw13,mapiw13,1,mapdv3,mapiv3,possv30,               &
     &           posst,rc)
!M.2.2mult V4(m,e,j,b) <- V3(m,e,j,n) . M2(n,b)
       call mult (wrk,wrksize,                                          &
     & 4,2,4,1,mapdv3,mapiv3,1,mapdm2,mapim2,1,mapdv4,mapiv4,           &
     &            ssc,possv40,rc)
!M.2.3map V3(m,e,b,j) <- V4(m,e,j,b)
       call map (wrk,wrksize,                                           &
     & 4,1,2,4,3,mapdv4,mapiv4,1,mapdv3,mapiv3,possv30,posst,           &
     &           rc)
!M.2.4add V1(m,e,b,j) <- 1.0d0 V3(m,e,b,j)
       call add (wrk,wrksize,                                           &
     & 4,4,0,0,0,0,1,1,1.0d0,mapdv3,1,mapdv1,mapiv1,1,rc)
!
!M.3  Q(f,b,j,n)abab   <= 0.5 T2o(f,b,j,n)abab + T1o(f,j)aa . T1o(b,n)bb
!     WIII(m,e,b,j)abba <- sum(n,f-ba)      [ Q(f,b,j,n)abab   . <fe||mn>abab ]
!M.3.1get V4(f,b,j,n) <- T2o(f,b,j,n)abab
       call filemanager (2,lunt2o3,rc)
       call getmediate (wrk,wrksize,                                    &
     & lunt2o3,possv40,mapdv4,mapiv4,rc)
!M.3.2mkQ V4(f,b,j,n) <- 0.5 V4(f,b,j,n) + T1o(f,j)aa . T1o(b,n)bb
       call mkq(wrk,wrksize,                                            &
     & mapdv4,mapiv4,mapdt11,mapit11,mapdt12,mapit12,0.5d0,rc)
!M.3.3map V3(f,n,b,j) <- V4(f,b,j,n)
       call map (wrk,wrksize,                                           &
     & 4,1,3,4,2,mapdv4,mapiv4,1,mapdv3,mapiv3,possv30,posst,           &
     &           rc)
!M.3.4get V2(f,e,m,n) <- <fe||mn>abab
       call filemanager (2,lunabij3,rc)
       call getmediate (wrk,wrksize,                                    &
     & lunabij3,possv20,mapdv2,mapiv2,rc)
!M.3.5map V4(m,e,f,n) <- V2(f,e,m,n)
       call map (wrk,wrksize,                                           &
     & 4,3,2,1,4,mapdv2,mapiv2,1,mapdv4,mapiv4,possv40,posst,           &
     &           rc)
!M.3.6mult V2(m,e,b,j) <- V4(m,e,f,n) . V3(f,n,b,j)
       call mult (wrk,wrksize,                                          &
     & 4,4,4,2,mapdv4,mapiv4,1,mapdv3,mapiv3,1,mapdv2,mapiv2,           &
     &            ssc,possv20,rc)
!M.3.7add V1(m,e,b,j) <- 1.0d0 V2(m,e,b,j)
       call add (wrk,wrksize,                                           &
     & 4,4,0,0,0,0,1,1,1.0d0,mapdv2,1,mapdv1,mapiv1,1,rc)
!
!M.4  T2n(a,b,i,j)abab <- sum(m,e-ab) [ T2o(a,e,m,j)abab . WIII(m,e,b,i)abba ]
!M.4.1get V2(a,e,m,j) <- T2o(a,e,m,j)abab
       call filemanager (2,lunt2o3,rc)
       call getmediate (wrk,wrksize,                                    &
     & lunt2o3,possv20,mapdv2,mapiv2,rc)
!M.4.2map V3(a,j,m,e) <- V2(a,e,m,j)
       call map (wrk,wrksize,                                           &
     & 4,1,4,3,2,mapdv2,mapiv2,1,mapdv3,mapiv3,possv30,posst,           &
     &           rc)
!M.4.3mult V4(a,j,b,i) <- V3(a,j,m,e) . V1(m,e,b,i)
       call mult (wrk,wrksize,                                          &
     & 4,4,4,2,mapdv3,mapiv3,1,mapdv1,mapiv1,1,mapdv4,mapiv4,           &
     &            ssc,possv40,rc)
!M.4.4map V3(a,b,i,j) <- V4(a,j,b,i)
       call map (wrk,wrksize,                                           &
     & 4,1,4,2,3,mapdv4,mapiv4,1,mapdv3,mapiv3,possv30,posst,           &
     &           rc)
!M.4.5add T2n(a,b,i,j)abab <- 1.0d0 V3(a,b,i,j)
       call add (wrk,wrksize,                                           &
     & 4,4,0,0,0,0,1,1,1.0d0,mapdv3,1,mapdt23,mapit23,1,rc)
!parend
       end if
!
!
!     N part W3baab
!
!par
      if (myRank.eq.idbaab) then
!
!N.1  get V1(m,e,a,j) <- W3baab
       call getw3 (wrk,wrksize,                                         &
     & lunw3baab,5)
!
!N.2  WIII(m,e,b,j)baab <- - sum(n-a) [ <je||nm>baab . T1o(n,b)aa ]
!N.2.1map V3(m,e,j,n) <- <j,e||n,m>baab
       call map (wrk,wrksize,                                           &
     & 4,3,2,4,1,mapdw14,mapiw14,1,mapdv3,mapiv3,possv30,               &
     &           posst,rc)
!N.2.2mult V4(m,e,j,b) <- V3(m,e,j,n) . M1(n,b)
       call mult (wrk,wrksize,                                          &
     & 4,2,4,1,mapdv3,mapiv3,1,mapdm1,mapim1,1,mapdv4,mapiv4,           &
     &            ssc,possv40,rc)
!N.2.3map V3(m,e,b,j) <- V4(m,e,j,b)
       call map (wrk,wrksize,                                           &
     & 4,1,2,4,3,mapdv4,mapiv4,1,mapdv3,mapiv3,possv30,posst,           &
     &           rc)
!N.2.4add V1(m,e,b,j) <- -1.0d0 V3(m,e,b,j)
       call add (wrk,wrksize,                                           &
     & 4,4,0,0,0,0,1,1,-1.0d0,mapdv3,1,mapdv1,mapiv1,1,rc)
!
!N.3  Q(b,f,n,j)abab   <= 0.5 T2o(b,f,n,j)abab + T1o(b,n)aa . T1o(f,j)bb
!     WIII(m,e,b,j)baab <- sum(n,f-ab)      [ Q(b,f,n,j)abab   . <ef||nm>abab ]
!N.3.1get V4(b,f,n,j) <- T2o(b,f,n,j)abab
       call filemanager (2,lunt2o3,rc)
       call getmediate (wrk,wrksize,                                    &
     & lunt2o3,possv40,mapdv4,mapiv4,rc)
!N.3.2mkQ V4(b,f,n,j) <- 0.5 V4(b,f,n,j) + T1o(b,n)aa . T1o(f,j)bb
       call mkq(wrk,wrksize,                                            &
     & mapdv4,mapiv4,mapdt11,mapit11,mapdt12,mapit12,0.5d0,rc)
!N.3.3map V3(f,n,b,j) <- V4(b,f,n,j)
       call map (wrk,wrksize,                                           &
     & 4,3,1,2,4,mapdv4,mapiv4,1,mapdv3,mapiv3,possv30,posst,           &
     &           rc)
!N.3.4get V2(e,f,n,m) <- <ef||nm>abab
       call filemanager (2,lunabij3,rc)
       call getmediate (wrk,wrksize,                                    &
     & lunabij3,possv20,mapdv2,mapiv2,rc)
!N.3.5map V4(m,e,f,n) <- V2(e,f,n,m)
       call map (wrk,wrksize,                                           &
     & 4,2,3,4,1,mapdv2,mapiv2,1,mapdv4,mapiv4,possv40,posst,           &
     &           rc)
!N.3.6mult V2(m,e,b,j) <- V4(m,e,f,n) . V3(f,n,b,j)
       call mult (wrk,wrksize,                                          &
     & 4,4,4,2,mapdv4,mapiv4,1,mapdv3,mapiv3,1,mapdv2,mapiv2,           &
     &            ssc,possv20,rc)
!N.3.7add V1(m,e,b,j) <- 1.0d0 V2(m,e,b,j)
       call add (wrk,wrksize,                                           &
     & 4,4,0,0,0,0,1,1,1.0d0,mapdv2,1,mapdv1,mapiv1,1,rc)
!
!N.4  T2n(a,b,i,j)abab <- sum(m,e-ab) [ T2o(e,b,i,m)abab . WIII(m,e,a,j)baab ]
!N.4.1get V2(e,b,i,m) <- T2o(e,b,i,m)abab
       call filemanager (2,lunt2o3,rc)
       call getmediate (wrk,wrksize,                                    &
     & lunt2o3,possv20,mapdv2,mapiv2,rc)
!N.4.2map V3(b,i,m,e) <- V2(e,b,i,m)
       call map (wrk,wrksize,                                           &
     & 4,4,1,2,3,mapdv2,mapiv2,1,mapdv3,mapiv3,possv30,posst,           &
     &           rc)
!N.4.3mult V4(b,i,a,j) <- V3(b,i,m,e) . V1(m,e,a,j)
       call mult (wrk,wrksize,                                          &
     & 4,4,4,2,mapdv3,mapiv3,1,mapdv1,mapiv1,1,mapdv4,mapiv4,           &
     &            ssc,possv40,rc)
!N.4.4map V3(a,b,i,j) <- V4(b,i,a,j)
       call map (wrk,wrksize,                                           &
     & 4,2,3,1,4,mapdv4,mapiv4,1,mapdv3,mapiv3,possv30,posst,           &
     &           rc)
!N.4.5add T2n(a,b,i,j)abab <- 1.0d0 V3(a,b,i,j)
       call add (wrk,wrksize,                                           &
     & 4,4,0,0,0,0,1,1,1.0d0,mapdv3,1,mapdt23,mapit23,1,rc)
!parend
       end if
!
       return
       end
