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
* Copyright (C) 2021, Yoshio Nishimoto                                 *
************************************************************************
      Subroutine CLagX(IFF,CLag,DEPSA,VECROT)

      use caspt2_output, only:iPrGlb,verbose
      use stdalloc, only: mma_allocate, mma_deallocate
      use gugx, only: SGS
      Implicit Real*8 (A-H,O-Z)
#include "rasdim.fh"
#include "caspt2.fh"
#include "pt2_guga.fh"
#include "WrkSpc.fh"
      Integer IFF
      Real*8 CLag(nConf,nState)
      Real*8 DEPSA(nAshT,nAshT),VECROT(*)

      Real*8, Allocatable::  G1(:),  G2(:),  G3(:),
     &                       F1(:),  F2(:),  F3(:)
      Real*8, Allocatable:: DG1(:), DG2(:), DG3(:),
     &                      DF1(:), DF2(:), DF3(:)

      Integer, External:: ip_of_Work
      Integer :: nLev
      nLev=SGS%nLev

      !! reduced density matrix and fock-weighted RDM
      CALL mma_allocate(G1 ,NG1, Label='G1')
      LG1 = ip_of_Work(G1(1))
      CALL mma_allocate(G2 ,NG2, Label='G2')
      LG2 = ip_of_Work(G2(1))
      CALL mma_allocate(G3 ,NG3, Label='G3')
      LG3 = ip_of_Work(G3(1))
      CALL mma_allocate(F1 ,NG1, Label='F1')
      LF1 = ip_of_Work(F1(1))
      CALL mma_allocate(F2 ,NG2, Label='F2')
      LF2 = ip_of_Work(F2(1))
      CALL mma_allocate(F3 ,NG3, Label='F3')
      LF3 = ip_of_Work(F3(1))

      !! their derivative contributions
      CALL mma_allocate(DG1,NG1,Label='DG1')
      CALL mma_allocate(DG2,NG2,Label='DG2')
      CALL mma_allocate(DG3,NG3,Label='DG3')
      CALL mma_allocate(DF1,NG1,Label='DF1')
      CALL mma_allocate(DF2,NG2,Label='DF2')
      CALL mma_allocate(DF3,NG3,Label='DF3')

      CALL PT2_GET(NG1,' GAMMA1',G1)
      CALL PT2_GET(NG2,' GAMMA2',G2)
      CALL PT2_GET(NG3,' GAMMA3',G3)
      CALL PT2_GET(NG1,' DELTA1',F1)
      CALL PT2_GET(NG2,' DELTA2',F2)
      CALL PT2_GET(NG3,' DELTA3',F3)
C
      !! Initialize them
      DG1(:)=0.0D0
      DG2(:)=0.0D0
      DG3(:)=0.0D0
      DF1(:)=0.0D0
      DF2(:)=0.0D0
      DF3(:)=0.0D0
      !! DEASUM is the derivative cont. of EASUM
      DEASUM = 0.0D+00

      CALL TIMING(CPTF0,CPE,TIOTF0,TIOE)
      Call CLagD(G1,G2,G3,
     *           DG1,DG2,DG3,
     *           DF1,DF2,DF3,DEASUM,
     *           DEPSA,VECROT)
      CALL TIMING(CPTF10,CPE,TIOTF10,TIOE)
      IF (IPRGLB.GE.verbose) THEN
        CPUT =CPTF10-CPTF0
        WALLT=TIOTF10-TIOTF0
        write(6,'(a,2f10.2)')" CLagD   : CPU/WALL TIME=", cput,wallt
        write(6,*) "Deasum = ", deasum
      END IF

      !! Some symmetrizations are likely required
      Call CLagSym(nAshT,DG1,DG2,DF1,DF2,0)

      !! Do for the derivative of EASUM
      !! EASUM=EASUM+EPSA(IT)*DREF(IT,IT)
      Do iT = 1, nAsh(1)
         DG1(iT+nAsh(1)*(iT-1)) = DG1(iT+nAsh(1)*(iT-1))
     &                          + DEASUM*EPSA(iT)
        If (ISCF.EQ.0) Then
          Do iU = 1, nAsh(1)
            DEPSA(iT,iU) = DEPSA(iT,iU)
     *        + DEASUM*G1(iT+nAsh(1)*(iU-1))
          End Do
        Else
          !! ?
        End If
      End Do

      Call CnstCLag(IFF,CLag(1,jState),
     *              DG1,DG2,DG3,
     *              DF1,DF2,DF3,
     *              DEPSA,
     *              G1,G2,G3,nLev)
!     write(6,*) "depsa after cnstclag"
!     call sqprt(depsa,nasht)

      Call mma_deallocate(G1)
      Call mma_deallocate(G2)
      Call mma_deallocate(G3)
      Call mma_deallocate(F1)
      Call mma_deallocate(F2)
      Call mma_deallocate(F3)

      Call mma_deallocate(DG1)
      Call mma_deallocate(DG2)
      Call mma_deallocate(DG3)
      Call mma_deallocate(DF1)
      Call mma_deallocate(DF2)
      Call mma_deallocate(DF3)

      End Subroutine CLagX
C
C-----------------------------------------------------------------------
C
      SUBROUTINE CLagD(G1,G2,G3,DG1,DG2,DG3,DF1,DF2,DF3,DEASUM,DEPSA,
     *                 VECROT)
! #ifdef _MOLCAS_MPP_
!       USE Para_Info, ONLY: Is_Real_Par, King
! #endif

      use caspt2_global, only:imag_shift, sigma_p_epsilon
      IMPLICIT REAL*8 (A-H,O-Z)
#include "rasdim.fh"
#include "caspt2.fh"
#include "eqsolv.fh"
#include "WrkSpc.fh"
#include "sigma.fh"
#include "pt2_guga.fh"

      DIMENSION G1(*),G2(*),G3(*),DG1(*),DG2(*),DG3(*),
     *          DF1(*),DF2(*),DF3(*),DEPSA(*),VECROT(*)

      Do iCase = 1, 13
C       cycle
C       If (icase.ne.10.and.icase.ne.11) cycle ! G
C       If (icase.ne.10)                 cycle ! GP
C       If (icase.ne. 6.and.icase.ne. 7) cycle ! E
C       If (icase.ne. 8.and.icase.ne. 9) cycle ! F
C       If (icase.ne. 8)                 cycle ! FP
C       If (icase.ne. 2.and.icase.ne. 3) cycle ! B
C       If (icase.ne. 5)                 cycle ! D
C       If (icase.ne. 4)                 cycle ! C
C       If (icase.ne. 1)                 cycle ! A
        Do iSym = 1, nSym
          nIN  = nINDEP(iSym,iCase)
          If (nIN.EQ.0) Cycle
          nIS  = nISUP(iSym,iCase)
          NVEC = nIN*nIS
          nAS  = nASUP(iSym,iCase)
          If (nVec.EQ.0) Cycle
C         write(6,*) "for icase = ", icase
C         write(6,*) "# of independent vecs:", nin
C         write(6,*) "# of non-active pairs:", nis
C         write(6,*) "# of     active pairs:", nas
C         write(6,*) "dimension for Vec = ", nin*nis
          !! lg_V1 = T (solution; not quasi-variational)
          Call RHS_ALLO(nIN,nIS,lg_V1)
          Call RHS_READ_SR(lg_V1,iCase,iSym,iVecX)
          !! lg_V2 = lambda (shift correction)
          Call RHS_ALLO(nIN,nIS,lg_V2)
          CALL RHS_READ_SR(lg_V2,iCase,iSym,iVecR)
          if (sigma_p_epsilon.ne.0.0d+00) then
            Call GETMEM('LBD','ALLO','REAL',LBD,nAS)
            Call GETMEM('LID','ALLO','REAL',LID,nIS)
            iD = iDBMat(iSym,iCase)
            Call dDaFile(LUSBT,2,Work(LBD),nAS,iD)
            Call dDaFile(LUSBT,2,Work(LID),nIS,iD)
            Call CASPT2_ResD(3,nIN,nIS,lg_V2,lg_V1,Work(LBD),Work(LID))
            Call GETMEM('LBD','FREE','REAL',LBD,nAS)
            Call GETMEM('LID','FREE','REAL',LID,nIS)
          end if
C
          If (iCase.ne.12.and.iCase.ne.13) Then
            !! lg_V3 = RHS (in IC basis)
            Call RHS_ALLO(nIN,nIS,lg_V3)
            Call RHS_READ_SR(lg_V3,iCase,iSym,iRHS)
            !! lg_V4 = RHS (in MO basis)
            Call RHS_ALLO(nAS,nIS,lg_V4)
            Call RHS_READ_C (lg_V4,iCase,iSym,iVecW)
            !! lg_V5 = RHS2 (in IC basis)
            If (IFMSCOUP) Then
              Call RHS_ALLO(nIN,nIS,lg_V5)
              Call RHS_READ_SR(lg_V5,iCase,iSym,7)
            Else
              lg_V5 = lg_V3
            End If
          Else
            Go To 100
          End If
C         write(6,*) "vec1-4"
C         do i = 1, nin*nis
C           write(6,'(i4,4f20.10)') i,work(lg_v1+i-1),work(lg_v2+i-1),
C    *                                 work(lg_v3+i-1),work(lg_v4+i-1)
C         end do
C         write(6,*) "vec5-6"
C         do i = 1, nas*nis
C           write(6,'(i4,2f20.10)') i,work(lg_v5+i-1),work(lg_v6+i-1)
C         end do
C         call abend
C
! #ifdef _MOLCAS_MPP_
    !       IF (Is_Real_Par()) THEN
    !         IF (KING()) THEN
    !           ! copy global array to local buffer
    !           CALL GETMEM('VEC1','ALLO','REAL',LVEC1,NVEC)
    !           CALL GA_GET(lg_V1,1,NIN,1,NIS,WORK(LVEC1),NIN)
    !           CALL GETMEM('VEC2','ALLO','REAL',LVEC2,NVEC)
    !           CALL GA_GET(lg_V2,1,NIN,1,NIS,WORK(LVEC2),NIN)

    !           CALL CLagDX(0,ISYM,ICASE,WORK(LVEC1),WORK(LVEC2),
    !  *                    WORK(LVEC3),WORK(LVEC4),
    !  *                    nIN,nIS,nAS,G1,G2,G3,
    !  *                    DG1,DG2,DG3,DF1,DF2,DF3,DEASUM,DEPSA,
    !  *                    VECROT,Work(lg_V5),lg_V2)

    !           ! free local buffer
    !           CALL GETMEM('VEC1','FREE','REAL',LVEC1,nVec)
    !           CALL GETMEM('VEC2','FREE','REAL',LVEC2,nVec)
    !         END IF
    !         CALL GASYNC
    !       ELSE
    !         CALL CLagDX(0,ISYM,ICASE,WORK(lg_V1),WORK(lg_V2),
    !  *                  Work(lg_V3),Work(lg_V4),
    !  *                  nIN,nIS,nAS,G1,G2,G3,
    !  *                  DG1,DG2,DG3,DF1,DF2,DF3,DEASUM,DEPSA,
    !  *                  VECROT,Work(lg_V5),lg_V2)
    !       END IF
! #else
C          write(6,*) "calling clagdx for icase = ", icase
          CALL CLagDX(0,iSym,iCase,Work(lg_V1),WORK(lg_V2),
     *                Work(lg_V3),Work(lg_V4),
     *                nIN,nIS,nAS,G1,G2,G3,
     *                DG1,DG2,DG3,DF1,DF2,DF3,DEASUM,DEPSA,
     *                VECROT,Work(lg_V5),lg_V2)
! #endif

          If (imag_shift .ne. 0.0d0 .or. sigma_p_epsilon.ne.0.0d0) Then
            nAS = nASUP(iSym,iCase)
            Call GETMEM('LBD','ALLO','REAL',LBD,nAS)
            Call GETMEM('LID','ALLO','REAL',LID,nIS)
            iD = iDBMat(iSym,iCase)
            Call dDaFile(LUSBT,2,Work(LBD),nAS,iD)
            Call dDaFile(LUSBT,2,Work(LID),nIS,iD)

            CALL RHS_READ_SR(lg_V1,ICASE,ISYM,iVecX)
            CALL RHS_READ_SR(lg_V2,ICASE,ISYM,iVecR)
            Call CASPT2_ResD(2,nIN,nIS,lg_V1,lg_V2,Work(LBD),Work(LID))

            Call DScal_(NG1,-1.0D+00,DG1,1)
            Call DScal_(NG2,-1.0D+00,DG2,1)
            Call DScal_(NG3,-1.0D+00,DG3,1)
            Call DScal_(NG1,-1.0D+00,DF1,1)
            Call DScal_(NG2,-1.0D+00,DF2,1)
            Call DScal_(NG3,-1.0D+00,DF3,1)
            DEASUM = -DEASUM
            Call DScal_(NG1,-1.0D+00,DEPSA,1)

! #ifdef _MOLCAS_MPP_
!           IF (Is_Real_Par()) THEN
!             IF (KING()) THEN
!               ! copy global array to local buffer
!               CALL GETMEM('VEC1','ALLO','REAL',LVEC1,NVEC)
!               CALL GA_GET(lg_V1,1,NIN,1,NIS,WORK(LVEC1),NIN)
!               CALL GETMEM('VEC2','ALLO','REAL',LVEC2,NVEC)
!               CALL GA_GET(lg_V2,1,NIN,1,NIS,WORK(LVEC2),NIN)

!               CALL CLagDX(1,ISYM,ICASE,WORK(LVEC1),WORK(LVEC2),
!      *                    WORK(LVEC3),WORK(LVEC4),
!      *                    nIN,nIS,nAS,G1,G2,G3,
!      *                    DG1,DG2,DG3,DF1,DF2,DF3,DEASUM,DEPSA,
!      *                    VECROT,Work(lg_V5),lg_V2)

!               ! free local buffer
!               CALL GETMEM('VEC1','FREE','REAL',LVEC1,nVec)
!               CALL GETMEM('VEC2','FREE','REAL',LVEC2,nVec)
!             END IF
!             CALL GASYNC
!           ELSE
!             CALL CLagDX(1,ISYM,ICASE,WORK(lg_V1),WORK(lg_V2),
!      *                  Work(lg_V3),Work(lg_V4),
!      *                  nIN,nIS,nAS,G1,G2,G3,
!      *                  DG1,DG2,DG3,DF1,DF2,DF3,DEASUM,DEPSA,
!      *                  VECROT,Work(lg_V5),lg_V2)
!           END IF
! #else
C          write(6,*) "calling clagdx for icase = ", icase
            CALL CLagDX(1,iSym,iCase,Work(lg_V1),WORK(lg_V2),
     *                  Work(lg_V3),Work(lg_V4),
     *                  nIN,nIS,nAS,G1,G2,G3,
     *                  DG1,DG2,DG3,DF1,DF2,DF3,DEASUM,DEPSA,
     *                  VECROT,Work(lg_V5),lg_V2)
! #endif

            Call DScal_(NG1,-1.0D+00,DG1,1)
            Call DScal_(NG2,-1.0D+00,DG2,1)
            Call DScal_(NG3,-1.0D+00,DG3,1)
            Call DScal_(NG1,-1.0D+00,DF1,1)
            Call DScal_(NG2,-1.0D+00,DF2,1)
            Call DScal_(NG3,-1.0D+00,DF3,1)
            DEASUM = -DEASUM
            Call DScal_(NG1,-1.0D+00,DEPSA,1)
C
            Call GETMEM('LBD','FREE','REAL',LBD,nAS)
            Call GETMEM('LID','FREE','REAL',LID,nIS)
          End If
C
 100      Continue
          !! for non-separable density/derivative
          CALL RHS_READ_SR(lg_V1,ICASE,ISYM,iVecX)
          CALL RHS_READ_SR(lg_V2,ICASE,ISYM,iVecR)
C         Call DaXpY_(nIN*nIS,0.5D+00,Work(lg_V2),1,Work(lg_V1),1)
C         Call RHS_Save(nIN,nIS,lg_V1,iCase,iSym,iVecX)

          CALL RHS_FREE(nIN,nIS,lg_V1)
          CALL RHS_FREE(nIN,nIS,lg_V2)
          If (iCase.ne.12.and.iCase.ne.13) Then
            CALL RHS_FREE(nIN,nIS,lg_V3)
            CALL RHS_FREE(nAS,nIS,lg_V4)
            If (IFMSCOUP) CALL RHS_FREE(nIN,nIS,lg_V5)
          End If
        End Do
      End Do
C
      Return
C
      End Subroutine CLagD
C
C-----------------------------------------------------------------------
C
      Subroutine CLagDX(Mode,iSym,iCase,VEC1,VEC2,VEC3,VEC4,nIN,nIS,nAS,
     *                  G1,G2,G3,DG1,DG2,DG3,DF1,DF2,DF3,
     *                  DEASUM,DEPSA,VECROT,VEC5,lg_V2)
C
      USE SUPERINDEX
      use stdalloc, only: mma_allocate, mma_deallocate
      use caspt2_global, only:ipea_shift, real_shift, imag_shift,
     *                        sigma_p_epsilon
      use caspt2_gradient, only:do_lindep,LUSTD
C
      Implicit Real*8 (A-H,O-Z)
C
#include "rasdim.fh"
#include "caspt2.fh"
#include "eqsolv.fh"
#include "WrkSpc.fh"
#include "sigma.fh"
#include "pt2_guga.fh"
#include "caspt2_grad.fh"
C
      DIMENSION VEC1(*),VEC2(*),VEC3(*),VEC4(*),VEC5(*)
      DIMENSION G1(nAshT,nAshT),G2(nAshT,nAshT,nAshT,nAshT),G3(*),
     *          DG1(nAshT,nAshT),DG2(nAshT,nAshT,nAshT,nAshT),DG3(*),
     *          DF1(nAshT,nAshT),DF2(nAshT,nAshT,nAshT,nAshT),DF3(*),
     *          DEPSA(nAshT,nAshT),VECROT(*)
C
      Real*8, Allocatable :: WrkBbf(:,:,:,:),WrkSbf(:,:,:,:)

      INTEGER*1, allocatable :: idxG3(:,:)
      ! INTEGER, PARAMETER :: I1=KIND(idxG3)

      nAshI = nAsh(iSym)
      Call GETMEM('WRK1  ','ALLO','REAL',LWRK1 ,nAS**2)
      Call GETMEM('WRK2  ','ALLO','REAL',LWRK2 ,MAX(nAS**2,nAS*nIS))
      Call GETMEM('WRK3  ','ALLO','REAL',LWRK3 ,nAS**2)
      Call GETMEM('LTRANS','ALLO','REAL',LTRANS,nAS*nIN)
      Call GETMEM('LEIG  ','ALLO','REAL',LEIG  ,nIN)
C
      idT  = idTMAT(iSym,iCase)
      Call DDAFILE(LUSBT,2,Work(LTRANS),nAS*nIN,idT)
      idB  = idBMAT(iSym,iCase)
      Call DDAFILE(LUSBT,2,WORK(LEIG),nIN,idB)
C
      SCAL = 1.0D+00
      IF (IFMSCOUP) SCAL = VECROT(jState)
C
      !! VEC1: solution in IC basis
      !! VEC2: lambda   in IC basis
      !! VEC3: RHS      in IC basis
      !! VEC4: RHS      in MO basis
C
      !! Form the density in internally contracted basis
      !! The G subspace is employed in the following comments
      !! as an example.
      !! i  : inactive
      !! a,b: secondary
      !! t,u: active
      !! o,p: internally contracted configuration (basis)
      !! WRK1(o,p) = \sum_{iab} T_{o,i}^{ab}*T_{p,i}^{ab}
      !! Work(LWRK1) is the effective density in the IC basis,
      !! and will be the B derivative contribution.
C
      If (Mode.eq.0) Then
        !! Work(LWRK1) = T*T
        Call DGEMM_('N','T',nIN,nIN,nIS,
     *              SCAL,VEC1,nIN,VEC1,nIN,
     *              0.0D+00,Work(LWRK1),nIN)
      Else
        Call DCopy_(nIN*nIN,[0.0D+0],0,Work(LWRK1),1)
      End If
C
      If (real_shift .NE. 0.0D+00 .OR. imag_shift .NE. 0.0D+00
     &    .OR. sigma_p_epsilon .ne. 0.0D+00 .OR. IFMSCOUP) Then
        !! Work(LWRK1) = T*T + (T*lambda+lambda*T)/2
        !! For sigma-p CASPT2, this if branch computes the pseudo-
        !! density that comes from the numerator of the shift.
        Call DGEMM_('N','T',nIN,nIN,nIS,
     *              0.5D+00,VEC2,nIN,VEC1,nIN,
     *              1.0D+00,Work(LWRK1),nIN)
        Call DGEMM_('N','T',nIN,nIN,nIS,
     *              0.5D+00,VEC1,nIN,VEC2,nIN,
     *              1.0D+00,Work(LWRK1),nIN)
      End If
      if (sigma_p_epsilon.ne.0.0d+00 .and. mode.eq.0) then
        !! the remaining is the derivative of 2<1|H|0>, so the unscaled
        !! lambda is loaded
        CALL RHS_READ_SR(lg_V2,ICASE,ISYM,iVecR)
      end if
C
      !! Transform the internally contracted density to
      !! active MO basis
      !! WRK3(t,u) = ST(t,o)*WRK1(o,p)*ST(u,p)
      !! WRK3 is the derivative contribution of the B matrix
      !! in the MO basis
      Call DGEMM_('N','N',nAS,nIN,nIN,
     *            1.0D+00,Work(LTRANS),nAS,Work(LWRK1),nIN,
     *            0.0D+00,Work(LWRK2),nAS)
      Call DGEMM_('N','T',nAS,nAS,nIN,
     *            1.0D+00,Work(LWRK2),nAS,Work(LTRANS),nAS,
     *            0.0D+00,Work(LWRK3),nAS)
C     write(6,*) "B derivative in MO"
C     call sqprt(Work(lWRK3),nas)
C
      !! Implicit derivative of the IC vector. This derivative
      !! comes from the derivative of the eigenvalue only. Other
      !! contributions of the derivative of the IC vector is considered
      !! later.
      !! -(e_o + e_p)*dS/da
      Do iICB = 1, nIN
        EigI = Work(LEIG+iICB-1)
        Do jICB = 1, nIN
          EigJ = Work(LEIG+jICB-1)
          Work(LWRK1+iICB-1+nIN*(jICB-1))
     *      = -Work(LWRK1+iICB-1+nIN*(jICB-1))*(EigI+EigJ)*0.5D+00
        End Do
      End Do
C
      !! Derivative of the overlap in the IC basis.
      !! WRK1(o,p) = WRK1(o,p) - T_{o,i}^{ab}*RHS(p,i,a,b)
      !! This contribution should not be done for the imaginary
      !! shift-specific term
      !  1) Implicit overlap derivative of the 2<1|H|0> part
      If (Mode.eq.0) Then
        !! Work(LWRK1) = -RHS*T
        Call DGEMM_('N','T',nIN,nIN,nIS,
     *             -1.0D+00,VEC5,nIN,VEC1,nIN,
     *              1.0D+00,Work(LWRK1),nIN)
        If (real_shift .NE. 0.0D+00 .OR. imag_shift .NE. 0.0D+00
     &      .OR. sigma_p_epsilon .NE. 0.0D+00 .OR. IFMSCOUP) Then
          !! Work(LWRK1) = -RHS*(T+lambda/2)
          Call DGEMM_('N','T',nIN,nIN,nIS,
     *               -0.5D+00,VEC3,nIN,VEC2,nIN,
     *                1.0D+00,Work(LWRK1),nIN)
        End If
      End If
C
      !! Convert the IC basis to the MO basis
      Call DGEMM_('N','N',nAS,nIN,nIN,
     *            1.0D+00,Work(LTRANS),nAS,Work(LWRK1),nIN,
     *            0.0D+00,Work(LWRK2),nAS)
      Call DGEMM_('N','T',nAS,nAS,nIN,
     *            1.0D+00,Work(LWRK2),nAS,Work(LTRANS),nAS,
     *            0.0D+00,Work(LWRK1),nAS)
!
      !! Add some trivial contributions due to the dependence
      !! on the linearly independent space
      If (do_lindep.AND.nAS.NE.nIN) Then
        Call LinDepLag(Work(LWRK3),Work(LWRK1),nAS,nIN,iSym,iCase)
      End If
