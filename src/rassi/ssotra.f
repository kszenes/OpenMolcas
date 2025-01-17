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
      SUBROUTINE SSOTRA(SGS,CIS,EXS,ISYM,LSM,NA,NO,TRA,NCO,CI,TMP)
      use gugx, only: SGStruct, CIStruct, EXStruct
      IMPLICIT REAL*8 (A-H,O-Z)
      Integer ISYM, LSM, NA, NO, NCO
      Real*8 TRA(NO,NO),CI(NCO),TMP(NCO)
#include "rassi.fh"
#include "WrkSpc.fh"
      Type (SGSTruct) SGS
      Type (CISTruct) CIS
      Type (EXSTruct) ExS

C ILEV(IORB)=GUGA LEVEL CORRESPONDING TO A SPECIFIC ACTIVE ORBITAL
C OF SYMMETRY ISYM.
      CALL GETMEM('ILEV','ALLO','INTE',LILEV,NA)
      NI=NO-NA
      IL=0
      DO IP=1,NA
5       IL=IL+1
        IF(SGS%ISM(IL).NE.ISYM) GOTO 5
        IWORK(LILEV-1+IP)=IL
      END DO
CTEST      write(*,*)' Check prints in SSOTRA.'
CTEST      write(*,*)' ISYM:',ISYM
      DO IK=1,NA
        IKLEV=IWORK(LILEV-1+IK)
        CALL DCOPY_(NCO,[0.0D0],0,TMP,1)
        DO IP=1,NA
          IPLEV=IWORK(LILEV-1+IP)
          CPK=TRA(NI+IP,NI+IK)
          IF(IP.EQ.IK) CPK=CPK-1.0D00
          X=0.5D0*CPK
CTEST          write(*,*)' IP,IK,X:',IP,IK,X
          IF(ABS(X).LT.1.0D-14) cycle
          CALL SIGMA1(SGS,CIS,EXS,IPLEV,IKLEV,X,LSM,CI,TMP)
        END DO
        CKK=TRA(NI+IK,NI+IK)
        X= 3.0D00-CKK
        CALL DAXPY_(NCO,X,TMP,1,CI,1)
        DO IP=1,NA
          IPLEV=IWORK(LILEV-1+IP)
          CPK=TRA(NI+IP,NI+IK)
          IF(IP.EQ.IK) CPK=CPK-1.0D00
          IF(ABS(CPK).LT.1.0D-14) cycle
          CALL SIGMA1(SGS,CIS,EXS,IPLEV,IKLEV,CPK,LSM,TMP,CI)

        END DO
      END DO
      CALL GETMEM('ILEV','FREE','INTE',LILEV,NA)

      END SUBROUTINE SSOTRA
