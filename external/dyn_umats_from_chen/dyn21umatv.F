# 1 "dyn21umatv.F"
# 1 ".\define.inc" 1 


# 26
















# 44


# 48


# 53


# 57


# 62









# 73









# 85



# 90






























# 122

# 126




# 136



# 180


# 188


# 223


# 257


# 283






# 299






# 311

# 318









# 329




# 341










# 370


# 1 ".\adios.h" 1 
# 9



















# 373 ".\define.inc" 2 


# 379

# 382






# 408



# 417

# 424





# 2 "dyn21umatv.F" 2 
# 1 ".\define2.inc" 1 



# 3 "dyn21umatv.F" 2 
      subroutine umat41v(cm,d1,d2,d3,d4,d5,d6,sig1,sig2,
     . sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,dt1siz,capa,
     . etype,tt,temps,failels,nlqa,crv,nnpcrv,cma,qmat,elsizv,idelev,
     . reject)
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
      include 'nhisparm.inc'
# 1 ".\usermat_vendor.inc" 1 
c
      integer user_iform
      character*10 vendor
      common /usermat_vendor/ user_iform,vendor
# 19 "dyn21umatv.F" 2 
      dimension d1(*),d2(*),d3(*),d4(*),d5(*),d6(*)
      dimension sig1(*),sig2(*),sig3(*),sig4(*),sig5(*),sig6(*)
      dimension cm(*),epsps(*),hsvs(nlq,*),dt1siz(*)
      dimension temps(*),crv(lq1,2,*),cma(*),qmat(nlq,3,3),elsizv(*)
      integer nnpcrv(*)
      integer idelev(*)
      logical failels(*),reject
      character*5 etype
c
      dimension sig(6),eps(6),hsv(NHISVAR)
c
c$omp threadprivate (/usermat_vendor/)
      if (ncycle.eq.1) call usermsg('mat41')
c
      do i=lft,llt
        sig(1)=sig1(i)
        sig(2)=sig2(i)
        sig(3)=sig3(i)
        sig(4)=sig4(i)
        sig(5)=sig5(i)
        sig(6)=sig6(i)
c
        eps(1)=d1(i)
        eps(2)=d2(i)
        eps(3)=d3(i)
        eps(4)=d4(i)
        eps(5)=d5(i)
        eps(6)=d6(i)
c
        call umat41(cm,eps,sig,epsps(i),hsv,dt1siz(i),capa,etype,tt,
     1   temps(i),failels(i),crv,nnpcrv,cma,0,elsizv(i),idelev(i),
     2   reject)
c
        sig1(i)=sig(1)
        sig2(i)=sig(2)
        sig3(i)=sig(3)
        sig4(i)=sig(4)
        sig5(i)=sig(5)
        sig6(i)=sig(6)
        d3(i)=eps(3)
      enddo
c
      return
      end
      subroutine umat42v(cm,d1,d2,d3,d4,d5,d6,sig1,sig2,
     . sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,dt1siz,capa,
     . etype,tt,temps,failels,nlqa,crv,nnpcrv,cma,qmat,elsizv,idelev,
     . reject)
c
c******************************************************************
c|  Livermore Software Technology Corporation (LSTC)              |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2007 LSTC                                      |
c|  All Rights Reserved                                           |
c******************************************************************
      include 'nlqparm'
      include 'bk06.inc'
      dimension d1(*),d2(*),d3(*),d4(*),d5(*),d6(*)
      dimension sig1(*),sig2(*),sig3(*),sig4(*),sig5(*),sig6(*)
      dimension cm(*),epsps(*),hsvs(nlq,*),dt1siz(*)
      dimension temps(*),crv(lq1,2,*),cma(*),qmat(nlq,3,3),elsizv(*)
      integer nnpcrv(*)
      integer idelev(*)
      logical failels(*),reject
      character*5 etype
c
c     eps(1)=local x  strain increment
c     eps(2)=local y  strain increment
c     eps(3)=local z  strain increment
c     eps(4)=local xy strain increment
c     eps(5)=local yz strain increment
c     eps(6)=local zx strain increment
c
c     sig(1)=local x  stress
c     sig(2)=local y  stress
c     sig(3)=local z  stress
c     sig(4)=local xy stress
c     sig(5)=local yz stress
c     sig(6)=local zx stress
c
c     material properties for orthotropic elastic material
c     If transverse elastic properties are not provided, the transverse
c     directions take on the same properties as the longitudinal direction,
c     i.e. behaves as an isotropic material
c
      if (ncycle.eq.1) call usermsg('mat42')
c
      E1 = cm(1)
      E2 = cm(12)
      E3 = cm(13)
      v21 = cm(14)
      v31=cm(15)
      v32=cm(16)
      G12 = cm(17)
      G23 = cm(18)
      G31 = cm(19)
