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
       subroutine saamphlp3                                             &
     & (t1aa,t1bb,t2abab,noa,nob,nva,nvb,noas,nvbs,key)
!
!     this routine rearrange amplitudes to be spin adapted
!     for T1 amplitudes for given si(=sa)
!
!     t1aa - T1aa amplitudes for given si (=sa) (I/O)
!     t1bb - T1bb amplitudes for given si (=sa) (I/O)
!     t2abab - T2(arsi)abab amplitudes sa=si (sr=ss=irrep of S) (I/O)
!     noa  - number of alpha occupied in symi (I)
!     nob  - number of beta occupied in symi (I)
!     nva  - number of alpha virtuals in symi (I)
!     nvb  - number of beta virtuals in symi (I)
!     noas - number of alpha occupied in symmetry, where S orbitals is (I)
!     nvbs - number of beta virtuals in symmetry, where S orbitals is (I)
!     key  - 0 - no adaptation (I)
!     1 - T2 DDVV adaptation
!     2 - T2 DDVV + T1 DV adaptation
!     3 - full T1 and T2 adaptation (only for doublets)
!     4 - full T2 without SDVS (only for doublets)
!
       integer noa,nob,nva,nvb,nvbs,noas
!T1
       real*8 t1aa(1:nva,1:noa)
       real*8 t1bb(1:nvb,1:nob)
!T2
       real*8 t2abab(1:nva,1:nvbs,1:noas,1:nob)
!
       integer key
!
!     help variables
!
       integer nd,nv,ns
       integer i,a
       real*8 t1,t2
!
       if (key.eq.0) return
!
       nd=nob
       ns=noa-nob
       nv=nva
!
!     T1 adaption
!
!     ta=t1oaa(i,a)     DV
!     tb=t1obb(i,a)     DV
!     tc=t2o2b(p,i,a,p) SDVS
!
!     direct :
!     t1= (ta+tb)/2
!     t2= (-ta+tb+2tc)/6
!
!     reverse :
!     ta= t1-t2
!     tb= t1+t2
!     tc= 2t2
!
       if (key.eq.3) then
!
       do 10 i=1,nd
       do 11 a=1,nv
!
       t1=(t1aa(a,i)+t1bb(a+ns,i))/2.0d0
       t2=(t1bb(a+ns,i)-t1aa(a,i)+2.0d0*t2abab(a,1,noas,i))/6.0d0
!
       t1aa(a,i)=t1-t2
       t1bb(a+ns,i)=t1+t2
       t2abab(a,1,noas,i)=2.0d0*t2
!
 11     continue
 10     continue
!
       else if (key.eq.2) then
!
       do 40 i=1,nd
       do 41 a=1,nv
!
       t1=(t1aa(a,i)+t1bb(a+ns,i))/2.0d0
!
       t1aa(a,i)=t1
       t1bb(a+ns,i)=t1
!
 41     continue
 40     continue
!
!     else if (key.eq.1) then
!     no adaption in T1 turn on
       end if
!
!
       return
       end
