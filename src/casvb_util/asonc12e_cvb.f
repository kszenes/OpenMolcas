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
      subroutine asonc12e_cvb(c,axc,sxc,nvec,nprm)
!  Applies S and H on c vector(s).
      implicit real*8 (a-h,o-z)
#include "main_cvb.fh"
#include "optze_cvb.fh"
#include "files_cvb.fh"
#include "print_cvb.fh"

#include "WrkSpc.fh"
      dimension c(nprm,nvec),axc(nprm,nvec),sxc(nprm,nvec)

      i1 = mstackr_cvb(nvb+nprorb)
      call asonc12e2_cvb(c,axc,sxc,nvec,nprm,                           &
     &  work(lc(3)),work(lc(4)),work(lc(2)),                            &
     &  work(lv(1)),work(lw(4)),work(lw(5)),work(lw(6)),work(lw(9)),    &
     &  work(lv(2)),                                                    &
     &  work(i1))
      call mfreer_cvb(i1)
      return
      end
