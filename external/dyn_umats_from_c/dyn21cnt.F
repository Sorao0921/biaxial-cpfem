# 1 "dyn21cnt.F"
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





# 2 "dyn21cnt.F" 2 
# 1 ".\define2.inc" 1 



# 3 "dyn21cnt.F" 2 
      subroutine usrtbrk(dx,dy,dz,tn1,tn2,tn3,xx1,xx2,xx3,xx4,stf,fni,
     . ctocn,cn0,prmtrs2,ftxi,ftyi,ftzi,areasn,dmg,xfail,
     . iopt,node,ifflag,iuser,vslvx,vslvy,vslvz,dt2,crv,nnpcrv,
     . aream,idif,time,nintcy,idms,temp,uhis)
# 10

c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     user-defined tiebreak models
c
c******************************************************************
      include 'nlqparm'
      include 'implicit1.inc'
      include 'iounits.inc'
# 1 ".\implicit2.inc" 1 
c   ... implicit common ...
      integer lnodim,ndofpn,nnpke,melemt,imlft,imllt,imnnm1,is17loc,
     &        is18loc,imp_mxe,imp_elm_type
      common/bki03iloc/lnodim(nlq,48),ndofpn,nnpke,melemt,imlft,imllt,
     &                 imnnm1,is17loc,is18loc,imp_mxe,imp_elm_type
c
      real ske,sme,ske_unsym(nlq,100,100),lumped_mass
      equivalence ( ske, ske_unsym )
      common/bki03rloc/ske(nlq,10440),sme(nlq,10440),
     &                 lumped_mass(nlq,27)
c
      integer lmke
      common/bki04iloc/lmke(nlq,144)
# 26 "dyn21cnt.F" 2 
c
      real*8 xx1,xx2,xx3,xx4
      dimension xx1(3),xx2(3),xx3(3),xx4(3)
      dimension fni(3,3),prmtrs2(*),crv(lq1,2,*),uhis(*)
      integer nnpcrv(*)
      integer node
c
c     global to local transformation matrix
c$omp threadprivate (/bki04iloc/)
c$omp threadprivate (/bki03rloc/)
c$omp threadprivate (/bki03iloc/)
      if (iopt.ne.2) then
        ts1=xx2(1)-xx1(1)
        ts2=xx2(2)-xx1(2)
        ts3=xx2(3)-xx1(3)
        omag=1./max(1.e-10,sqrt(ts1**2.+ts2**2.+ts3**2.))
        ts1=omag*ts1
        ts2=omag*ts2
        ts3=omag*ts3
        tt1=tn2*ts3-tn3*ts2
        tt2=tn3*ts1-tn1*ts3
        tt3=tn1*ts2-tn2*ts1
      endif
c
c     relative crack displacements in local system
      q3=dx*tn1+dy*tn2+dz*tn3
      if (iopt.ne.2) then
        q2=dx*ts1+dy*ts2+dz*ts3
        q1=dx*tt1+dy*tt2+dz*tt3
        qt=max(1.e-12,sqrt(q1**2+q2**2))
      else
        ts1=dx-q3*tn1
        ts2=dy-q3*tn2
        ts3=dz-q3*tn3
        omag=1./max(1.e-20,sqrt(ts1**2+ts2**2+ts3**2))
        ts1=omag*ts1
        ts2=omag*ts2
        ts3=omag*ts3
        qt=dx*ts1+dy*ts2+dz*ts3
      endif
c
c     relative velocities
      vel_n=vslvx*tn1+vslvy*tn2+vslvz*tn3
      if (iopt.ne.2) then
        vel_1=vslvx*ts1+vslvy*ts2+vslvz*ts3
        vel_2=vslvx*tt1+vslvy*tt2+vslvz*tt3
        vel_t=max(1.e-12,sqrt(vel_1**2+vel_2**2))
      else
        vel_t=vslvx*ts1+vslvy*ts2+vslvz*ts3
      endif
c
c     stiffness from input (cn0>0) or penalty stiffness (cn0=0)
c     if value from input is used, stability of contact is NOT assured!
      if (cn0.gt.1.0e-9) then
        cn=cn0
        ct=cn*abs(ctocn)
      else
        if (iopt.ne.2) then
          stif=stf/areasn
        else
          stif=stf
        endif
        if (ctocn.eq.0.0) then
          ct=stif
          cn=stif
        else if (ctocn.le.1.0) then
          ct=stif*ctocn
          cn=stif
        else if (ctocn.gt.1.0) then
          ct=stif
          cn=stif/ctocn
        endif
      endif
c
c     characteristic element length rle = sqrt(area)
      x1i=xx1(1)
      y1i=xx1(2)
      z1i=xx1(3)
      x2i=xx2(1)
      y2i=xx2(2)
      z2i=xx2(3)
      x3i=xx3(1)
      y3i=xx3(2)
      z3i=xx3(3)
      x4i=xx4(1)
      y4i=xx4(2)
      z4i=xx4(3)
      d21=sqrt((x1i-x2i)**2+(y1i-y2i)**2+(z1i-z2i)**2)
      d32=sqrt((x2i-x3i)**2+(y2i-y3i)**2+(z2i-z3i)**2)
      d31=sqrt((x3i-x1i)**2+(y3i-y1i)**2+(z3i-z1i)**2)
      s123=.5*(d21+d32+d31)
      area1=sqrt(s123*(s123-d21)*(s123-d32)*(s123-d31))
      d43=sqrt((x4i-x3i)**2+(y4i-y3i)**2+(z4i-z3i)**2)
      if (d43.lt.1.e-9) then
c       trias in mixed meshes: use factor of 2
        rle=sqrt(2.*area1)
      else
        d41=sqrt((x1i-x4i)**2+(y1i-y4i)**2+(z1i-z4i)**2)
        s134=.5*(d41+d43+d31)
        area2=sqrt(s134*(s134-d41)*(s134-d43)*(s134-d31))
        rle=sqrt(area1+area2)
      endif
c
      sig_n=0.0
      sig_t=0.0
      dmgold=dmg
      ioffset=iuser-1
      ifail=0
      ifflagl=ifflag-100*ioffset
