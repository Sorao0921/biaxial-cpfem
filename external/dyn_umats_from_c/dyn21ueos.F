# 1 "dyn21ueos.F"
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





# 2 "dyn21ueos.F" 2 
      subroutine ueoslib(lft,llt,nes,mte,eosp,pnew,v0,dvol,
     & crv,nnpcrv,ivect,ihistp,iflag,nh)
# 7

c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     user equation of state library
c
c     include 'alecom.inc'
      include 'nlqparm'
      include 'nhisparm.inc'
c
c
      common/aux14loc/
     & sign1(nlq),sign2(nlq),sign3(nlq),sign4(nlq),
     & sign5(nlq),sign6(nlq),sign7(nlq),aux(nlq,NHISVAR)
      common/aux18loc/dd(nlq),df(nlq),ddq(nlq)
      common/aux35loc/rho(nlq),cb(nlq),q1a(nlq),cxa(nlq)
      common/aux43loc/xm(nlq),p(nlq),xmua(nlq),specen(nlq),cc(nlq)
      common/eosdloc/pc(nlq),g(nlq)
      common/subtssloc/dt1siz(nlq)
c
      common/bk26/begtim,nintcy
      common/bk28/summss,xke,xpe,tt,xte0,erodeke,erodeie,selie,selke,
     1 erodehg
c
      logical first
c
      dimension eosp(*),pnew(*),v0(*),dvol(*),crv(lq1,2,*)
      integer nnpcrv(*)
      dimension auxs(148)
c
c$omp threadprivate (/subtssloc/)
c$omp threadprivate (/eosdloc/)
c$omp threadprivate (/aux43loc/)
c$omp threadprivate (/aux35loc/)
c$omp threadprivate (/aux18loc/)
c$omp threadprivate (/aux14loc/)
      nes20=nes-20
c
c***  first time step flag
      first=tt.eq.begtim.and.nintcy.eq.0
c
c***  reference density
      rho0=rho(lft)
c
c***  vectorized implementation of equation of state
      if (ivect.eq.1) then
        go to (21,22,23,24,25,26,27,28,29,30),nes20
c
   21   call ueos21v(lft,llt,iflag,cb,pnew,aux(1,ihistp),
     &               rho0,eosp,specen,
     &               df,dvol,v0,pc,dt1siz,tt,crv,nnpcrv,first)
        return
c
   22   call ueos22v(lft,llt,iflag,cb,pnew,aux(1,ihistp),
     &               rho0,eosp,specen,
     &               df,dvol,v0,pc,dt1siz,tt,crv,nnpcrv,first)
        return
c
   23   call ueos23v(lft,llt,iflag,cb,pnew,aux(1,ihistp),
     &               rho0,eosp,specen,
     &               df,dvol,v0,pc,dt1siz,tt,crv,nnpcrv,first)
        return
c
   24   call ueos24v(lft,llt,iflag,cb,pnew,aux(1,ihistp),
     &               rho0,eosp,specen,
     &               df,dvol,v0,pc,dt1siz,tt,crv,nnpcrv,first)
        return
c
   25   call ueos25v(lft,llt,iflag,cb,pnew,aux(1,ihistp),
     &               rho0,eosp,specen,
     &               df,dvol,v0,pc,dt1siz,tt,crv,nnpcrv,first)
        return
c
   26   call ueos26v(lft,llt,iflag,cb,pnew,aux(1,ihistp),
     &               rho0,eosp,specen,
     &               df,dvol,v0,pc,dt1siz,tt,crv,nnpcrv,first)
        return
c
   27   call ueos27v(lft,llt,iflag,cb,pnew,aux(1,ihistp),
     &               rho0,eosp,specen,
     &               df,dvol,v0,pc,dt1siz,tt,crv,nnpcrv,first)
        return
