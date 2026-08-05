# 1 "dyn21.F"
c
c $Id$
c
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





# 5 "dyn21.F" 2 
# 1 ".\define2.inc" 1 



# 6 "dyn21.F" 2 
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c
c User subroutines are moved:
c   dyn21umat.F: User Material Models
c   dyn21cnt.F : User Contact subroutines
c   dyn21ushl.F: User Shell Element
c   dyn21usld.F: User Solid Element
c
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c
c User Subroutine Initialization
c
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
      subroutine initdll(config,fsetsym,ierr)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     This entry subroutine to initialize the DLL. It is called upon
c     the DLL is loaded. One DLL may be loaded multiple times during
c     during one execution.
c
c     Description of Input Arguments:
c     config(1)   : main version of the LSDYNA
c           (2-4) : minor version numbers
c           (5)   : binary version
c           (6)   : nlq
c          ...
c     fsetsym     : function provided by LS-DYNA to
c                   set common blocks/function in the DLL
c     ierr        : 0 if the user subroutines are initialized properly.
c
      implicit none
      integer*8 config(*),ierr
CDLL_EXPORT(initdll)
      external fsetsym
      include 'nlqparm'
c
c     check NLQ
      if(config(6).ne.nlq)ierr=1
# 57

      end
c
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c
c User Subroutines for LSDYNA Material Models
c
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
      subroutine matusr_24(lft,llt,ietype,cm,crv,nnpcrv,
     . ipt,ipt_thk,nip,
     . nelbwp,lfail)
# 71

c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     user-defined damage subroutine for materials:
c     24, 36, 114, 123, 124, 133, 155, 182, 225, 238, 243, 251, 255
c
c     Description of Input Arguments:
c
c     sig1 - stress in x  direction, local x for shells
c     sig2 - stress in y  direction, local y for shells
c     sig3 - stress in z  direction, local z for shells
c     sig4 - stress in xy direction, local for shells
c     sig5 - stress in yz direction, local for shells
c     sig6 - stress in zx direction, local for shells
c
c     dt1siz-element time step size
c
c     incremental strains are used for shell elements
c     strain rates are used for solid elements
c
c     d1 - strain rate/increment in x  direction, local x for shells
c     d2 - strain rate/increment in y  direction, local y for shells
c     d3 - strain rate/increment in z  direction, local z for shells
c     d4 - strain rate/increment in xy direction, local for shells
c     d5 - strain rate/increment in yz direction, local for shells
c     d6 - strain rate/increment in zx direction, local for shells
c
c     wxxdt - time-step*spin rate in x  direction, only for solds
c     wyydt - time-step*spin rate in y  direction, only for solds
c     wzzdt - time-step*spin rate in z  direction, only for solds
c
c     The following strain components are only available when
c     INTOUT in *DATABASE_EXTENT_BINARY is set to "STRAIN" or "ALL"
c
c     eps1 - strain in x  direction, local x for shells
c     eps2 - strain in y  direction, local y for shells
c     eps3 - strain in z  direction, local z for shells
c     eps4 - strain in xy direction, local for shells
c     eps5 - strain in yz direction, local for shells
c     eps6 - strain in zx direction, local for shells
c
c     eint - strain energy density increment
c     ep - plastic strain
c     fail - failure flag SET TO ZERO IF ELEMENT FAILS
c     n - number of elements in vector block
c     ietype - 1 - beams, 2 - shells, 3 - solids.
c
c     lft: 1st element to be processed
c     llt: last element to be processed
c
c     cm: material properties
c       -1: young's modulus
c       -2: poissons's ratio
c
c     crv: curve array
c
c     nnpcrv=# of discretization points per crv()
c
c     ipt: integration point number
c     ipt_thk: through-thickness integration point number
c     nip: total number of integration points
c
c     nelbwp: element id array
c
c     - solids: idele=lqfinv8(nelbwp(i),2)
c     - beams : idele=lqfinv8(nelbwp(i),3)
c     - shells: idele=lqfinv8(nelbwp(i),4)
c
c     nintcy: current cycle
c     tt: current time
c
c     lfail: where failure flag is stored, defined by ls-dyna,
c           =0: failure is stored in fail0
c           >2: failure is stored in fail1
c
c     Be aware that in addition to failure criteria set forth in this routine,
c     failure also occurs if ep >= abs(FAIL) where FAIL is the 'failure flag'
c     provided in the mat24 input.
c
      include 'nlqparm'
      common/aux2loc/d1(nlq),d2(nlq),d3(nlq),d4(nlq),d5(nlq),d6(nlq),
     1 wzzdt(nlq),wyydt(nlq),wxxdt(nlq),einc(nlq)
      common/aux13loc/zeta(nlq),thick(nlq)
      common/aux14loc/
     1 sig1(nlq),sig2(nlq),sig3(nlq),sig4(nlq),
     2 sig5(nlq),sig6(nlq),  ep(nlq),fail1(nlq,187)
      common/failuloc/tmp1(nlq),fail0(nlq),ifaili(nlq),nfipts(nlq),
     . msgfail(nlq),def_ele_eros(nlq)
      common/subtssloc/dt1siz(nlq)
      common/strnintloc/eps1(nlq),eps2(nlq),eps3(nlq),eps4(nlq),
     1 eps5(nlq),eps6(nlq)
      common/bk26/begtim,nintcy
      common/bk28/summss,xke,xpe,tt,xte0,erodeke,erodeie,selie,selke,
     . erodehg,eintcnt,engjnt,vinfin,disipke,disipie
      dimension cm(*),crv(lq1,2,*),nelbwp(*)
      integer nnpcrv(*)
c
c     loop over elements
c     if (lfail.eq.0) then
c       do i=lft,llt
c        if (failure condition is met) fail0(i)=0.0
c       enddo
c     else
c       do i=lft,llt
c        if (failure condition is met) fail1(i,lfail)=0.0
c       enddo
c     endif
c$omp threadprivate (/subtssloc/)
c$omp threadprivate (/strnintloc/)
c$omp threadprivate (/failuloc/)
c$omp threadprivate (/aux14loc/)
c$omp threadprivate (/aux13loc/)
c$omp threadprivate (/aux2loc/)
      return
      end
      subroutine matusr_103 (sig1,sig2,sig3,sig4,sig5,sig6,dt1siz,
     . d1,d2,d3,d4,d5,d6,ep,fail,n,ietype,q1,q2,d1m,d2m,d3m,d4m,d5m,
     . d6m,failure_flag,s11,s12,s13,s21,s22,s23,s31,s32,s33,cm,crv,
     . nnpcrv,
     . parms,nparms,dmg,aux,naux,fracs,nfracs,clen,cang,dep)
# 200

c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     description of Input Arguments, global for solid element
c
c     sig1 - stress in x  direction, local x for shells
c     sig2 - stress in y  direction, local y for shells
c     sig3 - stress in z  direction, local z for shells
c     sig4 - stress in xy direction, local for shells
c     sig5 - stress in yz direction, local for shells
c     sig6 - stress in zx direction, local for shells
c
c     dt1siz-element time step size
c
c     incremental strains are used for shell elements
c     strain rates are used for solid elements
c
c     d1  - strain rate/increment in x  direction, local x for shells
c     d2  - strain rate/increment in y  direction, local y for shells
c     d3  - strain rate/increment in z  direction, local z for shells
c     d4  - strain rate/increment in xy direction, local for shells
c     d5  - strain rate/increment in yz direction, local for shells
c     d6  - strain rate/increment in zx direction, local for shells
c
c     d1-d6 are in the a,b,c material local system for solids
c
c     q1,q2  - direction cosines to obtain material direction (shells)
c
c     To obtain stresses in shell a,b coordinate system:
c
c           a11    =q1(i)*sig1(i)-q2(i)*sig4(i)
c           a12    =q2(i)*sig1(i)+q1(i)*sig4(i)
c           a21    =q1(i)*sig4(i)-q2(i)*sig2(i)
c           a22    =q2(i)*sig4(i)+q1(i)*sig2(i)
c           sig1(i)=q1(i)*a11-q2(i)*a21
c           sig2(i)=q2(i)*a12+q1(i)*a22
c           sig4(i)=q1(i)*a12-q2(i)*a22
c
c     To transform back to shell local
c
c           a11    = sig1(i)*q1(i)+sig4(i)*q2(i)
c           a12    =-sig1(i)*q2(i)+sig4(i)*q1(i)
c           a21    = sig4(i)*q1(i)+sig2(i)*q2(i)
c           a22    =-sig4(i)*q2(i)+sig2(i)*q1(i)
c           sig1(i)= q1(i)*a11+q2(i)*a21
c           sig2(i)=-q2(i)*a12+q1(i)*a22
c           sig4(i)= q1(i)*a12+q2(i)*a22
c
c
c     d1m - strain rate/increment in a  direction (shells)
c     d2m - strain rate/increment in b  direction (shells)
c     d3m - strain rate/increment in c  direction (shells)
c     d4m - strain rate/increment in ab direction (shells)
c     d5m - strain rate/increment in bc direction (shells)
c     d6m - strain rate/increment in ca direction (shells)
c
c     ep - plastic strain
c     fail - failure flag SET TO ZERO IF ELEMENT FAILS
c     n - number of elements in vector block
c     ietype  beams, 2 - shells, 3 - solids.
c
c     Be aware that in addition to failure criteria set forth in this routine,
c     failure also occurs if ep >= abs(FAIL) where FAIL is the 'failure flag'
c     provided in the mat24 input.
c
c     s11-s33 transformation matrix for SOLIDS only.  To transform the stresses
c     into the local system:
c
c     a11    =sig1(i)*s11(i)+sig4(i)*s12(i)+sig6(i)*s13(i)
c     a12    =sig1(i)*s21(i)+sig4(i)*s22(i)+sig6(i)*s23(i)
c     a13    =sig1(i)*s31(i)+sig4(i)*s32(i)+sig6(i)*s33(i)
c     a21    =sig4(i)*s11(i)+sig2(i)*s12(i)+sig5(i)*s13(i)
c     a22    =sig4(i)*s21(i)+sig2(i)*s22(i)+sig5(i)*s23(i)
c     a23    =sig4(i)*s31(i)+sig2(i)*s32(i)+sig5(i)*s33(i)
c     a31    =sig6(i)*s11(i)+sig5(i)*s12(i)+sig3(i)*s13(i)
c     a32    =sig6(i)*s21(i)+sig5(i)*s22(i)+sig3(i)*s23(i)
c     a33    =sig6(i)*s31(i)+sig5(i)*s32(i)+sig3(i)*s33(i)
c     sig1(i)=s11(i)*a11+s12(i)*a21+s13(i)*a31
c     sig2(i)=s21(i)*a12+s22(i)*a22+s23(i)*a32
c     sig3(i)=s31(i)*a13+s32(i)*a23+s33(i)*a33
c     sig4(i)=s11(i)*a12+s12(i)*a22+s13(i)*a32
c     sig5(i)=s21(i)*a13+s22(i)*a23+s23(i)*a33
c     sig6(i)=s11(i)*a13+s12(i)*a23+s13(i)*a33
c
c     warning: For shells the stresses must be in the shell local system
c              when returning from this subroutine.  For solids, the
c              stresses must be in the global system when returning.
c
c     Additional arguments for supporting user defined damage model
c
c     parms(nparms)      = damage parameters, input
c     dmg(i)             = damage, input/output
c     aux(i,naux)        = history variable, input/output
c     fracs(i,nfracs)    = fraction material of phases, input
c     clen(i)            = characteristic element length divided by shell
c                          thickness (for solids this is zero), input
c     cang(i)            = cosine of angle between loading and first material
c                          direction, input
c     dep(i)             = plastic strain rate, input
c
      include 'nlqparm'
      dimension sig1(*),sig2(*),sig3(*),sig4(*),sig5(*),sig6(*),
     . dt1siz(*),d1(*),d2(*),d3(*),d4(*),d5(*),d6(*),ep(*),
     . fail(*),q1(*),q2(*),d1m(*),d2m(*),d3m(*),d4m(*),d5m(*),d6m(*),
     . s11(*),s12(*),s13(*),s21(*),s22(*),s23(*),s31(*),s32(*),s33(*),
     . cm(*),crv(lq1,2,*)
      integer nnpcrv(*)
      dimension parms(*),dmg(*),aux(nlq,*),fracs(nlq,*),
     .     clen(*),cang(*),dep(*)
c
c     loop over elements, Put new failure criteria here.
c
       do i=1,n
c      if (failure condition is met) fail(i)=0.0
c      example
       if (ep(i).gt.abs(failure_flag)) fail(i)=0.
c
       enddo
      return
      end
      subroutine hdot(lft,llt,hmin,hmax,iactive,e,h,dt,const,s)
# 330

c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     user integration in time of the smoothing length
c
c     lft      : left indice of the loop
c     llt      : right indice of the loop
c     hmin     : Minimum smoothing length defined in the corresponding
c                *SECTION_SPH
c     hmax     : Maximum smoothing length defined in the corresponding
c                *SECTION_SPH
c     iactive  : variable that indicates if the particle is active or not
c                = 1, particle is active
c                = 0, particle is not active
c     e        : tensor of gradient of deformation
c     h        : smoothing length
c     dt       : current time step
c     const    : constant = dt/dimension of the problem
c     s        : stress tensor
c
      dimension h(1),iactive(1),e(9,1),ro(1),smthi(1),matsph(1)
      dimension s(6,1)
c
c$omp paralleldo default(none)
c$omp& shared(lft,llt,iactive,e,h,const,dt1,hmin,hmax)
c$omp& private(i,divv,hnew)
c
      do 200 i=lft,llt
      divv = e(1,i) + e(2,i) + e(3,i)
c
      hnew = (1.+const*divv)*h(i)
      h(i) = max(hmin,hnew)
      h(i) = min(h(i),hmax)
 200  continue
c
      return
      end
      subroutine f3dm9ale_userdef1(xmu,iel,gp,
     .                             ncon,ix,
     .                             auxvec,locaux,
     .                             ro,cm,
     .                             x,v,a,
     .                             xms,tt,ncycle,tmpnd)
# 382

c
c     *MAT_ALE_VISCOUS: user defined dynamic viscosity
c
      real*8 x
      dimension ix(ncon,*),auxvec(*),locaux(*),ro(*),cm(*),
     .          x(3,*),v(3,*),a(3,*),xms(*),tmpnd(*)
c
c xmu              : dynamic viscosity
c
c iel              : internal Lagrangian element ID (structure element)
c                    get user ID with lqfinvf(iel,2) if ncon=9
c                                     lqfinvf(iel,3) if ncon=5
c                                     lqfinvf(iel,4) if ncon=4
c
c gp               : material group rank (defined by *ALE_MULTI-MATERIAL_GROUP)
c
c ncon             : part ID + number of nodes connected to the elements
c                    ncon=9 : solids
c                    ncon=5 : shells
c                    ncon=4 : beams
c
c ix(j,iel)        : ix(1,iel) : part ID for the element iel
c                    ix(2,iel) : 1st node of the element iel
c                    .
c                    .
c                    .
c                    ix(ncon,iel) : (ncon-1)th node of the element iel
c
c locaux(iel)           : pointer to the auxiliary variables in the vector auxvec
c                         for the group gp
c auxvec(locaux(iel)+j) : auxiliary variables of the element iel
c                         auxvec(locaux(iel)+1) : xx-stress for the group gp
c                         auxvec(locaux(iel)+2) : yy-stress for the group gp
c                         auxvec(locaux(iel)+3) : zz-stress for the group gp
c                         auxvec(locaux(iel)+4) : xy-stress for the group gp
c                         auxvec(locaux(iel)+5) : yz-stress for the group gp
c                         auxvec(locaux(iel)+6) : xz-stress for the group gp
c                         auxvec(locaux(iel)+7) : plastic strain for the group gp
c                         auxvec(locaux(iel)+8) : internal energy for the group gp
c                         auxvec(locaux(iel)+9) : bulk viscosity for the group gp
c                         auxvec(locaux(iel)+10): previous material volume for
c                                                 the group gp
c
c ro(ix(1,iel))    : initial density
c
c cm               : list of keyword inputs from *NAT_ALE_VISCOUS
c                    cm(1) : PC
c                    cm(2) : MULO
c                    cm(3) : -IUSERDEF
c                    cm(4) : RK
c                    cm(6) : RT
c                    cm(7) : RN
c
c x(3,nd)          : position of the node nd (double precision)
c
c v(3,nd)          : velocity of the node nd
c
c a(3,nd)          : acceleration of the node nd
c
c xms(nd)          : inverse of the nodal mass
c
c tt               : time
c
c ncycle           : current cycle
c
c tmpnd(nd)        : nodal temperature
      return
      end
      subroutine f3dm9sph_userdefin(xmu,iel,inode,
     .                             cm,x,v,a,ro,
     .                             tt,ncycle,tmpnd)
# 457

c
c     *MAT_SPH_VISCOUS: user defined dynamic viscosity
c
      real*8 x
      dimension ro(*),cm(*),
     .          x(3,*),v(3,*),a(3,*),tmpnd(*)
c
c xmu              : dynamic viscosity
c
c iel              : internal SPH particle ID
c
c inode            : global nodal ID for SPH particle--iel
c
c ro(iel)          : SPH particle density
c
c cm               : list of keyword inputs from *MAT_SPH_VISCOUS
c                    cm(1) : PC
c                    cm(2) : MULO
c                    cm(3) : -IUSERDEF
c                    cm(4) : RK
c                    cm(6) : RT
c                    cm(7) : RN
c
c x(3,inod)        : position of the node inod (double precision)
c
c v(3,inod)        : velocity of the node inod
c
c a(3,inod)        : acceleration of the node inod
c
c
c tt               : time
c
c ncycle           : current cycle
c
c tmpnd(inod)        : nodal temperature
      return
      end
      subroutine matfailusercontrol(user)
