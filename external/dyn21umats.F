#include "define.inc"
#include "define2.inc"
      subroutine umat41 (cm,eps,sig,epsp,hsv,dt1,capa,etype,tt,
     1 temper,failel,crv,nnpcrv,cma,qmat,elsiz,idele,reject)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     isotropic elastic material (sample user subroutine)
c
c     Variables
c
c     cm(1)=first material constant, here young's modulus
c     cm(2)=second material constant, here poisson's ratio
c        .
c        .
c        .
c     cm(n)=nth material constant
c
c     eps(1)=local x  strain increment
c     eps(2)=local y  strain increment
c     eps(3)=local z  strain increment
c     eps(4)=local xy strain increment
c     eps(5)=local yz strain increment
c     eps(6)=local zx strain increment
c
c     Note that eps is in strain Voigt notation, meaning that
c     e.g. eps(4) is the sum of tensorial xy and yx strain increments.
c
c     sig(1)=local x  stress
c     sig(2)=local y  stress
c     sig(3)=local z  stress
c     sig(4)=local xy stress
c     sig(5)=local yz stress
c     sig(6)=local zx stress
c
c     hsv(1)=1st history variable
c     hsv(2)=2nd history variable
c        .
c        .
c        .
c        .
c     hsv(n)=nth history variable
c
c     dt1=current time step size
c     capa=reduction factor for transverse shear
c     etype:
c        eq."solid" for solid elements
c        eq."sph  " for smoothed particle hydrodynamics
c        eq."sld2d" for shell forms 13 (2D solids - plane strain)
c        eq."sldax" for shell forms 14, and 15 (2D solids - axisymmetric)
c        eq."shl_t" for shell forms 25, 26, and 27 (shells with thickness stretch)
c        eq."shell" for all other shell elements plus thick shell forms 1 and 2
c        eq."tshel" for thick shell forms 3 and 5
c        eq."hbeam" for beam element forms 1, 11, 14
c        eq."tbeam" for beam element form 3 (truss)
c        eq."dbeam" for beam element form 6 (discrete)
c        eq."beam " for all other beam elements (currently not used)
c
c     tt=current problem time.
c
c     temper=current temperature
c
c     failel=flag for failure, set to .true. to fail an integration point,
c            if .true. on input the integration point has failed earlier
c
c     crv=array representation of curves in keyword deck
c
c     nnpcrv=# of discretization points per crv()
c
c     cma=additional memory for material data defined by LMCA at
c       6th field of 2nd crad of *DATA_USER_DEFINED
c
c     elsiz=characteristic element size
c
c     idele=element id
c
c     reject (implicit only) = set to .true. if this implicit iterate is
c                              to be rejected for some reason
c
c     All transformations into the element local system are
c     performed prior to entering this subroutine.  Transformations
c     back to the global system are performed after exiting this
c     routine.
c
c     All history variables are initialized to zero in the input
c     phase. Initialization of history variables to nonzero values
c     may be done during the first call to this subroutine for each
c     element.
c
c     Energy calculations for the dyna3d energy balance are done
c     outside this subroutine.
c
      include 'nlqparm'
      include 'bk06.inc'
      include 'iounits.inc'
      dimension cm(*),eps(*),sig(*),hsv(*),crv(lq1,2,*),cma(*),qmat(3,3)
      integer nnpcrv(*)
      logical failel,reject
      character*5 etype
      INTEGER8 idele
      integer :: nflag=0
c
      if (ncycle.eq.1) then
        if (cm(16).ne.1234567) then
          call usermsg('mat41')
        endif
      endif
c
c     compute shear modulus, g
c
      g2 =abs(cm(1))/(1.+cm(2))
      g  =.5*g2
      if (nflag==0) then
        open(11,file='sig.dat',status='replace')
        write(11,*) "#sig"
        close(11)
        nflag=1
      endif
c
      if (etype.eq.'solid'.or.etype.eq.'shl_t'.or.
     1     etype.eq.'sld2d'.or.etype.eq.'tshel'.or.
     2     etype.eq.'sph  '.or.etype.eq.'sldax') then
        if (cm(16).eq.1234567) then
          call mitfail3d(cm,eps,sig,epsp,hsv,dt1,capa,failel,tt,crv)
        else
          if (.not.failel) then
            open(11,file='sig.dat',position='APPEND')
            write(11,*) 'ncycle idele'
            write(11,*) ncycle, idele
            write(11,*) '# sig first'
            do i=1,6
                  write(11,*) sig(i)
            enddo
            close(11)
          davg=(-eps(1)-eps(2)-eps(3))/3.
          p=-davg*abs(cm(1))/(1.-2.*cm(2))
          sig(1)=sig(1)+p+g2*(eps(1)+davg)
          sig(2)=sig(2)+p+g2*(eps(2)+davg)
          sig(3)=sig(3)+p+g2*(eps(3)+davg)
          sig(4)=sig(4)+g*eps(4)
          sig(5)=sig(5)+g*eps(5)
          sig(6)=sig(6)+g*eps(6)
          open(11,file='sig.dat',position='APPEND')
          write(11,*) '# sig end'
          do i=1,6
                write(11,*) sig(i)
          enddo
          close(11)
          if (cm(1).lt.0.) then
            if (sig(1).gt.cm(5)) failel=.true.
          endif
          endif
        end if
c
      else if (etype.eq.'shell') then
        if (cm(16).eq.1234567) then
          call mitfailure(cm,eps,sig,epsp,hsv,dt1,capa,failel,tt,crv)
        else
          if (.not.failel) then
          gc    =capa*g
          q1    =abs(cm(1))*cm(2)/((1.0+cm(2))*(1.0-2.0*cm(2)))
          q3    =1./(q1+g2)
          eps(3)=-q1*(eps(1)+eps(2))*q3
          davg  =(-eps(1)-eps(2)-eps(3))/3.
          p     =-davg*abs(cm(1))/(1.-2.*cm(2))
          sig(1)=sig(1)+p+g2*(eps(1)+davg)
          sig(2)=sig(2)+p+g2*(eps(2)+davg)
          sig(3)=0.0
          sig(4)=sig(4)+g *eps(4)
          sig(5)=sig(5)+gc*eps(5)
          sig(6)=sig(6)+gc*eps(6)
          if (cm(1).lt.0.) then
            if (sig(1).gt.cm(5)) failel=.true.
          endif
          endif
        end if
      elseif (etype.eq.'hbeam') then
          q1    =cm(1)*cm(2)/((1.0+cm(2))*(1.0-2.0*cm(2)))
          q3    =q1+2.0*g
          gc    =capa*g
          deti  =1./(q3*q3-q1*q1)
          c22i  = q3*deti
          c23i  =-q1*deti
          fac   =(c22i+c23i)*q1
          eps(2)=-eps(1)*fac-sig(2)*c22i-sig(3)*c23i
          eps(3)=-eps(1)*fac-sig(2)*c23i-sig(3)*c22i
          davg  =(-eps(1)-eps(2)-eps(3))/3.
          p     =-davg*cm(1)/(1.-2.*cm(2))
          sig(1)=sig(1)+p+g2*(eps(1)+davg)
          sig(2)=0.0
          sig(3)=0.0
          sig(4)=sig(4)+gc*eps(4)
          sig(5)=0.0
          sig(6)=sig(6)+gc*eps(6)
c
      elseif (etype.eq.'tbeam') then
        q1    =cm(1)*cm(2)/((1.0+cm(2))*(1.0-2.0*cm(2)))
        q3    =q1+2.0*g
        deti  =1./(q3*q3-q1*q1)
        c22i  = q3*deti
        c23i  =-q1*deti
        fac   =(c22i+c23i)*q1
        eps(2)=-eps(1)*fac
        eps(3)=-eps(1)*fac
        davg  =(-eps(1)-eps(2)-eps(3))/3.
        p     =-davg*cm(1)/(1.-2.*cm(2))
        sig(1)=sig(1)+p+g2*(eps(1)+davg)
        sig(2)=0.0
        sig(3)=0.0
c
      else
c       write(iotty,10) etype
c       write(iohsp,10) etype
c       write(iomsg,10) etype
c       call adios(TC_ERROR)
        cerdat(1)=etype
        call lsmsg(3,MSG_SOL+1150,ioall,ierdat,rerdat,cerdat,0)
      endif
      open(12,file='other_data.dat',position='APPEND')
      write(12,*) '# idele'
      write(12,*) idele
      close(12)
c
c10   format(/
c    1 ' *** Error element type ',a,' can not be',
c    2 '           run with the current material model.')
      return
      end
c$$$      subroutine umat42 (cm,eps,sig,epsp,hsv,dt1,capa,etype,tt,
c$$$     1 temper,failel,crv,nnpcrv,cma,qmat,elsiz,idele,reject)
c$$$c
c$$$c******************************************************************
c$$$c|  Livermore Software Technology Corporation  (LSTC)             |
c$$$c|  ------------------------------------------------------------  |
c$$$c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c$$$c|  All rights reserved                                           |
c$$$c******************************************************************
c$$$c
c$$$      include 'nlqparm'
c$$$      include 'bk06.inc'
c$$$      include 'iounits.inc'
c$$$      dimension cm(*),eps(*),sig(*),hsv(*),crv(lq1,2,*),cma(*),qmat(3,3)
c$$$      logical failel,reject
c$$$      integer nnpcrv(*)
c$$$      character*5 etype
c$$$      INTEGER8 idele
c$$$c
c$$$      if (ncycle.eq.1) then
c$$$        call usermsg('mat42')
c$$$      endif
c$$$c
c$$$      return
c$$$      end
      subroutine umat43(cm,eps,sig,epsp,hsv,dt1,capa,etype,tt,
     1 temper,failel,crv,nnpcrv,cma,qmat,elsiz,idele,reject)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     暗黙の型宣言の無効化(2020.02.11_1)
      implicit none
      include 'nlqparm'
      include 'bk06.inc'
      include 'iounits.inc'