c
      v12 = v21*E1/E2
      v23 = v32*E2/E3
      v13 = v31*E1/E3
c
c     stiffness matrix
c
      S = 1.-v12*v21-v23*v32-v31*v13-2.*v21*v32*v13
c
      C11=(1. - v23*v32)*E1/S
      C12=(v21 + v31*v23)*E1/S
      C13=(v31 + v21*v32)*E1/S
c     C13=(v31 + v21*v23)/(E2*E3*S)
      C22=(1. - v31*v13)*E2/S
      C23=(v32 + v31*v12)*E2/S
      C33=(1. - v12*v21)*E3/S
      C44=G12
      C55=G23
      C66=G31
c
c     write(59,*) 'Stiffness Matrix'
c     write(59,*) C11, '  ',C12,  '  ',  C13
c     write(59,*) C22, '  ',C23,  '  ',  C33
c     write(59,*) C44, '  ',C55,  '  ',  C66
c     write(59,*) '      '
c
      do  10 i=lft,llt
      if (etype.eq.'solid'.or.etype.eq.'shl_t'.or.
     1     etype.eq.'sld2d'.or.etype.eq.'tshel'.or.
     2     etype.eq.'sph  '.or.etype.eq.'sldax'.or.
     3     etype.eq.'sldco') then
c
c       Computes stresses
c
        sig1(i) = sig1(i)+(C11*d1(i)+C12*d2(i)+C13*d3(i))
        sig2(i) = sig2(i)+(C12*d1(i)+C22*d2(i)+C23*d3(i))
        sig3(i) = sig3(i)+(C13*d1(i)+C23*d2(i)+C33*d3(i))
        sig4(i) = sig4(i)+C44*d4(i)
        sig5(i) = sig5(i)+C55*d5(i)
        sig6(i) = sig6(i)+C66*d6(i)
c
c       sig1(i) = sig1(i)+(C11*d1(i)+C12*d2(i)+C13*d3(i))*dt1siz(i)
c       sig2(i) = sig2(i)+(C12*d1(i)+C22*d2(i)+C23*d3(i))*dt1siz(i)
c       sig3(i) = sig3(i)+(C13*d1(i)+C23*d2(i)+C33*d3(i))*dt1siz(i)
c       sig4(i) = sig4(i)+C44*d4(i)*dt1siz(i)
c       sig5(i) = sig5(i)+C55*d5(i)*dt1siz(i)
c       sig6(i) = sig6(i)+C66*d6(i)*dt1siz(i)
c
      else if (etype.eq.'shell'.or.etype.eq.'shl2d') then
c       hsv(i,7)=-(hsv(i,4)*C13*hsv(i,1) + C23*hsv(i,6))/C33
        d3(i) = -(C13*d1(i) + C23*d2(i))/C33
        sig1(i) = sig1(i)+(C11*d1(i)+C12*d2(i)+C13*d3(i))
        sig2(i) = sig2(i)+(C12*d1(i)+C22*d2(i)+C23*d3(i))
        sig3(i) = 0.0
        sig4(i) = sig4(i)+C44*d4(i)
        sig5(i) = sig5(i)+capa*C55*d5(i)
        sig6(i) = sig6(i)+capa*C66*d6(i)
         endif
   10 continue
c
      return
      end
      subroutine umat43v(cm,d1,d2,d3,d4,d5,d6,sig1,sig2,
     . sig3,sig4,sig5,sig6,epsps,hsv,lft,llt,dt1siz,capa,
     . etype,tt,temps,failels,nlqa,crv,nnpcrv,cma,qmat,elsizv,idelev,
     . reject)
c******************************************************************
c|  Livermore Software Technology Corporation (LSTC)              |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2007 LSTC                                      |
c|  All Rights Reserved                                           |
c******************************************************************
      include 'nlqparm'
      include 'bk06.inc'
      include 'iounits.inc'
      dimension d1(*),d2(*),d3(*),d4(*),d5(*),d6(*)
      dimension sig1(*),sig2(*),sig3(*),sig4(*),sig5(*),sig6(*)
      dimension cm(*),epsps(*),hsv(nlq,*),dt1siz(*)
      dimension temps(*),crv(101,2,*),cma(*),qmat(nlq,3,3),elsizv(*)
      integer nnpcrv(*)
      integer idelev(*)
      logical failels(*),reject
      character*5 etype
c
c     eps(1)=local x  strain increment
c     eps(2)=local y  strain increment
c     eps(3)=local z  strain increment
c     eps(4)=local xy strain increment
c     eps(5)=local yz strain increment
c     eps(6)=local zx strain increment
c
c     sig(1)=local x  stress
c     sig(2)=local y  stress
c     sig(3)=local z  stress
c     sig(4)=local xy stress
c     sig(5)=local yz stress
c     sig(6)=local zx stress
c
c     material properties for orthotropic elastic material
c     If transverse elastic properties are not provided, the transverse
c     directions take on the same properties as the longitudinal direction,
c     i.e. behaves as an isotropic material
c
      if (ncycle.eq.1) call usermsg('mat43')