# 499

      dimension user(*)
c
c     user interface to for user failure subroutine
c     when iuserfail equals to 1, user has the option to access stress,
c     and history information for each element
c     Then user can make any change with 'subroutine matuserfail'
c
      iuserfail=0
      if(iuserfail.eq.1) then
      call matfailusercontrol1(user)
      end if
      return
      end
      subroutine matuserfail(stress,shisv,nip,nplane,nhis)
# 517

      dimension stres(8,4,9),shisv(90,4,9)
c
c     user can access stress and history information now
c     so, user's failure model can be defined here.
c
c     no more than 9 integration point in the thickness
c
c     stress(1,*,*): zeta (local coordinate) in the thickness direction
c     stress(8,*,*): effective strain
c
c     shisv(n,*,*) the nth history variable in one integration
c
c     Stress and history can be obtained in the following format
c     do i = 1, nplane
c     do j = 1, nip
c       write(*,'(t1,8e10.3)') (stres(k,i,j),k=1,8)
c       do m = 1, nhis,8
c         n = min(nhis,m+7)
c         write(*,'(t1,8e10.3)') (shisv(k,i,j),k=m,n)
c       end do
c     end do
c     end do
      return
      end
      subroutine usermatfpert ( x, y, z, fail )
# 546

c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     user specification of material failure
c
c     Inputs:
c     x, y, z: coordinates
c
c     Returned:
c     fail:  failure criterion (stress, yield)
c
      fail = x
c
      return
      end
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c
c User Subroutines for Thermal problems
c
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
      subroutine usrhcon(h,uc,nc,d,p,xs,xm,vs,vm,ts,tm,
     . istria,imtria,crv,nnpcrv)
# 577

c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     User subroutine for interface conductivity control (mpp/smp)
c
c     To define thermal contact conductivity
c
c     Variables:
c
c     h      = thermal contact conductivity (output)
c     uc(nc) = array of user defined parameters (input)
c     nc     = number of user defined conductivity parameters (input)
c     d      = distance (gap) between slave and master segment (input)
c     p      = interface pressure (input)
c     xs     = slave segment coordinates (input)
c     xm     = master segment coordinates (input)
c     vs     = slave segment velocities (input)
c     vm     = master segment velocities (input)
c     ts     = slave segment temperatures (input)
c     tm     = master segment temperatures (input)
c     istria = 1 iff slave segment is a triangle (input)
c     imtria = 1 iff master segment is a triangle (input)
c     crv    = curve array (input)
c     nnpcrv = # of discretization points per crv()
c
c     Note that usrvrel can be called to compute relative sliding velocity
c
      include 'nlqparm'
      dimension uc(nc)
      dimension xs(3,4),xm(3,4)
      dimension vs(3,4),vm(3,4)
      dimension crv(lq1,2,*)
      integer nnpcrv(*)
c
c     Define conductivity as function of pressure via load curve
c
      call crvval(crv,nnpcrv,uc(1),p,h,dh)
c
      return
      end
      subroutine usrvrel(vrel,xs,vs,vm,istria,imtria)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     compute sliding velocity vrel and that can be called from usrhcon.
c
c     Variables:
c     vrel    = relative sliding velocity (output)
c     xs      = slave segment coordinates (input)
c     vs      = slave segment velocities (input)
c     vm      = master segment velocities (input)
c     istria  = 1 iff slave segment is a triangle (input)
c     imtria  = 1 iff master segment is a triangle (input)
c
      dimension xs(3,4),vs(3,4),vm(3,4)
      dimension xnrm(3),vr(3)
c
      jmax=4
      if (istria.eq.1) jmax=3
      do i=1,3
         vr(i)=0.
         do j=1,jmax
            vr(i)=vr(i)+vs(i,j)
         enddo
         vr(i)=vr(i)/jmax
      enddo
      jmax=4
      if (imtria.eq.1) jmax=3
      do i=1,3
         vrl=0.
         do j=1,jmax
            vrl=vrl+vm(i,j)
         enddo
         vr(i)=vr(i)-vrl/jmax
      enddo
      x31=xs(1,3)-xs(1,1)
      y31=xs(2,3)-xs(2,1)
      z31=xs(3,3)-xs(3,1)
      x42=xs(1,4)-xs(1,2)
      y42=xs(2,4)-xs(2,2)
      z42=xs(3,4)-xs(3,2)
      xnrm(1)=y31*z42-z31*y42
      xnrm(2)=z31*x42-x31*z42
      xnrm(3)=x31*y42-y31*x42
      xlen=sqrt(xnrm(1)**2+xnrm(2)**2+xnrm(3)**2)
      xnrm(1)=xnrm(1)/xlen
      xnrm(2)=xnrm(2)/xlen
      xnrm(3)=xnrm(3)/xlen
      vnrm=vr(1)*xnrm(1)+vr(2)*xnrm(2)+vr(3)*xnrm(3)
      vr(1)=vr(1)-vnrm*xnrm(1)
      vr(2)=vr(2)-vnrm*xnrm(2)
      vr(3)=vr(3)-vnrm*xnrm(3)
      vrel=sqrt(vr(1)**2+vr(2)**2+vr(3)**2)
      return
      end
      subroutine usrflux(fl,flp,x,tnpl,tnl,nodes,
     . alpha,atime,atemp,dt,time,fhsv,nfhsv,crv,nnpcrv,v)
# 688

c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     User subroutine for boundary thermal flux
c
c     To define thermal flux parameter (heat per surface area and time)
c
c     Variables:
c
c     fl              = flux intensity (output)
c     flp             = flux intensity derivative wrt atemp (output)
c     x(3,nodes)      = global segment coordinates (input)
c     v(3,nodes)      = global segment velocities (input)
c     tnpl(nodes)     = temperatures at time time (input)
c     tnl(nodes)      = temperatures at time time-dt (input)
c     nodes           = number of nodes in segment (3,4 or 6) (input)
c     alpha           = time integration parameter (input)
c     atime           = time+(alpha-1)*dt
c     atemp           = average segment temperature at time atime
c     dt              = time step size (input)
c     time            = time at which the new temperature is sought (input)
c     fhsv(nfhsv)     = flux history variables (input/output)
c     nfhsv           = number of flux history variables for this segment (input)
c     crv             = curve array (input)
c     nnpcrv          = # of discretization points per crv()
c
      include 'nlqparm'
      dimension x(3,*),tnpl(*),tnl(*),v(3,*)
      dimension fhsv(*),crv(lq1,2,*),func(9)
      integer nnpcrv(*)
c---------------------------------------------------------------------
c Example 1
c     Define flux by linear convection
c     that optionally decays (in an ad-hoc way) as power
c     dissipates from surface
c
c     fhsv(1) = convection coefficient
c     fhsv(2) = ambient temperature
c     fhsv(3) = total amount of energy per surface area available
c     fhsv(4) = dissipated energy per surface area at current
c
c---- uncomment following lines for example 1
c     hcon=fhsv(1)
c     tinf=fhsv(2)
c     flin=hcon*(tinf-atemp)
c     if (nfhsv.gt.2) then
c        q=(1.-fhsv(4)/fhsv(3))/
c    .        (1.+.5*dt*flin/fhsv(3))
c        flp=-q*hcon
c        if (q.gt.1.) then
c           q=1.
c           flp=-hcon
c        elseif (q.lt.0.) then
c           q=0.
c           flp=0.
c        endif
c        fl=q*flin
c        fhsv(4)=fhsv(4)+dt*.5*fl
c        fhsv(4)=min(fhsv(3),fhsv(4))
c     else
c        fl=flin
c        flp=-hcon
c     endif
c     fl=-fl
c     flp=-flp
c---------------------------------------------------------------------
c Example 2
c     Define flux using a function ID
c
c     fhsv(1) =  function ID
c
      fl=0.
      flp=0.
c-- get segment centroid coordinates
      func(1)=(x(1,1)+x(1,2)+x(1,3)+x(1,4))/4.
      func(2)=(x(2,1)+x(2,2)+x(2,3)+x(2,4))/4.
      func(3)=(x(3,1)+x(3,2)+x(3,3)+x(3,4))/4.
c-- get segment average velocity
      func(4)=(v(1,1)+v(1,2)+v(1,3)+v(1,4))/4.
      func(5)=(v(2,1)+v(2,2)+v(2,3)+v(2,4))/4.
      func(6)=(v(3,1)+v(3,2)+v(3,3)+v(3,4))/4.
c-- get segment average temperature
      func(7)=(tnl(1)+tnl(2)+tnl(3)+tnl(4))/4.
c-- T_infinity is not a typical input for flux, set it to zero
      func(8)=0.
c-- get time
      func(9)=atime
c-- the first history variable for this segment is a function id
c-- make it an integer
      idff=int(fhsv(1))
c-- convert user function ID to the internal numbering system
      internal_f=ind_gf(idff)
c-- check to see if internal_f is valid. If so, then evaluate function
      if (internal_f .gt. 0) then
        fl=eval_function(internal_f,func,ierr)
        flp=0
      endif
c
      return
      end
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c
c User Subroutines for Load
c
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
      subroutine loadsetud(time,lft,llt,crv,iduls,parm,nod,nnm1)
# 803

c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     Input (not modifiable)
c       time : analysis time
c       x    : coordinate of node or element center
c       d    : displacement of node or lement center
c       v    : velocity of node or lement center
c       temp : temperature of node or element center
c       crv  : value of LCURV at time=time
c       iduls: id of user_loading_set
c       parm : parameters from user_loading
c       nod  : internal node numbers
c       nnm1 : offset for node block
c     Output (defined by user)
c       udl : user-defined load curve value
      include 'nlqparm'
      common/aux8loc/
     & x1(nlq),x2(nlq),x3(nlq),v1(nlq),
     & v2(nlq),v3(nlq),d1(nlq),d2(nlq),
     & d3(nlq),temp(nlq),udl(nlq),
     & xx11(nlq),xx21(nlq),xx31(nlq),
     & xx12(nlq),xx22(nlq),xx32(nlq),
     & xx13(nlq),xx23(nlq),xx33(nlq),
     & xx14(nlq),xx24(nlq),xx34(nlq),
     & xctr(nlq),yctr(nlq),zctr(nlq),
     & f(nlq), tr1(nlq), tr2(nlq), tr3(nlq)
c
      dimension parm(*),nod(*)
c
c     node numbers are given as
c
c     for LTYPE.eq.FORCEN,BODYFN,TEMPTN
c     do i=lft,llt
c       n=i+nnm1
c       nodint=nod(n)
c       nodext=lqfinv(nodint,1)
c     enddo
c
c     for LTYPE.eq.PRESSS
c     do i=lft,llt
c       n=i+nnm1-1
c       np=n*7
c       n1=nod(np+1)
c       n2=nod(np+2)
c       n3=nod(np+3)
c       n4=nod(np+4)
c       (only first two for 2D case)
c       (get external node numbers using lqfinv as above)
c     enddo
c
c     for LTYPE.eq.PRESSB
c     do i=lft,llt
c       n=i+nnm1
c       n1=nod(n)
c       n2=nod(nlq+n)
c       ...
c     enddo
c
c     sample
c     if (iduls.eq.100) then
c       do i=lft,llt
cc        to define a pressure loading proportional to sin of the angle
cc        between unit vector v,=(vx,vy,vz), and element normal
cc        take 42 x 13 as normal
c         x42=xx12(i)-xx14(i)
c         y42=xx22(i)-xx24(i)
c         z42=xx32(i)-xx34(i)
c         x13=xx13(i)-xx11(i)
c         y13=xx23(i)-xx21(i)
c         z13=xx33(i)-xx31(i)
c         xn = y42*z13-y13*z42
c         yn = z42*x13-z13*x42
c         zn = x42*y13-x13*y42
cc        v x normal
c         vnx= vy*zn-yn*vz
c         vny= vz*xn-zn*vx
c         vnz= vx*yn-xn*vy
c         vn = sqrt(vnx*vnx+vny*vny+vnz*vnz)
cc        abs(sin)=abs(v x n )/|n|
c         rn = 1./sqrt(xn*xn+yn*yn+zn*zn)
c         sint = vn*rn
c         fact = sint
c         udl(i)=crv*fact
c       enddo
c     else if (iduls.eq.200) then
c       do i=lft,llt
c         udl(i)=....
c       enddo
c       ....
c     endif
c$omp threadprivate (/aux8loc/)
      do i=lft,llt
       udl(i)= crv
      enddo
c
      return
      end
      subroutine loadud(fnod,dt1,time,ires,x,d,v,a,ixs,
     . numels,ixb,numelb,idrflg,tfail,isf,p,npc,fval,iob,iadd64,numelh,
     . ixh,nhex_del,nbeam_del,nshell_del,hexarray,hextim,bemarray,
     . bemtim,shlarray,shltim,parm,numnp,fnodr,dr,vr,ndof,xmst,xmsr,
     . numelt,ixt,ntsh_del,tsharray,tshtim)
# 915

