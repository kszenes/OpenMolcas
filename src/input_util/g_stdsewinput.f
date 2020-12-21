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
      Subroutine StdSewInput(LuRd,ifnr,mdc,iShll,BasisTypes,
     &                       STDINP,lSTDINP,iErr)
************************************************************************
* This is a simplified copy of the BASI section of RdCtl_Seward that   *
* reads the string vector STDINP with the standard seward input        *
* generated by ZMatrixConverter.                                       *
************************************************************************
      use Basis_Info
      use Center_Info
      use Sizes_of_Seward, only: S
      use Logical_Info, only: UnNorm, Do_FckInt
      Implicit Real*8 (a-h,o-z)
*
#include "Molcas.fh"
#include "SysDef.fh"
#include "rctfld.fh"
#include "real.fh"
#include "print.fh"
#include "gateway.fh"
#include "stdalloc.fh"
c
c     IRELAE = 0  .... DKH
c            = 1  .... DK1
c            = 2  .... DK2
c            = 3  .... DK3
c            = 4  .... DK3full
c            = 11 .... RESC
c            = 21 .... ZORA
c            = 22 .... ZORA(FP)
c            = 23 .... IORA
CAWMR
c     NB: The IRELAE flag has been extended to account for
c         arbitrary-order DKH with different parametrizations!
c         IMPORTANT: new arbitrary-order DKH routines are only
c                    called for IRELAE values LARGER than 1000.
CAWMR
c
#include "relae.fh"
      Integer, Parameter:: nBuff=10000
      Real*8, Allocatable:: Buffer(:)
      Common /AMFn/ iAMFn
*
      Character Key*180, KWord*180,            BSLbl*80, Fname*256,
     &          DefNm*13, Ref(2)*80, dbas*4
      Integer BasisTypes(4)
*
      Character*180 Line, STDINP(mxAtom*2) ! CGGn
      Character*256 Basis_lib ! CGGd , INT2CHAR, CHAR4
*
CGGd      Data WellRad/-1.22D0,-3.20D0,-6.20D0/
*
#include "angstr.fh"
      Data DefNm/'basis_library'/ ! CGGd,
*                                                                      *
************************************************************************
*                                                                      *
      Interface
#include "getbs_interface.fh"
      End Interface
*                                                                      *
************************************************************************
*                                                                      *
      Call mma_allocate(Buffer,nBuff,Label='Buffer')
      iErr=0
      iRout=3
*                                                                      *
************************************************************************
*                                                                      *
      LuWr=6
*
      itype=0
*
      BasisTypes(:)=0
*                                                                      *
****** BASI ************************************************************
*                                                                      *
      iSTDINP = 2

10    nCnttp = nCnttp + 1
      If (nCnttp.gt.Mxdbsc) Then
         Write (LuWr,*) ' Increase Mxdbsc'
         iErr=1
         Return
      End If
*
*     Read the basis set label
*
      Key = STDINP(iSTDINP)
      BSLbl = Key(1:80)
