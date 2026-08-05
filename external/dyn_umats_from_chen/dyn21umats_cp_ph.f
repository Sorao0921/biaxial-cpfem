#include "define.inc"
#include "define2.inc"
      subroutine umatCpPhGetHsvOffsets(numSys,OFF_F,OFF_CRSS,
     1     OFF_R,OFF_S11,OFF_M11,OFF_GS,OFF_GN,OFF_EUL)
      
      implicit none
      integer numSys
      integer OFF_F, OFF_CRSS, OFF_R, OFF_S11, OFF_M11
      integer OFF_GS, OFF_GN, OFF_EUL

c    compute offsets (1-based indexing)
      OFF_F   = 1
      OFF_CRSS= OFF_F + 9
      OFF_R   = OFF_CRSS + numSys
      OFF_S11 = OFF_R + 9
      OFF_M11 = OFF_S11 + 3*numSys
      OFF_GS  = OFF_M11 + 3*numSys
      OFF_GN  = OFF_GS + numSys
      OFF_EUL = OFF_GN + 1
      
      end subroutine

      subroutine umatCpPh(cm,eps,sig,epsp,hsv,dt1,capa,etype,tt,
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
      integer ::nhsv=500
      double precision dt1
      character*5 etype
      logical failel,reject
      INTEGER idele
c     
      integer typeUmat
c     IO
      integer typeOri
c     Define the crystal
      integer,parameter:: typeCry=0
      integer numSys
    !   integer,parameter:: numSys=12
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
      double precision euler(3),euler_n1(3)
      double precision Dp(6),Wp(3)
c     Slip system constitutive model variables
      double precision tau(maxSys),dgamma(maxSys)
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
      integer OFF_F,OFF_CRSS,OFF_R,OFF_S11
      integer OFF_M11,OFF_GS,OFF_GN,OFF_EUL
      integer nhsv_min
!============================================================
! Obtain variables from materials constants
!------------------------------------------------------------
      call  umatCpPhGetMc(cm,ym,pr,bk,sm,
     1       typeUmat,dgamma0,mval,dgamma_lim,
     2       typeOri,euler,
     3       hardType,g0,gs,h0,hs,q)

      if (.not.failel) then
!============================================================
! Initial step: ncrycle = 0
!------------------------------------------------------------  
      if(ncycle==0) then
c     Init crystal orientation, slip system vectors
        call getSlipSysNum(typeCry,numSys)
        call initCrystal(typeOri,typeCry,euler,
     1           numSys,r,s11,m11)
c     Initialize the hsv list
      call umatCpPhInitHsv(g0,r,s11,m11,numSys,nhsv,
     1      hsv,sig)

      call umatCpPhGetHsvOffsets(numSys,OFF_F,OFF_CRSS,
     1     OFF_R,OFF_S11,OFF_M11,OFF_GS,OFF_GN,OFF_EUL)
      else
!============================================================
! Calculation begins: ncycle > 0
!------------------------------------------------------------ 
c     Obtain defromation gradient from hsv
      call  getSlipSysNum(typeCry,numSys)
c     Obtain defromation gradient from hsv
      call getDispGradfromHsv(hsv,nhsv,f,f_n1)
c     Obtain CRSS from hsv
      call umatCpPhGetHsv(hsv,numSys,g_crss,r,s11,m11,
     1       gamma_n1,gamma_slip)

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
      call calSlipRateVp(tau,g_crss,mval,dgamma0,
     1   dgamma_lim,numSys,dgamma)
      call updateCss(dgamma,numSys,dt1,
     1     dgamma_tol,gamma_slip,gamma_n1)
c     Project the slip deformation into macro deformation and spin
c     as plastic corrector
      call calStrainRateBySlip(dgamma,eschmid,numSys,Dp)
      call calSpinRateBySlip(dgamma,wschmid,numSys,Wp)

      do l=1,numSys
            hsv(200+l-1)=dgamma(l)
      enddo

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
! Hardening model
!------------------------------------------------------------
      call updateCrssFcc(g0,gs,h0,hs,q,gamma_n1,dgamma,
     1           dt1,g_crss)
!============================================================
! Give constitutive and non-constitutive variables to hsv
!------------------------------------------------------------
      call umatCpPhUpdateHsv(numSys,sig_n1,f_n1,g_crss,
     1       r_n1,s11_n1,m11_n1,gamma_slip,gamma_n1,
     2       hsv,sig,euler_n1)
      endif
      endif
!============================================================
! End of cpfem
!------------------------------------------------------------
      end subroutine umatCpPh

      subroutine umatCpPhGetMc(cm,ym,pr,bk,sm,
     1       typeUmat,dgamma0,mval,dgamma_lim,
     2       typeOri,euler,
     3       hardType,g0,gs,h0,hs,q)
      implicit none
      double precision cm(*)
      double precision ym,pr,bk,sm
      double precision typeUmat,dgamma0,mval,dgamma_lim
      double precision typeOri,euler(3)
      double precision hardType,g0,gs,h0,hs,q
c     cm(1 ~ 8)   Constitutive parameters
      ym=cm(1)
      pr=cm(2)
      bk=cm(3)
      sm=cm(4)
c     cm(9 ~ 16) basic crystal plasticity model
      typeUmat=cm(9)
      dgamma0=cm(10)
      mval=cm(11)
      dgamma_lim=cm(12)
c     cm(17 ~ 24) orientation information
      typeOri=cm(17)
      euler=cm(18:20)
c     cm(25 ~ 32) hardening 
      hardType=cm(25)
      g0=cm(26)
      gs=cm(27)
      h0=cm(28)
      hs=cm(29)
      q=cm(30)
      end subroutine umatCpPhGetMc

      subroutine umatCpPhInitHsv(g0,r,s11,m11,numSys,nhsv,hsv,sig)
      implicit none
      integer nhsv,numSys
      integer i,l,k
      double precision g0,hsv(nhsv),r(3,3),sig(6)
      double precision s11(3,numSys),m11(3,numSys)

      integer OFF_F, OFF_CRSS, OFF_R, OFF_S11, OFF_M11
      integer OFF_GS, OFF_GN, OFF_EUL

      call umatCpPhGetHsvOffsets(numSys,OFF_F,OFF_CRSS,
     1     OFF_R,OFF_S11,OFF_M11,OFF_GS,OFF_GN,OFF_EUL)
c     Initialize the hsv list
            do l=1,nhsv
                  hsv(l)=0.
            enddo
c     Diagonal part of deformation gradient
            hsv(OFF_F+0)=1.
            hsv(OFF_F+4)=1.
            hsv(OFF_F+8)=1.
c     CRSS
            do l=1,numSys
                  hsv(OFF_CRSS+(l-1))=g0
            enddo
c     Transformation matrix for orientation
            hsv(OFF_R+0)=r(1,1)
            hsv(OFF_R+1)=r(2,1)
            hsv(OFF_R+2)=r(3,1)
            hsv(OFF_R+3)=r(1,2)
            hsv(OFF_R+4)=r(2,2)
            hsv(OFF_R+5)=r(3,2)
            hsv(OFF_R+6)=r(1,3)
            hsv(OFF_R+7)=r(2,3)
            hsv(OFF_R+8)=r(3,3)
c     Slip system vectors
            do l=1,numSys
                  k=(l-1)*3
                  hsv(OFF_S11 + k    ) = s11(1,l)
                  hsv(OFF_S11 + k + 1) = s11(2,l)
                  hsv(OFF_S11 + k + 2) = s11(3,l)
                  hsv(OFF_M11 + k    ) = m11(1,l)
                  hsv(OFF_M11 + k + 1) = m11(2,l)
                  hsv(OFF_M11 + k + 2) = m11(3,l)
            enddo
c     Cauchy stress tensor
            do i=1,6
                  sig(i)=0.
            enddo
      end subroutine umatCpPhInitHsv

C     Hsv List
      subroutine umatCpPhGetHsv(hsv,numSys,g_crss,r,s11,m11,
     1       gamma_n1,gamma_slip)
      implicit none
      integer numSys
      integer l,k
      double precision hsv(*)
      double precision g_crss(numSys),r(3,3)
      double precision s11(3,numSys),m11(3,numSys)
      double precision gamma_n1
      double precision gamma_slip(numSys)
      integer OFF_F, OFF_CRSS, OFF_R, OFF_S11, OFF_M11
      integer OFF_GS, OFF_GN, OFF_EUL
c     Compute offsets
      call umatCpPhGetHsvOffsets(numSys,OFF_F,OFF_CRSS,
     1     OFF_R,OFF_S11,OFF_M11,OFF_GS,OFF_GN,OFF_EUL)
c     Obtain CRSS from hsv
      do l=1,numSys
            g_crss(l)=hsv(OFF_CRSS + (l-1))
      enddo
c     Obtain slip volume from hsv
c     Obtain orientation info
      r(1,1)=hsv(OFF_R + 0)
      r(2,1)=hsv(OFF_R + 1)
      r(3,1)=hsv(OFF_R + 2)
      r(1,2)=hsv(OFF_R + 3)
      r(2,2)=hsv(OFF_R + 4)
      r(3,2)=hsv(OFF_R + 5)
      r(1,3)=hsv(OFF_R + 6)
      r(2,3)=hsv(OFF_R + 7)
      r(3,3)=hsv(OFF_R + 8)
      do l=1,numSys
            k=(l-1)*3
            s11(1,l)=hsv(OFF_S11 + k    )
            s11(2,l)=hsv(OFF_S11 + k + 1)
            s11(3,l)=hsv(OFF_S11 + k + 2)
            m11(1,l)=hsv(OFF_M11 + k    )
            m11(2,l)=hsv(OFF_M11 + k + 1)
            m11(3,l)=hsv(OFF_M11 + k + 2)
      enddo
c     Obtain slip volume from hsv
      gamma_n1=hsv(OFF_GN)
      do l=1,numSys
            gamma_slip(l)=hsv(OFF_GS + (l-1))
      enddo
      end subroutine umatCpPhGetHsv
      
      subroutine umatCpPhUpdateHsv(numSys,sig_n1,f_n1,g_crss,
     1       r_n1,s11_n1,m11_n1,gamma_slip,gamma_n1,
     2       hsv,sig,euler_n1)
      implicit none
      integer l,k
      integer numSys
      double precision hsv(*)
      double precision sig(6),sig_n1(6)
      double precision f_n1(3,3),g_crss(numSys),r_n1(3,3)
      double precision s11_n1(3,numSys),m11_n1(3,numSys)
      double precision gamma_slip(numSys),gamma_n1
      double precision euler_n1(3)
      integer OFF_F, OFF_CRSS, OFF_R, OFF_S11, OFF_M11
      integer OFF_GS, OFF_GN, OFF_EUL
c     Compute offsets
      call umatCpPhGetHsvOffsets(numSys,OFF_F,OFF_CRSS,
     1     OFF_R,OFF_S11,OFF_M11,OFF_GS,OFF_GN,OFF_EUL)
      sig(1)=sig_n1(1)
      sig(2)=sig_n1(2)
      sig(3)=sig_n1(3)
      sig(4)=sig_n1(4)
      sig(5)=sig_n1(5)
      sig(6)=sig_n1(6)
c    update f_n1 into hsv
      hsv(OFF_F + 0)=f_n1(1,1)
      hsv(OFF_F + 1)=f_n1(2,1)
      hsv(OFF_F + 2)=f_n1(3,1)
      hsv(OFF_F + 3)=f_n1(1,2)
      hsv(OFF_F + 4)=f_n1(2,2)
      hsv(OFF_F + 5)=f_n1(3,2)
      hsv(OFF_F + 6)=f_n1(1,3)
      hsv(OFF_F + 7)=f_n1(2,3)
      hsv(OFF_F + 8)=f_n1(3,3)

c    update CRSS
      do l=1,numSys
            hsv(OFF_CRSS + (l-1)) = g_crss(l)
      enddo

c    update orientation r_n1
      hsv(OFF_R + 0)=r_n1(1,1)
      hsv(OFF_R + 1)=r_n1(2,1)
      hsv(OFF_R + 2)=r_n1(3,1)
      hsv(OFF_R + 3)=r_n1(1,2)
      hsv(OFF_R + 4)=r_n1(2,2)
      hsv(OFF_R + 5)=r_n1(3,2)
      hsv(OFF_R + 6)=r_n1(1,3)
      hsv(OFF_R + 7)=r_n1(2,3)
      hsv(OFF_R + 8)=r_n1(3,3)

c    update slip systems
      do l=1,numSys
            k=(l-1)*3
            hsv(OFF_S11 + k    ) = s11_n1(1,l)
            hsv(OFF_S11 + k + 1) = s11_n1(2,l)
            hsv(OFF_S11 + k + 2) = s11_n1(3,l)
            hsv(OFF_M11 + k    ) = m11_n1(1,l)
            hsv(OFF_M11 + k + 1) = m11_n1(2,l)
            hsv(OFF_M11 + k + 2) = m11_n1(3,l)
      enddo

c    update gamma_slip and gamma_n1
      do l=1,numSys
            hsv(OFF_GS + (l-1)) = gamma_slip(l)
      enddo
      hsv(OFF_GN) = gamma_n1

      hsv(OFF_EUL + 0)=euler_n1(1)
      hsv(OFF_EUL + 1)=euler_n1(2)
      hsv(OFF_EUL + 2)=euler_n1(3)
      end subroutine umatCpPhUpdateHsv
