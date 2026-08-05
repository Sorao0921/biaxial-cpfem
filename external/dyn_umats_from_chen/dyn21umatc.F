# 1 "dyn21umatc.F"
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





# 2 "dyn21umatc.F" 2 
      subroutine umatc(mte,idpart,cm,lft,llt,sig,dx,dxdt,aux,ek,
     & iffail,dt1siz,crv,nnpcrv,nhxbwp,cma,maketan,dsave,ctmp,elsiz,
     & reject,ip,nip,nmtcon,iop,cohthk)
# 8

c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      include 'nlqparm'
      include 'umatss.inc'
c
c     dx(nlq,3)   - components of displacements (in element system)
c     dxdt(nlq,3) - rates of displacements (in element system)
c     sig(nlq,3)  - components of cohesive force
c
      logical iffail,maketan,reject
      dimension cm(*),sig(nlq,*),dx(nlq,*),dxdt(nlq,*),aux(nlq,*),
     . ek(*),iffail(*),
     & dt1siz(*),crv(*),nhxbwp(*),cma(*),dsave(*),ctmp(*),elsiz(*)
      integer nnpcrv(*)
      integer idpart
c
      integer no_hsvs
c
      if (iop.ge.19.and.iop.le.22.and.iorien(mte).ne.0) then
c       nmtcon includes stresses+epsp (7 values)
        no_hsvs = nmtcon -7
c       additional histvars used for element types
        if(iop.eq.19.or.iop.eq.21) no_hsvs=no_hsvs-3
        if(iop.eq.20.or.iop.eq.22) no_hsvs=no_hsvs-6
c       6 histvars used if IORTHO=1 (q11,...,q33)
        no_hsvs=no_hsvs-6
c       have to shift by 2 as we get pointer to aux(7)
        ind_ortho=2+no_hsvs
        ind_q1=ind_ortho
        ind_q2=ind_ortho+1
c       ind_q13=ind_ortho+2
c       ind_q31=ind_ortho+3
c       ind_q32=ind_ortho+4
c       ind_q33=ind_ortho+5
c       ind_last=ind_q33
        do i=lft,llt
          q1 = aux(i,ind_q1)
          q2 = aux(i,ind_q2)
c         forces
          f1 = sig(i,1)
          f2 = sig(i,2)
          sig(i,1)= q1*f1+q2*f2
          sig(i,2)=-q2*f1+q1*f2
c         displacements
          u1 = dx(i,1)
          u2 = dx(i,2)
          dx(i,1)= q1*u1+q2*u2
          dx(i,2)=-q2*u1+q1*u2
c         displacement rates
          u1 = dxdt(i,1)
          u2 = dxdt(i,2)
          dxdt(i,1)= q1*u1+q2*u2
          dxdt(i,2)=-q2*u1+q1*u2
        enddo
      endif
c
      if (mte.eq.41) then
        call umat41c(idpart,cm,lft,llt,sig,dx,dxdt,aux,ek,iffail,
     .   dt1siz,crv,nnpcrv,nhxbwp,cma,maketan,dsave,ctmp,elsiz,
     .   reject,ip,nip)
      elseif (mte.eq.42) then
        call umat42c(idpart,cm,lft,llt,sig,dx,dxdt,aux,ek,iffail,
     .   dt1siz,crv,nnpcrv,nhxbwp,cma,maketan,dsave,ctmp,elsiz,
     .   reject,ip,nip)
      elseif (mte.eq.43) then
        call umat43c(idpart,cm,lft,llt,sig,dx,dxdt,aux,ek,iffail,
     .   dt1siz,crv,nnpcrv,nhxbwp,cma,maketan,dsave,ctmp,elsiz,
     .   reject,ip,nip)
      elseif (mte.eq.44) then
        call umat44c(idpart,cm,lft,llt,sig,dx,dxdt,aux,ek,iffail,
     .   dt1siz,crv,nnpcrv,nhxbwp,cma,maketan,dsave,ctmp,elsiz,
     .   reject,ip,nip)
      elseif (mte.eq.45) then
        call umat45c(idpart,cm,lft,llt,sig,dx,dxdt,aux,ek,iffail,
     .   dt1siz,crv,nnpcrv,nhxbwp,cma,maketan,dsave,ctmp,elsiz,
     .   reject,ip,nip)
      elseif (mte.eq.46) then
        call umat46c(idpart,cm,lft,llt,sig,dx,dxdt,aux,ek,iffail,
     .   dt1siz,crv,nnpcrv,nhxbwp,cma,maketan,dsave,ctmp,elsiz,
     .   reject,ip,nip)
      elseif (mte.eq.47) then
        call umat47c(idpart,cm,lft,llt,sig,dx,dxdt,aux,ek,iffail,
     .   dt1siz,crv,nnpcrv,nhxbwp,cma,maketan,dsave,ctmp,elsiz,
     .   reject,ip,nip)
      elseif (mte.eq.48) then
        call umat48c(idpart,cm,lft,llt,sig,dx,dxdt,aux,ek,iffail,
     .   dt1siz,crv,nnpcrv,nhxbwp,cma,maketan,dsave,ctmp,elsiz,
     .   reject,ip,nip)
      elseif (mte.eq.49) then
        call umat49c(idpart,cm,lft,llt,sig,dx,dxdt,aux,ek,iffail,
     .   dt1siz,crv,nnpcrv,nhxbwp,cma,maketan,dsave,ctmp,elsiz,
     .   reject,ip,nip)
      elseif (mte.eq.50) then
        call umat50c(idpart,cm,lft,llt,sig,dx,dxdt,aux,ek,iffail,
     .   dt1siz,crv,nnpcrv,nhxbwp,cma,maketan,dsave,ctmp,elsiz,
     .   reject,ip,nip)
      endif