c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     input arrays
c
c     fnod - global nodal forces
c     fnodr- global nodal moment
c     dt1 - current time step size
c     time - current problem time
c     ires - restart flag, ( 0=solution phase     )
c                          (-n=input n parameters )
c                          ( 2=restart            )
c                          ( 3=write data into dump file  )
c                          ( 4=read data from restart file)
c
c     When data is read, DUMMY arrays are passed in the call.
c     Data should be read into a local common block which is
c     written into the restart database.
c
c
c     d - displacements
c     v - velocities
c     a - acceleations
c     dr- rotational displacements
c     vr- rotational velocities
c     xmst(numnp) =reciprocal of nodal translational masses in solution phase
c     xmsr(numnp) =reciprocal of nodal rotational masses in solution phase.
c                  this array is defined if and only if ndof=6
c
c     ixs - shell element connectivities (ixs(1,*)=part ID)
c                                        (ixs(2,*)=node 1)
c                                        (ixs(3,*)=node 2)
c                                        (ixs(4,*)=node 3)
c                                        (ixs(5,*)=node 4)
c
c     ixb - beam  element connectivities (ixb(1,*)=part ID)
c                                        (ixb(2,*)=node 1)
c                                        (ixb(3,*)=node 2)
c                                        (ixb(4,*)=orientation node)
c
c     ixh - solid element connectivities (ixh(1,*)=part ID)
c                                         or
c                                        (ixh(1,*)=0 implies element deleted)
c                                        (ixh(2,*)=node 1)
c                                        (ixh(3,*)=node 2)
c                                        (ixh(4,*)=node 3)
c                                        (ixh(5,*)=node 4)
c                                        (ixh(6,*)=node 5)
c                                        (ixh(7,*)=node 6)
c                                        (ixh(8,*)=node 7)
c                                        (ixh(9,*)=node 8)
c
c     ixt - thick shell element connectivities
c                                        (ixt(1,*)=part ID)
c                                         or
c                                        (ixt(1,*)=0 implies element deleted)
c                                        (ixt(2,*)=node 1)
c                                        (ixt(3,*)=node 2)
c                                        (ixt(4,*)=node 3)
c                                        (ixt(5,*)=node 4)
c                                        (ixt(6,*)=node 5)
c                                        (ixt(7,*)=node 6)
c                                        (ixt(8,*)=node 7)
c                                        (ixt(9,*)=node 8)
c
c     numnp  - number of nodal points
c     numels - number of shell elements
c     numelb - number of beam  elements
c     numelh - number of solid elements
c     numelt - number of thick shell elements
c     isf    - shell element failure flag (1=on)
c     tfail  - shell element failure time (eq.0:okay)
c                                         (ne.0:failure time)
c
c     idrflg - nonzero if dynamic relaxation phase
c     p      - load curve data pairs (abcissa,ordinate)
c     npc    - pointer into p.  (p(npc(lc)) points to the beginning
c              of load curve ID lc.  npoints=npc(lc+1)-npc(lc)=
c              number of points in the load curve.
c     fval   - fval(lc) is the value of load curve lc at t=time
c     iob    - i/o buffer
c     ndof   - number of degrees of freedom per node in solution phase,
c            - 0 in initialization phase
c
c
c     ELEMENT DELETION FROM THE USER LOADING SUBROUTINE
c
c     to delete elements the original file needs to have a
c     *DEFINE_ELEMENT_DEATH definition for one or more elements
c     of the type to be deleted.  The deletion time can be set
c     to a value that greatly exceeds the termination time for the
c     run.  With this keyword the necessary arrays are created that
c     allows elements of the same type to deleted during the run.
c
c     nhex_del if >0 element deletion option is active for solids
c     nbem_del if >0 element deletion option is active for beams
c     nshl_del if >0 element deletion option is active for shells
c     ntsh_del if >0 element deletion option is active for thick shells
c     hexarray defines time to delete solid element,
c              the value should be >time
c     hextim   we check for solid element deletion when the current
c              time is greater to or equal to hextim
c     bemarray defines time to delete beam element,
c              the value should be >time
c     bemtim   we check for beam element deletion when the current
c              time is greater to or equal to bemim
c     shlarray defines time to delete shell element,
c              the value should be >time
c     shltim   we check for shell element deletion when the current
c              time is greater to or equal to shltim
c     tsharray defines time to delete thick shell element,
c              the value should be >time
c     tshtim   we check for thick shell element deletion when the
c              current time is greater to or equal to tshtim
c     parm     user loading parameter if ires<0
c
      include 'iounits.inc'
      include 'bigprb.inc'
      include 'txtline.inc'
c
      parameter (NPARM=1000)
c     common/usrldv/parm(NPARM)
c
      integer*8 iadd64
      real*8 x
      real*8 d,dr
      dimension a(3,*),v(3,*),d(3,*),fnod(3,*),ixs(5,*),ixb(4,*),
     . x(3,*),tfail(*),p(*),npc(*),fval(*),iob(*),ixh(9,*),
     . hexarray(*),bemarray(*),shlarray(*),parm(*),fnodr(3,*),
     . vr(3,*),dr(3,*),xmst(*),xmsr(*),ixt(9,*),tsharray(*)
c     character*80 txts,mssg
c
# 1074

c
      if (ires.lt.0) then
        n=abs(ires)
c       write(iohsp,1030)
        call prludparm(0,parm,0,0)
        mssg='reading user loading subroutine'
        if (longs) then
          do 11 i=1,n,8
          call gttxsg (txts,lcount)
          read (txts,'(8e20.0)',err=400) (parm(j),j=i,min(i+3,n))
c         write(iohsp,1040) (j,parm(j),j=i,min(i+3,n))
          call prludparm(1,parm,i,min(i+3,n))
   11     continue
        else
          do 10 i=1,n,8
          call gttxsg (txts,lcount)
          read (txts,1020,err=400) (parm(j),j=i,min(i+7,n))
c         write(iohsp,1040) (j,parm(j),j=i,min(i+7,n))
          call prludparm(1,parm,i,min(i+7,n))
   10     continue
        endif
c       write(iohsp,1050)
        call prludparm(2,parm,0,0)
# 1103

        return
      endif
c
c     sample coding of gravitational force bet. two nodes
c
c     if (ndof.eq.0) return
c     grav=6.67e-11
c     do i=1,numnp
c      xmsi=1./xmst(i)
c      xi=x(1,i)
c      yi=x(2,i)
c      zi=x(3,i)
c      do j=i+1,numnp
c       xj=x(1,j)
c       yj=x(2,j)
c       zj=x(3,j)
c       xij=xj-xi
c       yij=yj-yi
c       zij=zj-zi
c       rij2i=1./max(xij*xij+yij*yij+zij*zij,1.e-16)
c       riji =sqrt(rij2i)
c       xij=xij*riji
c       yij=yij*riji
c       zij=zij*riji
c       xmsj=1./xmst(j)
c       fij=grav*xmsi*xmsj*rij2i
c       fx=fij*xij
c       fy=fij*yij
c       fz=fij*zij
c       fnod(1,i)=fnod(1,i)+fx
c       fnod(2,i)=fnod(2,i)+fy
c       fnod(3,i)=fnod(3,i)+fz
c       fnod(1,j)=fnod(1,i)-fx
c       fnod(2,j)=fnod(2,i)-fy
c       fnod(3,j)=fnod(3,i)-fz
c      enddo
c     enddo
c
c     if (ires.eq.3) then
c       nloddv=160
c       call wrabsf64(iob,parm,nloddv,iadd64)
c       iadd64=iadd64+nloddv
c       return
c     endif
c
c     if (ires.eq.4) then
c       nloddv=160
c       call rdabsf64(iob,parm,nloddv,iadd64,ioerr)
c       iadd64=iadd64+nloddv
# 1158

c       return
c     endif
c
c     for shells only
c
# 1173

      do 20 i=1,numels
      ixs2i=ixs(2,i)
      ixs3i=ixs(3,i)
      ixs4i=ixs(4,i)
      ixs5i=ixs(5,i)
c
      xx11 =x(1,ixs2i)
      xx21 =x(2,ixs2i)
      xx31 =x(3,ixs2i)
c
      xx12 =x(1,ixs3i)
      xx22 =x(2,ixs3i)
      xx32 =x(3,ixs3i)
c
      xx13 =x(1,ixs4i)
      xx23 =x(2,ixs4i)
      xx33 =x(3,ixs4i)
c
      xx14 =x(1,ixs5i)
      xx24 =x(2,ixs5i)
      xx34 =x(3,ixs5i)
c
      fs1 =-xx11+xx12+xx13-xx14
      fs2 =-xx21+xx22+xx23-xx24
      fs3 =-xx31+xx32+xx33-xx34
c
      ft1 =-xx11-xx12+xx13+xx14
      ft2 =-xx21-xx22+xx23+xx24
      ft3 =-xx31-xx32+xx33+xx34
c
      e=fs1*fs1+fs2*fs2+fs3*fs3
      f=fs1*ft1+fs2*ft2+fs3*ft3
      g=ft1*ft1+ft2*ft2+ft3*ft3
      area=sqrt((e*g-f*f)/16.)
      tr1 =fs2*ft3-fs3*ft2
      tr2 =fs3*ft1-fs1*ft3
      tr3 =fs1*ft2-fs2*ft1
      xmg =.25/sqrt(tr1**2+tr2**2+tr3**2)
c
c     unit normal surface vector
c
c     pressure set by user here
c
      pressure=-5.e-04*fval(1)
c
      tr1 =xmg*tr1*area*pressure
      tr2 =xmg*tr2*area*pressure
      tr3 =xmg*tr3*area*pressure
c
      fnod(1,ixs2i)=fnod(1,ixs2i)-tr1
      fnod(2,ixs2i)=fnod(2,ixs2i)-tr2
      fnod(3,ixs2i)=fnod(3,ixs2i)-tr3
      fnod(1,ixs3i)=fnod(1,ixs3i)-tr1
      fnod(2,ixs3i)=fnod(2,ixs3i)-tr2
      fnod(3,ixs3i)=fnod(3,ixs3i)-tr3
      fnod(1,ixs4i)=fnod(1,ixs4i)-tr1
      fnod(2,ixs4i)=fnod(2,ixs4i)-tr2
      fnod(3,ixs4i)=fnod(3,ixs4i)-tr3
      fnod(1,ixs5i)=fnod(1,ixs5i)-tr1
      fnod(2,ixs5i)=fnod(2,ixs5i)-tr2
      fnod(3,ixs5i)=fnod(3,ixs5i)-tr3
# 1250

   20 continue
c
# 1282

c
      return
  400 call termin (txts,mssg,lcount,1)
 1020 format(8e10.0)
 1030 format(//' u s e r   d e f i n e d   l o a d i n g',
     .           '   p a r a m e t e r s',/)
 1040 format(
     1 5x,'   parameter number  ',i4,'=', e15.8)
 1050 format(//)
      end
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c
c User Subroutines for Spotweld
c
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
      subroutine uweldfail(idweld,strr,fail,fibl,cm,tt,lft,llt)
# 1302

c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     spotweld failure routine
c
c***  local coordinates: x is tangent to beam, y & z are normal
c
c***  variables
c          idweld ---- weld id number
c          strr ------ stress resultants
c                      (1) axial (x direction) force
c                      (2) y shear force
c                      (3) z shear force
c                      (4) moment about z
c                      (5) moment about y
c                      (6) torsional resultant
c          fail ------ failure flag
c                      =0 not failed
c                      =1 fail element
c          fibl ------ fibl(1,i)=diameter of weld
c          cm -------- 6 constants supplied by user
c          tt -------- current simulation time
c          lft,llt --- do-loop range for strr
c
      integer idweld
      dimension strr(8,*),fail(*),cm(*),fibl(5,*)
c
c***  demonstration failure model
c
c***  geometry
c
c***  failure constants
      if (cm(1).gt.0.) then
        oamax=1./cm(1)
      else
        oamax=0.
      endif
      if (cm(2).gt.0.) then
        osmax=1./cm(2)
      else
        osmax=0.
      endif
c
c***  evaluate failure criterion:
c       axial stress = axial force/area + moment/sectionmod
c       shear stress = shear force/area + torsion/(2.*sectionmod)
c       failure surface = (axial stress/cm(1))**2 +
c                         (shear stress/cm(2))**2
      do i=lft,llt
      Z       =3.14159265359*fibl(1,i)**3/32
      osctmod =1.0/Z
      hosctmod=.5*osctmod
      oarea   =4./(3.14159265359*fibl(1,i)**2)
        axial=max(0.,strr(1,i))*oarea+
     &          sqrt(strr(4,i)**2+strr(5,i)**2)*osctmod
        shear=sqrt(strr(2,i)**2+strr(3,i)**2)*oarea+
     &        abs(strr(6,i))*hosctmod
        if ((axial*oamax)**2+(shear*osmax)**2.gt.1.0) fail(i)=1.
      enddo
c
      return
      end
      subroutine uweldfail12(eps_to_fail,beta,dmg,uhisv,num_uhisv,
     . idweld,iwtype,strr,eps,esr,npt,diameter,cm,idmgopt,tt,ncycle,
     . lft,llt)
# 1376

c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     Sample user defined spotweld damage and failure routine with 46
c     parameters; this routine can be used to damage or fail beam welds
c     and hex weld assemblies.
c
c     There are two ways to use it.  The first way is to do a damage
c     initiation calculation and set eps_to_fail and beta when damage
c     should initiate.  Based on the values set (see below) either
c     immediate failure, or linear or exponential damage and failure
c     based on effective plastic strain will occur.  The second way is
c     for the user to do their own dmaage calculation and update the
c     dmg variable thoughout the calculation.
c
c     subroutine output variables (may be updated by user)
c
c        eps_to_fail  Plastic strain from damage initiation until
c                     failure.  A zero value means that damage has not
c                     yet begun.  Any negative value will cause
c                     immediate failure.  In the cycle when eps_to_fail
c                     is set, the current effective plastic strain will
c                     be stored and used as the strain at which damage
c                     inititiates (eps_di).  Note that eps_to_fail and
c                     beta can only be set only one time for each
c                     integration point and subsequent changes will be
c                     ignored.
c
c        beta ....... Set to positive number for exponential
c                     damage.  Set to zero for linear damage.
c
c                     For beta=0, the decay function is
c
c                        dmg=(eps-eps_di)/eps_to_fail
c
c                      For beta>0, the decay function is
c
c                        dmg=1.-exp(-beta*(eps-eps_di)/eps_to_fail)
c
c                     For exponential damage, the damage will grow
c                     according to the exponential equation above until
c                     the plastic strain reaches eps_to_fail at which
c                     time the weld will be failed.
c
c        uhisv ...... Weld history values.  These values will be
c                     retained, but will not be used for the
c                     calculation.
c
c     subroutine input/output variable (may be either calculated by
c     ls-dyna or updated by the user)
c
c
c        dmg ........ Current damage at the integration point.
c                     Initially, dmg=0.  When dmg=1.0, the integration
c                     point will fail.  When all integration points
c                     fail, the element or assembly will be deleted.
c                     If the user wants ls-dyna to calculate damage
c                     using eps_to_fail and beta, then damage should
c                     not be changed.  Optionally, the user may update
c                     the dmg variable throughout the calculation and
c                     the user's value will be applied.
c
c     subroutine input variables
c
c        num_uhisv .. number of weld history variables (will be
c                     equal to FVAL on card 3 of *MAT_SPOTWELD)
c        idweld ..... weld id number
c
c        iwtype ..... weld type
c                      1=beam element
c                      2=solid element assembly
c
c        strr ....... stress resultants
c                       (1) axial (x direction) force
c                       (2) y shear force
c                       (3) z shear force
c                       (4) moment about z
c                       (5) moment about y
c                       (6) torsional mement
c
c        eps ........ effective plastic strain at the integration point
c                     (or hex weld of an assembly)
c
c        esr ........ effective strain rate at the integration point
c                     (or hex weld of an assembly)
c
c        npt ........ number of integration points in the weld; for hex
c                     weld assemblies, npt is the number of elements
c                     in the assembly since each element has 1 integration
c                     point
c
c        diameter ... diameter of weld
c        cm ......... up to 46 constants supplied by user
c        idmgopt .... damage option parameter DMGOPT
c        tt ......... current simulation time
c        ncycle ..... current cycle number
c        lft,llt .... do-loop range
c
c
c     For hex assmeblies, some variables may be dumped to d3plot using
c     NEIPH on *DATABASE_EXTENT_BINARY.  The table below shows the
c     variable number for each.
c
c        variable name    extra history variable #
c
c             dmg                   8
c            eps_di                10
c          eps_to_fail             11
c             beta                 12
c             esr                  13
c
      integer idweld
      dimension eps_to_fail(*),beta(*),dmg(npt,*),uhisv(num_uhisv,*),
     . strr(8,*),eps(npt,*),esr(npt,*),diameter(*),cm(*)
c
c***  demonstration failure model
c
c***  failure constants
      if (cm(1).gt.0.) then
        oamax=1./cm(1)
      else
        oamax=0.
      endif
      if (cm(2).gt.0.) then
        osmax=1./cm(2)
      else
        osmax=0.
      endif
c
c***  evaluate damage initiation criterion:
c       axial stress = axial force/area + moment/sectionmod
c       shear stress = shear force/area + torsion/(2.*sectionmod)
c       failure surface = (axial stress/cm(1))**2 +
c                         (shear stress/cm(2))**2
      do i=lft,llt
      if (eps_to_fail(i).eq.0.) then
        Z       =3.14159265359*diameter(i)**3/32
        osctmod =1.0/Z
        hosctmod=.5*osctmod
        oarea   =4./(3.14159265359*diameter(i)**2)
c
        axial=max(0.,strr(1,i))*oarea+
     &         sqrt(strr(4,i)**2+strr(5,i)**2)*osctmod
        shear=sqrt(strr(2,i)**2+strr(3,i)**2)*oarea+
     &         abs(strr(6,i))*hosctmod
c
        if ((axial*oamax)**2+(shear*osmax)**2.gt.1.0) then
          eps_to_fail(i)=cm(3)
          beta(i)=cm(4)
        endif
      endif
      enddo
      return
      end
      subroutine uweldfail22(idweld,strr,rscale,fail,fibl,cm,tt,lft,llt)
# 1540

c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     sample user defined spotweld failure routine with 46 parameters
c
c
c***  local coordinates: x is tangent to beam, y & z are normal
c
c***  variables
c          idweld ---- weld id number
c          strr stress resultants at beam ends 1 and 2
c                      (1) axial (x direction) force
c                      (2) y shear force
c                      (3) z shear force
c                      (4) moment about z
c                      (5) moment about y
c                      (6) torsional resultant
c          fail ------ failure flag
c                      =0 not failed
c                      =1 fail element
c          fibl ------ fibl(1,i)=diameter of weld
c                      fibl(2,i)=pointer to rscale data
c          rscale ---- resultant force scale factor for
c                      *CONTROL_SPOTWELD_BEAM effects
c                      (1) node 1 tensile factor
c                      (2) node 2 tensile factor
c                      (3) node 1 shear factor
c                      (4) node 2 shear factor
c          cm -------- up to 46 constants supplied by user
c          tt -------- current simulation time
c          lft,llt --- do-loop range for strr
c
c     *** NOTE *** for solid element welds, the rscale factors are not
c                  useful and are set to 1.0
c
      integer idweld
      dimension strr(8,*),rscale(4,*),fail(*),cm(*),fibl(5,*)
c
c***  demonstration failure model
c
c***  failure constants
      if (cm(1).gt.0.) then
        oamax=1./cm(1)
      else
        oamax=0.
      endif
      if (cm(2).gt.0.) then
        osmax=1./cm(2)
      else
        osmax=0.
      endif
c
c***  evaluate failure criterion:
c       axial stress = axial force/area + moment/sectionmod
c       shear stress = shear force/area + torsion/(2.*sectionmod)
c       failure surface = (axial stress/cm(1))**2 +
c                         (shear stress/cm(2))**2
      do i=lft,llt
      Z       =3.14159265359*fibl(1,i)**3/32
      osctmod =1.0/Z
      hosctmod=.5*osctmod
      oarea   =4./(3.14159265359*fibl(1,i)**2)
      axial=max(0.,strr(1,i))*oarea+
     &        sqrt(strr(4,i)**2+strr(5,i)**2)*osctmod
      shear=sqrt(strr(2,i)**2+strr(3,i)**2)*oarea+
     &      abs(strr(6,i))*hosctmod
      j=nint(fibl(2,i))
      axial1=axial*rscale(1,j)
      axial2=axial*rscale(2,j)
      shear1=shear*rscale(3,j)
      shear2=shear*rscale(4,j)
      if ((axial1*oamax)**2+(shear1*osmax)**2.gt.1.0) fail(i)=1.
      if ((axial2*oamax)**2+(shear2*osmax)**2.gt.1.0) fail(i)=1.
      enddo
c
      return
      end
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c
c User Subroutines for Joint
c
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
      subroutine ujntfdrv(njntf,idat,kdat,idatjf,kdatjf,const,
     &                    statevar,q,rbv,rbf,x)
# 1633

c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      include 'iounits.inc'
c
c***  driver for the user joint force subroutines
c
c***  variables
c          njntf ----- number of joint forces
c          idatjf ---- integer user joint force data
c                      1) ID
c                      2) joint ID
c                      3) number of state variables
c                      4) joint index
c                      5) rigid body 1
c                      6) rigid body 2
c                      7) pointer into state variables
c          idat ------ 1) joint type
c                      2:7) nodes
c          const ----- user constants
c          statevar -- user state variables
c          q --------- integrated displacements
c          rbv ------- rigid body velocities
c          rbf ------- rigid body forces
c
c***  overall structure
c
c       qdot = B*{rigid body velocities}
c       q    = q + dt*qdot
c       f    = user_function(q,qdot,t,dt)
c       f_rb = f_rb - B^T*f
c       ener = ener + dt*f*qdot
c
      common/bk02/iburn,dt1,dt2,isdo,tet10jtol
      common/bk28/summss,xke,xpe,tt,xte0
