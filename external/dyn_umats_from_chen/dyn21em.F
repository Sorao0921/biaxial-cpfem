#include "define.inc"
#include "define2.inc"
c
#ifdef EXTENDED
#ifdef USES_CXX
c*********************************************************************
c*********************************************************************
c generalized randles circuit
c*********************************************************************
c*********************************************************************
      subroutine user_em_generalizedRandle(
c input
     &     nstep,
     &     time,
     &     dt,
     &     Rconn,
     &     numCircuit,
     &     circuitData,
     &     potential1,
     &     potential2,
c output
     &     current)
c******************************************************************
c|  livermore software technology corporation  (lstc)             |
c|  -------------------1-----------------------------------------  |
c|  copyright 1987-2004 Livermore Software Tech. Corp.            |
c|  all rights reserved                                           |
c******************************************************************
c
c typical usermat routine for generalized randles circuit 
c
      implicit none
c
      integer nstep
      real time
      real dt
      real Rconn
      integer numCircuit
      MINDEX circuitData
      real potential1(numCircuit)
      real potential2(numCircuit)
      real current(numCircuit)
c
      include 'iounits.inc'
#include "meshes.inc"
#include "dynmem.inc"
#include "em.inc"
#include "LCPACK.inc"
#include "SPOOLES.inc"
c
      integer numDataPerCircuit
      integer icircuit
      integer ioff
c
      integer ir0
      integer ir10
      integer ic10
      integer iQ
      integer icQ
      integer isoc
      integer iVc
      integer iVc_m1
      integer iu
      integer iareaType
c
      real r0
      real r10
      real c10
      real Q
      real cQ
      real soc
      real Vc
      real Vc_m1
      real Vc_ref
      real u
      real r0Loc
      real xareaCell,xareaCircuit,xareaType
c
      real xi,phi1,phi2
      real V
c
      call em_writeMessag(3,iomsg,
     &     'enter user_em_generalizedRandl')
c #ifdef DEBUG
c      write(iomsg,'(a15,i16)') 'circuitData',
c     &     circuitData
c #endif
      numDataPerCircuit=10
c
      ir0     =1
      ir10    =2
      ic10    =3
      iQ      =4
      icQ     =5
      isoc    =6
      iVc     =7
      iVc_m1  =8
      iu      =9
c*********************************************************************
c initialization
c*********************************************************************
      if (circuitData .eq. 0) then
         circuitData=mem_alloc(numCircuit*numDataPerCircuit)
c #ifdef DEBUG
c         write(iomsg,'(a15,3i16)') 'circuitData2',
c     &        circuitData,
c     &        numCircuit,
c     &        numDataPerCircuit
c #endif
c
         r0=0.02
         r10=0.008
         c10=110.
         Q=0.845
         cQ=2.777e-2
         soc=100.
         Vc=0.
         Vc_m1=0.
         u=4.15
         do icircuit=1,numCircuit
            ioff=(icircuit-1)*numDataPerCircuit
c
            r_mem(circuitData+ioff+ir0)=r0
            r_mem(circuitData+ioff+ir10)=r10
            r_mem(circuitData+ioff+ic10)=c10
            r_mem(circuitData+ioff+icQ)=cQ
            r_mem(circuitData+ioff+iQ)=Q
c     
            r_mem(circuitData+ioff+iVc)=Vc
            r_mem(circuitData+ioff+iVc_m1)=Vc_m1
            r_mem(circuitData+ioff+iu)=u
            r_mem(circuitData+ioff+isoc)=soc
c #ifdef DEBUG
c            if (icircuit .eq. 1) then
c               write(iomsg,'(a15,i5,9e12.4)') 'UMcircuit0',
c     &              icircuit,
c     &              r_mem(circuitData+ioff+ir10),
c     &              r_mem(circuitData+ioff+ir10),
c     &              r_mem(circuitData+ioff+ic10),
c     &              r_mem(circuitData+ioff+icQ),
c     &              r_mem(circuitData+ioff+iQ),
c     &              r_mem(circuitData+ioff+iVc),
c     &              r_mem(circuitData+ioff+iVc_m1),
c     &              r_mem(circuitData+ioff+iu),
c     &              r_mem(circuitData+ioff+isoc)
c            endif
c #endif
         enddo
c
         return
      endif
c*********************************************************************
c time step
c*********************************************************************
      do icircuit=1,numCircuit
         ioff=(icircuit-1)*numDataPerCircuit
c
         if (nstep .eq. 1) then
            phi1=4.15
            phi2=0.
            xi=0.
         else
            phi1=potential1(icircuit)
            phi2=potential2(icircuit)
            xi=current(icircuit)
         endif
c
         r0=r_mem(circuitData+ioff+ir0)
         r10=r_mem(circuitData+ioff+ir10)
         c10=r_mem(circuitData+ioff+ic10)
         cQ=r_mem(circuitData+ioff+icQ)
         Q=r_mem(circuitData+ioff+iQ)
c
         Vc=r_mem(circuitData+ioff+iVc)
         Vc_m1=r_mem(circuitData+ioff+iVc_m1)
         u=r_mem(circuitData+ioff+iu)
         soc=r_mem(circuitData+ioff+isoc)
c***********************************************************
c get areaType (from input deck),
c areaCell and areaCircuit if needed
c***********************************************************
         call em_randleGetVal(
     &        icircuit,
     &        em_randle_areaType,
     &        xareaType)
         iareaType=int(xareaType)
         call em_randleGetVal(
     &        icircuit,
     &        em_randle_areaCell,
     &        xareaCell)
         call em_randleGetVal(
     &        icircuit,
     &        em_randle_areaCircuit,
     &        xareaCircuit)
c*********************************************************************
c update state variables and copy them to circuitData
c*********************************************************************   
         Vc_ref=Vc
         Vc=Vc+dt*(xi/c10-Vc_m1/r10/c10)
         V=u-r0*xi-Vc
         soc=soc-dt*xi*cQ/Q
         Vc_m1=Vc_ref
c #ifdef DEBUG
c         if (icircuit .eq. 1) then
c            write(iomsg,'(a15,2i5,7e12.4)') 'UMcircuit',
c     &           nstep,
c     &           icircuit,
c     &           phi1,
c     &           phi2,
c     &           phi1-phi2,
c     &           Vc,
c     &           V,
c     &           xi,
c     &           soc
c            write(iomsg,'(a15,i5,7e12.4)') 'circ1Val1',
c     &           iem_cntl(IEM_NSTEP),
c     &           dt,
c     &           time,
c     &           xi,
c     &           V,
c     &           Vc,
c     &           u,
c     &           soc
c         endif
c #endif
         r_mem(circuitData+ioff+iVc)=Vc
         r_mem(circuitData+ioff+iVc_m1)=Vc_m1
         r_mem(circuitData+ioff+iu)=u
         r_mem(circuitData+ioff+isoc)=soc
c*********************************************************************
c compute current(icircuit) (RHS of the S0 system) 
c*********************************************************************
c***********************************************************
c define r0Loc such that
c 1./r0Loc + 1./Rconn = 1/r0
c and use it in for the term 1./r0Loc*(phi2-phi1)
c since the part 
c 1./Rconn*(phi2-phi1) is already used by adding 1/Rconn 
c to the stiffness matrix 
c***********************************************************
         r0Loc=1./r0-1./Rconn
c #ifdef DEBUG
c         if (icircuit .eq. 1) then
c            write(iomsg,'(a15,4e12.4)') 'r0Loc',
c     &           Rcell,Rconn,r0loc,1/r0Loc
c         endif
c #endif
         r0Loc=1./r0Loc
c
         goto 786
         if (r0Loc .le. 0.) then
            write(*,*) 
     &           'error setting Rconn in em_generalizedRandles'
            write(iomsg,*) 
     &           'error setting Rconn in em_generalizedRandles'
            call adios(TC_ERROR)
         endif
 786     continue
c #ifdef DEBUG
c         write(*,*) 'r0Loc',r0Loc,r0,Rconn
c #endif
c
         current(icircuit)=1./r0*(u-Vc)+1./r0Loc*(phi2-phi1)*0.
c #ifdef DEBUG
c         if (icircuit .eq. 1) then
c            write(iomsg,'(a15,2i5,10e12.4)') 'F-xrhs',
c     &           nstep,
c     &           icircuit,
c     &           r0,
c     &           u,
c     &           Vc,
c     &           u-Vc,
c     &           1./r0*(u-Vc),
c     &           phi1,
c     &           phi2,
c     &           1./r0*(phi2-phi1),
c     &           current(icircuit),
c     &           xi
c         endif
c #endif
c*********************************************************************
c copy variables to corresponding arrays so that they can be output
c to em_xxx.dat and d3plots 
c*********************************************************************
         call em_randlePutVal(
     &        icircuit,
     &        em_randle_i,
     &        xi)
         call em_randlePutVal(
     &        icircuit,
     &        em_randle_v,
     &        V)
         call em_randlePutVal(
     &        icircuit,
     &        em_randle_soc,
     &        soc)
      enddo
c
      call em_writeMessag(3,iomsg,
     &     'exit user_em_generalizedRandl ')
c
      return
      end
c
c*********************************************************************
c*********************************************************************
c simple electrochemistry model
c*********************************************************************
c*********************************************************************
c
      subroutine user_em_GR_simpleEchem(
c input
     &     nstep,
     &     time,
     &     dt,
     &     Rconn,
     &     numCircuit,
     &     circuitData,
     &     potential1,
     &     potential2,
c output
     &     current)
c******************************************************************
c|  livermore software technology corporation  (lstc)             |
c|  -------------------1-----------------------------------------  |
c|  copyright 1987-2004 Livermore Software Tech. Corp.            |
c|  all rights reserved                                           |
c******************************************************************
c
c typical usermat routine for generalized randles circuit 
c
      implicit none
c
      integer nstep
      real time
      real dt
      real Rconn
      integer numCircuit
      MINDEX circuitData
      real potential1(numCircuit)
      real potential2(numCircuit)
      real current(numCircuit)
c
      include 'iounits.inc'
#include "meshes.inc"
#include "dynmem.inc"
#include "em.inc"
#include "LCPACK.inc"
#include "SPOOLES.inc"
c
      integer numDataPerCircuit
      integer icircuit
      integer ioff
c
      integer ix0p
      integer ix0n
      integer ixp
      integer ixn		
      integer iepsp
      integer iepsn
      integer iepspf
      integer iepsnf
      integer icsmaxp
      integer icsmaxn
      integer iRp
      integer iRn
      integer ikp
      integer ikn
      integer iSp
      integer iSn
      integer ice
      integer iF
      integer iR
      integer iT
      integer iRcell
      integer iareaType
c
      real x0p
      real x0n
      real xp
      real xn		
      real epsp
      real epsn
      real epspf
      real epsnf
      real csmaxp
      real csmaxn
      real Rp
      real Rn
      real kp
      real kn
      real Sp
      real Sn
      real ce
      real F
      real R
      real T
      real Rcell
      real r0Loc
      real xsoc
      real xareaCell,xareaCircuit,xareaType
c
      real xi,phi1,phi2
      real Up,mp,Un,mn,Vcell
c
      call em_writeMessag(3,iomsg,
     &     'enter user_em_GR_simpleEchem  ')
c #ifdef DEBUG
c      write(iomsg,'(a15,i16)') 'circuitData',
c     &     circuitData
c #endif
      numDataPerCircuit=21