c      dimension cm(*),eps(*),sig(*),hsv(*),crv(lq1,2,*),cma(*),qmat(3,3)
c     引数の型宣言の変更(2020.02.11_1)
      double precision cm(*),eps(*),sig(*),hsv(*)
      double precision crv(lq1,2,*),cma(*),qmat(3,3),dt1
      integer nnpcrv(*)
      character*5 etype
      logical failel,reject
      INTEGER8 idele
      integer i,j,k,l,ii,jj
      integer :: nhsv=265 !履歴変数の総数に応じて変更する必要あり
      double precision f_n1(3,3) !displacement gradient at t=n+1
      double precision df_n1(3,3) !velocity gradient at t=n+1
      double precision f_n1_inv(3,3) !inverse of f_n1
      double precision L_n1(3,3) !velocity gradient tensor
      double precision D(3,3) !strain velocity gradient tensor
      double precision Dv(6) !Voigt表記のひずみ速度勾配テンソル
      double precision W(3,3) !spin velocity gradient tensor
      double precision Wv(3) !Voigt表記のスピン速度勾配テンソル
      double precision Pa(3,3,12), Pac(3,3,12) !schmid tensor
      double precision Wa(3,3,12), Wac(3,3,12) !spin tensor
      double precision eschmid(6,12)
      double precision wschmid(3,12)
      double precision s(3,12),m(3,12),s1(3,12),m1(3,12) !slip system
      double precision s11(3,12),m11(3,12)
      double precision r1(3,3) !回転マトリクス（材料座標系⇒結晶座標系）
      double precision r(3,3) !回転マトリクス（結晶座標系⇒材料座標系）
      double precision RL(6,6) !Voigt表記向けの回転マトリクス
      double precision phi(150000), theta(150000), psi(150000) !euler angle
      double precision tau(12) !shear stress
      double precision, parameter :: pi=acos(-1.0d0)      !円周率
      double precision dgamma(12)
      double precision Dp(6), Wp(3) !塑性変形、スピン速度勾配テンソル
      double precision L_ela(6,6) !材料座標系での弾性構成テンソル
      double precision L_ela_cry(6,6) !結晶座標系での弾性構成テンソル
      double precision dsig_0(6) !粘塑性型の応力速度
      double precision sig_jau(6) !Jaumann応力速度
      double precision sig_r(6) !Jaumann応力速度を計算するときに引くところ（回転部分）
      double precision sig_n1(6) !時刻n+1での全体座標系での応力
      double precision idm(3,3) !単位行列
      double precision fp_n(3,3) !時刻nでの変位勾配テンソルの塑性部分
      double precision fp_n_inv(3,3) !fp_nの逆行列
      double precision Wev(3), We(3,3) !時刻n+1でのスピン速度勾配テンソルの弾性部分
      double precision We1 !回転マトリクス更新時に使うw*
      double precision exp_we(3,3) !回転マトリクス更新時の係数expW*dt
      double precision r_n1(3,3) !時刻n+1での回転マトリクス
      double precision RL_n1(6,6) !Voigt表記向けのr_n1
      double precision L_ela_n1(6,6) !時刻n+1での材料座標系での弾性構成テンソル
      double precision fe_n1(3,3) !時刻n+1での変位勾配テンソルの弾性部分
      double precision fe_n1_inv(3,3) !fe_n1の逆行列
      double precision fq1(3,3) !すべり面法線ベクトル更新時の係数
      double precision fq2(3,3) !すべり方向ベクトル更新時の係数
      double precision s1_n1(3,12),m1_n1(3,12) !時刻n+1でのすべり系
      double precision Pac_n1(3,3,12) !時刻n+1でのシュミットテンソル
      double precision Wac_n1(3,3,12) !時刻n+1でのスピンシュミットテンソル
      double precision gamma_n1 !時刻n+1でのせん断ひずみの総和
      double precision gamma_slip(12) !各すべり系でのせん断ひずみの総和
      double precision g_n1(12) !時刻n+1での降伏せん断応力
      double precision h_n1 !時刻n+1での硬化係数h
      double precision Ra(6,12) !sig_0を計算するときの係数
      double precision term1, term2
      double precision dgamma_0,g0,mval,h0,gs,hs,q,nval
      double precision h_n1_zhang(12) !Zhangの硬化マトリクス
      double precision r_ini(3,3) !時刻nでの回転マトリクスの増分
      double precision r_ini_n1(3,3)  !時刻n+1での回転マトリクスの増分
      double precision r0(3,3) !初期の回転マトリクス
      double precision phi1,lphi,phi2
      double precision exp_we1(3,3)
      double precision exp_we2(3,3)
      double precision exp_we2_inv(3,3)
      double precision r0_t(3,3), r_n1_t(3,3),r_t(3,3)
      double precision We_c(3,3)
      double precision coeff_we(3,3) !s,mの更新用係数(2020.0330_3)
      double precision Dev(3) !Dの弾性部分
      double precision euler(1200,3)

c     Solid要素では使用しない変数(2020.02.11_1)--------------------------------
      double precision g,g2,gc,q1,q3,davg,p,deti,c22i,c23i,fac
      double precision temper,elsiz,epsp,capa,tt

c     材料定数の定義
c     cm(1): ヤング率
c     cm(2): ポアソン比
c     cm(3): 体積弾性係数
c     cm(4): せん断係数
      dgamma_0=cm(5) !参照せん断ひずみ速度
      g0=cm(6)       !初期せん断降伏応力
      mval=cm(7)     !ひずみ速度感度係数
      h0=cm(8)       !初期硬化係数
      gs=cm(9)       !飽和せん断降伏応力
      hs=cm(10)      !飽和硬化係数
      q=cm(11)       !潜在硬化係数
c     cm(12): dgammaの制限
c     cm(13)-cm(14): 未使用
c     cm(15): Part ID

c     すべり系の定義
           data s/-1.00,1.00,1.00, -1.00,1.00,1.00, -1.00,1.00,1.00,
     1         1.00,1.00,1.00, 1.00,1.00,1.00, 1.00,1.00,1.00,
     2        -1.00,-1.00,1.00, -1.00,-1.00,1.00, -1.00,-1.00,1.00,
     3        1.00,-1.00,1.00, 1.00,-1.00,1.00, 1.00,-1.00,1.00/
       data m/0.00,-1.00,1.00, 1.00,0.00,1.00, 1.00,1.00,0.00,
     1        0.00,-1.00,1.00, -1.00,0.00,1.00, -1.00,1.00,0.00,
     2        0.00,1.00,1.00, 1.00,0.00,1.00, -1.00,1.00,0.00,
     3        0.00,1.00,1.00, -1.00,0.00,1.00, 1.00,1.00,0.00/
c
      do l=1,12
            do i=1,3
                  s1(i,l)=s(i,l)/sqrt(3.)
                  m1(i,l)=m(i,l)/sqrt(2.)
            end do
      enddo
      if (ncycle.eq.1) then
        call usermsg('mat43')
      endif
c
      g2 =abs(cm(1))/(1.+cm(2))
      g  =.5*g2

      if (etype.eq.'solid'.or.etype.eq.'shl_t') then
       if (cm(16).eq.1234567) then
      call mitfail3d(cm,eps,sig,epsp,hsv,dt1,capa,failel,tt,crv)
      else
      if (.not.failel) then
            if(ncycle==0) then
                  do i=1,nhsv
                        hsv(i)=0.
                  enddo
                  hsv(1)=1.
                  hsv(5)=1.
                  hsv(9)=1.
                  do l=1,12
                    hsv(10+l)=g0
                  enddo
                  do i=1,6
                        sig(i)=0.
                  enddo
            else

c            start forward euler algorithm
             !step 1
             f_n1(1,1)=hsv(nhsv+1)
             f_n1(2,1)=hsv(nhsv+2)
             f_n1(3,1)=hsv(nhsv+3)
             f_n1(1,2)=hsv(nhsv+4)
             f_n1(2,2)=hsv(nhsv+5)
             f_n1(3,2)=hsv(nhsv+6)
             f_n1(1,3)=hsv(nhsv+7)
             f_n1(2,3)=hsv(nhsv+8)
             f_n1(3,3)=hsv(nhsv+9) !nhsvは使用した履歴変数の総数

      if(ncycle==1) then
       open(18,file='Euler_angle.csv',status='old')
       do j=1,1200
            read(18,*) euler(j,1),euler(j,2),euler(j,3) 
       enddo
!       read(18,*) euler
       close(18)
       phi(idele)=euler(cm(15),1)
       theta(idele)=euler(cm(15),2)
       psi(idele)=euler(cm(15),3)
      
        phi(idele)=(phi(idele)*pi)/180.
        theta(idele)=(theta(idele)*pi)/180.
        psi(idele)=(psi(idele)*pi)/180.

c      Bungeの定義（結晶座標系⇒材料座標系）
        r(1,1)=cos(phi(idele))*cos(psi(idele))
     1    -sin(phi(idele))*cos(theta(idele))*sin(psi(idele))
        r(1,2)=-cos(phi(idele))*sin(psi(idele))
     1   -sin(phi(idele))*cos(theta(idele))*cos(psi(idele))
        r(1,3)=sin(phi(idele))*sin(theta(idele))
        r(2,1)=sin(phi(idele))*cos(psi(idele))
     1   +cos(phi(idele))*cos(theta(idele))*sin(psi(idele))
        r(2,2)=-sin(phi(idele))*sin(psi(idele))
     1   +cos(phi(idele))*cos(theta(idele))*cos(psi(idele))
        r(2,3)=-cos(phi(idele))*sin(theta(idele))
        r(3,1)=sin(theta(idele))*sin(psi(idele))
        r(3,2)=sin(theta(idele))*cos(psi(idele))
        r(3,3)=cos(theta(idele))

      do l=1,12
            do i=1,3
                  s11(i,l)=0.
                  m11(i,l)=0.
                  do j=1,3
                        s11(i,l)=s11(i,l)+r(i,j)*s1(j,l)
                        m11(i,l)=m11(i,l)+r(i,j)*m1(j,l)
                  enddo
            enddo
      enddo
      do l=1,12
         do i=1,3
           do j=1,3
             Pa(i,j,l)=(s11(i,l)*m11(j,l)+s11(j,l)*m11(i,l))/2.
             Wa(i,j,l)=(s11(i,l)*m11(j,l)-s11(j,l)*m11(i,l))/2.
           end do
         end do
       end do

      ! シュミットテンソル（材料座標系）
        do l=1,12
          eschmid(1,l)=Pa(1,1,l)
          eschmid(2,l)=Pa(2,2,l)
          eschmid(3,l)=Pa(3,3,l)
          eschmid(4,l)=Pa(1,2,l)*2
          eschmid(5,l)=Pa(2,3,l)*2
          eschmid(6,l)=Pa(3,1,l)*2
          wschmid(1,l)=Wa(1,2,l)
          wschmid(2,l)=Wa(2,3,l)
          wschmid(3,l)=Wa(3,1,l)
        end do
      else
            r(1,1)=hsv(23)
            r(2,1)=hsv(24)
            r(3,1)=hsv(25)
            r(1,2)=hsv(26)
            r(2,2)=hsv(27)
            r(3,2)=hsv(28)
            r(1,3)=hsv(29)
            r(2,3)=hsv(30)
            r(3,3)=hsv(31)
            do l=1,12
                  k=(l-1)*6
                  eschmid(1,l)=hsv(53+k)
                  eschmid(2,l)=hsv(54+k)
                  eschmid(3,l)=hsv(55+k)
                  eschmid(4,l)=hsv(56+k)
                  eschmid(5,l)=hsv(57+k)
                  eschmid(6,l)=hsv(58+k)
            enddo
            do l=1,12
                  k=(l-1)*3
                  wschmid(1,l)=hsv(125+k)
                  wschmid(2,l)=hsv(126+k)
                  wschmid(3,l)=hsv(127+k)
            end do      
            do l=1,12
                  k=(l-1)*3
                  s11(1,l)=hsv(194+k)
                  s11(2,l)=hsv(195+k)
                  s11(3,l)=hsv(196+k)
                  m11(1,l)=hsv(230+k)
                  m11(2,l)=hsv(231+k)
                  m11(3,l)=hsv(232+k)
            enddo
