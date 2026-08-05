# 1 "dyn21tumat.F"
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





# 2 "dyn21tumat.F" 2 
      subroutine thusrmat(mt,c1,c2,c3,cvl,dcvdtl,hsrcl,dhsrcdtl,
     1 hsv,iphsv,r_matp,crv,nnpcrv,npc,plc,nel,nep,iep,eltype,dt,atime,
     2 ihsrcl,hsvm,nmecon,temp,hsv2,hstored)
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
      include 'iounits.inc'
      integer iburn,isdo
      real dt1,dt2
      common/bk02/iburn,dt1,dt2,isdo
      common/bk26/begtim,nintcy
      real summss,xke,xpe,tt,xte0,erodeke,erodeie,selie,selke,
     . erodehg,eintcnt,engjnt
      common/bk28/summss,xke,xpe,tt,xte0,erodeke,erodeie,selie,selke,
     . erodehg,eintcnt,engjnt
      integer ishc_tran,ishc_step,ishc_iprnt,ishc_iplot,
     & ishc_newfil,ishc_newstp,ishc_dump,ishc_lcthdt
      real shc_alpha,shc_timin,shc_dtlast,shc_timend,
     & shc_dt,shc_dtmin,shc_dtmax,shc_tmpmax,shc_tscp,shc_dyntim,
     & shc_dtminloc,shc_dtmaxloc,shc_tmpmaxloc
      common/blk05/shc_alpha,shc_timin,shc_dtlast,shc_timend,
     & shc_dt,shc_dtmin,shc_dtmax,shc_tmpmax,shc_tscp,shc_dyntim,
     & shc_dtminloc,shc_dtmaxloc,shc_tmpmaxloc,
     & ishc_tran,ishc_step,ishc_iprnt,ishc_iplot,
     & ishc_newfil,ishc_newstp,ishc_dump,ishc_lcthdt
      common/blk15/time,idumy6(7)
      common/blk17/nrstrt,ifirst
      character*(*) eltype
      dimension hsv(*),r_matp(64),crv(lq1,2,*),iphsv(*)
      integer nnpcrv(*)
      dimension npc(*),plc(*)
      dimension hsvm(100),hstored(*),hsv2(*)
      logical inithis
