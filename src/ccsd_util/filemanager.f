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
       subroutine filemanager (request,lun,rc)
!
!     request - specification of service (Input)
!     1 - open temporary file and give lun (minfiles-maxfiles)
!     2 - rewind file lun
!     3 - close file lun (and delete it if it is temporrary one)
!     4 - open file with given lun (used for fixed files 10-minfiles)
!     5 - close without deleting (for any file)
!     lun     - Logical unit number (Input, Output)
!     rc      - return (error) code (Output)
!
!     This routine is a manager of temporarry disk files, used durring
!     the calculations.
!     if request=1 it finds free lun number if it is possible
!     and open file as unformatted
!     if request=2 it rewinds lun file if it is opened
!     if request=3 if close given lun file if it is opened
!
#include "filemgr.fh"
#include "ccsd1.fh"
!
       integer lun,request,rc
!
!     help variables
!
       integer nhelp,mhelp,ierr,idum(1)
       logical is_error
!
       rc=0
!
!
       if (request.eq.1) then
!
!I    open new file
!
!I.1  look for lowest free lun
!
       do 100 nhelp=minfiles,maxfiles
        mhelp = nhelp
        if (filestatus(nhelp).eq.0) goto 101
 100    continue
!
!I.2  RC=1 : there is not enough Temporarry files allowed
       rc=1
       return
!
!I.3  open file
!
 101    lun=mhelp
!
       if (iokey.eq.1) then
!      Fortran IO
       call molcas_open_ext2(lun,filename(lun),'sequential',            &
     &  'unformatted',                                                  &
     &      ierr,.false.,1,'unknown',is_error)
!       open (unit=lun,
!     &       file=filename(lun),
!     &       status='unknown',
!     &       form='unformatted',
!     &       iostat=ierr)
!
       else
!      MOLCAS IO
       call daname (lun,filename(lun))
       daddr(lun)=0
       end if
!
       filestatus(lun)=1
!
!
       else if (request.eq.2) then
!
!II   rewind given file
!
!II.1 test lun, if it is not too large
!
       if ((lun.lt.10).or.(lun.gt.maxfiles)) then
!     RC=2 : lun is out of range
       rc=2
       return
       end if
!
!II.2 test, if lun is opened
!
       if (filestatus(lun).ne.1) then
!     RC=3 : file with logical unit lun is not opened, it can't be rewined
       rc=3
       return
       end if
!
!II.3 rewind lun file
!
       if (iokey.eq.1) then
!      Fortran IO
       rewind (lun)
!
       else
!      MOLCAS IO
       nhelp=0
       idum(1)=nhelp
       call idafile (lun,5,idum,1,daddr(lun))
       end if
!
!
       else if (request.eq.3) then
!
!III  close given file + scratch if it is Temp
!
!III.1test lun, if it is not too large
!
       if ((lun.lt.10).or.(lun.gt.maxfiles)) then
!     RC=4 : lun is out of range
       rc=4
       return
       end if
!
!III.2test, if lun is opened
!
       if (filestatus(lun).ne.1) then
!     RC=5 : file with logical unit lun is not opened,it can't be closed
       rc=5
       return
       end if
!
!III.3 close ; scratch file, if it was a temporarry one
!
       if (iokey.eq.1) then
!      Fortran IO
         if (lun.ge.minfiles) then
!        close and scratch
         close (lun)
         call molcas_open(lun,filename(lun))
!         open (unit=lun,file=filename(lun))
         write (lun,*) ' File scratched'
         close (lun)
!        call sqname (lun,filename'lun')
!        call sqeras (lun)
         else
!        close only
         close (lun)
         end if
!
       else
!      MOLCAS IO
         if (lun.ge.minfiles) then
!        close and scratch
         call daeras (lun)
         else
!        close only
         call daclos (lun)
         end if
!
       end if
!
       filestatus(lun)=0
!
!
       else if (request.eq.4) then
!
!IV   open file with given lun
!
!
!IV.1 test lun, if it is not too large
!
       if ((lun.lt.10).or.(lun.gt.maxfiles)) then
!     RC=6 : lun is out of range
       rc=6
       return
       end if
!
!IV.2  test if file is not already opened
       if (filestatus(lun).eq.1) then
!     RC=7 : file is already opened
       rc=7
       return
       end if
!
!IV.3 open file
!
       if (iokey.eq.1) then
!      Fortran IO
       call molcas_open_ext2(lun,filename(lun),                         &
     &     'sequential','unformatted',                                  &
     &      ierr,.false.,1,'unknown',is_error)
!       open (unit=lun,
!     &       file=filename(lun),
!     &       status='unknown',
!     &       form='unformatted',
!     &       iostat=ierr)
!
       else
!      MOLCAS IO
       call daname (lun,filename(lun))
       daddr(lun)=0
       end if
!
       filestatus(lun)=1
!
       else if (request.eq.5) then
!
!V     close file with given lun (without deleting)
!
!V.1   test lun, if it is not too large
!
       if ((lun.lt.10).or.(lun.gt.maxfiles)) then
!     RC=8 : lun is out of range
       rc=8
       return
       end if
!
!V.2  test, if lun is opened
!
       if (filestatus(lun).ne.1) then
!     RC=9 : file with logical unit lun is not opened,it can't be closed
       rc=9
       return
       end if
!
!V.3  close
!
       if (iokey.eq.1) then
!      Fortran IO
       close (lun)
!
       else
!      MOLCAS IO
       call daclos (lun)
       end if
!
       filestatus(lun)=0
!
!
       else
!     RC=10 : incorect value of request
       rc=10
       return
       end if
!
       return
       end