c
      ix0p        =0
      ix0n        =1
      ixp         =2
      ixn         =3		
      iepsp       =4
      iepsn       =5
      iepspf      =6
      iepsnf      =7
      icsmaxp     =8
      icsmaxn     =9
      iRp         =10
      iRn         =11
      ikp         =12
      ikn         =13
      iSp         =14
      iSn         =15
      ice         =16
      iF          =17
      iR          =18
      iT          =19
      iRcell      =20
c*********************************************************************
c initialization
c*********************************************************************
      if (circuitData .eq. 0) then
         circuitData=mem_alloc(numCircuit*numDataPerCircuit)
c #ifdef DEBUG
c         write(iomsg,'(a15,3i16)') 'circuitData2',
c     &        circuitData,
c     &        numCircuit,
c     &        numDataPerCircuit
c #endif
         x0p = 0.485
         x0n = 0.959
         xp = 0.485
         xn = 0.959		
         epsp = 0.39
         epsn = 0.385
         epspf = 0.03
         epsnf = 0.024
         csmaxp = 51410
         csmaxn = 31833
         Rp = 10.5e-6
         Rn = 12.5e-6
         kp = 1.764e-11
         kn = 6.6667e-11
         Sp = 0.7824
         Sn = 1.1167
         ce = 1000
         F = 96485
         R = 8.314
         T = 298.15
         Rcell = 0.012
c
         do icircuit=1,numCircuit
            ioff=(icircuit-1)*numDataPerCircuit
c
            r_mem(circuitData+ioff+
     &           ix0p)=x0p
            r_mem(circuitData+ioff+
     &           ix0n)=x0n
            r_mem(circuitData+ioff+
     &           ixp)=xp
            r_mem(circuitData+ioff+
     &           ixn)=xn		
            r_mem(circuitData+ioff+
     &           iepsp)=epsp
            r_mem(circuitData+ioff+
     &           iepsn)=epsn
            r_mem(circuitData+ioff+
     &           iepspf)=epspf
            r_mem(circuitData+ioff+
     &           iepsnf)=epsnf
            r_mem(circuitData+ioff+
     &           icsmaxp)=csmaxp
            r_mem(circuitData+ioff+
     &           icsmaxn)=csmaxn
            r_mem(circuitData+ioff+
     &           iRp)=Rp
            r_mem(circuitData+ioff+
     &           iRn)=Rn
            r_mem(circuitData+ioff+
     &           ikp)=kp
            r_mem(circuitData+ioff+
     &           ikn)=kn
            r_mem(circuitData+ioff+
     &           iSp)=Sp
            r_mem(circuitData+ioff+
     &           iSn)=Sn
            r_mem(circuitData+ioff+
     &           ice)=ce
            r_mem(circuitData+ioff+
     &           iF)=F
            r_mem(circuitData+ioff+
     &           iR)=R
            r_mem(circuitData+ioff+
     &           iT)=T
            r_mem(circuitData+ioff+
     &           iRcell)=Rcell
         enddo
c
         return
      endif
c*********************************************************************
c time step
c*********************************************************************
      do icircuit=1,numCircuit
         ioff=(icircuit-1)*numDataPerCircuit
c
         if (nstep .eq. 1) then
            phi1=4.0952568338370616
            phi2=0.
            xi=8.5516004562377930
         else
            phi1=potential1(icircuit)
            phi2=potential2(icircuit)
            xi=current(icircuit)
         endif
c*********************************************************************
c get variables from internal arrays
c*********************************************************************
         x0p=r_mem(circuitData+ioff+
     &        ix0p)
         x0n=r_mem(circuitData+ioff+
     &        ix0n)
         xp=r_mem(circuitData+ioff+
     &        ixp)
         xn=r_mem(circuitData+ioff+
     &        ixn)		
         epsp=r_mem(circuitData+ioff+
     &        iepsp)
         epsn=r_mem(circuitData+ioff+
     &        iepsn)
         epspf=r_mem(circuitData+ioff+
     &        iepspf)
         epsnf=r_mem(circuitData+ioff+
     &        iepsnf)
         csmaxp=r_mem(circuitData+ioff+
     &        icsmaxp)
         csmaxn=r_mem(circuitData+ioff+
     &        icsmaxn)
         Rp=r_mem(circuitData+ioff+
     &        iRp)
         Rn=r_mem(circuitData+ioff+
     &        iRn)
         kp=r_mem(circuitData+ioff+
     &        ikp)
         kn=r_mem(circuitData+ioff+
     &        ikn)
         Sp=r_mem(circuitData+ioff+
     &        iSp)
         Sn=r_mem(circuitData+ioff+
     &        iSn)
         ce=r_mem(circuitData+ioff+
     &        ice)
         F=r_mem(circuitData+ioff+
     &        iF)
         R=r_mem(circuitData+ioff+
     &        iR)
         T=r_mem(circuitData+ioff+
     &        iT)
         Rcell=r_mem(circuitData+ioff+
     &        iRcell)
c***********************************************************
c get areaType (from input deck),
c areaCell and areaCircuit if needed
c***********************************************************
         call em_randleGetVal(
     &        icircuit,
     &        em_randle_areaType,
     &        xareaType)
         iareaType=int(xareaType)
         call em_randleGetVal(
     &        icircuit,
     &        em_randle_areaCell,
     &        xareaCell)
         call em_randleGetVal(
     &        icircuit,
     &        em_randle_areaCircuit,
     &        xareaCircuit)
c
c   The following IF loop will be gotten rid off, when using a detailed model
c   The values for xp and xn if they exceed physically meaningful values, are
c   set to constant values (0.98 and 0.001). These constants can be further 
c   tweaked alongside other model parameters to make sure cell voltage never
c   goes below zero; but given that this is just an example and the detailed
c   models take care of this already, the workaround below would suffice for 
c   this example. The timestep dt has to be sufficiently small for V to stay
c   positive at higher currents.
         IF((xp.LT.1.0).and.(xn.GT.0.0)) THEN
            x0p = xp
            x0n = xn
         ELSE
            xp = 0.98
            xn = 0.001
         ENDIF
c     
         Up = (-4.656+88.669*xp**2.0-399.119*xp**4.0+342.909*xp**6.0
     &        -462.471*xp**8.0+433.434*xp**10.0)/(-1.0+18.933*xp**2.0
     &        -79.532*xp**4.0+37.311*xp**6.0
     &        -73.083*xp**8.0+95.96*xp**10.0)
         mp = xi/F/kp/Sp/csmaxp/sqrt((ce)*(1-xp)*xp)
         Un = -0.5e-1+0.325e1*exp(-(50*xn**1.2))-
     &        0.221e0*tanh(0.20000000e2*xn-0.21000000e2)-
     &        0.105e-1*tanh(0.31347962e2*xn-0.17241379e2)-
     &        0.34e-1*tanh(0.29411765e2*xn-0.60294118e1)-
     &        0.2e-2*tanh(0.70422535e1*xn-0.13661972e1)-
     &        0.155e-1*tanh(0.77519380e2*xn-0.81395349e1)
         mn = xi/F/kn/Sn/csmaxn/sqrt((ce)*(1-xn)*xn)
c     
c	Vcell = Up-Un+2*R*T/F*log((dsqrt(mp*mp+4)+mp)/2)
c     &    	+2*R*T/F*log((dsqrt(mn*mn+4)+mn)/2) - iapp*Rcell
c*********************************************************************
c compute current(icircuit) (RHS of the S0 system) 
c*********************************************************************
c***********************************************************
c define r0Loc such that
c 1./r0Loc + 1./Rconn = 1/Rcell
c and use it in for the term 1./r0Loc*(phi2-phi1)
c since the part 
c 1./Rconn*(phi2-phi1) is already used by adding 1/Rconn 
c to the stiffness matrix 
c***********************************************************
         r0Loc=1./Rcell-1./Rconn
c #ifdef DEBUG
c         if (icircuit .eq. 1) then
c            write(iomsg,'(a15,4e12.4)') 'r0Loc',
c     &           Rcell,Rconn,r0loc,1/r0Loc
c         endif
c #endif
         goto 444
         if (r0Loc .le. 0.) then
            write(*,*) 
     &           'error setting Rconn in em_generalizedRandles'
            write(iomsg,*) 
     &           'error setting Rconn in em_generalizedRandles'
            call adios(TC_ERROR)
         endif
 444     continue
c
         r0Loc=1./r0Loc
c
         Vcell=phi1-phi2
         current(icircuit)=
c     &        -1./r0Loc*Vcell
     &        -1./rcell*vcell*0.
     &        +1./Rcell*(
     &        Up-Un+2*R*T/F*log((sqrt(mp*mp+4)+mp)/2)
     &        +2*R*T/F*log((sqrt(mn*mn+4)+mn)/2))
c*********************************************************************
c update state variables and copy them to circuitData
c*********************************************************************     
         xp = x0p+xi*dt/F*(3/Rp*(1-epsp-epspf))/csmaxp
         xn = x0n-xi*dt/F*(3/Rn*(1-epsn-epsnf))/csmaxn
c     
         r_mem(circuitData+ioff+
     &        ixp)=xp
         r_mem(circuitData+ioff+
     &        ixn)=xn
c*********************************************************************
c copy variables to corresponding arrays so that they can be output
c to em_xxx.dat and d3plots 
c*********************************************************************
         call em_randlePutVal(
     &        icircuit,
     &        em_randle_i,
     &        xi)
         call em_randlePutVal(
     &        icircuit,
     &        em_randle_v,
     &        Vcell)
c
         xsoc=0.
         call em_randlePutVal(
     &        icircuit,
     &        em_randle_soc,
     &        xsoc)
ctest
c         current(icircuit)=8.5516004562377930
c
c
 100     continue
c #ifdef DEBUG
c         if (icircuit .eq. 1) then
c            write(iomsg,'(a15,i5,13e12.4)') 'echem',
c     &           iem_cntl(iem_nstep),
c     &           Rcell,
c     &           Vcell,
c     &           F,
c     &           Up,
c     &           Un,
c     &           F,
c     &           kn,
c     &           Sn,
c     &           mp,
c     &           mn,
c     &           log((sqrt(mp*mp+4)+mp)/2),
c     &           log((sqrt(mn*mn+4)+mn)/2),
c     &           current(icircuit)
c            write(iomsg,1000) icircuit,Vcell,current(icircuit),time,
c     &           xi
c            write(iomsg,'(a15,2i5,2e12.4)') 'echemCurrent',
c     &           iem_cntl(iem_nstep),
c     &           icircuit,
c     &           xi,
c     &           current(icircuit)
c            write(iomsg,'(a15,9e12.4)') 'check',Vcell,Rcell,Up,Un,mp,mn,
c     &           current(icircuit),phi1,phi2
c         endif
c #endif
      enddo
c
      call em_writeMessag(3,iomsg,
     &     'exit user_em_GR_simpleEchem   ')
c
 1000 format('icircuit=',i5,' Vcell=',e12.4,
     &     ' Current=',e12.4,' Time=',e12.4,
     &     ' Current2=',e12.4)
c
      return
      end
c
c*********************************************************************
c*********************************************************************
c EP set fiber orientation
c*********************************************************************
c*********************************************************************
c
      subroutine user_em_FO_writeSPCD(
     &     numnp,
     &     numelh,
     &     dm_ixh,
     &     dm_x,
     &     mpp_nsort,
     &     mpp_nsrh,
     &     mpp_numelh,
     &     mpp_numnp,
     &     iam)
c******************************************************************
c|  livermore software technology corporation  (lstc)             |
c|  ------------------------------------------------------------  |
c|  copyright 1987-2004 Livermore Software Tech. Corp.            |
c|  all rights reserved                                           |
c******************************************************************
c
c accumulates the data coming from solverRH for the fiber orient
c
c----------------------------------------------------------------------
      implicit none