c
      E1 = cm(1)
      E2 = cm(12)
      E3 = cm(13)
      v21 = cm(14)
      v31=cm(15)
      v32=cm(16)
      G12 = cm(17)
      G23 = cm(18)
      G31 = cm(19)
c
      v12 = v21*E1/E2
      v23 = v32*E2/E3
      v13 = v31*E1/E3
c
c     stiffness matrix
c
      S = (1.-v12*v21-v23*v32-v31*v13-2*v21*v32*v13)/(E1*E2*E3)
c
      C11=(1. - v23*v32)/(E2*E3*S)
      C12=(v21 + v31*v23)/(E2*E3*S)
      C13=(v31 + v21*v32)/(E2*E3*S)
      C22=(1. - v31*v13)/(E1*E3*S)
      C23=(v32 + v31*v12)/(E1*E3*S)
      C33=(1. - v12*v21)/(E1*E2*S)
      C44=G12
      C55=G23
      C66=G31
c
c     write(59,*) 'Stiffness Matrix'
c     write(59,*) C11, '  ',C12,  '  ',  C13
c     write(59,*) C22, '  ',C23,  '  ',  C33
c     write(59,*) C44, '  ',C55,  '  ',  C66
c     write(59,*) '      '
c
      do  10 i=lft,llt
      if (etype.eq.'solid'.or.etype.eq.'shl_t'.or.
     1     etype.eq.'sld2d'.or.etype.eq.'tshel'.or.
     2     etype.eq.'sph  '.or.etype.eq.'sldax'.or.
     3     etype.eq.'sldco') then
c
c       integrate 3-D strains (six components)
c       +++++++++++++++++++++++++++++++++++++++++++++++++
c       hsv(i,1)=hsv(i,1)+d1(i)
c       hsv(i,6)=hsv(i,6)+d2(i)
c       hsv(i,7)=hsv(i,7)+d3(i)
c       hsv(i,8)=hsv(i,8)+d4(i)
c       hsv(i,9)=hsv(i,9)+d5(i)
c       hsv(i,10)=hsv(i,10)+d6(i)
c       +++++++++++++++++++++++++++++++++++++++++++++++++
c
c       Computes stresses
c
c       sig1(i) = C11*hsv(i,1)+C12*hsv(i,6)+C13*hsv(i,7)
c       sig2(i) = C12*hsv(i,1)+C22*hsv(i,6)+C23*hsv(i,7)
c       sig3(i) = C13*hsv(i,1)+C23*hsv(i,6)+C33*hsv(i,7)
c       sig4(i) = C44*hsv(i,8)
c       sig5(i) = C55*hsv(i,9)
c       sig6(i) = C66*hsv(i,10)
c
c       sig1(i) = sig1(i)+(C11*d1(i)+C12*d2(i)+C13*d3(i))
c       sig2(i) = sig2(i)+(C12*d1(i)+C22*d2(i)+C23*d3(i))
c       sig3(i) = sig3(i)+(C13*d1(i)+C23*d2(i)+C33*d3(i))
c       sig4(i) = sig4(i)+C44*d4(i)
c       sig5(i) = sig5(i)+C55*d5(i)
c       sig6(i) = sig6(i)+C66*d6(i)
c
c       S1 = C11*d1(i)+C12*d2(i)+C13*d3(i)
c       S2 = C12*d1(i)+C22*d2(i)+C23*d3(i)
c       S3 = C13*d1(i)+C23*d2(i)+C33*d3(i)
c       S4 = C44*d4(i)
c       S5 = C55*d5(i)
c       S6 = C66*d6(i)
c
c       hsv(i,1) = 2.0
c       hsv(i,2) = 0.9
c       hsv(i,3) = 1.2
c       hsv(i,4) = 0.5
c       hsv(i,5) = 3.0
c       hsv(i,6) = 5.0
c       hsv(i,7) = 0.7
c       hsv(i,8) = 3.4
c       hsv(i,9) = 8.0
c
c       Right Green-St. Venant Strain Tensor
        G1 = 0.5*(hsv(i,1)*hsv(i,1)+hsv(i,2)*hsv(i,2)+
     .       hsv(i,3)*hsv(i,3)-1.)
        G2 = 0.5*(hsv(i,4)*hsv(i,4)+hsv(i,5)*hsv(i,5)+
     .       hsv(i,6)*hsv(i,6)-1.)
        G3 = 0.5*(hsv(i,7)*hsv(i,7)+hsv(i,8)*hsv(i,8)+
     .       hsv(i,9)*hsv(i,9)-1.)
        G4 = 0.5*(hsv(i,1)*hsv(i,4)+hsv(i,2)*hsv(i,5)+
     .       hsv(i,3)*hsv(i,6))
        G5 = 0.5*(hsv(i,4)*hsv(i,7)+hsv(i,5)*hsv(i,8)+
     .       hsv(i,6)*hsv(i,9))
        G6 = 0.5*(hsv(i,1)*hsv(i,7)+hsv(i,2)*hsv(i,8)+
     .       hsv(i,3)*hsv(i,9))