c---------------------------------------------------
      endif

             !STEP 2
             df_n1(1,1)=(f_n1(1,1)-hsv(1))/dt1
             df_n1(2,1)=(f_n1(2,1)-hsv(2))/dt1
             df_n1(3,1)=(f_n1(3,1)-hsv(3))/dt1
             df_n1(1,2)=(f_n1(1,2)-hsv(4))/dt1
             df_n1(2,2)=(f_n1(2,2)-hsv(5))/dt1
             df_n1(3,2)=(f_n1(3,2)-hsv(6))/dt1
             df_n1(1,3)=(f_n1(1,3)-hsv(7))/dt1
             df_n1(2,3)=(f_n1(2,3)-hsv(8))/dt1
             df_n1(3,3)=(f_n1(3,3)-hsv(9))/dt1
             hsv(1)=f_n1(1,1)
             hsv(2)=f_n1(2,1)
             hsv(3)=f_n1(3,1)
             hsv(4)=f_n1(1,2)
             hsv(5)=f_n1(2,2)
             hsv(6)=f_n1(3,2)
             hsv(7)=f_n1(1,3)
             hsv(8)=f_n1(2,3)
             hsv(9)=f_n1(3,3)
             call inverse(f_n1,f_n1_inv,3)

             do i=1,3
                  do j=1,3
                        L_n1(i,j)=0.
                        do k=1,3
                          L_n1(i,j)=L_n1(i,j)+df_n1(i,k)*f_n1_inv(k,j)
                        enddo
                  enddo
            enddo

            do i=1,3
                  do j=1,3
                        D(i,j)=0.
                        W(i,j)=0.
                  enddo
            enddo
            do i=1,3
                  do j=1,3
                        D(i,j)=(L_n1(i,j)+L_n1(j,i))/2.
                        W(i,j)=(L_n1(i,j)-L_n1(j,i))/2.
                  enddo
            enddo

            Dv(1)=D(1,1)
            Dv(2)=D(2,2)
            Dv(3)=D(3,3)
            Dv(4)=D(1,2)*2
            Dv(5)=D(2,3)*2
            Dv(6)=D(3,1)*2
            Wv(1)=W(1,2)
            Wv(2)=W(2,3)
            Wv(3)=W(3,1)

            !STEP 3
            do l=1,12
                  tau(l)=0.
                  do i=1,6
                    tau(l)=tau(l)+eschmid(i,l)*sig(i)
                  enddo
            enddo
            do l=1,12
              dgamma(l)=dgamma_0*(tau(l)/hsv(10+l))
     1         *abs(tau(l)/hsv(10+l))**((1/mval)-1)
            enddo

c           dgammaの上限の値を設定する
            do l=1,12
                  if(dgamma(l) .gt. cm(12)) then
                        dgamma(l)=cm(12)
                  elseif(dgamma(l) .lt. -cm(12)) then
                        dgamma(l)=-cm(12)
                  endif
            enddo

            !STEP4
            do i=1,6
                  Dp(i)=0.
                  do l=1,12
                        Dp(i)=Dp(i)+eschmid(i,l)*dgamma(l)
                  enddo
            enddo
            do i=1,3
                  Wp(i)=0.
                  do l=1,12
                        Wp(i)=Wp(i)+wschmid(i,l)*dgamma(l)
                  enddo
            enddo

            do j=1,6
                  do i=1,6
                        L_ela_cry(i,j)=0.
                  enddo
            enddo
            do j=1,3
                  do i=1,3
                    L_ela_cry(i,j)=cm(2)*cm(1)/((1+cm(2))*(1-2*cm(2)))
                  enddo
            enddo
            do i=1,3
                  L_ela_cry(i,i)=(1-cm(2))*cm(1)/((1+cm(2))*(1-2*cm(2)))
            enddo
            do i=4,6
                  L_ela_cry(i,i)=cm(1)/(2*(1+cm(2)))
            enddo

      if(ncycle==1) then
            do i=1,3
                  do j=1,3
                        RL(i,j)=r(i,j)**2
                  enddo
                        RL(i,4)=2.*r(i,2)*r(i,3)
                        RL(i,5)=2.*r(i,3)*r(i,1)
                        RL(i,6)=2.*r(i,1)*r(i,2)
            enddo
            do j=1,3
                  RL(4,j)=r(2,j)*r(3,j)
                  RL(5,j)=r(3,j)*r(1,j)
                  RL(6,j)=r(1,j)*r(2,j)
            enddo
            RL(4,4)=r(2,2)*r(3,3)+r(3,2)*r(2,3)
            RL(4,5)=r(2,3)*r(3,1)+r(3,3)*r(2,1)
            RL(4,6)=r(2,2)*r(3,1)+r(3,2)*r(2,1)
            RL(5,4)=r(3,2)*r(1,3)+r(1,3)*r(3,3)
            RL(5,5)=r(3,3)*r(1,1)+r(1,3)*r(3,1)
            RL(5,6)=r(3,2)*r(1,1)+r(1,2)*r(3,1)
            RL(6,4)=r(1,2)*r(2,3)+r(2,2)*r(1,3)
            RL(6,5)=r(1,3)*r(2,1)+r(2,3)*r(1,1)
            RL(6,6)=r(1,2)*r(2,1)+r(2,2)*r(1,1)

            do j=1,6
                  do i=1,6
                        L_ela(i,j)=0.
                  enddo
            enddo
            do j=1,6
                  do i=1,j
                        do ii=1,6
                              do jj=1,6
                                    L_ela(i,j)=L_ela(i,j)
     1                              +L_ela_cry(ii,jj)*RL(i,ii)*RL(j,jj)
                              enddo
                        enddo
                        L_ela(j,i)=L_ela(i,j)
                  enddo
            enddo
      else
            L_ela(1,1)=hsv(32)
            L_ela(2,1)=hsv(33)
            L_ela(3,1)=hsv(34)
            L_ela(4,1)=hsv(35)
            L_ela(5,1)=hsv(36)
            L_ela(6,1)=hsv(37)
            L_ela(2,2)=hsv(38)
            L_ela(3,2)=hsv(39)
            L_ela(4,2)=hsv(40)
            L_ela(5,2)=hsv(41)
            L_ela(6,2)=hsv(42)
            L_ela(3,3)=hsv(43)
            L_ela(4,3)=hsv(44)
            L_ela(5,3)=hsv(45)
            L_ela(6,3)=hsv(46)
            L_ela(4,4)=hsv(47)
            L_ela(5,4)=hsv(48)
            L_ela(6,4)=hsv(49)
            L_ela(5,5)=hsv(50)
            L_ela(6,5)=hsv(51)
            L_ela(6,6)=hsv(52)
            do j=1,6
                  do i=1,j
                        L_ela(i,j)=L_ela(j,i)
                  enddo
            enddo
      endif

            do l=1,12
                  do i=1,6
                        Ra(i,l)=0.
                        do j=1,6
                              Ra(i,l)=Ra(i,l)+L_ela(i,j)*eschmid(j,l)
                        enddo
                  enddo
            enddo
            
            do l=1,12
                  Ra(1,l)=Ra(1,l)
     1             +2*(wschmid(1,l)*sig(4)-wschmid(3,l)*sig(6))
                  Ra(2,l)=Ra(2,l)
     1             +2*(wschmid(2,l)*sig(5)-wschmid(1,l)*sig(4))
                  Ra(3,l)=Ra(3,l)
     1             +2*(wschmid(3,l)*sig(6)-wschmid(2,l)*sig(5))
                  Ra(4,l)=Ra(4,l)
     1             +wschmid(1,l)*sig(2)+wschmid(2,l)*sig(6)
     2             -wschmid(1,l)*sig(1)-wschmid(3,l)*sig(5)
                  Ra(5,l)=Ra(5,l)
     1             +wschmid(2,l)*sig(3)+wschmid(3,l)*sig(4)
     2             -wschmid(2,l)*sig(2)-wschmid(1,l)*sig(6)
                  Ra(6,l)=Ra(6,l)
     1             +wschmid(3,l)*sig(1)+wschmid(1,l)*sig(5)
     2             -wschmid(3,l)*sig(3)-wschmid(2,l)*sig(4)
            enddo

          !STEP5  
            do i=1,6
                  dsig_0(i)=0.
                  do l=1,12
                        dsig_0(i)=dsig_0(i)+Ra(i,l)*dgamma(l)
                  enddo
            enddo
            
c         DvをDevに変更(2020.0331_2)
            do i=1,6
                  sig_jau(i)=-dsig_0(i)-sig(i)*(Dv(1)+Dv(2)+Dv(3))
                  do j=1,6
                        sig_jau(i)=sig_jau(i)+L_ela(i,j)*Dv(j)
                  enddo
            enddo
            sig_r(1)=2.*(Wv(1)*sig(4)-Wv(3)*sig(6))
            sig_r(2)=2.*(Wv(2)*sig(5)-Wv(1)*sig(4))
            sig_r(3)=2.*(Wv(3)*sig(6)-Wv(2)*sig(5))
            sig_r(4)=Wv(1)*sig(2)+Wv(2)*sig(6)
     1       -Wv(1)*sig(1)-Wv(3)*sig(5)
            sig_r(5)=Wv(2)*sig(3)+Wv(3)*sig(4)
     1       -Wv(2)*sig(2)-Wv(1)*sig(6)
            sig_r(6)=Wv(3)*sig(1)+Wv(1)*sig(5)
     1       -Wv(3)*sig(3)-Wv(2)*sig(4)
            do i=1,6
                  sig_n1(i)=sig(i)+(sig_jau(i)+sig_r(i))*dt1
            enddo

           !STEP6
            do j=1,3
                  do i=1,3
                        if(i==j) then
                              idm(i,j)=1.
                        else
                              idm(i,j)=0.
                        endif
                  enddo
            enddo                                  
            do j=1,3
                  do i=1,3
                        fp_n(i,j)=idm(i,j)
                        do l=1,12
                              fp_n(i,j)=fp_n(i,j)
     1                         +dgamma(l)*s11(i,l)*m11(j,l)
                        enddo
                  enddo
            enddo
            call inverse(fp_n,fp_n_inv,3)
            do i=1,3
                  do j=1,3
                        fe_n1(i,j)=0.
                        do k=1,3
                          fe_n1(i,j)=fe_n1(i,j)+f_n1(i,k)*fp_n_inv(k,j)
                        enddo
                  enddo
            enddo

            Wev(:)=0.
            do i=1,3
                  Wev(i)=Wv(i)-Wp(i)
            enddo
            We(1,1)=0.
            We(1,2)=Wev(1)
            We(1,3)=-Wev(3)
            We(2,1)=-Wev(1)
            We(2,2)=0.
            We(2,3)=Wev(2)
            We(3,1)=Wev(3)
            We(3,2)=-Wev(2)
            We(3,3)=0.

            !STEP7
            We1=sqrt(We(1,2)*We(1,2)+We(2,3)*We(2,3)+We(3,1)*We(3,1))
            if(We1==0.) then
                  do j=1,3
                        do i=1,3
                              exp_we(i,j)=idm(i,j)
                        enddo
                  enddo
            else
                  do j=1,3
                     do i=1,3
                        exp_we(i,j)=idm(i,j)+(sin(We1*dt1)/We1)*We(i,j)
                        do k=1,3
                          exp_we(i,j)=exp_we(i,j)
     1                     +((1-cos(We1*dt1))/(We1**2))
     2                     *We(i,k)*We(k,j)
                        enddo
                     enddo
                  enddo
            endif
            do j=1,3
                  do i=1,3
                        r_n1(i,j)=0.
                        do k=1,3
                              r_n1(i,j)=r_n1(i,j)
     1                         +exp_we(i,k)*r(k,j)
                        enddo
                  enddo
            enddo