c
      integer numnp
      integer numelh
      integer dm_ixh(*)
      real dm_x(*)
      integer mpp_nsort(*)
      integer mpp_nsrh(*)
      integer mpp_numelh
      integer mpp_numnp
      integer iam
c
      include 'iounits.inc'
      include 'memaia.inc'
      integer iscratch(5)
      include 'nlqparm'
#include "meshes.inc"
#include "dynmem.inc"
#include "em.inc"
c
      integer ioutD3p
      integer iele,ieleUser
      integer ieleAL,ieleAG,ieleFL
      integer inode,inodeFL,inodeAL,inodeAG
      integer ioff
      integer iout4,iout5
      integer numEle,numEleGlob,ipartInt,ipartUser,ieleType,numEleFL
      integer numNodeGlob
      integer*4 nodeConnectivity4(8)
      integer ilcidUs,idff,ierr
      integer wordsper
      integer nodeConnectGlob(8)
      integer nodeUser(8)
      integer incycle
      integer i
c
      real plotScalPot1,plotScalPot2,xnorma,xnormd
      real theta,xpi,alpha,beta
      real eleCenter(3)
      real currDen1(3),currDen2(3),avector(3),arotate(3),dvector(3)
      real e0(3),e1(3),e2(3),ef(3)
      real longitudinal(3),transverse(3)
      real rnodesArray(24)
      real func(10)
      real timeFL
      real AOPT
      integer MACF
      real XP,YP,ZP
      real V1,V2,V3
      real A1,A2,A3
      real D1,D2,D3
      real r3eleNode(24)
      real abcInXYZ(9)
      real xnormaDiff
      real avectorDiff(3)
c
      MINDEX em_elementadvector
      MINDEX em_elementabcvector
      MINDEX em_lc1h
      MINDEX em_elementadvectorGlob
      MINDEX em_elementabcvectorGlob
      MINDEX em_lc1hGlob
      MINDEX em_eleFLtoEleAL
      MINDEX em_dmx_glob
c
      integer lqfinv,lqfb,lqfmiv
      external lqfinv,lqfb,lqfmiv
      real eval_function
      external eval_function
c
      character*30 filename15
c
      call em_writeMessag(3,iomsg,
     &     'enter user_em_FO_writeSPCD    ')
c
      if (iem_cntl(IEM_NSTEP) .gt. 2) then
         call em_writeMessag(3,iomsg,
     &        'exit user_em_FO_writeSPCD22   ')
         call em_smpp_stop
         return
      endif
c
      if (iem_cntl(IEM_NSTEP) .eq. 1) then
         em_epfo_eleALtoEMfields=mem_alloc(4*numelh*2)
      endif
c
      xpi=3.14159265358
c
c*********************************************************************
c accumulate data
c*********************************************************************
      do ieleAL=1,numelh
         ieleUser=lqfinv(iele,TYPE_SOLID_ELE)
         ioff=4*numelh*(iem_cntl(IEM_NSTEP)-1)
         r_mem(em_epfo_eleALtoEMfields+4*(ieleAL-1)+0+ioff)=
     &        r_mem(em_plotScalPot+ieleAL-1)
         call blkcpy(
     &        r_mem(em_plotCurrDen1Bem+3*(ieleAL-1)+0),
     &        r_mem(em_epfo_eleALtoEMfields+4*(ieleAL-1)+1+ioff),
     &        3)
      enddo
c*********************************************************************
c compute local orientation at element and store it
c each cpu does its elements
c*********************************************************************
      if (iem_cntl(IEM_NSTEP) .eq. 2) then
c
         numEle=numelh
         numEleFL=iem_nvol_eles
#ifdef MPP
         numEleGlob=mpp_numelh
         numNodeGlob=mpp_numnp
#else
         numEleGlob=numelh
         numNodeGlob=numnp
#endif
c
         em_eleFLtoEleAL=mem_alloc(iem_nvol_eles)
         do ieleFL=1,numEleFL
            ieleAL=i_mem(em_cond_eles+2*(ieleFL-1)+1)
           i_mem(em_eleFLtoEleAL+ieleFL-1)=ieleAL
         enddo
c
         em_elementadvector=mem_alloc(6*numEle)
         em_elementabcvector=mem_alloc(9*numEle)
         em_lc1h=mem_alloc(9*numEle)
c
         do ieleAL=1,numEle
c
#ifdef MPP
            ieleAG=mpp_nsrh(ieleAL)
#else 
            ieleAG=ieleAL
#endif
            ipartInt=dm_ixh(1+9*(ieleAL-1)+0)
            ipartUser=lqfmiv(ipartInt)
c
            ieleFL=lqfb(ieleAL,i_mem(em_eleFLtoEleAL),numEleFL,ierr)
c***********************************************************
            if (ierr .ne. 0) then
c this is NOT a conductor element
c***********************************************************
               i_mem(em_lc1h+9*(ieleAL-1)+0)=ipartUser
               do inode=1,8
                  inodeAL=dm_ixh(1+9*(ieleAL-1)+inode)
#ifdef MPP
                  inodeAG=mpp_nsort(inodeAL)
#else 
                  inodeAG=inodeAL
#endif
                  i_mem(em_lc1h+9*(ieleAL-1)+inode)=inodeAG
               enddo
c***********************************************************
            else
c this is a conductor element
c***********************************************************
               ieletype=i_mem(em_cond_eles+2*(ieleFL-1))
               call em_getEleNodeIdAndConnect(
     &              ieleFL,
     &              ieleType,
     &              nodeConnectivity4,
     &              rNodesArray)
c
               call em_eleAllCenter(
     &              ieleAL,
     &              eleCenter)
c read local scalPot and current density
               ioff=0
               plotScalPot1=r_mem(em_epfo_eleALtoEMfields+
     &              4*(ieleAL-1)+0+ioff)
               call blkcpy(
     &              r_mem(em_epfo_eleALtoEMfields+4*(ieleAL-1)+1+ioff),
     &              currDen1,
     &              3)
c
               ioff=4*numelh
               plotScalPot2=r_mem(em_epfo_eleALtoEMfields+
     &              4*(ieleAL-1)+0+ioff)
               call blkcpy(
     &              r_mem(em_epfo_eleALtoEMfields+4*(ieleAL-1)+1+ioff),
     &              currDen2,
     &              3)
c
               call em_normalizeVector2(
     &              3,
     &              currDen1)
               call em_normalizeVector2(
     &              3,
     &              currDen2)
c
               call blkcpy(currDen1,e1,3)
               call blkcpy(currDen2,e2,3)
c     
               call em_crossProduct(
     &              e0,
     &              e1,
     &              e2)
c***********************************************************
c alpha
c***********************************************************
               if (em_epfo_alpha .gt. 0.) then
                  alpha=em_epfo_alpha
               else 
c alpha is defined by a load curve
                  ilcidus=-int(em_epfo_alpha)
                  call em_lcidUsToIdff(ilcidUs,idff)
                  func(1)=eleCenter(1)
                  func(2)=eleCenter(2)
                  func(3)=eleCenter(3)
                  func(4)=plotScalPot1
                  func(5)=plotScalPot2
c
                  alpha=eval_function(idff,func,ierr)
               endif
c
               call em_linearCombination(
     &              3,
     &              longitudinal,
     &              cos(alpha),e0,
     &              sin(alpha),e1)
cccccccccc KARIMbegin ccccccccccccccccccccccccccccccccccccccccccccccccc
               call em_linearCombination(
     &              3,
     &              ef,
     &              -sin(alpha),e0,
     &              cos(alpha),e1)
cccccccccc KARIMend ccccccccccccccccccccccccccccccccccccccccccccccccc

c***********************************************************
c beta
c***********************************************************
               if (em_epfo_beta .gt. 0.) then
                  beta=em_epfo_beta
               else 
c beta is defined by a load curve
                  ilcidus=-int(em_epfo_beta)
                  call em_lcidUsToIdff(ilcidUs,idff)
                  func(1)=eleCenter(1)
                  func(2)=eleCenter(2)
                  func(3)=eleCenter(3)
                  func(4)=plotScalPot1
                  func(5)=plotScalPot2
c
                  beta=eval_function(idff,func,ierr)
               endif
c
cccccccccc KARIMbegin ccccccccccccccccccccccccccccccccccccccccccccccc
               call em_linearCombination(
     &              3,
     &              transverse,
     &              cos(beta),e2,
     &              -sin(beta),ef)
cccccccccc KARIMend ccccccccccccccccccccccccccccccccccccccccccccccccc
c
c               call em_linearCombination(
c     &              3,
c     &              transverse,
c     &              cos(beta),e2,
c     &              -sin(beta),longitudinal)
c     
               call blkcpy(longitudinal,avector,3)
               call blkcpy(transverse,dvector,3)
c
               call em_getNorm(3,xnorma,avector)
               call em_getNorm(3,xnormd,dvector)
c test    
c            avector(1)=1.
c            avector(2)=0.
c            avector(3)=0.
cc     
c            dvector(1)=0.
c            dvector(2)=0.
c            dvector(3)=1.
c
c dvector=currDen11
c         theta=30.
c            theta=(160*eleCenter(3)/3.-80.)*xpi/180.
c            theta=0.
c            call em_linearCombination(
c     &           3,
c     &           arotate,
c     &           cos(theta),avector,
c     &           sin(theta),dvector)
c***********************************************************
c get (a,b,c) local referential
c***********************************************************
c FOR NOW:
               AOPT=2.
               XP=0.
               YP=0.
               ZP=0.
               V1=0.
               V2=0.
               V3=0.
               call azero(r3eleNode,24)
               ieleType=em_hex
c
               A1=avector(1)
               A2=avector(2)
               A3=avector(3)
c
               D1=dvector(1)
               D2=dvector(2)
               D3=dvector(3)
c
               call em_eleGetMatReferentiel(
     &              ieleType,
     &              r3eleNode,
     &              AOPT,MACF,
     &              XP,YP,ZP,
     &              A1,A2,A3,
     &              V1,V2,V3,
     &              D1,D2,D3,
     &              abcInXYZ)
c
               call blkcpy(
     &              abcInXYZ(1),
     &              r_mem(em_elementabcVector+9*(ieleAL-1)+0),
     &              3)
               call blkcpy(
     &              abcInXYZ(4),
     &              r_mem(em_elementabcVector+9*(ieleAL-1)+3),
     &              3)
               call blkcpy(
     &              abcInXYZ(7),
     &              r_mem(em_elementabcVector+9*(ieleAL-1)+6),
     &              3)
c #ifdef DEBUG
               ieleUser=lqfinv(ieleAL,TYPE_SOLID_ELE)
               write(iomsg,'(a40)') 
     &              '****************************************'
               write(iomsg,'(a15,3i7,4e12.4)') 'currDen1',
     &              ieleAL,
     &              ieleAG,
     &              ieleUser,
     &              alpha,
     &              beta,
     &              xnorma,
     &              xnormd
               write(iomsg,'(a15,3e12.4)') 'e0',
     &              e0(1),
     &              e0(2),
     &              e0(3)
               write(iomsg,'(a15,3e12.4)') 'e1',
     &              e1(1),
     &              e1(2),
     &              e1(3)
               write(iomsg,'(a15,3e12.4)') 'e2',
     &              e2(1),
     &              e2(2),
     &              e2(3)
               write(iomsg,'(a15,3e12.4)') 'ef',
     &              ef(1),
     &              ef(2),
     &              ef(3)
               write(iomsg,'(a15,3e12.4)') 'transverse',
     &              transverse(1),
     &              transverse(2),
     &              transverse(3)
               write(iomsg,'(a15,3e12.4)') 'avector',
     &              avector(1),
     &              avector(2),
     &              avector(3)
               write(iomsg,'(a15,3e12.4)') 'dvector',
     &              dvector(1),
     &              dvector(2),
     &              dvector(3)
               write(iomsg,'(a15,3e12.4)') 'avectorFromabc',
     &              abcInXYZ(1),
     &              abcInXYZ(2),
     &              abcInXYZ(3)