c
c       Left Green-St. Venant Strain Tensor
c       G1 = 0.5*(hsv(i,1)*hsv(i,1)+hsv(i,4)*hsv(i,4)+
c     .      hsv(i,7)*hsv(i,7)-1.)
c       G2 = 0.5*(hsv(i,2)*hsv(i,2)+hsv(i,5)*hsv(i,5)+
c     .      hsv(i,8)*hsv(i,8)-1.)
c       G3 = 0.5*(hsv(i,3)*hsv(i,3)+hsv(i,6)*hsv(i,6)+
c     .      hsv(i,9)*hsv(i,9)-1.)
c       G4 = 0.5*(hsv(i,1)*hsv(i,2)+hsv(i,4)*hsv(i,5)+
c     .      hsv(i,7)*hsv(i,8))
c       G5 = 0.5*(hsv(i,2)*hsv(i,3)+hsv(i,5)*hsv(i,6)+
c     .      hsv(i,8)*hsv(i,9))
c       G6 = 0.5*(hsv(i,1)*hsv(i,3)+hsv(i,4)*hsv(i,6)+
c     .      hsv(i,7)*hsv(i,9))
c
c       write(59,*) 'Green-St. Venant Strain Tensor'
c       write(59,*) G1, '  ' ,G4,  '  ' ,G6
c       write(59,*) G4, '  ' ,G2,  '  ' ,G5
c       write(59,*) G6, '  ' ,G5,  '  ' ,G3
c       write(59,*) '      '
c
c       Second Piola-Kirchhoff Stress Tensor
        S1 = C11*G1 + C12*G2 + C13*G3
        S2 = C12*G1 + C22*G2 + C23*G3
        S3 = C13*G1 + C23*G2 + C33*G3
        S4 = 2.*C44*G4
        S5 = 2.*C55*G5
        S6 = 2.*C66*G6
c
c       write(59,*) 'Second Piola-Kirchhoff Stress Tensor'
c       write(59,*) S1, '  ' ,S4,  '  ' ,S6
c       write(59,*) S4, '  ' ,S2,  '  ' ,S5
c       write(59,*) S6, '  ' ,S5,  '  ' ,S3
c       write(59,*) '      '
c
c       Jacobian
        detF=hsv(i,1)*(hsv(i,5)*hsv(i,9)-hsv(i,6)*hsv(i,8))-
     .       hsv(i,2)*(hsv(i,4)*hsv(i,9)-hsv(i,6)*hsv(i,7))+
     .       hsv(i,3)*(hsv(i,4)*hsv(i,8)-hsv(i,5)*hsv(i,7))
c
c       write(59,*) 'Jacobian'
c       write(59,*) detF
c       write(59,*) '      '
c
c       Cauchy Stresses (F*S*F^T)
        FS11 = hsv(i,1)*S1 + hsv(i,4)*S4 + hsv(i,7)*S6
        FS12 = hsv(i,1)*S4 + hsv(i,4)*S2 + hsv(i,7)*S5
        FS13 = hsv(i,1)*S6 + hsv(i,4)*S5 + hsv(i,7)*S3
        FS21 = hsv(i,2)*S1 + hsv(i,5)*S4 + hsv(i,8)*S6
        FS22 = hsv(i,2)*S4 + hsv(i,5)*S2 + hsv(i,8)*S5
        FS23 = hsv(i,2)*S6 + hsv(i,5)*S5 + hsv(i,8)*S3
        FS31 = hsv(i,3)*S1 + hsv(i,6)*S4 + hsv(i,9)*S6
        FS32 = hsv(i,3)*S4 + hsv(i,6)*S2 + hsv(i,9)*S5
        FS33 = hsv(i,3)*S6 + hsv(i,6)*S5 + hsv(i,9)*S3