c-------------------------------------------------------------------
c           オイラー角の出力
            lphi=acos(r_n1(3,3))
            if(lphi==0.) then
                  phi1=atan2(-r_n1(1,2),r_n1(1,1))
                  phi2=0.
            else if(lphi==pi) then
                  phi1=atan2(r_n1(1,2),r_n1(1,1))
                  phi2=0.
            else
                  phi1=atan2(r_n1(1,3),-r_n1(2,3))
                  phi2=atan2(r_n1(3,1),r_n1(3,2))
            endif
            if(phi1 < 0.) then
                  phi1=phi1+2.*pi
            endif
            if(phi2 < 0.) then
                  phi2=phi2+2.*pi
            endif

            !STEP8
            do i=1,3
                  do j=1,3
                        RL_n1(i,j)=r_n1(i,j)**2
                  enddo
                        RL_n1(i,4)=2.*r_n1(i,2)*r_n1(i,3)
                        RL_n1(i,5)=2.*r_n1(i,3)*r_n1(i,1)
                        RL_n1(i,6)=2.*r_n1(i,1)*r_n1(i,2)
            enddo
            do j=1,3
                  RL_n1(4,j)=r_n1(2,j)*r_n1(3,j)
                  RL_n1(5,j)=r_n1(3,j)*r_n1(1,j)
                  RL_n1(6,j)=r_n1(1,j)*r_n1(2,j)
            enddo
            RL_n1(4,4)=r_n1(2,2)*r_n1(3,3)+r_n1(3,2)*r_n1(2,3)
            RL_n1(4,5)=r_n1(2,3)*r_n1(3,1)+r_n1(3,3)*r_n1(2,1)
            RL_n1(4,6)=r_n1(2,2)*r_n1(3,1)+r_n1(3,2)*r_n1(2,1)
            RL_n1(5,4)=r_n1(3,2)*r_n1(1,3)+r_n1(1,3)*r_n1(3,3)
            RL_n1(5,5)=r_n1(3,3)*r_n1(1,1)+r_n1(1,3)*r_n1(3,1)
            RL_n1(5,6)=r_n1(3,2)*r_n1(1,1)+r_n1(1,2)*r_n1(3,1)
            RL_n1(6,4)=r_n1(1,2)*r_n1(2,3)+r_n1(2,2)*r_n1(1,3)
            RL_n1(6,5)=r_n1(1,3)*r_n1(2,1)+r_n1(2,3)*r_n1(1,1)
            RL_n1(6,6)=r_n1(1,2)*r_n1(2,1)+r_n1(2,2)*r_n1(1,1)
            do j=1,6
                  do i=1,6
                        L_ela_n1(i,j)=0.
                  enddo
            enddo
            do j=1,6
                  do i=1,j
                        do ii=1,6
                              do jj=1,6
                                L_ela_n1(i,j)=L_ela_n1(i,j)
     1                        +L_ela_cry(ii,jj)*RL_n1(i,ii)*RL_n1(j,jj)
                              enddo
                        enddo
                        L_ela_n1(j,i)=L_ela_n1(i,j)
                  enddo
            enddo
            call inverse(fe_n1,fe_n1_inv,3)

c         s,m の更新にexp_weを使う(0408)
            do l=1,12
                  do i=1,3
                        s1_n1(i,l)=0.
                        m1_n1(i,l)=0.
                        do k=1,3
                              s1_n1(i,l)=s1_n1(i,l)
     1                         +exp_we(i,k)*s11(k,l)
                              m1_n1(i,l)=m1_n1(i,l)
     1                         +exp_we(i,k)*m11(k,l)
                        enddo
                  enddo
            enddo

c         シュミットテンソルの作成
            do l=1,12
                  do i=1,3
                    do j=1,3
                      Pac_n1(i,j,l)=(s1_n1(i,l)*m1_n1(j,l)
     1                 +s1_n1(j,l)*m1_n1(i,l))/2.
                      Wac_n1(i,j,l)=(s1_n1(i,l)*m1_n1(j,l)
     1                 -s1_n1(j,l)*m1_n1(i,l))/2.
                    end do
                  end do
            end do
            
            !STEP9
            gamma_n1=hsv(10)
            do l=1,12
              gamma_slip(l)=hsv(181+l)
            enddo
            do l=1,12
                  gamma_n1=gamma_n1+abs(dgamma(l))*dt1
                  gamma_slip(l)=gamma_slip(l)+abs(dgamma(l))*dt1
            enddo
            hsv(10)=gamma_n1
            do l=1,12
              hsv(181+l)=gamma_slip(l)
            enddo
c           Asaro型の硬化マトリクス 
            term1=(h0-hs)*gamma_n1/(gs-g0)
            term2=2.*exp(-term1)/(1.+exp(-2.*term1))
            h_n1=hs+(h0-hs)*term2**2
            do l=1,12
                  g_n1(l)=hsv(10+l)
            enddo
            do l=1,12
                  do k=1,12
                        if(k==l) then
                          g_n1(l)=g_n1(l)
     1                     +h_n1*abs(dgamma(k))*dt1
                        else
                          g_n1(l)=g_n1(l)
     1                     +q*h_n1*abs(dgamma(k))*dt1
                        endif
                  enddo
            enddo
            do l=1,12
                  hsv(10+l)=g_n1(l)
            enddo
            
            !値を返す
            sig(1)=sig_n1(1)
            sig(2)=sig_n1(2)
            sig(3)=sig_n1(3)
            sig(4)=sig_n1(4)
            sig(5)=sig_n1(5)
            sig(6)=sig_n1(6)
            !r_n1
            hsv(23)=r_n1(1,1)
            hsv(24)=r_n1(2,1)
            hsv(25)=r_n1(3,1)
            hsv(26)=r_n1(1,2)
            hsv(27)=r_n1(2,2)
            hsv(28)=r_n1(3,2)
            hsv(29)=r_n1(1,3)
            hsv(30)=r_n1(2,3)
            hsv(31)=r_n1(3,3)
            !L_ela_n1
            hsv(32)=L_ela_n1(1,1)
            hsv(33)=L_ela_n1(2,1)
            hsv(34)=L_ela_n1(3,1)
            hsv(35)=L_ela_n1(4,1)
            hsv(36)=L_ela_n1(5,1)
            hsv(37)=L_ela_n1(6,1)
            hsv(38)=L_ela_n1(2,2)
            hsv(39)=L_ela_n1(3,2)
            hsv(40)=L_ela_n1(4,2)
            hsv(41)=L_ela_n1(5,2)
            hsv(42)=L_ela_n1(6,2)
            hsv(43)=L_ela_n1(3,3)
            hsv(44)=L_ela_n1(4,3)
            hsv(45)=L_ela_n1(5,3)
            hsv(46)=L_ela_n1(6,3)
            hsv(47)=L_ela_n1(4,4)
            hsv(48)=L_ela_n1(5,4)
            hsv(49)=L_ela_n1(6,4)
            hsv(50)=L_ela_n1(5,5)
            hsv(51)=L_ela_n1(6,5)
            hsv(52)=L_ela_n1(6,6)
            !eschmid_n1
            do l=1,12
                  k=(l-1)*6
                  hsv(53+k)=Pac_n1(1,1,l)
                  hsv(54+k)=Pac_n1(2,2,l)
                  hsv(55+k)=Pac_n1(3,3,l)
                  hsv(56+k)=2*Pac_n1(1,2,l)
                  hsv(57+k)=2*Pac_n1(2,3,l)
                  hsv(58+k)=2*Pac_n1(3,1,l)
            enddo
            !wschmid_n1
            do l=1,12
                  k=(l-1)*3
                  hsv(125+k)=Wac_n1(2,1,l)
                  hsv(126+k)=Wac_n1(3,2,l)
                  hsv(127+k)=Wac_n1(1,3,l)
            enddo
c         dgammaの値を確認してみる
            do l=1,12
                  hsv(164+l)=dgamma(l)
            enddo
            
c        tau(4)をhsv(177)に保存する(0504_3)
           hsv(177)=tau(4)
            hsv(179)=phi1
            hsv(180)=lphi
            hsv(181)=phi2
c           s1_n1とm1_n1を保存(2020.02.04)                        
            do l=1,12
                  k=(l-1)*3
                  hsv(194+k)=s1_n1(1,l)
                  hsv(195+k)=s1_n1(2,l)
                  hsv(196+k)=s1_n1(3,l)
                  hsv(230+k)=m1_n1(1,l)
                  hsv(231+k)=m1_n1(2,l)
                  hsv(232+k)=m1_n1(3,l)
            enddo
      endif
      endif
      endif
      else if (etype.eq.'shell') then
        if (cm(16).eq.1234567) then
          call mitfailure(cm,eps,sig,epsp,hsv,dt1,capa,failel,tt,crv)
        else
          if (.not.failel) then
          gc    =capa*g
          q1    =abs(cm(1))*cm(2)/((1.0+cm(2))*(1.0-2.0*cm(2)))
          q3    =1./(q1+g2)
          eps(3)=-q1*(eps(1)+eps(2))*q3
          davg  =(-eps(1)-eps(2)-eps(3))/3.
          p     =-davg*abs(cm(1))/(1.-2.*cm(2))
          sig(1)=sig(1)+p+g2*(eps(1)+davg)
          sig(2)=sig(2)+p+g2*(eps(2)+davg)
          sig(3)=0.0
          sig(4)=sig(4)+g *eps(4)
          sig(5)=sig(5)+gc*eps(5)
          sig(6)=sig(6)+gc*eps(6)
          if (cm(1).lt.0.) then
            if (sig(1).gt.cm(5)) failel=.true.
          endif
          endif
        end if
      elseif (etype.eq.'beam ' ) then
          q1    =cm(1)*cm(2)/((1.0+cm(2))*(1.0-2.0*cm(2)))
          q3    =q1+2.0*g
          gc    =capa*g
          deti  =1./(q3*q3-q1*q1)
          c22i  = q3*deti
          c23i  =-q1*deti
          fac   =(c22i+c23i)*q1
          eps(2)=-eps(1)*fac-sig(2)*c22i-sig(3)*c23i
          eps(3)=-eps(1)*fac-sig(2)*c23i-sig(3)*c22i
          davg  =(-eps(1)-eps(2)-eps(3))/3.
          p     =-davg*cm(1)/(1.-2.*cm(2))
          sig(1)=sig(1)+p+g2*(eps(1)+davg)
          sig(2)=0.0
          sig(3)=0.0
          sig(4)=sig(4)+gc*eps(4)
          sig(5)=0.0
          sig(6)=sig(6)+gc*eps(6)