c
      real*8 x
      character*19 atype(14)
      dimension idat(kdat,*),idatjf(kdatjf,*),const(48,*),
     &          statevar(*),q(6,*),rbv(6,*),rbf(6,*),x(3,*)
c
      data atype/'spherical          ',
     2           'revolute           ',
     3           'cylindrical        ',
     4           'planar             ',
     5           'universal          ',
     6           'translational      ',
     7           'locking            ',
     8           'translational motor',
     9           'rotational motor   ',
     .           'gears              ',
     1           'rack and pinion    ',
     2           'constant velocity  ',
     3           'pulley             ',
     4           'screw              '/
c
c***  over joint forces
      do 1000 ijntf=1,njntf
c
c***    the basics
        idjntf=idatjf(1,ijntf)
        idjnt =idatjf(2,ijntf)
        indjnt=idatjf(4,ijntf)
        irb1  =idatjf(5,ijntf)
        irb2  =idatjf(6,ijntf)
        ipsv  =idatjf(7,ijntf)
        jnttyp=idat(indjnt,1)
c
c***    branch on joint type
        go to (  10,  20,  30,  40,  50,  60,  70,
     &           80,  90, 100, 110, 120, 130, 140), jnttyp
c
c***    spherical
   10   go to 911
c
c***    revolute
   20   call rjufrc(idjntf,idjnt,const(1,ijntf),tt,dt1,
     &              statevar(ipsv),q(1,ijntf),
     &              rbv(1,irb1),rbf(1,irb1),rbv(1,irb2),rbf(1,irb2),
     &              x,idat,kdat,indjnt)
        go to 1000
c
c***    cylindrical
   30   go to 911
c
c***    planar
   40   go to 911
c
c***    universal
   50   go to 911
c
c***    translational
   60   go to 911
c
c***    locking
   70   go to 911
c
c***    tranlational motor
   80   go to 911
c
c***    rotational motor
   90   go to 911
c
c***    gears
  100   go to 911
c
c***    rack and pinion
  110   go to 911
c
c***    constant velocity
  120   go to 911
c
c***    pulley
  130   go to 911
c
c***    screw
  140   go to 911
c
c***    error message -- should never get here
c 911   write(iohsp,1010) idjntf,atype(jnttyp),idjnt
c       write(iomsg,1010) idjntf,atype(jnttyp),idjnt
c       write(iotty,1010) idjntf,atype(jnttyp),idjnt
  911   continue
        ierdat(1)=idjntf
        cerdat(1)=atype(jnttyp)
        ierdat(2)=idjnt
        call lsmsg(3,MSG_SOL+1153,ioall,ierdat,rerdat,cerdat,0)
c
 1000 continue
c
      return
c1010 format(1x/
c    &  '*** Error user joint force ID',i12,' for ',a19,i12/
c    &  '          this type of joint is currently not supported',
c    &  '          for user joint forces.')
      end
      subroutine ujntfrc(idfrc,idjnt,const,t,dt,statevar,disp,vel,frc)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c***  user subroutine for applying forces to joint degrees of freedom
c
c***  variables
c          idfrc ----- ID for the joint force
c          idjnt ----- ID for the joint
c          const ----- array of user supplied constants
c          t --------- current time
c          dt -------- time step size
c          statevar -- array of user integrated state variables
c          disp ------ array of relative joint displacements
c          vel ------- array of relative joint velocities
c          frc ------- array of forces and torques calculated by user
c
      dimension const(*),statevar(*),disp(*),vel(*),frc(*)
c
c***  example for a spring and damper for a revolute joint
c     torque =  c*angular_velocity + k*(angle-offset)
      frc(1)=const(1)*vel(1)+const(2)*(disp(1)-const(3))
c
c***  statevariable integration: statevar(1)=0.5*t**2
      statevar(1)=statevar(1)+dt*t
c
      return
      end
      subroutine rjufrc(idfrc,idjnt,const,t,dt,statevar,q,
     &                  rbv1,rbf1,rbv2,rbf2,x,idat,kdat,indjnt)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c***  revolute joint user force driver
c
c***  variables
c          idfrc ----- id of user force
c          idjnt ----- id of joint
c          const ----- user constants
c          t --------- current time
c          dt -------- time step size
c          statevar -- user state variables
c          q --------- displacements
c          rbv1,2 ---- rigid body velocities
c          rbf1,2 ---- rigid body forces
c          x --------- coordinates
c          idat ------ list of joint nodes
c          indjnt ---- joint indext
c
      real*8 x
      dimension const(*),statevar(*),q(*),
     &          rbv1(*),rbf1(*),rbv2(*),rbf2(*),x(3,*),idat(kdat,*)
c
c***  nodes
      n1=idat(indjnt,2)
      n2=idat(indjnt,3)
      n3=idat(indjnt,4)
      n4=idat(indjnt,5)
c
c***  angular velocity
      dx11=x(1,n3)-x(1,n1)
      dx21=x(2,n3)-x(2,n1)
      dx31=x(3,n3)-x(3,n1)
      omag=1.0/sqrt(dx11**2+dx21**2+dx31**2)
      dx11=omag*dx11
      dx21=omag*dx21
      dx31=omag*dx31
c
      dx12=x(1,n4)-x(1,n2)
      dx22=x(2,n4)-x(2,n2)
      dx32=x(3,n4)-x(3,n2)
      omag=1.0/sqrt(dx12**2+dx22**2+dx32**2)
      dx12=omag*dx12
      dx22=omag*dx22
      dx32=omag*dx32
c
      angv=rbv2(4)*dx12+rbv2(5)*dx22+rbv2(6)*dx32
     &    -rbv1(4)*dx11-rbv1(5)*dx21-rbv1(6)*dx31
c
c***  angular displacement integrated in time
c     copy so user can't overwrite our history variable value
      q(1)=q(1)+dt*angv
      ang=q(1)
c
c***  call user routine
      call ujntfrc(idfrc,idjnt,const,t,dt,statevar,ang,angv,torq)
c
c***  add torq to rhs
      rbf2(4)=rbf2(4)-dx12*torq
      rbf2(5)=rbf2(5)-dx22*torq
      rbf2(6)=rbf2(6)-dx32*torq
      rbf1(4)=rbf1(4)+dx11*torq
      rbf1(5)=rbf1(5)+dx21*torq
      rbf1(6)=rbf1(6)+dx31*torq
c
      return
      end
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c
c User Subroutines for Solution Control
c
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
      subroutine uctrl1 (numnp,ndof,time,dt1,dt2,prtc1,pltc1,frci,prto,
     . plto,frco,vt,vr,at,ar,ut,ur,xmst,xmsr,irbody_flag,rbdyn,usrhv,
     . messag,totalm,cycle,idrint,mtype,mxrb,nrba,rbcor,x,rbv,nrbn,
     . nrb,xrb,yrb,zrb,axrb,ayrb,azrb,dtx,nmmat,rba,fvalnew,fvalold,
     . fvalmid,fvalnxt)
# 1895

c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     user subroutine for solution control and is called at the
c     beginning of time step n+1.   The time at n+
c
c
c     note:  ls-dyna3d uses an internal numbering system to
c            accomodate arbitrary node numbering.   to access
c            information for user node n, address array location m,
c            m=lqf8(n,1). to obtain user node number, n,
c            corresponding to array address m, set n=lqfinv8(m,1)
c
c     arguments:
c          numnp=number of nodal points
c          ndof =number of degrees of freedom per node
c          time =current solution time at n+1
c          dt1  =time step size between time n-1 and n
c          dt2  =time step size between time n and n+1
c          prtc1=output interval for taurus time history data
c          pltc1=output interval for taurus state data
c          frci =output interval for taurus interface force data
c          prto =output time for time history file
c          plto =output time for state data
c          frco =output time for force data
c          vt(3,numnp) =nodal translational velocity vector
c          vr(3,numnp) =nodal rotational velocity vector.  this
c                       array is defined if and only if ndof=6
c          at(3,numnp) =nodal translational acceleration vector
c          ar(3,numnp) =nodal rotational acceleration vector.  this
c                       array is defined if and only if ndof=6
c          ut(3,numnp) =nodal translational displacement vector
c          ur(3,numnp) =nodal rotational displacement vector.  this
c                       array is defined if and only if ndof=6
c          xmst(numnp) =reciprocal of nodal translational masses
c          xmsr(numnp) =reciprocal of nodal rotational masses.  this
c                       array is defined if and only if ndof=6
c          irbody_flag      =0 if no rigid bodies
c          rbdyn(numnp)=flag for rigid body nodal points
c                       if deformable node then set to 1.0
c                       if rigid body node then set to 0.0
c                       defined if and only if rigid bodies are present
c                       i.e., irbody_flag.ne.0 if no rigid bodies are
c                       present
c          usrhv(lenhv)=user defined history variables that are stored
c                       in the restart file.  lenhv=100+7*nummat where
c                       nummat is the # of materials in the problem.
c                       array usrhv is updated only in this subroutine.
c          messag      =flag for dyna3d which may be set to:
c                      'sw1.' ls-dyna3d terminates with restart file
c                      'sw3.' ls-dyna3d writes a restart file
c                     'sw4.' ls-dyna3d writes a plot state
c           totalm     =total mass in problem
c           cycle     =cycle number
c           idrint    =flag for dynamic relaxation phase
c                      .ne.0: dynamic relaxation in progress
c                      .eq.0: solution phase
c          mtype(*)   = material type for each part in the model
c          mxrb(*)    = master rigid body for each rigid body
c                       If part n is rigid and is a master or has not
c                       been merged then mxrb(n)==n.
c          nrba(*)    = starting index in nrb(*) of the nodes for each
c                       rigid body
c          rbcor(3,*) = rigid body cg coordinates
c          x(3,*)     = Node coordinate array
c          rbv(6,*)   = rigid body cg velocity
c          nrbn(*)    = # nodes in each rigid body
c          nrb(*)     = List of all rigid body nodes
c          xrb(*)     = RB scratch array as long as longest nrbn() value
c          yrb(*)     = RB scratch array as long as longest nrbn() value
c          zrb(*)     = RB scratch array as long as longest nrbn() value
c          axrb(*)    = RB scratch array as long as longest nrbn() value
c          ayrb(*)    = RB scratch array as long as longest nrbn() value
c          azrb(*)    = RB scratch array as long as longest nrbn() value
c          dtx        = (dt1+dt2)*0.5 except at time 0 when it is = dt2
c          nmmat      = number of parts in the model
c          rba(6,*)   = rigid body cg acceleration
c          fvalnew     =array for setting load curve values at time n+1
c                       only load curves with 0 input points may be user
c                       defined.  When the load curve is user set, the
c                       value at time n must be stored in array fvalold.
c          fvalold     =array for storing load curve values at time n
c          fvalmid     =array for predicting load curve values at time n+3/2
c          fvalnxt     =array for predicting load curve values at time n+2
c                       for some applications it is necessary to predict the
c                       load curve values at time n+2, a time that is not known,
c                       this for instance for boundary prescribed motion. In
c                       this case the load curve values at time n+3/2 need to
c                       be predicted in fvalmid, and fvalold should be set to
c                       fvalnew and fvalnew should be set to fvalnxt. See
c                       coding below.
c
c
      include 'ptimes.inc'
c
c     prtims(1-37)=output intervals for ascii files
c
c      ascii files:
c           ( 1)-cross section forces
c           ( 2)-rigid wall forces
c           ( 3)-nodal data
c           ( 4)-element data
c           ( 5)-global data
c           ( 6)-discrete elements
c           ( 7)-material energies
c           ( 8)-nodal interface forces
c           ( 9)-resultant interface forces
c           (10)-smug animator
c           (11)-spc reaction forces
c           (12)-nodal constraint resultant forces
c           (13)-airbag statistics
c           (14)-avs database
c           (15)-nodal force groups
c           (16)-output intervals for nodal boundary conditions
c           (17)-(32) unused at this time
c           (37)-auto tiebreak damage output
c
c     prtlst(32)=output times for ascii files above.  when solution time
c                exceeds the output time a print state is dumped.
c
      common/rbkeng/enrbdy,rbdyx,rbdyy,rbdyz
c
c      total rigid body energies and momentums:
c           enrbdy=rigid body kinetic energy
c           rbdyx =rigid body x-momentum
c           rbdyy =rigid body y-momentum
c           rbdyz =rigid body z-momentum
c
      common/swmke/swxmom,swymom,swzmom,swkeng
c
c      total stonewall energies and momentums:
c           swxmom=stonewall x-momentum
c           swymom=stonewall y-momentum
c           swzmom=stonewall z-momentum
c           swkeng=stonewall kinetic energy
c
      common/deengs/deeng
c
c      deeng=total discrete element energy
c
      include 'bk03.inc'
c
c      endtim = termination time
c
      common/bk28/summss,xke,xpe,tt,xte0,erodeke,erodeie,selie,selke,
     . erodehg
c
c      xpe  =total internal energy in the finite elements
c
      common/sprengs/spreng
c
c      spreng=total spr energy
c
      character*(*) messag
      integer cycle
      real*8 x
      dimension vt(3,*),vr(3,*),at(3,*),ar(3,*),
     . xmst(*),xmsr(*),rbdyn(*),usrhv(*),mtype(*),mxrb(*),nrba(*),
     . rbcor(3,1),x(*),rbv(6,*),nrbn(*),nrb(*),xrb(*),yrb(*),
     . zrb(*),axrb(*),ayrb(*),azrb(*),rba(6,*),fvalnew(*),
     . fvalold(*),fvalmid(*),fvalnxt(*)
      real*8 ut(3,*),ur(3,*)
c
c     MPP special variables
c
c     remove all "cmpp" for output to a single file in MPP for UMAT routine
c
# 2080

c
c     sample momentum and kinetic energy calculations
c
c     remove all comments in column 1 below to activate
      i=1
      if (i.eq.1) return
c     return
cc
cc
cc     initialize kinetic energy, xke, and x,y,z momentums.
cc
c      xke=2.*swkeng+2.*enrbdy
c      xm=swxmom+rbdyx
c      ym=swymom+rbdyy
c      zm=swzmom+rbdyz
cc
c      numnp2=numnp
c      if (ndof.eq.6) then
c        numnp2=numnp+numnp
c      endif
c      write(iotty,*)ndof
cc
cc
cc     no rigid bodies present
cc
c      if (irbody_flag.eq.0) then
cc       note in blank comment vr follows vt.  this fact is used below.
c        do 10 n=1,numnp2
c        xmsn=1./xmst(n)
c        vn1=vt(1,n)
c        vn2=vt(2,n)
c        vn3=vt(3,n)
c        xm=xm+xmsn*vn1
c        ym=ym+xmsn*vn2
c        zm=zm+xmsn*vn3
c        xke=xke+xmsn*(vn1*vn1+vn2*vn2+vn3*vn3)
c   10   continue
cc
cc
cc     rigid bodies present
cc
c      else
cc       nodal accerations for rigid bodies
cc
c        do 12 n=1,nmmat
c        if (mtype(n).ne.20.or.mxrb(n).ne.n) go to 12
c        lrbn=nrba(n)
c        call stvlut(rbcor(1,n),x,vt,at,ar,vr,rbv(1,n),dt2,
c    .   nrbn(n),nrb(lrbn),xrb,yrb,zrb,axrb,ayrb,azrb,dtx)
c
c        rigid body nodal accelerations
c
c        if (ndof.eq.6) then
c          call rbnacc(nrbn(n),nrb(lrbn),rba(4,n),ar)
c        endif
c
c  12    continue
cc
c        do 20 n=1,numnp
c        xmsn=1./xmst(n)
c        vn1=rbdyn(n)*vt(1,n)
c        vn2=rbdyn(n)*vt(2,n)
c        vn3=rbdyn(n)*vt(3,n)
c        xm=xm+xmsn*vn1
c        ym=ym+xmsn*vn2
c        zm=zm+xmsn*vn3
c        xke=xke+xmsn*(vn1*vn1+vn2*vn2+vn3*vn3)
c   20   continue
c        if (ndof.eq.6) then
c          do 30 n=1,numnp
c          xmsn=1./xmsr(n)
c          vn1=rbdyn(n)*vr(1,n)
c          vn2=rbdyn(n)*vr(2,n)
c          vn3=rbdyn(n)*vr(3,n)
c          xm=xm+xmsn*vn1
c          ym=ym+xmsn*vn2
c          zm=zm+xmsn*vn3
c          xke=xke+xmsn*(vn1*vn1+vn2*vn2+vn3*vn3)
c   30     continue
c        endif
c      endif
cc
cc     total kinetic energy
c      xke=.5*xke
cc     total internal energy
c      xie=xpe+deeng+spreng
cc     total energy
c      xte=xke+xpe+deeng+spreng
cc     total x-rigid body velocity
c      xrbv=xm/totalm
cc     total y-rigid body velocity
c     yrbv=ym/totalm
cc     total z-rigid body velocity
c      zrbv=zm/totalm
# 2207

c
c     New source to control load curve 2 in model during solution
c
c     External DYNA model load curve id
      lidext=2
c     Obtain the internal load curve id
      lidint=lqfl(lidext)
c     Put old 'new' value into fvalold
      fvalold(lidint)=fvalnew(lidint)
      fvalnew(lidint)=fvalnxt(lidint)
c     Calculate value for fvalnxt
      fvalnxt(lidint)=100.0*sin(time*3.1415926)
      fvalmid(lidint)=.5*(fvalnxt(lidint)+fvalnew(lidint))