c
c     Thermal user material top routine. User's should place their
c     user material routines in thumat11-15 corresponding to:
c       - Keyword input: MT=11-15 in MAT_THERMAL_USER_DEFINED MT=11-15.
c       - Structured input: Thermal material type 11-15.
c
c     These thermal material routines are not vectorized.
c
c     Results ( Write only)
c     c1,c2,c3- IORTHO.EQ.1 Conductivity in local r,s,t direction.
c               IORTHO.EQ.0 then only set c1 to the isotropic heat
c               conductivity (c2 and c3 are not used).
c     cvl     - Specific heat capacity (Energy/Mass/Temperature)
c     dcvldt  - Temperature derivative of cvl
c     hsrcl   - Heat source (Energy/Time/Volume)
c     dhsrcdtl- Temperature derivative of hsrcl
c     ihsrcl  - Set to 1 if heat source is to be taken into account for this material
c
c     Read and Writeable data
c     hsv     - History variables
c               History variable i=1...NVH for current element and
c               evaluation point is hsvep(i)=hsv(iphsv(nel)+(iep-1)*nvh+i)
c
c     Read only parameters:
c     mt      - Material number 11-15.
c     iphsv   - History variables index pointer
c     temp    - Temperature
c     atime   - Current time
c     dt      - Length of current time step
c     r_matp - Material parameters from card input (real):
c              r_matp(1)=LMC
c              r_matp(2)=NVH
c              r_matp(3)=IORTHO
c              r_matp(4)=IHVE
c              r_matp(9)=P1
c              ...
c              r_matp(8+LMC)=P_LMC
c
c     plc    - load curve data pairs (abcissa,ordinate).
c     npc    - pointer into plc.  (plc(npc(lcidi)) points to the beginning
c              of load curve ID lc.  npoints=npc(lc+1)-npc(lc)=
c              number of points in the load curve.
c     crv    - Array of load curves interpolated to curves
c              with 101 equidistant points. Array crv(*,*,lcidi)
c              contains the data for curve number lcidi.
c     nel    - Element internal number.
c     eltype - character*10 string identifying the calling subroutine. It may
c              be used in an 'if' conditional for error checking to identify
c              the calling subroutine or for special handling of material values
c              under different conditions. For example, when eltype=solid_ie to
c              calcualte element internal energy, only specific heat needs to be
c              returned by subroutine thusrmat. The calling subroutine will ignore
c              the other material parameters (e.g., c1, c2, etc.) if they are
c              also calculated and returned in the argument list.
c                1) called for element conductance and capacitance matrix formation
c                   eq.'beam'   = beam element
c                   eq.'shell'  = shell element
c                   eq.'solid'  = 3d solid element (hexahedral or tetrahedal)
c                   eq.'tshell' = thick shell element
c                2) called for element internal energy calculation
c                   eq.'shell_ie'  = shell element
c                   eq.'solid_ie'  = solid element
c                   eq.'tshell_ie' = thick shell element
c                3) called for stable explicit time step calculation
c                   eq.'shelldt' =  shell element
c                   eq.'soliddt' =  solid element
c                4) called for specialty calculations
c                   eq.'flux'    = element flux
c                   eq.'fluid1d' = bulk fluid flow
c     nep    - Number of points at which the material model is evaluated
c              for this element. Not valid for eltype.eq.'na'.
c     iep    - Current evaluation point, not valid for eltype.eq.'na'.
c     hsvm   - If IHVE.eq.1 then hsvm(i) i=1...nmecon, contains history
c              variable data from mechanical user material routine
c              interpolated to current integration point using linear interpolation
c              or extrapolation.
c                 hsvm(i) i=1..6:            Stress components Sxx, Syy, Szz, Sxy,
c                                            Syz, Szx.
c                                            Stresse
c                 hsvm(6+1):                 Effective plastic strain.
c                                            Corresponds to variable epsp in
c                                            mechanical user defined material.
c                 hsvm(6+1+i) i=i..LMC:      History variables hisv(i) in
c                                            mechanical user defined material.
c                                            LMC refers to the card input for the
c                                            mechanical user defined material.
c                 hsvm(i) i=(LMC+8)..nmecon: Additional history variables
c                                            such as material directions.
c              Note: The following mechanical elements are supported:
c                -Shell: 2, 3, 4, 16
c                -Solid: 1, 2, 10, 13
c
c     For treating mechanical history variables the following is good to know about
c     staggered step solutions since this can have consequences on this issue.
c     A thermal step is taken whenever the next mechanical time is greater than the
c     last converged thermal time, this since the mechanical side must always know
c     of the thermal state at a given time. Thermal steps are continuously taken until
c     the converged thermal time is greater than the next mechanical step. Whence,
c     at the time of solving the thermal problem we have (parameters in user thermal
c     material routines)
c
c     ttconv - last converged thermal time
c     atime  - time at which thermal properties are to be evaluated
c     ttnext - the time for which we are now solving the thermal problem
c     tmconv - last converged mechanical time
c     tmnext - PREDICTED time for which the next mechanical solution is obtained
c              (may change in implicit mechanics with variable time step)
c
c     We always have tmconv <= ttconv <= tmnext. For explicit mechanics we usually
c     have ttconv~=tmnext (roughly) and thus ttnext>tmnext. This means that only
c     one thermal step is needed before the next mechanical step is taken. In
c     implicit mechanics we may have ttnext<tmnext or even ttnext<<tmnext, which means
c     that several thermal steps are needed before the next mechanical step is taken.
c     The thermal solver does NOT know of the mechanical state at a given time, but
c     only the state at time tmconv. This is a consequence of staggered step approach,
c     one of the disciplines must be "ahead" of the other. If for instance the thermal
c     user material is supposed to convert mechanical work into heat, then the user
c     could (and should) use these parameters appropriately in order to distribute the
c     heat evenly throughout the entire time frame until the next mechanical steps to
c     avoid heat spikes after each mechanical step. A pseudo coding is the following.
c
c     Let hsvm(1) be a quantity we want to compute the derivative of, reserve hsv(1) to
c     be the "previous" value of this quantity and hsv(2) the time at which the "previous"
c     value was computed. We want to compute dhsv1=time derivative of hsvm(1), these are
c     the principles, the details may have to be worked on.
c
c     if (ttnext.ge.tmnext) then
c     dhsv1=(hsvm(1)-hsv(1))/(tmconv-hsv(2))
c     hsv(1)=hsvm(1)
c     hsv(2)=tmconv
c     else
c     frac=(ttnext-ttconv)/(tmnext-ttconv)
c     hsv1=hsv(1)+frac*(hsvm(1)-hsv(1))
c     hsv2=hsv(2)+frac*(tmconv-hsv(1))
c     dhsv1=(hsv1-hsv(1))/(hsv2-hsv(2))
c     hsv(1)=hsv1
c     hsv(2)=hsv2
c     endif
c
c     The conditional if (inithis) can be used to determine
c     the first time the thermal user subroutine is entered, this
c     in order to initialize history variables.
c
c     Note: If atime.lt.0.0 then that parameter is not available
c     If dt.lt.0.0 then that parameter is not available
c
c
c     Note on load curves (*DEFINE_CURVE):
c     Use the crvval subroutine for extracting curve value and slope:
c
c         subroutine crvval(crv,nnpcrv,eid,xval,yval,slope)
c
c         crv    = curve array                     input (real array)
c         nnpcrv = no. discretization pts per crv  input (integer array)
c         eid    = external curve id               input (real)
c         xval   = abcissa value (x-axis)          input (real)
c         yval   = ordinate value (y-axis)         output (real)
c         slope  = slope of curve (dy/dx)          output (real)
c
c
c     To convert an external load curve number lcid to the internal
c     load curve number lcidi use function lcids:
c        lcidi=lcids(lcid)
c
c
c     Implementation notes:
c      -A user defined subroutine must be able to
c       return results for the following eltype:
c       Material routine for solid: eltype.eq. 'solid', 'soliddt', and 'flux'
c       Material routine for 4-node thermal shell: eltype.eq. 'shell', 'shelldt'
c       Material routine for 12-node thermal shell: eltype.eq. 'tshell', 'shelldt'
c      -r_matp(i), i=41...64 are unused and may be used to store data for each
c       material.
c      -If nrstrt.gt.0 then this is a restart or remap.
c
      nvh=abs(nint(r_matp(2)))