c
c       write(59,*) 'F*S'
c       write(59,*) FS11, '  ' ,FS12,  '  ' ,FS13
c       write(59,*) FS21, '  ' ,FS22,  '  ' ,FS23
c       write(59,*) FS31, '  ' ,FS32,  '  ' ,FS33
c       write(59,*) '      '
c
        sig1(i) = 1./detF*(FS11*hsv(i,1)+FS12*hsv(i,4)+FS13*hsv(i,7))
        sig2(i) = 1./detF*(FS21*hsv(i,2)+FS22*hsv(i,5)+FS23*hsv(i,8))
        sig3(i) = 1./detF*(FS31*hsv(i,3)+FS32*hsv(i,6)+FS33*hsv(i,9))
        sig4(i) = 1./detF*(FS11*hsv(i,2)+FS12*hsv(i,5)+FS13*hsv(i,8))
        sig5(i) = 1./detF*(FS21*hsv(i,3)+FS22*hsv(i,6)+FS23*hsv(i,9))
        sig6(i) = 1./detF*(FS11*hsv(i,3)+FS12*hsv(i,6)+FS13*hsv(i,9))
c
c       write(59,*) 'Cauchy Stresses '
c       write(59,*) sig1(i), '  ' ,sig4(i),  '  ' ,sig6(i)
c       write(59,*) sig4(i), '  ' ,sig2(i),  '  ' ,sig5(i)
c       write(59,*) sig6(i), '  ' ,sig5(i),  '  ' ,sig3(i)
c       write(59,*) '      '
c
c       write(59,*) '-----------------------------'
c
      endif
   10 continue
c
      return
      end
      subroutine umat44v(cm,d1,d2,d3,d4,d5,d6,sig1,sig2,
     . sig3,sig4,sig5,sig6,eps,hsvs,lft,llt,dt1siz,capa,
     . etype,tt,temps,failels,nlqa,crv,nnpcrv,cma,qmat,elsizv,idelev,
     . reject)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c***  isotropic plasticity with linear hardening
c
c***  updates only the deviatoric stress so that it can be used with
c     an equation of state
c
      parameter (third=1.0/3.0)
      include 'nlqparm'
      include 'bk06.inc'
c
      common/eosdloc/pc(nlq)
c
      dimension cm(*),d1(*),d2(*),d3(*),d4(*),d5(*),d6(*),
     & sig1(*),sig2(*),sig3(*),sig4(*),sig5(*),sig6(*),
     & eps(*),hsvs(nlqa,*),dt1siz(*),temps(*),crv(lq1,2,*),cma(*),
     & failels(*),qmat(nlq,3,3),elsizv(*)
      integer nnpcrv(*)
      integer idelev(*)
c
      character*5 etype
      logical failels,reject
c
c$omp threadprivate (/eosdloc/)
      if (ncycle.eq.1) call usermsg('mat44')
c
c***  shear modulus, initial yield stress, hardening, and pressure cut-off
      g   =cm(1)
      sy0 =cm(2)
      h   =cm(3)
      pcut=cm(4)
c
c***  plastic strain for failure
      epsfail=cm(5)
c
      ofac=1.0/(3.0*g+h)
      twog=2.0*g
c
      do i=lft,llt
c
c***    elastic deviatoric stress
        davg=third*(d1(i)+d2(i)+d3(i))
        savg=third*(sig1(i)+sig2(i)+sig3(i))
        sig1(i)=sig1(i)-savg+twog*(d1(i)-davg)
        sig2(i)=sig2(i)-savg+twog*(d2(i)-davg)
        sig3(i)=sig3(i)-savg+twog*(d3(i)-davg)
        sig4(i)=sig4(i)+g*d4(i)
        sig5(i)=sig5(i)+g*d5(i)
        sig6(i)=sig6(i)+g*d6(i)
c
c***    radial return
        aj2=sqrt(1.5*(sig1(i)**2+sig2(i)**2+sig3(i)**2)+
     &           3.0*(sig4(i)**2+sig5(i)**2+sig6(i)**2))
        sy=sy0+h*eps(i)
        eps(i)=eps(i)+ofac*max(0.0,aj2-sy)
        synew=sy0+h*eps(i)
        scale=synew/max(synew,aj2)
c
c***    scaling for radial return
        sig1(i)=scale*sig1(i)
        sig2(i)=scale*sig2(i)
        sig3(i)=scale*sig3(i)
        sig4(i)=scale*sig4(i)
        sig5(i)=scale*sig5(i)
        sig6(i)=scale*sig6(i)
c
c***    set pressure cut-off
        pc(i)=pcut
c
c***    failure due to plastic strain
        failels(i)=eps(i).gt.epsfail
c
      enddo
c
      return
      end
      subroutine umat45v(cm,d1,d2,d3,d4,d5,d6,sig1,sig2,
     . sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,dt1siz,capa,
     . etype,tt,temps,failels,nlqa,crv,nnpcrv,cma,qmat,elsizv,idelev,ih,
     . reject)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      include 'nlqparm'
      include 'nhisparm.inc'
      include 'bk06.inc'
      common/bk36loc/index
      dimension d1(*),d2(*),d3(*),d4(*),d5(*),d6(*)
      dimension sig1(*),sig2(*),sig3(*),sig4(*),sig5(*),sig6(*)
      dimension cm(*),epsps(*),hsvs(nlq,*),dt1siz(*)
      dimension temps(*),crv(lq1,2,*),cma(*),qmat(nlq,3,3),elsizv(*)
      integer nnpcrv(*)
      integer idelev(*)
      logical failels(*),reject
      character*5 etype
