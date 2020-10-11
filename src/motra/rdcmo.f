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
      Subroutine RdCmo_motra(CMO,Ovlp)
************************************************************************
*                                                                      *
*     Purpose:                                                         *
*     Read molecular orbitals from input                               *
*     iVecTyp=1  : obsolete, regarded as error                         *
*     iVecTyp=2  : read from unit INPORB in the same format            *
*     iVecTyp=3  : read from an old casscf interface unit JOBIPH.      *
*                                                                      *
************************************************************************
*
      Implicit Real*8 (A-H,O-Z)
*
#include "motra_global.fh"
#include "trafo_motra.fh"
#include "files_motra.fh"
#include "SysDef.fh"
*
      Real*8 CMO(*), Ovlp(*)
      Logical okay
      Integer itemp2((LENIN8*MxOrb)/ItoB)
      Character ctemp2(LENIN8*MxOrb)
      Real*8  temp2(MxRoot)
      Dimension Dummy(1),iDummy(1)
*
*----------------------------------------------------------------------*
*     Read MO coefficients from input                                  *
*----------------------------------------------------------------------*
      If ( iVecTyp.eq.1 ) Then
        Write (6,*) 'RdCmo_motra: iVecTyp.eq.1'
        Write (6,*) 'This error means someone has put a bug into MOTRA!'
        Call Abend()
      End If
*----------------------------------------------------------------------*
*     Read MO coefficients from a formatted vector file                *
*----------------------------------------------------------------------*
      If ( iVecTyp.eq.2 ) Then
        call f_Inquire (FnInpOrb,okay)
        If ( okay ) Then
          lOcc = 0
          Call RdVec(FnInpOrb,LuInpOrb,'C',nSym,nBas,nBas,
     &          Cmo, Dummy, Dummy, iDummy,
     &          VecTit, 0, iErr)
        Else
          Write (6,*) 'RdCMO_motra: Error finding MO file'
          Call Abend()
        End If
      End If
*----------------------------------------------------------------------*
*     Read MO coefficients from JOBIPH generated by RASSCF             *
*----------------------------------------------------------------------*
      If ( iVecTyp.eq.3 ) Then
        call f_Inquire (FnJobIph,okay)
        If ( okay ) Then
          Call DaName(LuJobIph,FnJobIph)
          iDisk=0
          Call iDaFile( LuJobIph,2,TcJobIph,10,iDisk)
          iDisk=TcJobIph(1)
          Call WR_RASSCF_Info(LuJobIph,2,iDisk,
     &                        itemp2(1),itemp2(1),itemp2(1),itemp2(1),
     &                        itemp2,itemp2,itemp2,itemp2,
     &                        itemp2,mxSym,ctemp2,lenin8*mxOrb,
     &                        itemp2(1),ctemp2,144,
     &                        ctemp2,4*18*mxTit,
     &                        temp2(1),itemp2(1),itemp2(1),
     &                        itemp2,mxRoot,itemp2,itemp2,itemp2,
     &                        itemp2(1),itemp2(1),iPt2,temp2)
          iDisk=TcJobIph(2)
          if ( iPt2.ne.0 ) iDisk=TcJobIph(9)
          Call dDaFile(LuJobIph,2,Cmo,nTot2,iDisk)
          Call DaClos(LuJobIph)
          VecTit='JOBIPH'
        Else
          Write (6,*) 'RdCMO_motra: Error finding JOBIPH file'
          Call Abend()
        End If
      End If
*----------------------------------------------------------------------*
*     Normal termination                                               *
*----------------------------------------------------------------------*
      Call Ortho_Motra(nSym,nBas,nDel,Ovlp,Cmo)
      Return
      End
