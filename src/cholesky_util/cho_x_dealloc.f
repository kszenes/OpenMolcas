************************************************************************
* This file is part of OpenMolcas.                                     *
*                                                                      *
* OpenMolcas is free software; you can redistribute it and/or modify   *
* it under the terms of the GNU Lesser General Public License, v. 2.1. *
* OpenMolcas is distributed in the hope that it will be useful, but it *
* is provided "as is" and without any express or implied warranties.   *
* For more details see the full text of the license in the file        *
* LICENSE or in <http://www.gnu.org/licenses/>.                        *
*                                                                      *
* Copyright (C) 2004, Thomas Bondo Pedersen                            *
************************************************************************
      Subroutine Cho_X_Dealloc(irc)
      use ChoArr, only: iSOShl, iBasSh, nBasSh, nBstSh, iSP2F, iAtomShl,
     &                  iShlSO, iRS2F, IntMap, iScr, nDimRS
      use ChoSwp, only: iQuAB, iQuAB_L, iQuAB_Hidden, iQuAB_L_Hidden,
     &                  nnBstRSh_Hidden, nnBstRSh,
     &                  nnBstRSh_L_Hidden, nnBstRSh_G,
     &                  iiBstRSh_Hidden, iiBstRSh,
     &                  iiBstRSh_L_Hidden, iiBstRSh_G,
     &                    IndRSh_Hidden,   IndRSh,
     &                    IndRSh_G_Hidden,   IndRSh_G
C
C     T.B. Pedersen, July 2004.
C
C     Purpose: deallocate ALL index arrays for the Cholesky utility.
C              On exit, irc=0 signals sucessful completion.
C
      Implicit None
      Integer irc
#include "choptr.fh"
#include "chosew.fh"
#include "cholq.fh"
#include "chopar.fh"
#include "stdalloc.fh"

      Character*13 SecNam
      Parameter (SecNam = 'Cho_X_Dealloc')

      Integer nAlloc

C     Initialize allocation counter.
C     ------------------------------

      nAlloc = 0

C     Deallocate.
C     -----------

      If (l_InfRed .ne. 0) Then
         Call GetMem('InfRed','Free','Inte',ip_InfRed,l_InfRed)
      End If
      nAlloc = nAlloc + 1

      If (l_InfVec .ne. 0) Then
         Call GetMem('InfVec','Free','Inte',ip_InfVec,l_InfVec)
      End If
      nAlloc = nAlloc + 1

      If (l_IndRed .ne. 0) Then
         Call GetMem('IndRed','Free','Inte',ip_IndRed,l_IndRed)
      End If
      nAlloc = nAlloc + 1

      If (Allocated(IndRSh_Hidden))
     &    Call mma_deallocate(IndRSh_Hidden)
      If (Associated(IndRSh)) IndRSh=>Null()

      If (Allocated(iScr)) Call mma_deallocate(iScr)

      If (Allocated(iiBstRSh_Hidden))
     &    Call mma_deallocate(iiBstRSh_Hidden)
      If (Associated(iiBstRSh)) iiBstRSh=>Null()

      If (Allocated(nnBstRSh_Hidden))
     &    Call mma_deallocate(nnBstRSh_Hidden)
      If (Associated(nnBstRSh)) nnBstRSh=>Null()

      If (Allocated(IntMap)) Call mma_deallocate(IntMap)

      If (Allocated(nDimRS)) Call mma_deallocate(nDimRS)

      If (Allocated(iRS2F)) Call mma_deallocate(iRS2F)

      If (Allocated(iSOShl)) Call mma_deallocate(iSOShl)

      If (Allocated(iShlSO)) Call mma_deallocate(iShlSO)

      If (Allocated(iQuAB_Hidden)) Call mma_deallocate(iQuAB_Hidden)
      If (Associated(iQuAB)) iQuAB => Null()

      If (Allocated(iBasSh)) Call mma_deallocate(iBasSh)

      If (Allocated(nBasSh)) Call mma_deallocate(nBasSh)

      If (Allocated(nBstSh)) Call mma_deallocate(nBstSh)

      If (Allocated(iAtomShl)) Call mma_deallocate(iAtomShl)

      If (Allocated(iSP2F)) Call mma_deallocate(iSP2F)

C     Check that #allocations agrees with choptr.fh.
C     -----------------------------------------------

      irc = CHO_NALLOC - nAlloc
      If (irc .ne. 0) Then
         Write(6,*) SecNam,' is out of sync with choptr.fh !!!'
         Write(6,*) '(Note that this is due to a programming error...)'
         Return
      End If

C     Zero entire common block.
C     -------------------------

      Call Cho_PtrIni(irc)
      If (irc .ne. 0) Then
         Write(6,*) SecNam,': Cho_PtrIni is out of sync ',
     &              'with choptr.fh !!!'
         Write(6,*) '(Note that this is due to a programming error...)'
         Return
      End If

C     Deallocate any used pointer in chosew.fh
C     -----------------------------------------

      If (l_iShP2RS .ne. 0) Then
         Call GetMem('SHP2RS','Free','Inte',ip_iShP2RS,l_iShP2RS)
         ip_iShP2RS=0
         l_iShP2RS=0
      End If

      If (l_iShP2Q .ne. 0) Then
         Call GetMem('SHP2Q','Free','Inte',ip_iShP2Q,l_iShP2Q)
         ip_iSHP2Q=0
         l_iSHP2Q=0
      End If

C     Deallocate any used pointer in cholq.fh
C     ----------------------------------------

      If (Allocated(iQuAB_L_Hidden)) Call mma_deallocate(iQuAB_L_Hidden)
      If (Associated(iQuAB_L)) iQuAB_L => Null()

      If (l_iQL2G .ne. 0) Then
         Call GetMem('IQL2G','Free','Inte',ip_iQL2G,l_iQL2G)
         ip_iQL2G=0
         l_iQL2G=0
      End If

      If (l_LQ .ne. 0) Then
         Call GetMem('LQ','Free','Real',ip_LQ,l_LQ)
         ip_LQ=0
         l_LQ=0
      End If

C     Deallocate any used pointer in chopar.fh
C     -----------------------------------------

      If (l_InfVec_Bak .gt. 0) Then
         Call GetMem('InfVec_Bak','Free','Inte',ip_InfVec_Bak,
     &                                           l_InfVec_Bak)
         l_InfVec_Bak=0
      End If

C     Deallocate any used pointer in cholq.fh
C     -----------------------------------------

      If (Allocated(IndRSh_G_Hidden))
     &    Call mma_deallocate(IndRSh_G_Hidden)
      If (Associated(IndRSh_G)) IndRSh_G=>Null()

      If (Allocated(iiBstRSh_L_Hidden))
     &    Call mma_deallocate(iiBstRSh_L_Hidden)
      If (Associated(iiBstRSh_G)) iiBstRSh_G=>Null()

      If (Allocated(nnBstRSh_L_Hidden))
     &    Call mma_deallocate(nnBstRSh_L_Hidden)
      If (Associated(nnBstRSh_G)) nnBstRSh_G=>Null()

      Return
      End