c
      dimension sig(6),eps(6),hsv(NHISVAR),qmats(3,3)
c
c$omp threadprivate (/bk36loc/)
      if (ncycle.eq.1) call usermsg('mat45')
c
      do i=lft,llt
        index=i
        sig(1)=sig1(i)
        sig(2)=sig2(i)
        sig(3)=sig3(i)
        sig(4)=sig4(i)
        sig(5)=sig5(i)
        sig(6)=sig6(i)
c
        eps(1)=d1(i)
        eps(2)=d2(i)
        eps(3)=d3(i)
        eps(4)=d4(i)
        eps(5)=d5(i)
        eps(6)=d6(i)
c
        hsv(1)=hsvs(i,1)
        hsv(2)=hsvs(i,2)
        hsv(3)=hsvs(i,3)
        hsv(4)=hsvs(i,4)
        hsv(5)=hsvs(i,5)
        hsv(6)=hsvs(i,6)
        hsv(7)=hsvs(i,7)
        hsv(8)=hsvs(i,8)
        hsv(9)=hsvs(i,9)
c
        if (iabs(ih).eq.3) then
           hsv(10)=hsvs(i,10)
           hsv(11)=hsvs(i,11)
           hsv(12)=hsvs(i,12)
           hsv(13)=hsvs(i,13)
           do k=1,3
              do j=1,3
                 qmats(j,k)=qmat(i,j,k)
              enddo
           enddo
        endif
c
        call umat45(cm,eps,sig,epsps(i),hsv,dt1siz(i),capa,etype,tt,
     1  temps(i),failels(i),crv,nnpcrv,cma,qmats,elsizv(i),idelev(i),ih,
     2  reject)
c
        sig1(i)=sig(1)
        sig2(i)=sig(2)
        sig3(i)=sig(3)
        sig4(i)=sig(4)
        sig5(i)=sig(5)
        sig6(i)=sig(6)
c
        hsvs(i,1)=hsv(1)
        hsvs(i,2)=hsv(2)
        hsvs(i,3)=hsv(3)
        hsvs(i,4)=hsv(4)
        hsvs(i,5)=hsv(5)
        hsvs(i,6)=hsv(6)
        hsvs(i,7)=hsv(7)
        hsvs(i,8)=hsv(8)
        hsvs(i,9)=hsv(9)
        d3(i)=eps(3)
c
        if (iabs(ih).eq.3) then
           hsvs(i,10)=hsv(10)
           hsvs(i,11)=hsv(11)
           hsvs(i,12)=hsv(12)
           hsvs(i,13)=hsv(13)
        endif
      enddo
c
      return
      end
      subroutine umat46v(cm,d1,d2,d3,d4,d5,d6,sig1,sig2,
     . sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,dt1siz,capa,
     . etype,tt,temps,failels,nlqa,crv,nnpcrv,
     . cma,thhsv,nthhsv,qmat,elsizv,
     . idelev,reject)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      include 'nlqparm'
      include 'nhisparm.inc'
      include 'bk06.inc'
      dimension d1(*),d2(*),d3(*),d4(*),d5(*),d6(*)
      dimension sig1(*),sig2(*),sig3(*),sig4(*),sig5(*),sig6(*)
      dimension cm(*),epsps(*),hsvs(nlq,*),dt1siz(*),thhsv(nlq,*)
      dimension temps(*),crv(lq1,2,*),cma(*),qmat(nlq,3,3),elsizv(*)
      integer nnpcrv(*)
      integer idelev(*)
      logical failels(*),reject
      character*5 etype
c
c     For more information see comments in subroutine umat46.
c
c     nthhsv=Number of thermal history variables.
c     thhsv=If IHVE.eq.1 on *MAT_THERMAL_USER_DEFINED then
c           thhsvi(i,j) j=1...nthhsv, i=1...nlq, contains history
c           variable data from thermal user material routine
c           interpolated to current integration point using
c           shape functions for the corresponding thermal element.
c
      dimension sig(6),eps(6),hsv(NHISVAR),thhsvi(100)
c
      if (ncycle.eq.1) call usermsg('mat46')
c
      do i=lft,llt
        sig(1)=sig1(i)
        sig(2)=sig2(i)
        sig(3)=sig3(i)
        sig(4)=sig4(i)
        sig(5)=sig5(i)
        sig(6)=sig6(i)
        eps(1)=d1(i)
        eps(2)=d2(i)
        eps(3)=d3(i)
        eps(4)=d4(i)
        eps(5)=d5(i)
        eps(6)=d6(i)