c
               call em_linearCombination(
     &              3,
     &              avectorDiff,
     &              +1.,avector,
     &              -1.,abcInXYZ)
               call em_getNorm(3,xnorma,avector)
               call em_getNorm(3,xnormaDiff,avectorDiff)
               if (xnormaDiff .gt. 1.e-9*xnorma) then
                  write(iomsg,'(a15,3e12.4)') 'errorAdiff',
     &                 ieleAL,
     &                 xnormaDiff,xnorma
               endif
c #endif
c
               call blkcpy(
     &              avector,
     &              r_mem(em_elementadvector+6*(ieleAL-1)+0),
     &              3)
               call blkcpy(
     &              dvector,
     &              r_mem(em_elementadvector+6*(ieleAL-1)+3),
     &              3)
c 
               i_mem(em_lc1h+9*(ieleAL-1)+0)=ipartUser
               do inode=1,8
                  inodeFL=nodeConnectivity4(inode)
                  inodeAL=i_mem(em_cond_nds+inodeFL-1)
#ifdef MPP
                  inodeAG=mpp_nsort(inodeAL)
#else 
                  inodeAG=inodeAL
#endif
                  i_mem(em_lc1h+9*(ieleAL-1)+inode)=inodeAG
               enddo
c***********************************************************
            endif
c endif on conductor/not conductor
c***********************************************************
c enddo on ieleAL
         enddo
c*********************************************************************
c distribute element local coordinates
c*********************************************************************
#ifdef MPP
         wordsper=6
         call em_procToGlobMindexb(
     &        numEle,
     &        wordsper,
     &        em_elementadvector,
     &        mpp_numelh,
     &        mpp_nsrh,
     &        em_elementadvectorGlob,
     &        em_BM_real)
c
         wordsper=9
         call em_procToGlobMindexb(
     &        numEle,
     &        wordsper,
     &        em_elementabcvector,
     &        mpp_numelh,
     &        mpp_nsrh,
     &        em_elementabcvectorGlob,
     &        em_BM_real)
c
         wordsper=9
         call em_procToGlobMindexb(
     &        numEle,
     &        wordsper,
     &        em_lc1h,
     &        mpp_numelh,
     &        mpp_nsrh,
     &        em_lc1hGlob,
     &        em_BM_int)
c     
         wordsper=3
         call em_procToGlobMindexbx(
     &        numnp,
     &        wordsper,
     &        dm_x,
     &        mpp_numnp,
     &        mpp_nsort,
     &        em_dmx_glob)
#else
         call em_copyMindex(
     &        em_elementadvector,
     &        em_elementadvectorGlob,
     &        em_BM_real)
         call em_copyMindex(
     &        em_elementabcvector,
     &        em_elementabcvectorGlob,
     &        em_BM_real)
         call em_copyMindex(
     &        em_lc1h,
     &        em_lc1hGlob,
     &        em_BM_int)
         call em_copyMindexbx(
     &        3*numnp,
     &        dm_x,
     &        em_dmx_glob)
#endif
c*********************************************************************
c write element file
c*********************************************************************
         if (iam .eq. 0) then
c***********************************************************
c write element files
c***********************************************************   
            iout4=731
            filename15='element_solid.k'
            open (unit=iout4,file=filename15,status='unknown')
            write(iout4,'(a14)') '*ELEMENT_SOLID' 
c     
            iout5=732
            filename15='element_solid_ortho.k'
            open (unit=iout5,file=filename15,status='unknown')
            write(iout5,'(a20)') '*ELEMENT_SOLID_ORTHO'
         endif
c     
         do iele=1,numEleGlob
c     
            ipartUser=i_mem(em_lc1hGlob+9*(iele-1)+0)
            call blkcpy(
     &           i_mem(em_lc1hGlob+9*(iele-1)+1),
     &           nodeConnectGlob,
     &           8)
c     
            call blkcpy(
     &           r_mem(em_elementadvectorGlob+6*(iele-1)+0),
     &           avector,
     &           3)
            call blkcpy(
     &           r_mem(em_elementadvectorGlob+6*(iele-1)+3),
     &           dvector,
     &           3)
c
c            call blkcpy(
c     &           r_mem(em_elementabcvectorGlob+9*(iele-1)+0),
c     &           avector2,
c     &           3)
c            call blkcpy(
c     &           r_mem(em_elementabcvectorGlob+9*(iele-1)+3),
c     &           bvector2,
c     &           3)
c            call blkcpy(
c     &           r_mem(em_elementabcvectorGlob+9*(iele-1)+6),
c     &           cvector2,
c     &           3)
c     
            call em_getNorm(3,xnorma,avector)
c go from internal to user Id
            call em_eleAllGlobSortedToEleUser(iele,ieleUser)
            do inode=1,8
               call em_nodeAllGlobToNodeUser(
     &              nodeConnectGlob(inode),
     &              nodeUser(inode))
            enddo
c     
            if (iam .eq. 0) then
               if (xnorma .ne. 0.) then
c *element_solid_ortho
                  write(iout5,'(2i8)') 
     &                 ieleUser,
     &                 ipartUser
                  write(iout5,'(8i8)') 
     &                 nodeUser(1),
     &                 nodeUser(2),
     &                 nodeUser(3),
     &                 nodeUser(4),
     &                 nodeUser(5),
     &                 nodeUser(6),
     &                 nodeUser(7),
     &                 nodeUser(8)
c
                  write(iout5,'(3e16.8)')
     &                 avector(1),
     &                 avector(2),
     &                 avector(3)
                  write(iout5,'(3e16.8)')
     &                 dvector(1),
     &                 dvector(2),
     &                 dvector(3)
               else
*element_solid
                  write(iout4,'(10i8)')
     &                 ieleUser,
     &                 ipartUser,
     &                 nodeUser(1),
     &                 nodeUser(2),
     &                 nodeUser(3),
     &                 nodeUser(4),
     &                 nodeUser(5),
     &                 nodeUser(6),
     &                 nodeUser(7),
     &                 nodeUser(8)
               endif
            endif
c     
         enddo
c     
         if (iam .eq. 0) then
            write(iout4,'(a4)') '*END' 
            close(iout4)
c     
            write(iout5,'(a4)') '*END' 
            close(iout5)
c***********************************************************
c write fiber orientation debug file
c***********************************************************
#ifdef DEBUG  
            call em_d3p_writeMeshWithAD(
     &           numNodeGlob,
     &           numEleGlob,
     &           r_mem(em_dmx_glob),
     &           i_mem(em_lc1hGlob),
     &           r_mem(em_elementadvectorGlob),
     &           'd3p_FO_advectors')
c
            call em_vtk_writeMeshWithAD(
     &           numNodeGlob,
     &           numEleGlob,
     &           r_mem(em_dmx_glob),
     &           i_mem(em_lc1hGlob),
     &           r_mem(em_elementadvectorGlob),
     &           'vtk_FO_ADvectors')
c
            call em_vtk_writeMeshWithADabc(
     &           numNodeGlob,
     &           numEleGlob,
     &           r_mem(em_dmx_glob),
     &           i_mem(em_lc1hGlob),
     &           r_mem(em_elementadvectorGlob),
     &           r_mem(em_elementabcvectorGlob),
     &           'vtk_FO_ADabcvectors')
#endif
c***********************************************************
c test field lines
c***********************************************************
c            call em_orthoElementADVectorToPlotArray(
c     &           numelh,
c     &           r_mem(em_plotCurrDen2Bem),
c     &           r_mem(em_plotElecFieldBem))
c #ifdef DEBUG
c            do iele=1,numelh
c               call blkcpy(
c     &              r_mem(em_elementadvectorGlob+6*(iele-1)+0),
c     &              r_mem(em_plotCurrDen2Bem+3*(iele-1)),
c     &              3)
c               call blkcpy(
c     &              r_mem(em_elementadvectorGlob+6*(iele-1)+3),
c     &              r_mem(em_plotElecFieldBem+3*(iele-1)),
c     &              3)
c               write(iomsg,'(a15,i5,3e12.4)') 'AvectorXX',
c     &              iele,
c     &              r_mem(em_plotCurrDen2Bem+3*(iele-1)+0),   
c     &              r_mem(em_plotCurrDen2Bem+3*(iele-1)+1),   
c     &              r_mem(em_plotCurrDen2Bem+3*(iele-1)+2)
c               write(iomsg,'(a15,i5,3e12.4)') 'DvectorXX',
c     &              iele,
c     &              r_mem(em_plotElecFieldBem+3*(iele-1)+0),   
c     &              r_mem(em_plotElecFieldBem+3*(iele-1)+1),   
c     &              r_mem(em_plotElecFieldBem+3*(iele-1)+2)
c            enddo
c #endif
c            incycle=0
c            timeFL=1.
c            call em_OI_write_FLData(incycle,timeFL)
c***********************************************************
c end test field lines
c***********************************************************          
c endif on iam=0
         endif
c endif on nstep=2
      endif
c***********************************************************
c free memory
c***********************************************************
      call em_mem_freeZero(em_elementadvector)
      call em_mem_freeZero(em_elementabcvector)
      call em_mem_freeZero(em_lc1h)
      call em_mem_freeZero(em_elementadvectorGlob)
      call em_mem_freeZero(em_elementabcvectorGlob)
      call em_mem_freeZero(em_lc1hGlob)
      call em_mem_freeZero(em_eleFLtoEleAL)
      call em_mem_freeZero(em_dmx_glob)
c
      call em_writeMessag(3,iomsg,
     &     'exit user_em_FO_writeSPCD     ')
c
      return
      end
c
      subroutine user_EP_cellModel(
     &     time,
     &     timeStep,
     &     ioff,
     &     inodeFLOT,
     &     inodeFG,
     &     inodeUser,
     &     r3node,
     &     numPhi,
     &     phiVal,
     &     ipartUser,
     &     imodelId,
     &     xnodeToCellModVal,
     &     vnodetoCellModVal,
     &     VoneNode,
     &     calciumConc,
     &     Iext,
     &     isInit)
c******************************************************************
c|  livermore software technology corporation  (lstc)             |
c|  -------------------1-----------------------------------------  |
c|  copyright 1987-2004 Livermore Software Tech. Corp.            |
c|  all rights reserved                                           |
c******************************************************************
c
c typical usermat routine for generalized randles circuit 
c
      implicit none
c
      real time
      real timeStep
      integer ioff
      integer inodeFLOT
      integer inodeFG
      integer inodeUser
      real r3node(3)
      integer numPhi
      real phiVal(numPhi)
      integer ipartUser
      integer imodelId
      MINDEX xnodeToCellModVal
      MINDEX vnodetoCellModVal
      real VoneNode
      real calciumConc
      real Iext
      integer isInit
c*********************************************************************
c numPhi and phiVal are the number and values of the phi's 
c at the node as defined by *EM_EP_FIBERINITIAL
c*********************************************************************
c
      include 'iounits.inc'
#include "meshes.inc"
#include "dynmem.inc"
#include "em.inc"
#include "LCPACK.inc"
#include "SPOOLES.inc"
c
      integer numState
      integer numConst
      integer numVal