c
c     New source to check that we can correctly obtain the nodal
c     displacements and velocities for an arbitrary node.
c     Using node 3 in this case on part A of model.
c     Obtain the displacements and velocities at t=0.3s.
c
      if (abs(time-0.3).lt.1e-6) then
c        Time is 0.3s (time step is 2.5e-6s)
# 2238

         call lsopen(85,'node3.out','formatted','new',ierr,0,0)
c        External DYNA model node number
         nodext=3
c        Obtain the internal node id
         nodint=lqf8(nodext,1)

         write (85,'('' Time = '',E10.4E2,/)')time
c        Obtain and write out the nodal displacements
         write (85,'('' Node 3 x disp. = '',E10.4E2)')ut(1,nodint)
         write (85,'('' Node 3 y disp. = '',E10.4E2)')ut(2,nodint)
         write (85,'('' Node 3 z disp. = '',E10.4E2)')ut(3,nodint)
c        Obtain and write out the nodal velocities
         write (85,'('' Node 3 x velo. = '',E10.4E2)')vt(1,nodint)
         write (85,'('' Node 3 y velo. = '',E10.4E2)')vt(2,nodint)
         write (85,'('' Node 3 z velo. = '',E10.4E2)')vt(3,nodint)
         close (unit=85)
# 2258

      endif
c
      return
      end
      subroutine uctrl2(nsi,nty,time,cycle,msr,nmn,nsv,nsn,
     1 thmr,thsv,vt,xi,ut,iskip,idrint,numnp,dt2,ninput,ua,
     2 irectm,nrtm,irects,nrts)
# 2269

c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     user subroutine for interface control
c
c     note:  ls-dyna3d uses an internal numbering system to
c            accomodate arbitrary node numbering.   to access
c            information for user node n, address array location m,
c            m=lqf8(n,1). to obtain user node number, n,
c            corresponding to array address m, set n=lqfinv8(m,1)
c
c     arguments:
c          nsi        =number of sliding interface
c          nty        =interface type.
c                      .eq.4:single surface
c                      .ne.4:surface to surface
c          time       =current solution time
c          cycle      =cycle number
c          msr(nmn)   =list of master nodes numbers in internal
c                      numbering scheme
c          nmn        =number of master nodes
c          nsv(nsn)   =list of slave nodes numbers in internal
c                      numbering scheme
c          nsn        =number of slave nodes
c          thmr(nmn)  =master node thickness
c          thsv(nsn)  =slave node thickness
c          vt(3,numnp)=nodal translational velocity vector
c          xi(3,numnp)=initial coordinates at time=0
c          ut(3,numnp)=nodal translational displacement vector
c          idrint     =flag for dynamic relaxation phase
c                      .ne.0: dynamic relaxation in progress
c                      .eq.0: solution phase
c          numnp      =number of nodal points
c          dt2        =time step size at n+1/2
c          ninput     =number of variables input into ua
c          ua(*)      =users' array, first ninput locations
c                      defined by user.  the length of this
c                      array is defined on control card 10.
c                      this array is unique to interface nsi.
c          irectm(4,*)=list of master segments in internal
c                      numbering scheme
c          nrtm       =number of master segments
c          irects(4,*)=list of slave segments in internal
c                      numbering scheme
c          nrts       =number of master segments
c
c     set flag for active contact
c       iskip=0 active
c       iskip=1 inactive
c
c*******************************************************************
c
      integer cycle
      real*8 ut
      real*8 xi
      dimension msr(*),nsv(*),thmr(*),thsv(*),vt(3,*),xi(3,*),
     .          ut(3,*),ua(*),irectm(4,*),irects(4,*)
c
c     the following sample of codeing is provided to illustrate how
c     this subroutine might be used.   here we check to see if the
c     surfaces in the surface to surface contact are separated.   if
c     so the iskip=1 and the contact treatment is skipped.
c
c     if (nty.eq.4) return
c     dt2hlf=dt2/2.
c     xmins= 1.e+16
c     xmaxs=-xmins
c     ymins= 1.e+16
c     ymaxs=-ymins
c     zmins= 1.e+16
c     zmaxs=-zmins
c     xminm= 1.e+16
c     xmaxm=-xminm
c     yminm= 1.e+16
c     ymaxm=-yminm
c     zminm= 1.e+16
c     zmaxm=-zminm
c     thks=0.0
c     thkm=0.0
c     do 10 i=1,nsn
c     dsp1=ut(1,nsv(i))+dt2hlf*vt(1,nsv(i))
c     dsp2=ut(2,nsv(i))+dt2hlf*vt(2,nsv(i))
c     dsp3=ut(3,nsv(i))+dt2hlf*vt(3,nsv(i))
c     x1=xi(1,nsv(i))+dsp1
c     x2=xi(2,nsv(i))+dsp2
c     x3=xi(3,nsv(i))+dsp3
c     thks = max(thsv(i),thks)
c     xmins=min(xmins,x1)
c     xmaxs=max(xmaxs,x1)
c     ymins=min(ymins,x2)
c     ymaxs=max(ymaxs,x2)
c     zmins=min(zmins,x3)
c     zmaxs=max(zmaxs,x3)
c  10 continue
c     do 20 i=1,nmn
c     dsp1=ut(1,msr(i))+dt2hlf*vt(1,msr(i))
c     dsp2=ut(2,msr(i))+dt2hlf*vt(2,msr(i))
c     dsp3=ut(3,msr(i))+dt2hlf*vt(3,msr(i))
c     x1=xi(1,msr(i))+dsp1
c     x2=xi(2,msr(i))+dsp2
c     x3=xi(3,msr(i))+dsp3
c     thkm = max(thmr(i),thks)
c     xminm=min(xminm,x1)
c     xmaxm=max(xmaxm,x1)
c     yminm=min(yminm,x2)
c     ymaxm=max(ymaxm,x2)
c     zminm=min(zminm,x3)
c     zmaxm=max(zmaxm,x3)
c  20 continue
c
c     if thks or thkm equal zero set them to some reasonable value
c
c     if (thks.eq.0.0) then
c       e1=(xi(1,irects(1,1))-xi(1,irects(3,1)))**2
c    .    +(xi(2,irects(1,1))-xi(2,irects(3,1)))**2
c    .    +(xi(3,irects(1,1))-xi(3,irects(3,1)))**2
c       e2=(xi(1,irects(2,1))-xi(1,irects(4,1)))**2
c    .    +(xi(2,irects(2,1))-xi(2,irects(4,1)))**2
c    .    +(xi(3,irects(2,1))-xi(3,irects(4,1)))**2
c       thks=.3*sqrt(max(e1,e2))
c     endif
c     if (thkm.eq.0.0) then
c       e1=(xi(1,irectm(1,1))-xi(1,irectm(3,1)))**2
c    .    +(xi(2,irectm(1,1))-xi(2,irectm(3,1)))**2
c    .    +(xi(3,irectm(1,1))-xi(3,irectm(3,1)))**2
c       e2=(xi(1,irectm(2,1))-xi(1,irectm(4,1)))**2
c    .    +(xi(2,irectm(2,1))-xi(2,irectm(4,1)))**2
c    .    +(xi(3,irectm(2,1))-xi(3,irectm(4,1)))**2
c       thkm=.3*sqrt(max(e1,e2))
c     endif
c
c     if (xmaxs+thks.lt.xminm-thkm) go to 40
c     if (ymaxs+thks.lt.yminm-thkm) go to 40
c     if (zmaxs+thks.lt.zminm-thkm) go to 40
c     if (xmaxm+thkm.lt.xmins-thks) go to 40
c     if (ymaxm+thkm.lt.ymins-thks) go to 40
c     if (zmaxm+thkm.lt.zmins-thks) go to 40
c     iskip=0
c
c     return
c  40 iskip=1
c
      return
      end
      subroutine rbnacc(nrbn,nrb,rba,ar)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      dimension nrb(*),rba(6),ar(3,*)
c
      do 20 i=1,nrbn
      ar(1,nrb(i))=rba(1)
      ar(2,nrb(i))=rba(2)
      ar(3,nrb(i))=rba(3)
   20 continue
c
      return
      end
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c
c User Subroutines for *USER_NONLOCAL_SEARCH
c
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
      subroutine user_nunonl(nnon,ictl,rctl,auxvec,lochvh,
     . ixh,nwcon,x,iuhhv,uehh)
# 2448

c
c     Main subroutine for *USER_NONLOCAL_SEARCH
c
      real*8 x
      dimension ictl(40,*),rctl(40,*),auxvec(*),lochvh(*),iuhhv(*),uehh(
     $     *)
      dimension ixh(nwcon,*),x(3,*)
      integer*8 peid,ped1,plst,pelst,peslt,phst,ptmp,pcnst,pseid
      integer*8 pfail,pixh,pnid,pxrmt
      integer*8 plstue,phstue,ptmpue

# 1 ".\dynmem.inc" 1 
!
!     dynamic memory allocation stuff.  This has to be a C style
!     include because of the use of integer*8
!
# 25

      integer i_mem(0:1)
      real r_mem(0:1)
      integer*4 i4_mem(0:1)
      integer*8 i8_mem(0:1)
      real*4 r4_mem(0:1)
      real*8 r8_mem(0:1)
      real*8 real8_mem
      integer*8 m_mem(0:1)
      integer*8 mem8_blk(0:15)
      common/dynmem/real8_mem(0:15)
      equivalence (i_mem,r_mem,i8_mem,r8_mem,real8_mem,i4_mem,r4_mem,   
     &  m_mem,mem8_blk)

      integer*8 mem_alloc, mems_alloc,mem_realloc, memh_ptr
      integer mem_length,memh_alloc,memh_realloc,memh_length
      integer memh_enum,memh_enums,memh_attach
!      integer mem_newmark,mem_getmark,memh_getmark
      integer*8 memh_detach,memh_ralloc
      integer*8 m_to_m8
      integer*8 m_to_mm
      integer*8 m8_to_m
      integer*8 m_to_m4
      integer*8 mptr_to_m

      external mem_alloc, mems_alloc, mem_realloc, mem_length
      external memh_alloc, memh_realloc, memh_length, memh_ptr
      external memh_enum,memh_attach,memh_detach,memh_ralloc
      external memh_enums
      external m_to_m8
      external m_to_mm
      external m8_to_m
      external m_to_m4
      external mptr_to_m

      integer*8 dm_xtpz
      integer*8 dm_n45
      integer len_n45,len_n46
      common/dynmem1/                                                   
     & dm_xtpz,                                                         
     & dm_n45          
      common/dynmem1l/len_n45,len_n46
!
      integer*8 mem_allocm,mems_allocm,mem_reallocm,mem_loc
      integer memh_allocm,memh_reallocm

      external mem_allocm,mems_allocm,mem_reallocm,mem_loc
      external memh_allocm,memh_reallocm

      integer*8 mem_allocmchk,mem_allocchk,mems_allocmchk
      integer*8 mems_allocchk,mem_reallocmchk,mem_reallocchk
      integer memh_allocmchk,memh_allocchk

      external mem_allocmchk,mem_allocchk,mems_allocmchk
      external mems_allocchk,mem_reallocmchk,mem_reallocchk
      external memh_allocmchk,memh_allocchk

# 2461 "dyn21.F" 2 
      include 'bk06.inc'

c nnon       : number of user defined *user_nonlocal_search cards
c
c Element information (I indicates integers and H memory pointers):
c ictl(1)    : I, set ID
c ictl(2)    : I, number of master solid elements
c ictl(3)    : H, 1:nelems                    , solid internal sorted ID
c                 nelems+1:nelems+1+(nelems+1), range of neighorbing elements
c ictl(14)   : H, neighboring element list in the local list
c ictl(15)   : H, number of slave solid elements under this card and its
c                 solid internal ID
c ictl(20)   : I, location of last local solid element
c ictl(25)   : H, user ID of the slave element (>0 exist on current processor)
c                                              (<0 on remote processor)
c ictl(27)   : I, nip
c ictl(28)   : H, element fail flag (0 = deleted)
c ictl(29)   : H, remote element connectivity ixhrmt(8,*)
c ictl(32)   : H, remote node UID
c ictl(33)   : H, remote xyz

c Subroutine parameters:
c ictl(8)    : I, user defined function flag
c ictl(9)    : H, user defined constants (max 48), -1 means none

c Material history variables:
c ictl(4)    : I, number of requested material history variables, nhisv
c ictl(5)    : H, location list of requested material history variables
c ictl(26)   : I, total no. of user material history variables available
c ictl(16)   : H, array of requested material history variables for slave elements
c ictl(17)   : H, temporary working array (length nip*nhisv)
c
c User element history variables:
c ictl(34)    : I, number of requested user element history variables, nhisvue
c ictl(35)    : H, location list of requested user element history variables
c ictl(36)    : I, total no. of user element history variables available
c ictl(37)    : H, array of requested user element history variables for slave elements
c ictl(38)    : H, temporary working array (length nhisvue)

      do ii=1,nnon
        nfreq  = ictl(6,ii)
        iutype  = ictl(8,ii)
        if(mod(ncycle,nfreq).ne.0) cycle

c       Retrieve user defined constants
        if(ictl(9,ii).ge.0) then
          ncnst = memh_length(ictl(9,ii))
          pcnst = memh_ptr(ictl(9,ii))
        endif

        ids=ictl(1,ii)
        nelems = ictl(2,ii)
        peid   = memh_ptr(ictl(3,ii))
        ped1   = peid + nelems
        nhisv  = ictl(4,ii)
        nhisvue  = ictl(34,ii)
        plst   = memh_ptr(ictl(5,ii))
        plstue = memh_ptr(ictl(35,ii))

        pelst  = memh_ptr(ictl(14,ii))
        peslt  = memh_ptr(ictl(15,ii))
c       Why is nsld defined but not used?
        nsld   = memh_length(ictl(15,ii))
        phst   = memh_ptr(ictl(16,ii))
        phstue = memh_ptr(ictl(37,ii))
        ptmp   = memh_ptr(ictl(17,ii))
        ptmpue = memh_ptr(ictl(38,ii))
        pseid  = memh_ptr(ictl(25,ii))
        pfail  = memh_ptr(ictl(28,ii))

        max_lo = ictl(20,ii)
        pixh   = memh_ptr(ictl(29,ii))
        pnid   = memh_ptr(ictl(32,ii))
        pxrmt  = memh_ptr(ictl(33,ii))

        nmtcon = ictl(26,ii)
        nmtconue = ictl(36,ii)
        nip    = ictl(27,ii)

c       Calls user defined smoothing: different subroutines can be
c       called with iutype (UTYPE on card) as switch
        call user_nunonl_smooth(nelems,i_mem(peid),i_mem(ped1), nhisv,
     $       nhisvue,i_mem(pelst),i_mem(peslt),i_mem(phst),i_mem(phstue)
     $       ,i_mem(plst),i_mem(plstue), i_mem(ptmp),i_mem(ptmpue)
     $       ,i_mem(pseid) ,auxvec,lochvh,nmtcon ,nmtconue ,nip,
     $       i_mem(pfail),ixh ,nwcon,x,max_lo ,i_mem(pixh) ,i_mem(pnid),
     $       i_mem(pxrmt),iuhhv,uehh)
      enddo

      return
      end

      subroutine user_nunonl_smooth(nelems,neid,nrang, nhisv,nhisvue
     $     ,nlist,nsrt,histv,histvue,list,listue,htmp,htmpue,uid,auxvec
     $     ,lochvh ,nmtcon,nmtconue ,nip, ifail,ixh,nwcon,x,lstsld,ixhr
     $     ,nid,xrmt ,iuhhv ,uehh)
c
c     User defined smoothing for *USER_NONLOCAL_SEARCH
c
      real*8 x,xrmt
      dimension neid(*),nrang(*),nlist(0:*),nsrt(*),histv(nhisv,nip,*)
     $     ,histvue(nhisvue,*),list(*),listue(*),htmp(nhisv,nip)
     $     ,htmpue(nhisvue),auxvec(*) ,lochvh(*),ifail(*),ixh(nwcon,*)
     $     ,x(3,*),ixhr(8,*),xrmt(3,*),iuhhv(*),uehh(*)
      integer uid(*),nid(*),icc(8),nnd(8)

c  Element data:
c  nelems: number of master solid elements
c  neid  : the isolid internal sorted ID
c          (lqfinvf(ie,2) to get solid user ID)
c  nrang : nrang(ii):nrang(ii+1)-1 range of neighboring element for ii_th element
c  nlist : slave element in packed sorted list for this group
c  nsrt  : slave element array to convert "nlist" to internal sorted element ID

c  Material history variables for slave elements:
c  list  : list of requested material history variables
c  histv : array of requested material history vars. of all slave elements
c  htmp  : working array for material history
c
c  User element history variables for slave elements:
c  listue  : list of user requested user element history variables
c  histvue : array of requested user element history vars. of all slave elements
c  htmpue  : working array for user element history
c
c  Material history variables for master elements:
c  auxvec: ls-dyna history variables storage
c          1-7: sxx, syy, szz, sxy, syz, sxz, plastic strain
c  lochvh: starting point of the history variable for ie_th element
c
c  User element history variables for master elements:
c  iuhhv: starting point of the history variable for ie_th element
c  uehh:  ls-dyna ueser element history variables storage
c
c  Conversion from internal to User number:
c  lqfinvf : convert internal sorted element ID to user ID
c  lqfmiv  : convert internal part ID to user ID
c
c  Element connectivity and nodal coordinates:
c  local  element uid(je)>0:  ixh (2:9,jje), x   (1:3,ixh(2:9,jje));  jje=nsrt(je)
c  remote element uid(je)<0:  ixhr(1:8,lje), xrmt(1:3,ixhr(1:8,lje)); lje=je-lstsld


      DO II=1,NELEMS