c
c     transform back
      if (iop.ge.19.and.iop.le.22.and.iorien(mte).ne.0) then
        do i=lft,llt
          q1 = aux(i,ind_q1)
          q2 = aux(i,ind_q2)
c         forces
          f1 = sig(i,1)
          f2 = sig(i,2)
          sig(i,1)= q1*f1-q2*f2
          sig(i,2)= q2*f1+q1*f2
        enddo
      endif
c
      return
      end
c
      subroutine umat41c(idpart,cm,lft,llt,fc,dx,dxdt,aux,ek,
     & ifail,dt1siz,crv,nnpcrv,nhxbwp,cma,maketan,dsave,ctmp,elsiz,
     & reject,ip,nip)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     vectorized cohesive material user model example
c
c***  variables
c          idpart ---- part ID
c          cm -------- material constants
c          lft,llt --- start and end of block
c          fc -------- components of the cohesive force
c          dx -------- components of the displacement
c          dxdt ------ components of the velocity
c          aux ------- history storage
c                      in LS-Prepost: aux(i,1)=effective plastic strain,
c                                     aux(i,2)=history var#1,
c                                     aux(i,3)=history var#2, ...
c          ek -------- max. stiffness/area for time step calculation
c          ifail ----- =.false. not failed
c                      =.true. failed
c          dt1siz ---- time step size
c          crv ------- curve array
c          nnpcrv ---- # points per curve for crv array
c          nhxbwp ---- internal element id array, lqfinv(nhxbwp(i),2)
c                      gives external element id
c          cma ------- additional memory for material data defined by
c                      LMCA in 2nd card, 6th field of *MAT_USER_DEFINED
c          maketan --- true for implicit
c          dsave ----- material stiffness array, define for implicit
c          ctmp ------ current temperature
c          elsiz ----- characteristic element size (=sqrt(area))
c          reject ---- set to .true. if this implicit iterate is
c                      to be rejected for some reason (implicit only)
c          ip -------- integration point number
c          nip ------- total number of integration points
c
c***  dx, dxdt, and fc are in the local coordinate system:
c     components 1 and 2 are in the plane of the cohesive surface
c     component 3 is normal to the plane
c
c***  cm storage convention
c     (1) =0 density is per area
c         =1 density is per volume
c     (2) number of integration points for element deletion
c         =0 no deletion
c     (3:48) material model constants
c
      include 'nlqparm'
      logical ifail,maketan,reject
      dimension cm(*),fc(nlq,*),dx(nlq,*),dxdt(nlq,*),
     & aux(nlq,*),ek(*),ifail(*),dt1siz(*),crv(lq1,2,*),
     & nhxbwp(*),cma(*),dsave(nlq,6,*),ctmp(*),elsiz(*)
      integer nnpcrv(*)
      integer idpart
c
      et=cm(3)
      en=cm(4)
      eki=max(et,en)
      fcfail=cm(5)
c
      do i=lft,llt
        fc(i,1)=et*dx(i,1)
        fc(i,2)=et*dx(i,2)
        fc(i,3)=en*dx(i,3)
        ek(i)=eki
        ifail(i)=fc(i,3).gt.fcfail
      enddo