c
      real CONSTS(1000)
      real STATES(1000)
      real alpha,beta,gamma,c,mu1,mu2
      real phi,r
      real dphidt,drdt
c
      call em_writeMessag(4,iomsg,
     &     'enter user_EP_cellModel       ')
c
c #ifdef DEBUG
      if (Iext .ne. 0.) then
         write(iomsg,'(a15,2i9,e12.4)') 'userCM-Iext2',
     &        iem_cntl(iem_nstep),
     &        inodeFLOT,
     &        Iext
      endif
c #endif
c
c*************************************************
c part user can change
c numState and numConst can be different for different inodeUser
c but for a given inodeUser, it needs to be the same at
c the different time steps
c*************************************************
         numState=2
         numConst=6
         numVal=numState+numConst
c
      if (isInit .eq. ITRUE_EM) then
c*********************************************************************
c initialization at first time step
c*********************************************************************
c*************************************************
c part user should not change
c*************************************************
c
         i_mem(xnodetoCellModVal+inodeFLOT)=
     &        i_mem(xnodetoCellModVal+inodeFLOT-1)+
     &        numVal
         call em_mindexIncrease3(
     &        vnodeToCellModVal,
     &        ioff+numVal)
c
         call blkcpy(
     &        r_mem(vnodetoCellModVal+
     &        ioff),
     &        CONSTS,
     &        numConst)
         call blkcpy(
     &        r_mem(vnodetoCellModVal+
     &        ioff+numConst),
     &        STATES,
     &        numState)
c*************************************************
c part user can change
c*************************************************
         CONSTS(1)=0.01
         CONSTS(2)=0.15
         CONSTS(3)=0.002
         CONSTS(4)=8.
         CONSTS(5)=0.2
         CONSTS(6)=0.3
c
         STATES(1)=-80.
         STATES(2)=0.
c*************************************************
c part user should not change
c*************************************************
         call blkcpy(
     &        CONSTS,
     &        r_mem(vnodeToCellModVal+
     &        ioff),
     &        numConst)
         call blkcpy(
     &        STATES,
     &        r_mem(vnodeToCellModVal+
     &        ioff+numConst),
     &        numState)
c
         ioff=ioff+numVal
c
      else
c*********************************************************************
c advance one time step
c*********************************************************************
c*************************************************
c part user should not change
c*************************************************
         call blkcpy(
     &        r_mem(vnodeToCellModVal+
     &        ioff),
     &        CONSTS,
     &        numConst)
         call blkcpy(
     &        r_mem(vnodeToCellModVal+
     &        ioff+numConst),
     &        STATES,
     &        numState)
c*************************************************
c part user can change
c*************************************************
c the coefficients in 
c phi=(phi+80.)/100.
c phi=100.*phi-80
c and /12.9
c come from equation (1) and (2) of the paper:
c "a simple two-variable model of cardiac excitation"
c R.R Aliev and A.V. Panfilov, Chaos, 7-3, 1996, pp 293-301
c the 12.9 gives a time in ms
c
         if (iem_cntl(IEM_NSTEP) .eq. 1) then
         else
            STATES(1)=VoneNode
         endif
c
         alpha=CONSTS(1)
         beta=CONSTS(2)
         gamma=CONSTS(3)
         c=CONSTS(4)
         mu1=CONSTS(5)
         mu2=CONSTS(6)
c
         phi=STATES(1)
         r=STATES(2)
c
         phi=(phi+80.)/100.
c     
         dphidt=-c*phi*(phi-alpha)*(phi-1)-r*phi+Iext
         drdt=(gamma+r*mu1/(mu2+phi))*(-r-c*phi*(phi-beta-1))
c     
         phi=phi+timeStep*dphidt/12.9
         r=r+timeStep*drdt/12.9
c
         phi=100.*phi-80
c
c*********************************************************************
c copy STATES
c*********************************************************************
c*************************************************
c part user can change
c*************************************************
         STATES(1)=phi
         STATES(2)=r
c*********************************************************************
c copy new states and consts to cellModVal
c*********************************************************************
c*************************************************
c part user should not change
c*************************************************
         call blkcpy(
     &        CONSTS,
     &        r_mem(vnodeToCellModVal+
     &        ioff),
     &        numConst)
         call blkcpy(
     &        STATES,
     &        r_mem(vnodeToCellModVal+
     &        ioff+numConst),
     &        numState)
c*********************************************************************
c update V
c********************************************************************* 
         VoneNode=STATES(1)
c
      endif
c
      call em_writeMessag(4,iomsg,
     &     'exit user_EP_cellModel        ')
c
      return
      end
c*********************************************************************
c*********************************************************************
c test for FMM, sending the BEM mesh
c*********************************************************************
c*********************************************************************
      subroutine user_em_fmm_test1(
     &     numNode,
     &     numFace,
     &     r3node,
     &     faceToNode)
c******************************************************************
c|  livermore software technology corporation  (lstc)             |
c|  -------------------1-----------------------------------------  |
c|  copyright 1987-2004 Livermore Software Tech. Corp.            |
c|  all rights reserved                                           |
c******************************************************************
c
c typical usermat routine for generalized randles circuit 
c
      implicit none
c
      integer numNode
      integer numface
      real r3node(3*numNode)
      integer faceToNode(4*numFace)
c
      include 'iounits.inc'
#include "dynmem.inc"
#include "em.inc"
#include "LCPACK.inc"
#include "SPOOLES.inc"
c
      integer inode,iface
c
      call em_writeMessag(3,iomsg,
     &     'enter user_em_fmm_test1       ')
c
      do inode=1,numNode
         write(iomsg,'(a15,i9,3e12.4)') 'nodeCoordinate',
     &        inode,
     &        r3node(3*(inode-1)+1),
     &        r3node(3*(inode-1)+2),
     &        r3node(3*(inode-1)+3)
      enddo
c
      do iface=1,numFace
         write(iomsg,'(a15,5i9)') 'faceToNode',
     &        iface,
     &        faceToNode(4*(iface-1)+1),
     &        faceToNode(4*(iface-1)+2),
     &        faceToNode(4*(iface-1)+3),
     &        faceToNode(4*(iface-1)+4)
      enddo
c
      call em_smpp_stop
c
c
      call em_writeMessag(3,iomsg,
     &     'exit user_em_fmm_test1        ')
c
      return
      end
c
      subroutine user_getEMForceArray(idim,
     &     ieleUser,func,elevec)
      implicit none
      integer idim,ieleUser
      real func(27),elevec(idim)
ccccccc
ccccccc
c func(1-3) = Velocity field
c func(4) = Temperature
c func(5) = Pressure
c func(6) = Density
c func(7)= Element Volume
c func(9-11) = Electric Field
c func(12-14) = B field
c func(15-17) = Lorentz Force
c func(18) = Joule H rate
c func(19) = EM time
c func(20) = Effective stress (VM)
c func(21) = Effective strain
c func(22-24) = Coord
c func(25-27) = Current Den
c
      elevec(1)=func(7)*(func(26)*func(14)-func(27)*func(13))
      elevec(2)=-func(7)*(func(25)*func(14)-func(27)*func(12))
      elevec(3)=func(7)*(func(25)*func(13)-func(26)*func(12))
      return
      end
      subroutine user_getEMCond(ieosid,
     &     ieleUser,func,elecond)
      implicit none
      integer idim,ieleUser,ieosid
      real func(100),elecond
ccccccc
ccccccc
c if Not mat003 or mat005 :
c func(1-3) = Velocity field
c func(4) = Temperature
c func(5) = Pressure
c func(6) = Density
c func(7)= Element Volume
c func(9-11) = Electric Field
c func(12-14) = B field
c func(15-17) = Lorentz Force
c func(18) = Joule H rate
c func(19) = EM time
c func(20) = Effective stress (VM)
c func(21) = Effective strain
c func(22-24) = Coord
c func(25-27) = Current Den
c
c elseif mat003 or mat005
c
c func(1) = EM time
c func(2) = EM DT
c func(3-5) = ele coord
c func(6-14) = initial fiber phi (if they exist)
c func (14-23) = initial fiber curr (if they exist)
c func(24-26) = Velocity field
c func(27) = Temperature
c func(28) = Pressure
c func(29) = Density
c func(30)= Element Volume
c func(32) = Effective stress (VM)
c func(33) = Effective strain
c func(34-36) = Current Den
      
      elecond=func(7)*(func(26)*func(14)-func(27)*func(13))
c #ifdef DEBUG
c      eleCond=1.e-4
c      write(*,'(a15,2i5,e12.4)') 'eosDefFunc',
c     &     ieosId,ieleUser,eleCond
c #endif
      return
      end
c
      subroutine user_EP_cellModel_karimMS(
     &     time,
     &     timeStep,
     &     ioff,
     &     inodeFLOT,
     &     inodeFG,
     &     inodeUser,
     &     r3node,
     &     numPhi,
     &     phiVal,
     &     ipartUser,
     &     imodelId,
     &     xnodeToCellModVal,
     &     vnodetoCellModVal,
     &     VoneNode,
     &     Iext,
     &     isInit)
c******************************************************************
c|  livermore software technology corporation  (lstc)             |
c|  -------------------1-----------------------------------------  |
c|  copyright 1987-2004 Livermore Software Tech. Corp.            |
c|  all rights reserved                                           |
c******************************************************************
c
c typical usermat routine for generalized randles circuit 
c
      implicit none
c
      real time
      real timeStep
      integer ioff
      integer inodeFLOT
      integer inodeFG
      integer inodeUser
      real r3node(3)
      integer numPhi
      real phiVal(numPhi)
      integer ipartUser
      integer imodelId
      integer*8 xnodeToCellModVal
      integer*8 vnodetoCellModVal
      real VoneNode
      real Iext
      integer isInit
c*********************************************************************
c numPhi and phiVal are the number and values of the phi's 
c at the node as defined by *EM_EP_FIBERINITIAL
c*********************************************************************
c
      include 'iounits.inc'
#include "meshes.inc"
#include "dynmem.inc"
#include "em.inc"
#include "LCPACK.inc"
#include "SPOOLES.inc"
c
      integer numState
      integer numConst
      integer numVal
c
      real CONSTS(1000)
      real STATES(1000)
c      real alpha,beta,gamma,c,mu1,mu2
      real Vmin,Vmax,Vgate,tin,tout,topen,tclose,chi,CmMS
      real phi,r
      real dphidt,drdt
c#ifdef MPP
c#include "mpp.inc"
c#else
c      integer iam
c      iam=0      
c#endif      
c
      call em_writeMessag(4,iomsg,
     &     'enter user_EP_cellModel       ')
c
c #ifdef DEBUG
      if (Iext .ne. 0.) then
         write(iomsg,'(a15,2i9,e12.4)') 'userCM-Iext1',
     &        iem_cntl(iem_nstep),
     &        inodeFLOT,
     &        Iext
      endif
c #endif
c*************************************************
c part user can change
c numState and numConst can be different for different inodeUser
c but for a given inodeUser, it needs to be the same at
c the different time steps
c*************************************************
         numState=2
         numConst=9		 
         numVal=numState+numConst
c
      if (isInit .eq. ITRUE_EM) then
c*********************************************************************
c initialization at first time step
c*********************************************************************
c*************************************************
c part user should not change
c*************************************************
c
         i_mem(xnodetoCellModVal+inodeFLOT)=
     &        i_mem(xnodetoCellModVal+inodeFLOT-1)+
     &        numVal
         call em_mindexIncrease3(
     &        vnodeToCellModVal,
     &        ioff+numVal)
