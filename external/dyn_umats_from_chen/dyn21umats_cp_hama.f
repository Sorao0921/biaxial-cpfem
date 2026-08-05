#include "define.inc"
#include "define2.inc"
      subroutine umatCpHamaGetHsvOffsets(numSys,OFF_F,OFF_CRSS,
     1     OFF_RHO,OFF_R,OFF_S11,OFF_M11,OFF_GS,OFF_GN,OFF_EUL)

      implicit none
      integer numSys
      integer OFF_F,OFF_CRSS,OFF_RHO,OFF_R
      integer OFF_S11,OFF_M11,OFF_GS,OFF_GN,OFF_EUL

c    compute offsets (1-based indexing)
      OFF_F    = 1
      OFF_CRSS = OFF_F    + 9
      OFF_RHO  = OFF_CRSS + numSys
      OFF_R    = OFF_RHO  + numSys
      OFF_S11  = OFF_R    + 9
      OFF_M11  = OFF_S11  + 3*numSys
      OFF_GS   = OFF_M11  + 3*numSys
      OFF_GN   = OFF_GS   + numSys
      OFF_EUL  = OFF_GN   + 1

      end subroutine


      subroutine umatCpHama(cm,eps,sig,epsp,hsv,dt1,capa,etype,tt,
     1   temper,failel,crv,nnpcrv,cma,qmat,elsiz,idele,reject)
!============================================================
! Declaration of constitutive variables
!------------------------------------------------------------
      implicit none
      include 'nlqparm'
      include 'bk06.inc'
      include 'iounits.inc'
c     UMAT variables
      double precision cm(*),eps(*),sig(*),hsv(*),crv(lq1,2,*)
      double precision cma(*),qmat(3,3)
      integer nnpcrv(*)
      integer ::nhsv=300
      double precision dt1
      character*5 etype
      logical failel,reject
      INTEGER idele
c     
      double precision typeUmat,typeOri
      integer,parameter:: typeCry=3 ! 2: BCC12, 3: BCC24
      integer numSys
c     Intermedia variables
      integer i,j,k,l
c     Kinetic model variables
      double precision f(3,3),f_n1(3,3),df_n1(3,3),f_n1_inv(3,3)
      double precision f_det
      double precision L_n1(3,3)
      double precision D(3,3),Dv(6)
      double precision W(3,3),Wv(3)
      double precision We(3,3),Wev(3)
      double precision We1
      double precision exp_we(3,3)
c     Kinematic variables
      double precision s11(3,maxSys),m11(3,maxSys)
      double precision s11_n1(3,maxSys),m11_n1(3,maxSys)
      double precision r(3,3),RL(6,6),r_n1(3,3)
      double precision Pa(3,3,maxSys),eschmid(6,maxSys)
      double precision Wa(3,3,maxSys),wschmid(3,maxSys)
      double precision nschmid(6,maxSys)
      double precision euler(3),euler_n1(3)
      double precision Dp(6),Wp(3)
c     Slip system constitutive model variables
      double precision tau(maxSys),tauNsf(maxSys)
      double precision dgamma(maxSys)
      double precision gamma_slip(maxSys)
      double precision dgamma_tol,gamma_n1
      double precision g_crss(maxSys)
      double precision dgamma0,mval,dgamma_lim
c     Stress Update model variables
      double precision ym,pr,bk,sm
      double precision L_ela(6,6),L_ela_cry(6,6)
      double precision dsig_0(6),sig_jau(6),sig_r(6),sig_n1(6)
c     Hardening model variables
      integer hardType
      double precision g0,gs,h0,hs,q
c     Solid element variables
      double precision g,g2,gc,q1,q3,davg,p,deti,c22i,c23i,fac
      double precision temper,elsiz,epsp,capa,tt
c Declaration of offset hsv indices
      integer OFF_F,OFF_CRSS,OFF_RHO,OFF_R,OFF_S11
      integer OFF_M11,OFF_GS,OFF_GN,OFF_EUL