!
      !  2) Explicit overlap derivative of the 2<1|H|0> part
      !     Again, not for imaginary shift-specific terms
      If (Mode.eq.0) Then
        !! E = 2<1|H|0> + <1|H0-E0|1>
        Call DGEMM_('N','N',nAS,nIS,nIN,
     *              SCAL,Work(LTRANS),nAS,VEC1,nIN,
     *              0.0D+00,Work(LWRK2),nAS)
        If (real_shift .NE. 0.0D+00 .OR. imag_shift .NE. 0.0D+00
     &      .OR. sigma_p_epsilon .NE. 0.0D+00 .OR. IFMSCOUP) Then
          Call DGEMM_('N','N',nAS,nIS,nIN,
     *                0.5D+00,Work(LTRANS),nAS,VEC2,nIN,
     *                1.0D+00,Work(LWRK2),nAS)
        END IF
        Call DGEMM_('N','T',nAS,nAS,nIS,
     *              2.0D+00,Work(LWRK2),nAS,VEC4,nAS,
     *              1.0D+00,Work(LWRK1),nAS)
      End If
C
      !! Add the contributions from the off-diagonal coupling
      !! (i.e., CASPT2-N). Of course, this is not for imaginary shift-
      !! specific terms.
      If (MAXIT.NE.0.and.Mode.eq.0) Then
        idSD = idSDMat(iSym,iCase)
        CALL DDAFILE(LuSTD,2,Work(LWRK2),nAS*nAS,idSD)
        !! T*(T+lambda) + (T+lambda)*T is saved, so 1/2
        Call DaXpY_(nAS*nAS,0.5D+00,Work(LWRK2),1,Work(LWRK1),1)
      End If
C
      !! Now, convert the above contributions to derivatives of RDM,
      !! weighted Fock, etc.
      !! Work(LWRK3) is the derivative of B in the MO basis
      !! Work(LWRK1) is the derivative of S in the MO basis
      !! See and be consistent with mkbmat.f and mksmat.f
      !! Notice that F2 and G2 in mkbmat.f and mksmat.f are halved
      !! (see getdpref.f).
      IF (iCase.eq.1) Then
        idS = idSMAT(iSym,1)
        CALL DDAFILE(LUSBT,2,WORK(LWRK2),nAS*(nAS+1)/2,idS)
        Call CLagDXA_DP (iSym,nAS,Work(LWRK3),Work(LWRK1),
     *                   DF2,DG2,DF1,DG1,DEPSA,DEASUM,
     *                   1,nAS,1,nAS,0,g1,g2,work(lwrk2))
        !! G3 and F3 relevant
        CALL mma_allocate(idxG3,6,NG3,label='idxG3')
        iLUID=0
        CALL I1DAFILE(LUSOLV,2,idxG3,6*NG3,iLUID)
        idS = idSMAT(iSym,1)
        CALL DDAFILE(LUSBT,2,WORK(LWRK2),nAS*(nAS+1)/2,idS)
        CALL MKSC_G3(iSym,Work(LWRK2),nG3,G3,idxG3)
        call CLagDXA_FG3(iSym,nAS,NG3,Work(LWRK3),Work(LWRK1),
     *                   DF1,DF2,DF3,DG1,DG2,DG3,DEPSA,G2,
     *                   Work(LWRK2),idxG3)
        call mma_deallocate(idxG3)
      Else If (iCase.eq. 2.or.iCase.eq. 3) Then !! B
        Allocate (WrkBbf(nAshT,nAshT,nAshT,nAshT))
        Allocate (WrkSbf(nAshT,nAshT,nAshT,nAshT))
        Call DCopy_(nAshT**4,[0.0d+00],0,WrkBbf,1)
        Call DCopy_(nAshT**4,[0.0d+00],0,WrkSbf,1)
        If (ipea_shift.ne.0.0D+00) Then
          NS = NAS*(NAS+1)/2
          CALL GETMEM('S','ALLO','REAL',LS,NS)
          idS = idSMAT(iSym,iCase)
          CALL DDAFILE(LUSBT,2,WORK(LS),NS,idS)
        End If
        ScalB1 = 0.0D+00
        ScalB2 = 0.0D+00
        ScalS1 = 0.0D+00
        ScalS2 = 0.0D+00
        iTabs  = 0
        iUabs  = 0
        iXabs  = 0
        iYabs  = 0
        iTgeUabs = 0
        iTgtUabs = 0
        iXgeYabs = 0
        iXgtYabs = 0
        Do iTU = 1, nAS
          If (iCase.eq. 2) Then
            iTgeUabs = iTU + nTgeUes(iSym)
            iTabs    = mTgeU(1,iTgeUabs)
            iUabs    = mTgeU(2,iTgeUabs)
          Else If (iCase.eq. 3) Then
            iTgtUabs = iTU + nTgtUes(iSym)
            iTabs    = mTgtU(1,iTgtUabs)
            iUabs    = mTgtU(2,iTgtUabs)
          End If
          ET = EPSA(iTabs)
          EU = EPSA(iUabs)
          DO iXY = 1, nAS
            If (iCase.eq. 2) Then
              iXgeYabs = iXY + nTgeUes(iSym)
              iXabs    = mTgeU(1,iXgeYabs)
              iYabs    = mTgeU(2,iXgeYabs)
            Else If (iCase.eq. 3) Then
              iXgtYabs = iXY + nTgtUes(iSym)
              iXabs    = mTgtU(1,iXgtYabs)
              iYabs    = mTgtU(2,iXgtYabs)
            End If
            EX = EPSA(iXabs)
            EY = EPSA(iYabs)
            ATUXY = EASUM-ET-EU-EX-EY
            iBadr = iTU + nAS*(iXY-1)
            BDER = Work(LWRK3+iBadr-1)
C
            !! For IPEA shift
            If (iTU.eq.iXY.and.ipea_shift.ne.0.0D+00) Then
              idT=(iTabs*(iTabs+1))/2
              ! idU=(iUabs*(iUabs+1))/2
              NSEQ = iTU*(iTU+1)/2
              bsBDER = ipea_shift*0.5D+00*BDER
!           !! ipea_shift*0.5d0*(DREF(IDT)+DREF(IDU))*WORK(LSDP-1+ITGEU)
              DG1(iTabs,iTabs) = DG1(iTabs,iTabs)
     *          + Work(LS+NSEQ-1)*bsBDER
              DG1(iUabs,iUabs) = DG1(iUabs,iUabs)
     *          + Work(LS+NSEQ-1)*bsBDER
              Work(LWRK1+iBadr-1) = Work(LWRK1+iBadr-1)
     *          + (G1(iTabs,iTabs)+G1(iUabs,iUabs))*bsBDER
            End If
            SDER = Work(LWRK1+iBadr-1)
            If (iTabs.eq.iUabs) Then
              BDER = BDER*2.0D+00
              SDER = SDER*2.0D+00
            End If
C
            If (iCase.eq. 2) Then
              ScalB1 = BDER
              ScalB2 = BDER
              ScalS1 = SDER
              ScalS2 = SDER
            Else If (iCase.eq. 3) Then
              ScalB1 = BDER
              ScalB2 =-BDER
              ScalS1 = SDER
              ScalS2 =-SDER
            End If
C
            WRKBBF(iTabs,iUabs,iXabs,iYabs)
     *        = WRKBBF(iTabs,iUabs,iXabs,iYabs) + ScalB1
            WRKBBF(iTabs,iUabs,iYabs,iXabs)
     *        = WRKBBF(iTabs,iUabs,iYabs,iXabs) + ScalB2
            WRKSBF(iTabs,iUabs,iXabs,iYabs)
     *        = WRKSBF(iTabs,iUabs,iXabs,iYabs) + ScalS1
            WRKSBF(iTabs,iUabs,iYabs,iXabs)
     *        = WRKSBF(iTabs,iUabs,iYabs,iXabs) + ScalS2
            If (iTabs.ne.iUabs) Then
            WRKBBF(iUabs,iTabs,iXabs,iYabs)
     *        = WRKBBF(iUabs,iTabs,iXabs,iYabs) + ScalB2
            WRKBBF(iUabs,iTabs,iYabs,iXabs)
     *        = WRKBBF(iUabs,iTabs,iYabs,iXabs) + ScalB1
            WRKSBF(iUabs,iTabs,iXabs,iYabs)
     *        = WRKSBF(iUabs,iTabs,iXabs,iYabs) + ScalS2
            WRKSBF(iUabs,iTabs,iYabs,iXabs)
     *        = WRKSBF(iUabs,iTabs,iYabs,iXabs) + ScalS1
            End If
          End Do
        End Do
C
        Do iT = 1, nAshT
          ET = EPSA(iT)
          DO iU = 1, nAshT
            EU = EPSA(iU)
            Do iX = 1, nAshT
              EX = EPSA(iX)
              Do iY = 1, nAshT
                EY = EPSA(iY)
                BDER = WRKBBF(iT,iU,iX,iY)
                SDER = WRKSBF(iT,iU,iX,iY)
C
                !! term 1 (w/o delta)
                ATUXY = EASUM-ET-EU-EX-EY
                !! G1 and F1 derivative
                DF2(iX,iT,iY,iU) = DF2(iX,iT,iY,iU) + BDER
                DG2(iX,iT,iY,iU) = DG2(iX,iT,iY,iU) - ATUXY*BDER + SDER
                !! EASUM derivative
                DEASUM = DEASUM - BDER*G2(iX,iT,iY,iU)
                !! EPSA derivative
                Do iV = 1, nAsh(1)
                  DEPSA(iT,iV) = DEPSA(iT,iV) + BDER*G2(iX,iV,iY,iU)
                  DEPSA(iU,iV) = DEPSA(iU,iV) + BDER*G2(iX,iT,iY,iV)
                  DEPSA(iX,iV) = DEPSA(iX,iV) + BDER*G2(iV,iT,iY,iU)
                  DEPSA(iY,iV) = DEPSA(iY,iV) + BDER*G2(iX,iT,iV,iU)
                End Do
C
                BDER = BDER*2.0D+00
                SDER = SDER*2.0D+00
C
                !! term 2 (dxt)
                If (iX.eq.iT) Then
                  ATYU = EASUM-ET-EY-EU
                  !! G1 and F1 derivative
                  DF1(iY,iU) = DF1(iY,iU) - BDER
                  DG1(iY,iU) = DG1(iY,iU) + ATYU*BDER - SDER
                  !! EASUM derivative
                  DEASUM = DEASUM + BDER*G1(iY,iU)
                  !! EPSA derivative
                  Do iV = 1, nAsh(1)
                    DEPSA(iY,iV) = DEPSA(iY,iV) - BDER*G1(iV,iU)
                    DEPSA(iU,iV) = DEPSA(iU,iV) - BDER*G1(iY,iV)
                  End Do
                End If
                !! Additional EPSA derivative
                DEPSA(iX,iT) = DEPSA(iX,iT) - BDER*G1(iY,iU)
                !! dxt*dyu term
                If (iY.eq.iU) DEPSA(iX,iT) = DEPSA(iX,iT) + 2.0D+00*BDER
                If (iX.eq.iT) DEPSA(iY,iU) = DEPSA(iY,iU) + 2.0D+00*BDER
C
                !! term 3 (dyu)
                If (iY.eq.iU) Then
                  ATYX = EASUM-ET-EY-EX
                  !! G1 and F1 derivative
                  DF1(iX,iT) = DF1(iX,iT) - BDER
                  DG1(iX,iT) = DG1(iX,iT) + ATYX*BDER - SDER
                  !! EASUM derivative
                  DEASUM = DEASUM + BDER*G1(iX,iT)
                  !! EPSA derivative
                  Do iV = 1, nAsh(1)
                    DEPSA(iX,iV) = DEPSA(iX,iV) - BDER*G1(iV,iT)
                    DEPSA(iT,iV) = DEPSA(iT,iV) - BDER*G1(iX,iV)
                  End Do
                End If
                !! Additional EPSA derivative
                DEPSA(iY,iU) = DEPSA(iY,iU) - BDER*G1(iX,iT)
C
                BDER = BDER*0.5D+00
                SDER = SDER*0.5D+00
C
                !! term 4 (dyt)
                If (iY.eq.iT) Then
                  ATUX = EASUM-ET-EU-EX
                  !! G1 and F1 derivative
                  DF1(iX,iU) = DF1(iX,iU) + BDER
                  DG1(iX,iU) = DG1(iX,iU) - ATUX*BDER + SDER
                  !! EASUM derivative
                  DEASUM = DEASUM - BDER*G1(iX,iU)
                  !! EPSA derivative
                  Do iV = 1, nAsh(1)
                    DEPSA(iX,iV) = DEPSA(iX,iV) + BDER*G1(iV,iU)
                    DEPSA(iU,iV) = DEPSA(iU,iV) + BDER*G1(iX,iV)
                  End Do
                End If
                !! Additional EPSA derivative
                DEPSA(iY,iT) = DEPSA(iY,iT) + BDER*G1(iX,iU)
                !! dxu*dyt term
                If (iY.eq.iT) DEPSA(iX,iU) = DEPSA(iX,iU) - 2.0D+00*BDER
                If (iX.eq.iU) DEPSA(iY,iT) = DEPSA(iY,iT) - 2.0D+00*BDER
C
                !! term 5 (dxu)
                If (iX.eq.iU) Then
                  ATUY = EASUM-ET-EU-EY
                  !! G1 and F1 derivative
                  DF1(iY,iT) = DF1(iY,iT) + BDER
                  DG1(iY,iT) = DG1(iY,iT) - ATUY*BDER + SDER
                  !! EASUM derivative
                  DEASUM = DEASUM - BDER*G1(iY,iT)
                  !! EPSA derivative
                  Do iV = 1, nAsh(1)
                    DEPSA(iY,iV) = DEPSA(iY,iV) + BDER*G1(iV,iT)
                    DEPSA(iT,iV) = DEPSA(iT,iV) + BDER*G1(iY,iV)
                  End Do
                End If
                !! Additional EPSA derivative
                DEPSA(iX,iU) = DEPSA(iX,iU) + BDER*G1(iY,iT)
              End Do
            End Do
          End Do
        End Do
        If (ipea_shift.ne.0.0D+00) CALL GETMEM('S','FREE','REAL',LS,NS)
C
        DeAllocate (WrkBbf)
        DeAllocate (WrkSbf)
      Else If (iCase.eq. 4) Then !! C
C     write(6,*) "Clear S derivative for C"
C     call docpy_nas*nas,0.0d+00,0,work(lwrk1),1)
        idS = idSMAT(iSym,4)
        CALL DDAFILE(LUSBT,2,WORK(LWRK2),nAS*(nAS+1)/2,idS)
        Call CLagDXC_DP (iSym,nAS,Work(LWRK3),Work(LWRK1),
     *                   DF2,DG2,DF1,DG1,DEPSA,DEASUM,
     *                   1,nAS,1,nAS,0,g1,g2,work(lwrk2))
C
        !! G3 and F3 relevant
        CALL mma_allocate(idxG3,6,NG3,label='idxG3')
        iLUID=0
        CALL I1DAFILE(LUSOLV,2,idxG3,6*NG3,iLUID)
        idS = idSMAT(iSym,4)
        CALL DDAFILE(LUSBT,2,WORK(LWRK2),nAS*(nAS+1)/2,idS)
        CALL MKSC_G3(iSym,Work(LWRK2),nG3,G3,idxG3)
        call CLagDXC_FG3(iSym,nAS,NG3,Work(LWRK3),Work(LWRK1),
     *                   DF1,DF2,DF3,DG1,DG2,DG3,DEPSA,G2,
     *                   Work(LWRK2),idxG3)
        call mma_deallocate(idxG3)
      Else If (iCase.eq. 5) Then !! D
        LS=0
        If (ipea_shift.ne.0.0D+00) Then
          NS = NAS*(NAS+1)/2
          CALL GETMEM('S','ALLO','REAL',LS,NS)
          idS = idSMAT(iSym,iCase)
          CALL DDAFILE(LUSBT,2,WORK(LS),NS,idS)
        End If
        Do iTU = 1, nAS/2
          iTU2   = iTU + nAS/2
          iTUabs = iTU + nTUes(iSym)
          iTabs  = mTU(1,iTUabs)
          iUabs  = mTU(2,iTUabs)
          ET     = EPSA(iTabs)
          DO iXY = 1, nAS/2
            iXY2   = iXY + nAS/2
            iXYabs = iXY + nTUes(iSym)
            iXabs  = mTU(1,iXYabs)
            iYabs  = mTU(2,iXYabs)
            EX     = EPSA(iXabs)
            ETX    = ET+EX
C
            BDER1 = Work(LWRK3+iTU -1+nAS*(iXY -1))
     *            - Work(LWRK3+iTU -1+nAS*(iXY2-1))*0.5D+00
     *            - Work(LWRK3+iTU2-1+nAS*(iXY -1))*0.5D+00
            BDER2 = Work(LWRK3+iTU2-1+nAS*(iXY2-1))
C
            !! Derivative of B11
            DF2(iUabs,iTabs,iXabs,iYabs)
     *        = DF2(iUabs,iTabs,iXabs,iYabs) + 2.0D+00*BDER1
            DG2(iUabs,iTabs,iXabs,iYabs)
     *        = DG2(iUabs,iTabs,iXabs,iYabs) + 2.0D+00*(ETX-EASUM)*BDER1
            DEASUM = DEASUM - 2.0D+00*G2(iUabs,iTabs,iXabs,iYabs)*BDER1
            If (iXabs.eq.iTabs) Then
              DF1(iUabs,iYabs) = DF1(iUabs,iYabs) + 2.0D+00*BDER1
              DG1(iUabs,iYabs) = DG1(iUabs,iYabs)
     *          + 2.0D+00*(ET-EASUM)*BDER1
              DEASUM = DEASUM - 2.0D+00*G1(iUabs,iYabs)*BDER1
            End If
            Do iVabs = 1, nAshT
              DEPSA(iTabs,iVabs) = DEPSA(iTabs,iVabs)
     *          + 2.0D+00*BDER1*G2(iUabs,iVabs,iXabs,iYabs)
              DEPSA(iXabs,iVabs) = DEPSA(iXabs,iVabs)
     *          + 2.0D+00*BDER1*G2(iUabs,iTabs,iVabs,iYabs)
            End Do
            DEPSA(iTabs,iXabs) = DEPSA(iTabs,iXabs)
     *        + 2.0D+00*G1(iUabs,iYabs)*BDER1

            !! Derivative of B22
            DF2(iXabs,iTabs,iUabs,iYabs)
     *        = DF2(iXabs,iTabs,iUabs,iYabs) - BDER2
            DG2(iXabs,iTabs,iUabs,iYabs)
     *        = DG2(iXabs,iTabs,iUabs,iYabs) - (ETX-EASUM)*BDER2
            DEASUM = DEASUM + G2(iXabs,iTabs,iUabs,iYabs)*BDER2
            If (iXabs.eq.iTabs) Then
              DF1(iUabs,iYabs) = DF1(iUabs,iYabs) + 2.0D+00*BDER2
              DG1(iUabs,iYabs) = DG1(iUabs,iYabs)
     *          + 2.0D+00*(EX-EASUM)*BDER2
              DEASUM = DEASUM - 2.0D+00*G1(iUabs,iYabs)*BDER2
            End If
            Do iVabs = 1, nAshT
              DEPSA(iTabs,iVabs) = DEPSA(iTabs,iVabs)
     *          - BDER2*G2(iXabs,iVabs,iUabs,iYabs)
              DEPSA(iXabs,iVabs) = DEPSA(iXabs,iVabs)
     *          - BDER2*G2(iVabs,iTabs,iUabs,iYabs)
            End Do
            DEPSA(iXabs,iTabs) = DEPSA(iXabs,iTabs)
     *        + 2.0D+00*G1(iUabs,iYabs)*BDER2
C
            If (iTU.eq.iXY.and.ipea_shift.ne.0.0D+00) Then
C        !! ipea_shift*0.5d0*(2.0d0-DREF(IDU)+DREF(IDT))*WORK(LSD-1+ITU)
              bsBDER = ipea_shift*0.5D+0*Work(LWRK3+iTU -1+nAS*(iXY -1))
              NSEQ = iTU*(iTU+1)/2
              DG1(iTabs,iTabs) = DG1(iTabs,iTabs)
     *          + bsBDER*Work(LS+NSEQ-1)
              DG1(iUabs,iUabs) = DG1(iUabs,iUabs)
     *          - bsBDER*Work(LS+NSEQ-1)
              Work(LWRK1+iTU -1+nAS*(iXY -1))
     *          = Work(LWRK1+iTU -1+nAS*(iXY -1))
     *          + bsBDER*(2.0D+00+G1(iTabs,iTabs)-G1(iUabs,iUabs))
C    !! ipea_shift*0.5d0*(2.0d0-DREF(IDU)+DREF(IDT))*WORK(LSD-1+ITU+NAS)
              bsBDER = ipea_shift*0.5D+0*Work(LWRK3+iTU2-1+nAS*(iXY2-1))
              NSEQ = iTU2*(iTU2+1)/2
              DG1(iTabs,iTabs) = DG1(iTabs,iTabs)
     *          + bsBDER*Work(LS+NSEQ-1)
              DG1(iUabs,iUabs) = DG1(iUabs,iUabs)
     *          - bsBDER*Work(LS+NSEQ-1)
              Work(LWRK1+iTU2-1+nAS*(iXY2-1))
     *          = Work(LWRK1+iTU2-1+nAS*(iXY2-1))
     *          + bsBDER*(2.0D+00+G1(iTabs,iTabs)-G1(iUabs,iUabs))
            End If
C
            SDER1 = Work(LWRK1+iTU -1+nAS*(iXY -1))
     *            - Work(LWRK1+iTU -1+nAS*(iXY2-1))*0.5D+00
     *            - Work(LWRK1+iTU2-1+nAS*(iXY -1))*0.5D+00
            SDER2 = Work(LWRK1+iTU2-1+nAS*(iXY2-1))
C
            !! Derivative of S11
            DG2(iUabs,iTabs,iXabs,iYabs)
     *        = DG2(iUabs,iTabs,iXabs,iYabs) + 2.0D+00*SDER1
            If (iXabs.eq.iTabs) Then
              DG1(iUabs,iYabs) = DG1(iUabs,iYabs) + 2.0D+00*SDER1
            End If
            !! Derivative of S22
            DG2(iXabs,iTabs,iUabs,iYabs)
     *        = DG2(iXabs,iTabs,iUabs,iYabs) - SDER2
            If (iXabs.eq.iTabs) Then
              DG1(iUabs,iYabs) = DG1(iUabs,iYabs) + 2.0D+00*SDER2
            End If
          End Do
        End Do
        If (ipea_shift.ne.0.0D+00) CALL GETMEM('S','FREE','REAL',LS,NS)
      Else If (iCase.eq. 6.or.iCase.eq. 7) Then !! E
        If (ipea_shift.ne.0.0d0) Then
          NS = NAS*(NAS+1)/2
          CALL GETMEM('S','ALLO','REAL',LS,NS)
          idS = idSMAT(iSym,6)
          CALL DDAFILE(LUSBT,2,WORK(LS),NS,idS)
          !! ipea_shift*0.5d0*DREF(IDT)*WORK(LSD-1+IT)
          Do iT = 1, nAshI
            VAL = Work(LWRK3+iT-1+nAS*(iT-1))
            Work(LWRK1+iT-1+nAS*(iT-1)) = Work(LWRK1+iT-1+nAS*(iT-1))
     *        + ipea_shift*0.5D+00*G1(iT,iT)*VAL
            nSEQ = iT*(iT-1)/2+iT
            DG1(iT,iT)=DG1(iT,iT)+ipea_shift*0.5D+0*Work(LS+nSEQ-1)*VAL
          End Do
          CALL GETMEM('S','FREE','REAL',LS,NS)
        End If