c
      if(maketan) then
        do i=lft,llt
          dsave(i,1,1)=et
          dsave(i,2,1)=0.
          dsave(i,3,1)=0.
          dsave(i,1,2)=0.
          dsave(i,2,2)=et
          dsave(i,3,2)=0.
          dsave(i,1,3)=0.
          dsave(i,2,3)=0.
          dsave(i,3,3)=en
        enddo
      endif
      return
      end
      subroutine umat42c(idpart,params,lft,llt,fTraction,jump_u,dxdt,
     & aux,ek,ifail,dt1siz,crv,nnpcrv,nhxbwp,cma,maketan,dsave,ctmp,
     & elsiz,reject,ip,nip)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     vectorized cohesive material user model example
c
c***  variables
c          idpart ---- part ID
c          params ---- material constants
c          lft,llt --- start and end of block
c          fTraction - components of the cohesive force
c          jump_u ---- components of the displacement
c          dxdt ------ components of the velocity
c          aux ------- history storage
c          ek -------- max. stiffness/area for time step calculation
c          ifail ----- =.false. not failed
c                      =.true. failed
c          dt1siz ---- time step size
c          crv ------- curve array
c          nnpcrv ---- # points per curve for crv array
c          nhxbwp ---- internal element id array, lqfinv(nhxbwp(i),2)
c                      gives external element id
c          cma ------- additional memory for material data defined by
c                      LMCA in 2nd card, 6th field of *MAT_USER_DEFINED
c          maketan --- true for implicit
c          dsave ----- material stiffness array, define for implicit
c          ctmp ------ current temperature
c          elsiz ----- characteristic element size (=sqrt(area))
c          reject ---- set to .true. if this implicit iterate is
c                      to be rejected for some reason (implicit only)
c          ip -------- integration point number
c          nip ------- total number of integration points
c
c***  jump_u, dxdt, and fTraction are in the local coordinate system:
c     components 1 and 2 are in the plane of the cohesive surface
c     component 3 is normal to the plane
c
c***  cm storage convention
c     (1) =0 density is per area
c         =1 density is per volume
c     (2) number of integration points for element deletion
c         =0 no deletion
c     (3:48) material model constants
c
c     Tvergaard-Hutchinson model based on:
c     tahoe/src/elements/cohesive_surface/cohesive_models/TvergHutch3DT.cpp
c     the declaration below is processed by the C preprocessor and
c     is real*4 or real*8 depending on whether LS-DYNA is single or double
c     precision
c
      include 'nlqparm'
      real L,jump_u
      logical ifail,maketan,reject
      dimension params(*),fTraction(nlq,*),jump_u(nlq,*),
     &  dxdt(nlq,*),aux(nlq,*),ek(*),ifail(*),dt1siz(*),
     &  crv(lq1,2,*),nhxbwp(*),cma(*),dsave(nlq,6,*),ctmp(*),elsiz(*)
      integer nnpcrv(*)
      integer idpart
c
      fsigma_max=params(3)
      fd_c_n=params(4)
      fd_c_t=params(5)
      fL_1=params(6)
      fL_2=params(7)
      fdist=params(8)
      fpenalty=params(9)
      fL_1=fL_1/fdist
      fL_2=fL_2/fdist
      fK=fpenalty*fsigma_max/(fL_1*fd_c_n)
      fac=min(fd_c_n/fd_c_t**2,1./fd_c_n)
      do i=lft,llt
      u_t1 = jump_u(i,1)
      u_t2 = jump_u(i,2)
      u_n = jump_u(i,3)
      r_t1 = u_t1/fd_c_t
      r_t2 = u_t2/fd_c_t
      r_n = u_n/fd_c_n
      L = sqrt(r_t1*r_t1 + r_t2*r_t2 + r_n*r_n)
      if (L .lt. fL_1) then
         sigbyL=fsigma_max/fL_1
      else if (L .lt. fL_2) then
         sigbyL = fsigma_max/L
      else if (L .lt. 1.) then
         sigbyL = fsigma_max*(1. - L)/(1. - fL_2)/L
      else
         sigbyL = 0.0
         ifail(i)=.true.
      endif
      fTraction(i,1) = sigbyL*r_t1*(fd_c_n/fd_c_t)
      fTraction(i,2) = sigbyL*r_t2*(fd_c_n/fd_c_t)
      fTraction(i,3) = sigbyL*r_n
c     penetration
      if (u_n .lt. 0) fTraction(i,3)=fTraction(i,3)+fK*u_n