c
      if (ifflagl.eq.101) then
        call utb101(sig_n,sig_t,q3,qt,vel_n,vel_t,cn,ct,prmtrs2,uhis,
     .   dmg,idif,node,idms,areasn,aream,time,dt2,nintcy,crv,nnpcrv,
     .   temp,ifail,ioffset)
      elseif (ifflagl.eq.102) then
        call utb102(sig_n,sig_t,q3,qt,vel_n,vel_t,cn,ct,prmtrs2,uhis,
     .   dmg,idif,node,idms,areasn,aream,time,dt2,nintcy,crv,nnpcrv,
     .   temp,ifail,ioffset)
      elseif (ifflagl.eq.103) then
        call utb103(sig_n,sig_t,q3,qt,vel_n,vel_t,cn,ct,prmtrs2,uhis,
     .   dmg,idif,node,idms,areasn,aream,time,dt2,nintcy,crv,nnpcrv,
     .   temp,ifail,ioffset)
      elseif (ifflagl.eq.104) then
        call utb104(sig_n,sig_t,q3,qt,vel_n,vel_t,cn,ct,prmtrs2,uhis,
     .   dmg,idif,node,idms,areasn,aream,time,dt2,nintcy,crv,nnpcrv,
     .   temp,ifail,ioffset)
      elseif (ifflagl.eq.105) then
        call utb105(sig_n,sig_t,q3,qt,vel_n,vel_t,cn,ct,prmtrs2,uhis,
     .   dmg,idif,node,idms,areasn,aream,time,dt2,nintcy,crv,nnpcrv,
     .   temp,ifail,ioffset)
      endif
c
      fni(1,1)=sig_n
      if (q3.le.0.0.and.iopt.eq.0) fni(1,1)=cn*q3
      fst=sig_t
      dmgnew=dmg
c
c     local to global and implicit
      if (iopt.eq.2) then
        r=1.0-dmg
        ftxi=tn1*fni(1,1)+ts1*fst
        ftyi=tn2*fni(1,1)+ts2*fst
        ftzi=tn3*fni(1,1)+ts3*fst
        if (is17loc.ne.0) then
          if (dmgnew.le.dmgold) then
            fni(1,1)=r*(cn*tn1*tn1+ct*ts1*ts1)
            fni(1,2)=r*(cn*tn1*tn2+ct*ts1*ts2)
            fni(1,3)=r*(cn*tn1*tn3+ct*ts1*ts3)
            fni(2,1)=r*(cn*tn2*tn1+ct*ts2*ts1)
            fni(2,2)=r*(cn*tn2*tn2+ct*ts2*ts2)
            fni(2,3)=r*(cn*tn2*tn3+ct*ts2*ts3)
            fni(3,1)=r*(cn*tn3*tn1+ct*ts3*ts1)
            fni(3,2)=r*(cn*tn3*tn2+ct*ts3*ts2)
            fni(3,3)=r*(cn*tn3*tn3+ct*ts3*ts3)
          else
            fni(1,1)=0.
            fni(1,2)=0.
            fni(1,3)=0.
            fni(2,1)=0.
            fni(2,2)=0.
            fni(2,3)=0.
            fni(3,1)=0.
            fni(3,2)=0.
            fni(3,3)=0.
          endif
          areai=1./max(1.e-20,areasn)
          fni(1,1)=(fni(1,1)+r*ct*(1.-tn1*tn1-ts1*ts1))*areai
          fni(1,2)=(fni(1,2)+r*ct*(  -tn1*tn2-ts1*ts2))*areai
          fni(1,3)=(fni(1,3)+r*ct*(  -tn1*tn3-ts1*ts3))*areai
          fni(2,1)=(fni(2,1)+r*ct*(  -tn2*tn1-ts2*ts1))*areai
          fni(2,2)=(fni(2,2)+r*ct*(1.-tn2*tn2-ts2*ts2))*areai
          fni(2,3)=(fni(2,3)+r*ct*(  -tn2*tn3-ts2*ts3))*areai
          fni(3,1)=(fni(3,1)+r*ct*(  -tn3*tn1-ts3*ts1))*areai
          fni(3,2)=(fni(3,2)+r*ct*(  -tn3*tn2-ts3*ts2))*areai
          fni(3,3)=(fni(3,3)+r*ct*(1.-tn3*tn3-ts3*ts3))*areai
        endif
        if (isolvr(18).eq.0) then
          dmg=dmgnew
          xfail=dmg
        endif
      else
        ft=(areasn*fst/qt)*q1
        fs=(areasn*fst/qt)*q2
        fni(1,1)=areasn*fni(1,1)
c
        ftxi=ts1*fs+tt1*ft
        ftyi=ts2*fs+tt2*ft
        ftzi=ts3*fs+tt3*ft
c
        if (ifail.eq.1) then
          xfail=1.0
          ftxi=0.0
          ftyi=0.0
          ftzi=0.0
        else
          xfail=0.0
        endif
      endif
c
      return
      end
      subroutine utb101(sig_n,sig_t,disp_n,disp_t,vel_n,vel_t,cn,ct,
     . uparm,uhis,dmg,idcon,idsn,idms,areasn,areams,time,dt2,ncycle,
     . crv,nnpcrv,temp,ifail,ioffset)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     User subroutine for tiebreak contact: OPTION=101
c
c     Purpose: To define normal and tangential stresses
c              and possible failure
c              in a contact with tiebreak connection
c              (*CONTACT_AUTOMATIC_..._TIEBREAK_USER)
c
c     Variables:
c
c     sig_n,sig_t    = normal and tangential stress (output)
c     disp_n,disp_t  = normal and tangential displacement (input)
c     vel_n,vel_t    = normal and tangential relative velocity (input)
c     cn,ct          = normal and tangential stiffness (input)
c     uparm          = user defined tiebreak parameters (input)
c     uhis           = user defined tiebreak history variables (input/output)
c     dmg            = damage value (input/output)
c     idcon          = contact id (input)
c     idsn           = slave node id (input)
c     idms           = master segment id (input)
c     areasn         = slave node area (input)
c     areams         = master segment area (input)
c     time           = current solution time (input)
c     dt2            = time step size (input)
c     ncycle         = number of current cycle (input)
c     crv            = curve array (input)
c     nnpcrv         = # of discretization points per crv()
c     temp           = temperature (input, available for coupled analysis)
c     ifail          = failure flag (output)
c                      0:not failed, 1:failed
c     ioffset        = offset flag (input)
c                      0:no offset, 1:with offset for shells
c
      include 'iounits.inc'
      include 'nlqparm'
c
      dimension uparm(16),uhis(*),crv(lq1,2,*),nnpcrv(*)
      integer idsn
c
c     input parameters
      disp_fail=uparm(1)
      if (disp_fail.eq.0.0) disp_fail=1.e+20
c
c     stresses
      dmg=0.0
      if (disp_n.gt.disp_fail) dmg=1.0
      sig_t=(1.0-dmg)*ct*disp_t
      sig_n=(1.0-dmg)*cn*disp_n
c
c     failure
      if (disp_n.gt.disp_fail) ifail=1
c
      return
      end
      subroutine utb102(sig_n,sig_t,disp_n,disp_t,vel_n,vel_t,cn,ct,
     . uparm,uhis,dmg,idcon,idsn,idms,areasn,areams,time,dt2,ncycle,
     . crv,nnpcrv,temp,ifail,ioffset)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     User subroutine for tiebreak contact: OPTION=102