C     !! E_{ti}_{aj}
C     !! B_{tu} = (E_{ti}E_{aj})*f_{vw}E_{vw}*E_{uk}E_{bl}
C     !!        = (j+ a i+ t v+ w u+ k b+ l)*f_{vw}
C     !!        = j+ a t v+ w u+ b+ l * f_{vw}
C     !!        = t v+ w u+ * f_{vw}
C     !!        = t v+ (del(uw)- u+ w) * f_{vw}
C     !!        = del(uw)*tD_{tv}*f_{vw} - t v+ u+ w * f_{vw}
C     !!        = del(uw)*tD_{tv}*f_{vw} + t u+ v+ w * f_{vw}
C     !!        = del(uw)*tD_{tv}*f_{vw} + (del(tu)- u+ t) v+ w * f_{vw}
C     !!        = del(uw)*tD_{tv}*f_{vw} + del(tu) v+ w * f_{vw}
C     !!          - u+ t v+ w * f_{vw}
C     !!        = del(uw)*tD_{tv}*f_{vw} + del(tu)*D_{vw}*f_{vw} -F_{ut}
C     !!        = tD_{tv}*f_{vu} + del(tu)*EASUM - F_{ut}
C     !!        = (2*del(tv)-D_{tv})*f_{vu} + del(tu)*EASUM - F_{ut}
C     !!        = 2*f_{tu} - D_{tv}*f_{vu} + del(tu)*EASUM - F_{ut}
        Do iT = 1, nAshI
          iTabs = iT + nAes(iSym)
          ET = EPSA(iTabs)
          Do iU = 1, nAshI
            iUabs = iU + nAes(iSym)
            EU = EPSA(iUabs)
            !! Derivative of the B matrix
            !! B_{tu} = -F1_{tu} + (Esum-e_t-e_u)*G1(tu)
            DG1(iT,iU) = DG1(iT,iU)
     *        + (EASUM-ET-EU)*Work(LWRK3+iT-1+nAS*(iU-1))
            DEASUM = DEASUM + G1(iT,iU)*Work(LWRK3+iT-1+nAS*(iU-1))
            DF1(iT,iU) = DF1(iT,iU) - Work(LWRK3+iT-1+nAS*(iU-1))
            Do iV = 1, nAshI
              DEPSA(iTabs,iUabs) = DEPSA(iTabs,iUabs)
     *          - G1(iT,iV)*Work(LWRK3+iV-1+nAS*(iU-1))
     *          - G1(iU,iV)*Work(LWRK3+iV-1+nAS*(iT-1))
            End Do
            DEPSA(iTabs,iUabs) = DEPSA(iTabs,iUabs)
     *        + 2.0D+00*Work(LWRK3+iT-1+nAS*(iU-1))
            !! Derivative of the S matrix
            DG1(iT,iU) = DG1(iT,iU) - Work(LWRK1+iT-1+nAS*(iU-1))
          End Do
        End Do
      Else If (iCase.eq. 8.or.iCase.eq. 9) Then !! F
C     write(6,*) "Clear B derivative for F"
C     call docpy_nas*nas,0.0d+00,0,work(lwrk3),1)
        LS=0
        If (ipea_shift.ne.0.0D+00) Then
          NS = NAS*(NAS+1)/2
          CALL GETMEM('S','ALLO','REAL',LS,NS)
          idS = idSMAT(iSym,iCase)
          CALL DDAFILE(LUSBT,2,WORK(LS),NS,idS)
        End If
        ScalB1 = 0.0D+00
        ScalB2 = 0.0D+00
        ScalS1 = 0.0D+00
        ScalS2 = 0.0D+00
        iXabs  = 0
        iYabs  = 0
        iTabs  = 0
        iUabs  = 0
        iTgeUabs = 0
        iTgtUabs = 0
        iXgeYabs = 0
        iXgtYabs = 0
        Do iTU = 1, nAS
          If (iCase.eq. 8) Then
            iTgeUabs = iTU + nTgeUes(iSym)
            iTabs    = mTgeU(1,iTgeUabs)
            iUabs    = mTgeU(2,iTgeUabs)
          Else If (iCase.eq. 9) Then
            iTgtUabs = iTU + nTgtUes(iSym)
            iTabs    = mTgtU(1,iTgtUabs)
            iUabs    = mTgtU(2,iTgtUabs)
          End If
          DO iXY = 1, nAS !! iTU
            If (iCase.eq. 8) Then
              iXgeYabs = iXY + nTgeUes(iSym)
              iXabs    = mTgeU(1,iXgeYabs)
              iYabs    = mTgeU(2,iXgeYabs)
            Else If (iCase.eq. 9) Then
              iXgtYabs = iXY + nTgtUes(iSym)
              iXabs    = mTgtU(1,iXgtYabs)
              iYabs    = mTgtU(2,iXgtYabs)
            End If
            iBadr = iTU + nAS*(iXY-1)
C
            BDER = Work(LWRK3+iBadr-1)
            If (iTU.eq.iXY.and.ipea_shift.ne.0.0D+00) Then
              idT=(iTabs*(iTabs+1))/2
              ! idU=(iUabs*(iUabs+1))/2
              NSEQ = iTU*(iTU+1)/2
              bsBDER = ipea_shift*0.5D+00*BDER
C     !! ipea_shift*0.5d0*(4.0d0-DREF(IDT)-DREF(IDU))*WORK(LSDP-1+ITGEU)
              DG1(iTabs,iTabs) = DG1(iTabs,iTabs)
     *          - Work(LS+NSEQ-1)*bsBDER
              DG1(iUabs,iUabs) = DG1(iUabs,iUabs)
     *          - Work(LS+NSEQ-1)*bsBDER
              Work(LWRK1+iBadr-1) = Work(LWRK1+iBadr-1)
     *          + (4.0D+00-G1(iTabs,iTabs)-G1(iUabs,iUabs))*bsBDER
            End If
            SDER = Work(LWRK1+iBadr-1)
            If (iTabs.eq.iUabs) Then
              BDER = 2.0D+00*BDER
              SDER = 2.0D+00*SDER
            End If
C
            If (iCase.eq. 8) Then
              ScalB1 = BDER
              ScalB2 = BDER
              ScalS1 = SDER
              ScalS2 = SDER
            Else If (iCase.eq. 9) Then
              ScalB1 = BDER
              ScalB2 =-BDER
              ScalS1 = SDER
              ScalS2 =-SDER
            End If
C
            !! Derivative of the B matrix
            !! B(tuxy) -> PREF(tx,uy)
            DEASUM = DEASUM - ScalB1*G2(iTabs,iXabs,iUabs,iYabs)
     *                      - ScalB2*G2(iTabs,iYabs,iUabs,iXabs)
            If (iTabs.ne.iUabs)
     *      DEASUM = DEASUM - ScalB2*G2(iUabs,iXabs,iTabs,iYabs)
     *                      - ScalB1*G2(iUabs,iYabs,iTabs,iXabs)
C
            ! iTX = iTabs+nAshT*(iXabs-1)
            ! iUY = iUabs+nAshT*(iYabs-1)
            ! iTY = iTabs+nAshT*(iYabs-1)
            ! iUX = iUabs+nAshT*(iXabs-1)
C
            DF2(iTabs,iXabs,iUabs,iYabs)
     *        = DF2(iTabs,iXabs,iUabs,iYabs) + ScalB1
            DF2(iTabs,iYabs,iUabs,iXabs)
     *        = DF2(iTabs,iYabs,iUabs,iXabs) + ScalB2
            If (iTabs.ne.iUabs) Then
              DF2(iUabs,iXabs,iTabs,iYabs)
     *          = DF2(iUabs,iXabs,iTabs,iYabs) + ScalB2
              DF2(iUabs,iYabs,iTabs,iXabs)
     *          = DF2(iUabs,iYabs,iTabs,iXabs) + ScalB1
            End If
            DG2(iTabs,iXabs,iUabs,iYabs)
     *        = DG2(iTabs,iXabs,iUabs,iYabs) + ScalS1-EASUM*ScalB1
            DG2(iTabs,iYabs,iUabs,iXabs)
     *        = DG2(iTabs,iYabs,iUabs,iXabs) + ScalS2-EASUM*ScalB2
            If (iTabs.ne.iUabs) Then
              DG2(iUabs,iXabs,iTabs,iYabs)
     *          = DG2(iUabs,iXabs,iTabs,iYabs) + ScalS2-EASUM*ScalB2
              DG2(iUabs,iYabs,iTabs,iXabs)
     *          = DG2(iUabs,iYabs,iTabs,iXabs) + ScalS1-EASUM*ScalB1
            End If
          End Do
        End Do
        If (ipea_shift.ne.0.0D+00) CALL GETMEM('S','FREE','REAL',LS,NS)
      Else If (iCase.eq.10.or.iCase.eq.11) Then !! G
        If (ipea_shift.ne.0.0d0) Then
          NS = NAS*(NAS+1)/2
          CALL GETMEM('S','ALLO','REAL',LS,NS)
          idS = idSMAT(iSym,10)
          CALL DDAFILE(LUSBT,2,WORK(LS),NS,idS)
          !! ipea_shift*0.5d0*(2.0d0-DREF(IDT))*WORK(LSD-1+IT)
          Do iT = 1, nAshI
            VAL = Work(LWRK3+iT-1+nAS*(iT-1))
            Work(LWRK1+iT-1+nAS*(iT-1)) = Work(LWRK1+iT-1+nAS*(iT-1))
     *        + ipea_shift*0.5D+00*(2.0D+00-G1(iT,iT))*VAL
            nSEQ = iT*(iT-1)/2+iT
            DG1(iT,iT)=DG1(iT,iT)-ipea_shift*0.5D+00*Work(LS+nSEQ-1)*VAL
C     write(6,'(i3,3f20.10)') i,g1(it,it),work(ls+nseq-1),
C    *            ipea_shift*0.5d0*(2.0d0-g1(it,it))*work(ls+nseq-1)
C           Do iU = 1, nAshI
C             VAL = Work(LWRK3+iT-1+nAS*(iU-1))
C             Work(LWRK1+iT-1+nAS*(iU-1)) = Work(LWRK1+iT-1+nAS*(iU-1))
C    *          + ipea_shift*0.5D+00*(2.0D+00-G1(iT,iU))*VAL
C             if (it.ge.iu) then
C             nSEQ = iT*(iT-1)/2+iU
C             else
C             nSEQ = iU*(iU-1)/2+iT
C             end if
C         DG1(iT,iU) = DG1(iT,iU)-ipea_shift*0.5D+00*Work(LS+nSEQ-1)*VAL
C           End Do
          End Do
          CALL GETMEM('S','FREE','REAL',LS,NS)
        End If
        Do iT = 1, nAshI
          Do iU = 1, nAshI
            !! Derivative of the B matrix
            DG1(iT,iU) = DG1(iT,iU) - EASUM*Work(LWRK3+iT-1+nAS*(iU-1))
            DEASUM = DEASUM - G1(iT,iU)*Work(LWRK3+iT-1+nAS*(iU-1))
            DF1(iT,iU) = DF1(iT,iU) + Work(LWRK3+iT-1+nAS*(iU-1))
            !! Derivative of the S matrix
            DG1(iT,iU) = DG1(iT,iU) + Work(LWRK1+iT-1+nAS*(iU-1))
          End Do
        End Do
      End If
C
      CALL GETMEM('WRK1'  ,'FREE','REAL',LWRK1 ,nAS**2)
      CALL GETMEM('WRK2'  ,'FREE','REAL',LWRK2 ,nAS**2)
      CALL GETMEM('WRK3'  ,'FREE','REAL',LWRK3 ,nAS**2)
      CALL GETMEM('LTRANS','FREE','REAL',LTRANS,NAS*NIN)
      CALL GETMEM('LEIG'  ,'FREE','REAL',LEIG  ,NIN)
C
      Return
C
      End Subroutine CLagDX
C
C-----------------------------------------------------------------------
C
      !! From poly3
      SUBROUTINE CnstCLag(IFF,CLag,DG1,DG2,DG3,DF1,DF2,DF3,DEPSA,
     *                    G1,G2,G3,nLev)

      use stdalloc, only: mma_allocate, mma_deallocate
      use caspt2_output, only: iPrGlb, verbose
      use gugx, only: L2ACT
      IMPLICIT REAL*8 (A-H,O-Z)
#include "rasdim.fh"
#include "caspt2.fh"
#include "pt2_guga.fh"
#include "WrkSpc.fh"

C
      Integer, Intent(In):: nLev
      DIMENSION CLag(nConf)
      DIMENSION DG1(*),DG2(*),DG3(*),DF1(*),DF2(*),DF3(*)
      DIMENSION G1(*),G2(*),G3(*)
      DIMENSION DEPSA(*)
C
      INTEGER ILEV
      INTEGER NG3MAX
      INTEGER ILUID
      integer*1, allocatable :: idxG3(:,:)
C
      INTEGER IDCI
      INTEGER J
C
      INTEGER IPARDIV
C
      IF (IFF.EQ.1) THEN
C ORBITAL ENERGIES IN CI-COUPLING ORDER:
        DO ILEV=1,NLEV
          ETA(ILEV)=EPSA(L2ACT(ILEV))
        END DO
      END IF

C-SVC20100831: recompute approximate max NG3 size needed
      NG3MAX=iPARDIV(NG3TOT,NG2)

C-SVC20100831: allocate local G3 matrices
      CALL mma_allocate(idxG3,6,NG3,label='idxG3')
      iLUID=0
      CALL I1DAFILE(LUSOLV,2,idxG3,6*NG3,iLUID)
* NG3 will change inside subroutine MKFG3 to the actual
* number of nonzero elements, that is why here we allocate
* with NG3MAX, but we only store (PT2_PUT) the first NG3
* elements of the G3 and F3
      IF (ISCF.EQ.0) NG3=NG3MAX

      CALL GETMEM('LCI','ALLO','REAL',LCI,NCONF)
      If (ISCF.EQ.0) Then
        if (iff.eq.1) then
          IDCI=IDTCEX
          DO J=1,JSTATE-1
            CALL DDAFILE(LUCIEX,0,WORK(LCI),NCONF,IDCI)
          END DO
          CALL DDAFILE(LUCIEX,2,WORK(LCI),NCONF,IDCI)
        else
C         Call LoadCI_XMS('C',1,Work(LCI),JSTATE,U0)
        end if
        IF (IPRGLB.GE.VERBOSE) THEN
          WRITE(6,*)
          IF (NSTATE.GT.1) THEN
            WRITE(6,'(A,I4)')
     &      ' With new orbitals, the CI array of state ',MSTATE(JSTATE)
          ELSE
            WRITE(6,*)' With new orbitals, the CI array is:'
          END IF
          CALL PRWF_CP2(STSYM,NCONF,WORK(LCI),CITHR)
        END IF
      Else
        WORK(LCI) = 1.0D+00
      End If
C
      CALL TIMING(CPTF0,CPE,TIOTF0,TIOE)
      If (ISCF.EQ.0) Then
        CALL DERFG3(WORK(LCI),CLAG,DG1,DG2,DG3,DF1,DF2,DF3,
     &              idxG3,DEPSA,G1,G2,nLev)
      Else
        CALL DERSPE(DF1,DF2,DF3,idxG3,DEPSA,G1,G2,G3)
      End If
      CALL TIMING(CPTF10,CPE,TIOTF10,TIOE)
      IF (IPRGLB.GE.verbose) THEN
        CPUT =CPTF10-CPTF0
        WALLT=TIOTF10-TIOTF0
        write(6,*)
        write(6,'(a,2f10.2)')" DERFG3  : CPU/WALL TIME=", cput,wallt
      END IF
C
C     write(6,*) "clag after DERFG3"
C     do i = 1, min(50,nconf)
C       write(6,'(i3,2f20.10)') i,clag(i),work(lci+i-1)
C     end do

C     call abend
C     ovl = ddot_(nconf,work(lci),1,clag,1)
C     write(6,*) "ovl = ", ovl
C     call daxpy_(nconf,-ovl,work(lci),1,clag,1)
C     write(6,*) "clag after projection"
C     do i = 1, nconf
C       write(6,'(i3,f20.10)') i,clag(i)
C     end do
C     call abend

C     CALL DCOPY_(NCONF,[0.0D0],0,WORK(LSGM),1)
C     IF(ORBIN.EQ.'TRANSFOR') Call CLagX_TrfCI(CLAG)

C     write(6,*) "clag after rotation"
C     do i = 1, nconf
C       write(6,'(i3,f20.10)') i,clag(i)
C     end do
C     write(6,*) "after projection"
C     ovl = ddot_(nconf,work(lci),1,clag,1)
C     call daxpy_(nconf,-ovl,work(lci),1,clag,1)
C     do i = 1, nconf
C       write(6,'(i3,2f20.10)') i,clag(i),
C    *    clag(i)*2.0d+00
C     end do
C
      CALL GETMEM('LCI','FREE','REAL',LCI,NCONF)
      call mma_deallocate(idxG3)
C
      Return
C
      End Subroutine CnstCLag
C
C-----------------------------------------------------------------------
C
      !! From poly3
      SUBROUTINE CLagEig(IFSSDMloc,CLag,RDMEIG,nLev)
C
      IMPLICIT REAL*8 (A-H,O-Z)
#include "rasdim.fh"
#include "caspt2.fh"
#include "WrkSpc.fh"
#include "pt2_guga.fh"
#include "caspt2_grad.fh"
C
      Integer, Intent(In)::nLev
      DIMENSION CLag(nConf,nState),RDMEIG(*)
      Logical   IFSSDMloc
C
C     MODE=0: Either state-averaged or LDWGT matrix
C     MODE=1: XMS-specific term, always state-averaged DM
C
      !! RDMEIG
      Call GetMem('LCI','ALLO','REAL',LCI,nConf)

      Do iState = 1, nState
        If (.not.IFSSDMloc) Then
          If (ISCF.EQ.0) Then
            Call LoadCI(Work(LCI),iState)
          Else
            Work(LCI) = 1.0D+00
          End If
          WGT = 1.0D+00/nState
          Call DScal_(NLEV*NLEV,WGT,RDMEIG,1)
          Call Poly1_CLag(Work(LCI),CLag(1,iState),RDMEIG,nLev)
          Call DScal_(NLEV*NLEV,1.0D+00/WGT,RDMEIG,1)
        Else
          Wgt = Work(LDWgt+iState-1+nState*(jState-1))
          If (abs(wgt).gt.1.0d-09) Then
            If (ISCF.EQ.0) Then
              Call LoadCI(Work(LCI),iState)
            Else
              Work(LCI) = 1.0D+00
            End If
            !! how is the numerical precision?
            Call DScal_(NLEV*NLEV,WGT,RDMEIG,1)
            Call Poly1_CLag(Work(LCI),CLag(1,iState),RDMEIG,nLev)
            Call DScal_(NLEV*NLEV,1.0D+00/WGT,RDMEIG,1)
          End If

          !! Derivative of omega for dynamically weighted density
          If (IFDW .and. zeta >= 0.0d0) Then
            If (ISCF.EQ.0) Then
              Call LoadCI(Work(LCI),iState)
            Else
              Work(LCI) = 1.0D+00
            End If
            Call GetMem('WRK','ALLO','REAL',LWRK,nAshT**2)
            call POLY1(WORK(LCI))
            call GETDREF(WORK(LDREF))
            Call SQUARE(Work(LDREF),Work(LWRK),1,nAshT,nAshT)
            !! probably it is doubled somewhere, so should half
            Scal = DDOT_(nAshT**2,RDMEIG,1,Work(LWRK),1)*0.5d+00
C           write (*,*) "scal = ", scal
            Call GetMem('WRK','FREE','REAL',LWRK,nAshT**2)
            WORK(ipOMGDER+iState-1+nState*(jState-1))
     *      = WORK(ipOMGDER+iState-1+nState*(jState-1)) + Scal
          End If

        End If
      End Do
C     write(6,*) "clag before projection"
C     do istate = 1, nstate
C       write(6,*) "state = ", istate
C       do i = 1, nconf
C         write(6,'(i3,f20.10)') i,clag(i,istate)
C       end do
C     end do
C     write(6,*) "debug"
C     IF(ORBIN.EQ.'TRANSFOR') Call CLagX_TrfCI(CLAG)
C     if (proj) then
C     ovl = ddot_(nconf*nstate,work(lci),1,clag,1)
C     write(6,*) "projection coeff = ",ovl
C     call daxpy_(nconf*nstate,-ovl,work(lci),1,clag,1)
C     write(6,*) "clag after projection"
C     do istate = 1, nstate
C       write(6,*) "state = ", istate
C       do i = 1, nconf
C         write(6,'(i3,f20.10)') i,clag(i,istate)
C       end do
C     end do
C     end if
C
      Call GetMem('LCI','FREE','REAL',LCI,nConf)
C
      Return
C
      End Subroutine CLagEig
C
C-----------------------------------------------------------------------
C
      Subroutine CLagFinal(CLag,SLag)
C
      use caspt2_output, only: iPrGlb,verbose
      IMPLICIT REAL*8 (A-H,O-Z)
C
      Dimension CLag(nConf,nState),SLag(*)
C
#include "rasdim.fh"
#include "caspt2.fh"
#include "WrkSpc.fh"

      Call GetMem('LCI1','ALLO','REAL',LCI1,nConf)
      Call GetMem('LCI2','ALLO','REAL',LCI2,nConf)
C
      !! Construct SLag
      ijst = 0
      do ilStat = 1, nState
        If (ISCF.EQ.0) Then
          Call LoadCI(Work(LCI1),ilStat)
        Else
          Work(LCI1) = 1.0D+00
        End If
        Do jlStat = 1, ilStat !! -1
          ijst = ilStat + nState*(jlStat-1)
          If (ilStat.eq.jlStat) Cycle
          If (ISCF.EQ.0) Then
            Call LoadCI(Work(LCI2),jlStat)
          Else
            Work(LCI2) = 1.0D+00
          End If
          Scal = DDOT_(nConf,Work(LCI1),1,CLag(1,jlStat),1)
     *         - DDOT_(nConf,Work(LCI2),1,CLag(1,ilStat),1)
          Scal = Scal/(REFENE(jlStat)-REFENE(ilStat))
          SLag(ijst) = SLag(ijst) + Scal
          IF (IPRGLB.GE.VERBOSE) THEN
            write(6,*)
            write(6,'(1x,"SLag for State ",i1,"-",i1," = ",f20.10)')
     *         ilstat,jlstat,slag(ijst)
            write(6,*)
          END IF
        end do
      end do
C
      !! This projection is required to get convergence in MCLR.
      !! also the linear equation for non-invariant CASPT2
      Do ilStat = 1, nState
        Call DCopy_(nConf,CLag(1,ilStat),1,Work(LCI1),1)
C       do i = 1, nconf
C         write(6,'(i3,f20.10)') i,clag(i,ilstat)
C       end do
        Do jlStat = 1, nState
          If (ISCF.EQ.0) Then
            Call LoadCI(Work(LCI2),jlStat)
          Else
            Work(LCI2) = 1.0D+00
          End If
          Ovl = DDot_(nConf,Work(LCI1),1,Work(LCI2),1)
C         write(6,*) "projection coeff = ",ovl
          Call DaXpY_(nConf,-Ovl,Work(LCI2),1,CLag(1,ilStat),1)
        End Do
C       write(6,*) "clag after projection"
C       write(6,*) "state = ", ilstat
C       do i = 1, nconf
C         write(6,'(i3,f20.10)') i,clag(i,ilstat)
C       end do
      End Do
C
      Call GetMem('LCI1','FREE','REAL',LCI1,nConf)
      Call GetMem('LCI2','FREE','REAL',LCI2,nConf)
C
      Return
C
      End Subroutine CLagFinal
C
C-----------------------------------------------------------------------
C
      SUBROUTINE POLY1_CLag(CI,CLag,RDMEIG,nLev)
      IMPLICIT NONE
* PER-AAKE MALMQUIST, 92-12-07
* THIS PROGRAM CALCULATES THE 1-EL DENSITY
* MATRIX FOR A CASSCF WAVE FUNCTION.
#include "rasdim.fh"
#include "caspt2.fh"
#include "pt2_guga.fh"
#include "WrkSpc.fh"
      INTEGER, INTENT(IN) :: nLev
      REAL*8, INTENT(IN) :: CI(NCONF)

      INTEGER LSGM1

      INTEGER I
      REAL*8 :: CLag(*), RDMEIG(*)


      IF(NLEV.GT.0) THEN
        CALL GETMEM('LSGM1','ALLO','REAL',LSGM1 ,MXCI)
        CALL DENS1_RPT2_CLag(CI,WORK(LSGM1),CLag,RDMEIG,nLev)
      END IF
C     return !! for test purpose

* REINITIALIZE USE OF DMAT.
* The fields IADR10 and CLAB10 are kept in common included from
! pt2_guga.fh
* CLAB10 replaces older field called LABEL.
      DO I=1,64
        IADR10(I,1)=-1
        IADR10(I,2)=0
        CLAB10(I)='   EMPTY'
      END DO
      IADR10(1,1)=0
* HENCEFORTH, THE CALL PUT(NSIZE,LABEL,ARRAY) WILL ENTER AN
* ARRAY ON LUDMAT AND UPDATE THE TOC.
      IF(NLEV.GT.0) THEN
        CALL GETMEM('LSGM1','FREE','REAL',LSGM1 ,MXCI)
      END IF


      RETURN
      END
C
C-----------------------------------------------------------------------
C
      SUBROUTINE DENS1_RPT2_CLag (CI,SGM1,CLag,RDMEIG,nLev)