c     approximate stiffness for timestep
      if (u_n .lt. 0) then
        ek(i)=fac*sigbyL+fK
      else
        ek(i)=fac*sigbyL
      endif
      if (maketan) then
        dsave(i,1,1)=sigbyL/fd_c_t*(fd_c_n/fd_c_t)
        dsave(i,2,1)=0.
        dsave(i,3,1)=0.
        dsave(i,1,2)=0.
        dsave(i,2,2)=sigbyL/fd_c_t*(fd_c_n/fd_c_t)
        dsave(i,3,2)=0.
        dsave(i,1,3)=0.
        dsave(i,2,3)=0.
        dsave(i,3,3)=sigbyL/fd_c_n
        if (u_n.lt.0) dsave(i,3,3)=dsave(i,3,3)+fk
      endif
      enddo
      return
      end
      subroutine umat43c(idpart,params,lft,llt,fTraction,jump_u,dxdt,
     & aux,ek,ifail,dt1siz,crv,nnpcrv,nhxbwp,cma,maketan,dsave,ctmp,
     & elsiz,reject,ip,nip)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     scalar cohesive material user model example
c
c***  variables
c          idpart ---- part ID
c          params ---- material constants
c          lft,llt --- start and end of block
c                      will be set to 0 and 0 for scalar
c          fTraction - components of the cohesive force
c          jump_u ---- components of the displacement
c          dxdt ------ components of the velocity
c          aux ------- history storage
c          ek -------- max. stiffness/area for time step calculation
c          ifail ----- =.false. not failed
c                      =.true. failed
c          dt1siz ---- time step size
c          crv ------- curve array
c          nnpcrv ---- # points per curve for crv array
c          nhxbwp ---- internal element id array, lqfinv(nhxbwp(i),2)
c                      gives external element id
c          cma ------- additional memory for material data defined by
c                      LMCA in 2nd card, 6th field of *MAT_USER_DEFINED
c          maketan --- true for implicit
c          dsave ----- material stiffness array, define for implicit
c          ctmp ------ current temperature
c          elsiz ----- characteristic element size (=sqrt(area))
c          reject ---- set to .true. if this implicit iterate is
c                      to be rejected for some reason (implicit only)
c          ip -------- integration point number
c          nip ------- total number of integration points
c
c***  jump_u, dxdt, and fTraction are in the local coordinate system:
c     components 1 and 2 are in the plane of the cohesive surface
c     component 3 is normal to the plane
c
c***  cm storage convention
c     (1) =0 density is per area
c         =1 density is per volume
c     (2) number of integration points for element deletion
c         =0 no deletion
c     (3:48) material model constants
c
c     Tveergard-Hutchinson model based on:
c     tahoe/src/elements/cohesive_surface/cohesive_models/TvergHutch3DT.cpp
c     the declaration below is processed by the C preprocessor and
c     is real*4 or real*8 depending on whether LS-DYNA is single or double
c     precision
c
      include 'nlqparm'
      real L,jump_u
      logical ifail,maketan,reject
      dimension params(*),fTraction(*),jump_u(*),
     &  dxdt(*),aux(*),crv(lq1,2,*),nhxbwp(*),cma(*),dsave(6,*),
     &  ctmp(*),elsiz(*)
      integer nnpcrv(*)
      integer idpart
c
      fsigma_max=params(3)
      fd_c_n=params(4)
      fd_c_t=params(5)
      fL_1=params(6)
      fL_2=params(7)
      fdist=params(8)
      fpenalty=params(9)
      fL_1=fL_1/fdist
      fL_2=fL_2/fdist
      fK=fpenalty*fsigma_max/(fL_1*fd_c_n)
      fac=min(fd_c_n/fd_c_t**2,1./fd_c_n)
      u_t1 = jump_u(1)
      u_t2 = jump_u(2)
      u_n = jump_u(3)
      r_t1 = u_t1/fd_c_t
      r_t2 = u_t2/fd_c_t
      r_n = u_n/fd_c_n
      L = sqrt(r_t1*r_t1 + r_t2*r_t2 + r_n*r_n)
      if (L .lt. fL_1) then
         sigbyL=fsigma_max/fL_1
      else if (L .lt. fL_2) then
         sigbyL = fsigma_max/L
      else if (L .lt. 1.) then
         sigbyL = fsigma_max*(1. - L)/(1. - fL_2)/L
      else
         sigbyL = 0.0
         ifail=.true.
      endif
      fTraction(1) = sigbyL*r_t1*(fd_c_n/fd_c_t)
      fTraction(2) = sigbyL*r_t2*(fd_c_n/fd_c_t)
      fTraction(3) = sigbyL*r_n