c
      include 'iounits.inc'
      include 'nlqparm'
c
      dimension uparm(16),uhis(*),crv(lq1,2,*),nnpcrv(*)
      integer idsn
c
c
c
      return
      end
      subroutine utb103(sig_n,sig_t,disp_n,disp_t,vel_n,vel_t,cn,ct,
     . uparm,uhis,dmg,idcon,idsn,idms,areasn,areams,time,dt2,ncycle,
     . crv,nnpcrv,temp,ifail,ioffset)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     User subroutine for tiebreak contact: OPTION=103
c
      include 'iounits.inc'
      include 'nlqparm'
c
      dimension uparm(16),uhis(*),crv(lq1,2,*),nnpcrv(*)
      integer idsn
c
c
c
      return
      end
      subroutine utb104(sig_n,sig_t,disp_n,disp_t,vel_n,vel_t,cn,ct,
     . uparm,uhis,dmg,idcon,idsn,idms,areasn,areams,time,dt2,ncycle,
     . crv,nnpcrv,temp,ifail,ioffset)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     User subroutine for tiebreak contact: OPTION=104
c
      include 'iounits.inc'
      include 'nlqparm'
c
      dimension uparm(16),uhis(*),crv(lq1,2,*),nnpcrv(*)
      integer idsn
c
c
c
      return
      end
      subroutine utb105(sig_n,sig_t,disp_n,disp_t,vel_n,vel_t,cn,ct,
     . uparm,uhis,dmg,idcon,idsn,idms,areasn,areams,time,dt2,ncycle,
     . crv,nnpcrv,temp,ifail,ioffset)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     User subroutine for tiebreak contact: OPTION=105
c
      include 'iounits.inc'
      include 'nlqparm'
c
      dimension uparm(16),uhis(*),crv(lq1,2,*),nnpcrv(*)
      integer idsn
c
c
c
      return
      end
      subroutine mortar_usrfrc(init,mfrc,nprm,cprm,shst,mhst,icnt,
     1     selm,sprt,styp,stmp,seps,shis,
     2     melm,mprt,mtyp,mtmp,meps,mhis,
     3     cprs,vtan,crv,nnpcrv,dt)
# 387

      implicit none
      include 'nlqparm'
      include 'iounits.inc'
      logical init
      real mfrc,cprm(*),shst(*),mhst(*),cprs,vtan,stmp,mtmp,crv(lq1,2,*)
      real shis(*),mhis(*),seps,meps,dt
      integer selm,sprt,melm,mprt,nprm,icnt,nnpcrv(*)
      character*5 styp,mtyp
      real sscl,mscl,slope
c
c     User friction routine called from the Mortar contact,
c     purpose is to define the friction coefficient mfrc
c
c     During the initialization phase (init=.true.) history
c     variables may be initialized to their initial values
c
c     During the solution phase (init=.false.) only
c     mfrc and shst/mhst may be changed, all other variables are
c     to be regarded as constant inputs
c
c     Variables:
c
c     init = initialization phase (.true. or .false.)
c     mfrc = friction coefficient (output)
c     nprm = number of user friction parameters
c     cprm = list of user friction parameters
c     shst = slave friction history variables (input/output)
c     mhst = master friction history variables (input/output)
c     icnt = contact interface id
c     selm = element id for slave segment
c     sprt = part id for slave segment
c     styp = element type for slave segment
c            ('beam ','solid','shell' or 'tshel')
c     stmp = temperature of slave segment (n/a during initialization)
c     seps = effective plastic strain on slave side
c     shis = material history variables for the slave segment
c     melm = element id for master segment (n/a during initialization)
c     mprt = part id for master segment (n/a during initialization)
c     mtyp = element type for slave segment
c            ('beam ','solid','shell' or 'tshel',
c            n/a during initialization))
c     mtmp = temperature of master segment (n/a during initialization)
c     meps = effective plastic strain on master side
c     mhis = material history variables for the master segment
c     cprs = contact interface pressure (n/a during initialization)
c     vtan = tangential relative sliding velocity (n/a during initialization)
c     crv  = curve object (to be used in evaluating curve/table,
c            n/a during initialization)
c     nnpcrv = curve parameters (to be used in evaluating curve/table,
c            n/a during initialization)
c     dt   = time step
c
      real dmdp,dmdv
      if (cprm(1).gt.0.) then
c     extract coefficient of friction mfrc from table, as function
c     of contact pressure cprs and relative sliding velocity vtan,
c     see Appendix A for usage of tabval, this is equivalent to the
c     option FS=2 on *CONTACT_... and the table id FD is here represented
c     by cprm(1)
c
c     Addendum after 2d friction is supported,
c     cprm(2) and cprm(3) are optional scaling curves as function of
c     temperature, friction coefficient is scaled accordingly
c
      call tabval(crv,nnpcrv,-cprm(1),cprs,
     1     mfrc,dmdp,vtan,dmdv)
      if (cprm(2).gt.0.) then
         call crvval(crv,nnpcrv,-cprm(2),stmp,sscl,slope)
         mfrc=mfrc*sscl
      endif
      if (cprm(3).gt.0.) then
         call crvval(crv,nnpcrv,-cprm(3),mtmp,mscl,slope)
         mfrc=mfrc*mscl
      endif
      else
c     friction coefficient decays based on sliding distance, stored on
c     slave and master side as history variable #1
      shst(1)=shst(1)+dt*vtan
      mhst(1)=mhst(1)+dt*vtan
      mfrc=cprm(3)+
     1     cprm(4)*exp(cprm(1)*shst(1))+
     2     cprm(5)*exp(cprm(2)*mhst(1))
      endif
c     example of debug output, change .false. to .true. to activate,
c     use iotty for standard out, iomsg for message file and iohsp for d3hsp
      if (.false.) then
         write (iomsg,1) styp,selm,sprt,mtyp,melm,mprt,mfrc,cprs,vtan
      endif
      return
 1    format(/
     . '     Slave segment on ',a5,' element ',i10,' of ',/,
     . '     part ',i10,' is in contact with master segment',/,
     . '     on ',a5,' element ',i10,' of part ',i10,' with',/,
     . '     a friction coefficient of ',e14.7,'.',/,
     . '     The contact pressure is ',e14.7,' and the relative',/,
     . '     sliding velocity is ',e14.7,'.')
      end
      subroutine mortar_usrtie(tid,init,tie,nprm,cprm,
     .     shst,mhst,icnt,
     1     selm,sprt,styp,stmp,seps,shis,
     2     melm,mprt,mtyp,mtmp,meps,mhis,
     3     cprs,cshr,crv,nnpcrv,time,dt)
