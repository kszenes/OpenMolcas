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
! Copyright (C) 1993, Kurt Pfingst                                     *
!***********************************************************************
!#define _DEBUGPRINT_
      SubRoutine Radlq(Zeta,nZeta,lsum,Rnr,icop)
!***********************************************************************
!                                                                      *
! Object: to compute the radial part of the continuum Coulomb          *
!         integrals outside the R-matrix sphere                        *
!                                                                      *
! Called from: KneInt                                                  *
!                                                                      *
! Author: K.Pfingst 21/5/93                                            *
!***********************************************************************
      use fx, only: f_interface
      use rmat, only: ExpSum, l, EpsAbs, EpsRel, RMatR
      Implicit None
      Integer nZeta, lSum, icop
      Real*8 Zeta(nZeta), Rnr(nZeta,0:lsum)

      Integer, Parameter :: limit=200, lenw=4*limit
      procedure(f_interface) :: fradf
      Integer iScrt(limit)
      Real*8 Scrt(lenw)
      Integer ir, iZeta, ier, nEval, Last
      Real*8 Result, AbsEr
#ifdef _DEBUGPRINT_
      Character(LEN=80) Label
#endif
!
      Call Untested('Radlq')
!                                                                      *
!***********************************************************************
!                                                                      *
      Do ir=0,lsum
         Do iZeta=1,nZeta
            expsum=Zeta(iZeta)
            ier=0
            l=ir-icop
            Call dqagi(fradf,Rmatr,1,Epsabs,Epsrel,result,abser,neval,
     &                 ier,
     &                 limit,lenw,last,iScrt,Scrt)
            If (ier.gt.0) Then
               Call WarningMessage(1,
     &         ' WARNING in Radlq; Consult output for details!')
               write(6,*) ' ier=',ier,
     &                    ' Error in Dqagi called from Radlq.'
               write(6,*) ' result=',result
               write(6,*) ' abser =',abser
               write(6,*) ' neval =',neval
               write(6,*) ' WARNING in Radlq'
            End If
            Rnr(iZeta,ir)=result
         End Do
      End Do
!                                                                      *
!***********************************************************************
!                                                                      *
#ifdef _DEBUGPRINT_
      Write (6,*) ' Result in Radlq'
      Write (Label,'(A)') ' Rnr'
      Call RecPrt(Label,' ',Rnr(1,0),nZeta,lsum+1)
#endif
!
      End SubRoutine Radlq