c
      if(eltype.eq.'na') go to 1000
c
      inithis=tt.eq.begtim.and.nintcy.eq.0
c
      do i=1,nvh
        hstored(i)=hsv2(iphsv(nel)+(iep-1)*nvh+i)
      enddo
c
      gptime=atime
      if (gptime.eq.0.) gptime=time-dt+shc_alpha*dt
      goto (110,120,130,140,150) mt-10
 110  continue
      call thumat11(c1,c2,c3,cvl,dcvdtl,hsrcl,dhsrcdtl,
     1     hstored,hsvm,nmecon,r_matp,crv,nnpcrv,
     2     nel,nep,iep,eltype,dt,gptime,ihsrcl,temp,
     3     time-dt,time,tt-dt1,tt,inithis)
      go to 200
 120  continue
      call thumat12(c1,c2,c3,cvl,dcvdtl,hsrcl,dhsrcdtl,
     1     hstored,hsvm,nmecon,r_matp,crv,nnpcrv,
     2     nel,nep,iep,eltype,dt,gptime,ihsrcl,temp,
     3     time-dt,time,tt-dt1,tt,inithis)
      go to 200
 130  continue
      call thumat13(c1,c2,c3,cvl,dcvdtl,hsrcl,dhsrcdtl,
     1     hstored,hsvm,nmecon,r_matp,crv,nnpcrv,
     2     nel,nep,iep,eltype,dt,gptime,ihsrcl,temp,
     3     time-dt,time,tt-dt1,tt,inithis)
      go to 200
 140  continue
      call thumat14(c1,c2,c3,cvl,dcvdtl,hsrcl,dhsrcdtl,
     1     hstored,hsvm,nmecon,r_matp,crv,nnpcrv,
     2     nel,nep,iep,eltype,dt,gptime,ihsrcl,temp,
     3     time-dt,time,tt-dt1,tt,inithis)
      go to 200
 150  continue
      call thumat15(c1,c2,c3,cvl,dcvdtl,hsrcl,dhsrcdtl,
     1     hstored,hsvm,nmecon,r_matp,crv,nnpcrv,
     2     nel,nep,iep,eltype,dt,gptime,ihsrcl,temp,
     3     time-dt,time,tt-dt1,tt,inithis)
      go to 200