# 493

      implicit none
      include 'nlqparm'
      include 'iounits.inc'
      logical init,tie
      real cprm(*),shst(*),mhst(*),cprs,cshr,stmp,mtmp,crv(lq1,2,*)
      real shis(*),mhis(*),seps,meps,time,dt
      integer tid,selm,sprt,melm,mprt,nprm,icnt,nnpcrv(*)
      character*5 styp,mtyp
c
c     User tie routine called from the Mortar contact,
c     purpose is to define the condition for tying
c
c     During the initialization phase (init=.true.) history
c     variables may be initialized to their initial values
c
c     During the solution phase (init=.false.) only
c     tie and shst/mhst may be changed, all other variables are
c     to be regarded as constant inputs
c
c     Variables:
c
c     tid  = tie interface id,
c            negative of first parameter on tied weld optional card
c     tie  = set to .true. if tie condition is met, otherwise .false.
c     init = initialization phase (.true. or .false.)
c     nprm = number of user tie parameters,
c            fourth parameter on tied weld optional card
c     cprm = list of user tie parameters, use only nprm
c     shst = tie history variables slave (input/output)
c     mhst = tie history variables master (input/output)
c     icnt = contact interface id
c     selm = element id for slave segment
c     sprt = part id for slave segment
c     styp = element type for slave segment
c            ('beam ','solid','shell' or 'tshel')
c     stmp = temperature of slave segment (n/a during initialization)
c     seps = effective plastic strain on slave side
c     shis = material history variables for the slave segment
c     melm = element id for master segment (n/a during initialization)
c     mprt = part id for master segment (n/a during initialization)
c     mtyp = element type for slave segment
c            ('beam ','solid','shell' or 'tshel',
c            n/a during initialization))
c     mtmp = temperature of master segment (n/a during initialization)
c     meps = effective plastic strain on master side
c     mhis = material history variables for the master segment
c     cprs = contact interface pressure (n/a during initialization)
c     cshr = contact interface shear stress (n/a during initialization)
c     crv  = curve object (to be used in evaluating curve/table,
c            n/a during initialization)
c     nnpcrv = curve parameters (to be used in evaluating curve/table,
c            n/a during initialization)
c     time = simulation time
c     dt   = simulation time step
c
      if (tid.eq.1) then
c     sample model 1,
c     tie when plastic strain in slave exceeds value of first parameter
         tie=seps.gt.cprm(1)
      endif
      if (tid.eq.2) then
c     sample model 2,
c     tie when yield stress in master exceeds value of first parameter
         tie=mhis(5).gt.cprm(1)
      endif
      if (tid.eq.101) then
c     sample model 101,
c     tie at a certain time, and meanwhile increment "impulse density"
         shst(1)=shst(1)+cprm(1)*cprs*dt;
         tie=time.gt.cprm(2).and.cprs.gt.cprm(3)
      endif
c     example of debug output, for sample models 1 and 2, set second parameter to positive,
c     use iotty for standard out, iomsg for message file and iohsp for d3hsp
      if ((tid.eq.1.or.tid.eq.2.or.tid.eq.101).and.cprm(2).gt.0.) then
         if (tie) then
            write (iomsg,1) styp,selm,sprt,mtyp,melm,mprt,time,cprs,cshr
         endif
      endif
      return
 1    format(/
     . '     Slave segment on ',a5,' element ',i10,' of ',/,
     . '     part ',i10,' is tied to master segment',/,
     . '     on ',a5,' element ',i10,' of part ',i10,' at',/,
     . '     time ',e14.7,'. The contact pressure is ',e14.7,' and',/,
     . '     the contact shear stress is ',e14.7,'.')
      end
      subroutine mortar_usrtbrk(tid,dmg,
     1     pn,ps,iconv,
     2     dpndn,dpnds,dpsdn,dpsds,istif,
     3     prm,hst,whst,
     4     selm,melm,
     5     sprt,mprt,
     6     styp,mtyp,
     7     dn,ds,
     8     en,es,
     9     ts,tm,
     .     seps,meps,
     .     shis,mhis,
     .     time,dt)
# 596

      implicit none
      include 'nlqparm'
      include 'iounits.inc'
      integer tid
      real dmg
      real pn,ps
      integer iconv
      real dpndn,dpnds,dpsdn,dpsds
      integer istif
      real prm(*),hst(*),whst(*)
      integer selm,melm
      integer sprt,mprt
      character*5 styp,mtyp
      real dn,ds
      real en,es
      real ts,tm
      real seps,meps
      real shis(*),mhis(*)
      real time,dt
c
      real pd
c
c     User tiebreak routine called from the Mortar contact,
c     purpose is to increment damage in contact to simulate delamination
c
c     Variables:
c
c     tid  = tiebreak interface id, in, number between 101 and 105
c     dmg  = damage, in/out, unitless, should be increasing and between
c            0 (completely tied) and 1 (completely released)
c     pn   = normal traction, out, unit pressure,
c            acting in the direction of normal
c     ps   = tangential traction, out, unit pressure,
c            acting in the direction of tangential separation
c     iconv= flag for converged step, in, check iconv.eq.0
c     dpndn= tangent of normal traction wrt normal separation, out, unit pressure/length,
c            needed when istif.ne.0
c     dpnds= tangent of normal traction wrt tangential separation, out, unit pressure/length,
c            NOTE that dpnds must be equal to dpsdn, needed when istif.ne.0
c     dpsdn= tangent of tangential traction wrt normal separation, out, unit pressure/length,
c            NOTE that dpsdn must be equal to dpnds, needed when istif.ne.0
c     dpsds= tangent of tangential traction wrt tangential separation, out, unit pressure/length,
c            needed when istif.ne.0
c     istif= flag if stiffness is needed for implicit, check istif.ne.0
c     prm  = input parameters, in, at most 16,
c            see uparm on *contact_automatic_surface_to_surface_tiebreak_user_mortar
c     hst  = history variables, in/out, associated with the model,
c            see unhsv on *contact_automatic_surface_to_surface_tiebreak_user_mortar
c     whst = history variables from tied weld, in, for assessing lamination
c            see nhwld on *contact_automatic_surface_to_surface_tiebreak_user_mortar
c     selm = slave element number, in
c     melm = master element number, in
c     sprt = slave part, in
c     mprt = master part, in
c     styp = slave element type, in
c     mtyp = master element type, in
c     dn   = normal separation, in, unit length, positive means tensile
c     ds   = tangential separation, in, unit length, always positive
c     en   = normal stiffness, in, unit pressure/length
c     es   = tangential stiffness, in, unit pressure/length
c     ts   = temperature on slave side, in
c     tm   = temperature on master side, in
c     seps = plastic strain on slave side, in
c     meps = plastic strain on master side, in
c     shis = material history variables on slave side, in,
c            see nhmat on *contact_automatic_surface_to_surface_tiebreak_user_mortar
c     mhis = material history variables on master side, in,
c            see nhmat on *contact_automatic_surface_to_surface_tiebreak_user_mortar
c     time = current time, in, unit time
c     dt   = time step, in, unit time
c
      if (tid.eq.101) then