c       Master eid
        ie = neid(ii)
        if(ixh(1,ie).eq.0) cycle
       
c       Reset working arrays
        do ip=1,nip
          do k=1,nhisv
            htmp(k,ip) = 0.
          enddo
        enddo
        do k=1,nhisvue
          htmpue(k) = 0.
        enddo

c       ------------------------------------
c       Begin operations of neighboring data
       
c       Range of elements
        nstr = nrang(ii)
        nend = nrang(ii+1)-1
        do j=nstr,nend
c          Element internal sorted for this group:
c          je sorted ID for this group
c          jje internal sorted ID for this element
           je=nlist(j)
# 2635

           if(ifail(je).eq.0) cycle
           if(uid(je).gt.0) jje=nsrt(je)
           do ip=1,nip
# 2691

c             Get material history values
              if (nhisv.gt.0) then
                 do k=1,nhisv
c                   Example: sum for average over elements
                    htmp(k,ip) = htmp(k,ip) + histv(k,ip,je)
                 enddo
                 write(59,*) 'Slave element',uid(je)
                 write(59,*) 'IP no.',ip
                 write(59,*) 'Material HSV values'
                 write(59,*) histv(1:nhisv,ip,je)
                 write(59,*) '---------------------------------'
              endif
              
           enddo
c          End of loop over IPs
           
c          Get user element history values
           if (nhisvue.gt.0) then
              do k=1,nhisvue
c                Example: sum for average over elements
                 htmpue(k) = htmpue(k) + histvue(k,je)
              enddo
              write(59,*) 'Slave element',uid(je)
              write(59,*) 'Element HSV values'
              write(59,*) histvue(1:nhisvue,je)
              write(59,*) '---------------------------------'
           endif
           
        enddo
        
c       End operations of neighboring data
c       ------------------------------------
        
c       ------------------------------------
c       Begin operations on target element
        
c       Set material history values
        if (nhisv.gt.0) then
           lav=lochvh(ie)-1   
           write(59,*) 'Master element',lqfinvf(ie,2)
           do ip=1,nip
              write(59,*) 'IP no.',ip
              write(59,*) 'Material HSV values before'
              write(59,*) auxvec(lav+list(1:nhisv)+7+(ip-1)*nmtcon)
              do k=1,nhisv
                 ipos = list(k)+7+(ip-1)*nmtcon
c                Example: average over both master and slave elements
                 auxvec(lav+ipos) = (auxvec(lav+ipos) + htmp(k,ip))
     $                /(nend-nstr+2)
              enddo
              write(59,*) 'Material HSV values after'
              write(59,*) auxvec(lav+list(1:nhisv)+7+(ip-1)*nmtcon)
              write(59,*) '---------------------------------'
           enddo
        endif
        
c       Set user element history values
        if (nhisvue.gt.0) then
           lav = iuhhv(ie)-1
           write(59,*) 'Master element',lqfinvf(ie,2)
           write(59,*) 'Element HSV values before'
           write(59,*) uehh(lav+listue(1:nhisvue))
           do k=1,nhisvue
              ipos = listue(k)
c             Example: average over both master and slave elements
              uehh(lav+ipos) = (uehh(lav+ipos) + htmpue(k))/(nend
     $             -nstr+2)
           enddo
           write(59,*) 'Element HSV values after'
           write(59,*) uehh(lav+listue(1:nhisvue))
           write(59,*) '---------------------------------'
        endif

c       End operations on target element
c       ------------------------------------

c       Example for writing out element connectivity
c       ---------------------------------------------------
        write(59,*) 'Master EID:',lqfinvf(ie,2)
        do kk=1,8
           nnd(kk)=ixh(kk+1,ie)
           icc(kk)=lqfinvf(nnd(kk),1)
        enddo
        write(59,'(1x,"Nodes =",8i13)') icc(1:8)
        write(59,'(1x,"xl =", 8e13.5)') x(1,nnd(1:8))
        write(59,'(1x,"yl =", 8e13.5)') x(2,nnd(1:8))
        write(59,'(1x,"zl =", 8e13.5)') x(3,nnd(1:8))
        write(59,*) '---------------------------------'
        do j=nstr,nend
           je=nlist(j)
           if(ifail(je).eq.0) cycle
           write(59,*) 'Slave EID:',uid(je)
           if(uid(je).gt.0) then
              write(59,*) 'Slave on this CPU'
              jje=nsrt(je)
              do kk=1,8
                 nnd(kk)=ixh(kk+1,jje)
                 icc(kk)=lqfinvf(nnd(kk),1)
              enddo
              write(59,'(1x,"Nodes =",8i13)') icc(1:8)
              write(59,'(1x,"xl =", 8e13.5)') x(1,nnd(1:8))
              write(59,'(1x,"yl =", 8e13.5)') x(2,nnd(1:8))
              write(59,'(1x,"zl =", 8e13.5)') x(3,nnd(1:8))
           elseif(uid(je).lt.0) then
              lje=je-lstsld
              do kk=1,8
                 nnd(kk)=ixhr(kk,lje)
                 icc(kk)=nid(nnd(kk))
              enddo
              write(59,*) 'Slave on other CPU'
              write(59,'(1x,"Nodes =",8i13)') icc(1:8)
              write(59,'(1x,"xr =", 8e13.5)') xrmt(1,nnd(1:8))
              write(59,'(1x,"yr =", 8e13.5)') xrmt(2,nnd(1:8))
              write(59,'(1x,"zr =", 8e13.5)') xrmt(3,nnd(1:8))
           endif           
        enddo
        write(59,*) '---------------------------------'
c       ---------------------------------------------------
c       End of example for writing out element connectivity

      ENDDO

      return
      end

ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c
c User Subroutines for Keyword Reader
c
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
      subroutine rdusrkwd(iphase,iin,longkey,nbword,
     .  memh,idoff,fact,incout,
     .  iflag,txtkwd)
# 2828

c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      include 'memaia.inc'
# 1 ".\dynmem.inc" 1 
!
!     dynamic memory allocation stuff.  This has to be a C style
!     include because of the use of integer*8
!
# 25

      integer i_mem(0:1)
      real r_mem(0:1)
      integer*4 i4_mem(0:1)
      integer*8 i8_mem(0:1)
      real*4 r4_mem(0:1)
      real*8 r8_mem(0:1)
      real*8 real8_mem
      integer*8 m_mem(0:1)
      integer*8 mem8_blk(0:15)
      common/dynmem/real8_mem(0:15)
      equivalence (i_mem,r_mem,i8_mem,r8_mem,real8_mem,i4_mem,r4_mem,   
     &  m_mem,mem8_blk)

      integer*8 mem_alloc, mems_alloc,mem_realloc, memh_ptr
      integer mem_length,memh_alloc,memh_realloc,memh_length
      integer memh_enum,memh_enums,memh_attach
!      integer mem_newmark,mem_getmark,memh_getmark
      integer*8 memh_detach,memh_ralloc
      integer*8 m_to_m8
      integer*8 m_to_mm
      integer*8 m8_to_m
      integer*8 m_to_m4
      integer*8 mptr_to_m

      external mem_alloc, mems_alloc, mem_realloc, mem_length
      external memh_alloc, memh_realloc, memh_length, memh_ptr
      external memh_enum,memh_attach,memh_detach,memh_ralloc
      external memh_enums
      external m_to_m8
      external m_to_mm
      external m8_to_m
      external m_to_m4
      external mptr_to_m

      integer*8 dm_xtpz
      integer*8 dm_n45
      integer len_n45,len_n46
      common/dynmem1/                                                   
     & dm_xtpz,                                                         
     & dm_n45          
      common/dynmem1l/len_n45,len_n46
!
      integer*8 mem_allocm,mems_allocm,mem_reallocm,mem_loc
      integer memh_allocm,memh_reallocm

      external mem_allocm,mems_allocm,mem_reallocm,mem_loc
      external memh_allocm,memh_reallocm

      integer*8 mem_allocmchk,mem_allocchk,mems_allocmchk
      integer*8 mems_allocchk,mem_reallocmchk,mem_reallocchk
      integer memh_allocmchk,memh_allocchk

      external mem_allocmchk,mem_allocchk,mems_allocmchk
      external mems_allocchk,mem_reallocmchk,mem_reallocchk
      external memh_allocmchk,memh_allocchk

# 2839 "dyn21.F" 2 
c
c     In this routine, parameters are read from *USER_KEYWORD
c     in phase 1. If iflag is set to 1, the keyword reader
c     will call this routine in phase 2. The generated keyword
c     needs to be returned, until iflag is set to 0.
c
c     Main variables:
c       iphase : phase flag
c       iin    : current keyword file number
c       longkey: current keyword format
c       nbword : number of byte per word
c       memptr : pointer to i_mem memory
c
c     Offset and transformation factors from *INCLUDE_TRANSFORM
c       idoff(*): id offset numbers
c       fact(*): transformation factors
c       incout : the transformed included file will be written to dyna.inc
c                =0, no output file
c                =1, dyna.inc includes the complete transformed input
c
c       iflag  : in/out, user keyword generator is active
c       txt    : output text
c
      logical longkey
      dimension idoff(*),fact(*)
      character*(*) txtkwd
c
      character*80 mssg
      character*200 txt
      integer itxt(40)
      equivalence (itxt,txt)
      integer*8 kwdptr,memptr
c
      isexample=0
c
c---  PHASE 1: read keyword input
c
c     In phase 1, the read format can be defined arbitrarily.
c     Parameters can be stored as real a(...) or integer ia(...)
c     as shown in the example.
c
      if (iphase.eq.1) then
        mssg='reading *USER_KEYWORD'
c
        if (isexample.eq.0) then
c         skip all lines and return
   10     call gttxln (txt,lccount,1,1)
          if (txt(1:1).ne.'*')goto 10
          txtkwd=txt
          return
        endif
c
c       example: read some parameters and generate mesh for a box
c       xl,yl,zl, length of a box
c       nx,ny,nz, number of elements in each direction
c
        call gttxln (txt,lcount,2,8)
        if (longkey) then
          read (txt,'(3e20.0,3i20)',err=900)xl,yl,zl,nx,ny,nz
        else
          read (txt,'(3e10.0,3i10)',err=900)xl,yl,zl,nx,ny,nz
        endif
c
        nelem = nx*ny*nz
        nnode = (nx+1)*(ny+1)*(nz+1)
        nline = nelem+nnode+2
        nbpl  = 80
        if (longkey) nbpl=160
        nwpl  = nbpl/nbword
c
c       allocate memory
        memtot = nwpl*nline+4
        if(memh.gt.0)then
          if(memh_length(memh).lt.memtot)
     .    call memh_reallocmchk(memh,memtot,'*USER_KEYWORD buffer')
        else
          memh = memh_allocmchk(memtot,'*USER_KEYWORD buffer')
        endif
        memptr = memh_ptr(memh)
c
c       save total number of keyword cards, and current card id
        i_mem(memptr  )=nline
        i_mem(memptr+1)=0
        i_mem(memptr+2)=nbpl
        i_mem(memptr+3)=nwpl
        kwdptr=memptr+4
c
c       generate keywords
        txt='*NODE'
        call blkcpy(itxt,i_mem(kwdptr),nwpl)
        kwdptr=kwdptr+nwpl
        dx=xl/nx
        dy=yl/ny
        dz=zl/nz
        ndx=(ny+1)*(nz+1)
        ndy=(nz+1)
c       node: x,y,z
        txt=' '
        do ix=0,nx
          xx=ix*dx
          do iy=0,ny
            yy=iy*dy
            do iz=0,nz
              zz=iz*dz
              nid=ix*ndx+iy*ndy+iz+1
              if(longkey)then
                write(txt,'(t1,i20,3e20.10)')nid,xx,yy,zz
              else
                write(txt,'(t1,i8,3e16.7)')nid,xx,yy,zz
              endif
              call blkcpy(itxt,i_mem(kwdptr),nwpl)
              kwdptr=kwdptr+nwpl
            enddo
          enddo
        enddo
        txt='*ELEMENT_SOLID'
        call blkcpy(itxt,i_mem(kwdptr),nwpl)
        kwdptr=kwdptr+nwpl
c       element
        txt=' '
        npid=1
        do ix=1,nx
          nid=(ix*(ny+1)+iy)*(nz+1)+iz+1
          nx1=(ix-1)
          xx=ix*dx
          do iy=1,ny
            yy=iy*dy
            do iz=1,nz
              nid1=(ix-1)*ndx+(iy-1)*ndy+iz
              nid2=nid1+ndx
              nid3=nid2+ndy
              nid4=nid3-ndx
              nid5=nid1+1
              nid6=nid2+1
              nid7=nid3+1
              nid8=nid4+1
              neid=(ix-1)*ny*nz+(iy-1)*nz+iz
              if(longkey)then
                write(txt,'(t1,10i20)')neid,npid,
     .            nid1,nid2,nid3,nid4,nid5,nid6,nid7,nid8
              else
                write(txt,'(t1,10i8)')neid,npid,
     .            nid1,nid2,nid3,nid4,nid5,nid6,nid7,nid8
              endif
              call blkcpy(itxt,i_mem(kwdptr),nwpl)
              kwdptr=kwdptr+nwpl
            enddo
          enddo
        enddo
c
c       set the flag and return
        iflag = 1
        return
c
c---  PHASE 2: write structured input
c
c     In phase 2, return keywords. iflag should be reset to zero
c     if the last card is reached.
c     It is optional to free the memory pointer
c
      elseif (iphase.eq.2) then
        memptr = memh_ptr(memh)
        if (i_mem(memptr).le.i_mem(memptr+1)) then
c         reset iflag if it is the last card
          iflag=0
c         this is optional to free the memory
          call memh_free(memh)
          memh=0
          return
        endif
c       read the next card
        kwdptr=memptr+4
        nwpl = i_mem(memptr+3)
        kwdptr=kwdptr+i_mem(memptr+1)*nwpl
        call blkcpy(i_mem(kwdptr),itxt,nwpl)
        txtkwd = txt(1:i_mem(memptr+2))
c
        i_mem(memptr+1)=i_mem(memptr+1)+1
        return
c
      else
        goto 900
      endif
c
      return
  900 call terminn(txt,mssg,lcount,1)
      end
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c
c User Subroutines for Adaptivity
c
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
      subroutine useradap(eso,b,maxsiz64)
      use userinterface
# 3036

c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
# 1 ".\bk05.inc" 1 
      integer                                                           
     & nh01,nh02,nh03,nh04,nh05,nh06,nh07,nh08,nh09,nh10,               
     & nb01,nb02,nb03,nb04,nb05,nb06,nb07,nb08,nb09,nb10,               
     &                                         ns09,ns10,               
     & nt01,nt02,nt03,nt04,nt05,nt06,nt07,nt08,nt09,nt10,               
     & nu01,nu02,nu03,nu04,nu05,nu06,nu07,nu08,nu09,nu10,               
     & nd01,nd02,nd03,nd04,nd05,nd06,nd07,nd08,nd09,nd10,               
     & ntbqs,ihgen_flag,dmsbeta_size
      common/bk05/                                                      
     & nh01,nh02,nh03,nh04,nh05,nh06,nh07,nh08,nh09,nh10,               
     & nb01,nb02,nb03,nb04,nb05,nb06,nb07,nb08,nb09,nb10,               
     &                                         ns09,ns10,               
     & nt01,nt02,nt03,nt04,nt05,nt06,nt07,nt08,nt09,nt10,               
     & nu01,nu02,nu03,nu04,nu05,nu06,nu07,nu08,nu09,nu10,               
     & nd01,nd02,nd03,nd04,nd05,nd06,nd07,nd08,nd09,nd10,               
     & ntbqs,ihgen_flag,dmsbeta_size
!
      integer*8 dm_hmtnum,dm_hnfegp
      integer*8 dm_bmtnum,dm_bnfegp
      integer*8 dm_smtnum,dm_snfegp
      integer*8 dm_tmtnum,dm_tnfegp
!
      common/dmbk05/                                                    
     & dm_hmtnum,dm_hnfegp,                                             
     & dm_bmtnum,dm_bnfegp,                                             
     & dm_smtnum,dm_snfegp,                                             
     & dm_tmtnum,dm_tnfegp
# 3046 "dyn21.F" 2 
# 1 ".\bk07.inc" 1 
      integer n1,n2,n3,n4,n5,n6,n7,n8,n9,n10,n11,n12,n13,n14,n15,       
     & n16,n17,n18,n19,n20,n21,n22,n23,n24,n25,n26,n27,n28,n29,         
     & n30xx,n31xx,n32xx,n33xx,n34xx,n35xx,n36xx,n37xx,n38xx,n39xx,     
     & n40xx,n41,n42,n43,n44,n44a,n45,                                  
     & n46,n47,n48,n49,n50,n51,n52,n53,n54,n55,n56,n57,n58,n59,n60,n61, 
     & n62,n63,n64,n65,n66,n67,n68,n69,n70,n71,n72xx,                   
     & n73,n74,n75,n76,n77,                                             
     & n78,n79,n80,n81,n82,locend,iname,lendf
      common/bk07/n1,n2,n3,n4,n5,n6,n7,n8,n9,n10,n11,n12,n13,n14,n15,   
     & n16,n17,n18,n19,n20,n21,n22,n23,n24,n25,n26,n27,n28,n29,         
     & n30xx,n31xx,n32xx,n33xx,n34xx,n35xx,n36xx,n37xx,n38xx,n39xx,     
     & n40xx,n41,n42,n43,n44,n44a,n45,                                  
     & n46,n47,n48,n49,n50,n51,n52,n53,n54,n55,n56,n57,n58,n59,n60,n61, 
     & n62,n63,n64,n65,n66,n67,n68,n69,n70,n71,n72xx,                   
     & n73,n74,n75,n76,n77,                                             
     & n78,n79,n80,n81,n82,locend,iname,lendf
      integer n2ref,n2lab,n2mid,n2sec
      common/bk07a/n2ref,n2lab,n2mid,n2sec
