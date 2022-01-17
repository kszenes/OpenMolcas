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
      Subroutine GenVoronoi(Coor,nR_Eff,nNQ,Alpha,rm,iNQ)
************************************************************************
*                                                                      *
*     This version of GenVoronoi computes the radial quadrature points *
*     and computes datas useful for the angular quadrature.            *
*     The angular part is generated by Subblock.                       *
*                                                                      *
************************************************************************
      use NQ_Structure, only: NQ_Data
      Implicit Real*8 (a-h,o-z)
#include "itmax.fh"
#include "nq_info.fh"
#include "real.fh"
#include "WrkSpc.fh"
      Real*8 Coor(3)
      Integer nR_Eff(nNQ)
      Real*8 Alpha(2), rm(2)
      Logical Process
      Dimension Dum(2,1)
************************************************************************
*                                                                      *
*     Statement functions                                              *
*                                                                      *
#include "nq_structure.fh"
      declare_ip_atom_nr
      declare_ip_r_quad
#ifdef _DEBUGPRINT_
      iROff(i,ir)=2*(ir-1)+i-1
#endif
*
************************************************************************
*
*define _DEBUGPRINT_
#ifdef _DEBUGPRINT_
      Write (6,*) 'nR,L_Quad=',nR,L_Quad
#endif
      If (L_Quad.gt.lMax_NQ) Then
         Call WarningMessage(2,'GenVoronoi: L_Quad.gt.lMax_NQ')
         Write (6,*) 'Redimension lMax_NQ in nq_info.fh'
         Write (6,*) 'lMax_NQ=',lMax_NQ
         Write (6,*) 'L_Quad=',L_Quad
         Call Abend()
      End If
#define _NEW_
#ifdef _NEW_
      l_Max=Int(rm(1))
      Radius_Max=Eval_RMax(Alpha(1),l_Max,rm(2))
C     Write (6,*) 'Alpha(1)=',Alpha(1)
C     Write (6,*) 'l_max=',l_max
C     Write (6,*) 'rm(2)=',rm(2)
C     Write (6,*) 'Radius_Max=',Radius_Max
C     Write (6,*)
#endif
************************************************************************
*                                                                      *
*---- Generate radial quadrature points. Observe that the integrand    *
*     vanish at (r=0.0).                                               *
*
      If (Quadrature.eq.'MHL') Then
*
         iANr=Int(Work(ip_Atom_Nr(iNQ)))
         RBS=Bragg_Slater(iANr)
         Alpha(1)=RBS
         mR=nR-1
         Call GetMem('Radial','Allo','Real',ip_Rx,2*mR)
         Call FZero(Work(ip_Rx),2*mR)
         ip_iRx=ip_of_iWork_d(Work(ip_R_Quad(iNQ)))
         iWork(ip_iRx)=ip_Rx
         Call GenRadQuad_MHL(Work(ip_Rx),nR,nR_Eff(iNQ),Alpha(1))
         Call Truncate_Grid(Work(ip_Rx),mR,nR_Eff(iNQ),Radius_Max)
         mR=nR_Eff(iNQ)
         NQ_Data(iNQ)%R_max =Work(ip_Rx-1+(mR-1)*2+1)
*
      Else If (Quadrature.eq.'LOG3') Then
*
         rm(1)=Three
*------- alpha=5 (alpha=7 for alkali and rare earth metals)
         Alpha(1)=Five
         iANr=Int(Work(ip_Atom_Nr(iNQ)))
         If (iANr.eq.3 .or.
     &       iANr.eq.4 .or.
     &       iANr.eq.11.or.
     &       iANr.eq.12.or.
     &       iANr.eq.19.or.
     &       iANr.eq.20.or.
     &       iANr.eq.37.or.
     &       iANr.eq.38.or.
     &       iANr.eq.55.or.
     &       iANr.eq.56.or.
     &       iANr.eq.87.or.
     &       iANr.eq.88    ) Alpha(1)=Seven
         mR=nR-1
         Call GetMem('Radial','Allo','Real',ip_Rx,2*mR)
         ip_iRx=ip_of_iWork_d(Work(ip_R_Quad(iNQ)))
         iWork(ip_iRx)=ip_Rx
         Call GenRadQuad_MK(Work(ip_Rx),nR,nR_Eff(iNQ),rm(1),Alpha(1),
     &                      iNQ)
         Call Truncate_Grid(Work(ip_Rx),mR,nR_Eff(iNQ),Radius_Max)
         mR=nR_Eff(iNQ)
         NQ_Data(iNQ)%R_max=Work(ip_Rx-1+(mR-1)*2+1)