c
         call blkcpy(
     &        r_mem(vnodetoCellModVal+
     &        ioff),
     &        CONSTS,
     &        numConst)
         call blkcpy(
     &        r_mem(vnodetoCellModVal+
     &        ioff+numConst),
     &        STATES,
     &        numState)
c*************************************************
c part user can change
c*************************************************
c      Vmin,Vmax,Vgate,tin,tout,topen,tclose,chi,Cm
         CONSTS(1)=-80
         CONSTS(2)=20
         CONSTS(3)=-62
         CONSTS(4)=4.5
         CONSTS(5)=90
         CONSTS(6)=100
		 CONSTS(7)=150
		 CONSTS(8)=200
		 CONSTS(9)=0.001
         STATES(1)=-80.
         STATES(2)=0.

c*************************************************
c part user should not change
c*************************************************
         call blkcpy(
     &        CONSTS,
     &        r_mem(vnodeToCellModVal+
     &        ioff),
     &        numConst)
         call blkcpy(
     &        STATES,
     &        r_mem(vnodeToCellModVal+
     &        ioff+numConst),
     &        numState)
c
         ioff=ioff+numVal
c
      else
c*********************************************************************
c advance one time step
c*********************************************************************
c*************************************************
c part user should not change
c*************************************************
         call blkcpy(
     &        r_mem(vnodeToCellModVal+
     &        ioff),
     &        CONSTS,
     &        numConst)
         call blkcpy(
     &        r_mem(vnodeToCellModVal+
     &        ioff+numConst),
     &        STATES,
     &        numState)
c*************************************************
c part user can change
c*************************************************
c the coefficients in 
c phi=(phi+80.)/100.
c phi=100.*phi-80
c and /12.9
c come from equation (1) and (2) of the paper:
c "a simple two-variable model of cardiac excitation"
c R.R Aliev and A.V. Panfilov, Chaos, 7-3, 1996, pp 293-301
c the 12.9 gives a time in ms
c
         if (iem_cntl(IEM_NSTEP) .eq. 1) then
         else
            STATES(1)=VoneNode
         endif
c      Vmin,Vmax,Vgate,tin,tout,topen,tclose,chi,CmMS
         Vmin=CONSTS(1)
         Vmax=CONSTS(2)
         Vgate=CONSTS(3)
         tin=CONSTS(4)
         tout=CONSTS(5)
         topen=CONSTS(6)
		 tclose=CONSTS(7)
		 chi=CONSTS(8)
		 CmMS=CONSTS(9)
         phi=STATES(1)
         r=STATES(2)
         dphidt=r/tin*(phi-Vmin)*(phi-Vmin)*(Vmax-phi)
     &         /(Vmax-Vmin)-
     &         1/(tout)*(phi-Vmin)/(Vmax-Vmin)+Iext
         dphidt=dphidt/CmMS

c
         drdt=0	 
         if (phi < Vgate) then
			drdt=-r/topen+1/(topen*(Vmax-Vmin)**2)
         else
            drdt=-r/tclose
         endif
c
c         phi=(phi+80.)/100.
c         dphidt=-c*phi*(phi-alpha)*(phi-1)-r*phi+Iext
c         drdt=(gamma+r*mu1/(mu2+phi))*(-r-c*phi*(phi-beta-1))
c         phi=phi+timeStep*dphidt/12.9
c         r=r+timeStep*drdt/12.9
c         phi=100.*phi-80
c*********************************************************************
c copy STATES
c*********************************************************************
c*************************************************
c part user can change
c*************************************************
         STATES(1)=phi
         STATES(2)=r
c         write(iomsg,'(a15,2i16,4e12.4)') 'tidVdrVr',
c     &        iem_cntl(iem_nstep),
c	 &        inodeUser,
c	 &		  dphidt,
c     &        drdt,
c	 &		  phi,
c	 &	 	  r
c*********************************************************************
c copy new states and consts to cellModVal
c*********************************************************************
c*************************************************
c part user should not change
c*************************************************
         call blkcpy(
     &        CONSTS,
     &        r_mem(vnodeToCellModVal+
     &        ioff),
     &        numConst)
         call blkcpy(
     &        STATES,
     &        r_mem(vnodeToCellModVal+
     &        ioff+numConst),
     &        numState)
c*********************************************************************
c update V
c********************************************************************* 
         VoneNode=STATES(1)
c
      endif
c
      call em_writeMessag(4,iomsg,
     &     'exit user_EP_cellModel        ')
c
      return
      end
      subroutine user_batmac_getLHSRHS(
     &     icircuit,
     &     irandleCell,
     &     numrandlecircuit,
     &     numCircuitInCellGlob,
     &     inodeflo,
c     
     &     node_coord,
     &     nodetoPressure,
     &     nodetoEffs,
     &     nodetoStress11,
     &     nodetoStress22,
     &     nodetoStress33,
     &     nodetoStress12,
     &     nodetoStress13,
     &     nodetoStress23,
     &     nodetoStrain12,
     &     nodetoStrain13,
     &     nodetoStrain23,
     &     nodetoRho,
     &     nodetoTemp,
     &     nodetoCond,
     &     nodetoStrain,
     &     nodetoStrainLocX,
     &     nodetoStrainLocY,
     &     nodetoStrainLocZ,
c     &     em_potential1,
c     &     em_potential2,
c     &     em_current,
c     
     &     xr0,xrhs,xPower)
c
c    The purpose of this routine is to return the resistance entering the
c    the left hand side (l.h.s) part of the Laplacian equation as well as
c    the current entering the right hand side (r.h.s) of the equation.
c    This is akin to a Robin boundary condition. If using a complex chemistry
c    which allows to write d Phi/ dx = 1/alpha * (phi1-phi2) + beta, then
c    xr0=alpha and beta=xrhs. Alpha may not exist in which case, a high value of xr0 can be returned. 
c    Beware of non linear effects which may affect the stability of the solution. 
c    Contact LSTC developpers (P.and.I) for more information.
c
c
c     Examples given here include a simple first order Randles circuit
c     and a chemistry model
      implicit none
      include 'iounits.inc'
#include "dynmem.inc"
#include "em.inc"
c#include "LCPACK.inc"
c#include "SPOOLES.inc"
c
c list of input arguments
c
      integer      icircuit,
     &     irandleCell,
     &     numrandlecircuit,
     &     numCircuitInCellGlob,
     &     inodeflo
      real node_coord(3)
      real vmstress,xxvolume,xxlayersperthickness
      real xxarea,xxcurrentpre,xxpressure,xxeffs,xxstress11
      real xxstress22,xxstress33,xxstress13,xxstress12
      real xxstress23,xxstrainlocy
      real xxstrainlocz,xxstrain12,xxstrain23,xxrho
      real xxtemp,xxstrain,xxstrainlocx,xxcond
c      MINDEX em_potential1,em_potential2,em_current
      MINDEX nodetoPressure,
     &     nodetoEffs,
     &     nodetoStress11,
     &     nodetoStress22,
     &     nodetoStress33,
     &     nodetoStress12,
     &     nodetoStress13,
     &     nodetoStress23,
     &     nodetoStrain12,
     &     nodetoStrain13,
     &     nodetoStrain23,
     &     nodetoRho,
     &     nodetoTemp,
     &     nodetoCond,
     &     nodetoStrain,
     &     nodetoStrainLocX,
     &     nodetoStrainLocY,
     &     nodetoStrainLocZ
c
c list of output arguments
c
      real xr0,xrhs,xPower
c
c list of general local arguments
c
      real emtime,emdt
      integer hbh
      save hbh
      data hbh /0/
      real xcurrent,xareaCircuit,xareaCell,xareaType
c
c list of local arguments for Randles circuit model
c
      real factor
      real r0,u0,Q,r10,c10,r20,c20,cq
      real volt,soc,vc10,vc20
      MINDEX min_soc,min_vc10,min_vc20
      save min_soc,min_vc10,min_vc20
c
c     list of local arguments ofr chemistry model
      real voltage1,voltage2
      real x0p,x0n,xp,xn,epsp,epsn,epspf,epsnf,csmaxp,csmaxn,
     &     rp,rn,kp,kn,sp,sn,ce,f,r,t,rcell
      integer ix0p,ix0n,ixp,ixn,iepsp,iepsn,iepspf,iepsnf,icsmaxp
     &     ,icsmaxn,irp,irn,ikp,ikn,isp,isn,ice,iff,ir,it,ircell
      real Up,mp,Un,mn
      real xthicknessNode,xero
      real params(10),xxphi1
      real xxstrain13,vcell,xxphi2
      integer iapp
      real echem_heat
      integer numDataPerCircuit,ioff
      MINDEX circuitdata
      save circuitdata
      real socinit
      save socinit
      real short_res
      save short_res
      real cell_volume
      save cell_volume
      double precision U_NEG_spm,U_POS_spm
      integer ierr
c#ifdef MPP
c#include "mpp.inc"
c#else
c      integer iam
c      iam=0
c#endif
c
c Comment : the routines em_randlesgetval allows users
c           to access values associated to the icircuit ID.
c           Examples are given here. For a complete list, contact LSTC.
      call em_randleGetVal(
     &     icircuit,
     &     em_randle_i,
     &     xcurrent)
c     Warning : if the thickness of each unit cell (xthickUnitCell)
c     has been defined (see fifth flag of EM_RANDLES_BATMAC), then xareacircuit
c     is scaled by xthicknessNode/xthickUnitCell, otherwise,
c     xareaCircuit is the area associated to each node in the normal
c     direction of the element faces. Be aware therefore of element orientation
c     when building batmac Mesh.
      call em_randleGetVal(
     &     icircuit,
     &     em_randle_areaCircuit,
     &     xareaCircuit)
      call em_randleGetVal(
     &     icircuit,
     &     em_randle_areaCell,
     &     xareaCell)
      call em_randleGetVal(
     &     icircuit,
     &     em_randle_areaType,
     &     xareaType)
      call em_randleGetVal(
     &     icircuit,
     &     em_randle_thicknessCircuit,
     &     xthicknessNode)
      call em_randleGetVal(
     &     icircuit,
     &     em_randle_eroflag,
     &     xero)
      call em_randleGetVal(
     &     icircuit,
     &     em_randle_voltage1,
     &     voltage1)
      call em_randleGetVal(
     &     icircuit,
     &     em_randle_voltage2,
     &     voltage2)      
c      voltage1=r_mem(em_potential1+icircuit-1)
c      voltage2=r_mem(em_potential2+icircuit-1)
c    
c
      emtime=em_cntl(IEM_T)
      emdt=em_cntl(IEM_DT)
c the nodeid inodeflo allows you to access local values of strain stress
c etc etc for example :
c     VMstress=r_mem(nodetoEffs+inodeflo-1)
      VMstress=r_mem(nodetoEffs+inodeflo-1)
c     
      xxVolume = xthicknessNode*xareaCircuit
      xxLayersPerThickness = 7.204 ! number of seperator layers per unit thickness
      xxArea = (xthicknessNode*xxLayersPerThickness)*xareaCircuit