! #ifdef _MOLCAS_MPP_
!       USE Para_Info, ONLY: Is_Real_Par, King
! #endif
      use gugx, only: SGS, L2ACT, CIS
      IMPLICIT NONE

#include "rasdim.fh"
#include "caspt2.fh"
#include "pt2_guga.fh"
#include "WrkSpc.fh"

      LOGICAL RSV_TSK
      INTEGER, INTENT(IN):: nLev
      REAL*8 CI(MXCI),SGM1(MXCI)
      REAL*8 CLag(nConf,nState),RDMEIG(NLEV,NLEV) !! Symmetry?

C     REAL*8 GTU

      INTEGER ID
      INTEGER IST,ISU,ISTU
      INTEGER IT,IU,LT,LU

      INTEGER ITASK,LTASK,LTASK2T,LTASK2U,NTASKS

      INTEGER ISSG,NSGM

* Purpose: Compute the 1-electron density matrix array G1.


* For the general cases, we use actual CI routine calls, and
* have to take account of orbital order.
* We will use level inices LT,LU... in these calls, but produce
* the density matrices with usual active orbital indices.
* Translation tables L2ACT and LEVEL, in pt2_guga.fh

* SVC20100311: set up a task table with LT,LU
* SB20190319: maybe it doesn't even make sense to parallelize the 1-RDM
      nTasks=(nLev**2+nLev)/2

      nTasks = nLev**2
      CALL GETMEM ('Tasks','ALLO','INTE',lTask,2*nTasks)
      lTask2T=lTask
      lTask2U=lTask+nTasks

      iTask=0
C     DO LT=1,nLev
C       DO LU=1,LT
C         iTask=iTask+1
C         iWork(lTask2T+iTask-1)=LT
C         iWork(lTask2U+iTask-1)=LU
C       ENDDO
C     ENDDO
      ! First, IL < JL pairs.
      Do LT = 1, nLev-1
        Do LU = LT+1, nLev
          iTask = iTask + 1
          iWork(lTask2T+iTask-1) = LT
          iWork(lTask2U+iTask-1) = LU
        End Do
      End Do
      ! Then, IL = JL pairs.
      Do LT = 1, nLev
        iTask = iTask + 1
        iWork(lTask2T+iTask-1) = LT
        iWork(lTask2U+iTask-1) = LT
      End Do
      ! Last, IL > JL pairs.
      Do LT = 2, nLev
        Do LU = 1, LT-1
          iTask = iTask + 1
          iWork(lTask2T+iTask-1) = LT
          iWork(lTask2U+iTask-1) = LU
        End Do
      End Do
      IF (iTask.NE.nTasks) WRITE(6,*) "ERROR nTasks"

      Call Init_Tsk(ID, nTasks)

* SVC20100311: BEGIN SEPARATE TASK EXECUTION
 500  If (.NOT.Rsv_Tsk (ID,iTask)) GOTO 501

* Compute SGM1 = E_UT acting on CI, with T.ge.U,
* i.e., lowering operations. These are allowed in RAS.
      LT=iWork(lTask2T+iTask-1)
        IST=SGS%ISM(LT)
        IT=L2ACT(LT)
        LU=iWork(lTask2U+iTask-1)
          ISU=SGS%ISM(LU)
          IU=L2ACT(LU)
          ISTU=MUL(IST,ISU)
          ISSG=MUL(ISTU,STSYM)
          NSGM=CIS%NCSF(ISSG)
          IF(NSGM.EQ.0) GOTO 500
* GETSGM2 computes E_UT acting on CI and saves it on SGM1
          CALL GETSGM2(LU,LT,STSYM,CI,SGM1)
          IF(ISTU.EQ.1) THEN
            ! Symmetry not yet
C            write(6,*) "it,iu = ", it,iu
            Call DaXpY_(NSGM,RDMEIG(IT,IU),SGM1,1,CLag,1)
C           if (IT.ne.IU)
C    *        Call DaXpY_(NSGM,2.0d+00*RDMEIG(IT,IU),SGM1,1,CLag,1)

C           GTU=DDOT_(NSGM,CI,1,SGM1,1)
C           G1(IT,IU)=GTU
C           G1(IU,IT)=GTU
          END IF

* SVC: The master node now continues to only handle task scheduling,
*     needed to achieve better load balancing. So it exits from the task
*      list. It has to do it here since each process gets at least one
*      task.
! #if defined (_MOLCAS_MPP_) && ! defined (_GA_)
!       IF (IS_REAL_PAR().AND.KING().AND.(NPROCS.GT.1)) GOTO 501
! #endif

      GOTO 500
 501  CONTINUE
C      write(6,*) "clag1"
C      do itask = 1, nsgm
C        write(6,'(i3,f20.10)') itask,clag(itask,1)
C        clag(itask,1) = 0.0d+00
C       end do
C           write(6,*) "nsgm = ", nsgm
C          do lu = 1, nlev
C          do lt = 1, nlev
C         CALL GETSGM2(LU,LT,STSYM,CI,SGM1)
C         write(6,*) "lu,lt = ", lu,lt
C           write(6,'(5f15.10)') (sgm1(itask),itask=1,nsgm)
C         Call DaXpY_(NSGM,2.0d+00*RDMEIG(lT,lU),SGM1,1,CLag,1)
C           GTU=DDOT_(NSGM,CI,1,SGM1,1)
C           write(6,'(2i3,f20.10)') lu,lt,gtu
C          end do
C          end do
C      write(6,*) "clag2"
C      do itask = 1, nsgm
C        write(6,'(i3,f20.10)') itask,clag(itask,1)
C       end do

      CALL Free_Tsk(ID)

      CALL GETMEM ('Tasks','FREE','INTE',lTask,2*nTasks)

C 99  CONTINUE


      RETURN
      END
C
C-----------------------------------------------------------------------
C
      SUBROUTINE MLTUNF2(LST,X)
      IMPLICIT REAL*8 (A-H,O-Z)
      DIMENSION X(*)
      DIMENSION LST(4,NLST1)
#include "sigma.fh"
      DO ILST=1,NLST1
        L1=LST(1,ILST)
        L2=LST(2,ILST)
        L3=LST(3,ILST)
        L4=LST(4,ILST)
        V=VAL1(L4)
        IY=1+INCY2*(L3-1)
        CALL DScal_(LEN1,V,X(IY),INCY1)
        write(6,'(5i4,f20.10,2i4)') ilst,l1,l2,l3,l4,v,iy,incy1
      END DO
      RETURN
      END
C
C-----------------------------------------------------------------------
C
      !! Taken from grdctl.f
      SUBROUTINE CLagX_TrfCI(CI)
C
      IMPLICIT REAL*8 (A-H,O-Z)
C
#include "rasdim.fh"
#include "caspt2.fh"
#include "WrkSpc.fh"
C
      DIMENSION CI(*)
C
      CALL DCOPY_(NTAT,[0.0D0],0,WORK(LTAT),1)
C
      IOFF1=0
      IOFF2=0
      DO ISYM=1,NSYM
        NI=NISH(ISYM)
        NR1=NRAS1(ISYM)
        NR2=NRAS2(ISYM)
        NR3=NRAS3(ISYM)
        NS=NSSH(ISYM)
* Skip inactive transformation matrix:
        IOFF1=IOFF1+NI**2
* Copy RAS1 transformation matrix transposed to TAT:
        DO I=1,NR1
          DO J=1,NR1
            IJ=I+NR1*(J-1)
            JI=J+NR1*(I-1)
            WORK(LTAT-1+IOFF2+JI)=WORK(LTORB-1+IOFF1+IJ)
          END DO
        END DO
        IOFF1=IOFF1+NR1**2
        IOFF2=IOFF2+NR1**2
* Copy RAS2 transformation matrix transposed to TAT:
        DO I=1,NR2
          DO J=1,NR2
            IJ=I+NR2*(J-1)
            JI=J+NR2*(I-1)
            WORK(LTAT-1+IOFF2+JI)=WORK(LTORB-1+IOFF1+IJ)
          END DO
        END DO
        IOFF1=IOFF1+NR2**2
        IOFF2=IOFF2+NR2**2
* Copy RAS2 transformation matrix transposed to TAT:
        DO I=1,NR3
          DO J=1,NR3
            IJ=I+NR3*(J-1)
            JI=J+NR3*(I-1)
            WORK(LTAT-1+IOFF2+JI)=WORK(LTORB-1+IOFF1+IJ)
          END DO
        END DO
        IOFF1=IOFF1+NR3**2
        IOFF2=IOFF2+NR3**2
* Skip virtual transformation matrix:
        IOFF1=IOFF1+NS**2
      END DO
C Transform SGM to use original MO:
      ITOEND=0
      NSG=NCONF
      DO ISYM=1,NSYM
        NI=NISH(ISYM)
        NR1=NRAS1(ISYM)
        NR2=NRAS2(ISYM)
        NR3=NRAS3(ISYM)
        NS=NSSH(ISYM)
        ITOSTA=ITOEND+1
        ITOEND=ITOEND+NR1**2+NR2**2+NR3**2
*        ITO=ITOSTA+NI**2
        ITO=ITOSTA
        IF(NR1.GT.0) THEN
          ISTART=NAES(ISYM)+1
          CALL TRACI_RPT2(ISTART,NR1,WORK(LTAT-1+ITO),STSYM,
     &                                         NSG,CI)
        END IF
        ITO=ITO+NR1**2
        IF(NR2.GT.0) THEN
          ISTART=NAES(ISYM)+NR1+1
          CALL TRACI_RPT2(ISTART,NR2,WORK(LTAT-1+ITO),STSYM,
     &                                         NSG,CI)
        END IF
        ITO=ITO+NR2**2
        IF(NR3.GT.0) THEN
          ISTART=NAES(ISYM)+NR1+NR2+1
         !! NR1 should be NR3?
          CALL TRACI_RPT2(ISTART,NR3,WORK(LTAT-1+ITO),STSYM,
     &                                         NSG,CI)
        END IF
      END DO
C
      RETURN
C
      END SUBROUTINE CLagX_TrfCI
C
C-----------------------------------------------------------------------
C
      Subroutine CLagSym(nAshT,DG1,DG2,DF1,DF2,mode)
C
      Implicit Real*8 (A-H,O-Z)
C
      Dimension DG1(nAshT,nAshT),DG2(nAshT,nAshT,nAshT,nAshT),
     *          DF1(nAshT,nAshT),DF2(nAshT,nAshT,nAshT,nAshT)
C
C     return
C     if (mode.eq.0) then
      Do iI = 1, nAshT
        Do iJ = 1, iI-1
          Val1 = DG1(iI,iJ)
          Val2 = DG1(iJ,iI)
          DG1(iI,iJ) = (Val1+Val2)*0.5D+00
          DG1(iJ,iI) = (Val1+Val2)*0.5D+00
          Val1 = DF1(iI,iJ)
          Val2 = DF1(iJ,iI)
          DF1(iI,iJ) = (Val1+Val2)*0.5D+00
          DF1(iJ,iI) = (Val1+Val2)*0.5D+00
        End Do
      End Do
C     end if
C
      If (mode.eq.0) Then
        !! Follow G2 symmetry
        Do iI = 1, nAshT
        Do iJ = 1, nAshT
        Do iK = 1, nAshT
        Do iL = 1, nAshT
            Val1 = DG2(iI,iJ,iK,iL)
            Val2 = DG2(iJ,iI,iL,iK)
            Val3 = DG2(iK,iL,iI,iJ)
            Val4 = DG2(iL,iK,iJ,iI)
            Val  = (Val1+Val2+Val3+Val4)*0.25D+00
            DG2(iI,iJ,iK,iL) = Val
            DG2(iJ,iI,iL,iK) = Val
            DG2(iK,iL,iI,iJ) = Val
            DG2(iL,iK,iJ,iI) = Val
            Val1 = DF2(iI,iJ,iK,iL)
            Val2 = DF2(iJ,iI,iL,iK)
            Val3 = DF2(iK,iL,iI,iJ)
            Val4 = DF2(iL,iK,iJ,iI)
            Val  = (Val1+Val2+Val3+Val4)*0.25D+00
            DF2(iI,iJ,iK,iL) = Val
            DF2(iJ,iI,iL,iK) = Val
            DF2(iK,iL,iI,iJ) = Val
            DF2(iL,iK,iJ,iI) = Val
        End Do
        End Do
        End Do
        End Do
      Else If (mode.eq.1) Then
        !! Follow EtuEyz symmetry
        Do iI = 1, nAshT
        Do iJ = 1, nAshT
        Do iK = 1, nAshT
        Do iL = 1, nAshT
            Val1 = DG2(iI,iJ,iK,iL)
            Val2 = DG2(iL,iK,iJ,iI)
            Val  = (Val1+Val2)*0.5D+00
          ! DG2(iI,iJ,iK,iL) = Val
          ! DG2(iL,iK,iJ,iI) = Val
C           if (ii.ne.il.and.ij.ne.ik) then
C           DG2(iI,iJ,iK,iL) = 2.0d+00*val
C           DG2(iL,iK,iJ,iI) = 0.0d+00
C           end if
            Val1 = DF2(iI,iJ,iK,iL)
            Val2 = DF2(iL,iK,iJ,iI)
            Val  = (Val1+Val2)*0.5D+00
          ! DF2(iI,iJ,iK,iL) = Val
          ! DF2(iL,iK,iJ,iI) = Val
C           if (ii.ne.il.and.ij.ne.ik) then
C           DF2(iI,iJ,iK,iL) = 2.0d+00*val
C           DF2(iL,iK,iJ,iI) = 0.0d+00
C           end if
        End Do
        End Do
        End Do
        End Do
C       write(6,*) "asdf"
C       Do iI = 1, nAshT
C       Do iJ = 1, iI
C       Do iK = 1, iJ
C       Do iL = 1, iK
C       write(6,'(4i3,f20.10)') ii,ij,ik,il,dg2(ii,ij,ik,il)
C       DG2(iI,iJ,iK,iL) = DG2(iI,iJ,iK,iL) + DG2(iL,iK,iJ,iI)
C       if (ii.ne.il.and.ij.ne.ik) DG2(iL,iK,iJ,iI) = 0.0D+00
C       DF2(iI,iJ,iK,iL) = DF2(iI,iJ,iK,iL) + DF2(iL,iK,iJ,iI)
C       if (ii.ne.il.and.ij.ne.ik) DF2(iL,iK,iJ,iI) = 0.0D+00
C       End Do
C       End Do
C       End Do
C       End Do
C       write(6,*) "asdf end"
      end if
C
      Do iI = 1, nAshT
        Do iJ = 1, nAshT ! iI
          Do iK = 1, nAshT ! iJ
            Do iL = 1, nAshT ! iK
C             Val1 = DG2(iI,iJ,iK,iL)
C             Val2 = DG2(iJ,iI,iL,iK)
C             Val3 = DG2(iK,iL,iI,iJ)
C             Val4 = DG2(iL,iK,iJ,iI)
C             Val  = (Val1+Val2+Val3+Val4)*0.25D+00
C             DG2(iI,iJ,iK,iL) = Val
C             DG2(iJ,iI,iL,iK) = Val
C             DG2(iK,iL,iI,iJ) = Val
C             DG2(iL,iK,iJ,iI) = Val
C             Val1 = DF2(iI,iJ,iK,iL)
C             Val2 = DF2(iJ,iI,iL,iK)
C             Val3 = DF2(iK,iL,iI,iJ)
C             Val4 = DF2(iL,iK,iJ,iI)
C             Val  = (Val1+Val2+Val3+Val4)*0.25D+00
C             DF2(iI,iJ,iK,iL) = Val
C             DF2(iJ,iI,iL,iK) = Val
C             DF2(iK,iL,iI,iJ) = Val
C             DF2(iL,iK,iJ,iI) = Val
C             Val1 = DF2(iI,iJ,iK,iL)
C             Val2 = DF2(iL,iK,iJ,iI)
C             Val  = (Val1+Val2)*0.5D+00
C             DF2(iI,iJ,iK,iL) = Val
C             DF2(iL,iK,iJ,iI) = Val
            End DO
          End Do
        End Do
      End Do
C
      Return
C
      End Subroutine CLagSym
C
C-----------------------------------------------------------------------
C
      Subroutine CLagDXA_FG3(iSym,nAS,NG3,BDER,SDER,
     *                       DF1,DF2,DF3,DG1,DG2,DG3,DEPSA,
     *                       G2,SC,idxG3)
C
      USE SUPERINDEX
C
      Implicit Real*8 (A-H,O-Z)
C
#include "rasdim.fh"
#include "caspt2.fh"
#include "eqsolv.fh"
#include "WrkSpc.fh"
C
      Dimension BDER(nAS,nAS),SDER(nAS,nAS),DF3(*),DG3(*)
      Dimension DF1(nAshT,nAshT),DF2(nAshT,nAshT,nAshT,nAshT),
     *          DG1(nAshT,nAshT),DG2(nAshT,nAshT,nAshT,nAshT),
     *          DEPSA(nAshT,nAshT)
      Dimension G2(nAshT,nAshT,nAshT,nAshT)
      DIMENSION SC(*)
      INTEGER*1 idxG3(6,NG3)
C
      DO iG3=1,NG3
        iT=idxG3(1,iG3)
        iU=idxG3(2,iG3)
        iV=idxG3(3,iG3)
        iX=idxG3(4,iG3)
        iY=idxG3(5,iG3)
        iZ=idxG3(6,iG3)
        iST=IASYM(iT)
        iSU=IASYM(iU)
        iSV=IASYM(iV)
        iSX=IASYM(iX)
        iSY=IASYM(iY)
        iSZ=IASYM(iZ)
        ituvs=MUL(IST,MUL(ISU,ISV))
        ixyzs=MUL(ISX,MUL(ISY,ISZ))
        F3VAL=0.0D+00
        G3VAL=0.0D+00
        if(ituvs.ne.ixyzs) goto 500
        iTU=iT+NASHT*(iU-1)
        iVX=iV+NASHT*(iX-1)
        iYZ=iY+NASHT*(iZ-1)
C-SVC20100829: 12 equivalent cases, of which the second
C  half reflects the S(tuv,xyz)=S(xyz,tuv) symmetry:
C  - G(tuvxyz) -> SA(xut,vyz)
        jSYM=MUL(IASYM(iX),MUL(IASYM(iU),IASYM(iT)))
        IF (jSYM.EQ.iSYM) THEN
          ISUP=KTUV(iX,iU,iT)-nTUVES(jSYM)
          JSUP=KTUV(iV,iY,iZ)-nTUVES(jSYM)
          F3VAL = F3VAL + BDER(iSup,jSup)
          G3VAL = G3VAL + SDER(iSup,jSup)
        ENDIF
        if (iTU.eq.iVX.and.iVX.eq.iYZ) go to 300
        if (iTU.eq.iVX.or.iTU.eq.iYZ.or.iVX.eq.iYZ) go to 200
C  - G(vxtuyz) -> SA(uxv,tyz)
        jSYM=MUL(IASYM(iU),MUL(IASYM(iX),IASYM(iV)))
        IF (jSYM.EQ.iSYM) THEN
          ISUP=KTUV(iU,iX,iV)-nTUVES(jSYM)
          JSUP=KTUV(iT,iY,iZ)-nTUVES(jSYM)
          F3VAL = F3VAL + BDER(iSup,jSup)
          G3VAL = G3VAL + SDER(iSup,jSup)
        ENDIF
C  - G(yzvxtu) -> SA(xzy,vtu)
        jSYM=MUL(IASYM(iX),MUL(IASYM(iZ),IASYM(iY)))
        IF (jSYM.EQ.iSYM) THEN
          ISUP=KTUV(iX,iZ,iY)-nTUVES(jSYM)
          JSUP=KTUV(iV,iT,iU)-nTUVES(jSYM)
          F3VAL = F3VAL + BDER(iSup,jSup)
          G3VAL = G3VAL + SDER(iSup,jSup)
        ENDIF
C  - G(tuyzvx) -> SA(zut,yvx)
        jSYM=MUL(IASYM(iZ),MUL(IASYM(iU),IASYM(iT)))
        IF (jSYM.EQ.iSYM) THEN
          ISUP=KTUV(iZ,iU,iT)-nTUVES(jSYM)
          JSUP=KTUV(iY,iV,iX)-nTUVES(jSYM)
          F3VAL = F3VAL + BDER(iSup,jSup)
          G3VAL = G3VAL + SDER(iSup,jSup)
        ENDIF
 200   CONTINUE
C  - G(yztuvx) -> SA(uzy,tvx)
        jSYM=MUL(IASYM(iU),MUL(IASYM(iZ),IASYM(iY)))
        IF (jSYM.EQ.iSYM) THEN
          ISUP=KTUV(iU,iZ,iY)-nTUVES(jSYM)
          JSUP=KTUV(iT,iV,iX)-nTUVES(jSYM)
          F3VAL = F3VAL + BDER(iSup,jSup)
          G3VAL = G3VAL + SDER(iSup,jSup)
        ENDIF
C  - G(vxyztu) -> SA(zxv,ytu)
        jSYM=MUL(IASYM(iZ),MUL(IASYM(iX),IASYM(iV)))
        IF (jSYM.EQ.iSYM) THEN
          ISUP=KTUV(iZ,iX,iV)-nTUVES(jSYM)
          JSUP=KTUV(iY,iT,iU)-nTUVES(jSYM)
          F3VAL = F3VAL + BDER(iSup,jSup)
          G3VAL = G3VAL + SDER(iSup,jSup)
        ENDIF
 300   CONTINUE
        if (iT.eq.iU.and.iV.eq.iX.and.iY.eq.iZ) go to 500
        if (iT.eq.iU.and.iV.eq.iZ.and.iX.eq.iY) go to 500
        if (iX.eq.iV.and.iT.eq.iZ.and.iU.eq.iY) go to 500
        if (iZ.eq.iY.and.iV.eq.iU.and.iX.eq.iT) go to 500
C  - G(utxvzy) -> SA(vtu,xzy)
        jSYM=MUL(IASYM(iV),MUL(IASYM(iT),IASYM(iU)))
        IF (jSYM.EQ.iSYM) THEN
          ISUP=KTUV(iV,iT,iU)-nTUVES(jSYM)
          JSUP=KTUV(iX,iZ,iY)-nTUVES(jSYM)
          F3VAL = F3VAL + BDER(iSup,jSup)
          G3VAL = G3VAL + SDER(iSup,jSup)
        ENDIF
        if (iTU.eq.iVX.and.iVX.eq.iYZ) go to 500
        if (iTU.eq.iVX.or.iTU.eq.iYZ.or.iVX.eq.iYZ) go to 400
C  - G(xvutzy) -> SA(tvx,uzy)
        jSYM=MUL(IASYM(iT),MUL(IASYM(iV),IASYM(iX)))
        IF (jSYM.EQ.iSYM) THEN
          ISUP=KTUV(iT,iV,iX)-nTUVES(jSYM)
          JSUP=KTUV(iU,iZ,iY)-nTUVES(jSYM)
          F3VAL = F3VAL + BDER(iSup,jSup)
          G3VAL = G3VAL + SDER(iSup,jSup)
        ENDIF
C  - G(zyxvut) -> SA(vyz,xut)
        jSYM=MUL(IASYM(iV),MUL(IASYM(iY),IASYM(iZ)))
        IF (jSYM.EQ.iSYM) THEN
          ISUP=KTUV(iV,iY,iZ)-nTUVES(jSYM)
          JSUP=KTUV(iX,iU,iT)-nTUVES(jSYM)
          F3VAL = F3VAL + BDER(iSup,jSup)
          G3VAL = G3VAL + SDER(iSup,jSup)
        ENDIF
C  - G(utzyxv) -> SA(ytu,zxv)
        jSYM=MUL(IASYM(iY),MUL(IASYM(iT),IASYM(iU)))
        IF (jSYM.EQ.iSYM) THEN
          ISUP=KTUV(iY,iT,iU)-nTUVES(jSYM)
          JSUP=KTUV(iZ,iX,iV)-nTUVES(jSYM)
          F3VAL = F3VAL + BDER(iSup,jSup)
          G3VAL = G3VAL + SDER(iSup,jSup)
        ENDIF
 400   CONTINUE
C  - G(zyutxv) -> SA(tyz,uxv)
        jSYM=MUL(IASYM(iT),MUL(IASYM(iY),IASYM(iZ)))
        IF (jSYM.EQ.iSYM) THEN
          ISUP=KTUV(iT,iY,iZ)-nTUVES(jSYM)
          JSUP=KTUV(iU,iX,iV)-nTUVES(jSYM)
          F3VAL = F3VAL + BDER(iSup,jSup)
          G3VAL = G3VAL + SDER(iSup,jSup)
        ENDIF
