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
* Copyright (C) 2006, Per Ake Malmqvist                                *
*               2009, Grigory A. Shamov                                *
************************************************************************
      Subroutine XPBEsol(mGrid,dF_dRho,ndF_dRho,
     &                   Coeff,iSpin,F_xc,T_X)
************************************************************************
*                                                                      *
* Object: To compute the X part of PBEsol, PRL 100,136406,2008         *
*         simple change of paramters in PBE                            *
*                                                                      *
* Called from:                                                         *
*                                                                      *
* Calling    :                                                         *
*                                                                      *
*      Author:Per Ake Malmqvist, Department of Theoretical Chemistry,  *
*             University of Lund, SWEDEN. June 2006                    *
************************************************************************
      use nq_Grid, only: Rho, Sigma
      use nq_Grid, only: vRho
      Implicit Real*8 (A-H,O-Z)
#include "real.fh"
#include "nq_index.fh"
      Real*8 dF_dRho(ndF_dRho,mGrid), F_xc(mGrid)
* Call arguments:
* Weights(mGrid) (input) integration weights.
* Rho(nRho,mGrid) (input) Density and density derivative values,
*   Rho(1,iGrid) is rho_alpha values, Rho(2,iGrid) is rho_beta values
*   Rho(i,iGrid) is grad_rho_alpha (i=3..5 for d/dx, d/dy, d/dz)
*   Rho(i,iGrid) is grad_rho_beta  (i=6..8 for d/dx, d/dy, d/dz)
* dF_dRho (inout) are (I believe) values of derivatives of the
*   DFT functional (*NOT* derivatives of Fock matrix contributions).
* F_xc is values of the DFT energy density functional (surprised?)

* IDORD=Order of derivatives to request from XPBE:
      idord=1


      if (ispin.eq.1) then
* ispin=1 means spin zero.
* T_X: Screening threshold of total density.
        Ta=0.5D0*T_X
        do iGrid=1,mgrid
         rhoa=max(1.0D-24,Rho(1,iGrid))
         if(rhoa.lt.Ta) goto 110
         sigmaaa=Sigma(1,iGrid)

         call XPBEsol_(idord,rhoa,sigmaaa,Fa,dFdrhoa,dFdgammaaa,
     &          d2Fdra2,d2Fdradgaa,d2Fdgaa2)
         F_xc(iGrid)=F_xc(iGrid)+Coeff*(2.0D0*Fa)
         vRho(1,iGrid)=vRho(1,iGrid)+Coeff*dFdrhoa
* Maybe derivatives w.r.t. gamma_aa, gamma_ab, gamma_bb should be used instead.
         dF_dRho(ipGxx,iGrid)=dF_dRho(ipGxx,iGrid)+Coeff*dFdgammaaa
* Note: For xpbe, dFdgammaab is zero.
 110     continue
        end do
      else
* ispin .ne. 1, use both alpha and beta components.
        do iGrid=1,mgrid
         rhoa=max(1.0D-24,Rho(1,iGrid))
         rhob=max(1.0D-24,Rho(2,iGrid))
         rho_tot=rhoa+rhob
         if(rho_tot.lt.T_X) goto 210
         sigmaaa=Sigma(1,iGrid)
         call XPBEsol_(idord,rhoa,sigmaaa,Fa,dFdrhoa,dFdgammaaa,
     &          d2Fdra2,d2Fdradgaa,d2Fdgaa2)

         sigmabb=Sigma(2,iGrid)
         call XPBEsol_(idord,rhob,sigmabb,Fb,dFdrhob,dFdgammabb,
     &          d2Fdrb2,d2Fdrbdgbb,d2Fdgbb2)

         F_xc(iGrid)=F_xc(iGrid)+Coeff*(Fa+Fb)
         vRho(1,iGrid)=vRho(1,iGrid)+Coeff*dFdrhoa
         vRho(2,iGrid)=vRho(2,iGrid)+Coeff*dFdrhob
* Maybe derivatives w.r.t. gamma_aa, gamma_ab, gamma_bb should be used instead.
* Note: For xpbe, dFdgammaab is zero.
         dF_dRho(ipGaa,iGrid)=dF_dRho(ipGaa,iGrid)+Coeff*dFdgammaaa
         dF_dRho(ipGbb,iGrid)=dF_dRho(ipGbb,iGrid)+Coeff*dFdgammabb
 210     continue
        end do
      end if

      Return
      End

      Subroutine XPBEsol_(idord,rho_s,sigma_s,
     &                        f,dFdr,dFdg,d2Fdr2,d2Fdrdg,d2Fdg2)
************************************************************************
*                                                                      *
* Object: To compute the X part of PBEsol, PRL 100,136406,2008         *
*                                                                      *
* Called from:                                                         *
*                                                                      *
* Calling    :                                                         *
*                                                                      *
*      Author:Per Ake Malmqvist, Department of Theoretical Chemistry,  *
*             University of Lund, SWEDEN. December 2006                *
*      modified by GAS, UofM 2009                                      *
************************************************************************
      Implicit Real*8 (A-H,O-Z)
C Cmu modified to 10/81
      Data Ckp, Cmu / 0.804D0, 0.12345679012346D0/
      Data CkF / 3.0936677262801359310D0/
      Data CeX /-0.73855876638202240588D0/

      rho=max(1.0D-24,rho_s)
      sigma=max(1.0D-24,sigma_s)

      rthrd=(2.D0*rho)**(1.0D0/3.0D0)
      XkF=CkF*rthrd

* FX, and its derivatives wrt S:
      s2=sigma/((2.D0*rho)*XkF)**2
      s=sqrt(s2)
      Cmus2=Cmu*s2
      t=1.0D0/(Ckp+Cmus2)
      fx=(Cmus2+Ckp*(1.0D0+Cmus2))*t
      a=2.0D0*Cmu*(Ckp*t)**2
      dfxds=a*s
      d2fxds2=-a*(3.0D0*Cmus2-Ckp)*t

* The derivatives of S wrt rho (r)  and sigma (g)
      a=1.0D0/(3.0D0*rho)
      b=1.0D0/(2.0D0*sigma)
      dsdr=-4.0D0*s*a
      dsdg=s*b
      d2sdr2=-7.0D0*dsdr*a
      d2sdrdg=dsdr*b
      d2sdg2=-dsdg*b

* Thus, derivatives of fx wrt rho and sigma
      dfxdr=dsdr*dfxds
      dfxdg=dsdg*dfxds
      d2fxdr2=d2sdr2*dfxds+dsdr**2*d2fxds2
      d2fxdrdg=d2sdrdg*dfxds+dsdr*dsdg*d2fxds2
      d2fxdg2=d2sdg2*dfxds+dsdg**2*d2fxds2

* rho*XeX, and its derivatives wrt rho
      rX=rho*CeX*rthrd
      drXdr=4.0d0*rX*a
      d2rXdr2=drXdr*a

* Put it together:
      F=rX*fx
      dFdr=drXdr*fx+rX*dfxdr
      dFdg=rX*dfxdg
      d2Fdr2=d2rXdr2*fx+2.0D0*drXdr*dfxdr+rX*d2fxdr2
      d2Fdrdg=drXdr*dfxdg +rX*d2fxdrdg
      d2Fdg2=rX*d2fxdg2

      Return
c Avoid unused argument warnings
      If (.False.) Call Unused_integer(idord)
      End