# 3047 "dyn21.F" 2 
# 1 ".\bk08.inc" 1 
      integer n4f,n4g,n4h,n7a,nusir,                                    
     & mpusr,mpubr,n4i,n4j,n4k,n4l,n4m,n4n
      common/bk08/n4f,n4g,n4h,n7a,nusir,                                
     & mpusr,mpubr,n4i,n4j,n4k,n4l,n4m,n4n
# 3048 "dyn21.F" 2 
# 1 ".\bk13.inc" 1 
      integer lc0,lc1h,lc1b,lc1t,lc2,lc3,lc4,lc5,lc6,lc6e,lc6f,lc9,     
     & lc10,lc11,lc12,lc13,lc14,lc15,lc16,lc17,lc18,lb0,lb1,lb2,        
     & lc7a,lc7b,lc7c,lc7d,lc7e,lc7f,lc7g,lc7h,lc7i,lc7j,lc7k,lc7l,     
     & lc7t,lc7x,lc6g,lc6h
      common/bk13/lc0,lc1h,lc1b,lc1t,lc2,lc3,lc4,lc5,lc6,lc6e,lc6f,lc9, 
     & lc10,lc11,lc12,lc13,lc14,lc15,lc16,lc17,lc18,lb0,lb1,lb2,        
     & lc7a,lc7b,lc7c,lc7d,lc7e,lc7f,lc7g,lc7h,lc7i,lc7j,lc7k,lc7l,     
     & lc7t,lc7x,lc6g,lc6h
# 3049 "dyn21.F" 2 
# 1 ".\dynmem.inc" 1 
!
!     dynamic memory allocation stuff.  This has to be a C style
!     include because of the use of integer*8
!
# 25

      integer i_mem(0:1)
      real r_mem(0:1)
      integer*4 i4_mem(0:1)
      integer*8 i8_mem(0:1)
      real*4 r4_mem(0:1)
      real*8 r8_mem(0:1)
      real*8 real8_mem
      integer*8 m_mem(0:1)
      integer*8 mem8_blk(0:15)
      common/dynmem/real8_mem(0:15)
      equivalence (i_mem,r_mem,i8_mem,r8_mem,real8_mem,i4_mem,r4_mem,   
     &  m_mem,mem8_blk)

      integer*8 mem_alloc, mems_alloc,mem_realloc, memh_ptr
      integer mem_length,memh_alloc,memh_realloc,memh_length
      integer memh_enum,memh_enums,memh_attach
!      integer mem_newmark,mem_getmark,memh_getmark
      integer*8 memh_detach,memh_ralloc
      integer*8 m_to_m8
      integer*8 m_to_mm
      integer*8 m8_to_m
      integer*8 m_to_m4
      integer*8 mptr_to_m

      external mem_alloc, mems_alloc, mem_realloc, mem_length
      external memh_alloc, memh_realloc, memh_length, memh_ptr
      external memh_enum,memh_attach,memh_detach,memh_ralloc
      external memh_enums
      external m_to_m8
      external m_to_mm
      external m8_to_m
      external m_to_m4
      external mptr_to_m

      integer*8 dm_xtpz
      integer*8 dm_n45
      integer len_n45,len_n46
      common/dynmem1/                                                   
     & dm_xtpz,                                                         
     & dm_n45          
      common/dynmem1l/len_n45,len_n46
!
      integer*8 mem_allocm,mems_allocm,mem_reallocm,mem_loc
      integer memh_allocm,memh_reallocm

      external mem_allocm,mems_allocm,mem_reallocm,mem_loc
      external memh_allocm,memh_reallocm

      integer*8 mem_allocmchk,mem_allocchk,mems_allocmchk
      integer*8 mems_allocchk,mem_reallocmchk,mem_reallocchk
      integer memh_allocmchk,memh_allocchk

      external mem_allocmchk,mem_allocchk,mems_allocmchk
      external mems_allocchk,mem_reallocmchk,mem_reallocchk
      external memh_allocmchk,memh_allocchk

# 3050 "dyn21.F" 2 
# 1 ".\sorter.inc" 1 
!
! NOTE: IF YOU CHANGE THIS FILE PLEASE ALSO CHANGE sorter_noloc.inc
! WHICH NEEDS TO BE IDENTICAL EXCEPT FOR nnc->znnc, lczc->zlczc
!
      integer nnc,lczc,                                                 
     &    ns11, ns12,                                                   
     &    nh11, nh12, nh13, nh14, nh15, nh16,                           
     &    nt11, nt12, nt13, nt14, nt15, nt16,                           
     &    nb11, nb12, nb13, nb14, nb15, nb16,                           
     &    nu11, nu12, nu13, nu14, nu15, nu16,                           
     &    nd11, nd12, nd13, nd14, nd15, nd16,                           
     &    nd17, nd18, nd19, nd20, nd21, nd22,                           
     &    ncf26, ncf27, ncf28,                                          
     &    n_em_26, n_em_27, n_em_28,                                    
     &    nscf08, nscf09, nscf10, nscf13, nscf14,                       
     &    nhcf11, nhcf12, nhcf13, nhcf14, nhcf15,                       
     &    nh_em_11, nh_em_12, nh_em_13, nh_em_14, nh_em_15,             
     &    lccf1h, lccf1s, lc_em_1h
      common/sorter/nnc, lczc,                                          
     &    ns11, ns12,                                                   
     &    nh11, nh12, nh13, nh14, nh15, nh16,                           
     &    nt11, nt12, nt13, nt14, nt15, nt16,                           
     &    nb11, nb12, nb13, nb14, nb15, nb16,                           
     &    nu11, nu12, nu13, nu14, nu15, nu16,                           
     &    nd11, nd12, nd13, nd14, nd15, nd16,                           
     &    nd17, nd18, nd19, nd20, nd21, nd22,                           
     &    ncf26, ncf27, ncf28,                                          
     &    n_em_26, n_em_27, n_em_28,                                    
     &    nscf08, nscf09, nscf10, nscf13, nscf14,                       
     &    nhcf11, nhcf12, nhcf13, nhcf14, nhcf15,                       
     &    nh_em_11, nh_em_12, nh_em_13, nh_em_14, nh_em_15,             
     &    lccf1h, lccf1s, lc_em_1h
!
      integer*8 dm_hnsubgc,dm_hnfegc
      integer*8 dm_bnsubgc,dm_bnfegc
      integer*8 dm_snsubgc,dm_snfegc
      integer*8 dm_tnsubgc,dm_tnfegc
!
      common/dmsorter/                                                  
     & dm_hnsubgc,dm_hnfegc,                                            
     & dm_bnsubgc,dm_bnfegc,                                            
     & dm_snsubgc,dm_snfegc,                                            
     & dm_tnsubgc,dm_tnfegc
!
! The size of the sorter common block.  Used in the restart and dump
! routines.
!
      integer ISORTERSIZE
      parameter (ISORTERSIZE = 64)
# 3051 "dyn21.F" 2 
      common/bk00/numnp,numpc,numlp,neq,ndof,nlcur,numcl,numvc,
     1 ndtpts,nelmd,nmmat,numelh,numelb,numels,numelt,numdp,
     2 grvity,idirgv,nodspc,nspcor,numelh10,numels8,numelsx,numnpin,
     & numelhx,nmuxct,ndscmxh,ndscmxs,numnurb2d,nvcbox,lscmh,numnurb3d,
     & numbext,numbezt,numnurbcrv,iga_ns,iga_nels,iga_nh,iga_nelh,
     & nmexp,ndsexp,nsgexp,numelh11,iga_nbpm
      integer*8 maxsiz64
c
      dimension eso(7,*),b(1)
      real*8, pointer,contiguous :: dm_x(:)
      real, pointer,contiguous :: dm_s_auxvec(:),dm_csprop(:)
      integer, pointer,contiguous ::dm_ixs(:),dm_s_lochv(:),dm_nshpnt(:)
      integer, pointer,contiguous ::dm_mtype(:),dm_iqtype(:)
c
      call getreal8ptr('dm_x',dm_x)
      call getrealptr('dm_s_auxvec',dm_s_auxvec)
      call getrealptr('dm_csprop',dm_csprop)
      call getintegerptr('dm_ixs',dm_ixs)
      call getintegerptr('dm_s_lochv',dm_s_lochv)
      call getintegerptr('dm_nshpnt',dm_nshpnt)
      call getintegerptr('dm_mtype',dm_mtype)
      call getintegerptr('dm_iqtype',dm_iqtype)
c
      call userrefin (dm_mtype,dm_csprop,dm_x,i_mem(dm_smtnum),dm_ixs,
     +  dm_s_auxvec,dm_mtype(1+nmmat),dm_nshpnt,
     +  dm_s_lochv,eso,dm_iqtype(1+3*nmmat),maxsiz64)
c
      return
      end
      subroutine userrefin (mtype,csprop,x,mtnum,ixp,auxvec,
     + ishlfm,nshpnt,lochvs,eso,nconstp,maxsiz64)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      include 'bk06.inc'
# 1 ".\bk19.inc" 1 
      integer nconst(2000),lenma,ncneos(50),mtecom(2000),     
     & nhgshl(30)
      common/bk19/nconst,lenma,ncneos,mtecom,nhgshl
# 3092 "dyn21.F" 2 
      common/bk00/numnp,numpc,numlp,neq,ndof,nlcur,numcl,numvc,
     1 ndtpts,nelmd,nmmat,numelh,numelb,numels,numelt,numdp,
     2 grvity,idirgv,nodspc,nspcor,numelh10,numels8,numelsx,numnpin,
     3 numelhx,nmuxct,ndscmxh,ndscmxs,numnurb2d
c     common/bk28/summss,xke,xpe,time
      common/daimlr/noddie,neldie,ncunk,npersv,ivtmem
      common/ellcm2/nelnt,nelet,nstart,nelbt
      common/xcntrl/kontrl(400)
c
      real*8 x
      dimension mtype(*),csprop(24,*),x(3,*),mtnum(*),ixp(5,*),
     +          auxvec(*),ishlfm(*),nshpnt(*),lochvs(*),eso(7,*),
     +          stress(7,20),nconstp(*)
      dimension output(7)
      integer   iob28
      integer*8 maxsiz64
      integer*8 izero64,jadd64
      data izero64/0/
      data init/0/
      data output/7*0.0/
c
c     Variables in the subroutine:
c
c        numnp=number of nodal points
c        numels-neldie=number of shell elements
c
c        x(1,i)=x-coordinate of nodal point i
c        x(2,i)=y-coordinate of nodal point i
c        x(3,i)=z-coordinate of nodal point i
c
c
c        ixp - shell element connectivities (ixp(1,*)=part ID)
c                                           (ixp(2,*)=node 1)
c                                           (ixp(3,*)=node 2)
c                                           (ixp(4,*)=node 3)
c                                           (ixp(5,*)=node 4)
c
c        ipt=integration point number
c        nip=number of integration points
c
c        stress(1,ipt)=local x  stress
c        stress(2,ipt)=local y  stress
c        stress(3,ipt)=local z  stress
c        stress(4,ipt)=local xy stress
c        stress(5,ipt)=local yz stress
c        stress(6,ipt)=local zx stress
c        stress(7,ipt)=effective plastic strain
c
c     Write file with data for useradaptivity:
c
c     structure of file:
c     line 1: Number of nodes, number of elements (shell)
c     part 2: Nodal points (numnp lines)
c     part 3: Material # + Element connectivities (numels lines)
c     part 4: Element materials and stresses (numels*nip lines)
c             Material #,
c             Integration point #
c             local sigma_xx
c             local sigma_yy
c             local sigma_zz
c             local sigma_xy
c             local sigma_yz
c             local sigma_zx
c             effective plastic strain
c
      call lsopen(21,'adapt.user','formatted','unknown',ierr,0,0)
      write(21,900) numnp,numels-neldie
      write(21,915) (x(1,n),x(2,n),x(3,n),n=1,numnp)
      write(21,905) (ixp(1,nshpnt(n)),ixp(2,nshpnt(n)),
     +               ixp(3,nshpnt(n)),ixp(4,nshpnt(n)),
     +               ixp(5,nshpnt(n)),n=1,numels-neldie)
c
      do 100 n=1,numels-neldie
      nel =nshpnt(n)
      lav =lochvs(nel)
      mx=ixp(1,nel)
      if (mx.eq.0) go to 100
      iop=ishlfm(mx)
      nip=csprop(2,mx)
      mte=mtype(mx)
      nmtcon=7+nconstp(mx)
c
      do 50 ipt=1,nip
      if (mte.eq.20) then
        stress(1,ipt)=0.
        stress(2,ipt)=0.
        stress(3,ipt)=0.
        stress(4,ipt)=0.
        stress(5,ipt)=0.
        stress(6,ipt)=0.
        stress(7,ipt)=0.
      else
        call blkcpy (auxvec(lav),stress(1,ipt),7)
      endif
c
      write(21,540) mx,ipt,(stress(j,ipt),j=1,7)
      lav=lav+nmtcon
   50 continue
  100 continue
      close(21)
c
c     External program for caclulating refinement indicators
c     can be called here
c
c     call my_system('External program')
c
c     Write adapt.err file for userspecified adaptivity
c
c     The value of enerden specify
c     which element which will be refined
c
c     if enerden < 1 no refinement of element
c     if enerden > 1 refinement of element
c
c
c
c     Or refinement indicators can be calculated
c     inside the next loop
c
c     call llsopen(28,'adapt.err','unformatted','unknown',ierr,0,0)
c     rewind 28
# 3215

      call rwabsf64(iob28,'adapt.err',28,2**9,maxsiz64)

      nn=numels-neldie-nelet
      jadd64=0
      call wrabsf64(iob28,nn,1,jadd64)
      jadd64=1
c
      enerden=0.
      do 200 n=1,numels-neldie-nelet
c
c     calculate refinement for each element based
c     on the data in the "adapt.user" file
c
c     calculate the value of enerden here
c     and the value of enerden will be written to
c     the file "adapt.err"
c
      output(1)=enerden
      if (init .eq. 0) then
c       write(28) enerden,0.0,0.0,enerden,0.0,0.0,0.0
        output(4)=enerden
      else
c       write(28) enerden,0.0,0.0,eso(1,n),0.0,0.0,0.0
        output(4)=eso(1,n)
      endif
      call wrabsf64(iob28,output,7,jadd64)
      jadd64=jadd64+7
  200 continue
      kontrl(42)=jadd64
      init = init+1
c     close(28)
      jadd64=0
      call rwabsf64(iob28,'keep',0,0,0_8)
c
      return
  540 format(2i5,7(1pe15.7))
  900 format(10i8)
  905 format(5i10)
c 910 format(6(1pe12.5))
  915 format(3(1pe15.7))
      end
      subroutine uadpval(val, nmtcon, gl, ierr, gval)
# 3261

c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c   extract the solution variables at an integration point, and
c   convert into the global coordinate system
c
c***  input variables
c     val(nmtcon) solution variables at an integration point (aux14loc)
c     gl(3,3)     element local coordinate system
c     ierr        the option for the error estimation
c                 (refer to CONTROL_ADAPTIVITY Card 4, ADPERR)
c
c***  output variables
c     gval(7)     converted variables for adaptivity (upto 7 variables)
c
      implicit none
      integer nmtcon,ierr
      real val(nmtcon),gl(3,3),gval(7)
c
      real sig(7)
      real a11,a12,a13,a21,a22,a23,a31,a32,a33
      integer i
c
      if(mod(ierr,100).ne.20)return

      call blkcpy (val,sig,7)
c
c     stresses are in local coordinate system
c
      a11=sig(1)*gl(1,1)+sig(4)*gl(1,2)+sig(6)*gl(1,3)
      a12=sig(1)*gl(2,1)+sig(4)*gl(2,2)+sig(6)*gl(2,3)
      a13=sig(1)*gl(3,1)+sig(4)*gl(3,2)+sig(6)*gl(3,3)
      a21=sig(4)*gl(1,1)+sig(2)*gl(1,2)+sig(5)*gl(1,3)
      a22=sig(4)*gl(2,1)+sig(2)*gl(2,2)+sig(5)*gl(2,3)
      a23=sig(4)*gl(3,1)+sig(2)*gl(3,2)+sig(5)*gl(3,3)
      a31=sig(6)*gl(1,1)+sig(5)*gl(1,2)
      a32=sig(6)*gl(2,1)+sig(5)*gl(2,2)
      a33=sig(6)*gl(3,1)+sig(5)*gl(3,2)
c
      gval(1) = gl(1,1)*a11+gl(1,2)*a21+gl(1,3)*a31
      gval(2) = gl(2,1)*a12+gl(2,2)*a22+gl(2,3)*a32
      gval(3) = gl(3,1)*a13+gl(3,2)*a23+gl(3,3)*a33
      gval(4) = gl(1,1)*a12+gl(1,2)*a22+gl(1,3)*a32
      gval(5) = gl(2,1)*a13+gl(2,2)*a23+gl(2,3)*a33
      gval(6) = gl(1,1)*a13+gl(1,2)*a23+gl(1,3)*a33