C  - G(xvzyut) -> SA(yvx,zut)
        jSYM=MUL(IASYM(iY),MUL(IASYM(iV),IASYM(iX)))
        IF (jSYM.EQ.iSYM) THEN
          ISUP=KTUV(iY,iV,iX)-nTUVES(jSYM)
          JSUP=KTUV(iZ,iU,iT)-nTUVES(jSYM)
          F3VAL = F3VAL + BDER(iSup,jSup)
          G3VAL = G3VAL + SDER(iSup,jSup)
        ENDIF
 500   CONTINUE
C
        F3VAL = -F3VAL
        G3VAL = -G3VAL
C
        !! last line of F3 transformation in mkfg3.f
        G3VAL = G3VAL - (EPSA(iU)+EPSA(iY))*F3VAL
        Do iW = 1, nAshT
          ISUP=KTUV(iV,iW,iT)-nTUVES(iSYM)
          JSUP=KTUV(iX,iY,iZ)-nTUVES(iSYM)
          NSEQ=MAX(iSup,jSup)*(MAX(iSup,jSup)-1)/2 + MIN(iSup,jSup)
          DEPSA(iW,iU) = DEPSA(iW,iU) - F3VAL*SC(NSEQ)
C
          ISUP=KTUV(iV,iU,iT)-nTUVES(iSYM)
          JSUP=KTUV(iX,iW,iZ)-nTUVES(iSYM)
          NSEQ=MAX(iSup,jSup)*(MAX(iSup,jSup)-1)/2 + MIN(iSup,jSup)
          DEPSA(iW,iY) = DEPSA(iW,iY) - F3VAL*SC(NSEQ)
        End Do
C
        !! derivative of <0|EtuEwv,xwEyz|0>*fww
        DF3(iG3) = DF3(iG3) + F3VAL
        !! derivative of <0|EtuEvxEyz|0>
        DG3(iG3) = DG3(iG3) + G3VAL
C
        !! remaining F3 and G3 transformation in mkfg3.f
        If (iY.eq.iX) Then
          DF2(iT,iU,iV,iZ) = DF2(iT,iU,iV,iZ) - F3VAL
          DG2(iT,iU,iV,iZ) = DG2(iT,iU,iV,iZ) - EPSA(iU)*F3VAL
          Do iW = 1, nAshT
            DEPSA(iU,iW) = DEPSA(iU,iW) - F3VAL*G2(iT,iW,iV,iZ)
          End Do
          DG2(iT,iU,iV,iZ) = DG2(iT,iU,iV,iZ) - G3VAL
        End If
        If (iV.eq.iU) Then
          DF2(iT,iX,iY,iZ) = DF2(iT,iX,iY,iZ) - F3VAL
          DG2(iT,iX,iY,iZ) = DG2(iT,iX,iY,iZ) - EPSA(iY)*F3VAL
          Do iW = 1, nAshT
            DEPSA(iW,iY) = DEPSA(iW,iY) - F3VAL*G2(iT,iX,iW,iZ)
          End Do
          DG2(iT,iX,iY,iZ) = DG2(iT,iX,iY,iZ) - G3VAL
        End If
        If (iY.eq.iU) Then
          DF2(iV,iX,iT,iZ) = DF2(iV,iX,iT,iZ) - F3VAL
          DG2(iV,iX,iT,iZ) = DG2(iV,iX,iT,iZ) - EPSA(iU)*F3VAL
          DG2(iV,iX,iT,iZ) = DG2(iV,iX,iT,iZ) - G3VAL
        End If
        DEPSA(iY,iU) = DEPSA(iY,iU) - F3VAL*G2(iV,iX,iT,iZ)
        If (iY.eq.iX.and.iV.eq.iU) Then
          DF1(iT,iZ) = DF1(iT,iZ) - F3VAL
          DG1(iT,iZ) = DG1(iT,iZ) - G3VAL
        End If
      END DO
C
      Return
C
      End Subroutine CLagDXA_FG3
C
C-----------------------------------------------------------------------
C
      Subroutine CLagDXA_DP(iSym,nAS,BDER,SDER,DF2,DG2,DF1,DG1,
     *                      DEPSA,DEASUM,iLo,iHi,jLo,jHi,LDA,g1,g2,sa)
C
      USE SUPERINDEX
      use caspt2_global, only:ipea_shift
C
      Implicit Real*8 (A-H,O-Z)
C
#include "rasdim.fh"
#include "caspt2.fh"
#include "eqsolv.fh"
#include "WrkSpc.fh"
C
      Dimension BDER(*),SDER(*),
     *          DF2(nAshT,nAshT,nAshT,nAshT),
     *          DG2(nAshT,nAshT,nAshT,nAshT),
     *          DF1(nAshT,nAshT),DG1(nAshT,nAshT),DEPSA(nAshT,nAshT)
      dimension g1(nAshT,nAshT),G2(nAshT,nAshT,nasht,nasht),sa(*)
C     INTEGER*1 idxG3(6,NG3)
C
      ISADR=0
      if (isadr.ne.0) write (6,*) lda !! just for avoid compiling error
      DO 100 IXYZ=jLo,jHi
        IXYZABS=IXYZ+NTUVES(ISYM)
        IXABS=MTUV(1,IXYZABS)
        IYABS=MTUV(2,IXYZABS)
        IZABS=MTUV(3,IXYZABS)
        EX=EPSA(IXABS)
        EY=EPSA(IYABS)
        DO 101 ITUV=iLo,iHi
          ITUVABS=ITUV+NTUVES(ISYM)
          ITABS=MTUV(1,ITUVABS)
          IUABS=MTUV(2,ITUVABS)
          IVABS=MTUV(3,ITUVABS)
          ET=EPSA(ITABS)
          EU=EPSA(IUABS)
          ETU=ET+EU
          FACT=EY+EU+EX+ET-EASUM
        ! IF (LDC.NE.0) THEN
C       !   VALUE=SC(1+iTUV-iLo+LDC*(iXYZ-jLo))
        !   ValS=SDER(1+iTUV-iLo+LDC*(iXYZ-jLo))
        ! ELSE
        !   IF (IXYZ.LE.ITUV) THEN
        !     ISADR=(ITUV*(ITUV-1))/2+IXYZ
C             VALUE=SC(ISADR)
            iSAdr=iTUV+nAS*(iXYZ-1)
            ValB=BDER(ISADR)
C
            If (iTUV.eq.iXYZ.and.ipea_shift.ne.0.0D+00) Then
C             !! BA in the next equation refers to the active overlap
C       ipea_shift*0.5d0*BA(ISADR)*(2.0d0-DREF(IDV)+DREF(IDT)+DREF(IDU))
              bsBDER = ipea_shift*0.5D+00*ValB
              SDER(iSAdr) = SDER(iSAdr) + bsBDER*(2.0D+00
     *          +G1(iTabs,iTabs)+G1(iUabs,iUabs)-G1(iVabs,iVabs))
              iSAdr2 = iTUV*(iTUV+1)/2
              DG1(iTabs,iTabs) = DG1(iTabs,iTabs) + bsBDER*SA(iSAdr2)
              DG1(iUabs,iUabs) = DG1(iUabs,iUabs) + bsBDER*SA(iSAdr2)
              DG1(iVabs,iVabs) = DG1(iVabs,iVabs) - bsBDER*SA(iSAdr2)
            End If
C
            !! First VALUE contribution in MKBC_DP (FACT)
            SDER(ISADR) = SDER(ISADR) + FACT*ValB
            ValS=SDER(ISADR)
C
          Do iWabs = 1, nAshT
            !! EU derivative
            iTWV = iTabs+nAshT*(iWabs-1)+nAshT**2*(iVabs-1)
            iSAdr2 = Max(iTWV,iXYZ)*(Max(iTWV,iXYZ)-1)/2
     *             + Min(iTWV,iXYZ)
            DEPSA(iWabs,iUabs) = DEPSA(iWabs,iUabs)
     *        + ValB*SA(iSAdr2)
C
            !! EY derivative
            iXWZ = iXabs+nAshT*(iWabs-1)+nAshT**2*(iZabs-1)
            iSAdr2 = Max(iTUV,iXWZ)*(Max(iTUV,iXWZ)-1)/2
     *             + Min(iTUV,iXWZ)
            DEPSA(iWabs,iYabs) = DEPSA(iWabs,iYabs)
     *        + ValB*SA(iSAdr2)
C
            !! EX derivative
            iWYZ = iWabs+nAshT*(iYabs-1)+nAshT**2*(iZabs-1)
            iSAdr2 = Max(iTUV,iWYZ)*(Max(iTUV,iWYZ)-1)/2
     *             + Min(iTUV,iWYZ)
            DEPSA(iWabs,iXabs) = DEPSA(iWabs,iXabs)
     *        + ValB*SA(iSAdr2)
C
            !! ET derivative
            iWUV = iWabs+nAshT*(iUabs-1)+nAshT**2*(iVabs-1)
            iSAdr2 = Max(iWUV,iXYZ)*(Max(iWUV,iXYZ)-1)/2
     *             + Min(iWUV,iXYZ)
            DEPSA(iWabs,iTabs) = DEPSA(iWabs,iTabs)
     *        + ValB*SA(iSAdr2)
          End Do

          iSAdr = Max(iTUV,iXYZ)*(Max(iTUV,iXYZ)-1)/2
     *          + Min(iTUV,iXYZ)
          DEASUM = DEASUM - ValB*SA(iSAdr)
C
C         2dtx ( Fvuyz-Et*Gvuyz )
C         2 dtx Gvuyz + 2 dtx dyu Gvz
          If (iTabs.eq.iXabs) Then
            !! VALUE=VALUE+4.0D0*(FP(IP)-ET*PREF(IP))
            DF2(iVabs,iUabs,iYabs,iZabs)
     *        = DF2(iVabs,iUabs,iYabs,iZabs) + 2.0D+00*ValB
            DG2(iVabs,iUabs,iYabs,iZabs)
     *        = DG2(iVabs,iUabs,iYabs,iZabs) - 2.0D+00*ET*ValB
C
            !! VALUE=VALUE+4.0D0*PREF(IP)
            DG2(iVabs,iUabs,iYabs,iZabs)
     *        = DG2(iVabs,iUabs,iYabs,iZabs) + 2.0D+00*ValS
            If (iYabs.eq.iUabs) Then
              !! VALUE=VALUE+2.0D0*DREF(ID)
              DG1(iVabs,iZabs) = DG1(iVabs,iZabs) + 2.0D+00*ValS
            End If
          End If
          DEPSA(iTabs,iXabs) = DEPSA(iTabs,iXabs)
     *      -2.0D+00*ValB*G2(iVabs,iUabs,iYabs,iZabs)
C
C         dxu ( -Fvtyz + Eu*Gvtyz )
C         -dxu Gvtyz -dxu dyt Gvz
          If (iXabs.eq.iUabs) Then
            !! VALUE=VALUE-2.0D0*(FP(IP)-EU*PREF(IP))
            DF2(iVabs,iTabs,iYabs,iZabs)
     *        = DF2(iVabs,iTabs,iYabs,iZabs) - ValB
            DG2(iVabs,iTabs,iYabs,iZabs)
     *        = DG2(iVabs,iTabs,iYabs,iZabs) + EU*ValB
            !! VALUE=VALUE - 2.0D0*PREF(IP)
            DG2(iVabs,iTabs,iYabs,iZabs)
     *        = DG2(iVabs,iTabs,iYabs,iZabs) - ValS
            If (iYabs.eq.iTabs) Then
              !! VALUE=VALUE - DREF(ID)
              DG1(iVabs,iZabs) = DG1(iVabs,iZabs) - ValS
            End If
          End If
          DEPSA(iXabs,iUabs) = DEPSA(iXabs,iUabs)
     *      + ValB*G2(iVabs,iTabs,iYabs,iZabs)
C
C         dyt ( -Fvuxz + Et*Gvuxz +dxu (-Fvz+(Et+Eu)*Gvz))
C         -dyt Gvuxz
          If (iYabs.eq.iTabs) Then
            !! VALUE=VALUE-2.0D0*(FP(IP)-ET*PREF(IP))
            DF2(iVabs,iUabs,iXabs,iZabs)
     *        = DF2(iVabs,iUabs,iXabs,iZabs) - ValB
            DG2(iVabs,iUabs,iXabs,iZabs)
     *        = DG2(iVabs,iUabs,iXabs,iZabs) + ET*ValB
            If (iXabs.eq.iUabs) Then
              !! VALUE=VALUE - (FD(ID)-ETU*DREF(ID))
              DF1(iVabs,iZabs) = DF1(iVabs,iZabs) - ValB
              DG1(iVabs,iZabs) = DG1(iVabs,iZabs) + ETU*ValB
            End If
C
            !! VALUE=VALUE - 2.0D0*PREF(IP)
            DG2(iVabs,iUabs,iXabs,iZabs)
     *        = DG2(iVabs,iUabs,iXabs,iZabs) - ValS
          End If
          DEPSA(iYabs,iTabs) = DEPSA(iYabs,iTabs)
     *      + ValB*G2(iVabs,iUabs,iXabs,iZabs)
          If (iYabs.eq.iTabs)
     *    DEPSA(iXabs,iUabs) = DEPSA(iXabs,iUabs) + ValB*G1(iVabs,iZabs)
          If (iXabs.eq.iUabs)
     *    DEPSA(iYabs,iTabs) = DEPSA(iYabs,iTabs) + ValB*G1(iVabs,iZabs)
C
C         -dyu Gvzxt
          If (iYabs.eq.iUabs) Then
            !! VALUE=VALUE-2.0D0*(FP(IP)-EU*PREF(IP))
            DF2(iVabs,iZabs,iXabs,iTabs)
     *        = DF2(iVabs,iZabs,iXabs,iTabs) - ValB
            DG2(iVabs,iZabs,iXabs,iTabs)
     *        = DG2(iVabs,iZabs,iXabs,iTabs) + EU*ValB
            If (iXabs.eq.iTabs) Then
              !! VALUE=VALUE+2.0D0*(FD(ID)-ETU*DREF(ID))
              DF1(iVabs,iZabs) = DF1(iVabs,iZabs) + 2.0D+00*ValB
              DG1(iVabs,iZabs) = DG1(iVabs,iZabs) - 2.0D+00*ETU*ValB
            End If
C
            !! VALUE=VALUE - 2.0D0*PREF(IP)
            DG2(iVabs,iZabs,iXabs,iTabs)
     *        = DG2(iVabs,iZabs,iXabs,iTabs) - ValS
          End If
          DEPSA(iYabs,iUabs) = DEPSA(iYabs,iUabs)
     *      + ValB*G2(iVabs,iZabs,iXabs,iTabs)
          If (iYabs.eq.iUabs) DEPSA(iXabs,iTabs) = DEPSA(iXabs,iTabs)
     *      - 2.0D+00*ValB*G1(iVabs,iZabs)
          If (iXabs.eq.iTabs) DEPSA(iYabs,iUabs) = DEPSA(iYabs,iUabs)
     *      - 2.0D+00*ValB*G1(iVabs,iZabs)
 101    CONTINUE
 100  CONTINUE
C
      Return
C
      End Subroutine CLagDXA_DP
C
C-----------------------------------------------------------------------
C
      Subroutine CLagDXC_FG3(iSym,nAS,NG3,BDER,SDER,
     *                       DF1,DF2,DF3,DG1,DG2,DG3,DEPSA,
     *                       G2,SC,idxG3)
C
      USE SUPERINDEX
C
      Implicit Real*8 (A-H,O-Z)
C
#include "rasdim.fh"
#include "caspt2.fh"
#include "eqsolv.fh"
#include "WrkSpc.fh"
C
      Dimension BDER(nAS,nAS),SDER(nAS,nAS),DF3(*),DG3(*)
      Dimension DF1(nAshT,nAshT),DF2(nAshT,nAshT,nAshT,nAshT),
     *          DG1(nAshT,nAshT),DG2(nAshT,nAshT,nAshT,nAshT),
     *          DEPSA(nAshT,nAshT)
      Dimension G2(nAshT,nAshT,nAshT,nAshT)
      DIMENSION SC(*)
      INTEGER*1 idxG3(6,NG3)
C
      DO iG3=1,NG3
        iT=idxG3(1,iG3)
        iU=idxG3(2,iG3)
        iV=idxG3(3,iG3)
        iX=idxG3(4,iG3)
        iY=idxG3(5,iG3)
        iZ=idxG3(6,iG3)
        iST=IASYM(iT)
        iSU=IASYM(iU)
        iSV=IASYM(iV)
        iSX=IASYM(iX)
        iSY=IASYM(iY)
        iSZ=IASYM(iZ)
        ituvs=MUL(IST,MUL(ISU,ISV))
        ixyzs=MUL(ISX,MUL(ISY,ISZ))
        F3VAL=0.0D+00
        G3VAL=0.0D+00
        if(ituvs.ne.ixyzs) goto 500
        iTU=iT+NASHT*(iU-1)
        iVX=iV+NASHT*(iX-1)
        iYZ=iY+NASHT*(iZ-1)
C-SVC20100829: 12 equivalent cases, of which the second
C  half reflects the S(tuv,xyz)=S(xyz,tuv) symmetry:
C  - G(tuvxyz) -> SC(vut,xyz)
        jSYM=MUL(IASYM(iV),MUL(IASYM(iU),IASYM(iT)))
        IF (jSYM.EQ.iSYM) THEN
          ISUP=KTUV(iV,iU,iT)-nTUVES(jSYM)
          JSUP=KTUV(iX,iY,iZ)-nTUVES(jSYM)
          F3VAL = F3VAL + BDER(iSup,jSup)
          G3VAL = G3VAL + SDER(iSup,jSup)
        ENDIF
        if (iTU.eq.iVX.and.iVX.eq.iYZ) go to 300
        if (iTU.eq.iVX.or.iTU.eq.iYZ.or.iVX.eq.iYZ) go to 200
C  - G(vxtuyz) -> SC(txv,uyz)
        jSYM=MUL(IASYM(iT),MUL(IASYM(iX),IASYM(iV)))
        IF (jSYM.EQ.iSYM) THEN
          ISUP=KTUV(iT,iX,iV)-nTUVES(jSYM)
          JSUP=KTUV(iU,iY,iZ)-nTUVES(jSYM)
          F3VAL = F3VAL + BDER(iSup,jSup)
          G3VAL = G3VAL + SDER(iSup,jSup)
        ENDIF
C  - G(yzvxtu) -> SC(vzy,xtu)
        jSYM=MUL(IASYM(iV),MUL(IASYM(iZ),IASYM(iY)))
        IF (jSYM.EQ.iSYM) THEN
          ISUP=KTUV(iV,iZ,iY)-nTUVES(jSYM)
          JSUP=KTUV(iX,iT,iU)-nTUVES(jSYM)
          F3VAL = F3VAL + BDER(iSup,jSup)
          G3VAL = G3VAL + SDER(iSup,jSup)
        ENDIF
C  - G(tuyzvx) -> SC(yut,zvx)
        jSYM=MUL(IASYM(iY),MUL(IASYM(iU),IASYM(iT)))
        IF (jSYM.EQ.iSYM) THEN
          ISUP=KTUV(iY,iU,iT)-nTUVES(jSYM)
          JSUP=KTUV(iZ,iV,iX)-nTUVES(jSYM)
          F3VAL = F3VAL + BDER(iSup,jSup)
          G3VAL = G3VAL + SDER(iSup,jSup)
        ENDIF
 200   CONTINUE
C  - G(yztuvx) -> SC(tzy,uvx)
        jSYM=MUL(IASYM(iT),MUL(IASYM(iZ),IASYM(iY)))
        IF (jSYM.EQ.iSYM) THEN
          ISUP=KTUV(iT,iZ,iY)-nTUVES(jSYM)
          JSUP=KTUV(iU,iV,iX)-nTUVES(jSYM)
          F3VAL = F3VAL + BDER(iSup,jSup)
          G3VAL = G3VAL + SDER(iSup,jSup)
        ENDIF
C  - G(vxyztu) -> SC(yxv,ztu)
        jSYM=MUL(IASYM(iY),MUL(IASYM(iX),IASYM(iV)))
        IF (jSYM.EQ.iSYM) THEN
          ISUP=KTUV(iY,iX,iV)-nTUVES(jSYM)
          JSUP=KTUV(iZ,iT,iU)-nTUVES(jSYM)
          F3VAL = F3VAL + BDER(iSup,jSup)
          G3VAL = G3VAL + SDER(iSup,jSup)
        ENDIF
 300   CONTINUE
        if (iT.eq.iU.and.iV.eq.iX.and.iY.eq.iZ) go to 500
        if (iT.eq.iU.and.iV.eq.iZ.and.iX.eq.iY) go to 500
        if (iX.eq.iV.and.iT.eq.iZ.and.iU.eq.iY) go to 500
        if (iZ.eq.iY.and.iV.eq.iU.and.iX.eq.iT) go to 500
C  - G(utxvzy) -> SC(xtu,vzy)
        jSYM=MUL(IASYM(iX),MUL(IASYM(iT),IASYM(iU)))
        IF (jSYM.EQ.iSYM) THEN
          ISUP=KTUV(iX,iT,iU)-nTUVES(jSYM)
          JSUP=KTUV(iV,iZ,iY)-nTUVES(jSYM)
          F3VAL = F3VAL + BDER(iSup,jSup)
          G3VAL = G3VAL + SDER(iSup,jSup)
        ENDIF
        if (iTU.eq.iVX.and.iVX.eq.iYZ) go to 500
        if (iTU.eq.iVX.or.iTU.eq.iYZ.or.iVX.eq.iYZ) go to 400
C  - G(xvutzy) -> SC(uvx,tzy)
        jSYM=MUL(IASYM(iU),MUL(IASYM(iV),IASYM(iX)))
        IF (jSYM.EQ.iSYM) THEN
          ISUP=KTUV(iU,iV,iX)-nTUVES(jSYM)
          JSUP=KTUV(iT,iZ,iY)-nTUVES(jSYM)
          F3VAL = F3VAL + BDER(iSup,jSup)
          G3VAL = G3VAL + SDER(iSup,jSup)
        ENDIF
C  - G(zyxvut) -> SC(xyz,vut)
        jSYM=MUL(IASYM(iX),MUL(IASYM(iY),IASYM(iZ)))
        IF (jSYM.EQ.iSYM) THEN
          ISUP=KTUV(iX,iY,iZ)-nTUVES(jSYM)
          JSUP=KTUV(iV,iU,iT)-nTUVES(jSYM)
          F3VAL = F3VAL + BDER(iSup,jSup)
          G3VAL = G3VAL + SDER(iSup,jSup)
        ENDIF
C  - G(utzyxv) -> SC(ztu,yxv)
        jSYM=MUL(IASYM(iZ),MUL(IASYM(iT),IASYM(iU)))
        IF (jSYM.EQ.iSYM) THEN
          ISUP=KTUV(iZ,iT,iU)-nTUVES(jSYM)
          JSUP=KTUV(iY,iX,iV)-nTUVES(jSYM)
          F3VAL = F3VAL + BDER(iSup,jSup)
          G3VAL = G3VAL + SDER(iSup,jSup)
        ENDIF
 400   CONTINUE
C  - G(zyutxv) -> SC(uyz,txv)
        jSYM=MUL(IASYM(iU),MUL(IASYM(iY),IASYM(iZ)))
        IF (jSYM.EQ.iSYM) THEN
          ISUP=KTUV(iU,iY,iZ)-nTUVES(jSYM)
          JSUP=KTUV(iT,iX,iV)-nTUVES(jSYM)
          F3VAL = F3VAL + BDER(iSup,jSup)
          G3VAL = G3VAL + SDER(iSup,jSup)
        ENDIF
C  - G(xvzyut) -> SC(zvx,yut)
        jSYM=MUL(IASYM(iZ),MUL(IASYM(iV),IASYM(iX)))
        IF (jSYM.EQ.iSYM) THEN
          ISUP=KTUV(iZ,iV,iX)-nTUVES(jSYM)
          JSUP=KTUV(iY,iU,iT)-nTUVES(jSYM)
          F3VAL = F3VAL + BDER(iSup,jSup)
          G3VAL = G3VAL + SDER(iSup,jSup)
        ENDIF
 500   CONTINUE
C
        !! last line of F3 transformation in mkfg3.f
