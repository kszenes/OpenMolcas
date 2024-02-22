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
      SUBROUTINE MKSEG(SGS,NLEV,NVERT,NMIDV,IDRT,IDOWN,
     &                 LTV,IVR,MVL,MVR,ISGMNT,VSGMNT)
      use rassi_aux, only: ipglob
      use Struct, only: SGStruct
      IMPLICIT REAL*8 (A-H,O-Z)
      Type (SGStruct) SGS
      CHARACTER*26 CC1,CC2,CTVPT,CBVPT,CSVC
      CHARACTER*20 FRML(7),TEXT
#include "segtab.fh"
      DIMENSION IVR(NVERT,2),ISGMNT(NVERT,26),VSGMNT(NVERT,26)
      DIMENSION IDRT(NVERT,5),IDOWN(NVERT,0:3),LTV(-1:NLEV)
      DIMENSION MVL(NMIDV,2),MVR(NMIDV,2)
      PARAMETER (LTAB=1, NTAB=2, IATAB=3, IBTAB=4, ICTAB=5)
      PARAMETER (ZERO=0.0D00, ONE=1.0D00)
C PURPOSE: CONSTRUCT THE TABLES ISGMNT AND VSGMNT.
C ISGMNT(IVLT,ISGT) REFERS TO A SEGMENT OF THE SEGMENT TYPE
C    ISGT=1,..,26, WHOSE TOP LEFT VERTEX IS IVLT. ISGMNT GIVES
C    ZERO IF THE SEGMENT IS IMPOSSIBLE IN THE GRAPH DEFINED BY
C    THE PALDUS TABLE IDRT. ELSE IT IS THE BOTTOM LEFT VERTEX
C    NUMBER OF THE SEGMENT. THE SEGMENT VALUE IS THEN VSGMNT.




C Dereference SGS
      MVSTA=SGS%MVSta
      MVEND=SGS%MVEnd

      CC1=  '01230201011230122313230123'
      CC2=  '01231323012230112302010123'
      CTVPT='00000000111112222211223333'
      CBVPT='00001122112112212233333333'
      CSVC ='11111615124721732215161111'
      FRML(1)='        1.0         '
      FRML(2)='       -1.0         '
      FRML(3)='        1/(B+1)     '
      FRML(4)='       -1/(B+1)     '
      FRML(5)='  SQRT(   B /(B+1)) '
      FRML(6)='  SQRT((B+2)/(B+1)) '
      FRML(7)='  SQRT(B(B+2))/(B+1)'
      READ(CC1,'(26I1)') IC1
      READ(CC2,'(26I1)') IC2
      READ(CTVPT,'(26I1)') ITVPT
      READ(CBVPT,'(26I1)') IBVPT
      READ(CSVC,'(26I1)') ISVC
      DO IV=1,NVERT
        IVR(IV,1)=0
        IVR(IV,2)=0
      END DO
      DO LEV=1,NLEV
        IV1=LTV(LEV)
        IV2=LTV(LEV-1)-1
        DO IVL=IV1,IV2
          IAL=IDRT(IVL,IATAB)
          IBL=IDRT(IVL,IBTAB)
          DO IV=IVL+1,IV2
            IA=IDRT(IV,IATAB)
            IF(IA.EQ.IAL) THEN
              IB=IDRT(IV,IBTAB)
              IF(IB.EQ.(IBL-1)) IVR(IVL,1)=IV
            ELSE IF (IA.EQ.(IAL-1)) THEN
              IB=IDRT(IV,IBTAB)
              IF(IB.EQ.(IBL+1)) IVR(IVL,2)=IV
            END IF
          END DO
        END DO
      END DO
