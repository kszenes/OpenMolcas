************************************************************************
* This file is part of OpenMolcas.                                     *
*                                                                      *
* OpenMolcas is free software; you can redistribute it and/or modify   *
* it under the terms of the GNU Lesser General Public License, v. 2.1. *
* OpenMolcas is distributed in the hope that it will be useful, but it *
* is provided "as is" and without any express or implied warranties.   *
* For more details see the full text of the license in the file        *
* LICENSE or in <http://www.gnu.org/licenses/>.                        *
************************************************************************
       subroutine deflength (mapd,length)
c
c     this routine defines length of mediate, described by mapd
c
       integer mapd(0:512,1:6)
       integer length
c
c     help variable
c
       integer ii
c
       ii=mapd(0,5)
       length=mapd(ii,1)+mapd(ii,2)-mapd(1,1)
c
       return
       end