c     penetration
      if (u_n .lt. 0) fTraction(3)=fTraction(3)+fK*u_n
c     approximate stiffness for timestep
      if (u_n .lt. 0) then
        ek=fac*sigbyL+fK
      else
        ek=fac*sigbyL
      endif
      if (maketan) then
        dsave(1,1)=sigbyL/fd_c_t*(fd_c_n/fd_c_t)
        dsave(2,1)=0.
        dsave(3,1)=0.
        dsave(1,2)=0.
        dsave(2,2)=sigbyL/fd_c_t*(fd_c_n/fd_c_t)
        dsave(3,2)=0.
        dsave(1,3)=0.
        dsave(2,3)=0.
        dsave(3,3)=sigbyL/fd_c_n
        if (u_n.lt.0) dsave(3,3)=dsave(3,3)+fk
      endif
      return
      end
      subroutine umat44c(idpart,cm,lft,llt,fc,dx,dxdt,aux,ek,
     & ifail,dt1siz,crv,nnpcrv,nhxbwp,cma,maketan,dsave,ctmp,elsiz,
     & reject,ip,nip)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      include 'nlqparm'
      include 'iounits.inc'
      logical ifail,maketan,reject
      dimension cm(*),fc(nlq,*),dx(nlq,*),dxdt(nlq,*),
     &  aux(nlq,*),ek(*),ifail(*),dt1siz(*),crv(lq1,2,*),
     &  nhxbwp(*),cma(*),dsave(nlq,6,*),ctmp(*),elsiz(*)
      integer nnpcrv(*)
      integer idpart
c
c     write(iotty,1000) idpart
c     write(iohsp,1000) idpart
c     write(iomsg,1000) idpart
c     call adios(2)
      ierdat(1)=44
      ierdat(2)=idpart
      call lsmsg(3,MSG_SOL+1348,ioall,ierdat,rerdat,cerdat,0)
c
c1000 format(/' **** Error umat44c not implemented for part ',i10)
c
      return
      end
      subroutine umat45c(idpart,cm,lft,llt,fc,dx,dxdt,aux,ek,
     & ifail,dt1siz,crv,nnpcrv,nhxbwp,cma,maketan,dsave,ctmp,elsiz,
     & reject,ip,nip)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      include 'nlqparm'
      include 'iounits.inc'
      logical ifail,maketan,reject
      dimension cm(*),fc(nlq,*),dx(nlq,*),dxdt(nlq,*),
     & aux(nlq,*),ek(*),ifail(*),dt1siz(*),crv(lq1,2,*),
     & nhxbwp(*),cma(*),dsave(nlq,6,*),ctmp(*),elsiz(*)
      integer nnpcrv(*)
      integer idpart
c
c     write(iotty,1000) idpart
c     write(iohsp,1000) idpart
c     write(iomsg,1000) idpart
c     call adios(2)
      ierdat(1)=45
      ierdat(2)=idpart
      call lsmsg(3,MSG_SOL+1348,ioall,ierdat,rerdat,cerdat,0)
c
c1000 format(/' *** Error umat45c not implemented for part ',i10)
c
      return
      end
      subroutine umat46c(idpart,cm,lft,llt,fc,dx,dxdt,aux,ek,
     & ifail,dt1siz,crv,nnpcrv,nhxbwp,cma,maketan,dsave,ctmp,elsiz,
     & reject,ip,nip)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      include 'nlqparm'
      include 'iounits.inc'
      logical ifail,maketan,reject
      dimension cm(*),fc(nlq,*),dx(nlq,*),dxdt(nlq,*),
     &  aux(nlq,*),ek(*),ifail(*),dt1siz(*),crv(lq1,2,*),
     &  nhxbwp(*),cma(*),dsave(nlq,6,*),ctmp(*),elsiz(*)
      integer nnpcrv(*)
      integer idpart
c
c     write(iotty,1000) idpart
c     write(iohsp,1000) idpart
c     write(iomsg,1000) idpart
c     call adios(2)
      ierdat(1)=46
      ierdat(2)=idpart
      call lsmsg(3,MSG_SOL+1348,ioall,ierdat,rerdat,cerdat,0)