c     Variables for thermal activation slip rate
      double precision tau0,DeltaGk0,rhoInfi
      double precision thmSlpCstP,thmSlpCstQ,thmSlpCstT

c     Variables for dislocation evolution
      double precision bv,km,yc,alpha,mu,rho0
      double precision dcrss(maxSys),crss(maxSys)
      double precision rho(maxSys),drho(maxSys)
      double precision drhoSlip(maxSys)
      double precision drhoRecy(maxSys)
      double precision kappa1,kappa2
      double precision rhoTol,rhoMean
      double precision drhoSlipTol,drhoRecyTol

      double precision temperature,slope
      real tempCurId
!============================================================
! Obtain variables from materials constants
!------------------------------------------------------------
      call umatCpHamaGetMc(cm,ym,pr,bk,sm,
     &       typeUmat,dgamma0,tau0,thmSlpCstP,
     &       thmSlpCstQ,thmSlpCstT,DeltaGk0,
     &       typeOri,euler,
     &   hardType,rho0,g0,yc,km,alpha,kappa1,kappa2,rhoInfi)

      call getSlipSysNum(typeCry,numSys)

      tempCurId=2
!============================================================
      if (.not.failel) then
!============================================================
! Initial step: ncrycle = 0
!------------------------------------------------------------  
      if(ncycle==0) then
      if(thmSlpCstT.lt.-0.5.and.thmSlpCstT.gt.-1.5)then
      call crvval(crv,nnpcrv,tempCurId,tt,temperature,slope)
      if(idele.eq.1)then
      ! print *, 'Temperature from curve:', tt,temperature
      endif
      else if(thmSlpCstT.lt.-1.5.and.thmSlpCstT.gt.-2.5)then
      temperature=temper
      else
      temperature=thmSlpCstT
      endif
c     Initialize crystal orientation from csv file
      if(typeOri.eq.1)then
      call getCrystalOriCsv(idele,euler)
      endif
c     Init crystal orientation, slip system vectors
        call initCrystal(typeOri,typeCry,euler,
     1           numSys,r,s11,m11)
c     Initialize the hsv list
      call umatCpHamaInitHsv(g0,rho0,r,s11,m11,numSys,nhsv,
     1      hsv,sig)
      call umatCpHamaGetHsvOffsets(numSys,OFF_F,OFF_CRSS,
     & OFF_RHO,OFF_R,OFF_S11,OFF_M11,OFF_GS,OFF_GN,OFF_EUL)
!============================================================
! Calculation begins: ncycle > 0
!------------------------------------------------------------
      else
      if(thmSlpCstT.lt.-0.5.and.thmSlpCstT.gt.-1.5)then
      call crvval(crv,nnpcrv,tempCurId,tt,temperature,slope)
      if(idele.eq.1)then
      ! print *, 'Temperature from curve:', tt,temperature
      endif
      else if(thmSlpCstT.lt.-1.5.and.thmSlpCstT.gt.-2.5)then
      temperature=temper
      else
      temperature=thmSlpCstT
      endif
c     Obtain defromation gradient from hsv
      call getDispGradfromHsv(hsv,nhsv,f,f_n1)
c     Obtain CRSS from hsv
      call umatCpHamaGetHsv(hsv,numSys,crss,r,s11,m11,
     1       gamma_n1,gamma_slip,rho)
!============================================================
! Kinetic model
!------------------------------------------------------------
      call calDeforSpinRateByDispGrad(f,f_n1,dt1,Dv,Wv)
!============================================================
! Constitutive model for slip at slip system
!------------------------------------------------------------ 
      call calSchmidTensor(s11,m11,numSys,
     1     Pa,Wa,eschmid,wschmid)
      call calSigRss(sig(1:6),eschmid,numSys,tau)
      call calNonSchmidTensor(s11,m11,numSys,nschmid)
      call calSigRss(sig(1:6),nschmid,numSys,tauNsf)
      call vecAdd(tau,tauNsf,numSys,tau)

      call calSlipRateHeatAct(tau,crss,dgamma0,tau0,
     &    DeltaGk0,thmSlpCstP,thmSlpCstQ,temperature,
     &    numSys,dgamma)
      call updateCss(dgamma,numSys,dt1,
     1     dgamma_tol,gamma_slip,gamma_n1)