c     sample model 101, damage goes from 0 to 1 when normal separation
c     goes between first and second parameter
         pn=en*dn
         ps=es*ds
         pd=dmg
         if (dn.ge.prm(2)) then
            dmg=1.
            pn=0.
            ps=0.
            dmg=1.
         elseif (dn.gt.prm(1)) then
            dmg=max(dmg,(dn-prm(1))/(prm(2)-prm(1)))
            dmg=min(dmg,1.)
            pn=(1.-dmg)*pn
            ps=(1.-dmg)*ps
         endif
         if (dmg.eq.1.and.pd.lt.1..and.iconv.eq.0) then
            write (iomsg,1) styp,selm,sprt,mtyp,melm,mprt,time
         endif
      endif
      if (tid.eq.102) then
c     sample model 102
c     compute normal traction, compensating for initial
         pn=max(0.,en*dn)
c     compute tangential traction, compensating for initial
         ps=es*ds
c     damage as we start
         pd=dmg
c     increment "impulse density"
         hst(1)=hst(1)+prm(1)*pn*(time-hst(2))
         if (hst(1).gt.whst(1)) then
c     if "impulse density" exceeds "impulse density" from
c     adhesive operation, start damage
            dmg=dmg+prm(2)*(time-hst(2))
         endif
c     damage cannot exceed 1
         dmg=min(dmg,1.)
c     "damage" the tractions
         pn=pn*(1.-dmg)
         ps=ps*(1.-dmg)
         if (istif.ne.0) then
c     compute normal stiffness, accounting for damage
            dpndn=0.
            if (dn.ge.0.) dpndn=en*(1.-dmg)
c     compute tanegntial stiffness, accounting for damage
            dpsds=es*(1.-dmg)
c     no couplings
            dpnds=0.
            dpsdn=0.
         endif
c     store current time to compute time step, for academic
c     purposes, time step is already in the routine
         hst(2)=time
         if (dmg.eq.1.and.pd.lt.1..and.iconv.eq.0) then
c     when fully damaged, write some info
            write (iomsg,1) styp,selm,sprt,mtyp,melm,mprt,time
         endif
      endif
      return
 1    format(/
     . '     Slave segment on ',a5,' element ',i10,' of ',/,
     . '     part ',i10,' is completely released from master segment',/,
     . '     on ',a5,' element ',i10,' of part ',i10,' at',/,
     . '     time ',e14.7,'.')
      end
# 839

      subroutine usrfrc(nosl,time,ncycle,dt2,insv,areas,xs,ys,zs,
     . lsv,ix1,ix2,ix3,ix4,aream,xx1,xx2,xx3,stfn,stf,fni,
     . dx,dy,dz,fdt2,ninput,ua,side,iisv5,niisv5,rn1,rn2,rn3,fric1,
     . fric2,fric3,fric4,bignum,fdat,iseg,fxis,fyis,fzis,ss,tt,
     . ilbsv,stfk,frc,numnp,npc,pld,lcfst,lcfdt,temp,temp_bot,
     . temp_top,isurface,nhv,ufhist,neps,ufeps,sfacn3,thkn,tk)
# 849

c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     user subroutine for interface friction control (smp)
c
c     note:  ls-dyna3d uses an internal numbering system to
c            accomodate arbitrary node numbering.   to access
c            information for user node n, address array location m,
c            m=lqf8(n,1). to obtain user node number, n,
c            corresponding to array address m, set n=lqfinv8(m,1)
c
c     arguments:
c
c          nosl       =number of sliding interface
c          time       =current solution time
c          ncycle     =ncycle number
c          dt2        =time step size at n+1/2
c          insv       =slave node array where the nodes are stored
c                      in ls-dyna3d internal numbering.  User numbers
c                      are given by function: lqfinv8(insv(ii),1)
c                      for slave node ii.
c          areas(ii)  =slave node area (interface types 5&10 only) for
c                      slave node ii (forming contact, too)
c          xs(ii)     =x-coordinate slave node ii (projected)
c          ys(ii)     =y-coordinate slave node ii (projected)
c          zs(ii)     =z-coordinate slave node ii (projected)
c          lsv(ii)    =master segment number for slave node ii
c          ix1(ii), ix2(ii), ix3(ii), ix4(ii)
c                     =master segment nodes in ls-dyna3d internal
c                      numbering for slave node ii
c          aream(ii)  =master segment area for slave node ii.
c                      (not for forming contacts)
c          xx1(ii,4)  =x-coordinates master surface (projected) for
c                      slave node ii (not for forming contacts)
c          xx2(ii,4)  =y-coordinates master surface (projected) for
c                      slave node ii (not for forming contacts)
c          xx3(ii,4)  =z-coordinates master surface (projected) for
c                      slave node ii (not for forming contacts)
c          stfn       =slave node penalty stiffness
c          stf        =master segment penalty stiffness
c          fni        =normal force
c          dx,dy,dz   =relative x,y,z-displacement between slave node and
c                      master surface.  Multipling by fdt2 defines the
c                      relative velocity.
c          rn1,rn2,rn3=x,y, and z components of master segments normal
c                      vector
c          sfacn3     =scaling factor for implicit calculations
c          thkn(ii)   =slave node thickness
c          tk(ii)     =master segment thickness
c
c***********************************************************************
c       frictional coefficients defined for the contact interface
c
c          fric1      =static friction coefficient
c          fric2      =dynamic friction coefficient
c          fric3      =decay constant
c          fric4      =viscous friction coefficient (setting fric4=0
c                      turns this option off)
c
c***********************************************************************
c
c          bignum     =0.0 for one way surface to surface and
c                      for surface to surface, and 1.e+10 for nodes
c                      to surface contact
c                     =0.0 for forming contact
c          ninput     =number of variables input into ua
c          ua(*)      =users' array, first ninput locations
c                      defined by user.  the length of this
c                      array is defined on control card 10.
c                      this array is unique to interface nosl.
c
c          side       ='master' for first pass.  the master
c                       surface is the surface designated in the
c                       input
c                     ='slave' for second pass after slave and
c                      master surfaces have be switched for
c                      the type 3 symmetric interface treatment.
c
c          iisv5      =an array giving the pointers to the active nodes
c                      in the arrays.
c
c          niisv5     =number of active nodes
c
c          fdat       =contact history data array containing:
c                       1 - ss (isoparametric coord x)
c                       2 - tt (isoparametric coord y)
c                       3 - old friction x-force
c                       4 - old friction y-force
c                       5 - old friction z-force
c          iseg       =contact master segment from previous step.
c          fxis       =slave node force component in global x dir.
c                      to be updated to include friction
c          fyis       =slave node force component in global y dir.
c                      to be updated to include friction
c          fzis       =slave node force component in global z dir.
c                      to be updated to include friction
c          ss(ii)     =s contact point (-1 to 1) in parametric coordinates
c                      for slave node ii.
c          tt(ii)     =t contact point (-1 to 1) in parametric coordinates
c                      for slave node ii.
c          ilbsv(ii)  =pointer for node ii into global arrays.
c          stfk(ii)   =penalty stiffness for slave node ii which was used
c                      to compute normal interface force.
c          frc(1,lsv(ii))
c                    =Coulomb friction scale factor for segment lsv(ii)
c          frc(2,lsv(ii))
c                    =viscous friction scale factor for segment lsv(ii)
c
c***********************************************************************
c       parameters for a coupled thermal-mechanical contact
c
c          numnp      = number of nodal points in the model
c          npc        = load curve pointer
c          pld        = load curve (x,y) data
c          lcfst(nosl)= load curve number for static coefficient of
c                       friction versus temperture for contact
c                       surface nosl
c          lcfdt(nosl)= load curve number for dynamic coefficient of
c                       friction versus temperture for contact
c                       surface nosl
c          temp(j)    = temperature for node point j
c          temp_bot(j)= temparature for thick thermal shell bottom
c                       surface
c          temp_top(j)= temparature for thick thermal shell top
c                       surface
c          numsh12    = number of thick thermal shells
c          itopaz(1)  = 999 ==> thermal-mechanical analysis
c          isurface   = thick thermal shell surface pointer
c
c***********************************************************************
c
c          nhv = size of user friction history data array
c          ufhist(nhv,ilbsv(ii)) = user friction history data array
c          neps= size of element history data array
c          ufeps(neps,ilbsv(ii)) = element history data array ...
c                           (materials 36,103,133,243)
c             ... with NEHIS=0:
c               1 - plastic strain
c               2 - yield stress (materials 24,36,37,106,224,243,244)
c               3,4,5 - x,y,z components of material direction
c                             (materials 36,103,133,243)
c             ... with NEHIS>0:
c               1 - plastic strain
c               2 - 1st history variable
c               3 - 2nd history variable
c               ...
c
c***********************************************************************
      include 'nlqparm'
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
# 1005 "dyn21cnt.F" 2 
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
# 1006 "dyn21cnt.F" 2 
# 1 ".\bk08.inc" 1 
      integer n4f,n4g,n4h,n7a,nusir,                                    
     & mpusr,mpubr,n4i,n4j,n4k,n4l,n4m,n4n
      common/bk08/n4f,n4g,n4h,n7a,nusir,                                
     & mpusr,mpubr,n4i,n4j,n4k,n4l,n4m,n4n