c
      elseif (etype.eq.'tbeam') then
        q1    =cm(1)*cm(2)/((1.0+cm(2))*(1.0-2.0*cm(2)))
        q3    =q1+2.0*g
        deti  =1./(q3*q3-q1*q1)
        c22i  = q3*deti
        c23i  =-q1*deti
        fac   =(c22i+c23i)*q1
        eps(2)=-eps(1)*fac
        eps(3)=-eps(1)*fac
        davg  =(-eps(1)-eps(2)-eps(3))/3.
        p     =-davg*cm(1)/(1.-2.*cm(2))
        sig(1)=sig(1)+p+g2*(eps(1)+davg)
        sig(2)=0.0
        sig(3)=0.0
c
      else
c       write(iotty,10) etype
c       write(iohsp,10) etype
c       write(iomsg,10) etype
c       call adios(TC_ERROR)
        cerdat(1)=etype
        call lsmsg(3,MSG_SOL+1150,ioall,ierdat,rerdat,cerdat,0)
      endif
c
c10   format(/
c    1 ' *** Error element type ',a,' can not be',
c    2 '           run with the current material model.')
      return
      end

      subroutine inverse(a,c,n)
            !============================================================
            ! Inverse matrix
            ! Method: Based on Doolittle LU factorization for Ax=b
            ! Alex G. December 2009
            !-----------------------------------------------------------
            ! input ...
            ! a(n,n) - array of coefficients for matrix A
            ! n      - dimension
            ! output ...
            ! c(n,n) - inverse matrix of A
            ! comments ...
            ! the original matrix a(n,n) will be destroyed 
            ! during the calculation
            !===========================================================
            implicit none 
            integer n
            double precision a(n,n), c(n,n)
            double precision L(n,n), U(n,n), b(n), d(n), x(n)
            double precision coeff
            integer i, j, k
            
            ! step 0: initialization for matrices L and U and b
            ! Fortran 90/95 aloows such operations on matrices
            L=0.0
            U=0.0
            b=0.0
            
            ! step 1: forward elimination
            do k=1, n-1
               do i=k+1,n
                  coeff=a(i,k)/a(k,k)
                  L(i,k) = coeff
                  do j=k+1,n
                     a(i,j) = a(i,j)-coeff*a(k,j)
                  end do
               end do
            end do
            
            ! Step 2: prepare L and U matrices 
            ! L matrix is a matrix of the elimination coefficient
            ! + the diagonal elements are 1.0
            do i=1,n
              L(i,i) = 1.0
            end do
            ! U matrix is the upper triangular part of A
            do j=1,n
              do i=1,j
                U(i,j) = a(i,j)
              end do
            end do
            
            ! Step 3: compute columns of the inverse matrix C
            do k=1,n
              b(k)=1.0
              d(1) = b(1)
            ! Step 3a: Solve Ld=b using the forward substitution
              do i=2,n
                d(i)=b(i)
                do j=1,i-1
                  d(i) = d(i) - L(i,j)*d(j)
                end do
              end do
            ! Step 3b: Solve Ux=d using the back substitution
              x(n)=d(n)/U(n,n)
              do i = n-1,1,-1
                x(i) = d(i)
                do j=n,i+1,-1
                  x(i)=x(i)-U(i,j)*x(j)
                end do
                x(i) = x(i)/u(i,i)
              end do
            ! Step 3c: fill the solutions x(n) into column k of C
              do i=1,n
                c(i,k) = x(i)
              end do
              b(k)=0.0
            end do
            end subroutine inverse

      subroutine umat44 (cm,eps,sig,epsp,hsv,dt1,capa,etype,tt,
     1 temper,failel,crv,nnpcrv,cma,qmat,elsiz,idele,reject)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      include 'nlqparm'
      include 'bk06.inc'
      include 'iounits.inc'
      dimension cm(*),eps(*),sig(*),hsv(*),crv(lq1,2,*),cma(*),qmat(3,3)
      integer nnpcrv(*)
      character*5 etype
      logical failel,reject
      INTEGER8 idele
      integer :: nflag=0
c
c
      if (ncycle.eq.1) then
        call usermsg('mat44')
      endif
c
      g2 =abs(cm(1))/(1.+cm(2))
      g  =.5*g2
      if (nflag==0) then
            open(11,file='sig.dat',status='replace')
            write(11,*) "#sig"
            close(11)
            nflag=1
      endif

      if (etype.eq.'solid'.or.etype.eq.'shl_t') then
        if (cm(16).eq.1234567) then
            call mitfail3d(cm,eps,sig,epsp,hsv,dt1,capa,failel,tt,crv)
            else
          if (.not.failel) then
            open(11,file='sig.dat',position='APPEND')
            write(11,*) 'ncycle idele'
            write(11,*) ncycle, idele
            write(11,*) '# sig first'
            do i=1,6
                  write(11,*) sig(i)
            enddo
            close(11)
             savg=(sig(1)+sig(2)+sig(3))/3.d0
             q1=sig(1)-savg
             q2=sig(2)-savg
             q3=sig(3)-savg
             q4=sig(4)
             q5=sig(5)
             q6=sig(6)

             davg=(eps(1)+eps(2)+eps(3))/3.0
             savg=savg+abs(cm(1))*davg/(1.-2.*cm(2))
            
             q1=q1+g2*(eps(1)-davg)
             q2=q2+g2*(eps(2)-davg)
             q3=q3+g2*(eps(3)-davg)
             q4=q4+g*eps(4)
             q5=q5+g*eps(5)
             q6=q6+g*eps(6)

             qh=cm(5)*cm(1)/(cm(1)-cm(5))
             ak=cm(6)+qh*epsp
             aj2=q4*q4+q5*q5+q6*q6+(q1*q1+q2*q2+q3*q3)/2.d0
             ak2=3*aj2-ak*ak
               if(ak2<=0) then
                   sig(1)=q1+savg
                   sig(2)=q2+savg
                   sig(3)=q3+savg
                   sig(4)=q4
                   sig(5)=q5
                   sig(6)=q6
               else
                   aj1=sqrt(3*abs(aj2))
                   depi=(aj1-ak)/(3.0*g+qh)
                   epsp=epsp+depi

                   dL=0.5*depi/(ak+qh*depi)
                   q1=q1/(1.0+6.0*g*dL)
                   q2=q2/(1.0+6.0*g*dL)
                   q3=q3/(1.0+6.0*g*dL)
                   q4=q4/(1.0+6.0*g*dL)
                   q5=q5/(1.0+6.0*g*dL)
                   q6=q6/(1.0+6.0*g*dL)

                   sig(1)=q1+savg
                   sig(2)=q2+savg
                   sig(3)=q3+savg
                   sig(4)=q4
                   sig(5)=q5
                   sig(6)=q6
               endif
               open(11,file='sig.dat',position='APPEND')
               write(11,*) '# sig end'
               do i=1,6
                     write(11,*) sig(i)
               enddo
               close(11)

            endif
        endif

      else if (etype.eq.'shell') then
        if (cm(16).eq.1234567) then
          call mitfailure(cm,eps,sig,epsp,hsv,dt1,capa,failel,tt,crv)
        else
          if (.not.failel) then
          gc    =capa*g
          q1    =abs(cm(1))*cm(2)/((1.0+cm(2))*(1.0-2.0*cm(2)))
          q3    =1./(q1+g2)
          eps(3)=-q1*(eps(1)+eps(2))*q3
          davg  =(-eps(1)-eps(2)-eps(3))/3.
          p     =-davg*abs(cm(1))/(1.-2.*cm(2))
          sig(1)=sig(1)+p+g2*(eps(1)+davg)
          sig(2)=sig(2)+p+g2*(eps(2)+davg)
          sig(3)=0.0
          sig(4)=sig(4)+g *eps(4)
          sig(5)=sig(5)+gc*eps(5)
          sig(6)=sig(6)+gc*eps(6)
          if (cm(1).lt.0.) then
            if (sig(1).gt.cm(5)) failel=.true.
          endif
          endif
        end if
      elseif (etype.eq.'beam ' ) then
          q1    =cm(1)*cm(2)/((1.0+cm(2))*(1.0-2.0*cm(2)))
          q3    =q1+2.0*g
          gc    =capa*g
          deti  =1./(q3*q3-q1*q1)
          c22i  = q3*deti
          c23i  =-q1*deti
          fac   =(c22i+c23i)*q1
          eps(2)=-eps(1)*fac-sig(2)*c22i-sig(3)*c23i
          eps(3)=-eps(1)*fac-sig(2)*c23i-sig(3)*c22i
          davg  =(-eps(1)-eps(2)-eps(3))/3.
          p     =-davg*cm(1)/(1.-2.*cm(2))
          sig(1)=sig(1)+p+g2*(eps(1)+davg)
          sig(2)=0.0
          sig(3)=0.0
          sig(4)=sig(4)+gc*eps(4)
          sig(5)=0.0
          sig(6)=sig(6)+gc*eps(6)

c
      elseif (etype.eq.'tbeam') then
        q1    =cm(1)*cm(2)/((1.0+cm(2))*(1.0-2.0*cm(2)))
        q3    =q1+2.0*g
        deti  =1./(q3*q3-q1*q1)
        c22i  = q3*deti
        c23i  =-q1*deti
        fac   =(c22i+c23i)*q1
        eps(2)=-eps(1)*fac
        eps(3)=-eps(1)*fac
        davg  =(-eps(1)-eps(2)-eps(3))/3.
        p     =-davg*cm(1)/(1.-2.*cm(2))
        sig(1)=sig(1)+p+g2*(eps(1)+davg)
        sig(2)=0.0
        sig(3)=0.0
c
      else
c       write(iotty,10) etype
c       write(iohsp,10) etype
c       write(iomsg,10) etype
c       call adios(TC_ERROR)
        cerdat(1)=etype
        call lsmsg(3,MSG_SOL+1150,ioall,ierdat,rerdat,cerdat,0)
      endif
      return
      end
      subroutine umat45 (cm,eps,sig,epsp,hsv,dt1,capa,
     . etype,time,temp,failel,crv,nnpcrv,cma,qmat,elsiz,idele,ih,
     . reject)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     Neo-Hookean material (sample user subroutine)