c     
c      xxCurrentPre  = r_mem(em_current+icircuit-1)
c     
      xxPressure=r_mem(nodetoPressure+inodeflo-1)
      xxEffs=r_mem(nodetoEffs+inodeflo-1)
      xxStress11=r_mem(nodetoStress11+inodeflo-1)
      xxStress22=r_mem(nodetoStress22+inodeflo-1)
      xxStress33=r_mem(nodetoStress33+inodeflo-1)
      xxStress12=r_mem(nodetoStress12+inodeflo-1)
      xxStress13=r_mem(nodetoStress13+inodeflo-1)
      xxStress23=r_mem(nodetoStress23+inodeflo-1)
      xxStrain12=r_mem(nodetoStrain12+inodeflo-1)
      xxStrain13=r_mem(nodetoStrain13+inodeflo-1)
      xxStrain23=r_mem(nodetoStrain23+inodeflo-1)
      xxRho=r_mem(nodetoRho+inodeflo-1)
      xxTemp=r_mem(nodetoTemp+inodeflo-1)
      xxCond=r_mem(nodetoCond+inodeflo-1)
      xxStrain=r_mem(nodetoStrain+inodeflo-1)
      xxStrainLocX=r_mem(nodetoStrainLocX+inodeflo-1)
      xxStrainLocY=r_mem(nodetoStrainLocY+inodeflo-1)
      xxStrainLocZ=r_mem(nodetoStrainLocZ+inodeflo-1)
c
c     Warning : the returned values are scaled by the user's choice of
c     areatype for example the factor xareaCircuit/xareaCell is applied
c     if areatype=2
c      factor=xareaCircuit/xareaCell
      factor=1.
c
c     This goto is to use the chemistry model instead of the Randles
c     or equivalent circuit model.
c     comment it out to switch to the ECM example.
c      goto 101
c     Examples of Randles Circuit parameters
c
      write(iomsg,*)'enterdyn21'
      r0=0.02
      u0=4.15;
      Q=20.;
      r10=0.002;
      c10=500.;
      r20=0.001;
      c20=1000.;
      Cq=1./36.;
      Q=factor*Q
      r10=r10/factor
      c10=factor*c10
      r20=r20/factor
      c20=factor*c20
      r0=r0/factor
c constant R0 in this case
      xr0=r0
c allocate mindex first time it enters
c      if (hbh.eq.0) then
c         hbh=1
c         min_soc=mem_alloc(numrandlecircuit)
c         min_vc10=mem_alloc(numrandlecircuit)
c         min_vc20=mem_alloc(numrandlecircuit)
c      endif
      if (emtime.lt.emdt) then
c     initial conditions
         soc=100.
         vc10=0.
         vc20=0.
         call em_randlePutVal(
     &        icircuit,
     &        em_randle_soc,
     &        soc)
         call em_randlePutVal(
     &        icircuit,
     &        em_randle_vc,
     &        vc10)
         call em_randlePutVal(
     &        icircuit,
     &        em_randle_vc2,
     &        vc20)
         xrhs=u0/r0
         return
      endif
      call em_randleGetVal(
     &     icircuit,
     &     em_randle_soc,
     &     soc)
      call em_randleGetVal(
     &     icircuit,
     &     em_randle_vc,
     &     vc10)
      call em_randleGetVal(
     &     icircuit,
     &     em_randle_vc2,
     &     vc20)
      soc=soc-emdt*xcurrent*cq/q
      vc10=(vc10
     &     -r10*xcurrent)*exp(-emdt/(r10*c10))+xcurrent*r10
      vc20=(vc20
     &     -r20*xcurrent)*exp(-emdt/(r20*c20))+xcurrent*r20
c      r_mem(min_soc+icircuit-1)=r_mem(min_soc+icircuit-1)
c     &     -emdt*xcurrent*cq/q
*save2=(*save2-r10*current)*exp(-emdt/(r10*c10))+current*r10
c      r_mem(min_vc10+icircuit-1)=(r_mem(min_vc10+icircuit-1)
c     &     -r10*xcurrent)*exp(-emdt/(r10*c10))+xcurrent*r10
c      r_mem(min_vc20+icircuit-1)=(r_mem(min_vc20+icircuit-1)
c     &     -r20*xcurrent)*exp(-emdt/(r20*c20))+xcurrent*r20
c      soc=r_mem(min_soc+icircuit-1)
c      vc10=r_mem(min_vc10+icircuit-1)
c      vc20=r_mem(min_vc20+icircuit-1)
      if (soc.gt.10.) then
c Randles circuit equation
         volt=3.6+0.55*(soc)/100.;
         xrhs=(volt-vc10-vc20)/(r0);
      elseif (soc.le.0.) then
         volt=2.8
         xrhs=0.
      else
         volt=2.8+0.855*(soc)/10.;
         xrhs=(volt-vc10-vc20)/(r0)
      endif
      call em_randlePutVal(
     &     icircuit,
     &     em_randle_soc,
     &     soc)
      call em_randlePutVal(
     &     icircuit,
     &     em_randle_vc,
     &     vc10)
      call em_randlePutVal(
     &     icircuit,
     &     em_randle_vc2,
     &     vc20)
      write(iomsg,*)'exitdyn21'
      return
cccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccc
 100  continue
      numDataPerCircuit=4
      ix0p        =0
      ix0n        =1
      ixp         =2
      ixn         =3		
c      iepsp       =4
c      iepsn       =5
c      iepspf      =6
c      iepsnf      =7
c      icsmaxp     =8
c      icsmaxn     =9
c      iRp         =10
c      iRn         =11
c      ikp         =12
c      ikn         =13
c      iSp         =14
c      iSn         =15
c      ice         =16
c      iFF         =17
c      iR          =18
c      iT          =19
c      iRcell      =20
      if (hbh.eq.0) then
         circuitData=mem_alloc(numrandlecircuit*numDataPerCircuit)
         hbh=1
      endif
      x0p = 0.485
      x0n = 0.959
      xp = 0.485
      xn = 0.959		
      epsp = 0.39
      epsn = 0.385
      epspf = 0.03
      epsnf = 0.024
      csmaxp = 51410
      csmaxn = 31833
      Rp = 10.5e-6
      Rn = 12.5e-6
      kp = 1.764e-11
      kn = 6.6667e-11
      Sp = 0.7824
      Sn = 1.1167
      ce = 1000
      F = 96485
      R = 8.314
      T = 298.15
      Rcell = 0.012/factor
      ioff=(icircuit-1)*numDataPerCircuit
      if (emtime.lt.emdt) then
c init
            r_mem(circuitData+ioff+
     &           ix0p)=x0p
            r_mem(circuitData+ioff+
     &           ix0n)=x0n
            r_mem(circuitData+ioff+
     &           ixp)=xp
            r_mem(circuitData+ioff+
     &           ixn)=xn		
      endif
c*********************************************************************
c get variables from internal arrays
c*********************************************************************
         x0p=r_mem(circuitData+ioff+
     &        ix0p)
         x0n=r_mem(circuitData+ioff+
     &        ix0n)
         xp=r_mem(circuitData+ioff+
     &        ixp)
         xn=r_mem(circuitData+ioff+
     &        ixn)		
c   The values for xp and xn if they exceed physically meaningful values, are
c   set to constant values (0.98 and 0.001). These constants can be further 
c   tweaked alongside other model parameters to make sure cell voltage never
c   goes below zero; but given that this is just an example and the detailed
c   models take care of this already, the workaround below would suffice for 
c   this example. The timestep dt has to be sufficiently small for V to stay
c   positive at higher currents.
         x0p = xp
         x0n = xn
         xp = min(xp,0.98)
         xn = max(xn,0.001)
c
c
c
c
         Up = (-4.656+88.669*xp**2.0-399.119*xp**4.0+342.909*xp**6.0
     &        -462.471*xp**8.0+433.434*xp**10.0)/(-1.0+18.933*xp**2.0
     &        -79.532*xp**4.0+37.311*xp**6.0
     &        -73.083*xp**8.0+95.96*xp**10.0)
         mp=0.
         if ((ce*(1-xp)*xp).gt.0.) then
            mp = xcurrent/F/kp/Sp/csmaxp/sqrt((ce)*(1-xp)*xp)
         endif
         Un = -0.5e-1+0.325e1*exp(-(50*xn**1.2))-
     &        0.221e0*tanh(0.20000000e2*xn-0.21000000e2)-
     &        0.105e-1*tanh(0.31347962e2*xn-0.17241379e2)-
     &        0.34e-1*tanh(0.29411765e2*xn-0.60294118e1)-
     &        0.2e-2*tanh(0.70422535e1*xn-0.13661972e1)-
     &        0.155e-1*tanh(0.77519380e2*xn-0.81395349e1)
         mn=0.
         if ((ce*(1-xn)*xn).gt.0.) then
            mn = xcurrent/F/kn/Sn/csmaxn/sqrt((ce)*(1-xn)*xn)
         endif
         xrhs=
     &        +1./Rcell*(
     &        Up-Un+2*R*T/F*log((sqrt(mp*mp+4)+mp)/2)
     &        +2*R*T/F*log((sqrt(mn*mn+4)+mn)/2))
         xrhs=max(xrhs,0.)
         xr0=Rcell
c*********************************************************************
c update state variables and copy them to circuitData
c*********************************************************************     
         xp = x0p+xcurrent*emdt/F*(3/Rp*(1-epsp-epspf))/csmaxp
         xn = x0n-xcurrent*emdt/F*(3/Rn*(1-epsn-epsnf))/csmaxn
c         if (icircuit.eq.1) write(iomsg,'(a10,11e12.4)')'xrhss',
c     &        emtime,xrhs,up,un,xp,xn,xcurrent,x0p,x0n,xp-x0p,xn-x0n
         r_mem(circuitData+ioff+
     &        ixp)=xp
         r_mem(circuitData+ioff+
     &        ixn)=xn
         r_mem(circuitData+ioff+
     &        ix0p)=x0p
         r_mem(circuitData+ioff+
     &        ix0n)=x0n
 101     continue
         numDataPerCircuit=2
      ixp        =0
      ixn        =1
c
c      write(iomsg,*)'enterdyn21anu',hbh,iam
      if (hbh.eq.0) then
         circuitData=mem_alloc(numrandlecircuit*numDataPerCircuit)
         socinit=0.9
         short_res=0.01
         cell_volume=1.
c         if (iam.eq.0) then
c            open(11,file='params.k')
c            read(11,*) params
c            socinit = params(1)
c            short_res = params(2)
c            cell_volume = params(3)
c            close(11)
c         endif
c#ifdef MPP
c         call MPI_BCAST(
c     &        socinit,
c     &        1,
c     &        MPP_REAL,
c     &        0,MPP_COMM_WORLD,ierr)
c         call MPI_BCAST(
c     &        short_res,
c     &        1,
c     &        MPP_REAL,
c     &        0,MPP_COMM_WORLD,ierr)
c         call MPI_BCAST(
c     &        cell_volume,
c     &        1,
c     &        MPP_REAL,
c     &        0,MPP_COMM_WORLD,ierr)
c#endif
         hbh=1
      endif
c      socinit=0.9
c      short_res=0.01
c      cell_volume=1.
c
      xp = 0.5646 + (1.- socinit) * (9.8627e-01 - 0.5646)
      xn = 0.6371 + (1.- socinit) * (1.6212e-02 - 0.6371)
c
      factor = xxVolume/cell_volume
c
      ioff=(icircuit-1)*numDataPerCircuit
c
      if (emtime.lt.1e-10) then
c init
            r_mem(circuitData+ioff+ixp)=xp
            r_mem(circuitData+ioff+ixn)=xn
c
c
         xxPhi1 = U_POS_spm(xp) ! 4.15
         xxPhi2 = U_NEG_spm(xn) ! 0.00
c
c
      else
c 
         xxPhi1 = voltage1
         xxPhi2 = voltage2
c			
      endif
c
c*********************************************************************
c get variables from internal arrays
c*********************************************************************
          xp= r_mem(circuitData+ioff+ixp)
          xn= r_mem(circuitData+ioff+ixn)