# 1007 "dyn21cnt.F" 2 
# 1 ".\bk13.inc" 1 
      integer lc0,lc1h,lc1b,lc1t,lc2,lc3,lc4,lc5,lc6,lc6e,lc6f,lc9,     
     & lc10,lc11,lc12,lc13,lc14,lc15,lc16,lc17,lc18,lb0,lb1,lb2,        
     & lc7a,lc7b,lc7c,lc7d,lc7e,lc7f,lc7g,lc7h,lc7i,lc7j,lc7k,lc7l,     
     & lc7t,lc7x,lc6g,lc6h
      common/bk13/lc0,lc1h,lc1b,lc1t,lc2,lc3,lc4,lc5,lc6,lc6e,lc6f,lc9, 
     & lc10,lc11,lc12,lc13,lc14,lc15,lc16,lc17,lc18,lb0,lb1,lb2,        
     & lc7a,lc7b,lc7c,lc7d,lc7e,lc7f,lc7g,lc7h,lc7i,lc7j,lc7k,lc7l,     
     & lc7t,lc7x,lc6g,lc6h
# 1008 "dyn21cnt.F" 2 
      common/bmcntc/ibmcnt(101)
      common/thropt/itopaz(101),iprm_thrm(20),rprm_thrm(20)
      common/blk03/rdumy1(2),idumy6(25),numsh12,ndtot,nsl_th,lenhsv,
     . numel2,numel4,numel6,numel8,numel10,numel20,
     . numelts,numelts8,numelts6,numel27,numelttpz
      dimension insv(*),areas(*),xs(*),ys(*),zs(*),lsv(*),ix1(*),
     . ix2(*),ix3(*),ix4(*),aream(*),xx1(nlq,*),xx2(nlq,*),xx3(nlq,*),
     . stfn(*),stf(*),fni(*),dx(*),dy(*),dz(*),ua(*),iisv5(*),
     . fdat(5,*),iseg(*),fxis(*),fyis(*),fzis(*),ss(*),tt(*),
     . ilbsv(*),stfk(*),frc(2,*),npc(*),pld(2,*),lcfst(*),lcfdt(*),
     . temp(*),temp_bot(*),temp_top(*),isurface(numnp,*),
     . ufhist(nhv,*),ufeps(neps,*),thkn(*),tk(*)
      real rn1(*),rn2(*),rn3(*)
      integer ncycle
      character*(*) side
      integer lqfinv8
c
c     set coefficient of friction multipliers to 1.
      fstm=1.
      fdym=1.
c
c     loop on the number of active nodes niisv5 in contact
      do kk = 1, niisv5
c
c     get the location pointer ii for this active node
      ii = iisv5(kk)
c
c------------------------- begin thermal -------------------------------
c     recalculate coefficient of friction multipliers if
c     function of temperature
c
      if (itopaz(1) .eq. 999) then
c
c     get the node number jj
c     the user node number is obtained using node_user=lqfinv8(jj,1)
      jj = insv(ii)
c
c     get the temperature of the active node.
c     use the array isurface to distinquish between a bottom,
c     midplane, or top surface node for a thick thermal shell
      if (numsh12.ne.0) then
      if (isurface(jj,nosl) .lt. 0) then
        tnode=temp_bot(jj)
      elseif (isurface(jj,nosl) .gt. 0) then
        tnode=temp_top(jj)
      else
        tnode=temp(jj)
      endif
      else
        tnode=temp(jj)
      endif
c
c     get the shape functions for this active node projected
c     onto the surface it contacts
      h1=.25*(1.-ss(ii))*(1.-tt(ii))
      h2=.25*(1.+ss(ii))*(1.-tt(ii))
      h3=.25*(1.+ss(ii))*(1.+tt(ii))
      h4=.25*(1.-ss(ii))*(1.+tt(ii))
