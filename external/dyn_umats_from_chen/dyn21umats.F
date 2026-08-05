# 1 "dyn21umats.F"
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





# 2 "dyn21umats.F" 2 
# 1 ".\define2.inc" 1 



# 3 "dyn21umats.F" 2 
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
c        eq."shl2d" for shell forms 12 (2D solids - plane stress)
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
c       6th field of 2nd card of *DATA_USER_DEFINED
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
      integer idele
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
c
      if (etype.eq.'solid'.or.etype.eq.'shl_t'.or.
     1     etype.eq.'sld2d'.or.etype.eq.'tshel'.or.
     2     etype.eq.'sph  '.or.etype.eq.'sldax'.or.
     3     etype.eq.'sldco') then
        if (cm(16).eq.1234567) then
          call mitfail3d(cm,eps,sig,epsp,hsv,dt1,capa,failel,tt,crv)
        else
          if (.not.failel) then
          davg=(-eps(1)-eps(2)-eps(3))/3.
          p=-davg*abs(cm(1))/(1.-2.*cm(2))
          sig(1)=sig(1)+p+g2*(eps(1)+davg)
          sig(2)=sig(2)+p+g2*(eps(2)+davg)
          sig(3)=sig(3)+p+g2*(eps(3)+davg)
          sig(4)=sig(4)+g*eps(4)
          sig(5)=sig(5)+g*eps(5)
          sig(6)=sig(6)+g*eps(6)
          if (cm(1).lt.0.) then
            if (sig(1).gt.cm(5)) failel=.true.
          endif
          endif
        end if
c
      else if (etype.eq.'shell'.or.etype.eq.'shl2d') then
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
c       call adios(2)
        cerdat(1)=etype
        call lsmsg(3,MSG_SOL+1150,ioall,ierdat,rerdat,cerdat,0)
      endif
c
c10   format(/
c    1 ' *** Error element type ',a,' can not be',
c    2 '           run with the current material model.')
      return
      end

      subroutine umat42 (cm,eps,sig,epsp,hsv,dt1,capa,etype,tt,
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
      integer idele
c
      if (ncycle.eq.1) then
        call usermsg('mat42')
      endif

c     Replace with your own code
      call umat42_test (cm,eps,sig,epsp,hsv,dt1,capa,etype,tt,
     1 temper,failel,crv,nnpcrv,cma,qmat,elsiz,idele,reject)

      return
      end

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
      include 'nlqparm'
      include 'bk06.inc'
      include 'iounits.inc'
      dimension cm(*),eps(*),sig(*),hsv(*),crv(lq1,2,*),cma(*),qmat(3,3)
      integer nnpcrv(*)
      character*5 etype
      logical failel,reject
      integer idele
c     Intermedia variables
      integer i,j,k,l,ii,jj
c     Solid element variables
      double precision g,g2,gc,q1,q3,davg,p,deti,c22i,c23i,fac
      double precision temper,elsiz,epsp,capa,tt
c     Euler angles
      integer typeUmat
c
c      if (ncycle.eq.1) then
c        call usermsg('mat43')
c      endif
c     
!============================================================
c
      typeUmat=cm(9)
      if (.not.failel) then
            if(typeUmat.eq.0)then
                  call umatCpPh(cm,eps,sig,
     1     epsp,hsv,dt1,capa,etype,tt,temper,failel,crv,
     2   nnpcrv,cma,qmat,elsiz,idele,reject)
            else if(typeUmat.eq.1)then
                  call umatCpHama(cm,eps,sig,
     1     epsp,hsv,dt1,capa,etype,tt,temper,failel,crv,
     2   nnpcrv,cma,qmat,elsiz,idele,reject)
            endif
      endif
      return
      end

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
      integer idele
c
c
C      if (ncycle.eq.1) then
C        call usermsg('mat44')
C      endif

      call umatSubroutineFccImplicit(cm,eps,sig,epsp,hsv,dt1,
     1   capa,etype,tt,temper,failel,crv,nnpcrv,cma,qmat,
     2   elsiz,idele,reject)
c
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
c        eq."sldco" for solid form 62 (corotational element)
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
c       6th field of 2nd card of *DATA_USER_DEFINED
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
      integer idele
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
c       call adios(2)
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
      integer idele
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
      else if (etype.eq.'shell'.or.etype.eq.'shl2d') then
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
c       call adios(2)
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
      integer idele
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
      integer idele
c
      if (ncycle.eq.1) then
        call usermsg('mat48')
      endif
c
      return
      end


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
      integer idele
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
      integer idele
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
      integer index
      common/bk36loc/index
      real fs(3,3),ts(4),ss(4),es
      real f(nlq,3,3),t(nlq,4),s(nlq,4),e(nlq)
      integer i,j
c$omp threadprivate (/bk36loc/)
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