c
c1000 format(/' *** Error umat46c not implemented for part ',i10)
c
      return
      end
      subroutine umat47c(idpart,cm,lft,llt,fc,dx,dxdt,aux,ek,
     & ifail,dt1siz,crv,nnpcrv,nhxbwp,cma,maketan,dsave,ctmp,elsiz,
     & reject,ip,nip)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      include 'nlqparm'
      include 'iounits.inc'
      logical ifail,maketan,reject
      dimension cm(*),fc(nlq,*),dx(nlq,*),dxdt(nlq,*),
     & aux(nlq,*),ek(*),ifail(*),dt1siz(*),crv(lq1,2,*),
     & nhxbwp(*),cma(*),dsave(nlq,6,*),ctmp(*),elsiz(*)
      integer nnpcrv(*)
      integer idpart
c
c     write(iotty,1000) idpart
c     write(iohsp,1000) idpart
c     write(iomsg,1000) idpart
c     call adios(2)
      ierdat(1)=47
      ierdat(2)=idpart
      call lsmsg(3,MSG_SOL+1348,ioall,ierdat,rerdat,cerdat,0)
c
c1000 format(/' *** Error umat47c not implemented for part ', i10)
c
      return
      end
      subroutine umat48c(idpart,cm,lft,llt,fc,dx,dxdt,aux,ek,
     & ifail,dt1siz,crv,nnpcrv,nhxbwp,cma,maketan,dsave,ctmp,elsiz,
     & reject,ip,nip)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      include 'nlqparm'
      include 'iounits.inc'
      logical ifail,maketan,reject
      dimension cm(*),fc(nlq,*),dx(nlq,*),dxdt(nlq,*),
     & aux(nlq,*),ek(*),ifail(*),dt1siz(*),crv(lq1,2,*),
     & nhxbwp(*),cma(*),dsave(nlq,6,*),ctmp(*),elsiz(*)
      integer nnpcrv(*)
      integer idpart
c
c     write(iotty,1000) idpart
c     write(iohsp,1000) idpart
c     write(iomsg,1000) idpart
c     call adios(2)
      ierdat(1)=48
      ierdat(2)=idpart
      call lsmsg(3,MSG_SOL+1348,ioall,ierdat,rerdat,cerdat,0)
c
c1000 format(/' *** Error umat48c not implemented for part ',i10)
c
      return
      end
      subroutine umat49c(idpart,cm,lft,llt,fc,dx,dxdt,aux,ek,
     & ifail,dt1siz,crv,nnpcrv,nhxbwp,cma,maketan,dsave,ctmp,elsiz,
     & reject,ip,nip)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      include 'nlqparm'
      include 'iounits.inc'
      logical ifail,maketan,reject
      dimension cm(*),fc(nlq,*),dx(nlq,*),dxdt(nlq,*),
     & aux(nlq,*),ek(*),ifail(*),dt1siz(*),crv(lq1,2,*),
     & nhxbwp(*),cma(*),dsave(nlq,6,*),ctmp(*),elsiz(*)
      integer nnpcrv(*)
      integer idpart
c
c     write(iotty,1000) idpart
c     write(iohsp,1000) idpart
c     write(iomsg,1000) idpart
c     call adios(2)
      ierdat(1)=49
      ierdat(2)=idpart
      call lsmsg(3,MSG_SOL+1348,ioall,ierdat,rerdat,cerdat,0)
c
c1000 format(/' *** Error umat49c not implemented for part ',i10)
c
      return
      end
      subroutine umat50c(idpart,cm,lft,llt,fc,dx,dxdt,aux,ek,
     & ifail,dt1siz,crv,nnpcrv,nhxbwp,cma,maketan,dsave,ctmp,elsiz,
     & reject,ip,nip)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      include 'nlqparm'
      include 'iounits.inc'
      logical ifail,maketan,reject
      dimension cm(*),fc(nlq,*),dx(nlq,*),dxdt(nlq,*),
     & aux(nlq,*),ek(*),ifail(*),dt1siz(*),crv(lq1,2,*),
     & nhxbwp(*),cma(*),dsave(nlq,6,*),ctmp(*),elsiz(*)
      integer nnpcrv(*)
      integer idpart
c
c     write(iotty,1000) idpart
c     write(iohsp,1000) idpart
c     write(iomsg,1000) idpart
c     call adios(2)
      ierdat(1)=50
      ierdat(2)=idpart
      call lsmsg(3,MSG_SOL+1348,ioall,ierdat,rerdat,cerdat,0)
c
c1000 format(/' *** Error umat50c not implemented for part ', i10)
c
      return
      end