c     get the segment temperature at the interpolation point
c     use the array isurface to distinquish between a bottom,
c     midplane, or top surface node for a thick thermal shell
      if (numsh12.ne.0) then
      if (isurface(ix1(ii),nosl) .lt. 0) then
        tseg=h1*temp_bot(ix1(ii))+h2*temp_bot(ix2(ii))
     1   +h3*temp_bot(ix3(ii))+h4*temp_bot(ix4(ii))
      elseif (isurface(ix1(ii),nosl) .gt. 0) then
        tseg=h1*temp_top(ix1(ii))+h2*temp_top(ix2(ii))
     1   +h3*temp_top(ix3(ii))+h4*temp_top(ix4(ii))
      else
        tseg=h1*temp(ix1(ii))+h2*temp(ix2(ii))
     1   +h3*temp(ix3(ii))+h4*temp(ix4(ii))
      endif
      else
        tseg=h1*temp(ix1(ii))+h2*temp(ix2(ii))
     1   +h3*temp(ix3(ii))+h4*temp(ix4(ii))
      endif
c
c     get the average contact temperature
      tavg=.5*(tnode+tseg)
c
c     get static coefficient of friction temperature multiplier fstm
      call value (nosl,lcfst,npc,pld,tavg,tavg,fstm,valp,1)
c     get dynamic coefficient of friction temperature multiplier fdym
      call value (nosl,lcfdt,npc,pld,tavg,tavg,fdym,valp,1)
      endif
c------------------------- end thermal ---------------------------------
c---------------------- begin mechanical -------------------------------
c
c     current & accumulated sliding distance
      ddist=sqrt(dx(ii)**2+dy(ii)**2+dz(ii)**2)
      ufhist(1,ilbsv(ii))=ufhist(1,ilbsv(ii))+ddist
      dist=ufhist(1,ilbsv(ii))
c
c     current sliding velocity
      vel=fdt2*ddist
c
c     current contact pressure = normal force / slave node area
      press=-fni(ii)/areas(ii)
c
c     master and slave node area
c     (needed for frict. force limit, see parameter VC in the manual)
      aream(ii)=aream(ii)*fric4*frc(2,lsv(ii))+
     .          1.e+16*(.5-sign(.5,fric4-1.e-10))
      areas(ii)=areas(ii)*fric4*frc(2,lsv(ii))+
     .          1.e+16*(.5-sign(.5,fric4-1.e-10))+bignum
      areas(ii)=areas(ii)+1.e+16*(.5-sign(.5,areas(ii)-1.e-10))
c
c     new contact force = old + current penalty force
      fdat(3,ii)=fdat(3,ii)+stfk(ii)*dx(ii)*sfacn3
      fdat(4,ii)=fdat(4,ii)+stfk(ii)*dy(ii)*sfacn3
      fdat(5,ii)=fdat(5,ii)+stfk(ii)*dz(ii)*sfacn3
c
c     tangential part = total - normal part
      proj=fdat(3,ii)*rn1(ii)+fdat(4,ii)*rn2(ii)+fdat(5,ii)*rn3(ii)
      fdat(3,ii)=fdat(3,ii)-proj*rn1(ii)
      fdat(4,ii)=fdat(4,ii)-proj*rn2(ii)
      fdat(5,ii)=fdat(5,ii)-proj*rn3(ii)
c
c     scalar tangential force = func(fric.coeff.) * normal force
      fmax=-(fdym*fric2+(fstm*fric1-fdym*fric2)*exp(-fric3*vel))
     .     *fni(ii)*frc(1,lsv(ii))
c
c     limit the friction force
      fmax=min(fmax,aream(ii),areas(ii))
      fmag=sqrt(fdat(3,ii)**2+fdat(4,ii)**2+fdat(5,ii)**2)+1.e-06
c
c     tangential force due to friction
      if (fmag.gt.fmax .and. fmag.ne.0.0) then
        sclf=fmax/fmag
        fdat(3,ii)=sclf*fdat(3,ii)
        fdat(4,ii)=sclf*fdat(4,ii)
        fdat(5,ii)=sclf*fdat(5,ii)
      endif
c
c     slave node force components in global directions
      fxis(ii)=fxis(ii)+fdat(3,ii)
      fyis(ii)=fyis(ii)+fdat(4,ii)
      fzis(ii)=fzis(ii)+fdat(5,ii)
c
      iseg(ii)  =lsv(ii)
      fdat(1,ii)=ss(ii)
      fdat(2,ii)=tt(ii)
c----------------------- end mechanical --------------------------------
c
      enddo
c
      return
      end

      subroutine userwear(wdepth,wtype,cside,
     1     wparm,mwearu,
     2     whisv,lwearu,
     3     nx,ny,nz,
     4     dx,dy,dz,
     5     press,tract,area,temp,stemp,time,dt,
     6     crv,nnpcrv,
     7     idnode,idcntct,isslave)
# 1168

      implicit none
      include 'nlqparm'
      real wdepth
      integer wtype,cside
      integer mwearu,lwearu
      real wparm(*),whisv(*)
      real nx,ny,nz
      real dx,dy,dz
      real press,tract,area,temp,stemp,time,dt
      real crv(lq1,2,*)
      integer nnpcrv(*)
      integer idnode,idcntct,isslave
c
c     User defined wear routine, see *CONTACT_ADD_WEAR, for processing
c     wear on a contact node. This routine is called for wear interfaces
c     with WTYPE<0, this denotes the type. The purpose is to increment the
c     parameter wdepth, which is the wear depth in length units. The
c     following is a list of input parameters, after that is a
c     sample code for the simple Archard's law corresponding to
c     WTYPE=0 and positive as well as negative parameters.
c
c     outputs:
c
c     wdepth        = wear depth to be incremented (length unit)
c     whisv(lwearu) = list of wear history variables, initialized to zero,
c                     to be updated in this routine
c
c     inputs:
c
c     wtype         = wear type, this is the value of WTYPE from the input
c                     and can be used to distinguish wear laws, see sample
c                     routine below
c     cside         = 0 if contact node is on slave side of the contact,
c                     1 otherwise
c     wparm(mwearu) = list of input wear parameters from keyword deck
c     mwearu        = number of input wear parameters requested, for this
c                     wear interface
c     lwearu        = number of input wear histories requested, for this
c                     contact node
c     nx,ny,nz      = components of normal in the contact, vector is normalized,
c                     normal is pointing in the direction defined by the
c                     orientation of underlying element connectivity
c     dx,dy,dz      = relative incremental displacement vector of the contact
c                     point, in both normal and tangential direction
c                     (length unit), vector is defined as the contact nodal
c                     incremental displacement minus the incremental
c                     displacement of the opposite contact point
c     press         = contact pressure in the contact node, positive
c                     (force per area unit)
c     tract         = contact tangential tractions in the contact node, positive
c                     (force per area unit)
c     area          = contact area
c                     (area unit)
c     temp          = temperature in the contact node, zero if no thermal
c                     calculation
c     stemp         = temperature on the contact segment on opposing side,
c                     zero if no thermal calculation
c     time          = current simulation time
c     dt            = current time step
c     crv(lq1,*,*)  = curve array, use subroutines crvval and tabval for
c                     evaluating data, see Appendix A
c     nnpcrv(*)     = data required for curve data
c     idnode        = global node ID (from keyword input) for the node
c     idcntct       = contact ID (from keyword input) for the underlying contact
c     isslave       = 1 if the contact node is on the slave side of the
c                       contact interface,
c                     0 otherwise
c
c     Sample routine follows, Archard's law in two forms, mwearu=3, lwearu=0,
c
c     Wear parameters for wtype=-1 are
c
c     wparm(1)      = dimensionless coefficient
c     wparm(2)      = hardness of slave surface
c     wparm(3)      = hardness of master surface
c
c     Wear parameters for wtype=-2 are
c
c     wparm(1)      = dimensionless coefficient table id as function
c                     of pressure and sliding velocity
c     wparm(2)      = hardness of slave surface curve id as function
c                     of temperature
c     wparm(3)      = hardness of master surface curve id as function
c                     of temperature
c
c     Declare variables
      real dn,tx,ty,tz,tt,c,h
      real vt,dcdvt,dcdpress,dhdtemp
