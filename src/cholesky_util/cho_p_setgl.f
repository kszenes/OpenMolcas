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
      SubRoutine Cho_P_SetGL(ip_Diag)
C
C     Purpose: set global and local index arrays and diagonal. On entry,
C              ip_Diag points to the global diagonal. On exit, it has
C              been reset to point to the local one, allocated and
C              defined in this routine.
C
      use ChoSwp, only: nnBstRSh, nnBstRSh_G, nnBstRsh_L_Hidden
      use ChoSwp, only: iiBstRSh, iiBstRSh_G, iiBstRsh_L_Hidden
      use ChoSwp, only: IndRSh, IndRSh_G, IndRsh_G_Hidden
      Implicit None
      Integer ip_Diag
#include "cholesky.fh"
#include "choptr.fh"
#include "choptr2.fh"
#include "choglob.fh"
#include "cho_para_info.fh"
#include "WrkSpc.fh"
#include "stdalloc.fh"

      Character*11 SecNam
      Parameter (SecNam = 'Cho_P_SetGL')

      Integer N, iSP, iSym, iShlAB, i1, i2, irc
      Integer l_LDiag

      Integer i, j
      Integer mySP, iL2G
      Integer IndRed_G

      iL2G(i)=iWork(ip_iL2G-1+i)
      mySP(i)=iWork(ip_mySP-1+i)
      IndRed_G(i,j)=iWork(ip_IndRed_G-1+mmBstRT_G*(j-1)+i)

C     If not parallel, return.
C     ------------------------

      If (.not.Cho_Real_Par) Return

C     Set global data (choglob.fh).
C     ------------------------------

      ip_Diag_G = ip_Diag
      l_Diag_G = mmBstRT

      nnShl_G = nnShl
      mmBstRT_G = mmBstRT

      N = 8*3
      Call iCopy(N,iiBstR,1,iiBstR_G,1)
      Call iCopy(N,nnBstR,1,nnBstR_G,1)
      Call iCopy(3,nnBstRT,1,nnBstRT_G,1)

      ip_InfRed_G = ip_InfRed
      l_InfRed_G = l_InfRed

      ip_InfVec_G = ip_InfVec
      l_InfVec_G = l_InfVec

      iiBstRSh_G => iiBstRSh

      nnBstRSh_G => nnBstRSh

      ip_IndRed_G = ip_IndRed
      l_IndRed_G = l_IndRed

      IndRSh_G => IndRSh

C     Reallocate and reset local data.
C     --------------------------------

      Call GetMem('LInfRed','Allo','Inte',ip_InfRed,l_InfRed)
      Call GetMem('LInfVec','Allo','Inte',ip_InfVec,l_InfVec)

      nnShl = n_mySP
      Call mma_allocate(iiBstRsh_L_Hidden,nSym,n_mySP,3,
     &                  Label='iiBstRSh_L_Hidden')
      iiBstRSh => iiBstRSh_L_Hidden
      Call mma_allocate(nnBstRsh_L_Hidden,nSym,n_mySP,3,
     &                  Label='nnBstRSh_L_Hidden')
      nnBstRSh => nnBstRSh_L_Hidden

      Do iSP = 1,nnShl
         iShlAB = mySP(iSP)
         Do iSym = 1,nSym
            nnBstRSh(iSym,iSP,1) = nnBstRSh_G(iSym,iShlAB,1)
         End Do
      End Do
      Call Cho_SetRedInd(iiBstRSh,nnBstRSh,nSym,nnShl,1)
      mmBstRT = nnBstRT(1)

      l_IndRed = mmBstRT*3
      l_iL2G = mmBstRT
      Call GetMem('LIndRed','Allo','Inte',ip_IndRed,l_IndRed)
      Call mma_allocate(IndRSh_G_Hidden,mmBstRT,
     &                  Label='IndRSh_G_Hidden')
      IndRSh => IndRSh_G_Hidden
      Call GetMem('iL2G','Allo','Inte',ip_iL2G,l_iL2G)

      N = 0
      Do iSym = 1,nSym
         Do iSP = 1,nnShl
            iShlAB = mySP(iSP)
            i1 = iiBstR_G(iSym,1) + iiBstRSh_G(iSym,iShlAB,1) + 1
            i2 = i1 + nnBstRSh_G(iSym,iShlAB,1) - 1
            Do i = i1,i2
               iWork(ip_IndRed+N) = IndRed_G(i,1)
               IndRSh(N+1) = IndRSh_G(i)
               iWork(ip_iL2G+N) = i
               N = N + 1
            End Do
         End Do
      End Do
      Call Cho_X_RSCopy(irc,1,2)
      If (irc .ne. 0) Then
         Write(Lupri,*) SecNam,': [1] Cho_X_RSCopy returned ',irc
         Call Cho_Quit('Error in '//SecNam,104)
      End If
      Call Cho_X_RSCopy(irc,2,3)
      If (irc .ne. 0) Then
         Write(Lupri,*) SecNam,': [2] Cho_X_RSCopy returned ',irc
         Call Cho_Quit('Error in '//SecNam,104)
      End If

C     Allocate and set local diagonal.
C     --------------------------------

      l_LDiag = mmBstRT
      Call GetMem('LDiag','Allo','Real',ip_Diag,l_LDiag)
      Do i = 1,mmBstRT
         Work(ip_Diag-1+i) = Work(ip_Diag_G-1+iL2G(i))
      End Do

      End
