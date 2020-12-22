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
      Subroutine Mk_Hss_Q()
      use Slapaf_Info, only: Cx, Coor, DipM, qInt, dqInt, BMx, mRowH
      use Slapaf_Parameters, only: BSet, HSet, Delta, lNmHss
      Implicit Real*8 (a-h,o-z)
#include "info_slapaf.fh"
#include "real.fh"
*
*     Compute the Hessian in internal coordinates.
*
*#define _DEBUGPRINT_
#ifdef _DEBUGPRINT_
      Call RecPrt('Mk_Hss_Q: DipM',' ',DipM,SIZE(DipM,1),SIZE(DipM,2))
#endif
      If ((lNmHss.or.Allocated(mRowH)).and.iter.eq.NmIter) Then
         Call Put_dArray('Unique Coordinates',Cx,3*nsAtom)
         Call Put_Coord_New(Cx,nsAtom)
         If (Allocated(mRowH)) Then
            If (BSet.and.HSet) Call Hss_Q()
            Call RowHessian(NmIter,mInt,Delta/2.5d0)
         Else
            Call FormNumHess(iter,mInt,Delta,Stop,nsAtom,iNeg,DipM)
         End If
*
         call dcopy_(3*nsAtom,Cx,1,Coor,1)
         Call Get_dArray('BMxOld',BMx,3*nsAtom*mInt)
         call dcopy_(mInt, qInt(:,1),1, qInt(:,Iter),1)
         call dcopy_(mInt,dqInt(:,1),1,dqInt(:,Iter),1)
      Else
         If (BSet.and.HSet) Call Hss_Q()
      End If
*                                                                      *
************************************************************************
*                                                                      *
      Return
      End