C     g3val=0.0d+00 ! asdf
        G3VAL = G3VAL - (EPSA(iU)+EPSA(iY))*F3VAL
        Do iW = 1, nAshT
          ISUP=KTUV(iV,iW,iT)-nTUVES(iSYM)
          JSUP=KTUV(iX,iY,iZ)-nTUVES(iSYM)
          NSEQ=MAX(iSup,jSup)*(MAX(iSup,jSup)-1)/2 + MIN(iSup,jSup)
          DEPSA(iW,iU) = DEPSA(iW,iU) - F3VAL*SC(NSEQ)
C
          ISUP=KTUV(iV,iU,iT)-nTUVES(iSYM)
          JSUP=KTUV(iX,iW,iZ)-nTUVES(iSYM)
          NSEQ=MAX(iSup,jSup)*(MAX(iSup,jSup)-1)/2 + MIN(iSup,jSup)
          DEPSA(iW,iY) = DEPSA(iW,iY) - F3VAL*SC(NSEQ)
        End Do
C
        !! derivative of <0|EtuEwv,xwEyz|0>*fww
        DF3(iG3) = DF3(iG3) + F3VAL
        !! derivative of <0|EtuEvxEyz|0>
        DG3(iG3) = DG3(iG3) + G3VAL
C
        !! remaining F3 and G3 transformation in mkfg3.f
        If (iY.eq.iX) Then
          DF2(iT,iU,iV,iZ) = DF2(iT,iU,iV,iZ) - F3VAL
          DG2(iT,iU,iV,iZ) = DG2(iT,iU,iV,iZ) - EPSA(iU)*F3VAL
          Do iW = 1, nAshT
            DEPSA(iU,iW) = DEPSA(iU,iW) - F3VAL*G2(iT,iW,iV,iZ)
          End Do
          DG2(iT,iU,iV,iZ) = DG2(iT,iU,iV,iZ) - G3VAL
        End If
        If (iV.eq.iU) Then
          DF2(iT,iX,iY,iZ) = DF2(iT,iX,iY,iZ) - F3VAL
          DG2(iT,iX,iY,iZ) = DG2(iT,iX,iY,iZ) - EPSA(iY)*F3VAL
          Do iW = 1, nAshT
            DEPSA(iW,iY) = DEPSA(iW,iY) - F3VAL*G2(iT,iX,iW,iZ)
          End Do
          DG2(iT,iX,iY,iZ) = DG2(iT,iX,iY,iZ) - G3VAL
        End If
        If (iY.eq.iU) Then
          DF2(iV,iX,iT,iZ) = DF2(iV,iX,iT,iZ) - F3VAL
          DG2(iV,iX,iT,iZ) = DG2(iV,iX,iT,iZ) - EPSA(iU)*F3VAL
          DG2(iV,iX,iT,iZ) = DG2(iV,iX,iT,iZ) - G3VAL
        End If
        DEPSA(iY,iU) = DEPSA(iY,iU) - F3VAL*G2(iV,iX,iT,iZ)
        If (iY.eq.iX.and.iV.eq.iU) Then
          DF1(iT,iZ) = DF1(iT,iZ) - F3VAL
          DG1(iT,iZ) = DG1(iT,iZ) - G3VAL
        End If
      END DO
C
      Return
C
      End Subroutine CLagDXC_FG3
C
C-----------------------------------------------------------------------
C
      Subroutine CLagDXC_DP(iSym,nAS,BDER,SDER,DF2,DG2,DF1,DG1,
     *                      DEPSA,DEASUM,iLo,iHi,jLo,jHi,LDC,g1,g2,sc)
C
      use caspt2_global, only:ipea_shift
      USE SUPERINDEX
C
      Implicit Real*8 (A-H,O-Z)
C
#include "rasdim.fh"
#include "caspt2.fh"
#include "eqsolv.fh"
#include "WrkSpc.fh"
C
      Dimension BDER(*),SDER(*),
     *          DF2(nAshT,nAshT,nAshT,nAshT),
     *          DG2(nAshT,nAshT,nAshT,nAshT),
     *          DF1(nAshT,nAshT),DG1(nAshT,nAshT),DEPSA(nAshT,nAshT)
      dimension g1(nAshT,nAshT),G2(nAshT,nAshT,nasht,nasht),sc(*)
C     INTEGER*1 idxG3(6,NG3)
C
      ISADR=0
      if (isadr.ne.0) write (6,*) ldc !! just for avoid compiling error
      DO 100 IXYZ=jLo,jHi
        IXYZABS=IXYZ+NTUVES(ISYM)
        IXABS=MTUV(1,IXYZABS)
        IYABS=MTUV(2,IXYZABS)
        IZABS=MTUV(3,IXYZABS)
        EY=EPSA(IYABS)
        DO 101 ITUV=iLo,iHi
          ITUVABS=ITUV+NTUVES(ISYM)
          ITABS=MTUV(1,ITUVABS)
          IUABS=MTUV(2,ITUVABS)
          IVABS=MTUV(3,ITUVABS)
          EU=EPSA(IUABS)
          EYU=EY + EU
          FACT=EYU-EASUM
        ! IF (LDC.NE.0) THEN
C       !   VALUE=SC(1+iTUV-iLo+LDC*(iXYZ-jLo))
        !   ValS=SDER(1+iTUV-iLo+LDC*(iXYZ-jLo))
        ! ELSE
        !   IF (IXYZ.LE.ITUV) THEN
        !     ISADR=(ITUV*(ITUV-1))/2+IXYZ
C             VALUE=SC(ISADR)
            iSAdr=iTUV+nAS*(iXYZ-1)
            ValB=BDER(ISADR)
C
            If (iTUV.eq.iXYZ.and.ipea_shift.ne.0.0D+00) Then
C             !! BC in the next equation refers to the active overlap
C    !! ipea_shift*0.5d0*BC(ISADR)*(4.0d0-DREF(IDT)-DREF(IDV)+DREF(IDU))
              bsBDER = ipea_shift*0.5D+00*ValB
              SDER(iSAdr) = SDER(iSAdr) + bsBDER*(4.0D+00
     *         -G1(iTabs,iTabs)+G1(iUabs,iUabs)-G1(iVabs,iVabs))
              iSAdr2 = iTUV*(iTUV+1)/2
              DG1(iTabs,iTabs) = DG1(iTabs,iTabs) - bsBDER*SC(iSAdr2)
              DG1(iUabs,iUabs) = DG1(iUabs,iUabs) + bsBDER*SC(iSAdr2)
              DG1(iVabs,iVabs) = DG1(iVabs,iVabs) - bsBDER*SC(iSAdr2)
            End If
C
            !! First VALUE contribution in MKBC_DP (FACT)
            SDER(ISADR) = SDER(ISADR) + FACT*ValB
            ValS=SDER(ISADR)
        ! END IF
C     vals=0.0d+00 ! asdf
C
          Do iWabs = 1, nAshT
            iTWV = iTabs+nAshT*(iWabs-1)+nAshT**2*(iVabs-1)
            iSAdr2 = Max(iTWV,iXYZ)*(Max(iTWV,iXYZ)-1)/2
     *             + Min(iTWV,iXYZ)
            DEPSA(iWabs,iUabs) = DEPSA(iWabs,iUabs)
     *        + ValB*SC(iSAdr2)
C
            iXWZ = iXabs+nAshT*(iWabs-1)+nAshT**2*(iZabs-1)
            iSAdr2 = Max(iTUV,iXWZ)*(Max(iTUV,iXWZ)-1)/2
     *             + Min(iTUV,iXWZ)
            DEPSA(iWabs,iYabs) = DEPSA(iWabs,iYabs)
     *        + ValB*SC(iSAdr2)
          End Do

          iSAdr = Max(iTUV,iXYZ)*(Max(iTUV,iXYZ)-1)/2
     *          + Min(iTUV,iXYZ)
          DEASUM = DEASUM - ValB*SC(iSAdr)
C
C         dyu ( Fvztx - EPSA(u)*Gvztx )
C         dyu Gvztx
          IF(IYABS.EQ.IUABS) THEN
            !! VALUE=VALUE+2.0D0*(FP(IP)-EU*PREF(IP))
            DF2(iVabs,iZabs,iTabs,iXabs)
     *        = DF2(iVabs,iZabs,iTabs,iXabs) + ValB
            DG2(iVabs,iZabs,iTabs,iXabs)
     *        = DG2(iVabs,iZabs,iTabs,iXabs) - EU*ValB
C
            !! VALUE=VALUE+2.0D0*PREF(IP)
            DG2(iVabs,iZabs,iTabs,iXabs)
     *        = DG2(iVabs,iZabs,iTabs,iXabs) + ValS
          END IF
          DEPSA(iYabs,iUabs) = DEPSA(iYabs,iUabs)
     *      - ValB*G2(iVabs,iZabs,iTabs,iXabs)
C
C         dyx ( Fvutz - EPSA(y)*Gvutz )
C         dyx Gvutz -> dut Gzyxv
          IF(IYABS.EQ.IXABS) THEN
            !! VALUE=VALUE+2.0D0*(FP(IP)-EY*PREF(IP))
            DF2(iVabs,iUabs,iTabs,iZabs)
     *        = DF2(iVabs,iUabs,iTabs,iZabs) + ValB
            DG2(iVabs,iUabs,iTabs,iZabs)
     *        = DG2(iVabs,iUabs,iTabs,iZabs) - EY*ValB
C
            !! VALUE=VALUE+2.0D0*PREF(IP)
            DG2(iVabs,iUabs,iTabs,iZabs)
     *        = DG2(iVabs,iUabs,iTabs,iZabs) + ValS
          END IF
          DEPSA(iYabs,iXabs) = DEPSA(iYabs,iXabs)
     *      - ValB*G2(iVabs,iUabs,iTabs,iZabs)

