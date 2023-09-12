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
! Copyright (C) 1996-2006, Thorstein Thorsteinsson                     *
!               1996-2006, David L. Cooper                             *
!***********************************************************************
      subroutine symtrizorbs2_cvb(orbs,                                 &
     &  north,corth,irels,relorb,ifxorb,iorts,                          &
     &  ihlp,ihlp2,ihlp3,iprev,jprev,updi,updj)
      implicit real*8 (a-h,o-z)
#include "main_cvb.fh"
#include "optze_cvb.fh"
#include "files_cvb.fh"
#include "print_cvb.fh"

#include "formats_cvb.fh"
      dimension orbs(norb,norb)
      dimension north(norb),corth(norb,niorth)
      dimension irels(2,nijrel),relorb(norb,norb,nijrel)
      dimension ifxorb(norb),iorts(2,nort)
      dimension ihlp(norb),ihlp2(norb),ihlp3(norb)
      dimension iprev(norb),jprev(norb)
      dimension updi(norb),updj(norb)
      dimension dum(1)
      save four,hund,thresh
      data four/4d0/,hund/100d0/,thresh/1d-10/

      ioffs=1
      do 100 iorb=1,norb
      if(north(iorb).ne.0) call schmidtd_cvb(corth(1,ioffs),            &
     &  north(iorb),orbs(1,iorb),1,dum,norb,0)
      ioffs=ioffs+north(iorb)
100   continue

!  Now enforce orthogonality between specified orbitals:
!  -----------------------------------------------------
      do 290 i=1,norb
      ihlp(i)=-1
290   continue
      do 300 iort=1,nort
      do 301 j=1,2
      iorb=iorts(j,iort)
      ihlp(iorb)=min(north(iorb),norb)
301   continue
300   continue
!  Check feasibility
      do 350 irel=1,nijrel
      if(ihlp(irels(1,irel)).ne.-1)then
        write(6,'(2a,i3)')' WARNING - cannot perform orthogonalizations'&
     &    ,' involving orbital ',irels(1,irel)
        write(6,'(2a,i3)')' because this orbital is generated by',      &
     &    ' symmetry operations from orbital ',irels(2,irel)
        write(6,'(a)')' Please simplify orthogonality constraints.'
        call abend_cvb()
      endif
350   continue
!  Set up order of orthogonalization - first help arrays :
      call izero(ihlp2,norb)
      call izero(ihlp3,norb)
      nortorb=0
      do 400 icon=norb,0,-1
      do 401 iorb=1,norb
      if(ihlp(iorb).eq.icon)then
        nortorb=nortorb+1
        ihlp2(nortorb)=iorb
        ihlp3(iorb)=nortorb
      endif
401   continue
400   continue

!  Loop all pairs that may be orthogonalized
      do 450 iortorb=1,nortorb
      iorb=ihlp2(iortorb)
!  Create list of previous orthonormalisations involving IORB
      niprev=0
      do 465 iort=1,nort
      if(iorts(1,iort).eq.iorb)then
        if(ihlp3(iorts(2,iort)).lt.iortorb)then
          niprev=niprev+1
          iprev(niprev)=iorts(2,iort)
        endif
      elseif(iorts(2,iort).eq.iorb)then
        if(ihlp3(iorts(1,iort)).lt.iortorb)then
          niprev=niprev+1
          iprev(niprev)=iorts(1,iort)
        endif
      endif
465   continue
      do 451 jortorb=iortorb+1,nortorb
      jorb=ihlp2(jortorb)
!  Create list of previous orthonormalisations involving JORB
      iok=0
      njprev=0
      do 475 iort=1,nort
      if(iorts(1,iort).eq.jorb)then
        if(ihlp3(iorts(2,iort)).lt.iortorb)then
          njprev=njprev+1
          jprev(njprev)=iorts(2,iort)
        elseif(ihlp3(iorts(2,iort)).eq.iortorb)then
          iok=1
        endif
      elseif(iorts(2,iort).eq.jorb)then
        if(ihlp3(iorts(1,iort)).lt.iortorb)then
          njprev=njprev+1
          jprev(njprev)=iorts(1,iort)
        elseif(ihlp3(iorts(1,iort)).eq.iortorb)then
          iok=1
        endif
      endif
475   continue
      if(iok.eq.0)goto 451
      sovr=ddot_(norb,orbs(1,iorb),1,orbs(1,jorb),1)
      if(abs(sovr).lt.thresh)goto 490