c
 200  continue
      if (.not.(eltype.eq.'soliddt'.or.eltype.eq.'shelldt'.or.
     1     eltype.eq.'solid_ie'.or.eltype.eq.'shell_ie'.or.
     2     eltype.eq.'tshell_ie'.or.eltype.eq.'flux')) then
        do i=1,nvh
          hsv(iphsv(nel)+(iep-1)*nvh+i)=hstored(i)
        enddo
      endif
c
      return
c     Error termination
 1000 continue
c     write(iotty,1100)
c     write(iohsp,1100)
c     write(iomsg,1100)
c     call adios(2)
      call lsmsg(3,MSG_SOL+1350,ioall,ierdat,rerdat,cerdat,0)
c1100 format(/' *** Error non-valid element type.')
      end
      subroutine thumat11(c1,c2,c3,cvl,dcvdtl,hsrcl,dhsrcdtl,
     1 hsv,hsvm,nmecon,r_matp,crv,nnpcrv,
     2 nel,nep,iep,eltype,dt,atime,ihsrcl,temp,ttconv,ttnext,
     3 tmconv,tmnext,inithis)
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
c
      character*(*) eltype
      logical inithis
      dimension hsv(*),hsvm(*),r_matp(*),crv(lq1,2,*)
      integer nnpcrv(*)
c
c     Thermal usermaterial number 11.
c
c     See comments at the begining of subroutine thusrmat
c     for instructions.
c
c     Orthotropic thermal material
      c1=r_matp(8+1)
      c2=r_matp(8+2)
      c3=r_matp(8+3)
      cvl=r_matp(8+4)
      return
 1000 continue
c     write(iotty,1100)
c     write(iohsp,1100)
c     write(iomsg,1100)
c     call adios(2)
      ierdat(1)=11
      call lsmsg(3,MSG_SOL+1351,ioall,ierdat,rerdat,cerdat,0)
c1100 format(/' *** Error thumat11 not defined')
      return
      end
      subroutine thumat12(c1,c2,c3,cvl,dcvdtl,hsrcl,dhsrcdtl,
     1 hsv,hsvm,nmecon,r_matp,crv,nnpcrv,
     2 nel,nep,iep,eltype,dt,atime,ihsrcl,temp,ttconv,ttnext,
     3 tmconv,tmnext,inithis)
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
c
      character*(*) eltype
      logical inithis
      dimension hsv(*),hsvm(*),r_matp(*),crv(lq1,2,*)
      integer nnpcrv(*)
c
c     Thermal usermaterial number 12.
c
c     See comments at the begining of subroutine thusrmat
c     for instructions.
c
c     Example: isotropic/orthotropic material with k1=P1 and
c     cvl=P2 for solid element only.
c
c     Valid element type?
c
c     Print out some info
      if(nint(r_matp(64)).eq.0) then
         r_matp(64)=1.
         do i=1,6
           rerdat(i)=r_matp(8+i)
         enddo
         call lsmsg(0,MSG_SOL+1352,ioall,ierdat,rerdat,cerdat,0)
c        write(iotty,1200)  (r_matp(8+i),i=1,6)
c        write(iohsp,1200) (r_matp(8+i),i=1,6)
c        write(iomsg,1200) (r_matp(8+i),i=1,6)
      endif
c
c     Calculate response
      c1=r_matp(8+1)
      c2=r_matp(8+2)
      c3=r_matp(8+3)
      cvl=r_matp(8+4)
      dcvdtl=0.0
      eid=nint(r_matp(8+6))
      if(nint(eid).gt.0) then
         call crvval(crv,nnpcrv,eid,atime,cvlfac,tmp1)
         cvl=cvl*cvlfac
         dcvdtl=0.0
      endif
c
      eid=nint(r_matp(8+5))
      if(nint(eid).gt.0) then
         ihsrcl=1
         call crvval(crv,nnpcrv,eid,atime,hsrcl,tmp1)
         dhsrcdtl=0.0
      endif
c
c     Update history variables
      hsv(1)=cvl
      hsv(2)=atime
      hsv(3)=hsv(3)+1.0
      hsv(4)=iep
      hsv(5)=0.0
      if (nint(r_matp(4)).eq.1) then
         hsv(5)=hsvm(7)
      endif