c     Project the slip deformation into macro deformation and spin
c     as plastic corrector
      call calStrainRateBySlip(dgamma,eschmid,numSys,Dp)
      call calSpinRateBySlip(dgamma,wschmid,numSys,Wp)

!============================================================
! Update cauchy stress
!------------------------------------------------------------
c     Fourth-order elastic tensor at crystal coordinate
      call calElasIsoTensorCrystalGlobal(ym,pr,r,L_ela)
c     Update the Cauchy stress tensor
      call mat33Det(f,f_det)
      call updateSigJaum(sig,eschmid,wschmid,dgamma,Wv,
     1     Dv,L_ela,f_det,numSys,dt1,sig_n1)

!============================================================
! Rotation model
!------------------------------------------------------------
c     calculate the rotation rate for further rotation
      call updateOrientation(Wv,Wp,s11,m11,r,numSys,dt1,
     1  s11_n1,m11_n1,r_n1)
c     Extract the euler angle from the tranformation matrix
      call calEulerbyTransMat(r_n1,euler_n1)

!============================================================
! Dislocation update and Hardening model
!------------------------------------------------------------
      mu=sm/(2.0*(1.0+pr))
      if(yc.lt.0.d0) then ! determine yc if not given
            call calDslYcHama(temperature,yc)
      endif
      call calDslRateHama(yc,km,rho,typeCry,numSys,
     1      dgamma,drhoSlip)
      call calDslRcvyRateKohenert(rho,temperature,mu,
     &     kappa1,kappa2,numSys,drhoRecy,rhoInfi)
      call vecMinus(drhoSlip,drhoRecy,numSys,drho)
      call updateDsl(drho,numSys,dt1,rho)

      call calCrssRateDslHama(rho,dgamma,alpha,mu,km,yc,
     1         typeCry,numSys,dcrss)
      call updateCrss(dcrss,dt1,numSys,crss)

!============================================================
! Give constitutive and non-constitutive variables to hsv
!------------------------------------------------------------
      call umatCpHamaUpdateHsv(numSys,sig_n1,f_n1,crss,
     1       r_n1,s11_n1,m11_n1,gamma_slip,gamma_n1,
     2       rho,hsv,sig,euler_n1)

c     Store some variables for output

c     Store dislocation density and rate average
      rhoTol=0.0
      drhoSlipTol=0.0
      drhoRecyTol=0.0
      do l=1,numSys
            rhoTol=rhoTol+rho(l)
            drhoSlipTol=drhoSlipTol+drhoSlip(l)
            drhoRecyTol=drhoRecyTol+drhoRecy(l)
      enddo
      rhoMean=rhoTol/numSys
      ! drhoSlipTol=drhoSlipTol/numSys
      ! drhoRecyTol=drhoRecyTol/numSys
      hsv(296)=rhoTol
      hsv(297)=rhoMean
      hsv(298)=drhoSlipTol
      hsv(299)=drhoRecyTol
c     Store temperature to check temperature input
      hsv(300)=temperature
      endif
      endif
!============================================================
! End of cpfem
!------------------------------------------------------------
      end subroutine umatCpHama

      subroutine umatCpHamaGetMc(cm,ym,pr,bk,sm,
     &       typeUmat,dgamma0,tau0,thmSlpCstP,
     &       thmSlpCstQ,thmSlpCstT,DeltaGk0,
     &       typeOri,euler,
     &  hardType,rho0,g0,yc,km,alpha,kappa1,kappa2,rhoInfi)
      implicit none
      double precision cm(*)
      double precision ym,pr,bk,sm
      double precision typeUmat,dgamma0
      double precision tau0,thmSlpCstP,thmSlpCstQ
      double precision thmSlpCstT,DeltaGk0
      double precision typeOri,euler(3)
      double precision hardType,g0,rho0,yc,km,alpha
      double precision kappa1,kappa2,rhoInfi
