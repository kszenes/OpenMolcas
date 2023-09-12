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
      subroutine vb2cic_cvb(cvbdet,civec)
!  *********************************************************************
!  *                                                                   *
!  *  VB2CI[CFG] := VB to CASSCF transformation.                       *
!  *  CI2VB[CFG] := CASSCF to VB transformation.                       *
!  *  VB2CIAF    := Adds first-order term in CVBDET to CAS CI vector.  *
!  *                                                                   *
!  *  Transformation between VB vector and CASSCF vector (both defined *
!  *  in determinant basis).                                           *
!  *                                                                   *
!  *  Normally a simple indexed copy of the coefficients is all that   *
!  *  is required. For direct-product wavefunctions, however, a        *
!  *  partial contraction is also carried out (relevant for first-     *
!  *  order changes and gradient back transformation).                 *
!  *                                                                   *
!  *  [C] : Transforms coefficients.                                   *
!  *  [F] : Transforms a first-order change of the coefficients.       *
!  *  [G] : Transforms a gradient-type quantity.                       *
!  *                                                                   *
!  *********************************************************************
      implicit real*8 (a-h,o-z)
#include "main_cvb.fh"
#include "optze_cvb.fh"
#include "files_cvb.fh"
#include "print_cvb.fh"

#include "frag_cvb.fh"
#include "WrkSpc.fh"
      dimension cvbdet(ndetvb),civec(*)

      icivec=nint(civec(1))
      ic=0

      if(iform_ci(icivec).ne.0)then
        write(6,*)' Unsupported format in VB2CI :',iform_ci(icivec)
        call abend_cvb()
      endif
      if(nfrag.le.1)then
        call ci2vb2_cvb(work(iaddr_ci(icivec)),cvbdet,                  &
     &    iwork(ll(11)),iwork(ll(12)),dum,1)
      else
        call dpci2vb_cvb(work(iaddr_ci(icivec)),cvbdet,work(lv(5)),ic,  &
     &                   dum,1)
      endif
      call setcnt2_cvb(icivec,0)
      return
      end

      subroutine vb2cif_cvb(cvbdet,civec)
      implicit real*8 (a-h,o-z)
#include "main_cvb.fh"
#include "optze_cvb.fh"
#include "files_cvb.fh"
#include "print_cvb.fh"

#include "frag_cvb.fh"
#include "WrkSpc.fh"
      dimension cvbdet(ndetvb),civec(*)

      icivec=nint(civec(1))
      ic=1

      if(iform_ci(icivec).ne.0)then
        write(6,*)' Unsupported format in VB2CI :',iform_ci(icivec)
        call abend_cvb()
      endif
      if(nfrag.le.1)then
        call ci2vb2_cvb(work(iaddr_ci(icivec)),cvbdet,                  &
     &    iwork(ll(11)),iwork(ll(12)),dum,1)
      else
        call dpci2vb_cvb(work(iaddr_ci(icivec)),cvbdet,work(lv(5)),ic,  &
     &                   dum,1)
      endif
      call setcnt2_cvb(icivec,0)
      return
      end


      subroutine ci2vbc_cvb(civec,cvbdet)
      implicit real*8 (a-h,o-z)
#include "main_cvb.fh"
#include "optze_cvb.fh"
#include "files_cvb.fh"
#include "print_cvb.fh"

#include "frag_cvb.fh"
#include "WrkSpc.fh"
      dimension cvbdet(ndetvb),civec(*)
      icivec=nint(civec(1))
      ic=0

      if(iform_ci(icivec).ne.0)then
        write(6,*)' Unsupported format in CI2VB :',iform_ci(icivec)
        call abend_cvb()
      endif
      if(nfrag.le.1)then
        call ci2vb2_cvb(work(iaddr_ci(icivec)),cvbdet,                  &
     &    iwork(ll(11)),iwork(ll(12)),dum,0)
      else
        call dpci2vb_cvb(work(iaddr_ci(icivec)),cvbdet,work(lv(5)),ic,  &
     &                   dum,0)
      endif
      return
      end



      subroutine ci2vbg_cvb(civec,cvbdet)
      implicit real*8 (a-h,o-z)
#include "main_cvb.fh"
#include "optze_cvb.fh"
#include "files_cvb.fh"
#include "print_cvb.fh"

#include "frag_cvb.fh"
#include "WrkSpc.fh"
      dimension cvbdet(ndetvb),civec(*)
      icivec=nint(civec(1))
      ic=2

      if(iform_ci(icivec).ne.0)then
        write(6,*)' Unsupported format in CI2VB :',iform_ci(icivec)
        call abend_cvb()
      endif
      if(nfrag.le.1)then
        call ci2vb2_cvb(work(iaddr_ci(icivec)),cvbdet,                  &
     &    iwork(ll(11)),iwork(ll(12)),dum,0)
      else
        call dpci2vb_cvb(work(iaddr_ci(icivec)),cvbdet,work(lv(5)),ic,  &
     &                   dum,0)
      endif
      return
      end

      subroutine vb2ciaf_cvb(cvbdet,civec)
      implicit real*8 (a-h,o-z)
#include "main_cvb.fh"
#include "optze_cvb.fh"
#include "files_cvb.fh"
#include "print_cvb.fh"

#include "frag_cvb.fh"
#include "WrkSpc.fh"
      dimension cvbdet(ndetvb),civec(*)
      icivec=nint(civec(1))
      if(iform_ci(icivec).ne.0)then
        write(6,*)' Unsupported format in VB2CIP :',iform_ci(icivec)
        call abend_cvb()
      endif
      if(nfrag.le.1)then
        call ci2vb2_cvb(work(iaddr_ci(icivec)),cvbdet,                  &
     &    iwork(ll(11)),iwork(ll(12)),dum,2)
      else
        call dpci2vb_cvb(work(iaddr_ci(icivec)),cvbdet,work(lv(5)),1,   &
     &                   dum,2)
      endif
      call setcnt2_cvb(icivec,0)
      return
      end