c
c     Also serves as a test example for the *MODULE feature,
c     see comments at the beginning of the code body
c
c     Variables
c
c     cm(1)=first material constant, here young's modulus
c     cm(2)=second material constant, here poisson's ratio
c        .
c        .
c        .
c     cm(n)=nth material constant
c
c     eps(1)=local x  strain increment
c     eps(2)=local y  strain increment
c     eps(3)=local z  strain increment
c     eps(4)=local xy strain increment
c     eps(5)=local yz strain increment
c     eps(6)=local zx strain increment
c
c     Note that eps is in strain Voigt notation, meaning that
c     e.g. eps(4) is the sum of tensorial xy and yx strain increments.
c
c     sig(1)=local x  stress
c     sig(2)=local y  stress
c     sig(3)=local z  stress
c     sig(4)=local xy stress
c     sig(5)=local yz stress
c     sig(6)=local zx stress
c
c     hsv(1)=1st history variable
c     hsv(2)=2nd history variable
c        .
c        .
c        .
c        .
c     hsv(n)=nth history variable
c
c     dt1=current time step size
c     capa=reduction factor for transverse shear
c     etype:
c        eq."solid" for solid elements
c        eq."sph  " for smoothed particle hydrodynamics
c        eq."sld2d" for shell forms 13 (2D solids - plane strain)
c        eq."sldax" for shell forms 14, and 15 (2D solids)
c        eq."shl_t" for shell forms 25, 26, and 27 (shells with thickness stretch)
c        eq."shell" for all other shell elements plus thick shell forms 1 and 2
c        eq."tshel" for thick shell forms 3 and 5
c        eq."hbeam" for beam element forms 1, 11, 14
c        eq."tbeam" for beam element form 3 (truss)
c        eq."dbeam" for beam element form 6 (discrete)
c        eq."beam " for all other beam elements (currently not used)
c
c     time=current problem time.
c     temp=current temperature
c
c     cma=additional memory for material data defined by LMCA at
c       6th field of 2nd crad of *DATA_USER_DEFINED
c
c     All transformations into the element local system are
c     performed prior to entering this subroutine.  Transformations
c     back to the global system are performed after exiting this
c     routine.
c
c     All history variables are initialized to zero in the input
c     phase.   Initialization of history variables to nonzero values
c     may be done during the first call to this subroutine for each
c     element.
c
c     Energy calculations for the dyna3d energy balance are done
c     outside this subroutine.
c
      include 'nlqparm'
      include 'iounits.inc'
      include 'bk06.inc'
      character*5 etype
      dimension cm(*),eps(*),sig(*),hsv(*),crv(lq1,2,*),cma(*),qmat(3,3)
      integer nnpcrv(*)
      logical failel,reject
      INTEGER8 idele
      real newthick(4)
c
      logical usemodule,usemetal
c
c     As an example of the use of *MODULE, this routine can be executed
c     both as a hyperelastic Neo-Hookean material (this routine) and as
c     an elastic-plastic material (subroutines metal*). The purpose of
c     the *MODULE concept is to load several shared object files to a
c     single LS-DYNA executable and whence (in this particular case)
c     allow multiple instances of subroutine umat45 be executed without
c     conflicts. This is important if independent user material distributors
c     happen to use the same user material number for their respective
c     material implementations, and neither want to reveal the source code.
c
c     To use this example, perform the following steps in order
c
c     1) Set usemodule=.true. below
c     2) Compile the code to a shared object file and call this file
c        hyperelastic.so
c     3) Set usemetal=.true. below
c     4) Recompile the code to a new shared object file and call this file
c        elasticplastic.so
c     5) In the keyword file, use *MODULE_LOAD for loading the two object
c        files and *MODULE_USE to associate hyperelastic materials to
c        material 45 in hyperelastic.so and elastic-plastic materials to
c        material 45 in elasticplastic.so
c
c     Note that for implicit, utan45 needs to modified accordingly
c
c     For details, refer to Appendix A of the Keyword User's Manual
c
      usemodule=.false.
      if (usemodule) then
        usemetal=.false.
        if (usemetal) then
          if (etype.eq.'solid') then
            call metalsld(cm,eps,sig,epsp,hsv,dt1,capa,etype,time,temp,
     .            failel,crv,nnpcrv)
          else
            call metalshl(cm,eps,sig,epsp,hsv,dt1,capa,etype,time,temp,
     .            failel,crv,nnpcrv)
          endif
          return
        endif
      endif
      if (.not.usemodule) then
      if (ncycle.eq.1) then
        call usermsg('mat45')
      endif
      endif
c
c     compute lame parameters
c
      xlambda=cm(1)*cm(2)/((1.+cm(2))*(1.-2.*cm(2)))
      xmu=.5*cm(1)/(1.+cm(2))
c
      if (etype.eq.'solid'.or.etype.eq.'shl_t'.or.
     1     etype.eq.'sld2d'.or.etype.eq.'tshel'.or.
     2     etype.eq.'sph  '.or.etype.eq.'sldax'.or.
     3     etype.eq.'shell'.and.iabs(ih).eq.3) then
c
        if (iabs(ih).eq.3) then
c     sample routine for ihyper=3
c     initialize iteration counter and new thickness,
c     the four thickness variables are stored immediately
c     after the deformation gradient always
           iter=0
           newthick(1)=hsv(10)
           newthick(2)=hsv(11)
           newthick(3)=hsv(12)
           newthick(4)=hsv(13)
        endif
 1      if (iabs(ih).eq.3) then
c     sample routine for ihyper=3
c     transform deformation gradient to local system
           b1=qmat(1,1)*hsv(1)+qmat(2,1)*hsv(2)+qmat(3,1)*hsv(3)
           b2=qmat(1,2)*hsv(1)+qmat(2,2)*hsv(2)+qmat(3,2)*hsv(3)
           b3=qmat(1,3)*hsv(1)+qmat(2,3)*hsv(2)+qmat(3,3)*hsv(3)
           hsv(1)=b1
           hsv(2)=b2
           hsv(3)=b3
           b1=qmat(1,1)*hsv(4)+qmat(2,1)*hsv(5)+qmat(3,1)*hsv(6)
           b2=qmat(1,2)*hsv(4)+qmat(2,2)*hsv(5)+qmat(3,2)*hsv(6)
           b3=qmat(1,3)*hsv(4)+qmat(2,3)*hsv(5)+qmat(3,3)*hsv(6)
           hsv(4)=b1
           hsv(5)=b2
           hsv(6)=b3
           b1=qmat(1,1)*hsv(7)+qmat(2,1)*hsv(8)+qmat(3,1)*hsv(9)
           b2=qmat(1,2)*hsv(7)+qmat(2,2)*hsv(8)+qmat(3,2)*hsv(9)
           b3=qmat(1,3)*hsv(7)+qmat(2,3)*hsv(8)+qmat(3,3)*hsv(9)
           hsv(7)=b1
           hsv(8)=b2
           hsv(9)=b3
        endif
c
c       deformation gradient stored in hsv(1),...,hsv(9)
c
c       compute jacobian
c
        detf=hsv(1)*(hsv(5)*hsv(9)-hsv(6)*hsv(8))
     1      -hsv(2)*(hsv(4)*hsv(9)-hsv(6)*hsv(7))
     2      +hsv(3)*(hsv(4)*hsv(8)-hsv(5)*hsv(7))
c
c       compute left cauchy-green tensor
c
        b1=hsv(1)*hsv(1)+hsv(4)*hsv(4)+hsv(7)*hsv(7)
        b2=hsv(2)*hsv(2)+hsv(5)*hsv(5)+hsv(8)*hsv(8)
        b3=hsv(3)*hsv(3)+hsv(6)*hsv(6)+hsv(9)*hsv(9)
        b4=hsv(1)*hsv(2)+hsv(4)*hsv(5)+hsv(7)*hsv(8)
        b5=hsv(2)*hsv(3)+hsv(5)*hsv(6)+hsv(8)*hsv(9)
        b6=hsv(1)*hsv(3)+hsv(4)*hsv(6)+hsv(7)*hsv(9)
c
c       compute cauchy stress
c
        detf=max(detf,1.e-8)
        detfinv=1./detf
        dmu=xmu-xlambda*log(detf)
        sig(1)=detfinv*(xmu*b1-dmu)
        sig(2)=detfinv*(xmu*b2-dmu)
        sig(3)=detfinv*(xmu*b3-dmu)
        sig(4)=detfinv*xmu*b4
        sig(5)=detfinv*xmu*b5
        sig(6)=detfinv*xmu*b6
c
        if (iabs(ih).eq.3) then
c     sample routine for ihyper=3
           if (abs(sig(3)).le.1.e-4*max(1.e-4*cm(1),abs(sig(1)),
     1          abs(sig(2)),abs(sig(4)),abs(sig(5)),abs(sig(6)))) then
c     convergence in thickness iterations, update thickness and return
              hsv(10)=newthick(1)
              hsv(11)=newthick(2)
              hsv(12)=newthick(3)
              hsv(13)=newthick(4)
              return
           endif
           iter=iter+1
           if (iter.eq.100) then
c     divergence, update thickness and return
              hsv(10)=newthick(1)
              hsv(11)=newthick(2)
              hsv(12)=newthick(3)
              hsv(13)=newthick(4)
              return
           elseif (iter.eq.1) then
c     the first stress was evaluated for eps(3)=0., store this point
              sigold=sig(3)
              epsold=eps(3)
c     new thickness strain estimate
              eps(3)=-xlambda*(eps(1)+eps(2))/(xlambda+2.*xmu)
           elseif (abs(sig(3)-sigold).gt.0.0) then
c     secant increment of thickness strain
              deps=-(eps(3)-epsold)/(sig(3)-sigold)*sig(3)
c     store previous point
              sigold=sig(3)
              epsold=eps(3)
c     update strain
              eps(3)=eps(3)+deps
           endif
c     recalculate deformation gradient with new thickness strain increment
           call usrshl_updatfs(hsv,hsv(10),newthick,eps(3))
c     go back and reevaluate stress
           goto 1
        endif
c
      else if (etype.eq.'shell') then
c
c       deformation gradient stored in hsv(1),...,hsv(9)
c
c       compute part of left cauchy-green tensor
c       independent of thickness strain increment
c
        b1=hsv(1)*hsv(1)+hsv(4)*hsv(4)+hsv(7)*hsv(7)
        b2=hsv(2)*hsv(2)+hsv(5)*hsv(5)+hsv(8)*hsv(8)
        b4=hsv(1)*hsv(2)+hsv(4)*hsv(5)+hsv(7)*hsv(8)
c
c       secant iterations for zero normal stress
c
        do iter=1,5
c
c         first thickness strain increment initial guess
c         assuming Poisson's ratio different from zero
c
          if (iter.eq.1) then
            eps(3)=-xlambda*(eps(1)+eps(2))/(xlambda+2.*xmu)
c
c         second thickness strain increment initial guess
c
          else if (iter.eq.2) then
            sigold=sig(3)
            epsold=eps(3)
            eps(3)=0.
c
c         secant update of thickness strain increment
c
          else if (abs(sig(3)-sigold).gt.0.0) then
            deps=-(eps(3)-epsold)/(sig(3)-sigold)*sig(3)
            sigold=sig(3)
            epsold=eps(3)
            eps(3)=eps(3)+deps
          endif
c
c         compute last row of deformation gradient
c
          call compute_f3s(hsv(3),hsv(6),hsv(9),eps(3))
c
c         compute jacobian
c
          detf=hsv(1)*(hsv(5)*hsv(9)-hsv(6)*hsv(8))
     1        -hsv(2)*(hsv(4)*hsv(9)-hsv(6)*hsv(7))
     2        +hsv(3)*(hsv(4)*hsv(8)-hsv(5)*hsv(7))
c
c         compute normal component of left cauchy-green tensor
c
          b3=hsv(3)*hsv(3)+hsv(6)*hsv(6)+hsv(9)*hsv(9)
c
c         compute normal stress
c
          detf=max(detf,1.e-8)
          detfinv=1./detf
          dmu=xmu-xlambda*log(detf)
          sig(1)=detfinv*(xmu*b1-dmu)
          sig(2)=detfinv*(xmu*b2-dmu)
          sig(3)=detfinv*(xmu*b3-dmu)
          sig(4)=detfinv*xmu*b4