c
c     First do stuff necessary for both wtype=-1 and wtype=-2
c
c     Calculate relative normal displacement
      dn=dx*nx+dy*ny+dz*nz
c     Calculate relative tangential displacement
      tx=dx-dn*nx
      ty=dy-dn*ny
      tz=dz-dn*nz
c     Calculate relative sliding distance
      tt=sqrt(tx**2+ty**2+tz**2)
c     For law with constant parameters
      if (wtype.eq.-1) then
c     Dimensionless coefficient
         c=wparm(1)
c     Make sure correct hardness is used
         if (cside.eq.0) then
            h=wparm(2)
         else
            h=wparm(3)
         endif
      endif
c     store opposite side temperature as first history variable
      if (lwearu.ge.1) whisv(1)=stemp
c     For law with dependent parameters
      if (wtype.eq.-2) then
c     Sliding velocity
         vt=tt/max(dt,1.e-20)
c     Evaluate coefficient from table
         call tabval(crv,nnpcrv,wparm(1),vt,c,dcdvt,press,dcdpress)
c     Make sure correct hardness is used
         if (cside.eq.0) then
            call crvval(crv,nnpcrv,wparm(2),temp,h,dhdtemp)
         else
            call crvval(crv,nnpcrv,wparm(3),temp,h,dhdtemp)
         endif
      endif
c     Increment wear depth by the Archard's law parameters
      wdepth=wdepth+c*tt*press/h
c     Done, wdepth can be post-processed in the intfor file,
c     see DATABASE_EXTENT_INTFOR
c
      return
      end
      subroutine userdewear(wearvol,wpara,
     1     xp01,xp02,xp03,xs01,xs02,xs03,
     2     rp0,vr1,vr2,vr3,
     3     vp01,vp02,vp03,vs01,vs02,vs03,
     4     nx,ny,nz,
     5     fnx,fny,fnz,frx,fry,frz,
     6     temp,stemp,time,dt,crv,nnpcrv,
     7     net_wear,accu_wear,area)
# 1312

c
c     *DEFINE_DE_TO_SURFACE_COUPLING user defined wear
c
      implicit none
      include 'nlqparm'
      real wearvol,wpara(*)
      real xp01,xp02,xp03,xs01,xs02,xs03
      real rp0,vr1,vr2,vr3,vp01,vp02,vp03,vs01,vs02,vs03
      real fnx,fny,fnz,frx,fry,frz
      real nx,ny,nz
      real temp,stemp,time,dt
      real crv(lq1,2,*)
      integer nnpcrv(*)
      real net_wear,accu_wear,area
c
c     User defined wear routine, see *DEFINE_DE_TO_SURFACE_COUPLING, for
c     processing wear on a contact segment. This routine is called for
c     wear interfaces with WREARC=-100. The purpose is to calculate the
c     increment worn volume on a segment
c     following is a list of input parameters, after that is a
c     sample code for the simple Archard's law corresponding to WEARC>0
c
c     outputs:
c
c     wearvol       = wear volume to be incremented for this time step
c
c     inputs:
c
c     wpara         = list of input wear parameters from keyword deck
c     xp01-03       = coordinate of discrete element
c     xs01-03       = coordinate of contact point at segment
c     rp0           = radius of discrete element
c     vr1,vr2,vr3   = rotational velocity of discrete element
c     vp01-03       = velocity of discrete element
c     vs01-03       = velocity of contact point at segment
c     nx,ny,nz      = components of normal in the contact, vector is normalized,
c                     normal is pointing in the direction from contact point
c                     at segment to discrete element
c     fnx,fny,fnz   =   normal force applied at contact point of segment
c     frx,fry,frz   = friction force applied at contact point of segment
c     temp          = temperature in the contact node, zero if no thermal
c                     calculation, currently not used
c     stemp         = temperature on the contact segment on opposing side,
c                     currently not used zero if no thermal calculation
c     time          = current simulation time
c     dt            = current time step
c     crv(lq1,*,*)  = curve array, use subroutines crvval and tabval for
c                     evaluating data, see Appendix A
c     nnpcrv(*)     = data required for curve data
c     net_wear      = wear volume of previous timestep
c     accu_wear     = accumulated wear volume of previous timestep
c     area          = area of the contact segment
c
c
c     Declare variables
# 1394

c
c     Sample routine for finnie model
c
c
      real dvn,dv1,dv2,dv3,alp,fp,dvp
      dv1 = vp01 - vs01
      dv2 = vp02 - vs02
      dv3 = vp03 - vs03
      dvp=sqrt(dv1*dv1+dv2*dv2+dv3*dv3)
      dvn = dv1*nx+dv2*ny+dv3*nz
      alp= asin(abs(dvn)/max(1.e-20,dvp))
      fp= sqrt(fnx*fnx+fny*fny+fnz*fnz+frx*frx+fry*fry+frz*frz)
      if(dv1*(xp01-xs01)+dv2*(xp02-xs02)+dv3*(xp03-xs03).lt.0.) then
         if(alp.le.0.3228859) then
           wearvol = 0.25*dvp*fp*dt*
     .                      (sin(2*alp)-3.*sin(alp)*sin(alp))/wpara(1)
         else
           wearvol = 0.083333*dvp*fp*dt*cos(alp)*cos(alp)/wpara(1)
         endif
      else
c       dwear =0 for repulsion phase
        wearvol=0.
      endif
c
c     Done, wearvol is used to calculate worn depth, whcih can be
c     post-processed in the intfor file, see DATABASE_BINARY_DEMFOR
      return
      end