c
   28   call ueos28v(lft,llt,iflag,cb,pnew,aux(1,ihistp),
     &               rho0,eosp,specen,
     &               df,dvol,v0,pc,dt1siz,tt,crv,nnpcrv,first)
        return
c
   29   call ueos29v(lft,llt,iflag,cb,pnew,aux(1,ihistp),
     &               rho0,eosp,specen,
     &               df,dvol,v0,pc,dt1siz,tt,crv,nnpcrv,first)
        return
c
   30   call ueos30v(lft,llt,iflag,cb,pnew,aux(1,ihistp),
     &               rho0,eosp,specen,
     &               df,dvol,v0,pc,dt1siz,tt,crv,nnpcrv,first)
        return
c
c***  scalar
      else if (ivect.eq.0) then
        go to (121,122,123,124,125,126,127,128,129,130),nes20
c
  121   do i=lft,llt
          do j=1,nh
            auxs(j)=aux(i,ihistp-1+j)
          enddo
          dt=dt1siz(i)
          call ueos21s(iflag,cb(i),pnew(i),auxs,
     &                 rho0,eosp,specen(i),
     &                 df(i),dvol(i),v0(i),pc(i),dt,tt,crv,nnpcrv,
     &                 first)
          do j=1,nh
            aux(i,ihistp-1+j)=auxs(j)
          enddo
        enddo
        return
c
  122   do i=lft,llt
          do j=1,nh
            auxs(j)=aux(i,ihistp-1+j)
          enddo
          dt=dt1siz(i)
          call ueos22s(iflag,cb(i),pnew(i),auxs,
     &                 rho0,eosp,specen(i),
     &                 df(i),dvol(i),v0(i),pc(i),dt,tt,crv,nnpcrv,
     &                 first)
          do j=1,nh
            aux(i,ihistp-1+j)=auxs(j)
          enddo
        enddo
        return
c
  123   do i=lft,llt
          do j=1,nh
            auxs(j)=aux(i,ihistp-1+j)
          enddo
          dt=dt1siz(i)
          call ueos23s(iflag,cb(i),pnew(i),auxs,
     &                 rho0,eosp,specen(i),
     &                 df(i),dvol(i),v0(i),pc(i),dt,tt,crv,nnpcrv,
     &                 first)
          do j=1,nh
            aux(i,ihistp-1+j)=auxs(j)
          enddo
        enddo
        return
c
  124   do i=lft,llt
          do j=1,nh
            auxs(j)=aux(i,ihistp-1+j)
          enddo
          dt=dt1siz(i)
          call ueos24s(iflag,cb(i),pnew(i),auxs,
     &                 rho0,eosp,specen(i),
     &                 df(i),dvol(i),v0(i),pc(i),dt,tt,crv,nnpcrv,
     &                 first)
          do j=1,nh
            aux(i,ihistp-1+j)=auxs(j)
          enddo
        enddo
        return
c
  125   do i=lft,llt
          do j=1,nh
            auxs(j)=aux(i,ihistp-1+j)
          enddo
          dt=dt1siz(i)
          call ueos25s(iflag,cb(i),pnew(i),auxs,
     &                 rho0,eosp,specen(i),
     &                 df(i),dvol(i),v0(i),pc(i),dt,tt,crv,nnpcrv,
     &                 first)
          do j=1,nh
            aux(i,ihistp-1+j)=auxs(j)
          enddo
        enddo
        return
c
  126   do i=lft,llt
          do j=1,nh
            auxs(j)=aux(i,ihistp-1+j)
          enddo
          dt=dt1siz(i)
          call ueos26s(iflag,cb(i),pnew(i),auxs,
     &                 rho0,eosp,specen(i),
     &                 df(i),dvol(i),v0(i),pc(i),dt,tt,crv,nnpcrv,
     &                 first)
          do j=1,nh
            aux(i,ihistp-1+j)=auxs(j)
          enddo
        enddo
        return