c     cm(1 ~ 8)   Constitutive parameters
      ym=cm(1)
      pr=cm(2)
      bk=cm(3)
      sm=cm(4)
c     cm(9 ~ 16) basic crystal plasticity model
      typeUmat=cm(9)
      dgamma0=cm(10)
      tau0=cm(11)
      thmSlpCstP=cm(12)
      thmSlpCstQ=cm(13)
      thmSlpCstT=cm(14)
      DeltaGk0=cm(15)
c     cm(17 ~ 24) orientation information
      typeOri=cm(17)
      euler=cm(18:20)
c     cm(25 ~ 32) hardening and dislocation parameters
      rhoInfi=cm(24)
      hardType=cm(25)
      rho0=cm(26)
      g0=cm(27)
      yc=cm(28)
      km=cm(29)
      alpha=cm(30)
      kappa1=cm(31)
      kappa2=cm(32)
      end subroutine umatCpHamaGetMc

      subroutine umatCpHamaInitHsv(g0,rho0,r,s11,m11,numSys,nhsv,
     &      hsv,sig)
      implicit none
      include '../udf/model/define_cp.inc'
      integer nhsv,numSys
      integer i,l,k
      double precision g0,rho0,hsv(nhsv),r(3,3),sig(6)
      double precision s11(3,maxSys),m11(3,maxSys)

      integer OFF_F,OFF_CRSS,OFF_RHO,OFF_R
      integer OFF_S11,OFF_M11,OFF_GS,OFF_GN,OFF_EUL

      call umatCpHamaGetHsvOffsets(numSys,OFF_F,OFF_CRSS,
     1     OFF_RHO,OFF_R,OFF_S11,OFF_M11,OFF_GS,OFF_GN,OFF_EUL)

c     clear hsv
      do l=1,nhsv
            hsv(l)=0.d0
      enddo

c     deformation gradient
      hsv(OFF_F+0)=1.d0
      hsv(OFF_F+4)=1.d0
      hsv(OFF_F+8)=1.d0

c     CRSS
      do l=1,numSys
            hsv(OFF_CRSS+(l-1)) = g0
      enddo

c     dislocation density rho
      do l=1,numSys
            hsv(OFF_RHO+(l-1)) = rho0
      enddo

c     orientation matrix
      hsv(OFF_R+0)=r(1,1)
      hsv(OFF_R+1)=r(2,1)
      hsv(OFF_R+2)=r(3,1)
      hsv(OFF_R+3)=r(1,2)
      hsv(OFF_R+4)=r(2,2)
      hsv(OFF_R+5)=r(3,2)
      hsv(OFF_R+6)=r(1,3)
      hsv(OFF_R+7)=r(2,3)
      hsv(OFF_R+8)=r(3,3)

c     slip systems
      do l=1,numSys
            k=(l-1)*3
            hsv(OFF_S11+k  ) = s11(1,l)
            hsv(OFF_S11+k+1) = s11(2,l)
            hsv(OFF_S11+k+2) = s11(3,l)
            hsv(OFF_M11+k  ) = m11(1,l)
            hsv(OFF_M11+k+1) = m11(2,l)
            hsv(OFF_M11+k+2) = m11(3,l)
      enddo

      do i=1,6
            sig(i)=0.d0
      enddo
      end subroutine


C     Hsv List
      subroutine umatCpHamaGetHsv(hsv,numSys,g_crss,r,s11,m11,
     1       gamma_n1,gamma_slip,rho)
      implicit none
      include '../udf/model/define_cp.inc'
      integer numSys,l,k
      double precision hsv(*)
      double precision g_crss(maxSys),rho(maxSys)
      double precision r(3,3)
      double precision s11(3,maxSys),m11(3,maxSys)
      double precision gamma_n1,gamma_slip(maxSys)

      integer OFF_F,OFF_CRSS,OFF_RHO,OFF_R
      integer OFF_S11,OFF_M11,OFF_GS,OFF_GN,OFF_EUL

      call umatCpHamaGetHsvOffsets(numSys,OFF_F,OFF_CRSS,
     1     OFF_RHO,OFF_R,OFF_S11,OFF_M11,OFF_GS,OFF_GN,OFF_EUL)