c
c*********************************************************************
c*********************************************************************
c
      Rcell = 0.0013/factor
      Vcell = voltage1-voltage2
      iapp = xcurrent/factor
c
      call solve_vcell_spm(Vcell,iapp,xp,xn,emdt*1e4,
     &   echem_heat,xxTemp)
c
      xr0 = Rcell
      xrhs = iapp*factor + (voltage1-voltage2)/xr0
c
C
c
c*********************************************************************
c update state variables and copy them to circuitData
c*********************************************************************  
c
        r_mem(circuitData+ioff+ixp)=xp
        r_mem(circuitData+ioff+ixn)=xn
c	
c*********************************************************************
c
      if (emtime.lt.1e-10) then
        xrhs = (xxPhi1-xxPhi2)/xr0
        write(*,*) 'init: ',icircuit,emtime,emdt,xrhs
c
      end if
c
        xPower = abs(echem_heat)*factor 
c*********************************************************************
c copy variables to corresponding arrays so that they can be output
c to em_xxx.dat and d3plots 
c*********************************************************************
         call em_randlePutVal(
     &        icircuit,
     &        em_randle_i,
     &        xcurrent/xxVolume)
         call em_randlePutVal(
     &        icircuit,
     &        em_randle_r0,
     &        xero)
         call em_randlePutVal(
     &        icircuit,
     &        em_randle_r10,
     &        xp)
         call em_randlePutVal(
     &        icircuit,
     &        em_randle_c10,
     &        xn)
      return
      end
      subroutine solve_vcell_spm(Vset,iapp,xp,xn,dt, heat_gen, temp)
      implicit none
      real Vset, iapp, dt, xp, xn, v_echem,output_current, heat_gen
      real x0, f0, x1, f1, x2, f2,xp_next,xn_next, heat,temp
      integer i
c
c
      x0 = -2000
      x1 = 2000
	  
c
      do i=1,30
c
        output_current = x0
		call vcell_spm(v_echem,output_current,xp,xn,
     &  xp_next,xn_next,dt,heat,temp)
        f0 = v_echem - Vset - 1e-60
c
        output_current = x1
		call vcell_spm(v_echem,output_current,xp,xn,
     &  xp_next,xn_next,dt,heat,temp)
        f1 = v_echem - Vset - 1e-60
c
        x2 = (x1 + x0) / 2.0
        output_current = x2
		call vcell_spm(v_echem,output_current,xp,xn,
     &  xp_next,xn_next,dt,heat,temp)
        f2 = v_echem - Vset - 1e-60
c
        if (f2.gt.0.0) then 
         x1 = x1 
         x0 = x2
        else
         x1 = x2
         x0 = x0
        end if
c
      end do
c

      iapp = x2
      xp = xp_next
      xn = xn_next
      heat_gen  = heat
	  
c
      return
      end subroutine
c
      subroutine vcell_spm(v_echem,iapp,xp,xn,xp_next,
     &  xn_next,dt,heat,temp)
	  
      implicit none
	  
      real iapp,xp,xn,dt, v_echem,xp_next,xn_next,heat,temp
      real epsp,epsn,epspf,epsnf,csmaxp,csmaxn,
     &     rp,rn,kp,kn,sp,sn,ce,f,r,t,rcell,x0n,x0p
	 
      real j_app_n,j_app_p,Dsoln,Dsolp
      real M1n,M1p,M2n,M2p,xn_s,xp_s
c
      DOUBLE PRECISION dummy,Up,mp,Un,mn, Vcell
      double precision safeReturn
      double precision U_NEG_spm,U_POS_spm
c
      x0n = 0.6371
      x0p = 0.5646
c
      epsp = 0.45
      epsn = 0.45
      epspf = 0.05
      epsnf = 0.05
      csmaxp = 51555.
      csmaxn = 30555.
      Rp = 10.0e-6
      Rn = 12.5e-6
      kp = 2.0e-11
      kn = 5.0e-11
      Sp = (3.0*(1.0 - epsp - epspf) / Rp)*3.0e-4*0.3975
      Sn = (3.0*(1.0 - epsn - epsnf) / Rn)*3.0e-4*0.4555
      ce = 1000
c
      Rcell = 0.0013
      Dsoln = 1.0e-13
      Dsolp = 1.3e-14
c
      F = 96485
      R = 8.314
      T = temp + 273.15
      j_app_n = iapp / (F*Sn)
      j_app_p = iapp / (F*Sp)
c
      M1n = (3.0*(1.0 - epsn - epsnf) / Rn)*dt
      M1p = (3.0*(1.0 - epsp - epspf) / Rp)*dt
c
      M2n = (Rn / 5)/Dsoln
      M2p = (Rp / 5)/Dsolp
c
      xn_s = safeReturn(1e-10, 
     &        xn - (M1n + M2n)*j_app_n / csmaxn, 1.0 - 1e-10)
      xp_s = safeReturn(1e-10, 
     &        xp + (M1p + M2p)*j_app_p / csmaxp, 1.0 - 1e-10)
c
      Un = U_NEG_spm(xn_s)
      Up = U_POS_spm(xp_s)
c
      mp = iapp / F / kp / Sp / csmaxp / sqrt((ce)*(1 - xp_s)*xp_s)
      mn = iapp / F / kn / Sn / csmaxn / sqrt((ce)*(1 - xn_s)*xn_s)
c
      Vcell = Up - Un + 2*R*T/F * log((sqrt(mp*mp + 4) + mp) / 2)
     &     + 2*R*T/F * log((sqrt(mn*mn + 4) + mn) / 2) - iapp * Rcell
c
      v_echem = safeReturn(1e-20, Vcell, 4.3)
c
      xn_next=safeReturn(1e-60,(M1n*xn_s+M2n*xn)/(M1n+M2n),1.0-1e-60)
      xp_next=safeReturn(1e-60,(M1p*xp_s+M2p*xp)/(M1p+M2p),1.0-1e-60)
c
      heat = abs(iapp * 2 * R*T / F * log((sqrt(mp*mp + 4) + mp) / 2))
     &     + abs(iapp * 2 * R*T / F * log((sqrt(mn*mn + 4) + mn) / 2))
     &     + iapp * iapp * Rcell
	 
      end subroutine
cc
      DOUBLEPRECISION FUNCTION U_POS_spm(X1)
c
      implicit none
      double precision X,X1
      double precision dumy
      double precision p(10)
      double precision safeReturn
      integer i
c
      X = safeReturn(1e-60, X1, 1.0 - 1e-60)
c
      p(1) = -2278420.72653387
      p(2) = 14866701.7258283
      p(3) = -42957255.4088813
      p(4) = 72150449.6408081
      p(5) = -77637418.8444074
      p(6) = 55512260.8350541
      p(7) = -26379356.5199933
      p(8) = 8034935.01386951
      p(9) = -1423744.25488851
      p(10) = 111846.399803416
c
      if (X.lt.0.51) then
        dumy = 5.146
      else
        dumy = 0.00
        do i=1,10
          dumy = dumy+ p(i)*X**(10-i)
        end do
      end if
      U_POS_spm = safeReturn(-2.0, dumy, 8.541)
      end function
c
c
      DOUBLEPRECISION FUNCTION U_NEG_spm(X1)
      implicit none
      double precision X,X1
      double precision dumy
      double precision safeReturn
c
      X = safeReturn(1e-60, X1, 1.0 - 1e-60)
c
      if (X.lt.0.007) then
        dumy = 4.077280851 - 353.4159288*X
      else
        dumy = 0.7222 + 0.1387*X + 0.029*X**0.5 - 0.0172*X**(-1) +
     &  0.0019*X**(-1.5) + 0.2808*dexp(0.9 - 15.0 * X) - 
     &  0.7984*dexp(0.4465*X - 0.4108)
ccccc Ramadass et al 2004
      end if
c
      U_NEG_spm = safeReturn(0.04, dumy, 1000.0)
c
      end function
c
      DOUBLEPRECISION FUNCTION safeReturn(mi, num, mx)
      implicit none
      double precision mi,num,mx
      if (num.le.mi) then
        safeReturn = mi
      else if (num .ge. mx) then
        safeReturn = mx
      else 
        safeReturn = num
      end if
      end function
      subroutine user_getcircuitval(numcirc,icircuit,icircuitus,
     & emt,emdt,rmesh,rcontact,
     &     xi,xim1,xvm1,xv,xl)
      include 'iounits.inc'
#include "meshes.inc"
#include "dynmem.inc"
c     allows the user to implement his own circuit equation
c     the value to be returned is the potential Xv (xvm1 is the previous
c     timestep value which the user can reuse)
c     example given here is that of a R,L,C circuit
c     Warning : routine called twice per timestep
c               once at the beginning, once at the end
      integer icircuit,icircuitus,numcirc
      real emt,emdt,rmesh,rcontact,xi,xvm1,xv,xl
      real xc,xv0,xr,xq,xim1,xqm1,xiavg,emtold
      save emtold
      data emtold /0./
      save xq
      data xq /0./
      integer hbh
      save hbh
      data hbh /0/
      MINDEX min_xq,min_hbh
      save min_xq,min_hbh
      xl=230.e-6
      xC=2.0e-7
      xr=5.96
      xv0=7.e9
      if (hbh.eq.0) then
         hbh=1
         min_hbh=mem_alloc(numcirc)
         min_xq=mem_alloc(numcirc)
      endif
      if (i_mem(min_hbh+icircuit-1).eq.0) then
         i_mem(min_hbh+icircuit-1)=1
         xq=xC*Xv0
         r_mem(min_xq+icircuit-1)=xq
      else
         xqm1=r_mem(min_xq+icircuit-1)
         xiavg=0.5*(xi+xim1)
c         xiavg=xim1
c         xqm1=xqm1-0.5*emdt*(0.5*(xi+xim1))
         xqm1=xqm1-0.5*emdt*xim1
         r_mem(min_xq+icircuit-1)=xqm1
         xq=xqm1
      endif
      xv=xq/xc-xr*xiavg
c     xV=xQ/xC-xR*(0.5*(xI+xim1))
c      xim1=xi
      return
      end
      subroutine usermat_bp(inodeuser,func,xvalue)
c     this subroutine is called when a negative BC type is entered
c     in the keyword *EM_BOUNDARY_PRESCRIBED
c     data contained in func array :
c      'time','emdt','curr','pot',
c     & 'cond','temp','potglob','currglob','areaglob','area','x','y','z'/
      include 'iounits.inc'
#include "meshes.inc"
#include "dynmem.inc"
      real func(13),xvalue
      integer inodeuser,i
c
      real r0, temp
      do i=1,13
         write(iomsg,*)'funcbp',i,func(i)
      enddo
      temp=func(6)
      R0 = 1.e-6;
      if(temp<300.) then
         xvalue= R0;
         return
      endif
      xvalue=0.128*1e-7*temp-0.2857e-5;
c       xvalue=1.
      return
      end
      subroutine usermat_iconn(iconnid,func,xvalue)
c     this subroutine is called when a negative BC type is entered
c     in the keyword *EM_BOUNDARY_PRESCRIBED
c     data contained in func array :
      include 'iounits.inc'
#include "meshes.inc"
#include "dynmem.inc"
      real func(12),xvalue
      integer inodeuser,i,iconnid
c the data contained in the func array is :
c'time','emdt','curr',
c     & 'curr1','curr2','pot1','pot2','0','pot','Rmesh',
c     & 'JEnergy', 'JPower'/
c
      do i=1,12
         write(iomsg,*)'funciconn',i,func(i)
      enddo
      xvalue=1.
      return
      end
c
#endif
#endif