c
  127   do i=lft,llt
          do j=1,nh
            auxs(j)=aux(i,ihistp-1+j)
          enddo
          dt=dt1siz(i)
          call ueos27s(iflag,cb(i),pnew(i),auxs,
     &                 rho0,eosp,specen(i),
     &                 df(i),dvol(i),v0(i),pc(i),dt,tt,crv,nnpcrv,
     &                 first)
          do j=1,nh
            aux(i,ihistp-1+j)=auxs(j)
          enddo
        enddo
        return
c
  128   do i=lft,llt
          do j=1,nh
            auxs(j)=aux(i,ihistp-1+j)
          enddo
          dt=dt1siz(i)
          call ueos28s(iflag,cb(i),pnew(i),auxs,
     &                 rho0,eosp,specen(i),
     &                 df(i),dvol(i),v0(i),pc(i),dt,tt,crv,nnpcrv,
     &                 first)
          do j=1,nh
            aux(i,ihistp-1+j)=auxs(j)
          enddo
        enddo
        return
c
  129   do i=lft,llt
          do j=1,nh
            auxs(j)=aux(i,ihistp-1+j)
          enddo
          dt=dt1siz(i)
          call ueos29s(iflag,cb(i),pnew(i),auxs,
     &                 rho0,eosp,specen(i),
     &                 df(i),dvol(i),v0(i),pc(i),dt,tt,crv,nnpcrv,
     &                 first)
          do j=1,nh
            aux(i,ihistp-1+j)=auxs(j)
          enddo
        enddo
        return
c
  130   do i=lft,llt
          do j=1,nh
            auxs(j)=aux(i,ihistp-1+j)
          enddo
          dt=dt1siz(i)
          call ueos30s(iflag,cb(i),pnew(i),auxs,
     &                 rho0,eosp,specen(i),
     &                 df(i),dvol(i),v0(i),pc(i),dt,tt,crv,nnpcrv,
     &                 first)
          do j=1,nh
            aux(i,ihistp-1+j)=auxs(j)
          enddo
        enddo
        return
      endif
c
      return
      end
      subroutine ueos21s(iflag,cb,pnew,hist,rho0,eosp,specen,
     & df,dvol,v0,pc,dt,tt,crv,nnpcrv,first)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     example scalar user implementation of the gruneisen EOS
c
c***  variables
c          iflag ----- =-1 initialize EOS constants
c                      =0 calculate bulk modulus
c                      =1 update pressure and energy
c          cb -------- bulk modulus
c          pnew ------ new pressure
c          hist ------ history variables
c          rho0 ------ reference density
c          eosp ------ EOS constants
c          specen ---- energy/reference volume
c          df -------- volume ratio, v/v0 = rho0/rho
c          dvol ------ change in volume over time step
c          v0 -------- reference volume
c          pc -------- pressure cut-off
c          dt -------- time step size
c          tt -------- current time
c          crv ------- curve array
c          first ----- logical .true. for tt,crv,first time step
c                      (for initialization of the history variables)
c
      include 'nlqparm'
      logical first
c
      dimension hist(*),eosp(*),crv(lq1,2,*)
      integer nnpcrv(*)
c
      c  =eosp(1)
      s1 =eosp(2)
      s2 =eosp(3)
      s3 =eosp(4)
      g0 =eosp(5)
      sa =eosp(6)
      s11=s1-1.
      s22=2.*s2
      s33=3.*s3
      s32=2.*s3
      sad2=.5*sa
      g0d2=1.-.5*g0
      roc2=rho0*c**2