!  Now ready to orthogonalise
!  Update vectors
      call updvec_cvb(updi,iorb,jorb,niprev,iprev,                      &
     &  orbs,north,corth)
      cnrmi=ddot_(norb,updi,1,updi,1)
      if(ifxorb(iorb).eq.1)cnrmi=zero
      call updvec_cvb(updj,jorb,iorb,njprev,jprev,                      &
     &  orbs,north,corth)
      cnrmj=ddot_(norb,updj,1,updj,1)
      if(ifxorb(jorb).eq.1)cnrmj=zero

      if(cnrmi.gt.thresh.and.cnrmj.gt.thresh)then
        faci=one/sqrt(cnrmi)
        call dscal_(norb,faci,updi,1)
        facj=one/sqrt(cnrmj)
        call dscal_(norb,facj,updj,1)
        s1=ddot_(norb,updi,1,orbs(1,jorb),1)
        s2=ddot_(norb,updj,1,orbs(1,iorb),1)
        s3=ddot_(norb,updi,1,updj,1)
!  Initialize cpp & cpm to suppress compiler warning ...
        cpp=0d0
        cpm=0d0
!  Same magnitudes of updates, either ++ or +- :
        if(abs(s3).gt.thresh)then
          a=s3
          b=s1+s2
          c=sovr
          discrpp=b*b-four*a*c
          if(discrpp.ge.zero)then
            c1=(-b+sqrt(discrpp))/(two*a)
            c2=(-b-sqrt(discrpp))/(two*a)
            if(abs(c1).lt.abs(c2))cpp=c1
            if(abs(c2).le.abs(c1))cpp=c2
          else
            cpp=hund
          endif
          a=-s3
          b=s1-s2
          discrpm=b*b-four*a*c
          if(discrpm.ge.zero)then
            c1=(-b+sqrt(discrpm))/(two*a)
            c2=(-b-sqrt(discrpm))/(two*a)
            if(abs(c1).lt.abs(c2))cpm=c1
            if(abs(c2).le.abs(c1))cpm=c2
          else
            cpm=hund
          endif
        else
          if(abs(s1+s2).gt.thresh)then
            cpp=sovr/(s1+s2)
          else
            cpp=hund
          endif
          if(abs(s1-s2).gt.thresh)then
            cpm=sovr/(s1+s2)
          else
            cpm=hund
          endif
        endif
        if(abs(cpp).lt.abs(cpm))c=cpp
        if(abs(cpm).le.abs(cpp))c=cpm
        if(c.eq.hund.or.abs(s2+c*s3).lt.thresh)then
          write(6,'(a,2i3)')' Could not orthogonalize orbitals',        &
     &      iorb,jorb
          write(6,'(a)')' Please simplify orthogonality constraints.'
          call abend_cvb()
        endif
        d=-(sovr+c*s1)/(s2+c*s3)
        call dscal_(norb,c,updi,1)
        call addvec(orbs(1,iorb),orbs(1,iorb),updi,norb)
        call dscal_(norb,d,updj,1)
        call addvec(orbs(1,jorb),orbs(1,jorb),updj,norb)
      elseif(cnrmi.gt.thresh)then
        faci=one/sqrt(cnrmi)
        call dscal_(norb,faci,updi,1)
        s1=ddot_(norb,updi,1,orbs(1,jorb),1)
        c=-sovr/s1
        call dscal_(norb,c,updi,1)
        call addvec(orbs(1,iorb),orbs(1,iorb),updi,norb)
      elseif(cnrmj.gt.thresh)then
        facj=one/sqrt(cnrmj)
        call dscal_(norb,facj,updj,1)
        s2=ddot_(norb,updj,1,orbs(1,iorb),1)
        d=-sovr/s2
        call dscal_(norb,d,updj,1)
        call addvec(orbs(1,jorb),orbs(1,jorb),updj,norb)
      else
        write(6,'(a,2i3)')' Could not orthogonalize orbitals',iorb,jorb
        write(6,'(a)')' Please simplify orthogonality constraints.'
        call abend_cvb()
      endif
490   niprev=niprev+1
      iprev(niprev)=jorb
451   continue
450   continue

      call nize_cvb(orbs,norb,dum,norb,0,0)
      smax=-one
      do 497 iort=1,nort
      iorb=iorts(1,iort)
      jorb=iorts(2,iort)
      s=abs(ddot_(norb,orbs(1,iorb),1,orbs(1,jorb),1))
      if(s.gt.smax)then
        smax=s
        iorbmax=iorb
        jorbmax=jorb
      endif
497   continue
      if(ip(3).ge.2.and.smax.gt.1d-10)then
        write(6,'(a,2i3)')                                              &
     &    ' Maximum overlap for orthogonalized orbitals :',             &
     &    iorbmax,jorbmax
        write(6,formAD)                                                 &
     &    ' Value : ',ddot_(norb,orbs(1,iorbmax),1,orbs(1,jorbmax),1)
      endif

      do 500 irel=1,nijrel
      iorb=irels(1,irel)
      jorb=irels(2,irel)
      call mxatb_cvb(relorb(1,1,irel),orbs(1,jorb),                     &
     &  norb,norb,1,orbs(1,iorb))
500   continue

      return
      end
