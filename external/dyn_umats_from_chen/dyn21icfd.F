#include "define.inc"
#include "define2.inc"
c
#ifdef EXTENDED
#ifdef USES_CXX
      subroutine icfd_userdefinedbc(eqtype,dimf,time,dt,
     &     i,pid,dragarray,
     &     pidsurarray,npids,nod,
     &     vel1,vel2,pre,rho,visc,lnnod,
     &     lcv)
c user defined routine returning lcv function of input variables
c
c     eqtype=1 pressure equation
c     eqtype=2 velocity equation
c     eqtype=3 temperature equation
c     dimf (for eqtype=2 only) : 1,2,3 for X,Y,Z axis respectfully
c     time and dt : current icfd time and timestep
c     i : internal node identifier on which the BC should be applied (base 0).
c     pid : surface part id on which the BC is applied
c     dragarray : mindex of size nbr surface part*12 containing all drag info
c                 for the different PIDs (ID given in pidsurarray)
c     pidsurarray : mindex of size nbr surface part containing all surface PIDs
c     npids : nbr surface parts
c     nod : mindex of size 3*number of nodes containing coordinates
c     vel1,vel2 : mindex of size 3*numberof nodes containing velocity at 
c                 current and previous timestep
c     pre, rho, visc : mindex of size number of nodes containing pressure,
c                      density,viscosity for all nodes
c     lnnod : nbr of nodes recognized by local cpu
c    
c     for example to access coordinates of node i one can do :
c           coord(1)=r_mem(nod+3*i  )
c           coord(2)=r_mem(nod+3*i+1)
c           coord(3)=r_mem(nod+3*i+2)
c     to acces pressure : press = r_mem(pre+i)
c     to access X-vel : vel(1)= r_mem(vel1+3*i  ) etc
c
c
      implicit none
      include 'iounits.inc'
#include "meshes.inc"
#include "dynmem.inc"
      integer eqtype,dimf
      real time,dt
      integer i,pid,npids,lnnod
      MINDEX dragarray,pidsurarray,nod,vel1,vel2,pre,rho,visc
      real lcv
      lcv=3.
      return
      end
      subroutine icfd_usercircuit(pidsur,nsteps,
     &     time,dt,flux,flux1,flux2,press1,press2,
c
     &        lcv)
      implicit none
      include 'iounits.inc'
c pidsur : icfd surface part ID
c nsteps : current ICFD step
c time : current ICFD time
c dt : current ICFD timestep
c flux : flow rate at time t
c flux1 : flow rate at time t_n-1 i.e at previous timestep
c flux2: flow rate at time t_n-2 i.e two time steps previously
c press1/press2 : pressure at previous timestep and two timesteps back
c pinit : Initial PRessure i.e Pressure given in *ICFD_INITIAL
c lcv : value which needs to be returned by the circuit equation i.e Pressure
c       value
      integer pidsur,nsteps
      real time,dt,flux,flux1,flux2,press1,press2
      real lcv
ccccc
      real pinit
      real r1,term1,c1,l1,r2,dflux,dflux2
      real rd,cd,rp,term2,term3,term4
      r1=5.
      c1=31.02
      pinit=1.2
      l1=0.
      r2=0.
      write(*,*)'enterusewind'
      if (r1.eq.0.) then
         term1=0.
      else
         term1=1/r1
      endif
      if (nsteps.le.2) then
         dflux=0.
         dflux2=0.
      elseif (nsteps.le.3) then
         dflux=(flux-flux1)/dt
         dflux2=0.
      else
         dflux=(flux-flux1)/dt
         dflux2=(flux+flux2-2*flux1)/(dt**2)
      endif
cccccccccc
      Rp=150.
      Rd=700.
      Cd=0.001
      term1=(Rp+Rd)*flux
      term2=Rp*Rd*Cd*dflux
      term3=press1/dt*Rd*Cd
      term4=(1.+Rd*Cd/dt)
ccccccccccc
      if (nsteps.le.1) then
         lcv=0.
      else
         lcv=((flux*(1+term1*r2)+(C1*r2+term1*l1)*dflux+l1*c1*dflux2)
     &        +C1/dt*press1)/
     &        (term1+c1/dt)
          lcv=(term1+term2+term3)/term4
       endif
       write(*,*)'lcvvvin',time,lcv
 18   continue
      return
      end
#endif
#endif