c
c         exit if normal stress is sufficiently small
c
          if (abs(sig(3)).le.1.e-5*
     1     (abs(sig(1))+abs(sig(2))+abs(sig(4)))) goto 10
         enddo
c
c       compute remaining components of left cauchy-green tensor
c
 10     b5=hsv(2)*hsv(3)+hsv(5)*hsv(6)+hsv(8)*hsv(9)
        b6=hsv(1)*hsv(3)+hsv(4)*hsv(6)+hsv(7)*hsv(9)
c
c       compute remaining stress components
c
        sig(5)=detfinv*xmu*b5
        sig(6)=detfinv*xmu*b6
c
c     material model only available for solids and shells
c
      else
c       write(iotty,20) etype
c       write(iohsp,20) etype
c       write(iomsg,20) etype
c       call adios(TC_ERROR)
        cerdat(1)=etype
        call lsmsg(3,MSG_SOL+1151,ioall,ierdat,rerdat,cerdat,0)
      endif
c
c20   format(/
c    1 ' *** Error element type ',a,' can not be',
c    2 '           run with the current material model.')
      return
      end
      subroutine umat46 (cm,eps,sig,epsp,hsv,dt1,capa,etype,tt,
     1 temper,failel,crv,nnpcrv,cma,thhsvi,nthhsv,qmat,elsiz,idele,
     2 reject)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      include 'nlqparm'
      include 'bk06.inc'
      include 'iounits.inc'
      dimension cm(*),eps(*),sig(*),hsv(*),crv(lq1,2,*),thhsvi(*),
     . cma(*),qmat(3,3)
      integer nnpcrv(*)
      character*5 etype
      logical failel,reject
      INTEGER8 idele
c
c     Isotropic elastic material with access to history variables
c     of a corresponding thermal user material. See also
c     subroutine umat41 for information about non-thermal
c     specific information. Access to thermal history variables
c     requieres IHVE.eq.1 on *MAT_THERMAL_USER_DEFINED and
c     is only possible for a selection of shell and solid elements.
c     More information including a list of supported element
c     types is given in the comments to subroutine thusrmat.
c
c     Read only variables
c
c     cm(1)=first material constant, here young's modulus
c     cm(2)=second material constant, here poisson's ratio
c     cm(3)=.eq.0 do nothing
c           .eq.1 print mechanical and thermal history variables.
c
c     nthhsv=Number of thermal history variables.
c     thhsvi=If IHVE.eq.1 on *MAT_THERMAL_USER_DEFINED then
c            thhsvi(i) i=1...nthhsv, contains history
c            variable data from thermal user material routine
c            interpolated to current integration point using
c            shape functions for the corresponding thermal element.
c
c     compute shear modulus, g
c
      if (ncycle.eq.1) then
        call usermsg('mat46')
      endif
c
      g2 =cm(1)/(1.+cm(2))
      g  =.5*g2
c
      if (etype.eq.'solid'.or.etype.eq.'shl_t'.or.
     1     etype.eq.'sld2d'.or.etype.eq.'tshel'.or.
     2     etype.eq.'sph  '.or.etype.eq.'sldax') then
        davg=(-eps(1)-eps(2)-eps(3))/3.
        p=-davg*cm(1)/(1.-2.*cm(2))
        sig(1)=sig(1)+p+g2*(eps(1)+davg)
        sig(2)=sig(2)+p+g2*(eps(2)+davg)
        sig(3)=sig(3)+p+g2*(eps(3)+davg)
        sig(4)=sig(4)+g*eps(4)
        sig(5)=sig(5)+g*eps(5)
        sig(6)=sig(6)+g*eps(6)
c
      else if (etype.eq.'shell') then
        gc    =capa*g
        q1    =cm(1)*cm(2)/((1.0+cm(2))*(1.0-2.0*cm(2)))
        q3    =1./(q1+g2)
        eps(3)=-q1*(eps(1)+eps(2))*q3
        davg  =(-eps(1)-eps(2)-eps(3))/3.
        p     =-davg*cm(1)/(1.-2.*cm(2))
        sig(1)=sig(1)+p+g2*(eps(1)+davg)
        sig(2)=sig(2)+p+g2*(eps(2)+davg)
        sig(3)=0.0
        sig(4)=sig(4)+g *eps(4)
        sig(5)=sig(5)+gc*eps(5)
        sig(6)=sig(6)+gc*eps(6)
c
      else
c       write(iotty,10) etype
c       write(iohsp,10) etype
c       write(iomsg,10) etype
c       call adios(TC_ERROR)
        cerdat(1)=etype
        call lsmsg(3,MSG_SOL+1152,ioall,ierdat,rerdat,cerdat,0)
      endif
c
c     print history variables?
c
      if ( nint(cm(3)).eq.1) then
        write(iotty,*) " epsp ",epsp," thhsvi(1) ",thhsvi(1),
     1   " thhsvi(5) ",thhsvi(5),nthhsv
      endif
c
c10   format(/
c    1 ' *** Error element type ',a,' can not be',
c    2 '           run with the current user material model #47.')
      return
      end
#ifndef AEROQA
      subroutine umat47 (cm,eps,sig,epsp,hsv,dt1,capa,etype,tt,
     1 temper,failel,crv,nnpcrv,cma,qmat,elsiz,idele,reject)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      include 'nlqparm'
      include 'bk06.inc'
      include 'iounits.inc'
      dimension cm(*),eps(*),sig(*),hsv(*),crv(lq1,2,*),cma(*),qmat(3,3)
      logical failel,reject
      integer nnpcrv(*)
      character*5 etype
      INTEGER8 idele
c
      if (ncycle.eq.1) then
        call usermsg('mat47')
      endif
c
      return
      end
      subroutine umat48 (cm,eps,sig,epsp,hsv,dt1,capa,etype,tt,
     1 temper,failel,crv,nnpcrv,cma,qmat,elsiz,idele,reject)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      include 'nlqparm'
      include 'bk06.inc'
      include 'iounits.inc'
      dimension cm(*),eps(*),sig(*),hsv(*),crv(lq1,2,*),cma(*),qmat(3,3)
      logical failel,reject
      integer nnpcrv(*)
      character*5 etype
      INTEGER8 idele
c
      if (ncycle.eq.1) then
        call usermsg('mat48')
      endif
c
      return
      end
#endif
      subroutine umat49 (cm,eps,sig,epsp,hsv,dt1,capa,etype,tt,
     1 temper,failel,crv,nnpcrv,cma,qmat,elsiz,idele,reject)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      include 'nlqparm'
      include 'bk06.inc'
      include 'iounits.inc'
      dimension cm(*),eps(*),sig(*),hsv(*),crv(lq1,2,*),cma(*),qmat(3,3)
      integer nnpcrv(*)
      logical failel,reject
      character*5 etype
      INTEGER8 idele
c
      if (ncycle.eq.1) then
        call usermsg('mat49')
      endif
c
      return
      end
      subroutine umat50 (cm,eps,sig,epsp,hsv,dt1,capa,etype,tt,
     1 temper,failel,crv,nnpcrv,cma,qmat,elsiz,idele,reject)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      include 'nlqparm'
      include 'bk06.inc'
      include 'iounits.inc'
      dimension cm(*),eps(*),sig(*),hsv(*),crv(lq1,2,*),cma(*),qmat(3,3)
      integer nnpcrv(*)
      logical failel,reject
      character*5 etype
      INTEGER8 idele
c
      if (ncycle.eq.1) then
        call usermsg('mat50')
      endif
c
      return
      end
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c
c User Material Model: 
c   Some subroutines are used in the sample umat material models, and
c   can be excluded.
c
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
      subroutine metalshl (cm,eps,sig,epsp,hisv,dt,capa,elform,tt,temp,
     .     failel,crv,nnpcrv)
      implicit none
      include 'nlqparm'
      real cm(*),eps(*),sig(*),hisv(*)
      real crv(lq1,2,*)
      integer nnpcrv(*)
      character*5 elform
      logical failel
      real epsp,dt,capa,tt,temp
c
c     Elastic plastic material routine for shells
c
c     Material parameters:
c
c     cm(1)=Young's modulus
c     cm(2)=Poisson's ratio
c     cm(3)=Bulk modulus
c     cm(4)=Shear modulus
c     cm(5)=Hardening rule
c           .eq.0.:Linear hardening
c           .ne.0.:Hardening determined by load curve with ID cm(5)
c     cm(6)=Yield stress for linear hardening
c     cm(7)=Hardening modulus for linear hardening
c     cm(8)=Failure strain
c
c     History variables:
c
c     epsp   =Effective plastic strain
c     hisv(1)=Multiplier for plastic correction in implicit tangent
c
      real em,pr,bm,gm,hrd,epsf,g2,g3,gc,gt,sigyld,sighrd,eps12,
     1     eps3e,dvol,davg,p,sig1,sig2,sig4,sig5,sig6,sig56,sig456,
     2     sigv,sig1d,sig2d,sig3d,sigeff2,sigeff,quot,deps,coef,
     3     sig3e,eps3p,sig3p
c
c     Compute material parameters
c
      em=cm(1)
      pr=cm(2)
      bm=cm(3)
      gm=cm(4)
      hrd=cm(5)
      epsf=cm(8)
c
c     Some useful shear modulus parameters
c
      g2=2.*gm
      g3=3.*gm
      gc=capa*gm
      gt=4.5*(gc-gm)
c
c     Compute yield stress for current value of plastic strain
c
      if (hrd.le.0.) then
         sigyld=cm(6)+cm(7)*epsp
         sighrd=cm(7)
      else
         call crvval(crv,nnpcrv,hrd,epsp,sigyld,sighrd)
      endif
c
c     Compute elastic through thickness strain increment
c
      eps12=eps(1)+eps(2)
      eps3e=-pr*eps12/(1.-pr)
c
c     Compute volumetric strain increment
c
      dvol=eps12+eps3e
      davg=dvol/3.
c
c     Compute increment in (negative) pressure
c
      p=bm*dvol
c
c     Compute elastic trial stress
c
      sig1=sig(1)+p+g2*(eps(1)-davg)
      sig2=sig(2)+p+g2*(eps(2)-davg)
      sig4=sig(4)+gm*eps(4)
      sig5=sig(5)+gc*eps(5)
      sig6=sig(6)+gc*eps(6)
c
c     Compute some parameters of shear stress components
c     useful for further calculations
c
      sig56=sig5**2+sig6**2
      sig456=sig4**2+sig56
c
c     Compute effective stress in the sense of von Mises
c
      sigv=(sig1+sig2)/3.
      sig1d=sig1-sigv
      sig2d=sig2-sigv
      sig3d=-sigv
c
      sigeff2=1.5*(sig1d**2+sig2d**2+sig3d**2+2.*sig456)
      sigeff=sqrt(sigeff2)
c
c     Indicate elastic update as default
c
      hisv(1)=0.
c
c     Check if yielding
c
      if (sigeff.gt.sigyld) then
c
c     Yield stress exceeded, perform elastic-plastic stress return
c
c     Compute through thickness stress
c     for elastic through thickness strain
c
         quot=sig56/sigeff2
         deps=(sigeff-sigyld)/(sighrd+g3+gt*quot)
         coef=g3*deps/sigeff
         sig3e=-coef*sig3d