*
      Else If (Quadrature.eq.'BECKE') Then
*
         iANr=Int(Work(ip_Atom_Nr(iNQ)))
         RBS=Bragg_Slater(iANr)
         If (iANr.eq.1) Then
            Alpha(1)=RBS
         Else
            Alpha(1)=Half*RBS
         End If
         mR=nR-1
         Call GetMem('Radial','Allo','Real',ip_Rx,2*mR)
         ip_iRx=ip_of_iWork_d(Work(ip_R_Quad(iNQ)))
         iWork(ip_iRx)=ip_Rx
         Call GenRadQuad_B(Work(ip_Rx),nR,nR_Eff(iNQ),Alpha(1))
         Call Truncate_Grid(Work(ip_Rx),mR,nR_Eff(iNQ),Radius_Max)
         mR=nR_Eff(iNQ)
         NQ_Data(iNQ)%R_max=Work(ip_Rx-1+(mR-1)*2+1)
*
      Else If (Quadrature.eq.'TA') Then
*
         Alpha(1)=-One
         iANr=Int(Work(ip_Atom_Nr(iNQ)))
         If (iANr.eq. 1) Then
            Alpha(1)=0.8D00
         Else If (iANr.eq. 2) Then
            Alpha(1)=0.9D00
         Else If (iANr.eq. 3) Then
            Alpha(1)=1.8D00
         Else If (iANr.eq. 4) Then
            Alpha(1)=1.4D00
         Else If (iANr.eq. 5) Then
            Alpha(1)=1.3D00
         Else If (iANr.eq. 6) Then
            Alpha(1)=1.1D00
         Else If (iANr.eq. 7) Then
            Alpha(1)=0.9D00
         Else If (iANr.eq. 8) Then
            Alpha(1)=0.9D00
         Else If (iANr.eq. 9) Then
            Alpha(1)=0.9D00
         Else If (iANr.eq.10) Then
            Alpha(1)=0.9D00
         Else If (iANr.eq.11) Then
            Alpha(1)=1.4D00
         Else If (iANr.eq.12) Then
            Alpha(1)=1.3D00
         Else If (iANr.eq.13) Then
            Alpha(1)=1.3D00
         Else If (iANr.eq.14) Then
            Alpha(1)=1.2D00
         Else If (iANr.eq.15) Then
            Alpha(1)=1.1D00
         Else If (iANr.eq.16) Then
            Alpha(1)=1.0D00
         Else If (iANr.eq.17) Then
            Alpha(1)=1.0D00
         Else If (iANr.eq.18) Then
            Alpha(1)=1.0D00
         Else If (iANr.eq.19) Then
            Alpha(1)=1.5D00
         Else If (iANr.eq.20) Then
            Alpha(1)=1.4D00
         Else If (iANr.eq.21) Then
            Alpha(1)=1.3D00
         Else If (iANr.eq.22) Then
            Alpha(1)=1.2D00
         Else If (iANr.eq.23) Then
            Alpha(1)=1.2D00
         Else If (iANr.eq.24) Then
            Alpha(1)=1.2D00
         Else If (iANr.eq.25) Then
            Alpha(1)=1.2D00
         Else If (iANr.eq.26) Then
            Alpha(1)=1.2D00
         Else If (iANr.eq.27) Then
            Alpha(1)=1.2D00
         Else If (iANr.eq.28) Then
            Alpha(1)=1.1D00
         Else If (iANr.eq.29) Then
            Alpha(1)=1.1D00
         Else If (iANr.eq.30) Then
            Alpha(1)=1.1D00
         Else If (iANr.eq.31) Then
            Alpha(1)=1.1D00
         Else If (iANr.eq.32) Then
            Alpha(1)=1.0D00
         Else If (iANr.eq.33) Then
            Alpha(1)=0.9D00
         Else If (iANr.eq.34) Then
            Alpha(1)=0.9D00
         Else If (iANr.eq.35) Then
            Alpha(1)=0.9D00
         Else If (iANr.eq.36) Then
            Alpha(1)=0.9D00
         Else
            Call WarningMessage(2,'TA grid not defined')
            Write (6,*) ' TA grid not defined for atom number:', iANR
            Call Abend()
         End If
         mR=nR-1
         Call GetMem('Radial','Allo','Real',ip_Rx,2*mR)
         ip_iRx=ip_of_iWork_d(Work(ip_R_Quad(iNQ)))
         iWork(ip_iRx)=ip_Rx
         Call GenRadQuad_TA(Work(ip_Rx),nR,nR_Eff(iNQ),Alpha(1))
         Call Truncate_Grid(Work(ip_Rx),mR,nR_Eff(iNQ),Radius_Max)
         mR=nR_Eff(iNQ)
         NQ_Data(iNQ)%R_Max=Work(ip_Rx-1+(mR-1)*2+1)