c
c     effective plastic strain
c
      gval(7) = sig(7)

      return
      end

      subroutine uadpnorm(gval,dgval,gl,ym,pr,ierr,vnorm,dvnorm)
# 3324

c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c   calculate the error norm based on the recovered solutions, at
c   an integration point
c
c***  input variables
c     gval(7)     converted variables for adaptivity (upto 7 variables)
c     dgval(7)    errors for adaptivity (upto 7 variables)
c                 dgval(i) = gval_recoverd(i) - gval(i)
c
c     gl(3,3)     local coordinate system
c     ym          material constant, E
c     pr          material constant, u
c
c     ierr        the option for the error estimation
c                 (refer to CONTROL_ADAPTIVITY Card 4, ADPERR)
c
c   OUTPUT
c     vnorm       Norm of the numerical variables, val
c     dvnorm      Norm of the error, valrecr-val
c

      implicit none
      real gl(3,3),gval(7),dgval(7),ym,pr,vnorm,dvnorm
      integer ierr
c
      real ymi
      integer i,ierrn
c
      if(mod(ierr,100).ne.20)return
c
c     default, energy norm
c
      vnorm = 0.0
      dvnorm = 0.0
      do i=1,6
        vnorm  = vnorm  + gval(i)*gval(i)
        dvnorm = dvnorm + dgval(i)*dgval(i)
      enddo
c
      ymi = 1.0/ym
      vnorm  =  vnorm*ymi
      dvnorm = dvnorm*ymi
c
      end
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c
c User Subroutines for Coupling
c
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
      subroutine rebar_bondslip_get_nhisvar(nhisvar)
# 3385

c
c     user defined debonding law in *CONSTRAINED_BEAM_IN_SOLID
c*CONSTRAINED_BEAM_IN_SOLID
c#   slave    master     sstyp     mstyp     ctype     empty     nquad      idir
c        2         1         1         1         0                   2         1
c#   start       end               axfor
c    0.000     0.000                1001
c
c
c     here user needs to request number of history variables per coupling point
c     note: hisvar arrays allocated as float. If need double precision when
c     running single precision executable, need make nhisvar twice the
c     original value
c
      nhisvar=12
      return
      end
      subroutine rebar_bondslip_get_force(slip,dslip,dl,force,pf,hsv,
     .  userparm,lawid,temp)
# 3408

c
c in this subroutine user defines debonding properties and
c call his own debonding subroutine to get force
c*CONSTRAINED_BEAM_IN_SOLID
c#   slave    master     sstyp     mstyp     ctype     empty     nquad      idir
c        3         1         1         1         0                   2         1
c#   start       end               axfor
c    0.000     0.000                1001
c*USER_LOADING
c#   parm1     parm2     parm3     parm4     parm5     parm6     parm7     parm8
c      1.0       6.0
c
c slip ------ total slip between beam and solid
c dslip ----- incremental slip this timestep
c dl   ------ tributory length of this coupling point
c force ----- force to be calculated and passed back
c pf   ------ penalty spring stiffness (needed for implicit)
c hsv  ------ history variables to be stored
c userparm -- user defined parameters through *USER_LOADING
c lawid ----- debonding lawid. useful when having multiple debonding laws.
c temp ------ temperature from TOPAZ
      real hsv
      dimension hsv(12),cm(8),userparm(*)
c
      ys=userparm(1)
      yd=userparm(2)
      dia=userparm(3)
      stiff=ys/yd
c
      pi=3.1415926
      area=pi*dia*dl
      pshear=hsv(1)
      pslip=hsv(2)
c
      dslip=slip-pslip
      tshear=pshear+stiff*dslip
      atshear=abs(tshear)
c
c     check if elastic or plastic
c
      if (atshear.lt.ys) then
        shear=tshear
      else
        shear=tshear*ys/atshear
      endif
      force=shear*area
      pf=stiff*area 
      hsv(1)=shear
      hsv(2)=slip
      return
      end
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c
c User Subroutines for User Functions
c
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
      subroutine userinput(id,p1,p2,p3,p4,val)
# 3469

c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     mdlid     module lib id defined in *MODULE_LOAD
c     id        vairable id
c     p1,...,p4 input parameters
c     val       return value
c
      integer id
      real p1,p2,p3,p4,val
c     write(*,'(A,I8,1p4E12.4)')'USERINPUT',id,p1,p2,p3,p4
      val = 0.0
      end
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c
c User Subroutines for ALE
c
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
      subroutine alebrnswmg_ignitioncondition(fire,igni,
     .                                        iel,jel,
     .                                        mmgfr,mmgto,
     .                                        nvar,var,
     .                                        npar,par,
     .                                        ierr)
# 3502

c
c     *ALE_BURN_SWITCH_MMG user subroutine:
c     Routine providing the conditions starting the reaction in an element
c
c     fire  : ignition flag (=1 starts the burning, =0 not yet)
c     igni  : *DEFINE_FUNCTION id of a user defined function
c             setting the ignition flag (see IGNI in *ALE_BURN_SWITCH_MMG)
c     iel   : element internal id
c             lqfinvf(iel,ieltyp) provides the user id
c             with ieltyp=2 for solids
c                  ieltyp=3 for beams
c                  ieltyp=4 for shells
c     jel   : rank of iel in the list of ALE elements
c     mmgfr : *ALE_MULTI-MATERIAL_GROUP rank of the ALE reactant
c             (see MMGFR in *ALE_BURN_SWITCH_MMG)
c     mmgto : *ALE_MULTI-MATERIAL_GROUP rank of the ALE burned material
c             (see MMGTO in *ALE_BURN_SWITCH_MMG)
c     var() : list of variables provided by the user
c             (see IVAR in *ALE_BURN_SWITCH_MMG)
c     nvar  : number of variables in var()
c     par() : list of parameters provided by the user
c             (see PAR in *ALE_BURN_SWITCH_MMG)
c     npar  : number of variables in par()
c     ierr  : error flag  ierr=0: No problem
c                         ierr=1: No function or another problem
c                                 The routine won't be called anymore
c                                 An error messag could be output in messag file
c
      dimension var(*),par(*)
      fire=eval_function(igni,var,ierr)
      return
      end
      subroutine alebrnswmg_ignitionspeed(vigni,igniv,
     .                                    iel,jel,
     .                                    mmgfr,mmgto,
     .                                    nvar,var,
     .                                    npar,par,
     .                                    ierr)
# 3544

c
c     *ALE_BURN_SWITCH_MMG user subroutine:
c     Routine to compute the speed of the ignition front
c
c     vigni : ignition speed
c     igniv : *DEFINE_FUNCTION id of a user defined function
c             computing vigni (see IGNIV in *ALE_BURN_SWITCH_MMG)
c     iel   : element internal id
c             lqfinvf(iel,ieltyp) provides the user id
c             with ieltyp=2 for solids
c                  ieltyp=3 for beams
c                  ieltyp=4 for shells
c     jel   : rank of iel in the list of ALE elements
c     mmgfr : *ALE_MULTI-MATERIAL_GROUP rank of the ALE reactant
c             (see MMGFR in *ALE_BURN_SWITCH_MMG)
c     mmgto : *ALE_MULTI-MATERIAL_GROUP rank of the ALE burned material
c             (see MMGTO in *ALE_BURN_SWITCH_MMG)
c     var() : list of variables provided by the user
c             (see IVAR in *ALE_BURN_SWITCH_MMG)
c     nvar  : number of variables in var()
c     par() : list of parameters provided by the user
c             (see PAR in *ALE_BURN_SWITCH_MMG)
c     npar  : number of variables in par()
c     ierr  : error flag  ierr=0: No problem
c                         ierr=1: No function or another problem
c                                 The routine won't be called anymore
c                                 An error messag could be output in messag file
c
      dimension var(*),par(*)
      vigni=eval_function(igniv,var,ierr)
      return
      end
      subroutine alebrnswmg_reactionrate(volfrac,ireact,
     .                                   iel,jel,
     .                                   mmgfr,mmgto,
     .                                   nvar,var,
     .                                   npar,par,
     .                                   ierr)
# 3586

c
c     *ALE_BURN_SWITCH_MMG user subroutine:
c     Routine to compute the volume fraction that switches from mmgfr to mmgto
c     because of the burning reaction
c
c    volfrac: volume fraction that switches from mmgfr to mmgto
c     ireact: *DEFINE_FUNCTION id of a user defined function
c             computing frac (see IREACT in *ALE_BURN_SWITCH_MMG)
c     iel   : element internal id
c             lqfinvf(iel,ieltyp) provides the user id
c             with ieltyp=2 for solids
c                  ieltyp=3 for beams
c                  ieltyp=4 for shells
c     jel   : rank of iel in the list of ALE elements
c     mmgfr : *ALE_MULTI-MATERIAL_GROUP rank of the ALE reactant
c             (see MMGFR in *ALE_BURN_SWITCH_MMG)
c     mmgto : *ALE_MULTI-MATERIAL_GROUP rank of the ALE burned material
c             (see MMGTO in *ALE_BURN_SWITCH_MMG)
c     var() : list of variables provided by the user
c             (see IVAR in *ALE_BURN_SWITCH_MMG)
c     nvar  : number of variables in var()
c     par() : list of parameters provided by the user
c             (see PAR in *ALE_BURN_SWITCH_MMG)
c     npar  : number of variables in par()
c     ierr  : error flag  ierr=0: No problem
c                         ierr=1: No function or another problem
c                                 The routine won't be called anymore
c                                 An error messag could be output in messag file
c
      dimension var(*),par(*)
      volfrac=eval_function(ireact,var,ierr)
      return
      end
      subroutine lagpor_getab_userdef(ab,iel,iuserdef,
     .                                ncon,ix,
     .                                xloc,yloc,zloc,
     .                                auxvec,locaux,
     .                                ro,cm,
     .                                x,v,a,
     .                                xms,tt,ncycle,tmpnd)
# 3630

c
c    *SET_POROUS_LAGRANGIAN: user defined Aij and Bij matrix
c
      real*8 x
      dimension ab(18),ix(ncon,*),xloc(3),yloc(3),zloc(3),
     .          auxvec(*),locaux(*),ro(*),cm(*),
     .          x(3,*),v(3,*),a(3,*),xms(*),tmpnd(*)
c
c ab(j) for j=1,9  : Aij matrix
c                    Axx=ab(1), Axy=ab(2), ... , Azz=ab(9)
c
c ab(j) for j=10,18: Bij matrix
c                    Bxx=ab(10), Bxy=ab(11), ... , Bzz=ab(18)
c
c iel              : internal Lagrangian element ID (structure element)
c                    get user ID with lqfinvf(iel,2) if ncon=9
c                                     lqfinvf(iel,3) if ncon=5
c                                     lqfinvf(iel,4) if ncon=4
c
c iuserdef         : 6th parameter on the 1st line of *SET_POROUS_LAGRANGIAN
c
c ncon             : part ID + number of nodes connected to the elements
c                    ncon=9 : solids
c                    ncon=5 : shells
c                    ncon=4 : beams
c
c ix(j,iel)        : ix(1,iel) : part ID for the element iel
c                    ix(2,iel) : 1st node of the element iel
c                    .
c                    .
c                    .
c                    ix(ncon,iel) : (ncon-1)th node of the element iel
c
c xloc(j)          : x-axis of the local coordinate system attached to iel
c yloc(j)          : y-axis of the local coordinate system attached to iel
c zloc(j)          : z-axis of the local coordinate system attached to iel
c
c locaux(iel)           : pointer to the auxiliary variables in the vector auxvec
c auxvec(locaux(iel)+j) : auxiliary variables of the element iel
c                         auxvec(locaux(iel)+1) : xx-stress
c                         auxvec(locaux(iel)+2) : yy-stress
c                         auxvec(locaux(iel)+3) : zz-stress
c                         auxvec(locaux(iel)+4) : xy-stress
c                         auxvec(locaux(iel)+5) : yz-stress
c                         auxvec(locaux(iel)+6) : xz-stress
c                         auxvec(locaux(iel)+7) : plastic strain
c The history variables depends on the material (see histlist.txt)
c
c ro(ix(1,iel))    : initial density
c
c cm               : list of keyword inputs from *NAT
c
c x(3,nd)          : position of the node nd (double precision)
c
c v(3,nd)          : velocity of the node nd
c
c a(3,nd)          : acceleration of the node nd
c
c xms(nd)          : inverse of the nodal mass
c
c tt               : time
c
c ncycle           : current cycle
c
c tmpnd(nd)        : nodal temperature
c
      do j=1,18
        ab(j)=0.0
      enddo
      return
      end
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c
c User Subroutines for Airbag
c
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
      subroutine airusr (rbu,rbv,rba,time,dt1,dt2,param,hist,itrnon,
     . rbug,rbvg,rbag,icnv)
# 3712

c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     user subroutine to initiate the inflation of the airbag
c
c     variables
c
c     displacements are defined at time n+1 in local system
c     velocites are defined at time n+1/2 in local system
c     accelerations are defined at time n in local system
c
c         rbu(1-3) total displacements in the local xyz directions
c         rbu(3-6) total rotations about the local xyz axes
c         rbv(1-3) velocities in the local xyz directions
c         rbv(3-6) rotational velocities about the local xyz axes
c         rba(1-3) accelerations in the local xyz directions
c         rba(3-6) rotational accelerations about the local xyz axes
c         time is the current time
c         dt1 is time step size at n-1/2
c         dt2 is time step size at n+1/2
c         param is user defined input parameters
c         hist is user defined history variables
c         itrnon is a flag to turn on the airbag inflation
c         rbug,rbvg,rbag, are similar to rbu,rbv,rba but are defined
c                         globally.
c         icnv is the airbag ID
c
c     the user subroutine sets the variable itrnon to:
c
c           itrnon=0 bag is not inflated
c           itrnon=1 bag inflation begins and this subroutine is
c                    not called again
c
      include 'iounits.inc'
      dimension rbu(6),rbv(6),rba(6),param(25),hist(25),
     . rbug(6),rbvg(6),rbag(6)
c
      itrnon=0
      ra=sqrt(rba(1)**2+rba(2)**2+rba(3)**2)
      if (ra.gt.param(1)) then
        itrnon=1
c       write(iotty,100) time
c       write(iohsp,100) time
c       write(iomsg,100) time
        rerdat(1)=time
        call lsmsg(0,MSG_SOL+1354,ioall,ierdat,rerdat,cerdat,0)
      endif
c100  format (' Airbag activated at time ',1pe10.3)
c
      return
      end
      subroutine user_inflator(V,P,T,tt,dt,
     .                       xdot,temp,dV)
# 3774

c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c   calculate the error norm based on the recovered solutions, at
c   an integration point
c
c***  INPUT VARIABLES
c     V           volume
c     P           pressure
c     T           Temperature
c     tt          time
c     dt          delta time
c
c   OUTPUT
c     xdot        total mass release druing dt
c     temp        gas temperature
c     dV          volume increases due to burning
c
      implicit none
      real V,P,T,tt,dt
      real xdot,temp,dV
c
      dV = 0.
      temp = 296.0
      xdot = 2.0e-3*dt
      if(tt.gt.0.002) xdot = 0.
c      Print *,'xdot =',xdot,dt,tt
c
      return
      end
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c
c Utilities for User Subroutine Development
c
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
      subroutine usermsg(msg)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     print warning message
c
      include 'iounits.inc'
      include 'shlioc.inc'
      character*(*) msg
c
c     write(iotty,2100) msg
c     write(iohsp,2100) msg
c     write(iomsg,2100) msg
c
      if (ioshl(1069).eq.0) then
        cerdat(1)=msg
        call lsmsg(1,MSG_SOL+1147,ioall,ierdat,rerdat,cerdat,0)
      else
        cerdat(1)=msg
        call lsmsg(3,MSG_SOL+1147,ioall,ierdat,rerdat,cerdat,0)
      endif
c
c2100 format(/
c    1 ' *** Warning'
c    2 5x,'Default ',a,' is used',/,
c    3 5x,'Please check user material library')
c
      return
      end
      subroutine usrdmp (ioflg,iobuf,jadd64,maxsiz64,lendhu)
# 3853

c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     dump out or read files
c
c     ioflag -
c         =0 return the length of magusr to lendhu
c         =1 read user defined data
c         =2 dump user defined data
c         useful for plot files etc.
c
      include 'bk06.inc'
      parameter (magusr=1)
      common/usrcom/usr(magusr)
      integer   iobuf
      integer*8 jadd64,maxsiz64
c
      magusrr=magusr
      if (magusrr.eq.1) return
c     if (magusr.eq.1) return
c
c     return the lenght of magusr
c
      if (ioflg.eq.0) then
        lendhu=magusr
c
c     read user's data
c
      elseif (ioflg.eq.1) then
        call rdabsf64 (iobuf,usr,magusr,jadd64,ioerr)
        jadd64=jadd64+magusr
c
c     dump user's data
c
      elseif (ioflg.eq.2) then
        call wrabsf64 (iobuf,usr,magusr,jadd64)
        jadd64=jadd64+magusr
      endif
c
      return
      end
# 4052

# 4081

# 4233

      subroutine uinstability(value,mte,cm,cma,sig,epsp,hsvs)
      implicit none
      integer mte
      real value,cm(*),cma(*),sig(*),epsp,hsvs(*)
c     set value to the level of instability, between 0 and 1, for output
      value=0.
      return
      end
      subroutine udamage(value,mte,cm,cma,sig,epsp,hsvs)
      implicit none
      integer mte
      real value,cm(*),cma(*),sig(*),epsp,hsvs(*)
c     set value to the level of damage, between 0 and 1, for output
      value=0.
      return
      end