c     CRSS
      do l=1,numSys
            g_crss(l)=hsv(OFF_CRSS+(l-1))
            rho(l)   =hsv(OFF_RHO +(l-1))
      enddo

c     orientation
      r(1,1)=hsv(OFF_R+0)
      r(2,1)=hsv(OFF_R+1)
      r(3,1)=hsv(OFF_R+2)
      r(1,2)=hsv(OFF_R+3)
      r(2,2)=hsv(OFF_R+4)
      r(3,2)=hsv(OFF_R+5)
      r(1,3)=hsv(OFF_R+6)
      r(2,3)=hsv(OFF_R+7)
      r(3,3)=hsv(OFF_R+8)

      do l=1,numSys
            k=(l-1)*3
            s11(1,l)=hsv(OFF_S11+k  )
            s11(2,l)=hsv(OFF_S11+k+1)
            s11(3,l)=hsv(OFF_S11+k+2)
            m11(1,l)=hsv(OFF_M11+k  )
            m11(2,l)=hsv(OFF_M11+k+1)
            m11(3,l)=hsv(OFF_M11+k+2)
      enddo

      gamma_n1=hsv(OFF_GN)
      do l=1,numSys
            gamma_slip(l)=hsv(OFF_GS+(l-1))
      enddo
      end subroutine

      
      subroutine umatCpHamaUpdateHsv(numSys,sig_n1,f_n1,g_crss,
     1       r_n1,s11_n1,m11_n1,gamma_slip,gamma_n1,
     2       rho,hsv,sig,euler_n1)
      implicit none
      integer l,k,numSys
      include '../udf/model/define_cp.inc'
      double precision hsv(*),rho(maxSys)
      double precision sig(6),sig_n1(6)
      double precision f_n1(3,3),g_crss(maxSys),r_n1(3,3)
      double precision s11_n1(3,maxSys),m11_n1(3,maxSys)
      double precision gamma_slip(maxSys),gamma_n1
      double precision euler_n1(3)

      integer OFF_F,OFF_CRSS,OFF_RHO,OFF_R
      integer OFF_S11,OFF_M11,OFF_GS,OFF_GN,OFF_EUL

      call umatCpHamaGetHsvOffsets(numSys,OFF_F,OFF_CRSS,
     1     OFF_RHO,OFF_R,OFF_S11,OFF_M11,OFF_GS,OFF_GN,OFF_EUL)

      sig = sig_n1

c     F
      hsv(OFF_F:OFF_F+8) = reshape(f_n1,(/9/))

c     CRSS + rho
      do l=1,numSys
            hsv(OFF_CRSS+(l-1)) = g_crss(l)
            hsv(OFF_RHO +(l-1)) = rho(l)
      enddo

c     orientation
      hsv(OFF_R:OFF_R+8) = reshape(r_n1,(/9/))

c     slip systems
      do l=1,numSys
            k=(l-1)*3
            hsv(OFF_S11+k  ) = s11_n1(1,l)
            hsv(OFF_S11+k+1) = s11_n1(2,l)
            hsv(OFF_S11+k+2) = s11_n1(3,l)
            hsv(OFF_M11+k  ) = m11_n1(1,l)
            hsv(OFF_M11+k+1) = m11_n1(2,l)
            hsv(OFF_M11+k+2) = m11_n1(3,l)
      enddo

      do l=1,numSys
            hsv(OFF_GS+(l-1)) = gamma_slip(l)
      enddo
      hsv(OFF_GN)=gamma_n1

      hsv(OFF_EUL+0)=euler_n1(1)
      hsv(OFF_EUL+1)=euler_n1(2)
      hsv(OFF_EUL+2)=euler_n1(3)
      end subroutine