c
c     First point in secant iteration algorithm: (eps3e,sig3e)
c
c     Compute "plastic" through thickness strain increment
c
         eps3p=-eps12
c
c     Compute elastic trial stress
c
         sig1=sig(1)+g2*eps(1)
         sig2=sig(2)+g2*eps(2)
         sig3p=g2*eps3p
c
c     Compute effective stress in the sense of von Mises
c
         sigv=(sig1+sig2+sig3p)/3.
         sig1d=sig1-sigv
         sig2d=sig2-sigv
         sig3d=sig3p-sigv
c
         sigeff2=1.5*(sig1d**2+sig2d**2+sig3d**2+2.*sig456)
         sigeff=sqrt(sigeff2)
c
c     Check if yielding
c
         if (sigeff.gt.sigyld) then
c
c     Yield stress exceeded, perform stress return
c
            quot=sig56/sigeff2
            deps=(sigeff-sigyld)/(sighrd+g3+gt*quot)
            coef=g3*deps/sigeff
            sig3p=sig3p-coef*sig3d
c
         endif
c
c     Second point in secant iteration algorithm: (eps3p,sig3p)
c
c     Determine through thickness strain based on
c     interpolation from previous two stress updates
c
         if (abs(sig3e-sig3p).gt.1.e-4*
     1        max(abs(sig3e),abs(sig3p))) then
            eps(3)=eps3e-sig3e*(eps3e-eps3p)/(sig3e-sig3p)
         else
            eps(3)=eps3p
         endif
c
c     Compute volumetric strain increment
c
         dvol=eps12+eps(3)
         davg=dvol/3.
c
c     Compute increment in (negative) pressure
c
         p=bm*dvol
c
c     Compute elastic trial stress
c
         sig(1)=sig(1)+p+g2*(eps(1)-davg)
         sig(2)=sig(2)+p+g2*(eps(2)-davg)
         sig(3)=p+g2*(eps(3)-davg)
c
c     Compute effective stress in the sense of von Mises
c
         sigv=(sig(1)+sig(2)+sig(3))/3.
         sig1d=sig(1)-sigv
         sig2d=sig(2)-sigv
         sig3d=sig(3)-sigv
c
         sigeff2=1.5*(sig1d**2+sig2d**2+sig3d**2+2.*sig456)
         sigeff=sqrt(sigeff2)
c
c     Check if yielding
c
         if (sigeff.gt.sigyld) then
c
c     Plastic update
c
            hisv(1)=.9
c
c     Yield stress exceeded, perform stress return
c
c     Increment plastic strain
c
            quot=sig56/sigeff2
            deps=(sigeff-sigyld)/(sighrd+g3+gt*quot)
            epsp=epsp+deps
c
c     Return stress in the direction of deviatoric stress
c     and set through thickness stress to zero
c
            coef=g3*deps/sigeff
            sig(1)=sigv+sig1d*(1.-coef)
            sig(2)=sigv+sig2d*(1.-coef)
            sig(3)=0.
            sig(4)=sig4*(1.-coef)
            sig(5)=sig5*(1.-capa*coef)
            sig(6)=sig6*(1.-capa*coef)
c
         else
c
c     Yield stress not exceeded
c
            sig(3)=0.
            sig(4)=sig4
            sig(5)=sig5
            sig(6)=sig6
c
         endif
         
c
c     Elastic-plastic stress update finished
c
      else
c
c     The update was elastic, just store the stress
c     and strain increment with no update of history
c     variables, i.e., plastic strain
c
         sig(1)=sig1
         sig(2)=sig2
         sig(3)=0.
         sig(4)=sig4
         sig(5)=sig5
         sig(6)=sig6
c
c     Store through thickness strain increment
c
         eps(3)=eps3e
c
c     Elastic stress update finished
c
      endif
c
c     Check if failure
c
      if (epsp.gt.epsf) failel=.true.
c
      return
      end
      subroutine metalsld (cm,eps,sig,epsp,hisv,dt,capa,elform,tt,temp,
     .     failel,crv,nnpcrv)
      implicit none
      include 'nlqparm'
      real cm(*),eps(*),sig(*),hisv(*)
      real crv(lq1,2,*)
      integer nnpcrv(*)
      character*5 elform
      logical failel
      real epsp,dt,capa,tt,temp
c
c     Elastic plastic material routine for solids
c
c     Material parameters:
c
c     cm(1)=Young's modulus
c     cm(2)=Poisson's ratio
c     cm(3)=Bulk modulus
c     cm(4)=Shear modulus
c     cm(5)=Hardening rule
c           .eq.0.:Linear hardening
c           .ne.0.:Hardening determined by load curve with ID cm(5)
c     cm(6)=Yield stress for linear hardening
c     cm(7)=Hardening modulus for linear hardening
c     cm(8)=Failure strain
c
c     History variables:
c
c     epsp   =Effective plastic strain
c     hisv(1)=Multiplier for plastic correction in implicit tangent
c
      real em,pr,bm,gm,hrd,epsf,g2,g3,sigyld,sighrd,dvol,davg,p,sigv,
     1     sig1d,sig2d,sig3d,sig456,sigeff,deps,coef
c
c     Compute material parameters
c
      em=cm(1)
      pr=cm(2)
      bm=cm(3)
      gm=cm(4)
      hrd=cm(5)
      epsf=cm(8)
c
c     Some useful shear modulus parameters
c
      g2=2.*gm
      g3=3.*gm
c
c     Compute yield stress for current value of plastic strain
c
      if (hrd.le.0.) then
         sigyld=cm(6)+cm(7)*epsp
         sighrd=cm(7)
      else
         call crvval(crv,nnpcrv,hrd,epsp,sigyld,sighrd)
      endif
c
c     Compute volumetric strain increment
c
      dvol=eps(1)+eps(2)+eps(3)
      davg=dvol/3.
c
c     Compute increment in (negative) pressure
c
      p=bm*dvol
c
c     Compute elastic trial stress
c
      sig(1)=sig(1)+p+g2*(eps(1)-davg)
      sig(2)=sig(2)+p+g2*(eps(2)-davg)
      sig(3)=sig(3)+p+g2*(eps(3)-davg)
      sig(4)=sig(4)+gm*eps(4)
      sig(5)=sig(5)+gm*eps(5)
      sig(6)=sig(6)+gm*eps(6)
c
c     Compute effective stress in the sense of von Mises
c
      sigv=(sig(1)+sig(2)+sig(3))/3.
      sig1d=sig(1)-sigv
      sig2d=sig(2)-sigv
      sig3d=sig(3)-sigv
      sig456=sig(4)**2+sig(5)**2+sig(6)**2
c
      sigeff=sqrt(1.5*(sig1d**2+sig2d**2+sig3d**2+2.*sig456))
c
c     Indicate elastic update as default
c
      hisv(1)=0.
c
c     Check if yielding
c
      if (sigeff.gt.sigyld) then
c
c     Plastic update
c
         hisv(1)=.9
c
c     Yield stress exceeded, perform elastic-plastic stress return
c
c     Increment plastic strain
c
         deps=(sigeff-sigyld)/(sighrd+g3)
         epsp=epsp+deps
c
c     Return stress in the direction of deviatoric stress
c
         coef=1.-g3*deps/sigeff
         sig(1)=sigv+sig1d*coef
         sig(2)=sigv+sig2d*coef
         sig(3)=sigv+sig3d*coef
         sig(4)=sig(4)*coef
         sig(5)=sig(5)*coef
         sig(6)=sig(6)*coef
c
      endif
c
c     Check if failure
c
      if (epsp.gt.epsf) failel=.true.
c
      return
      end
      subroutine metaltan (cm,eps,sig,epsp,hisv,dt,capa,elform,tt,temp,
     1 failel,crv,nnpcrv,es)
      implicit none
      include 'nlqparm'
      real cm(*),eps(*),sig(*),hisv(*)
      real crv(lq1,2,*)
      integer nnpcrv(*)
      character*5 elform
      logical failel
      real epsp,dt,capa,tt,temp
      real es(6,6)
c
c     Elastic plastic material routine associated with
c     the metal* routines above, tangent is the same for
c     solids and shells. For shells this is a code that
c     assumes capa=1.0, a minor detail.
c
      real em,pr,bm,gm,hrd,g3,bg23,bg43,sigv,sig1d,sig2d,sig3d,sig456,
     1     sigeff,sighrd,coef,cdfds(6)
      integer i,j
c
c     Compute material parameters
c
      em=cm(1)
      pr=cm(2)
      bm=cm(3)
      gm=cm(4)
      hrd=cm(5)
c
c     Some useful modulus parameters
c
      g3=3.*gm
      bg23=bm-2.*gm/3.
      bg43=bm+4.*gm/3.
c
c     Elastic tangent
c
      es(1,1)=bg43
      es(2,2)=bg43
      es(3,3)=bg43
      es(2,1)=bg23
      es(3,1)=bg23
      es(3,2)=bg23
      es(1,2)=es(2,1)
      es(1,3)=es(3,1)
      es(2,3)=es(3,2)
      es(4,4)=gm
      es(5,5)=gm
      es(6,6)=gm
c
      if (hisv(1).gt.0.) then
c
c     Need plastic correction
c
c     Compute effective stress in the sense of von Mises
c
         sigv=(sig(1)+sig(2)+sig(3))/3.
         sig1d=sig(1)-sigv
         sig2d=sig(2)-sigv
         sig3d=sig(3)-sigv
         sig456=sig(4)**2+sig(5)**2+sig(6)**2
c
         sigeff=sqrt(1.5*(sig1d**2+sig2d**2+sig3d**2+2.*sig456))
c
c     Compute hardening
c
         if (hrd.le.0.) then
            sighrd=cm(7)
         else
            call crvval(crv,nnpcrv,hrd,epsp,coef,sighrd)
         endif
c
c     Compute C*df/ds
c
         coef=g3/sigeff
         cdfds(1)=coef*sig1d
         cdfds(2)=coef*sig2d
         cdfds(3)=coef*sig3d
         cdfds(4)=coef*sig(4)
         cdfds(5)=coef*sig(5)
         cdfds(6)=coef*sig(6)
c
c     Update tangent
c
         coef=hisv(1)/(g3+sighrd)
         do j=1,6
            do i=1,6
               es(i,j)=es(i,j)-coef*cdfds(i)*cdfds(j)
            enddo
         enddo
c
      endif
c
      return
      end
      subroutine usrshl_updatfs(fs,ts,ss,es)
      implicit none
      include 'nlqparm'
C_TASKCOMMON (bk36loc)
      integer index
      common/bk36loc/index
      real fs(3,3),ts(4),ss(4),es
      real f(nlq,3,3),t(nlq,4),s(nlq,4),e(nlq)
      integer i,j
      e(index)=es
      do i=1,4
         t(index,i)=ts(i)
         do j=1,nlq
            s(j,i)=1.
         enddo
      enddo
      call usrshl_updatfv(f,t,s,e,index,index)
      do i=1,4
         ss(i)=s(index,i)
      enddo
      do i=1,3
         do j=1,3
            fs(i,j)=f(index,i,j)
         enddo
      enddo
      return
      end