*
      Else If (Quadrature.eq.'LMG') Then
*
*                                                                      *
************************************************************************
*                                                                      *
*--------Generate radial quadrature. The first call will generate
*        the size of the grid.
*
         nR=1     ! Dummy size on the first call.
         Process=.False.
         Call GenRadQuad_PAM(iNQ,nR_Eff(iNQ),rm,Alpha(1),
     &                       Process,Dum,nR)
*
         nR=nR_Eff(iNQ)
         Call GetMem('Radial','Allo','Real',ip_Rx,2*nR)
         ip_iRx=ip_of_iWork_d(Work(ip_R_Quad(iNQ)))
         iWork(ip_iRx)=ip_Rx
         Process=.True.
         Call GenRadQuad_PAM(iNQ,nR_Eff(iNQ),rm,Alpha(1),
     &                       Process,Work(ip_Rx),nR)
         NQ_Data(iNQ)%R_max=Work(ip_Rx-1+(nR-1)*2+1)
*                                                                      *
************************************************************************
*                                                                      *
#ifdef _DEBUGPRINT_
         Write(6,*) 'GenRadQuad_PAM ----> GenVoronoi'
         Write(6,*) 'nR_Eff=',nR_Eff(iNQ)
         Write(6,*) 'rm : ',rm(1),rm(2)
         Write(6,*) 'Alpha : ',Alpha(1),Alpha(2)
#endif
      Else
         Call WarningMessage(2,
     &               'Invalid quadrature scheme:'//Quadrature)
         Call Quit_OnUserError()
      End If
*
#ifdef _DEBUGPRINT_
      Write (6,*)
      Write (6,*) ' ******** The radial grid ********'
      Write (6,*)
      Write (6,*) 'Initial number of radial grid points=',nR
      Write (6,*) 'iNQ=',iNQ
      Write (6,*) 'Effective number of radial grid points=',nR_Eff(iNQ)
      Do iR = 1, nR_Eff(iNQ)
         Write (6,*) Work(ip_Rx+iROff(1,iR)),
     &               Work(ip_Rx+iROff(2,iR))
      End Do
      Write (6,*)
      Write (6,*) ' *********************************'
      Write (6,*)
#endif
*                                                                      *
************************************************************************
*                                                                      *
      Return
c Avoid unused argument warnings
      If (.False.) Call Unused_real_array(Coor)
      End
      Subroutine Truncate_Grid(R,nR,nR_Eff,Radius_Max)
      Implicit Real*8 (a-h,o-z)
      Real*8 R(2,nR)
*
      nTmp=nR_Eff
      Do i = 1, nTmp
         If (R(1,i).gt.Radius_Max) Then
             nR_Eff=i-1
             Go To 99
         End If
      End Do
 99   Continue
*
      Return
      End