C CONSTRUCT THE MVL AND MVR TABLES:
      DO IVL=MVSTA,MVEND
        MVLL=IVL-MVSTA+1
        MVRR=0
        IF(IVR(IVL,1).NE.0) MVRR=IVR(IVL,1)-MVSTA+1
        MVR(MVLL,1)=MVRR
        MVRR=0
        IF(IVR(IVL,2).NE.0) MVRR=IVR(IVL,2)-MVSTA+1
        MVR(MVLL,2)=MVRR
        MVL(MVLL,1)=0
        MVL(MVLL,2)=0
      END DO
      DO MV=1,NMIDV
        IF(MVR(MV,1).NE.0) MVL(MVR(MV,1),1)=MV
        IF(MVR(MV,2).NE.0) MVL(MVR(MV,2),2)=MV
      END DO
      IF(IPGLOB.GE.5) THEN
        WRITE(6,*)
        WRITE(6,*)' MIDVERT PAIR TABLES MVL,MVR IN MKSEG:'
        WRITE(6,*)' MVL TABLE:'
        WRITE(6,1234)(MV,MVL(MV,1),MVL(MV,2),MV=1,NMIDV)
        WRITE(6,*)' MVR TABLE:'
        WRITE(6,1234)(MV,MVR(MV,1),MVR(MV,2),MV=1,NMIDV)
1234    FORMAT(3(3(1X,I4),4X))
      END IF
      IF(IPGLOB.GE.5) THEN
        WRITE(6,*)
        WRITE(6,*)' VERTEX PAIR TABLE IVR IN MKSEG:'
        WRITE(6,1234)(IVL,IVR(IVL,1),IVR(IVL,2),IVL=1,NVERT)
      END IF
C INITIALIZE SEGMENT TABLES, AND MARK VERTICES AS UNUSABLE:
      DO IVLT=1,NVERT
        DO ISGT=1,26
          ISGMNT(IVLT,ISGT)=0
          VSGMNT(IVLT,ISGT)=ZERO
        END DO
      END DO
      DO IVLT=1,NVERT
        DO ISGT=1,26
          ITT=ITVPT(ISGT)
          IVRT=IVLT
          IF((ITT.EQ.1).OR.(ITT.EQ.2)) IVRT=IVR(IVLT,ITT)
          IF(IVRT.EQ.0) cycle
          IVLB=IDOWN(IVLT,IC1(ISGT))
          IF(IVLB.EQ.0) cycle
          IVRB=IDOWN(IVRT,IC2(ISGT))
          IF(IVRB.EQ.0) cycle
C SEGMENT IS NOW ACCEPTED AS POSSIBLE.
          ISGMNT(IVLT,ISGT)=IVLB
          IB=IDRT(IVLT,IBTAB)
          GOTO (1001,1002,1003,1004,1005,1006,1007) ISVC(ISGT)
1001      V=ONE
          GOTO 99
1002      V=-ONE
          GOTO 99
1003      V=ONE/DBLE(1+IB)
          GOTO 99
1004      V=-(ONE/DBLE(1+IB))
          GOTO 99
1005      V=SQRT(DBLE(IB)/DBLE(1+IB))
          GOTO 99
1006      V=SQRT(DBLE(2+IB)/DBLE(1+IB))
          GOTO 99
1007      V=SQRT(DBLE(IB*(2+IB)))/DBLE(1+IB)
99        VSGMNT(IVLT,ISGT)=V
        END DO
      END DO
      IF(IPGLOB.GE.5) THEN
        WRITE(6,*)' SEGMENT TABLE IN MKSEG.'
        WRITE(6,*)' VLT SGT ICL ICR VLB       SEGMENT TYPE    ',
     *            '     FORMULA'
        DO IV=1,NVERT
          DO ISGT=1,26
            ID=ISGMNT(IV,ISGT)
            IF(ID.EQ.0) cycle
            ICL=IC1(ISGT)
            ICR=IC2(ISGT)
            IF(ISGT.LE.4) TEXT='  WALK SECTION.'
            IF((ISGT.GE.5).AND.(ISGT.LE.8)) TEXT=' TOP SEGMENT.'
            IF((ISGT.GE.9).AND.(ISGT.LE.18)) TEXT=' MID-SEGMENT.'
            IF((ISGT.GE.19).AND.(ISGT.LE.22)) TEXT=' BOTTOM SEGMENT.'
            IF(ISGT.GT.22) TEXT=' DOWN-WALK SECTION.'
            WRITE(6,2345) IV,ISGT,ICL,ICR,ID,TEXT,FRML(ISVC(ISGT))
2345        FORMAT(1X,5I4,5X,A20,5X,A20)
          END DO
        END DO
      END IF

      END