c
c***  calculate the bulk modulus for the EOS contribution to the sound speed
      if (iflag.eq.0) then
        xmu=1.0/df-1.
        dfmu=df*xmu
        facp=.5*(1.+sign(1.,xmu))
        facn=1.-facp
        xnum=1.+xmu*(+g0d2-sad2*xmu)
        xdem=1.-xmu*(s11+dfmu*(s2+s3*dfmu))
        tmp=facp/(xdem*xdem)
        a=roc2*xmu*(facn+tmp*xnum)
        b=g0+sa*xmu
        pnum=roc2*(facn+facp*(xnum+xmu*(g0d2-sa*xmu)))
        pden=2.*xdem*(-s11 +dfmu*(-s22+dfmu*(s2-s33+s32*dfmu)))
        cb=pnum*(facn+tmp)-tmp*a*pden+sa*specen+
     &        b*df**2*max(pc,(a+b*specen))
c
c***  update the pressure and internal energy
      else
        xmu=1.0/df-1.
        dfmu=df*xmu
        facp=.5*(1.+sign(1.,xmu))
        facn=1.-facp
        xnum=1.+xmu*(+g0d2-sad2*xmu)
        xdem=1.-xmu*(s11+dfmu*(s2+s3*dfmu))
        tmp=facp/(xdem*xdem)
        a=roc2*xmu*(facn+tmp*xnum)
        b=g0+sa*xmu
        dvov0=.5*dvol/v0
        denom=1.+b*dvov0
        pnew=(a+specen*b)/max(1.e-6,denom)
        pnew=max(pnew,pc)
        specen=specen-pnew*dvov0
      endif
c
      return
      end
      subroutine ueos21v(lft,llt,iflag,cb,pnew,hist,rho0,eosp,specen,
     & df,dvol,v0,pc,dt,tt,crv,nnpcrv,first)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     example vectorized user implementation of the gruneisen EOS
c
c***  variables
c          lft,llt --- tt,crv,first and last indices into arrays
c          iflag ----- =-1 initialize EOS constants
c                      =0 calculate bulk modulus
c                      =1 update pressure and energy
c          cb -------- bulk modulus
c          pnew ------ new pressure
c          hist ------ history variables
c          rho0 ------ reference density
c          eosp ------ EOS constants
c          specen ---- energy/reference volume
c          df -------- volume ratio, v/v0 = rho0/rho
c          dvol ------ change in volume over time step
c          v0 -------- reference volume
c          pc -------- pressure cut-off
c          dt -------- time step size
c          tt -------- current time
c          crv ------- curve array
c          first ----- logical .true. for tt,crv,first time step
c                      (for initialization of the history variables)
c
      include 'nlqparm'
      logical first
c
      dimension cb(*),pnew(*),hist(nlq,*),eosp(*),
     &          specen(*),df(*),dvol(*),pc(*),v0(*)
      dimension crv(lq1,2,*)
      integer nnpcrv(*)
c
      c  =eosp(1)
      s1 =eosp(2)
      s2 =eosp(3)
      s3 =eosp(4)
      g0 =eosp(5)
      sa =eosp(6)
      s11=s1-1.
      s22=2.*s2
      s33=3.*s3
      s32=2.*s3
      sad2=.5*sa
      g0d2=1.-.5*g0
      roc2=rho0*c**2
c
c***  calculate the bulk modulus for the EOS contribution to the sound speed
      if (iflag.eq.0) then
        do i=lft,llt
          xmu=1.0/df(i)-1.
          dfmu=df(i)*xmu
          facp=.5*(1.+sign(1.,xmu))
          facn=1.-facp
          xnum=1.+xmu*(+g0d2-sad2*xmu)
          xdem=1.-xmu*(s11+dfmu*(s2+s3*dfmu))
          tmp=facp/(xdem*xdem)
          a=roc2*xmu*(facn+tmp*xnum)
          b=g0+sa*xmu
          pnum=roc2*(facn+facp*(xnum+xmu*(g0d2-sa*xmu)))
          pden=2.*xdem*(-s11 +dfmu*(-s22+dfmu*(s2-s33+s32*dfmu)))
          cb(i)=pnum*(facn+tmp)-tmp*a*pden+sa*specen(i)+
     &          b*df(i)**2*max(pc(i),(a+b*specen(i)))
        enddo
