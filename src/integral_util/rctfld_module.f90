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
!***********************************************************************
!                                                                      *
!-----Data for reaction field calculations.                            *
!                                                                      *
!     lMax: highest angular momentum for multipole expansion           *
!     Eps  : dielectric constant                                       *
!     EpsInf: refraction index                                         *
!     rds: radius of cavity                                            *
!     latato: Gitter type                                              *
!     polsi: site polarizability                                       *
!     dipsi: site dipole moment                                        *
!     radlat: maximum extension of the lattice                         *
!     scala,scalb,scalc: lengths of the cell dimensions                *
!     scaaa: overall scaling                                           *
!     gatom: atoms in the lattice.                                     *
!     diedel: controlls deletion of gitter polarizabilities            *
!     tK: Boltzman factor                                              *
!     clim: convergence threshold for solver                           *
!     afac: controlls equation solver (valid values 0.1-0.97)          *
!     nexpo: exponent of the potential with which the QM system kills  *
!            the gitter polatizabilities                               *
!     prefac: scaling of the polarization energies                     *
!     fmax: the square of the largest field in any grid point          *
!                                                                      *
!     PCM: whether to use the PCM solvent model                        *
!     Conductor: whether to use the Conductor-PCM model                *
!     Solvent: the name of the solvent we are using                    *
!             (allowed solvents in datasol.f)                          *
!     ISlPar: 100 integers to pass quickly PCM information             *
!            (defaulted and explained in pcmdef.f)                     *
!     RSlPar: 100 reals to pass quickly PCM information                *
!            (defaulted and explained in pcmdef.f)                     *
!     MxA: maximum number of atoms for the building of PCM cavity      *
!     NSinit: initial number of atomic spheres                         *
!     NS: actual number of spheres (initial+smoothing)                 *
!     nTs: number of surface tesserae                                  *
!     NOrdInp: number of atom where explicit spheres are centered      *
!     RadInp: radius of spheres explicitly given in the input          *
!                                                                      *
!***********************************************************************
Module Rctfld_Module
      integer, parameter :: MxPar=100,MxA=1000
      integer lRFStrt, lRFEnd
      logical lRF, lLangevin, RF_Basis, PCM, Conductor, NonEq_ref,      &
     &        DoDeriv,lRFCav,LSparse,LGridAverage,lDamping,lAmberPol,   &
     &        Done_Lattice,lFirstIter,lDiprestart
      common /lRct/ lRFStrt,                                            &
     &              lRF, lLangevin, RF_Basis, PCM, Conductor, NonEq_ref,&
     &              DoDeriv,lRFCav,LSparse,LGridAverage,lDamping,       &
     &              lAmberPol,                                          &
     &              Done_Lattice,lFirstIter,lDiprestart,                &
     &              lRFEnd
      integer :: lMax, nMM, latato, nexpo, maxa, maxb, maxc,            &
     &              iRFStrt, nabc, nCavxyz,                             &
     &              nGrid, nGrid_Eff,nSparse,                           &
     &              ISlPar(MxPar),NSinit,NS,nTs,NTT(MxA),NOrdInp(MxA),  &
     &              nPCM_Info,iCharge_ref,nGridAverage,nGridSeed,       &
     &              iRFEnd
      common /iRct/ iRFStrt,                                            &
     &              lMax, nMM, latato, nexpo, maxa, maxb, maxc,         &
     &              nabc, nCavxyz, nGrid, nGrid_Eff,nSparse,            &
     &              ISlPar,NSinit,NS,nTs,NTT,NOrdInp,                   &
     &              nPCM_Info,iCharge_ref,nGridAverage,nGridSeed,       &
     &              iRFEnd
      real(kind=8) :: Cordsi(3,4), rRfStrt,                             &
     &              EpsInf_User,                                        &
     &              Eps_User,rds, polsi, dipsi, radlat,                 &
     &              scala, scalb, scalc, scaaa, gatom, diedel, tK,      &
     &              rotAlpha, rotBeta, rotGamma,distSparse,             &
     &              clim, afac, prefac, tk5, fmax,rsca,                 &
     &              Eps,EpsInf,DerEps,RSolv,VMol,TCE,GCav,GDis,GRep,    &
     &              RDiff(MxA),KT(MxA),RWT(MxA),RadInp(MxA),            &
     &              RSlPar(MxPar),dampIter,dipCutoff,                   &
     &              scal14, rRFEnd

      common /rRct/ rRFStrt,                                            &
     &              EpsInf_User,                                        &
     &              Eps_User,rds, Cordsi, polsi, dipsi, radlat,         &
     &              scala, scalb, scalc, scaaa, gatom, diedel, tK,      &
     &              rotAlpha, rotBeta, rotGamma,distSparse,             &
     &              clim, afac, prefac, tk5, fmax,rsca,                 &
     &              Eps,EpsInf,DerEps,RSolv,VMol,TCE,GCav,GDis,GRep,    &
     &              RDiff,KT,RWT,RadInp,                                &
     &              RSlPar,dampIter,dipCutoff,                          &
     &              scal14,                                             &
     &              rRFEnd


      character(LEN=32) :: Solvent
      integer :: cRFStrt, cRFEnd
      common /cRct/ cRFStrt,                                            &
     &              Solvent,                                            &
     &              cRFEnd

      real(kind=8), allocatable :: MM(:,:)
End Module Rctfld_Module