*     Call UpCase(BSLbl)
      LenBSL=Len(BSLbl)
      Last=iCLast(BSLbl,LenBSL)
      Indx=Index(BSLbl,'/')
      If (Indx.eq.0) Then
       call WhichMolcas(Basis_lib)
       if(Basis_lib(1:1).ne.' ') then
         ib=index(Basis_lib,' ')-1
         if(ib.lt.1)
     *    Call SysAbendMsg('rdCtl','Too long PATH to MOLCAS',' ')
         Fname=Basis_lib(1:ib)//'/basis_library'
       else
         Fname=DefNm
       endif
       Indx = Last+1
       dbsc(nCnttp)%Bsl=BSLbl
      Else
         Fname= BSLbl(Indx+2:Last)
         If (Fname.eq.' ') Then
            Call WarningMessage(2,
     &                     ' No basis set library specified for'
     &                   //';BSLbl='//BSLbl//';Fname='//Fname)
            Call Quit_OnUserError()
         End If
 1919    If (Fname(1:1).eq.' ') Then
            Fname(1:79)=Fname(2:80)
            Fname(80:80) = ' '
            Go To 1919
         End If
         dbsc(nCnttp)%Bsl=BSLbl(1:Indx-1)
      End If
*
      n=INDEX(dbsc(nCnttp)%Bsl,' ')
      dbsc(nCnttp)%Bsl(n:n+5)='.....'
*
      If (Show.and.nPrint(2).ge.6) Then
         Write (LuWr,*)
         Write (LuWr,*)
         Write(LuWr,'(1X,A,I5,A,A)')
     &           'Basis Set ',nCnttp,' Label: ', BSLbl(1:Indx-1)
         Write(LuWr,'(1X,A,A)') 'Basis set is read from library:',
     *         Fname(1:index(Fname,' '))
      End if
*
      jShll = iShll
      dbsc(nCnttp)%Bsl_old=dbsc(nCnttp)%Bsl
      dbsc(nCnttp)%mdci=mdc
      Call GetBS(Fname,dbsc(nCnttp)%Bsl,iShll,Ref,UnNorm,
     &           LuRd,BasisTypes,STDINP,iSTDINP,.True.,.true.,' ')
*
      Do_FckInt = Do_FckInt .and. dbsc(nCnttp)%FOp
      If (itype.eq.0) Then
         If (BasisTypes(3).eq.1 .or. BasisTypes(3).eq.2)
     &       iType=BasisTypes(3)
      Else
         If (BasisTypes(3).eq.1 .or. BasisTypes(3).eq.2) Then
            If (BasisTypes(3).ne.iType) Then
               BasisTypes(3)=-1
            End If
            iType=BasisTypes(3)
         End If
      End If
      If (itype.eq.1) ifnr=1
      If (itype.eq.2) ifnr=0
*
      If (Show.and.nPrint(2).ge.6 .and.
     &   Ref(1).ne.'' .and. Ref(2).ne.'') Then
         Write (LuWr,'(1x,a)')  'Basis Set Reference(s):'
         If (Ref(1).ne.'') Write (LuWr,'(5x,a)') Ref(1)
         If (Ref(2).ne.'') Write (LuWr,'(5x,a)') Ref(2)
         Write (LuWr,*)
         Write (LuWr,*)
      End If
      dbsc(nCnttp)%ECP=(dbsc(nCnttp)%nPrj
     &                + dbsc(nCnttp)%nSRO
     &                + dbsc(nCnttp)%nSOC
     &                + dbsc(nCnttp)%nPP
     &                + dbsc(nCnttp)%nM1
     &                + dbsc(nCnttp)%nM2) .NE.0
      dbsc(nCnttp)%nShells = dbsc(nCnttp)%nVal
     &                     + dbsc(nCnttp)%nPrj
     &                     + dbsc(nCnttp)%nSRO
     &                     + dbsc(nCnttp)%nSOC
     &                     + dbsc(nCnttp)%nPP
*
      lAng=Max(dbsc(nCnttp)%nVal,
     &         dbsc(nCnttp)%nSRO,
     &         dbsc(nCnttp)%nPrj)-1
      S%iAngMx=Max(S%iAngMx,lAng)
*     No transformation needed for s and p shells
      Shells(jShll+1)%Transf=.False.
      Shells(jShll+1)%Prjct =.False.
      Shells(jShll+2)%Transf=.False.
      Shells(jShll+2)%Prjct =.False.
      nCnt = 0
      If (dbsc(nCnttp)%Aux) Then
         Do iSh = jShll+1, iShll
            Shells(iSh)%Aux=.True.
         End Do
      End If
*                                                                      *
************************************************************************
*                                                                      *
*     Here we will have to fix that the 6-31G family of basis sets
*     should by default be used with 6 d-functions rather than 5.
*
      KWord=BSLbl(1:Indx-1)
      Call UpCase(KWord)
      If (INDEX(KWord,'6-31G').ne.0) Then
         Do iSh = jShll+3, iShll
            Shells(iSh)%Transf=.False.
            Shells(iSh)%Prjct =.False.
         End Do
      End If
*                                                                      *
************************************************************************
*                                                                      *
*
100   iSTDINP = iSTDINP + 1
      Line = STDINP(iSTDINP)
      KWord = Line
      Call UpCase(KWord)
      If (KWord(1:4).eq.'END ') Then
         If (nCnt.eq.0) Then
            Call WarningMessage(2,' Input error, no center specified!')
            Call Quit_OnUserError()
         End If
         dbsc(nCnttp)%nCntr = nCnt
         call mma_allocate(dbsc(nCnttp)%Coor_Hidden,3,nCnt,
     &                     Label='dbsc:C')
         dbsc(nCnttp)%Coor => dbsc(nCnttp)%Coor_Hidden(:,:)
         Call DCopy_(3*nCnt,Buffer,1,dbsc(nCnttp)%Coor,1)
         mdc = mdc + nCnt
         Go To 900
      End If
*
*     Read Coordinates
*
      nCnt = nCnt + 1
      n_dc=max(mdc+nCnt,n_dc)
      If (mdc+nCnt.gt.MxAtom) Then
         Call WarningMessage(2,' RdCtl: Increase MxAtom')
         Write (LuWr,*) '        MxAtom=',MxAtom
         Call Quit_OnUserError()
      End If
      iend=Index(KWord,' ')
      If (iEnd.gt.LENIN+1) Then
         Write (6,*) 'Warning: the label ', KWord(1:iEnd),
     &               ' will be truncated to ',LENIN,' characters!'
      End If
      dc(mdc+nCnt)%LblCnt = KWord(1:Min(LENIN,iend-1))
      dbas=Trim(dc(mdc+nCnt)%LblCnt(1:LENIN))
      Call Upcase(dbas)
      If (dbas.eq.'DBAS') Then
         Call WarningMessage(2,' RdCtl: ZMAT does not work with DBAS')
         Call Quit_OnUserError()
      End If
      If (mdc+nCnt.gt.1)
     &   Call Chk_LblCnt(dc(mdc+nCnt)%LblCnt,mdc+nCnt-1)
      iOff=1+(nCnt-1)*3
C      print *,line
      Read (Line,*)
      Read (Line(6:),*) (Buffer(iOff+i),i=0,2) ! CGGn
      If (Index(KWord,'ANGSTROM').ne.0) Then
         Do i = 0, 2
            Buffer(iOff+i) = Buffer(iOff+i)/angstr
         End Do
      End If
*
      GoTo 100

900   iSTDINP = iSTDINP + 2
      If (iSTDINP.LT.lSTDINP) Go to 10

      If (S%iAngMx.lt.0) Then
         Write (6,*) ' There is an error somewhere in the input!'
         Write (6,*) 'S%iAngMx.lt.'
         iErr=1
         Return
      End If
      Call mma_deallocate(Buffer)
*
      Return
      End