c
c***  update the pressure and internal energy
      else
        do i=lft,llt
          xmu=1.0/df(i)-1.
          dfmu=df(i)*xmu
          facp=.5*(1.+sign(1.,xmu))
          facn=1.-facp
          xnum=1.+xmu*(+g0d2-sad2*xmu)
          xdem=1.-xmu*(s11+dfmu*(s2+s3*dfmu))
          tmp=facp/(xdem*xdem)
          a=roc2*xmu*(facn+tmp*xnum)
          b=g0+sa*xmu
          dvov0=0.5*dvol(i)/v0(i)
          denom=1.+b*dvov0
          pnew(i)=(a+specen(i)*b)/max(1.e-6,denom)
          pnew(i)=max(pnew(i),pc(i))
          specen(i)=specen(i)-pnew(i)*dvov0
        enddo
      endif
c
      return
      end
      subroutine ueos22s(iflag,cb,pnew,hist,rho0,eosp,specen,
     & df,dvol,v0,pc,dt,tt,crv,nnpcrv,first)
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
      real crv(lq1,2,*)
      integer nnpcrv(*)
      logical first
c     write(iotty,1000)
c     write(iohsp,1000)
c     write(iomsg,1000)
c     call adios(2)
      cerdat(1)='22s'
      call lsmsg(3,MSG_SOL+1349,ioall,ierdat,rerdat,cerdat,0)
      return
c1000 format(/' *** Error ueos22s not implemented')
      end
      subroutine ueos22v(lft,llt,iflag,cb,pnew,hist,rho0,eosp,specen,
     & df,dvol,v0,pc,dt,tt,crv,nnpcrv,first)
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
      real crv(lq1,2,*)
      integer nnpcrv(*)
      logical first
c     write(iotty,1000)
c     write(iohsp,1000)
c     write(iomsg,1000)
c     call adios(2)
      cerdat(1)='22v'
      call lsmsg(3,MSG_SOL+1349,ioall,ierdat,rerdat,cerdat,0)
      return
c1000 format(/' *** Error ueos22v not implemented')
      end
      subroutine ueos23s(iflag,cb,pnew,hist,rho0,eosp,specen,
     & df,dvol,v0,pc,dt,tt,crv,nnpcrv,first)
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
      real crv(lq1,2,*)
      integer nnpcrv(*)
      logical first
c     write(iotty,1000)
c     write(iohsp,1000)
c     write(iomsg,1000)
c     call adios(2)
      cerdat(1)='23s'
      call lsmsg(3,MSG_SOL+1349,ioall,ierdat,rerdat,cerdat,0)
      return
c1000 format(/' *** Error ueos23s not implemented')
      end
      subroutine ueos23v(lft,llt,iflag,cb,pnew,hist,rho0,eosp,specen,
     & df,dvol,v0,pc,dt,tt,crv,nnpcrv,first)
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
      real crv(lq1,2,*)
      integer nnpcrv(*)
      logical first
c     write(iotty,1000)
c     write(iohsp,1000)
c     write(iomsg,1000)
c     call adios(2)
      cerdat(1)='23v'
      call lsmsg(3,MSG_SOL+1349,ioall,ierdat,rerdat,cerdat,0)
      return
c1000 format(/' *** Error ueos23v not implemented')
      end
      subroutine ueos24s(iflag,cb,pnew,hist,rho0,eosp,specen,
     & df,dvol,v0,pc,dt,tt,crv,nnpcrv,first)
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
      real crv(lq1,2,*)
      integer nnpcrv(*)
      logical first
c     write(iotty,1000)
c     write(iohsp,1000)
c     write(iomsg,1000)
c     call adios(2)
      cerdat(1)='24s'
      call lsmsg(3,MSG_SOL+1349,ioall,ierdat,rerdat,cerdat,0)
      return