c
c     Done
      return
 1000 continue
c     write(iotty,1100)
c     write(iohsp,1100)
c     write(iomsg,1100)
c     call adios(2)
      ierdat(1)=12
      call lsmsg(3,MSG_SOL+1351,ioall,ierdat,rerdat,cerdat,0)
 1010 continue
c     write(iotty,1110) eltype
c     write(iohsp,1110) eltype
c     write(iomsg,1110) eltype
c     call adios(2)
      cerdat(1)=eltype
      call lsmsg(3,MSG_SOL+1353,ioall,ierdat,rerdat,cerdat,0)
c1100 format(/' *** Error thumat12 not defined ')
 1110 format(/' *** Error thumat12 undefined eltype: ',a)
c1200 format(/' This is thermal user defined material #12. '/
c    1       /'  Material parameter c1-c3       : ',1p3e10.3
c    2       /'  Material parameter cv          : ',e10.3
c    3       /'  Heatsource load curve          : ',f10.0
c    4       /'  Phase transformation load curve: ',f10.0
c    5       /'  Thermal History variable 1     : cv'
c    5       /'  Thermal History variable 2-5   : Stuff'/)
      return
      end
      subroutine thumat13(c1,c2,c3,cvl,dcvdtl,hsrcl,dhsrcdtl,
     1 hsv,hsvm,nmecon,r_matp,crv,nnpcrv,
     2 nel,nep,iep,eltype,dt,atime,ihsrcl,temp,ttconv,ttnext,
     3 tmconv,tmnext,inithis)
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
      character*(*) eltype
      logical inithis
      dimension hsv(*),hsvm(*),r_matp(*),crv(lq1,2,*)
      integer nnpcrv(*)
c
c     Thermal usermaterial number 13.
c
c     See comments at the begining of subroutine thusrmat
c     for instructions.
c
 1000 continue
c     write(iotty,1100)
c     write(iohsp,1100)
c     write(iomsg,1100)
c     call adios(2)
      ierdat(1)=13
      call lsmsg(3,MSG_SOL+1351,ioall,ierdat,rerdat,cerdat,0)
c1100 format(/' *** Error thumat13 not defined ')
      return
      end
      subroutine thumat14(c1,c2,c3,cvl,dcvdtl,hsrcl,dhsrcdtl,
     1 hsv,hsvm,nmecon,r_matp,crv,nnpcrv,
     2 nel,nep,iep,eltype,dt,atime,ihsrcl,temp,ttconv,ttnext,
     3 tmconv,tmnext,inithis)
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
      character*(*) eltype
      logical inithis
      dimension hsv(*),hsvm(*),r_matp(*),crv(lq1,2,*)
      integer nnpcrv(*)
c
c     Thermal usermaterial number 14.
c
c     See comments at the begining of subroutine thusrmat
c     for instructions.
c
 1000 continue
c     write(iotty,1100)
c     write(iohsp,1100)
c     write(iomsg,1100)
c     call adios(2)
      ierdat(1)=14
      call lsmsg(3,MSG_SOL+1351,ioall,ierdat,rerdat,cerdat,0)
c1100 format(/' *** Error thumat14 not defined ')
      return
      end
      subroutine thumat15(c1,c2,c3,cvl,dcvdtl,hsrcl,dhsrcdtl,
     1 hsv,hsvm,nmecon,r_matp,crv,nnpcrv,
     2 nel,nep,iep,eltype,dt,atime,ihsrcl,temp,ttconv,ttnext,
     3 tmconv,tmnext,inithis)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     thermal usermaterial number 15.
c
c     see comments at the begining of subroutine thusrmat
c     for instructions.
c
      include 'nlqparm'
      include 'iounits.inc'
      character*(*) eltype
      logical inithis
c
      dimension hsv(*),hsvm(*),r_matp(*),crv(lq1,2,*)
      integer nnpcrv(*)
 1000 continue
c     write(iotty,1100)
c     write(iohsp,1100)
c     write(iomsg,1100)
c     call adios(2)
      ierdat(1)=15
      call lsmsg(3,MSG_SOL+1351,ioall,ierdat,rerdat,cerdat,0)
c1100 format(/' *** Error thumat15 not defined ')
      return
      end