C         dtu ( Fvxyz - EPSA(u)*Gvxyz + dyx Fvz -
C                (EPSA(u)+EPSA(y)*dyz Gvz)
C         dtu Gvxyz + dtu dyx Gvz
          IF(ITABS.EQ.IUABS) THEN
            !! VALUE=VALUE+2.0D0*(FP(IP)-EU*PREF(IP))
            DF2(iVabs,iXabs,iYabs,iZabs)
     *        = DF2(iVabs,iXabs,iYabs,iZabs) + ValB
            DG2(iVabs,iXabs,iYabs,iZabs)
     *        = DG2(iVabs,iXabs,iYabs,iZabs) - EU*ValB
C
            !! VALUE=VALUE+2.0D0*PREF(IP)
            DG2(iVabs,iXabs,iYabs,iZabs)
     *        = DG2(iVabs,iXabs,iYabs,iZabs) + ValS
            IF(IYABS.EQ.IXABS) THEN
              !! VALUE=VALUE+FD(ID)-EYU*DREF(ID)
              DF1(iVabs,iZabs) = DF1(iVabs,iZabs) + ValB
              DG1(iVabs,iZabs) = DG1(iVabs,iZabs) - EYU*ValB
C
              !! VALUE=VALUE+DREF((ID1*(ID1-1))/2+ID2)
              DG1(iVabs,iZabs) = DG1(iVabs,iZabs) + ValS
            END IF
          END IF
          DEPSA(iTabs,iUabs) = DEPSA(iTabs,iUabs)
     *      - ValB*G2(iVabs,iXabs,iYabs,iZabs)
          If (iYabs.eq.iXabs)
     *    DEPSA(iTabs,iUabs) = DEPSA(iTabs,iUabs) - ValB*G1(iVabs,iZabs)
          If (iTabs.eq.iUabs)
     *    DEPSA(iYabs,iXabs) = DEPSA(iYabs,iXabs) - ValB*G1(iVabs,iZabs)
 101    CONTINUE
 100  CONTINUE
C
      Return
C
      End Subroutine CLagDXC_DP
C
C-----------------------------------------------------------------------
C
      Subroutine DEPSAOffC(CLag,DEPSA,FIFA,FIMO,WRK1,WRK2,U0)
C
      use caspt2_output, only:IPrGlb,verbose
      use caspt2_gradient, only: ConvInvar
      use gugx, only: SGS, CIS
      Implicit Real*8 (A-H,O-Z)
C
#include "rasdim.fh"
#include "caspt2.fh"
#include "WrkSpc.fh"
#include "pt2_guga.fh"
#include "caspt2_grad.fh"
C
      Dimension CLag(nConf,nState),DEPSA(nAshT,nAshT),FIFA(*),FIMO(*),
     *          WRK1(nBasT,nBasT),WRK2(*),U0(nState,nState)
      Dimension Eact(nState)
      Integer :: nLev, nMidV
      nLev = SGS%nLev
      nMidV= CIS%nMidV
C
      Thres = ConvInvar !! 1.0d-07
C
      If (IPRGLB.GE.verbose) Then
        Write (6,*)
        Write (6,'(3X,"Linear Equation for Non-Invariant CASPT2",
     *                " (threshold =",ES9.2,")")') Thres
        Write (6,*)
        CALL TIMING(CPTF0,CPE,TIOTF0,TIOE)
      End If
C
C     If CASPT2 energy is not invariant with respect to rotations within
C     active space (with IPEA shift and/or with RAS reference), the
C     active density obtained in constructing CI derivative is no longer
C     correct... well, it may be correct, but orbital rotations in the
C     active space cannot be parametrized in Z-vector, so analytic
C     derivatives cannot be computed with the existing module. So,
C     the active density is computed in a differnt way.
C
C     See J. Chem. Phys. 2023, 158, 174112. for details, in particular,
C     Section II C 4 "Non-invariance with respect to active MOs"
C     To be more specific, this subroutine solves the linear equation
C     (Eq. (71)) and computes the second term in Eq. (70) later.
C     CLag corresponds to the RHS in Eq. (71).
C
      !! Some post-processing of CI derivative
      !! Somehow, this has to be done in the XMS basis
      Call CLagFinalOffC(Work(ipSLag))
C
C     ----- Solve the linear equation -----
C     A_{IS,JR}*X_{JR} = CLag_{IS}, where A_{IS,JR} is the CI-CI Hessian
C     which may be seen in Z-vector
C
      Call GetMem('ST  ','ALLO','REAL',ipST ,nConf*nState)
      Call GetMem('S1  ','ALLO','REAL',ipS1 ,nConf*nState)
      Call GetMem('S2  ','ALLO','REAL',ipS2 ,nConf*nState)
      Call GetMem('CID ','ALLO','REAL',ipCID,nConf*nState)
      Call GetMem('CIT ','ALLO','REAL',ipCIT,nConf*nState)
      Call GetMem('S   ','ALLO','REAL',ipS  ,nState*(nState-1)/2)
      Call GetMem('PREC','ALLO','REAL',ipPre,nConf)
      Call GetMem('FANC','ALLO','REAL',ipFancy,nState**3)
C
      Call GetMem('INT1','ALLO','REAL',ipINT1,nAshT**2)
      Call GetMem('INT2','ALLO','REAL',ipINT2,nAshT**4)
C
      !! We do not have Cholesky vectors for frozen orbitals,
      !! so may be it is not possible to get inactive energies?
      !! It can be computed with TimesE2
      iSym = 1
      Call CnstInt(0,Work(ipINT1),Work(ipINT2))
      ID = IDTCEX !! IDCIEX !! this parameter is hacked
      Do iState = 1, nState
        If (ISCF.EQ.0) Then
          !! quasi-canonical, XMS
          Call DDaFile(LUCIEX,2,Work(ipCIT+nConf*(iState-1)),nConf,ID)
        Else
          Work(ipCIT+iState-1) = 1.0D+00
        End If
        !! The second term should be removed
        Eact(iState)=0.0d+00
      End Do
      if (ifxms.or.ifrms) then
        !! Transform the CLag and CI vector from XMS to SCF basis
        !! Maybe, in order to define Eact
        Call DGEMM_('N','T',nConf,nState,nState,
     &              1.0D+00,CLag,nConf,U0,nState,
     &              0.0D+00,Work(ipST),nConf)
        Call DCopy_(nConf*nState,Work(ipST),1,CLag,1)
        Call DGEMM_('N','T',nConf,nState,nState,
     &              1.0D+00,Work(ipCIT),nConf,U0,nState,
     &              0.0D+00,Work(ipST),nConf)
        Call DCopy_(nConf*nState,Work(ipST),1,Work(ipCIT),1)
      end if
      Call TimesE2(0,Work(ipCIT),Work(ipS1),Work(ipINT1),Work(ipINT2))
      Do iState = 1, nState
        !! scaling with nState is due to the division in TimesE2
        Eact(iState) = -0.5D+00*nState*
     *    DDot_(nConf,Work(ipS1+nConf*(iState-1)),1,
     *                Work(ipCIT+nConf*(iState-1)),1)
      End Do
      isyci = 1
C
      !! Precondition
      Call CnstInt(2,Work(ipINT1),Work(ipINT2))
      Call CnstPrec(CIS%NOCSF,CIS%IOCSF,CIS%NOW,
     *              CIS%IOW,ISYCI,Work(ipPre),work(ipcit),
     *              Work(ipINT1),Work(ipINT2),Work(ipFancy),nLev,
     *              nMidV)
      Call CnstInt(0,Work(ipINT1),Work(ipINT2))
C
      !! Begin!
      Call DCopy_(nConf*nState,CLag,1,Work(ipST),1)
C
      !! z0 = M^{-1}*r0
C     Call DMinvCI_sa(ipST,Work(ipIn(ipS2)),rdum,isym,work(ipS))
      Call DCopy_(nConf*nState,Work(ipST),1,Work(ipS2),1)
      Call DoPrec(Work(ipST),Work(ipS2),Work(ipS1),Work(ipPre),
     *            Work(ipFancy))
      !! p0 = z0
      Call DCopy_(nConf*nState,Work(ipS2),1,Work(ipCId),1)
      MaxIter = 100
      Iter    = 1
      iSym    = 1
      ! jspin   = 0
      ! r^T dot z
      ! r (residue) = ipST
      ! z (prec. r) = ipS2
      ! p (...)     = ipCId
      ! x (solution)= ipCIT
      ! Ap          = ipS1
      ! r_{k}z_{k}  = ipST*ipS2 = deltaC
      DeltaC = DDot_(nConf*nState,Work(ipST),1,Work(ipS2),1)
      Delta  = DeltaC
      Delta0 = Delta
C
      If (IPRGLB.GE.verbose) Write(6,*)
     &      ' Iteration       Delta           Res(CI)        '//
     &      '  DeltaC'
      Call DCopy_(nConf*nState,[0.0D+00],0,Work(ipCIT),1)
      If (Delta0.le.Abs(Thres)) Go To 100
      Do Iter = 1, MaxIter
        If (nConf.EQ.1) Then
          Do iState = 1, nState
            Work(ipCIT+iState-1)=1.0d+00
          End Do
          Exit
        End If
        !! Compute Ap
        !! ipS2 is used as a workind array
        Call TimesE2(1,Work(ipCId),Work(ipS1),Work(ipINT1),Work(ipINT2))
C
        !! AlphaC = p^T*A*p
        AlphaC= DDot_(nConf*nState,Work(ipS1),1,Work(ipCId),1)
        !! Alpha = r^T*z / AlphaC
        Alpha = Delta/(AlphaC)
        ! new x of CI
        Call DaXpY_(nConf*nState,Alpha,Work(ipCId),1,Work(ipCIT),1)
        ! new r of CI
        Call DaXpY_(nConf*nState,-Alpha,Work(ipS1),1,Work(ipST),1)
        ResCI=sqrt(DDot_(nConf*nState,Work(ipST),1,Work(ipST),1))
        !! z = M^{-1}*r
C       Call DMinvCI_SA(ipST,Work(ipS2),rdum,isym,work(ipS))
        Call DCopy_(nConf*nState,Work(ipST),1,Work(ipS2),1)
        Call DoPrec(Work(ipST),Work(ipS2),Work(ipS1),Work(ipPre),
     *              Work(ipFancy))
C
        !! Append new vectors
        DeltaC= Ddot_(nConf*nState,Work(ipST),1,Work(ipS2),1)
        Beta  = DeltaC/Delta
        Delta = DeltaC
        Call DScal_(nConf*nState,   Beta,Work(ipCID),1)
        Call DaXpY_(nConf*nState,1.0D+00,Work(ipS2),1,Work(ipCID),1)
C
        If (IPRGLB.GE.verbose)
     *  Write(6,'(I7,4X,ES17.9,ES17.9,ES17.9)')
     &         iter,delta/delta0,resci,deltac
C
        Res = ResCI
        If (Res.le.Abs(Thres)) Exit
      End Do
C
      If (Iter.eq.MaxIter+1) Then
        write(6,*)
     *  "CI iteration for non-invariant CASPT2 did not converge..."
        call abend
      End If
C
  100 CONTINUE
C
      If (IPRGLB.GE.verbose) Then
        CALL TIMING(CPTF1,CPE,TIOTF1,TIOE)
        CPUT =CPTF1-CPTF0
        WALLT=TIOTF1-TIOTF0
        Write (6,*)
        Write (6,'(3X,"Linear equation converged in ",I3," steps")')
     *         iter-1
        Write (6,'(3X,"CPU and wall time (in s) = ",2F8.2)') CPUT,WALLT
        Write (6,*)
      End If
C
      If (IFXMS.OR.IFRMS) Then
        !! Transform back the CLag from CAS to XMS
        Call DGEMM_('N','N',NConf,nState,nState,
     &              1.0D+00,CLag,nConf,U0,nState,
     &              0.0D+00,Work(ipST),nConf)
        Call DCopy_(nConf*nState,Work(ipST),1,CLag,1)
      End If
C
      CALL GETMEM('S1  ','FREE','REAL',ipS1 ,nConf*nState)
      CALL GETMEM('S2  ','FREE','REAL',ipS2 ,nConf*nState)
      CALL GETMEM('CID ','FREE','REAL',ipCID,nConf*nState)
      CALL GETMEM('S   ','FREE','REAL',ipS  ,nState*(nState-1)/2)
      CALL GETMEM('PREC','FREE','REAL',ipPre,nConf)
      Call GetMem('FANC','FREE','REAL',ipFancy,nState**3)
C
C     ----- Construct (a part of) the true active density -----
C     Compute the second term in Eq. (70) = Eq. (72)
C     The SCF, not XMS, basis is used
C
      ID = IDCIEX !! idtcex?
      Do iState = 1, nState
        If (ISCF.EQ.0) Then
          If (IFXMS.OR.IFRMS) THen
            !! Use unrotated (SCF) CI vector
            Call LoadCI_XMS('C',1,Work(ipST+nConf*(iState-1)),iState,U0)
          Else
            Call DDaFile(LUCIEX,2,Work(ipST+nConf*(iState-1)),nConf,ID)
          End If
        Else
          Work(ipST+iState-1) = 1.0D+00
        End If
      End Do
      Call GetMem('G2  ','ALLO','REAL',ipG2,nAshT**4)
      Call CnstInt(1,Work(ipINT1),Work(ipINT2))
      Call CnstDEPSA(Work(ipST),Work(ipCIT),Work(ipINT1),Work(ipG2),
     *               Work(ipINT2))
      Call GetMem('G2  ','FREE','REAL',ipG2,nAshT**4)
C
      If (IPRGLB.GE.verbose) Then
        CALL TIMING(CPTF2,CPE,TIOTF2,TIOE)
        CPUT =CPTF2-CPTF1
        WALLT=TIOTF2-TIOTF1
        Write (6,'(3X,"Off-diagonal density is constructed")')
        Write (6,'(3X,"CPU and wall time (in s) = ",2F8.2)') CPUT,WALLT
        Write (6,*)
      End If
C
      CALL GETMEM('ST  ','FREE','REAL',ipST ,nConf*nState)
      CALL GETMEM('CIT ','FREE','REAL',ipCIT,nConf*nState)
      CALL GETMEM('INT1','FREE','REAL',ipINT1,nAshT**2)
      CALL GETMEM('INT2','FREE','REAL',ipINT2,nAshT**4)
C
      Contains
C
C-----------------------------------------------------------------------
C
      Subroutine CLagFinalOffC(SLag)
C
C     Orthogonalize the partial derivative with respect to CI coeff
C
      IMPLICIT REAL*8 (A-H,O-Z)
C
      Dimension SLag(*)
C
      Call GetMem('ST  ','ALLO','REAL',ipST ,nConf*nState)
      Call DGEMM_('N','T',nConf,nState,nState,
     &            1.0D+00,CLag,nConf,U0,nState,
     &            0.0D+00,Work(ipST),nConf)
      Call DCopy_(nConf*nState,Work(ipST),1,CLag,1)

      Call GetMem('LCI1','ALLO','REAL',LCI1,nConf)
      Call GetMem('LCI2','ALLO','REAL',LCI2,nConf)
C
      !! Construct SLag
      ijst = 0
      do ilStat = 1, nState
        If (ISCF.EQ.0) Then
          Call LoadCI_XMS('C',1,Work(LCI1),ilStat,U0)
        Else
          Work(LCI1) = 1.0D+00
        End If
        Do jlStat = 1, ilStat !! -1
          ijst = ilStat + nState*(jlStat-1)
          If (ilStat.eq.jlStat) Cycle
          If (ISCF.EQ.0) Then
            Call LoadCI_XMS('C',1,Work(LCI2),jlStat,U0)
          Else
            Work(LCI2) = 1.0D+00
          End If
          Scal = DDOT_(nConf,Work(LCI1),1,CLag(1,jlStat),1)
     *         - DDOT_(nConf,Work(LCI2),1,CLag(1,ilStat),1)
          Scal = Scal/(REFENE(jlStat)-REFENE(ilStat))
          SLag(ijst) = SLag(ijst) + Scal
          IF (IPRGLB.GE.verbose) THEN
            write(6,'(1x,"SLag for State ",i1,"-",i1," = ",f20.10)')
     *         ilstat,jlstat,slag(ijst)
          END IF
        end do
      end do
C
      !! Projection
      Do ilStat = 1, nState
        Call DCopy_(nConf,CLag(1,ilStat),1,Work(LCI1),1)
        Do jlStat = 1, nState
          If (ISCF.EQ.0) Then
            Call LoadCI_XMS('C',1,Work(LCI2),jlStat,U0)
          Else
            Work(LCI2) = 1.0D+00
          End If
          Ovl = DDot_(nConf,Work(LCI1),1,Work(LCI2),1)
          Call DaXpY_(nConf,-Ovl,Work(LCI2),1,CLag(1,ilStat),1)
        End Do
      End Do
C
      Call DGEMM_('N','N',nConf,nState,nState,
     &            1.0D+00,CLag,nConf,U0,nState,
     &            0.0D+00,Work(ipST),nConf)
      Call DCopy_(nConf*nState,Work(ipST),1,CLag,1)
C
      Call GetMem('LCI1','FREE','REAL',LCI1,nConf)
      Call GetMem('LCI2','FREE','REAL',LCI2,nConf)
      Call GetMem('ST  ','FREE','REAL',ipST ,nConf*nState)
C
      Return
C
      End Subroutine CLagFinalOffC
C
C-----------------------------------------------------------------------
C
      Subroutine CnstInt(Mode,INT1,INT2)
C
      Use CHOVEC_IO
C
      Implicit Real*8 (A-H,O-Z)
C
#include "chocaspt2.fh"
C
      Real*8 INT1(nAshT,nAshT),INT2(nAshT,nAshT,nAshT,nAshT)
C
      Integer Active, Inactive, Virtual
      Parameter (Inactive=1, Active=2, Virtual=3)
      Integer nSh(8,3)
C
      Call DCopy_(nAshT**2,[0.0D+00],0,INT1,1)
      Call DCopy_(nAshT**4,[0.0D+00],0,INT2,1)
C
      nFroI = nFro(iSym)
      nIshI = nIsh(iSym)
      nCorI = nFroI+nIshI
      nBasI = nBas(iSym)
C
C     --- One-Electron Integral
C
      !! Read H_{\mu \nu}
C     IRC=-1
C     IOPT=6
C     ICOMP=1
C     ISYLBL=1
C     CALL RDONE(IRC,IOPT,'OneHam  ',ICOMP,WRK2,ISYLBL)
C     !! triangular -> square transformation
C     Call Square(WRK2,WRK1,1,nBasT,nBasT)
C     !! AO -> MO transformation
C     Call DGemm_('T','N',nBasT,nBasT,nBasT,
C    *            1.0D+00,Work(LCMOPT2),nBasT,WRK1,nBasT,
C    *            0.0D+00,WRK2,nBasT)
C     Call DGemm_('N','N',nBasT,nBasT,nBasT,
C    *            1.0D+00,WRK2,nBasT,Work(LCMOPT2),nBasT,
C    *            0.0D+00,WRK1,nBasT)
      !! Inactive energy
C     Do iCorI = 1, nFro(iSym)+nIsh(iSym)
C       RIn_Ene = RIn_Ene + 2.0d+00*WRK1(iCorI,iCorI)
C     End Do
      !! Put in INT1
C     Do iAshI = 1, nAsh(iSym)
C       Do jAshI = 1, nAsh(iSym)
C         Val = WRK1(nCorI+iAshI,nCorI+jAshI)
C         INT1(iAshI,jAshI) = INT1(iAshI,jAshI) + Val
C       End Do
C     End Do
      Do iAshI = 1, nAsh(iSym)
        Do jAshI = 1, nAsh(iSym)
          Val = FIMO(nCorI+iAshI+nBasI*(nCorI+jAshI-1))
          INT1(iAshI,jAshI) = INT1(iAshI,jAshI) + Val
        End Do
      End Do
C
C     --- Two-Electron Integral
C
      iSymA = 1
      iSymI = 1
      iSymB = 1
      iSymJ = 1
C     If (.not.IfChol) Then
C       Do iCorI = 1, nFro(iSym)+nIsh(iSym)
C         iOrb = iCorI
C         jOrb = iCorI
C         Call Coul(iSymA,iSymI,iSymB,iSymJ,iOrb,jOrb,WRK1,WRK2)
C         Do jCorI = 1, nFro(iSym)+nIsh(iSym)
C           RIn_Ene = RIn_Ene + 2.0d+00*WRK1(jCorI,jCorI)
C         End Do
C         Call Exch(iSymA,iSymI,iSymB,iSymJ,iOrb,jOrb,WRK1,WRK2)
C         Do jCorI = 1, nFro(iSym)+nIsh(iSym)
C           RIn_Ene = RIn_Ene - WRK1(jCorI,jCorI)
C         End Do
C       End Do
C     End If
C
      If (IfChol) Then
        Call ICopy(NSYM,NISH,1,nSh(1,Inactive),1)
        Call ICopy(NSYM,NASH,1,nSh(1,Active  ),1)
        Call ICopy(NSYM,NSSH,1,nSh(1,Virtual ),1)
        DO JSYM=1,NSYM
          IB1=NBTCHES(JSYM)+1
          IB2=NBTCHES(JSYM)+NBTCH(JSYM)
C
          MXBGRP=IB2-IB1+1
          IF (MXBGRP.LE.0) CYCLE
          CALL GETMEM('BGRP','ALLO','INTE',LBGRP,2*MXBGRP)
          IBGRP=1
          DO IB=IB1,IB2
           IWORK(LBGRP  +2*(IBGRP-1))=IB
           IWORK(LBGRP+1+2*(IBGRP-1))=IB
           IBGRP=IBGRP+1
          END DO
          NBGRP=MXBGRP
C
          CALL MEMORY_ESTIMATE(JSYM,IWORK(LBGRP),NBGRP,
     &                         NCHOBUF,MXPIQK,NADDBUF)
          CALL GETMEM('KETBUF','ALLO','REAL',LKET,NCHOBUF)
C         write(6,*) "nchobuf= ", nchobuf
C         write(6,*) "nbgrp= ", nbgrp
C         write(6,*) "nbtch= ", nbtch(jsym)
          Do IBGRP=1,NBGRP
C
            IBSTA=IWORK(LBGRP  +2*(IBGRP-1))
            IBEND=IWORK(LBGRP+1+2*(IBGRP-1))
C           write(6,*) ibsta,ibend
C
            NV=0
            DO IB=IBSTA,IBEND
              NV=NV+NVLOC_CHOBATCH(IB)
            END DO
C
            !! int2(tuvx) = (tu|vx)/2
            !! This can be computed without frozen orbitals
            Call Get_Cholesky_Vectors(Active,Active,JSYM,
     &                                Work(LKET),nKet,
     &                                IBSTA,IBEND)
C
            CALL GETMEM('WRKCHO','ALLO','REAL',LWRKCHO,NV)
            Call DCopy_(NV,[0.0D+00],0,Work(LWRKCHO),1)
            Call DGEMM_('N','T',NASH(JSYM)**2,NASH(JSYM)**2,NV,
     *                  0.5D+00,Work(LKET),NASH(JSYM)**2,
     *                          Work(LKET),NASH(JSYM)**2,
     *                  0.0D+00,INT2,NASH(JSYM)**2)
            CALL GETMEM('WRKCHO','FREE','REAL',LWRKCHO,NV)
          End Do
          CALL GETMEM('KETBUF','FREE','REAL',LKET,NCHOBUF)
          CALL GETMEM('BGRP','FREE','INTE',LBGRP,2*MXBGRP)
        End Do
      Else
        Do iAshI = 1, nAsh(iSym)
          iOrb = nCorI+iAshI
          Do jAshI = 1, nAsh(iSym)
            jOrb = nCorI+jAshI
C
            Call Coul(iSymA,iSymI,iSymB,iSymJ,iOrb,jOrb,WRK1,WRK2)
            !! Put in INT1
C           Do iCorI = 1, nFro(iSym)+nIsh(iSym)
C             INT1(iAshI,jAshI) = INT1(iAshI,jAshI)
C    *          + 2.0d+00*WRK1(iCorI,iCorI)
C           End Do
            !! Put in INT2
            Do kAshI = 1, nAsh(iSym)
              Do lAshI = 1, nAsh(iSym)
                INT2(iAshI,jAshI,kAshI,lAshI)
     *        = INT2(iAshI,jAshI,kAshI,lAshI)
     *        + WRK1(nCorI+kAshI,nCorI+lAshI)*0.5d+00
              End Do
            End Do
C
C           Call Exch(iSymA,iSymI,iSymB,iSymJ,iOrb,jOrb,WRK1,WRK2)
            !! Put in INT1
C           Do iCorI = 1, nFro(iSym)+nIsh(iSym)
C             INT1(iAshI,jAshI) = INT1(iAshI,jAshI) - WRK1(iCorI,iCorI)
C           End Do
          End Do
        End Do
      End If
C     write(6,*) "int2"
C     call sqprt(int2,25)
C     call sqprt(int1,5)
C     call sqprt(fimo,12)
      If (Mode.eq.0) Then
      Do IT = 1, nAshT
        Do iU = 1, nAshT
          iTU = iT + nAshT*(iU-1)
          Do iV = 1, nAshT
            Do iX = 1, nAshT
              iVX = iV + nAshT*(iX-1)
              If (iVX.gt.iTU) Then
               INT2(iT,iU,iV,IX) = INT2(iT,iU,iV,iX) + INT2(iV,iX,iT,iU)
               INT2(iV,iX,iT,iU) = 0.0D+00
              End If
            End Do
          End Do
        End Do
      End Do
      End If
C
      if (mode.eq.0.or.mode.eq.1) then
      Do IT = 1, nAshT
        Do iU = 1, nAshT
          Do iX = 1, nAshT
            INT1(IT,IU) = INT1(IT,IU) - INT2(IT,IX,IX,IU)
          End Do
        End Do
      End Do
      endif
C
      Return
C
      End Subroutine CnstInt
C
C-----------------------------------------------------------------------
C
      !! dens2_rpt2.f
      Subroutine TimesE2(Mode,CIin,CIout,INT1,INT2)
! #ifdef _MOLCAS_MPP_
!       USE Para_Info, ONLY: Is_Real_Par, King
! #endif
      use gugx, only: SGS, L2ACT, CIS
      Implicit Real*8 (A-H,O-Z)

      Dimension CIin(nConf,nState),CIout(nConf,nState)
      Real*8    INT1(nAshT,nAshT),INT2(nAshT,nAshT,nAshT,nAshT)
      LOGICAL   RSV_TSK
      Integer :: nLev
      nLev=SGS%nLev
      ! logical tras,uras,vras,xras
C
C     --- H_{IJ}*P_J
C    <CI1|EtuEvx|CI2>=<CI1|Evx
C
      nTasks= nLev**2
      CALL GETMEM ('Tasks','ALLO','INTE',lTask,2*nTasks)
      lTask2T=lTask
      lTask2U=lTask+nTasks
C
      iTask=0
      DO LT=1,nLev
        DO LU=1,nLev
          iTask=iTask+1
          iWork(lTask2T+iTask-1)=LT
          iWork(lTask2U+iTask-1)=LU
        ENDDO
      ENDDO
      IF (iTask.NE.nTasks) WRITE(6,*) "ERROR nTasks"
C
      Call GetMem('SGM1','ALLO','REAL',LSGM1,nConf)
      Call GetMem('SGM2','ALLO','REAL',LSGM2,nConf)
C
      Call DCopy_(nConf*nState,[0.0D+00],0,CIout,1)
      Do kState = 1, nState
        !! Start the actual part of dens2_rpt2
        Call Init_Tsk(ID, nTasks)
C
 500    If (.NOT.Rsv_Tsk (ID,iTask)) GOTO 501
C
        LT=iWork(lTask2T+iTask-1)
        ! tras=.false.
        ! if (lt.le.nras1(1)) tras=.true.
          IST=SGS%ISM(LT)
          IT=L2ACT(LT)
          LU=iWork(lTask2U+iTask-1)
          ! uras=.false.
          ! if (lu.gt.nras1(1)+nras2(1)) uras=.true.
C         if (tras.and.uras) go to 500
            ! LTU=iTask
            ISU=SGS%ISM(LU)
            IU=L2ACT(LU)
            ISTU=MUL(IST,ISU)
            ISSG=MUL(ISTU,STSYM)
            NSGM=CIS%NCSF(ISSG)
            IF(NSGM.EQ.0) GOTO 500
            !! <CIin|Etu
            CALL GETSGM2(LU,LT,STSYM,CIin(1,kState),Work(LSGM1))
C           CALL GETSGM2(LT,LU,STSYM,CIin(1,iState),Work(LSGM1))
            IF(ISTU.EQ.1) THEN
              !! <CIin|Etu|CIout>*I1tu
              Call DaXpY_(NSGM,INT1(IT,IU),Work(LSGM1),1,
     *                                     CIout(1,kState),1)
            END IF
            LVX=0
            DO LV=1,NLEV
              ISV=SGS%ISM(LV)
              IV=L2ACT(LV)
              ! vras=.false.
              ! if (lv.le.nras1(1)) vras=.true.
              DO LX=1,NLEV
                LVX=LVX+1
                ISX=SGS%ISM(LX)
                ISVX=MUL(ISV,ISX)
                ! xras=.false.
                ! if (lx.gt.nras1(1)+nras2(1)) xras=.true.
C               if (vras.and.xras) go to 110
                IF(ISVX.NE.ISTU) GOTO 110
                IX=L2ACT(LX)
                CALL GETSGM2(LX,LV,ISSG,Work(LSGM1),Work(LSGM2))
C               CALL GETSGM2(LV,LX,ISSG,Work(LSGM1),Work(LSGM2))
                Call DaXpY_(NSGM,INT2(IT,IU,IV,IX),Work(LSGM2),1,
     *                      CIout(1,kState),1)
 110          CONTINUE
              END DO
            END DO

C
! #if defined (_MOLCAS_MPP_) && ! defined (_GA_)
!         IF (IS_REAL_PAR().AND.KING().AND.(NPROCS.GT.1)) GOTO 501
! #endif
C
        GOTO 500
 501    CONTINUE
        CALL Free_Tsk(ID)
        !! End the actual part of dens2_rpt2
      End Do
C
      CALL GETMEM ('Tasks','FREE','INTE',lTask,2*nTasks)
C
      CALL GAdSUM(CIout,nConf*nState)
C
C     --- -E_{S}*CJ + zL_{KL}
C
      Do kState = 1, nState
        EC=Eact(kState)
        Call Daxpy_(nConf,EC,CIin(1,kState),1,CIout(1,kState),1)
      End Do
C
      !! Project out the reference vector, just in case
      If (Mode.eq.1) Then
        Do ilStat = 1, nState
          Call DCopy_(nConf,CIout(1,ilStat),1,Work(LSGM1),1)
          Do jlStat = 1, nState
            Call LoadCI_XMS('C',1,Work(LSGM2),jlStat,U0)
            Ovl = DDot_(nConf,Work(LSGM1),1,Work(LSGM2),1)
            Call DaXpY_(nConf,-Ovl,Work(LSGM2),1,CIout(1,ilStat),1)
          End Do
        End Do
      End If
C
      Call GetMem('SGM1','FREE','REAL',LSGM1,nConf)
      Call GetMem('SGM2','FREE','REAL',LSGM2,nConf)
C
      Call DScal_(nConf*nState,2.0D+00/nState,CIout,1)
C
      Return
C
      End Subroutine TimesE2
C
C-----------------------------------------------------------------------
C
      Subroutine CnstDEPSA(CI,CIT,G1,G2,INT2)
C
      use gugx, only: SGS
      Implicit Real*8 (A-H,O-Z)
C
#include "caspt2_grad.fh"
#include "pt2_guga.fh"
C
      Dimension CI(nConf,nState),CIT(nConf,nState),G1(nAshT,nAshT),
     *          G2(nAshT,nAshT,nAshT,nAshT)
      Real*8    INT2(nAshT,nAshT,nAshT,nAshT)
      Integer :: nLev
      nLev=SGS%nLev
C
C     LOGICAL   RSV_TSK
C
C     This subroutine computes the second term in Eq. (70) or the RHS of
C     Eq. (72) in the CASPT2-IPEA gradient paper
C     CIT corresponds to \overline{Q}, if I remember correctly
C
      Call DCopy_(nAshT**2,[0.0D+00],0,G1,1)
      Call DCopy_(nAshT**4,[0.0D+00],0,G2,1)
C
      !! Construct transition(?) density matrix
      !! (<CI|Etu|CIT>+<CIT|Etu|CI>)/2, where CIT is the solution
      nTasks= nLev**2
      CALL GETMEM ('Tasks','ALLO','INTE',lTask,2*nTasks)
      lTask2T=lTask
      lTask2U=lTask+nTasks
C
      iTask=0
      DO LT=1,nLev
        DO LU=1,nLev
          iTask=iTask+1
          iWork(lTask2T+iTask-1)=LT
          iWork(lTask2U+iTask-1)=LU
        ENDDO
      ENDDO
      IF (iTask.NE.nTasks) WRITE(6,*) "ERROR nTasks"
C
      Call GetMem('SGM1','ALLO','REAL',LSGM1,nConf)
      Call GetMem('SGM2','ALLO','REAL',LSGM2,nConf)
      Call GetMem('GT1 ','ALLO','REAL',LG1T,NG1)
      Call GetMem('GT2 ','ALLO','REAL',LG2T,NG2)
C
C  !! This is for CASSCF orbital Lagrangian, but this may not contribute
C     Call Dens2T_RPT2(CI(1,jState),CI(1,jState),
C    *                 Work(LSGM1),Work(LSGM2),Work(LG1T),Work(LG2T),nLev)
C     Call DaXpY_(NG1,-0.5D+00,Work(LG1T),1,G1,1)
C     Call DaXpY_(NG2,-0.5D+00,Work(LG2T),1,G2,1)
C
      Do kState = 1, nState
C       Wgt = Work(LDWgt+iState-1+nState*(iState-1))
        Wgt = 1.0D+00/nState
C
        !! <CI|Etu|CIT>+<CIT|Etu|CI> and the t+ u+ x v variant
        Call Dens2T_RPT2(CI(1,kState),CIT(1,kState),
     *                   Work(LSGM1),Work(LSGM2),Work(LG1T),Work(LG2T),
     *                   nLev)
        Call DaXpY_(NG1,WGT,Work(LG1T),1,G1,1)
        Call DaXpY_(NG2,WGT,Work(LG2T),1,G2,1)
C
        !! For the orbital contribution of CASSCF Lagrangian
        !! Just add the SLag rotation contributions
        ilState = kState
        Do jlState = 1, ilState-1
C         If (ilState.eq.jlState) Cycle
          iSLag = ilState + nState*(jlState-1)
          vSLag = -0.5D+00*Work(ipSLag+iSLag-1)
          If (abs(vSLag).le.1.0D-08) Cycle
          Call Dens2T_RPT2(CI(1,ilState),CI(1,jlState),
     *                     Work(LSGM1),Work(LSGM2),
     *                     Work(LG1T),Work(LG2T),nLev)
          Call DaXpY_(NG1,vSLag,Work(LG1T),1,G1,1)
          Call DaXpY_(NG2,vSLag,Work(LG2T),1,G2,1)
        End Do
      End Do
C
      CALL GETMEM ('Tasks','FREE','INTE',lTask,2*nTasks)
C
      Call GetMem('SGM1','FREE','REAL',LSGM1,nConf)
      Call GetMem('SGM2','FREE','REAL',LSGM2,nConf)
C
      Call GetMem('GT1 ','FREE','REAL',LG1T,NG1)
      Call GetMem('GT2 ','FREE','REAL',LG2T,NG2)
C     write(6,*) "finished TRDM2"
C     call sqprt(g1,nlev)
C     call sqprt(g2,nlev**2)
C
C     Call GetMem('SGM1','ALLO','REAL',LSGM1,nConf)
C     Call GetMem('SGM2','ALLO','REAL',LSGM2,nConf)
C     Call GetMem('G1  ','ALLO','REAL',LG1  ,nAshT**2)
C     Call GetMem('G2  ','ALLO','REAL',LG2  ,nAshT**4)
C     Do iState = 1, nState
C       Call Dens2_RPT2(CI(1,iState),Work(LSGM1),Work(LSGM2),
C    *                  Work(LG1),Work(LG2),nAshT)
C       WGT=2.0D+00/nState
C       Call DaXpY_(nAshT**2,WGT,Work(LG1),1,G1,1)
C       Call DaXpY_(nAshT**4,WGT,Work(LG2),1,G2,1)
C     end do
C     Call GetMem('SGM1','FREE','REAL',LSGM1,nConf)
C     Call GetMem('SGM2','FREE','REAL',LSGM2,nConf)
C     Call GetMem('G1  ','FREE','REAL',LG1  ,nAshT**2)
C     Call GetMem('G2  ','FREE','REAL',LG2  ,nAshT**4)
C
      !! Finally, construct the Fock matrix only for active-active
      !! Should be equivalent to FockGen in MCLR
      Call GetMem('FOCK ','ALLO','REAL',ipFock,nAshT**2)
      Call DCopy_(nAshT**2,[0.0D+00],0,Work(ipFock),1)
C
      !! 1) FIMO term
      Do iS=1,nSym
        If (nBas(iS).gt.0) Then
          jS=iEOr(is-1,iSym-1)+1
          Do iA=1,nAsh(is)
            Do jA=1,nAsh(js)
C             rd=rDens1(iA+nA(iS),jA+nA(js))
C             ip1=nBas(iS)*(nIsh(is)+iA-1)+ipCM(is)-1
C             ip2=nBas(iS)*(nIsh(js)+jA-1) +ipmat(is,js)
              rd=G1(iA,jA)
              ip1= 1+nFro(jS)+nIsh(jS)
     *           + nBas(iS)*(nFro(iS)+nIsh(iS)+iA-1)
              ip2=ipFock            + nAsh(iS)*(jA-1)
              Call DaXpY_(nAsh(iS),Rd,FIMO(ip1),1,Work(ip2),1)
            End Do
          End Do
        End If
      End Do
C     write(6,*) "after 1"
C     call sqprt(work(ipfock),nasht)
C
      !! 2) two-electron term (only CreQADD part)
      Do iS=1,nSym
        ipS=iEOr(is-1,isym-1)+1
        if (norb(ips).ne.0) Then
          Do jS=1,nsym
            ijS=iEOR(is-1,js-1)+1
            Do kS=1,nSym
              ls=iEOr(ijs-1,iEor(ks-1,isym-1))+1
*                                                                      *
************************************************************************
*                                                                      *
               Do kAsh=1,nAsh(kS)
                kAA=kAsh+nFro(kS)+nIsh(kS)
                Do lAsh=1,nAsh(lS)
                  lAA=lAsh+nFro(lS)+nIsh(lS)
C                 ikl=nna*(lAsh+nA(lS)-1)+kAsh+nA(kS)
*
*                 Pick up (pj|kl)
*
                  Call Coul(ipS,jS,kS,lS,kAA,lAA,WRK1,WRK2)
C    *                      Work(ipWRK1),Work(ipWRK2))
*
                  Do iAsh=1,nAsh(iS)
C                   iAA=iAsh+nIsh(iS)
C                   ipQ=ipMat(ipS,iS)+nOrb(ipS)*(iAA-1)
                    ipQ=nAsh(ipS)*(iAsh-1)