c1000 format(/' *** Error ueos24s not implemented')
      end
      subroutine ueos24v(lft,llt,iflag,cb,pnew,hist,rho0,eosp,specen,
     & df,dvol,v0,pc,dt,tt,crv,nnpcrv,first)
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
      real crv(lq1,2,*)
      integer nnpcrv(*)
      logical first
c     write(iotty,1000)
c     write(iohsp,1000)
c     write(iomsg,1000)
c     call adios(2)
      cerdat(1)='24v'
      call lsmsg(3,MSG_SOL+1349,ioall,ierdat,rerdat,cerdat,0)
      return
c1000 format(/' *** Error ueos24v not implemented')
      end
      subroutine ueos25s(iflag,cb,pnew,hist,rho0,eosp,specen,
     & df,dvol,v0,pc,dt,tt,crv,nnpcrv,first)
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
      real crv(lq1,2,*)
      integer nnpcrv(*)
      logical first
c     write(iotty,1000)
c     write(iohsp,1000)
c     write(iomsg,1000)
c     call adios(2)
      cerdat(1)='25s'
      call lsmsg(3,MSG_SOL+1349,ioall,ierdat,rerdat,cerdat,0)
      return
c1000 format(/' *** Error ueos25s not implemented')
      end
      subroutine ueos25v(lft,llt,iflag,cb,pnew,hist,rho0,eosp,specen,
     & df,dvol,v0,pc,dt,tt,crv,nnpcrv,first)
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
      real crv(lq1,2,*)
      integer nnpcrv(*)
      logical first
c     write(iotty,1000)
c     write(iohsp,1000)
c     write(iomsg,1000)
c     call adios(2)
      cerdat(1)='25v'
      call lsmsg(3,MSG_SOL+1349,ioall,ierdat,rerdat,cerdat,0)
      return
c1000 format(/' *** Error ueos25v not implemented')
      end
      subroutine ueos26s(iflag,cb,pnew,hist,rho0,eosp,specen,
     & df,dvol,v0,pc,dt,tt,crv,nnpcrv,first)
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
      real crv(lq1,2,*)
      integer nnpcrv(*)
      logical first
c     write(iotty,1000)
c     write(iohsp,1000)
c     write(iomsg,1000)
c     call adios(2)
      cerdat(1)='26s'
      call lsmsg(3,MSG_SOL+1349,ioall,ierdat,rerdat,cerdat,0)
      return
c1000 format(/' *** Error ueos26s not implemented')
      end
      subroutine ueos26v(lft,llt,iflag,cb,pnew,hist,rho0,eosp,specen,
     & df,dvol,v0,pc,dt,tt,crv,nnpcrv,first)
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
      real crv(lq1,2,*)
      integer nnpcrv(*)
      logical first
c     write(iotty,1000)
c     write(iohsp,1000)
c     write(iomsg,1000)
c     call adios(2)
      cerdat(1)='26v'
      call lsmsg(3,MSG_SOL+1349,ioall,ierdat,rerdat,cerdat,0)
      return
c1000 format(/' *** Error ueos26v not implemented')
      end
      subroutine ueos27s(iflag,cb,pnew,hist,rho0,eosp,specen,
     & df,dvol,v0,pc,dt,tt,crv,nnpcrv,first)
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
      real crv(lq1,2,*)
      integer nnpcrv(*)
      logical first
c     write(iotty,1000)
c     write(iohsp,1000)
c     write(iomsg,1000)
c     call adios(2)
      cerdat(1)='27s'
      call lsmsg(3,MSG_SOL+1349,ioall,ierdat,rerdat,cerdat,0)
      return
c1000 format(/' *** Error ueos27s not implemented')
      end
      subroutine ueos27v(lft,llt,iflag,cb,pnew,hist,rho0,eosp,specen,
     & df,dvol,v0,pc,dt,tt,crv,nnpcrv,first)
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
      real crv(lq1,2,*)
      integer nnpcrv(*)
      logical first