c
        do j=1,nthhsv
          thhsvi(j)=thhsv(i,j)
        enddo
c
        call umat46(cm,eps,sig,epsps(i),hsv,dt1siz(i),capa,etype,tt,
     1   temps(i),failels(i),crv,nnpcrv,cma,thhsvi,nthhsv,0,elsizv(i),
     2   idelev(i),reject)
c
        do j=1,nthhsv
          thhsv(i,j)=thhsvi(j)
        enddo
c
        sig1(i)=sig(1)
        sig2(i)=sig(2)
        sig3(i)=sig(3)
        sig4(i)=sig(4)
        sig5(i)=sig(5)
        sig6(i)=sig(6)
        d3(i)=eps(3)
      enddo
c
      return
      end
      subroutine umat47v(cm,d1,d2,d3,d4,d5,d6,sig1,sig2,
     . sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,dt1siz,capa,
     . etype,tt,temps,failels,nlqa,crv,nnpcrv,cma,qmat,elsizv,idelev,
     . reject)
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
      dimension d1(*),d2(*),d3(*),d4(*),d5(*),d6(*)
      dimension sig1(*),sig2(*),sig3(*),sig4(*),sig5(*),sig6(*)
      dimension cm(*),epsps(*),hsvs(nlq,*),dt1siz(*)
      dimension temps(*),crv(lq1,2,*),cma(*),qmat(nlq,3,3),elsizv(*)
      integer nnpcrv(*)
      integer idelev(*)
      logical failels(*),reject
      character*5 etype
c
      if (ncycle.eq.1) call usermsg('mat47')
c
c     Test for *USER_NONLOCAL, replace with your own code
      call umat47v_test(cm,d1,d2,d3,d4,d5,d6,sig1,sig2, sig3,sig4,sig5
     $     ,sig6,epsps,hsvs,lft,llt,dt1siz,capa, etype,tt,temps,failels
     $     ,nlqa,crv,nnpcrv,cma,qmat,elsizv,idelev, reject)
c
      return
      end
      subroutine umat48v(cm,d1,d2,d3,d4,d5,d6,sig1,sig2,
     . sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,dt1siz,capa,
     . etype,tt,temps,failels,nlqa,crv,nnpcrv,cma,qmat,elsizv,idelev,
     . reject,ipt,npc,plc)
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
      dimension d1(*),d2(*),d3(*),d4(*),d5(*),d6(*)
      dimension sig1(*),sig2(*),sig3(*),sig4(*),sig5(*),sig6(*)
      dimension cm(*),epsps(*),hsvs(nlq,*),dt1siz(*)
      dimension temps(*),crv(lq1,2,*),cma(*),qmat(nlq,3,3),elsizv(*)
      integer nnpcrv(*)
      integer idelev(*)
      logical failels(*),reject
      character*5 etype
      dimension npc(*),plc(*)
c
      if (ncycle.eq.1) call usermsg('mat48')
c
c     Replace with your own code
      call umat48v_test(cm,d1,d2,d3,d4,d5,d6,sig1,sig2,sig3,sig4,
     . sig5,sig6,hsvs,hsvs,lft,llt,dt1siz,capa,etype,tt,
     . ipt,npc,plc,cma,qmat,elsizv,idelev,reject)

      return
      end
      subroutine umat49v(cm,d1,d2,d3,d4,d5,d6,sig1,sig2,
     . sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,dt1siz,capa,
     . etype,tt,temps,failels,nlqa,crv,nnpcrv,cma,qmat,elsizv,idelev,
     . reject,ipt,npc,plc)
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
      dimension d1(*),d2(*),d3(*),d4(*),d5(*),d6(*)
      dimension sig1(*),sig2(*),sig3(*),sig4(*),sig5(*),sig6(*)
      dimension cm(*),epsps(*),hsvs(nlq,*),dt1siz(*)
      dimension temps(*),crv(lq1,2,*),cma(*),qmat(nlq,3,3),elsizv(*)
      integer nnpcrv(*)
      integer idelev(*)
      logical failels(*),reject
      character*5 etype
      dimension npc(*),plc(*)
c
      if (ncycle.eq.1) call usermsg('mat49')
c
c     Replace with your own code
      call umat49v_test(cm,d1,d2,d3,d4,d5,d6,sig1,sig2,
     . sig3,sig4,sig5,sig6,epsp,hisv,lft,llt,dt1siz,capa,etype,tt,ipt,
     . temps,cma,qmat,elsizv,idelev,reject)

      return
      end
      subroutine umat50v(cm,d1,d2,d3,d4,d5,d6,sig1,sig2,
     . sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,dt1siz,capa,
     . etype,tt,temps,failels,nlqa,crv,nnpcrv,cma,qmat,elsizv,idelev,
     . reject)
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
      dimension d1(*),d2(*),d3(*),d4(*),d5(*),d6(*)
      dimension sig1(*),sig2(*),sig3(*),sig4(*),sig5(*),sig6(*)
      dimension cm(*),epsps(*),hsvs(nlq,*),dt1siz(*)
      dimension temps(*),crv(lq1,2,*),cma(*),qmat(nlq,3,3),elsizv(*)
      integer nnpcrv(*)
      integer idelev(*)
      logical failels(*),reject
      character*5 etype