C                   ipM=1+nIsh(jS)*nOrb(ipS)
                    Do jAsh=1,nAsh(jS)
                      ! jAA=jAsh+nFro(jS)+nIsh(jS)
                      ipM=nFro(ipS)+nIsh(ipS)
     *                   +(nFro(jS)+nIsh(jS)+jAsh-1)*nBas(ipS)
C                     iij=nna*(jAsh+nA(jS)-1)+iAsh+nA(iS)
C                     ipG=itri(iij,ikl)
C                     P_ijkl=G2(ipG)
*
C                     Call DaXpY_(nOrb(ipS),P_ijkl,MO(ipM),1,
C    &                            Q(ipQ),1)
                      !! Fpi = Gijkl*(pj|kl)
C                     Call DaXpY_(nAsh(ipS),G2(iAsh,jAsh,kAsh,lAsh),
C    &                            Work(ipWRK1+ipM),1,Work(ipFock+ipQ),1)
C                     Call DaXpY_(nAsh(ipS),G2(iAsh,jAsh,kAsh,lAsh),
C    &                            WRK1(ipM+1,1),1,Work(ipFock+ipQ),1)
                      Call DaXpY_(nAsh(ipS),G2(iAsh,jAsh,kAsh,lAsh)*2,
     &                            INT2(1,jAsh,kAsh,lAsh),1,
     *                            Work(ipFock+ipQ),1)
                      ipM=ipM+nOrb(ipS)
*
                    End Do
                  End Do
*
                End Do
              End Do
*                                                                      *
************************************************************************
*                                                                      *
            End Do  ! kS
          End Do     ! jS
        End If
      End Do           ! iS
C     write(6,*) "after 2"
C     call sqprt(work(ipfock),nasht)
C
      !! 3) anti-symmetrize
      !! 4) Divide by the difference of orbital energies
      Call GetMem('FOCKO','ALLO','REAL',ipFockOut,nAshT**2)
      Do iS=1,nSym
        jS=iEOR(iS-1,iSym-1)+1
        If (nAsh(is)*nAsh(jS).ne.0) Then
          !! Anti-symmetrize
C         Call DGeSub(Fock(ipMat(iS,jS)),nAsh(iS),'N',
C    &                Fock(ipMat(jS,iS)),nAsh(jS),'T',
C    &                FockOut(ipMat(iS,jS)),nAsh(iS),
C    &                nAsh(iS),nAsh(jS))
          Call DGeSub(Work(ipFock),nAsh(iS),'N',
     &                Work(ipFock),nAsh(jS),'T',
     &                Work(ipFockOut),nAsh(iS),
     &                nAsh(iS),nAsh(jS))
C         write(6,*) "after 3"
C         call sqprt(work(ipfockout),nasht)


          !! Divide
          imo=1
          Do iAsh = 1, nAsh(iSym)
            iOrb = iAsh + nFro(iSym) + nIsh(iSym)
            EigI = FIFA(iMO+iOrb-1+nBas(iSym)*(iOrb-1))
            Do jAsh = 1, iAsh-1
              jOrb = jAsh + nFro(iSym) + nIsh(iSym)
              EigJ = FIFA(iMO+jOrb-1+nBas(iSym)*(jOrb-1))
              OLagIJ = Work(ipFockOut+iAsh-1+nAsh(iSym)*(jAsh-1))
              Tmp = OLagIJ/(EigI-EigJ)
              DEPSA(iAsh,jAsh) = DEPSA(iAsh,jAsh) + Tmp
              DEPSA(jAsh,iAsh) = DEPSA(jAsh,iAsh) + Tmp
            End Do
          End Do
C         write(6,*) "DEPSA in OffC"
C         call sqprt(depsa,nasht)
        End If
      End Do
      Call GetMem('FOCKO','FREE','REAL',ipFockOut,nAshT**2)
C
      Call GetMem('FOCK ','FREE','REAL',ipFock,nAshT**2)
C
      Return
C
      End Subroutine CnstDEPSA
C
C-----------------------------------------------------------------------
C
      !! PRWF1_CP2
      SUBROUTINE CnstPrec(NOCSF,IOCSF,NOW,IOW,ISYCI,PRE,ci,
     *                    INT1,INT2,Fancy,nLev,nMidV)
      use gugx, only: SGS, CIS
      IMPLICIT REAL*8 (A-H,O-Z)
      INTEGER, INTENT(IN) :: nLev
      DIMENSION NOCSF(NSYM,NMIDV,NSYM),IOCSF(NSYM,NMIDV,NSYM)
      DIMENSION NOW(2,NSYM,NMIDV),IOW(2,NSYM,NMIDV)
      DIMENSION PRE(*)
      dimension ci(*)
      REAL*8 INT1(NLEV,NLEV),INT2(NLEV,NLEV,NLEV,NLEV)
C     CHARACTER(LEN=256) LINE
C     CHARACTER(LEN=1) CODE(0:3)
      REAL*8 Fancy(nRoots,nRoots,nRoots)

#include "rasdim.fh"
#include "caspt2.fh"
#include "WrkSpc.fh"
#include "pt2_guga.fh"
      DIMENSION ICS(MXLEV)
C     DATA CODE /'0','u','d','2'/
      Integer :: nIpWlk
      nIpWlk = CIS%nIpWlk
C
C     Construct (approximate?) preconditioner for the active linear
C     equation that should be solved for non-invariant CASPT2 methods
C     (with IPEA shift)
C
C -- NOTE: THIS PRWF ROUTINE USES THE CONVENTION THAT CI BLOCKS
C -- ARE MATRICES CI(I,J), WHERE THE   F I R S T   INDEX I REFERS TO
C -- THE   U P P E R   PART OF THE WALK.

C SVC: set up a CSF string length as LENCSF
C     LINE=' '
      LENCSF=0
      ISY=0
      DO LEV=1,NLEV
        IF(ISY.NE.SGS%ISM(LEV)) THEN
          ISY=SGS%ISM(LEV)
          LENCSF=LENCSF+1
        END IF
        LENCSF=LENCSF+1
      END DO
      LENCSF=MIN(LENCSF,256)
      LENCSF=MAX(LENCSF,10)

C100  FORMAT(2X,A10,2X,A16,2X,A,2(2X,A13))
C200  FORMAT(2X,I10,2X,'(',I2,':',I1,':',I4,'/',I4,')',
C    &       2X,A,2(2X,F13.6))

C Size of occup/spin coupling part of line:
C     WRITE(6,*)' Occupation of active orbitals, and spin coupling'
C     WRITE(6,*)' of open shells. (u,d: Spin up or down).'
C     WRITE(6,*)' SGUGA info is (Midvert:IsyUp:UpperWalk/LowerWalk)'
C     LINE(1:10)='Occupation'
C     WRITE(6,100)
C    & 'Conf','SGUGA info      ',LINE(1:LENCSF),
C    & 'Coefficient','Weight'

C     SVC2010:
C     allocate scratch memory for determinant expansion
      IF (PRSD) THEN
        CALL GETMEM ('LEX','ALLO','INTEGER',LLEX,NLEV)
      END IF

C     LINE=' '

C -- THE MAIN LOOP IS OVER BLOCKS OF THE ARRAY CI
C    WITH SPECIFIED MIDVERTEX MV, AND UPPERWALK SYMMETRY ISYUP.
      DO 40 MV=1,NMIDV
        DO 41 ISYUP=1,NSYM
          NCI=NOCSF(ISYUP,MV,ISYCI)
          IF(NCI.EQ.0) GOTO 41
          NUP=NOW(1,ISYUP,MV)
          ISYDWN=MUL(ISYUP,ISYCI)
          NDWN=NOW(2,ISYDWN,MV)
          ICONF=IOCSF(ISYUP,MV,ISYCI)
          IUW0=1-NIPWLK+IOW(1,ISYUP,MV)
          IDW0=1-NIPWLK+IOW(2,ISYDWN,MV)
          IDWNSV=0
          DO 30 IDWN=1,NDWN
            DO 31 IUP=1,NUP
              ICONF=ICONF+1
C             COEF=CI(ICONF)
C -- SKIP OR PRINT IT OUT?
C             IF(ABS(COEF).LT.THR) GOTO  31
              IF(IDWNSV.NE.IDWN) THEN
                ICDPOS=IDW0+IDWN*NIPWLK
                ICDWN=CIS%ICASE(ICDPOS)
C -- UNPACK LOWER WALK.
                NNN=0
                DO 10 LEV=1,SGS%MIDLEV
                  NNN=NNN+1
                  IF(NNN.EQ.16) THEN
                    NNN=1
                    ICDPOS=ICDPOS+1
                    ICDWN=CIS%ICASE(ICDPOS)
                  END IF
                  IC1=ICDWN/4
                  ICS(LEV)=ICDWN-4*IC1
                  ICDWN=IC1
  10            CONTINUE
                IDWNSV=IDWN
              END IF
              ICUPOS=IUW0+NIPWLK*IUP
              ICUP=CIS%ICASE(ICUPOS)
C -- UNPACK UPPER WALK:
              NNN=0
              DO LEV=SGS%MIDLEV+1,NLEV
                NNN=NNN+1
                IF(NNN.EQ.16) THEN
                  NNN=1
                  ICUPOS=ICUPOS+1
                  ICUP=CIS%ICASE(ICUPOS)
                END IF
                IC1=ICUP/4
                ICS(LEV)=ICUP-4*IC1
                ICUP=IC1
              END DO
C -- PRINT IT!
              K=0
              ISY=0
              PRE(ICONF) = 0.0D+00
              DO LEV=1,NLEV
                IF(ISY.NE.SGS%ISM(LEV)) THEN
                  ISY=SGS%ISM(LEV)
                  K=K+1
C                 LINE(K:K)=' '
                END IF
                K=K+1
C               LINE(K:K)=CODE(ICS(LEV))
                IF (ICS(LEV).EQ.0) THEN
                  VAL = 0.0D+00
                ELSE IF (ICS(LEV).EQ.3) THEN
                  VAL = 2.0D+00*INT1(LEV,LEV)
C                 L=0
C                 JSY=0
                  DO LEV2=1,NLEV
                    IF (ICS(LEV2).EQ.0) THEN
                    val = val + 0.0d+00
                    ELSE IF ((LEV.EQ.LEV2.AND.ICS(LEV2).EQ.3).OR.
     *                       (LEV.NE.LEV2.AND.ICS(LEV2).EQ.1).OR.
     *                       (LEV.NE.LEV2.AND.ICS(LEV2).EQ.2)) THEN
                      val2 =  4.0d+00*int2(lev,lev ,lev2,lev2)
     *                      - 2.0d+00*int2(lev,lev2,lev ,lev2)
                      val = val + val2
                    ELSE IF (LEV.NE.LEV2.AND.ICS(LEV2).EQ.3) THEN
                      val2 =  4.0d+00*int2(lev,lev ,lev2,lev2)
     *                      - 2.0d+00*int2(lev,lev2,lev ,lev2)
                      val = val + val2
                    END IF
                  END DO
                ELSE
C       write (*,*) "singly occupied"
                  VAL = INT1(LEV,LEV)
C                 L=0
C                 JSY=0
                  DO LEV2=1,NLEV
                    IF (ICS(LEV2).EQ.0.OR.LEV.EQ.LEV2) THEN
                    ELSE IF (ICS(LEV2).EQ.3) THEN
C      val2 =  2.0d+00*int2(lev,lev ,lev2,lev2)
C    *       - 1.0d+00*int2(lev,lev2,lev ,lev2)
C      val2 = 0.0d+00
C      val = val + val2*0.5d+00
                    ELSE
                      val2 = int2(lev,lev ,lev2,lev2)
     *                     + int2(lev,lev2,lev ,lev2)
                      if (ics(lev).eq.ics(lev2)) then
                      val2 = int2(lev,lev ,lev2,lev2)
     *                     - int2(lev,lev2,lev ,lev2)
                      end if
                      val = val + val2
                    END IF
                  END DO
                END IF
                PRE(ICONF) = PRE(ICONF) + VAL
              END DO
C             COEF=CI(ICONF)
C             WRITE(6,200)
C    &               ICONF,MV,ISYUP,IUP,IDWN,
C    &               LINE(1:LENCSF),COEF,COEF**2
C     SVC2010 experimental: add determinant expansion
C             IF (PRSD) THEN
c     Specify projected spin in half integer units
C     Default: use maximum spin projection
C              IMS = ISPIN-1
C              WRITE(6,*)
C              CALL EXPCSF (ICS, NLEV, IMS, IWORK(LLEX))
C              WRITE(6,*)
C             ENDIF
  31        CONTINUE
  30      CONTINUE
  41    CONTINUE
  40  CONTINUE
C
      !! mclr/sa_prec.f
      !! Prepare so-called fancy preconditioner
      Do iSt = 1, nRoots
        Ene = Eact(iSt)
        Do jSt = 1, nRoots
          Do kSt = 1, nRoots
            Fancy(jSt,kSt,iSt) = 0.0D+00
            Do iConf = 1, nConf
              dnum=PRE(iConf)+Ene
              dnum=Sign(Max(Abs(dnum),1.0d-16),dnum)
              Fancy(jSt,kSt,iSt) = Fancy(jSt,kSt,iSt)
     *          + CI(iConf+nConf*(jSt-1))*CI(iConf+nConf*(kSt-1))/dnum
            End Do
          End Do
        End Do
        Call MatInvert(Fancy(1,1,iSt),nRoots)
      End Do
C
C     SVC2010: free scratch for determinant expansion
      IF (PRSD) THEN
        CALL GETMEM ('LEX','FREE','INTEGER',LLEX,NLEV)
      END IF
C     WRITE(6,*)
      RETURN
      END SUBROUTINE CnstPrec
C
C-----------------------------------------------------------------------
C
      !! mclr/dminvci_sa.f
      Subroutine DoPrec(VecIN,VecOUT,CI,Pre,Fancy)
C
C     Apply precondition to CI vectors, taken from the MCLR module
C
      Implicit Real*8 (A-H,O-Z)
C
      Dimension VecIN(*),VecOUT(*),CI(*),Pre(*),
     *          Fancy(nRoots,nRoots,nRoots)
      Dimension rcoeff(nRoots),alpha(nRoots)
C
      !! Standard inverse of the diagonal elements
      Do iRoots = 1, nRoots
        Do iConf = 1, nConf
          VecOUT(iConf+nConf*(iRoots-1))
     *      = VecIN(iConf+nConf*(iRoots-1))/(Pre(iConf)+Eact(iRoots))
        End Do
      End Do
C
      !! Construct reference CI vectors
      Do iRoots = 1, nRoots
        Call LoadCI_XMS('C',1,CI(1+nConf*(iRoots-1)),iRoots,U0)
      End Do
C
      !! The so-called fancy precondioner
      Do iRoots = 1, nRoots
        Do jRoots = 1, nRoots
          rcoeff(jRoots) = DDot_(nconf,VecOUT(1+nConf*(iRoots-1)),1,
     *                                 CI(1+nConf*(jRoots-1)),1)
        End Do
C
        Do jRoots = 1, nRoots
          alpha(jRoots) = 0.0D+00
          Do kRoots = 1, nRoots
            alpha(jRoots) = alpha(jRoots)
     *        + Fancy(jRoots,kRoots,iRoots)*rcoeff(kRoots)
          End Do
        End Do
C
        Do jRoots = 1, nRoots
          Do iConf = 1, nConf
            VecOUT(iConf+nConf*(iRoots-1))
     *        = VecOUT(iConf+nConf*(iRoots-1))
     *        - CI(iConf+nConf*(jRoots-1))*alpha(jRoots)
     *          /(Pre(iConf)+Eact(iRoots))
          End Do
        End Do
      End Do
C
      End Subroutine DoPrec
C
      End Subroutine DEPSAOffC
C
C-----------------------------------------------------------------------
C
      Subroutine DEPSAOffO(OLag,DEPSA,FIFA)
C
      Implicit Real*8 (A-H,O-Z)
C
#include "rasdim.fh"
#include "caspt2.fh"
C
      Dimension OLag(*),DEPSA(nAshT,nAshT),FIFA(*)
C
C     This is much easier; similar to the frozen core approximation.
C     Corresponds to the first term in Eq. (70)
C
      iMO  = 1
      DO iSym = 1, nSym
        nAshI = nAsh(iSym)
        nOrbI = 0
        If (nAshI.ne.0) Then
          nOrbI = nBas(iSym)-nDel(iSym)
          nFroI = nFro(iSym)
          nIshI = nIsh(iSym)
          nBasI = nBas(iSym)
C
          Do iAsh = 1, nAshI
            iOrb = iAsh + nFroI + nIshI
            EigI = FIFA(iMO+iOrb-1+nBasI*(iOrb-1))
            Do jAsh = 1, iAsh-1
              jOrb = jAsh + nFroI + nIshI
              EigJ = FIFA(iMO+jOrb-1+nBasI*(jOrb-1))
              OLagIJ = OLag(iMO+iOrb-1+nOrbI*(jOrb-1))
              OLagJI = OLag(iMO+jOrb-1+nOrbI*(iOrb-1))
              Tmp = -(OLagIJ-OLagJI)/(EigI-EigJ)*0.5D+00
C
              DEPSA(iAsh,jAsh) = DEPSA(iAsh,jAsh) + Tmp
              DEPSA(jAsh,iAsh) = DEPSA(jAsh,iAsh) + Tmp
            End Do
          End Do
        End If
        iMO  = iMO  + nOrbI*nOrbI
      End Do
C
      End Subroutine DEPSAOffO
C
C-----------------------------------------------------------------------
C
      Subroutine LinDepLag(BDer,SDer,nAS,nIN,iSym,iCase)
C
      use caspt2_gradient, only: LUSTD, idBoriMat
C
      Implicit Real*8 (A-H,O-Z)
C
#include "rasdim.fh"
#include "caspt2.fh"
#include "eqsolv.fh"
#include "WrkSpc.fh"
#include "caspt2_grad.fh"
C
      DIMENSION WGRONK(2)
      Dimension BDer(*),SDer(*)
C
C     Compute contributions that arise from the non-invariance effect
C     in non-orthogonal -> orthogonal ICB rotations
C     See J. Chem. Phys. 2023, 158, 174112. for details, in particular,
C     Section II C 3 "Non-invariance with respect to orthogonal..."
C
      !! Obtain the X matrix
      !! First, read S
      NS = NAS*(NAS+1)/2
      CALL GETMEM('S','ALLO','REAL',LS,NS)
      CALL GETMEM('SS','ALLO','REAL',LSS,NAS*NAS)
      idS = idSMAT(iSym,iCase)
      CALL DDAFILE(LUSBT,2,WORK(LS),NS,idS)
      IJ=0
      DO J=1,NAS
        DO I=1,J
          IJ=IJ+1
          WORK(LSS-1+NAS*(J-1)+I)=WORK(LS-1+IJ)
          WORK(LSS-1+NAS*(I-1)+J)=WORK(LS-1+IJ)
        END DO
      END DO
C
      CALL GETMEM('LVEC','ALLO','REAL',LVEC,NAS**2)
      CALL GETMEM('LEIG','ALLO','REAL',LEIG,NAS)
C
      CALL GETMEM('LSCA','ALLO','REAL',LSCA,NAS)
      IDIAG=0
      DO I=1,NAS
        IDIAG=IDIAG+I
        SD=WORK(LS-1+IDIAG)
        If (IFDORTHO) then
          WORK(LSCA-1+I)=1.0D+00
        Else
          IF(SD.GT.THRSHN) THEN
* Small variations of the scale factor were beneficial
              WORK(LSCA-1+I)=(1.0D00+DBLE(I)*3.0D-6)/SQRT(SD)
          ELSE
            WORK(LSCA-1+I)=0.0D0
          END IF
        End If
      END DO
      IJ=0
      DO J=1,NAS
        DO I=1,J
          IJ=IJ+1
          WORK(LS-1+IJ)=WORK(LS-1+IJ)*
     &        WORK(LSCA-1+I)*WORK(LSCA-1+J)
        END DO
      END DO
C
      IJ=0
      DO J=1,NAS
        DO I=1,J
          IJ=IJ+1
          WORK(LVEC-1+NAS*(J-1)+I)=WORK(LS-1+IJ)
        END DO
      END DO
      INFO=0
      call dsyev_('V','L',NAS,WORK(LVEC),NAS,WORK(LEIG),WGRONK,-1,INFO)
      NSCRATCH=INT(WGRONK(1))
      CALL GETMEM('SCRATCH','ALLO','REAL',LSCRATCH,NSCRATCH)
      call dsyev_('V','U',NAS,WORK(LVEC),NAS,WORK(LEIG),WORK(LSCRATCH),
     &            NSCRATCH,INFO)
      CALL GETMEM('SCRATCH','FREE','REAL',LSCRATCH,NSCRATCH)
C
      DO I=1,NAS
        SCA=WORK(LSCA-1+I)
C       CALL DSCAL_(NIN,SCA,WORK(LVEC-1+I),NAS)
        CALL DSCAL_(NAS,SCA,WORK(LVEC-1+I),NAS)
      END DO
      CALL GETMEM('LSCA','FREE','REAL',LSCA,NAS)
      CALL GETMEM('LS','FREE','REAL',LS,NS)
C
      !! Scale only the independent vectors to avoid
      !! any numerically unstable computation
      DO I=1,NAS
        EVAL=WORK(LEIG-1+I)
        IF(EVAL.LT.THRSHS) CYCLE
        FACT=1.0D00/SQRT(EVAL)
        Call DScal_(nAS,FACT,Work(LVEC+nAS*(I-1)),1)
      END DO
C
      CALL GETMEM('LLAG','ALLO','REAL',LLAG,NAS**2)
      IDB=IDBoriMat(ISYM,ICASE)
      NB=NS
      CALL GETMEM('LB','ALLO','REAL',LB,NB)
      CALL DDAFILE(LUSTD,2,WORK(LB),NB,IDB)
      CALL GETMEM('LF','ALLO','REAL',LF,NAS**2)
      IJ=0
      DO J=1,NAS
        DO I=1,J
          IJ=IJ+1
          WORK(LF-1+NAS*(J-1)+I)=WORK(LB-1+IJ)
          WORK(LF-1+NAS*(I-1)+J)=WORK(LB-1+IJ)
        END DO
      END DO
C
      !! Compute the partial derivative
      !! Work(LF)  : B
      !! BDER      : D
      !! Work(LVEC): X^0 and X
      Call DGEMM_('N','T',NAS,NAS,NAS,
     *            2.0D+00,Work(LF),NAS,BDER,NAS,
     *            0.0D+00,Work(LLAG),NAS)
      Call DGEMM_('N','N',NAS,NAS,NAS,
     *            1.0D+00,Work(LLAG),NAS,Work(LVEC),NAS,
     *            0.0D+00,Work(LF),NAS)
      Call DCopy_(NAS*NAS,Work(LF),1,Work(LLAG),1)
C
      CALL DGEMM_('T','N',NAS,NAS,NAS,
     *            1.0D+00,Work(LVEC),NAS,Work(LLAG),NAS,
     *            0.0D+00,Work(LF),NAS)
      !! At this point,
      !! Work(LF) = 2 \mathcal{X}^0 * B * D * \mathcal{X}
C
      !! remove dependent part
      !! (linearly indep-indep and dep-dep)
      Do I = 1, nAS-nIN
        Do J = 1, nAS-nIN
          Work(LF+i-1+nAS*(j-1)) = 0.0D+00
        End Do
      End Do
      Do I = nAS-nIN+1, nAS
        Do J = nAS-nIN+1, nAS
          Work(LF+i-1+nAS*(j-1)) = 0.0D+00
        End Do
      End Do
C
      !! orthogonal -> non-orthogonal
      !! Finalize Eq. (62)
      CALL DGEMM_('N','N',NAS,NAS,NAS,
     *            1.0D+00,Work(LVEC),NAS,Work(LF),NAS,
     *            0.0D+00,Work(LLAG),NAS)
      CALL DGEMM_('N','T',NAS,NAS,NAS,
     *            1.0D+00,Work(LLAG),NAS,Work(LVEC),NAS,
     *            0.0D+00,Work(LF),NAS)
C
      Call DaXpY_(nAS*nAS,1.0D+00,Work(LF),1,SDER,1)
C
      CALL GETMEM('LLAG','FREE','REAL',LLAG,NAS**2)
      CALL GETMEM('LB','FREE','REAL',LB,NB)
      CALL GETMEM('LF','FREE','REAL',LF,NAS**2)
C
      CALL GETMEM('SS','FREE','REAL',LSS,NAS*NAS)
      CALL GETMEM('LEIG','FREE','REAL',LEIG,NAS)
      CALL GETMEM('LVEC','FREE','REAL',LVEC,NAS**2)
C
      Return
C
      End Subroutine LinDepLag