c     write(iotty,1000)
c     write(iohsp,1000)
c     write(iomsg,1000)
c     call adios(2)
      cerdat(1)='27v'
      call lsmsg(3,MSG_SOL+1349,ioall,ierdat,rerdat,cerdat,0)
      return
c1000 format(/' *** Error ueos27v not implemented')
      end
      subroutine ueos28s(iflag,cb,pnew,hist,rho0,eosp,specen,
     & df,dvol,v0,pc,dt,tt,crv,nnpcrv,first)
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
      real crv(lq1,2,*)
      integer nnpcrv(*)
      logical first
c     write(iotty,1000)
c     write(iohsp,1000)
c     write(iomsg,1000)
c     call adios(2)
      cerdat(1)='28s'
      call lsmsg(3,MSG_SOL+1349,ioall,ierdat,rerdat,cerdat,0)
      return
c1000 format(/' *** Error ueos28s not implemented')
      end
      subroutine ueos28v(lft,llt,iflag,cb,pnew,hist,rho0,eosp,specen,
     & df,dvol,v0,pc,dt,tt,crv,nnpcrv,first)
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
      real crv(lq1,2,*)
      integer nnpcrv(*)
      logical first
c     write(iotty,1000)
c     write(iohsp,1000)
c     write(iomsg,1000)
c     call adios(2)
      cerdat(1)='28v'
      call lsmsg(3,MSG_SOL+1349,ioall,ierdat,rerdat,cerdat,0)
      return
c1000 format(/' *** Error ueos28v not implemented')
      end
      subroutine ueos29s(iflag,cb,pnew,hist,rho0,eosp,specen,
     & df,dvol,v0,pc,dt,tt,crv,nnpcrv,first)
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
      real crv(lq1,2,*)
      integer nnpcrv(*)
      logical first
c     write(iotty,1000)
c     write(iohsp,1000)
c     write(iomsg,1000)
c     call adios(2)
      cerdat(1)='29s'
      call lsmsg(3,MSG_SOL+1349,ioall,ierdat,rerdat,cerdat,0)
      return
c1000 format(/' *** Error ueos29s not implemented')
      end
      subroutine ueos29v(lft,llt,iflag,cb,pnew,hist,rho0,eosp,specen,
     & df,dvol,v0,pc,dt,tt,crv,nnpcrv,first)
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
      real crv(lq1,2,*)
      integer nnpcrv(*)
      logical first
c     write(iotty,1000)
c     write(iohsp,1000)
c     write(iomsg,1000)
c     call adios(2)
      cerdat(1)='29v'
      call lsmsg(3,MSG_SOL+1349,ioall,ierdat,rerdat,cerdat,0)
      return
c1000 format(/' *** Error ueos29v not implemented')
      end
      subroutine ueos30s(iflag,cb,pnew,hist,rho0,eosp,specen,
     & df,dvol,v0,pc,dt,tt,crv,nnpcrv,first)
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
      real crv(lq1,2,*)
      integer nnpcrv(*)
      logical first
c     write(iotty,1000)
c     write(iohsp,1000)
c     write(iomsg,1000)
c     call adios(2)
      cerdat(1)='30s'
      call lsmsg(3,MSG_SOL+1349,ioall,ierdat,rerdat,cerdat,0)
      return
c1000 format(/' *** Error ueos30s not implemented')
      end
      subroutine ueos30v(lft,llt,iflag,cb,pnew,hist,rho0,eosp,specen,
     & df,dvol,v0,pc,dt,tt,crv,nnpcrv,first)
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
      real crv(lq1,2,*)
      integer nnpcrv(*)
      logical first
c     write(iotty,1000)
c     write(iohsp,1000)
c     write(iomsg,1000)
c     call adios(2)
      cerdat(1)='30v'
      call lsmsg(3,MSG_SOL+1349,ioall,ierdat,rerdat,cerdat,0)
      return
c1000 format(/' *** Error ueos30v not implemented')
      end