c
      if (ncycle.eq.1) call usermsg('mat50')
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
      subroutine umat47v_test(cm,d1,d2,d3,d4,d5,d6,sig1,sig2, sig3,sig4
     $     ,sig5,sig6,epsps,hsvs,lft,llt,dt1siz,capa, etype,tt,temps
     $     ,failels,nlqa,crv,nnpcrv,cma,qmat,elsizv,idelev, reject)
      use userinterface
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
      dimension d1(*),d2(*),d3(*),d4(*),d5(*),d6(*)
      dimension sig1(*),sig2(*),sig3(*),sig4(*),sig5(*),sig6(*)
      dimension cm(*),epsps(*),hsvs(nlq,*),dt1siz(*)
      dimension temps(*),crv(lq1,2,*),cma(*),qmat(nlq,3,3),elsizv(*)
      integer nnpcrv(*)
      integer idelev(*)
      logical failels(*),reject
      character*5 etype

      common/aux33loc/ix1(nlq),ix2(nlq),ix3(nlq),ix4(nlq),ix5(nlq),
     1 ix6(nlq),ix7(nlq),ix8(nlq),mxt(nlq)
      real*8, pointer,contiguous :: dm_x(:)
      dimension x(8),y(8),z(8)

c     Test for *USER_NONLOCAL
c$omp threadprivate (/aux33loc/)
      call getreal8ptr('dm_x',dm_x)      
      if (ncycle.eq.0) then
         do i=lft,llt
            x(1) = dm_x(3*(ix1(i)-1)+1)
            x(2) = dm_x(3*(ix2(i)-1)+1)
            x(3) = dm_x(3*(ix3(i)-1)+1)
            x(4) = dm_x(3*(ix4(i)-1)+1)
            x(5) = dm_x(3*(ix5(i)-1)+1)
            x(6) = dm_x(3*(ix6(i)-1)+1)
            x(7) = dm_x(3*(ix7(i)-1)+1)
            x(8) = dm_x(3*(ix8(i)-1)+1)
            y(1) = dm_x(3*(ix1(i)-1)+2)
            y(2) = dm_x(3*(ix2(i)-1)+2)
            y(3) = dm_x(3*(ix3(i)-1)+2)
            y(4) = dm_x(3*(ix4(i)-1)+2)
            y(5) = dm_x(3*(ix5(i)-1)+2)
            y(6) = dm_x(3*(ix6(i)-1)+2)
            y(7) = dm_x(3*(ix7(i)-1)+2)
            y(8) = dm_x(3*(ix8(i)-1)+2)
            z(1) = dm_x(3*(ix1(i)-1)+3)
            z(2) = dm_x(3*(ix2(i)-1)+3)
            z(3) = dm_x(3*(ix3(i)-1)+3)
            z(4) = dm_x(3*(ix4(i)-1)+3)
            z(5) = dm_x(3*(ix5(i)-1)+3)
            z(6) = dm_x(3*(ix6(i)-1)+3)
            z(7) = dm_x(3*(ix7(i)-1)+3)
            z(8) = dm_x(3*(ix8(i)-1)+3)            
c           Midpoint x-distance
            hsvs(i,1) = sum(x)/8.
c           Midpoint y-distance
            hsvs(i,2) = sum(y)/8.
c           Midpoint z-distance
            hsvs(i,3) = sum(z)/8.
c            write(59,*) 'Element',idelev(i)
c            write(59,*) 'Material HSVs'
c            write(59,*) hsvs(i,1:3)
c            write(59,*) '---------------------------------'

         enddo
      endif

      return
      end
      subroutine usrshl_updatfv(f,t,s,e,lft,llt)
      implicit none
      include 'nlqparm'
      real f(nlq,3,3),t(nlq,4),s(nlq,4),e(nlq)
      integer lft,llt
      integer i,j
      real q
      do i=lft,llt
         e(i)=min(1.9999,e(i))
         q=(1.+.5*e(i))/(1.-.5*e(i))
         do j=1,4
            s(i,j)=max(t(i,j)*q,1.e-20)
         enddo
      enddo
      call usrshl_defgrad(f,3,
     1     0.,0.,0.,
     2     0.d0,0.d0,
     3     0.,s,
     4     s,
     5     lft,llt)
      return
      end
