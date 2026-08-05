# 1 "dyn21utan.F"
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





# 2 "dyn21utan.F" 2 
# 1 ".\define2.inc" 1 



# 3 "dyn21utan.F" 2 
      subroutine urtanb(cm,mt,capa,lft,llt,nconstp,crv,nnpcrv,nnm1,
     .     eltype)
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
      include 'nhisparm.inc'
      include 'memaia.inc'
      include 'umatss.inc'
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
# 22 "dyn21utan.F" 2 
      common/aux2loc/d1(nlq),d2(nlq),d3(nlq),d4(nlq),d5(nlq),d6(nlq),
     1 wzzdt(nlq),wyydt(nlq),wxxdt(nlq),einc(nlq)
      common/aux14loc/
     & sig1(nlq),sig2(nlq),sig3(nlq),sig4(nlq),
     & sig5(nlq),sig6(nlq),epsps(nlq),hsvs(nlq,NHISVAR)
      common/aux33loc/
     1 ix1(nlq),ix2(nlq),ix3(nlq),ix4(nlq),ixs(nlq),mxt(nlq)
      common/bk36loc/index
      common/bux13loc/eps(6),sig(6),hsv(NHISVAR),temps(nlq),es(6,6)
      common/subtssloc/dt1siz(nlq)
      common/vect8loc/dsave(nlq,6,6)
      common/bk00/numnp,numpc,numlp,neq,ndof,nlcur,numcl,numvc,
     + ndtpts,nelmd,nmmat,numelh,numelb,numels,numelt,numdp,
     + grvity,idirgv,nodspc,nspcor,nusa
      common/bk26/begtim,nintcy
      common/bk28/summss,xke,xpe,tt,xte0,erodeke,erodeie
c
      dimension cm(*),nconstp(*),crv(lq1,2,*),nnpcrv(*)
      character*(*) eltype
      logical failel,failels(nlq),unsym
c     flag if the tangent stiffness is allowed nonsymmetric
c$omp threadprivate (/vect8loc/)
c$omp threadprivate (/subtssloc/)
c$omp threadprivate (/bux13loc/)
c$omp threadprivate (/bk36loc/)
c$omp threadprivate (/aux33loc/)
c$omp threadprivate (/aux14loc/)
c$omp threadprivate (/aux2loc/)
c$omp threadprivate (/bki04iloc/)
c$omp threadprivate (/bki03rloc/)
c$omp threadprivate (/bki03iloc/)
      unsym=is17loc.eq.2
c
      mx=48*(mxt(lft)-1)
c
c     Determining number of requested history variables
c
      no_hsvs=nconstp(mxt(lft))
c
c     memory pointer for extra memory data
      lcma=ncma+nmmat+ia(ncma+mxt(lft)-1)-1
c
c     vector flag
c
      ivect=ivectr(mt)
c
      mte40=mt-40
c
c     scalar utan
c
      if (ivect.eq.0) then
        do 90 i=lft,llt
c
c       gathering of variables
c
        index =i
        dt1   =dt1siz(i)
        eps(1)=d1(i)
        eps(2)=d2(i)
        eps(3)=d3(i)
        eps(4)=d4(i)
        eps(5)=d5(i)
        eps(6)=d6(i)
        sig(1)=sig1(i)
        sig(2)=sig2(i)
        sig(3)=sig3(i)
        sig(4)=sig4(i)
        sig(5)=sig5(i)
        sig(6)=sig6(i)
        epsp=epsps(i)
        temper=temps(i)
        failel=.false.
        if (no_hsvs.gt.0) then
          do 30 j=1,no_hsvs
          hsv(j)=hsvs(i,j)
 30       continue
        endif
c
c       setting material tangent modulus to = 0
c
        do k=1,6
          do j=1,6
            es(j,k)=0.
          enddo
        enddo
c
c       call user developed subroutines here
c
        go to (41,42,43,44,45,46,47,48,49,50), mte40
   41   call utan41 (cm(mx+1),eps,sig,epsp,hsv,dt1,unsym,
     1   capa,eltype,tt,temper,es,crv,nnpcrv,failel,a(lcma),0)
        go to 60
   42   call utan42 (cm(mx+1),eps,sig,epsp,hsv,dt1,unsym,
     1   capa,eltype,tt,temper,es,crv,nnpcrv,failel,a(lcma),0)
        go to 60
   43   call utan43 (cm(mx+1),eps,sig,epsp,hsv,dt1,unsym,
     1   capa,eltype,tt,temper,es,crv,nnpcrv,failel,a(lcma),0)
        go to 60
   44   call utan44 (cm(mx+1),eps,sig,epsp,hsv,dt1,unsym,
     1   capa,eltype,tt,temper,es,crv,nnpcrv,failel,a(lcma),0)
        go to 60
   45   call utan45 (cm(mx+1),eps,sig,epsp,hsv,dt1,unsym,
     1   capa,eltype,tt,temper,es,crv,nnpcrv,failel,a(lcma),0)
        go to 60
   46   call utan46 (cm(mx+1),eps,sig,epsp,hsv,dt1,unsym,
     1   capa,eltype,tt,temper,es,crv,nnpcrv,failel,a(lcma),0)
        go to 60
   47   call utan47 (cm(mx+1),eps,sig,epsp,hsv,dt1,unsym,
     1   capa,eltype,tt,temper,es,crv,nnpcrv,failel,a(lcma),0)
        go to 60
   48   call utan48 (cm(mx+1),eps,sig,epsp,hsv,dt1,unsym,
     1   capa,eltype,tt,temper,es,crv,nnpcrv,failel,a(lcma),0)
        go to 60
   49   call utan49 (cm(mx+1),eps,sig,epsp,hsv,dt1,unsym,
     1   capa,eltype,tt,temper,es,crv,nnpcrv,failel,a(lcma),0)
        go to 60
 50     call utan50 (cm(mx+1),eps,sig,epsp,hsv,dt1,unsym,
     1   capa,eltype,tt,temper,es,crv,nnpcrv,failel,a(lcma),0)
c
c       scattering tangent modulus
c
 60     do k=1,6
          do j=1,6
           dsave(i,j,k)=es(j,k)
          enddo
        enddo
 90    continue
c
c
c     vector umat
c
      else
c
c       setting material tangent modulus to = 0
c
        do k=1,6
          do j=1,6
            do i=lft,llt
              dsave(i,j,k)=0.
            enddo
          enddo
        enddo
c
        do i=lft,llt
          failels(i)=.false.
        enddo
c
c       call user developed routines here
c       first history variable is the one requested
c
        if (mt.eq.41) then
          call utan41v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .     sig1,sig2,sig3,sig4,
     .     sig5,sig6,epsps,hsvs,unsym,
     .     lft,llt,dt1siz,capa,eltype,tt,temps,dsave,nlq,crv,nnpcrv,
     .     failels,
     .     a(lcma),0)
        elseif (mt.eq.42) then
          call utan42v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .     sig1,sig2,sig3,sig4,
     .     sig5,sig6,epsps,hsvs,unsym,
     .     lft,llt,dt1siz,capa,eltype,tt,temps,dsave,nlq,crv,nnpcrv,
     .     failels,
     .     a(lcma),0)
        elseif (mt.eq.43) then
          call utan43v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .     sig1,sig2,sig3,sig4,
     .     sig5,sig6,epsps,hsvs,unsym,
     .     lft,llt,dt1siz,capa,eltype,tt,temps,dsave,nlq,crv,nnpcrv,
     .     failels,
     .     a(lcma),0)
        elseif (mt.eq.44) then
          call utan44v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .     sig1,sig2,sig3,sig4,
     .     sig5,sig6,epsps,hsvs,unsym,
     .     lft,llt,dt1siz,capa,eltype,tt,temps,dsave,nlq,crv,nnpcrv,
     .     failels,
     .     a(lcma),0)
        elseif (mt.eq.45) then
          call utan45v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .     sig1,sig2,sig3,sig4,
     .     sig5,sig6,epsps,hsvs,unsym,
     .     lft,llt,dt1siz,capa,eltype,tt,temps,dsave,nlq,crv,nnpcrv,
     .     failels,
     .     a(lcma),0)
        elseif (mt.eq.46) then
          call utan46v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .     sig1,sig2,sig3,sig4,
     .     sig5,sig6,epsps,hsvs,unsym,
     .     lft,llt,dt1siz,capa,eltype,tt,temps,dsave,nlq,crv,nnpcrv,
     .     failels,
     .     a(lcma),0)
        elseif (mt.eq.47) then
          call utan47v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .     sig1,sig2,sig3,sig4,
     .     sig5,sig6,epsps,hsvs,unsym,
     .     lft,llt,dt1siz,capa,eltype,tt,temps,dsave,nlq,crv,nnpcrv,
     .     failels,
     .     a(lcma),0)
        elseif (mt.eq.48) then
          call utan48v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .     sig1,sig2,sig3,sig4,
     .     sig5,sig6,epsps,hsvs,unsym,
     .     lft,llt,dt1siz,capa,eltype,tt,temps,dsave,nlq,crv,nnpcrv,
     .     failels,
     .     a(lcma),0)
        elseif (mt.eq.49) then
          call utan49v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .     sig1,sig2,sig3,sig4,
     .     sig5,sig6,epsps,hsvs,unsym,
     .     lft,llt,dt1siz,capa,eltype,tt,temps,dsave,nlq,crv,nnpcrv,
     .     failels,
     .     a(lcma),0)
        elseif (mt.eq.50) then
          call utan50v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .     sig1,sig2,sig3,sig4,
     .     sig5,sig6,epsps,hsvs,unsym,
     .     lft,llt,dt1siz,capa,eltype,tt,temps,dsave,nlq,crv,nnpcrv,
     .     failels,
     .     a(lcma),0)
        elseif (mt.eq.281) then
          call utan281v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .     sig1,sig2,sig3,sig4,
     .     sig5,sig6,epsps,hsvs,
     .     lft,llt,dt1siz,capa,eltype,tt,temps,dsave,nlq,crv,failels,
     .     a(lcma))
        elseif (mt.eq.282) then
          call utan282v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .     sig1,sig2,sig3,sig4,
     .     sig5,sig6,epsps,hsvs,
     .     lft,llt,dt1siz,capa,eltype,tt,temps,dsave,nlq,crv,failels,
     .     a(lcma))
        elseif (mt.eq.283) then
          call utan283v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .     sig1,sig2,sig3,sig4,
     .     sig5,sig6,epsps,hsvs,
     .     lft,llt,dt1siz,capa,eltype,tt,temps,dsave,nlq,crv,failels,
     .     a(lcma))
        elseif (mt.eq.284) then
          call utan284v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .     sig1,sig2,sig3,sig4,
     .     sig5,sig6,epsps,hsvs,
     .     lft,llt,dt1siz,capa,eltype,tt,temps,dsave,nlq,crv,failels,
     .     a(lcma))
        elseif (mt.eq.286) then
          call utan286v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .     sig1,sig2,sig3,sig4,
     .     sig5,sig6,epsps,hsvs,
     .     lft,llt,dt1siz,capa,eltype,tt,temps,dsave,nlq,crv,failels,
     .     a(lcma))
        elseif (mt.eq.287) then
          call utan287v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .     sig1,sig2,sig3,sig4,
     .     sig5,sig6,epsps,hsvs,
     .     lft,llt,dt1siz,capa,eltype,tt,temps,dsave,nlq,crv,failels,
     .     a(lcma))
       elseif (mt.eq.289) then
          call utan289v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .     sig1,sig2,sig3,sig4,
     .     sig5,sig6,epsps,hsvs,
     .     lft,llt,dt1siz,capa,eltype,tt,temps,dsave,nlq,crv,failels,
     .     a(lcma))
        endif
      endif
c
      return
      end
      subroutine urtanh(cm,mt,crv,nnpcrv,lft,llt,nconstp,nnm1,eltype)
# 290

c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     assume that F and all coordinate transformations have been
c     performed by this time, and everything is already loaded in
c     common blocks
c
      include 'nlqparm'
      include 'nhisparm.inc'
# 1 ".\bk19.inc" 1 
      integer nconst(2000),lenma,ncneos(50),mtecom(2000),     
     & nhgshl(30)
      common/bk19/nconst,lenma,ncneos,mtecom,nhgshl
# 306 "dyn21utan.F" 2 
      include 'memaia.inc'
      include 'umatss.inc'
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
# 309 "dyn21utan.F" 2 
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
# 310 "dyn21utan.F" 2 
# 1 ".\bk13.inc" 1 
      integer lc0,lc1h,lc1b,lc1t,lc2,lc3,lc4,lc5,lc6,lc6e,lc6f,lc9,     
     & lc10,lc11,lc12,lc13,lc14,lc15,lc16,lc17,lc18,lb0,lb1,lb2,        
     & lc7a,lc7b,lc7c,lc7d,lc7e,lc7f,lc7g,lc7h,lc7i,lc7j,lc7k,lc7l,     
     & lc7t,lc7x,lc6g,lc6h
      common/bk13/lc0,lc1h,lc1b,lc1t,lc2,lc3,lc4,lc5,lc6,lc6e,lc6f,lc9, 
     & lc10,lc11,lc12,lc13,lc14,lc15,lc16,lc17,lc18,lb0,lb1,lb2,        
     & lc7a,lc7b,lc7c,lc7d,lc7e,lc7f,lc7g,lc7h,lc7i,lc7j,lc7k,lc7l,     
     & lc7t,lc7x,lc6g,lc6h
# 311 "dyn21utan.F" 2 
      common/aux14loc/sig1(nlq),sig2(nlq),sig3(nlq),sig4(nlq),sig5(nlq),
     & sig6(nlq),epsps(nlq),hsvs(nlq,NHISVAR)
      common/aux18loc/dd(nlq),def(nlq),ddq(nlq)
      common/aux33loc/
     1 ix1(nlq),ix2(nlq),ix3(nlq),ix4(nlq),ixs(nlq,4),mxt(nlq)
      common/aux40loc/
     1 a11(nlq),a12(nlq),a13(nlq),a21(nlq),a22(nlq),a23(nlq),
     2 a31(nlq),a32(nlq),a33(nlq),z11(nlq),z12(nlq),z13(nlq),
     3 z21(nlq),z22(nlq),z23(nlq),z31(nlq),z32(nlq),z33(nlq)
      common/aux35loc/rhoa(nlq),cb(nlq),davg(nlq),p(nlq)
      common/aux41loc/qq1(nlq),cbb(nlq),aj1(nlq)
      common/bk36loc/index
      common/bux13loc/ eps(6),sig(6),hsv(NHISVAR),temps(nlq),es(6,6)
      common/soundloc/ss(nlq),sndsp(nlq),diagm(nlq),sarea(nlq),
     . dxl(nlq)
      common/subtssloc/dt1siz(nlq)
      common/vect8loc/dsave(nlq,6,6)
c
      common/bk00/numnp,numpc,numlp,neq,ndof,nlcur,numcl,numvc,
     + ndtpts,nelmd,nmmat,numelh,numelb,numels,numelt,numdp,
     + grvity,idirgv,nodspc,nspcor,nusa
      common/bk01/itherm,itemp,ntmp0,ntmp1,itempan,itempdr,itmpe(14),
     . itempe(10),nthxp,ithxp(19)
      common/bk28/summss,xke,xpe,tt,xte0,erodeke,erodeie
      common/aux2loc/d1(nlq),d2(nlq),d3(nlq),d4(nlq),d5(nlq),d6(nlq),
     1 wzzdt(nlq),wyydt(nlq),wxxdt(nlq),einc(nlq)
      common/bk26/begtim,nintcy
      common/numcpu/ncpu,ncpua,ncpub,lenvec(9)
      common/thropt/itopaz(101)
      common/tsbsis/h(8,5,5),pr(8,5,5),ps(8,5,5),pt(8,5,5),ipt,
     1 nip,wgts(10,10),szeta(10,10)
c
      dimension cm(*),crv(lq1,2,*),nconstp(*)
      integer nnpcrv(*)
      character*(*) eltype
c     dimension eps(6),sig(6),hsv(NHISVAR),temps(nlq),es(6,6)
      dimension sigmaold(nlq,6)
      dimension dfgold(nlq,9)
      logical failel,failels(nlq),unsym
c     data temps/nlq*0.0/
c     flag if the tangent stiffness is allowed nonsymmetric
c$omp threadprivate (/vect8loc/)
c$omp threadprivate (/subtssloc/)
c$omp threadprivate (/soundloc/)
c$omp threadprivate (/bux13loc/)
c$omp threadprivate (/bk36loc/)
c$omp threadprivate (/aux41loc/)
c$omp threadprivate (/aux40loc/)
c$omp threadprivate (/aux35loc/)
c$omp threadprivate (/aux33loc/)
c$omp threadprivate (/aux18loc/)
c$omp threadprivate (/aux14loc/)
c$omp threadprivate (/aux2loc/)
c$omp threadprivate (/bki04iloc/)
c$omp threadprivate (/bki03rloc/)
c$omp threadprivate (/bki03iloc/)
      unsym=is17loc.eq.2
c
      capa=0.0
      mx=48*(mxt(lft)-1)
c
c     Determining number of requested history variables
c
      no_hsvs=nconstp(mxt(lft))
      if (lenvec(5) .eq.1) no_hsvs=no_hsvs-6
      if (iorien(mt).ne.0) no_hsvs=no_hsvs-6
      if (ihyper(mt).ne.0) no_hsvs=no_hsvs-9
      if (iorien(mt).ne.0.and.ihyper(mt).lt.0) no_hsvs=no_hsvs-6
      if (ifipts(mt).lt.0) no_hsvs=no_hsvs-1
c
c     initialization of indeces
c
      if (iorien(mt).ne.0) then
        if (ihyper(mt).ne.0) then
          ind_defgrad=1+no_hsvs
          ind_ortho=ind_defgrad+9
        else
          ind_ortho=1+no_hsvs
        endif
        if (ifipts(mt).lt.0) then
          ind_fipts=ind_ortho
          ind_ortho=ind_ortho+1
        endif
        ind_q11=ind_ortho
        ind_q12=ind_ortho+1
        ind_q13=ind_ortho+2
        ind_q31=ind_ortho+3
        ind_q32=ind_ortho+4
        ind_q33=ind_ortho+5
        ind_last=ind_q33
        if (ihyper(mt).lt.0) then
          ind_qstore=ind_last+1
          ind_last=ind_last+6
        endif
      else
        if (ihyper(mt).ne.0) then
          ind_defgrad=1+no_hsvs
          ind_last=ind_defgrad+8
        else
          ind_last=no_hsvs
        endif
        if (ifipts(mt).lt.0) then
          ind_fipts=ind_last+1
          ind_last=ind_last+1
        endif
      endif
c
      if (iorien(mt).ne.0) then
c
c       store global stresses
c
        if (ihyper(mt).ge.0) then
          do i=lft,llt
            sigmaold(i,1)=sig1(i)
            sigmaold(i,2)=sig2(i)
            sigmaold(i,3)=sig3(i)
            sigmaold(i,4)=sig4(i)
            sigmaold(i,5)=sig5(i)
            sigmaold(i,6)=sig6(i)
          enddo
c
c         transform stresses to local system
c
          call ldsm22(lft,llt)
        endif
c
c       storage of deformation gradient
c
        if (ihyper(mt).gt.0) then
          if11=ind_defgrad
          if21=ind_defgrad+1
          if31=ind_defgrad+2
          if12=ind_defgrad+3
          if22=ind_defgrad+4
          if32=ind_defgrad+5
          if13=ind_defgrad+6
          if23=ind_defgrad+7
          if33=ind_defgrad+8
c
c         store deformation gradient in global system
c
          do i=lft,llt
            dfgold(i,1)=hsvs(i,if11)
            dfgold(i,2)=hsvs(i,if21)
            dfgold(i,3)=hsvs(i,if31)
            dfgold(i,4)=hsvs(i,if12)
            dfgold(i,5)=hsvs(i,if22)
            dfgold(i,6)=hsvs(i,if32)
            dfgold(i,7)=hsvs(i,if13)
            dfgold(i,8)=hsvs(i,if23)
            dfgold(i,9)=hsvs(i,if33)
          enddo
c
c         transform deformation gradient to local system
c         as F_bar=Q^T*F
c
          do i=lft,llt
            f1=z11(i)*hsvs(i,if11)+
     1         z12(i)*hsvs(i,if21)+z13(i)*hsvs(i,if31)
            f2=z21(i)*hsvs(i,if11)+
     1         z22(i)*hsvs(i,if21)+z23(i)*hsvs(i,if31)
            hsvs(i,if31)=z31(i)*hsvs(i,if11)+
     1         z32(i)*hsvs(i,if21)+z33(i)*hsvs(i,if31)
            hsvs(i,if11)=f1
            hsvs(i,if21)=f2
            f1=z11(i)*hsvs(i,if12)+
     1         z12(i)*hsvs(i,if22)+z13(i)*hsvs(i,if32)
            f2=z21(i)*hsvs(i,if12)+
     1         z22(i)*hsvs(i,if22)+z23(i)*hsvs(i,if32)
            hsvs(i,if32)=z31(i)*hsvs(i,if12)+
     1         z32(i)*hsvs(i,if22)+z33(i)*hsvs(i,if32)
            hsvs(i,if12)=f1
            hsvs(i,if22)=f2
            f1=z11(i)*hsvs(i,if13)+
     1         z12(i)*hsvs(i,if23)+z13(i)*hsvs(i,if33)
            f2=z21(i)*hsvs(i,if13)+
     1         z22(i)*hsvs(i,if23)+z23(i)*hsvs(i,if33)
            hsvs(i,if33)=z31(i)*hsvs(i,if13)+
     1         z32(i)*hsvs(i,if23)+z33(i)*hsvs(i,if33)
            hsvs(i,if13)=f1
            hsvs(i,if23)=f2
          enddo
c
c       storage of deformation gradient
c
        else if (ihyper(mt).lt.0) then
          if11=ind_defgrad
          if21=ind_defgrad+1
          if31=ind_defgrad+2
          if12=ind_defgrad+3
          if22=ind_defgrad+4
          if32=ind_defgrad+5
          if13=ind_defgrad+6
          if23=ind_defgrad+7
          if33=ind_defgrad+8
c
c         store deformation gradient in global system
c
          do i=lft,llt
            dfgold(i,1)=hsvs(i,if11)
            dfgold(i,2)=hsvs(i,if21)
            dfgold(i,3)=hsvs(i,if31)
            dfgold(i,4)=hsvs(i,if12)
            dfgold(i,5)=hsvs(i,if22)
            dfgold(i,6)=hsvs(i,if32)
            dfgold(i,7)=hsvs(i,if13)
            dfgold(i,8)=hsvs(i,if23)
            dfgold(i,9)=hsvs(i,if33)
          enddo
c
c         transform deformation gradient to local system
c         as F_bar=F*Q
c
          do i=lft,llt
            f1=z11(i)*hsvs(i,if11)+
     1         z12(i)*hsvs(i,if12)+z13(i)*hsvs(i,if13)
            f2=z21(i)*hsvs(i,if11)+
     1         z22(i)*hsvs(i,if12)+z23(i)*hsvs(i,if13)
            hsvs(i,if13)=z31(i)*hsvs(i,if11)+
     1         z32(i)*hsvs(i,if12)+z33(i)*hsvs(i,if13)
            hsvs(i,if11)=f1
            hsvs(i,if12)=f2
            f1=z11(i)*hsvs(i,if21)+
     1         z12(i)*hsvs(i,if22)+z13(i)*hsvs(i,if23)
            f2=z21(i)*hsvs(i,if21)+
     1         z22(i)*hsvs(i,if22)+z23(i)*hsvs(i,if23)
            hsvs(i,if23)=z31(i)*hsvs(i,if21)+
     1         z32(i)*hsvs(i,if22)+z33(i)*hsvs(i,if23)
            hsvs(i,if21)=f1
            hsvs(i,if22)=f2
            f1=z11(i)*hsvs(i,if31)+
     1         z12(i)*hsvs(i,if32)+z13(i)*hsvs(i,if33)
            f2=z21(i)*hsvs(i,if31)+
     1         z22(i)*hsvs(i,if32)+z23(i)*hsvs(i,if33)
            hsvs(i,if33)=z31(i)*hsvs(i,if31)+
     1         z32(i)*hsvs(i,if32)+z33(i)*hsvs(i,if33)
            hsvs(i,if31)=f1
            hsvs(i,if32)=f2
          enddo
        endif
      endif
c
c     if ishrmp(mt).lt.0 then the flag for temperature is active
c     temperatures are stored in the temps array.
c
      num_nods=8
      if (eltype.eq.'shl_t') num_nods=4
      if (eltype.eq.'sld2d'.or.eltype.eq.'sldax') num_nods=4
      if (ishrmp(mt).lt.0) then
        if (eltype.eq.'solid'.or.eltype.eq.'sldco') then
          call usr_temps (a(ntmp0+1),a(n19),itemp,temps,lft,llt,ix1,ix2,
     .        ix3,ix4,ixs(1,1),ixs(1,2),ixs(1,3),ixs(1,4),num_nods,
     .        itopaz,0,0.,0.,0.,itempe(3),ia(nnm1+itempe(7)))
        elseif (eltype.eq.'tshel') then
          call usr_temps (a(ntmp0+1),a(n19),itemp,temps,lft,llt,ix1,ix2,
     .        ix3,ix4,ixs(1,1),ixs(1,2),ixs(1,3),ixs(1,4),num_nods,
     .        itopaz,0,0.,0.,0.,itempe(6),ia(nnm1+itempe(10)))
        else  
          call usr_temps (a(ntmp0+1),a(n19),itemp,temps,lft,llt,ix1,ix2,
     .        ix3,ix4,ixs(1,1),ixs(1,2),ixs(1,3),ixs(1,4),num_nods,
     .        itopaz,0,0.,0.,0.,0,ia(nnm1+itempe(7)))
        endif
      else
        do i=lft,llt
          temps(i)=0.0
        enddo
      endif
c
c     memory pointer for extra memory data
      lcma=ncma+nmmat+ia(ncma+mxt(lft)-1)-1
c
c     vector flag
c
      ivect=ivectr(mt)
c
      mte40=mt-40
c
c     scalar utan
c
      if (ivect.eq.0) then
        do 90 i=lft,llt
c
c       gathering of variables
c
        index =i
        dt1   =dt1siz(i)
        eps(1)=d1(i)
        eps(2)=d2(i)
        eps(3)=d3(i)
        eps(4)=d4(i)
        eps(5)=d5(i)
        eps(6)=d6(i)
        sig(1)=sig1(i)
        sig(2)=sig2(i)
        sig(3)=sig3(i)
        sig(4)=sig4(i)
        sig(5)=sig5(i)
        sig(6)=sig6(i)
        epsp=epsps(i)
        temper=temps(i)
        failel=.false.
        if (ifipts(mt).lt.0) failel=hsvs(i,ind_fipts).ne.0.
        if (no_hsvs.gt.0) then
          do 30 j=1,no_hsvs
          hsv(j)=hsvs(i,j)
 30       continue
        endif
        if (ihyper(mt).ne.0) then
          do 40 j=1,9
          hsv(no_hsvs+j)=hsvs(i,ind_defgrad-1+j)
 40       continue
        endif
c
c       setting material tangent modulus to = 0
c
        do k=1,6
          do j=1,6
            es(j,k)=0.
          enddo
        enddo
c
c       call user developed subroutines here
c
        go to (41,42,43,44,45,46,47,48,49,50), mte40
   41   call utan41 (cm(mx+1),eps,sig,epsp,hsv,dt1,unsym,
     1   capa,eltype,tt,temper,es,crv,nnpcrv,failel,a(lcma),0)
        go to 60
   42   call utan42 (cm(mx+1),eps,sig,epsp,hsv,dt1,unsym,
     1   capa,eltype,tt,temper,es,crv,nnpcrv,failel,a(lcma),0)
        go to 60
   43   call utan43 (cm(mx+1),eps,sig,epsp,hsv,dt1,unsym,
     1   capa,eltype,tt,temper,es,crv,nnpcrv,failel,a(lcma),0)
        go to 60
   44   call utan44 (cm(mx+1),eps,sig,epsp,hsv,dt1,unsym,
     1   capa,eltype,tt,temper,es,crv,nnpcrv,failel,a(lcma),0)
        go to 60
   45   call utan45 (cm(mx+1),eps,sig,epsp,hsv,dt1,unsym,
     1   capa,eltype,tt,temper,es,crv,nnpcrv,failel,a(lcma),0)
        go to 60
   46   call utan46 (cm(mx+1),eps,sig,epsp,hsv,dt1,unsym,
     1   capa,eltype,tt,temper,es,crv,nnpcrv,failel,a(lcma),0)
        go to 60
   47   call utan47 (cm(mx+1),eps,sig,epsp,hsv,dt1,unsym,
     1   capa,eltype,tt,temper,es,crv,nnpcrv,failel,a(lcma),0)
        go to 60
   48   call utan48 (cm(mx+1),eps,sig,epsp,hsv,dt1,unsym,
     1   capa,eltype,tt,temper,es,crv,nnpcrv,failel,a(lcma),0)
        go to 60
   49   call utan49 (cm(mx+1),eps,sig,epsp,hsv,dt1,unsym,
     1   capa,eltype,tt,temper,es,crv,nnpcrv,failel,a(lcma),0)
        go to 60
 50     call utan50 (cm(mx+1),eps,sig,epsp,hsv,dt1,unsym,
     1   capa,eltype,tt,temper,es,crv,nnpcrv,failel,a(lcma),0)
c
c       scattering tangent modulus
c
 60     do k=1,6
          do j=1,6
           dsave(i,j,k)=es(j,k)
          enddo
        enddo
 90    continue
c
c
c     vector umat
c
      else
c
c       setting material tangent modulus to = 0
c
        do k=1,6
          do j=1,6
            do i=lft,llt
              dsave(i,j,k)=0.
            enddo
          enddo
        enddo
c
        if (ifipts(mt).ge.0) then
          do i=lft,llt
            failels(i)=.false.
          enddo
        else
          do i=lft,llt
            failels(i)=hsvs(i,ind_fipts).ne.0.
          enddo
        endif
c
c       call user developed routines here
c       first history variable is the one requested
c
        if (mt.eq.41) then
          call utan41v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .     sig1,sig2,sig3,sig4,
     .     sig5,sig6,epsps,hsvs,unsym,
     .     lft,llt,dt1siz,capa,eltype,tt,temps,dsave,nlq,crv,nnpcrv,
     .     failels,
     .     a(lcma),0)
        elseif (mt.eq.42) then
          call utan42v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .     sig1,sig2,sig3,sig4,
     .     sig5,sig6,epsps,hsvs,unsym,
     .     lft,llt,dt1siz,capa,eltype,tt,temps,dsave,nlq,crv,nnpcrv,
     .     failels,
     .     a(lcma),0)
        elseif (mt.eq.43) then
          call utan43v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .     sig1,sig2,sig3,sig4,
     .     sig5,sig6,epsps,hsvs,unsym,
     .     lft,llt,dt1siz,capa,eltype,tt,temps,dsave,nlq,crv,nnpcrv,
     .     failels,
     .     a(lcma),0)
        elseif (mt.eq.44) then
          call utan44v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .     sig1,sig2,sig3,sig4,
     .     sig5,sig6,epsps,hsvs,unsym,
     .     lft,llt,dt1siz,capa,eltype,tt,temps,dsave,nlq,crv,nnpcrv,
     .     failels,
     .     a(lcma),0)
        elseif (mt.eq.45) then
          call utan45v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .     sig1,sig2,sig3,sig4,
     .     sig5,sig6,epsps,hsvs,unsym,
     .     lft,llt,dt1siz,capa,eltype,tt,temps,dsave,nlq,crv,nnpcrv,
     .     failels,
     .     a(lcma),0)
        elseif (mt.eq.46) then
          call utan46v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .     sig1,sig2,sig3,sig4,
     .     sig5,sig6,epsps,hsvs,unsym,
     .     lft,llt,dt1siz,capa,eltype,tt,temps,dsave,nlq,crv,nnpcrv,
     .     failels,
     .     a(lcma),0)
        elseif (mt.eq.47) then
          call utan47v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .     sig1,sig2,sig3,sig4,
     .     sig5,sig6,epsps,hsvs,unsym,
     .     lft,llt,dt1siz,capa,eltype,tt,temps,dsave,nlq,crv,nnpcrv,
     .     failels,
     .     a(lcma),0)
        elseif (mt.eq.48) then
          call utan48v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .     sig1,sig2,sig3,sig4,
     .     sig5,sig6,epsps,hsvs,unsym,
     .     lft,llt,dt1siz,capa,eltype,tt,temps,dsave,nlq,crv,nnpcrv,
     .     failels,
     .     a(lcma),0)
        elseif (mt.eq.49) then
          call utan49v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .     sig1,sig2,sig3,sig4,
     .     sig5,sig6,epsps,hsvs,unsym,
     .     lft,llt,dt1siz,capa,eltype,tt,temps,dsave,nlq,crv,nnpcrv,
     .     failels,
     .     a(lcma),0)
        elseif (mt.eq.50) then
          call utan50v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .     sig1,sig2,sig3,sig4,
     .     sig5,sig6,epsps,hsvs,unsym,
     .     lft,llt,dt1siz,capa,eltype,tt,temps,dsave,nlq,crv,nnpcrv,
     .     failels,
     .     a(lcma),0)
        elseif (mt.eq.281) then
          call utan281v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .     sig1,sig2,sig3,sig4,
     .     sig5,sig6,epsps,hsvs,
     .     lft,llt,dt1siz,capa,eltype,tt,temps,dsave,nlq,crv,failels,
     .     a(lcma))
        elseif (mt.eq.282) then
          call utan282v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .     sig1,sig2,sig3,sig4,
     .     sig5,sig6,epsps,hsvs,
     .     lft,llt,dt1siz,capa,eltype,tt,temps,dsave,nlq,crv,failels,
     .     a(lcma))
        elseif (mt.eq.283) then
          call utan283v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .     sig1,sig2,sig3,sig4,
     .     sig5,sig6,epsps,hsvs,
     .     lft,llt,dt1siz,capa,eltype,tt,temps,dsave,nlq,crv,failels,
     .     a(lcma))
        elseif (mt.eq.284) then
          call utan284v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .     sig1,sig2,sig3,sig4,
     .     sig5,sig6,epsps,hsvs,
     .     lft,llt,dt1siz,capa,eltype,tt,temps,dsave,nlq,crv,failels,
     .     a(lcma))
        elseif (mt.eq.286) then
          call utan286v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .     sig1,sig2,sig3,sig4,
     .     sig5,sig6,epsps,hsvs,
     .     lft,llt,dt1siz,capa,eltype,tt,temps,dsave,nlq,crv,failels,
     .     a(lcma))
        elseif (mt.eq.287) then
          call utan287v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .     sig1,sig2,sig3,sig4,
     .     sig5,sig6,epsps,hsvs,
     .     lft,llt,dt1siz,capa,eltype,tt,temps,dsave,nlq,crv,failels,
     .     a(lcma))
        elseif (mt.eq.289) then
          call utan289v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .     sig1,sig2,sig3,sig4,
     .     sig5,sig6,epsps,hsvs,
     .     lft,llt,dt1siz,capa,eltype,tt,temps,dsave,nlq,crv,failels,
     .     a(lcma))
        endif
      endif
c
      if (iorien(mt).ne.0) then
c
c       transform tangent stiffness to global system
c
        if (ihyper(mt).ge.0) then
          call transform44(z11,z12,z13,z21,z22,z23,z31,z32,z33,
     1     lft,llt)
c
c         restore stresses in global system
c
          do i=lft,llt
            sig1(i)=sigmaold(i,1)
            sig2(i)=sigmaold(i,2)
            sig3(i)=sigmaold(i,3)
            sig4(i)=sigmaold(i,4)
            sig5(i)=sigmaold(i,5)
            sig6(i)=sigmaold(i,6)
          enddo
        endif
c
c       restore deformation gradient in global system
c
        if (ihyper(mt).ne.0) then
          do i=lft,llt
            hsvs(i,if11)=dfgold(i,1)
            hsvs(i,if21)=dfgold(i,2)
            hsvs(i,if31)=dfgold(i,3)
            hsvs(i,if12)=dfgold(i,4)
            hsvs(i,if22)=dfgold(i,5)
            hsvs(i,if32)=dfgold(i,6)
            hsvs(i,if13)=dfgold(i,7)
            hsvs(i,if23)=dfgold(i,8)
            hsvs(i,if33)=dfgold(i,9)
          enddo
        endif
      endif
c
      return
      end
      subroutine urtans(cm,mt,capa,lft,llt,nconstp,nnm1,eltype)
# 857

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
# 1 ".\bk19.inc" 1 
      integer nconst(2000),lenma,ncneos(50),mtecom(2000),     
     & nhgshl(30)
      common/bk19/nconst,lenma,ncneos,mtecom,nhgshl
# 869 "dyn21utan.F" 2 
      include 'memaia.inc'
      include 'umatss.inc'
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
# 872 "dyn21utan.F" 2 
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
# 873 "dyn21utan.F" 2 
# 1 ".\bk13.inc" 1 
      integer lc0,lc1h,lc1b,lc1t,lc2,lc3,lc4,lc5,lc6,lc6e,lc6f,lc9,     
     & lc10,lc11,lc12,lc13,lc14,lc15,lc16,lc17,lc18,lb0,lb1,lb2,        
     & lc7a,lc7b,lc7c,lc7d,lc7e,lc7f,lc7g,lc7h,lc7i,lc7j,lc7k,lc7l,     
     & lc7t,lc7x,lc6g,lc6h
      common/bk13/lc0,lc1h,lc1b,lc1t,lc2,lc3,lc4,lc5,lc6,lc6e,lc6f,lc9, 
     & lc10,lc11,lc12,lc13,lc14,lc15,lc16,lc17,lc18,lb0,lb1,lb2,        
     & lc7a,lc7b,lc7c,lc7d,lc7e,lc7f,lc7g,lc7h,lc7i,lc7j,lc7k,lc7l,     
     & lc7t,lc7x,lc6g,lc6h
# 874 "dyn21utan.F" 2 
# 1 ".\dynmem.inc" 1 
c$omp threadprivate (/bki04iloc/)
c$omp threadprivate (/bki03rloc/)
c$omp threadprivate (/bki03iloc/)
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

# 875 "dyn21utan.F" 2 
# 1 ".\ez_mem.inc" 1 
!
!***  EASY dynamic memory management
!
!***  C STYLE INCLUDE because of the use of integer*8
!
!***  ALLOCATE MEMORY:
!         call ez_mem_allocm(i,len,literal_string)
!         call ez_mem_allocmchk(i,len,literal_string)
!
!       ez_mem_allocm puts a value of 0 in iezp(i) and mezp(i) to indicate
!                  that the memory allocation failed just as mem_allocm
!                  returns a 0 for the memory pointer
!
!       ez_mem_allocmchk terminates the code on failure.
!
!       where
!         i is the equivalent of the integer used with addlen
!         len is the number of words of memory
!         literal_string is a 'description'
!
!         iezp(i) is the handle you are using
!         mezp(i) is the corresponding integer*8 pointer to i_mem and r_mem
!
!       therefore iezp points to mezp through memh_ptr, i.e.,
!         mezp(i)=memh_ptr(iezp(i))
!
!***  REALLOCATE MEMORY:
!         call ez_mem_realloc(i,len,literal_string)
!
!***  FREE MEMORY:
!         automatic at end of run
!       or
!         call ez_mem_free(i)
!
!***  RESTARTS:
!         iezp is written to the restart file and
!         mezp is automatically updated during the restart
!
!         memory allocated using this method will automatically
!         be handled during restart writes and reads
!
!***  IEZP AND MEZP DOCUMENTATION:
!         the equivalent of the ioshl comments in dynai
!         are located in routine ez_mem_allocmchk in atemp.F
!
!***  INITIALIZATION:
!         all arrays initialized to zero in ez_mem_init
!
      integer LENEZMEM  
      parameter (LENEZMEM=1000)
      integer iezp
      integer*8  mezp
      common/iezpcom/iezp(LENEZMEM)
      common/mezpcom/mezp(LENEZMEM)
# 876 "dyn21utan.F" 2 
c
      common/aux2loc/e1(nlq),e2(nlq),d3(nlq),e4(nlq),e5(nlq),e6(nlq),
     1 wzzdt(nlq),wyydt(nlq),wxxdt(nlq),einc(nlq)
      common /aux8cloc/
     & d1(nlq),d2(nlq),d4(nlq),d5(nlq),d6(nlq),
     & dfg11(nlq),dfg21(nlq),dfg31(nlq),dfg12(nlq),dfg22(nlq),
     & dfg32(nlq),dfg13(nlq),dfg23(nlq),dfg33(nlq),stg5(nlq),
     & stg6(nlq),a11(nlq),a12(nlq),a21(nlq),a22(nlq)
      common/aux14loc/
     & sig1(nlq),sig2(nlq),sig3(nlq),sig4(nlq),
     & sig5(nlq),sig6(nlq),epsps(nlq),hsvs(nlq,NHISVAR)
      common/aux19loc/
     1 sign0(nlq),sign1(nlq),sign2(nlq),sign3(nlq),sign4(nlq),
     2 sign5(nlq),sign6(nlq)
      common/aux33loc/
     1 ix1(nlq),ix2(nlq),ix3(nlq),ix4(nlq),ixs(nlq,4),mxt(nlq)
      common/bk36loc/index
      common/bux13loc/ eps(6),sig(6),hsv(NHISVAR),temps(nlq)
      common/failuloc/sieu(nlq),fail(nlq),ifaili(nlq),nfipts(nlq),
     . msgfail(nlq),def_ele_eros(nlq)
      common/frozloc/yhat(nlq,3,4),qloc(nlq,3,3),qmat(nlq,3,3)
      common/hourgloc/ym(nlq),gm(nlq),ifsv(nlq)
      common/shlopt/istrn,istupd_flag,ibelyts,miter
      common/shloptloc/ibelyt
      common/soundloc/ss(nlq),sndsp(nlq),diagm(nlq),sarea(nlq),
     . dxl(nlq)
      common/vect8loc/dsave(nlq,6,6)
c
      common/bk00/numnp,numpc,numlp,neq,ndof,nlcur,numcl,numvc,
     + ndtpts,nelmd,nmmat,numelh,numelb,numels,numelt,numdp,
     + grvity,idirgv,nodspc,nspcor,nusa
      common/bk01/itherm,itemp,ntmp0,ntmp1,itempan,itempdr,itmpe(44)
      common/bk26/begtim,nintcy
      common/bk28/summss,xke,xpe,tt,xte0,erodeke,erodeie
      common/numcpu/ncpu,ncpua,ncpub,lenvec(9)
      common/slcntr/islcnt(21)
      common/subtssloc/dt1siz(nlq)
      common/thropt/itopaz(101)
c
      dimension cm(*),nconstp(*)
      character*(*) eltype
c     dimension eps(6),sig(6),hsv(NHISVAR),temps(nlq)
      dimension es(6,6)
      dimension sigmaold(nlq,6)
      logical failel,failels(nlq),unsym
      dimension qmats(3,3)
c     data temps/nlq*0.0/
c     flag if the tangent stiffness is allowed nonsymmetric
c$omp threadprivate (/vect8loc/)
c$omp threadprivate (/subtssloc/)
c$omp threadprivate (/soundloc/)
c$omp threadprivate (/shloptloc/)
c$omp threadprivate (/hourgloc/)
c$omp threadprivate (/frozloc/)
c$omp threadprivate (/failuloc/)
c$omp threadprivate (/bux13loc/)
c$omp threadprivate (/bk36loc/)
c$omp threadprivate (/aux33loc/)
c$omp threadprivate (/aux19loc/)
c$omp threadprivate (/aux14loc/)
c$omp threadprivate (/aux8cloc/)
c$omp threadprivate (/aux2loc/)
      unsym=is17loc.eq.2
c
c     Note that no temperatures are calculated here
c
      mx=48*(mxt(lft)-1)
c
c     Determining number of requested history variables
c
      no_hsvs=nconstp(mxt(lft))
      if (lenvec(5) .eq.1) no_hsvs=no_hsvs-6
      if (iorien(mt).ne.0) no_hsvs=no_hsvs-2
      if (ihyper(mt).ne.0) no_hsvs=no_hsvs-9
      if (ifipts(mt).lt.0) no_hsvs=no_hsvs-1
c
c     initializing indeces
c
      if (iorien(mt).ne.0) then
        if (ihyper(mt).ne.0) then
          ind_defgrad=1+no_hsvs
          ind_ortho=ind_defgrad+9
        else
          ind_ortho=1+no_hsvs
        endif
        if (ifipts(mt).lt.0) then
          ind_fipts=ind_ortho
          ind_ortho=ind_ortho+1
        endif
        ind_q1=ind_ortho
        ind_q2=ind_ortho+1
        ind_last=ind_q2
      else
        if (ihyper(mt).ne.0) then
          ind_defgrad=1+no_hsvs
          ind_last=ind_defgrad+8
        else
          ind_last=no_hsvs
        endif
        if (ifipts(mt).lt.0) then
          ind_fipts=ind_last+1
          ind_last=ind_last+1
        endif
      endif
c
      if (iorien(mt).ne.0) then
c
c       store element local stresses
c
        if (ihyper(mt).ge.0) then
          do i=lft,llt
            sigmaold(i,1)=sig1(i)
            sigmaold(i,2)=sig2(i)
            sigmaold(i,3)=sig3(i)
            sigmaold(i,4)=sig4(i)
            sigmaold(i,5)=sig5(i)
            sigmaold(i,6)=sig6(i)
          enddo
c
c         transform stresses to material system
c
          do 20 i=lft,llt
          stg5(i)=sig5(i)
          stg6(i)=sig6(i)
          a11(i) =hsvs(i,ind_q1)*sig1(i)-hsvs(i,ind_q2)*sig4(i)
          a12(i) =hsvs(i,ind_q2)*sig1(i)+hsvs(i,ind_q1)*sig4(i)
          a21(i) =hsvs(i,ind_q1)*sig4(i)-hsvs(i,ind_q2)*sig2(i)
          a22(i) =hsvs(i,ind_q2)*sig4(i)+hsvs(i,ind_q1)*sig2(i)
          sig1(i)=hsvs(i,ind_q1)*a11(i)-hsvs(i,ind_q2)*a21(i)
          sig2(i)=hsvs(i,ind_q2)*a12(i)+hsvs(i,ind_q1)*a22(i)
          sig4(i)=hsvs(i,ind_q1)*a12(i)-hsvs(i,ind_q2)*a22(i)
          sig5(i)=hsvs(i,ind_q2)*stg6(i)+hsvs(i,ind_q1)*stg5(i)
          sig6(i)=hsvs(i,ind_q1)*stg6(i)-hsvs(i,ind_q2)*stg5(i)
 20       continue
        endif
c
c       storage of deformation gradient
c
        if (ihyper(mt).gt.0) then
          if11=ind_defgrad
          if21=ind_defgrad+1
          if31=ind_defgrad+2
          if12=ind_defgrad+3
          if22=ind_defgrad+4
          if32=ind_defgrad+5
          if13=ind_defgrad+6
          if23=ind_defgrad+7
          if33=ind_defgrad+8
c
c         transform deformation gradient to material system
c         as F_bar=Q^T*F
c
          do i=lft,llt
c
c           store deformation gradient in element system
c
            dfg11(i)=hsvs(i,if11)
            dfg21(i)=hsvs(i,if21)
            dfg12(i)=hsvs(i,if12)
            dfg22(i)=hsvs(i,if22)
            dfg13(i)=hsvs(i,if13)
            dfg23(i)=hsvs(i,if23)
c
            ftemp=hsvs(i,ind_q1)*hsvs(i,if11)-
     1            hsvs(i,ind_q2)*hsvs(i,if21)
            hsvs(i,if21)=hsvs(i,ind_q2)*hsvs(i,if11)+
     1            hsvs(i,ind_q1)*hsvs(i,if21)
            hsvs(i,if11)=ftemp
            ftemp=hsvs(i,ind_q1)*hsvs(i,if12)-
     1            hsvs(i,ind_q2)*hsvs(i,if22)
            hsvs(i,if22)=hsvs(i,ind_q2)*hsvs(i,if12)+
     1            hsvs(i,ind_q1)*hsvs(i,if22)
            hsvs(i,if12)=ftemp
            ftemp=hsvs(i,ind_q1)*hsvs(i,if13)-
     1            hsvs(i,ind_q2)*hsvs(i,if23)
            hsvs(i,if23)=hsvs(i,ind_q2)*hsvs(i,if13)+
     1            hsvs(i,ind_q1)*hsvs(i,if23)
            hsvs(i,if13)=ftemp
          enddo
c
c       storage of deformation gradient
c
        else if (ihyper(mt).lt.0) then
          if11=ind_defgrad
          if21=ind_defgrad+1
          if31=ind_defgrad+2
          if12=ind_defgrad+3
          if22=ind_defgrad+4
          if32=ind_defgrad+5
          if13=ind_defgrad+6
          if23=ind_defgrad+7
          if33=ind_defgrad+8
c
c         transform deformation gradient to material system
c         as F_bar=F*Q
c
          do i=lft,llt
c
c           store deformation gradient in element system
c
            dfg11(i)=hsvs(i,if11)
            dfg21(i)=hsvs(i,if21)
            dfg31(i)=hsvs(i,if31)
            dfg12(i)=hsvs(i,if12)
            dfg22(i)=hsvs(i,if22)
            dfg32(i)=hsvs(i,if32)
c
            ftemp=hsvs(i,ind_q1)*hsvs(i,if11)-
     1            hsvs(i,ind_q2)*hsvs(i,if12)
            hsvs(i,if12)=hsvs(i,ind_q2)*hsvs(i,if11)+
     1            hsvs(i,ind_q1)*hsvs(i,if12)
            hsvs(i,if11)=ftemp
            ftemp=hsvs(i,ind_q1)*hsvs(i,if21)-
     1            hsvs(i,ind_q2)*hsvs(i,if22)
            hsvs(i,if22)=hsvs(i,ind_q2)*hsvs(i,if21)+
     1            hsvs(i,ind_q1)*hsvs(i,if22)
            hsvs(i,if21)=ftemp
            ftemp=hsvs(i,ind_q1)*hsvs(i,if31)-
     1            hsvs(i,ind_q2)*hsvs(i,if32)
            hsvs(i,if32)=hsvs(i,ind_q2)*hsvs(i,if31)+
     1            hsvs(i,ind_q1)*hsvs(i,if32)
            hsvs(i,if31)=ftemp
          enddo
        endif
      endif
c
c     memory pointer for extra memory data
      lcma=ncma+nmmat+ia(ncma+mxt(lft)-1)-1
c
c     vector parameter
c
      ivect=ivectr(mt)
c
      mte40=mt-40
c
      if (ivect.eq.0) then
c
c       scalar utan
c
        do 120 i=lft,llt
c
c       gathering of variables
c
        index=i
        dt1   =dt1siz(i)
        eps(1)=d1(i)
        eps(2)=d2(i)
        eps(3)=d3(i)
        eps(4)=d4(i)
        eps(5)=d5(i)
        eps(6)=d6(i)
        sig(1)=sig1(i)
        sig(2)=sig2(i)
        sig(3)=sig3(i)
        sig(4)=sig4(i)
        sig(5)=sig5(i)
        sig(6)=sig6(i)
        epsp=epsps(i)
        temper=temps(i)
        failel=.false.
        if (ifipts(mt).lt.0) failel=hsvs(i,ind_fipts).ne.0.
        if (no_hsvs.gt.0) then
          do j=1,no_hsvs
            hsv(j)=hsvs(i,j)
          enddo
        endif
        if (ihyper(mt).ne.0) then
          do j=1,9
            hsv(no_hsvs+j)=hsvs(i,ind_defgrad-1+j)
          enddo
          if (iabs(ihyper(mt)).eq.3) then
             do k=1,3
                do j=1,3
                   qmats(j,k)=qmat(i,j,k)
                enddo
             enddo
          endif
        endif
c
c       setting material tangent modulus to = 0
c
        do k=1,6
          do j=1,6
            es(j,k)=0.
          enddo
        enddo
c
c       call user developed subroutines here
c
        go to (41,42,43,44,45,46,47,48,49,50), mte40
 41    call utan41 (cm(mx+1),eps,sig,epsp,hsv,dt1,unsym,capa,eltype,tt,
     .   temper,es,a(islcnt(16)),i_mem(mezp(34)),failel,a(lcma),qmats)
        go to 60
 42    call utan42 (cm(mx+1),eps,sig,epsp,hsv,dt1,unsym,capa,eltype,tt,
     .   temper,es,a(islcnt(16)),i_mem(mezp(34)),failel,a(lcma),qmats)
        go to 60
 43    call utan43 (cm(mx+1),eps,sig,epsp,hsv,dt1,unsym,capa,eltype,tt,
     .   temper,es,a(islcnt(16)),i_mem(mezp(34)),failel,a(lcma),qmats)
        go to 60
 44    call utan44 (cm(mx+1),eps,sig,epsp,hsv,dt1,unsym,capa,eltype,tt,
     .   temper,es,a(islcnt(16)),i_mem(mezp(34)),failel,a(lcma),qmats)
        go to 60
 45    call utan45 (cm(mx+1),eps,sig,epsp,hsv,dt1,unsym,capa,eltype,tt,
     .   temper,es,a(islcnt(16)),i_mem(mezp(34)),failel,a(lcma),qmats)
        go to 60
 46    call utan46 (cm(mx+1),eps,sig,epsp,hsv,dt1,unsym,capa,eltype,tt,
     .   temper,es,a(islcnt(16)),i_mem(mezp(34)),failel,a(lcma),qmats)
        go to 60
 47    call utan47 (cm(mx+1),eps,sig,epsp,hsv,dt1,unsym,capa,eltype,tt,
     .   temper,es,a(islcnt(16)),i_mem(mezp(34)),failel,a(lcma),qmats)
        go to 60
 48    call utan48 (cm(mx+1),eps,sig,epsp,hsv,dt1,unsym,capa,eltype,tt,
     .   temper,es,a(islcnt(16)),i_mem(mezp(34)),failel,a(lcma),qmats)
        go to 60
 49    call utan49 (cm(mx+1),eps,sig,epsp,hsv,dt1,unsym,capa,eltype,tt,
     .   temper,es,a(islcnt(16)),i_mem(mezp(34)),failel,a(lcma),qmats)
        go to 60
 50    call utan50 (cm(mx+1),eps,sig,epsp,hsv,dt1,unsym,capa,eltype,tt,
     .   temper,es,a(islcnt(16)),i_mem(mezp(34)),failel,a(lcma),qmats)
c
c       scattering material tangent modulus
c
 60     do k=1,6
          do j=1,6
           dsave(i,j,k)=es(j,k)
         enddo
        enddo
 120    continue
c
c     vector utan
c
      else
c
c       setting material tangent modulus to = 0
c
        do k=1,6
          do j=1,6
            do i=lft,llt
              dsave(i,j,k)=0.
            enddo
          enddo
        enddo
c
        if (ifipts(mt).ge.0) then
          do i=lft,llt
            failels(i)=.false.
          enddo
        else
          do i=lft,llt
            failels(i)=hsvs(i,ind_fipts).ne.0.
          enddo
        endif
c
c       call user developed routines here
c       first history variable is the one requested
c
        if (mt.eq.41) then
          call utan41v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,unsym,lft,llt,
     .     dt1siz,capa,eltype,tt,temps,dsave,nlq,a(islcnt(16)),
     .     i_mem(mezp(34)),failels,
     .     a(lcma),qmat)
        elseif (mt.eq.42) then
          call utan42v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,unsym,lft,llt,
     .     dt1siz,capa,eltype,tt,temps,dsave,nlq,a(islcnt(16)),
     .     i_mem(mezp(34)),failels,
     .     a(lcma),qmat)
        elseif (mt.eq.43) then
          call utan43v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,unsym,lft,llt,
     .     dt1siz,capa,eltype,tt,temps,dsave,nlq,a(islcnt(16)),
     .     i_mem(mezp(34)),failels,
     .     a(lcma),qmat)
        elseif (mt.eq.44) then
          call utan44v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,unsym,lft,llt,
     .     dt1siz,capa,eltype,tt,temps,dsave,nlq,a(islcnt(16)),
     .     i_mem(mezp(34)),failels,
     .     a(lcma),qmat)
        elseif (mt.eq.45) then
          call utan45v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,unsym,lft,llt,
     .     dt1siz,capa,eltype,tt,temps,dsave,nlq,a(islcnt(16)),
     .     i_mem(mezp(34)),failels,
     .     a(lcma),qmat)
        elseif (mt.eq.46) then
          call utan46v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,unsym,lft,llt,
     .     dt1siz,capa,eltype,tt,temps,dsave,nlq,a(islcnt(16)),
     .     i_mem(mezp(34)),failels,
     .     a(lcma),qmat)
        elseif (mt.eq.47) then
          call utan47v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,unsym,lft,llt,
     .     dt1siz,capa,eltype,tt,temps,dsave,nlq,a(islcnt(16)),
     .     i_mem(mezp(34)),failels,
     .     a(lcma),qmat)
        elseif (mt.eq.48) then
          call utan48v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,unsym,lft,llt,
     .     dt1siz,capa,eltype,tt,temps,dsave,nlq,a(islcnt(16)),
     .     i_mem(mezp(34)),failels,
     .     a(lcma),qmat)
        elseif (mt.eq.49) then
          call utan49v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,unsym,lft,llt,
     .     dt1siz,capa,eltype,tt,temps,dsave,nlq,a(islcnt(16)),
     .     i_mem(mezp(34)),failels,
     .     a(lcma),qmat)
        elseif (mt.eq.50) then
          call utan50v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,unsym,lft,llt,
     .     dt1siz,capa,eltype,tt,temps,dsave,nlq,a(islcnt(16)),
     .     i_mem(mezp(34)),failels,
     .     a(lcma),qmat)
        elseif (mt.eq.281) then
          call utan281v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,
     .     dt1siz,capa,eltype,tt,temps,dsave,nlq,a(islcnt(16)),failels,
     .     a(lcma))
        elseif (mt.eq.282) then
          call utan282v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,
     .     dt1siz,capa,eltype,tt,temps,dsave,nlq,a(islcnt(16)),failels,
     .     a(lcma))
        elseif (mt.eq.283) then
          call utan283v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,
     .     dt1siz,capa,eltype,tt,temps,dsave,nlq,a(islcnt(16)),failels,
     .     a(lcma))
        elseif (mt.eq.284) then
          call utan284v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,
     .     dt1siz,capa,eltype,tt,temps,dsave,nlq,a(islcnt(16)),failels,
     .     a(lcma))
        elseif (mt.eq.286) then
          call utan286v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,
     .     dt1siz,capa,eltype,tt,temps,dsave,nlq,a(islcnt(16)),failels,
     .     a(lcma))
        elseif (mt.eq.287) then
          call utan287v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,
     .     dt1siz,capa,eltype,tt,temps,dsave,nlq,a(islcnt(16)),failels,
     .     a(lcma))
       elseif (mt.eq.289) then
          call utan289v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .     sig1,sig2,sig3,sig4,
     .     sig5,sig6,epsps,hsvs,
     .     lft,llt,dt1siz,capa,eltype,tt,temps,dsave,nlq,crv,failels,
     .     a(lcma))
        endif
      endif
c
      if (iorien(mt).ne.0) then
c
c       transform tangent stiffness to element system
c
        if (ihyper(mt).ge.0) then
          call transform44s(hsvs(1,ind_q1),hsvs(1,ind_q2),lft,llt)
c
c         restore element local stresses
c
          do i=lft,llt
            sig1(i)=sigmaold(i,1)
            sig2(i)=sigmaold(i,2)
            sig3(i)=sigmaold(i,3)
            sig4(i)=sigmaold(i,4)
            sig5(i)=sigmaold(i,5)
            sig6(i)=sigmaold(i,6)
          enddo
        endif
c
c       restore deformation gradient in element system
c
        if (ihyper(mt).ne.0) then
          do i=lft,llt
            hsvs(i,if11)=dfg11(i)
            hsvs(i,if21)=dfg21(i)
            hsvs(i,if12)=dfg12(i)
            hsvs(i,if22)=dfg22(i)
            hsvs(i,if13)=dfg13(i)
            hsvs(i,if23)=dfg23(i)
          enddo
        endif
      endif
c
      return
      end
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c
c User Material Model: Series Version of the Tangent Stiffness
c
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
      subroutine utan41(cm,eps,sig,epsp,hsv,dt1,unsym,capa,etype,tt,
     1 temper,es,crv,nnpcrv,failel,cma,qmat)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      include 'nlqparm'
      dimension cm(*),eps(*),sig(*),hsv(*),crv(lq1,2,*),cma(*)
      integer nnpcrv(*)
      dimension es(6,*),qmat(3,3)
      logical failel,unsym
      character*5 etype
c
      factor=1.
      if (failel) factor=1.e-8
c
      g=factor*.5*abs(cm(1))/(1.+cm(2))
      b=factor*abs(cm(1))/3./(1.-2.*cm(2))
      bg23=b-2.*g/3.
      bg43=b+4.*g/3.
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
      es(4,4)=g
      es(5,5)=g
      es(6,6)=g
c
      return
      end
      subroutine utan42(cm,eps,sig,epsp,hsv,dt1,unsym,capa,etype,tt,
     1 temper,es,crv,nnpcrv,failel,cma,qmat)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      include 'nlqparm'
      dimension cm(*),eps(*),sig(*),hsv(*),crv(lq1,2,*),cma(*)
      integer nnpcrv(*)
      dimension es(6,*),qmat(3,3)
      logical failel,unsym
      character*5 etype
c
      return
      end
      subroutine utan43(cm,eps,sig,epsp,hsv,dt1,unsym,capa,etype,tt,
     1 temper,es,crv,nnpcrv,failel,cma,qmat)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      include 'nlqparm'
      dimension cm(*),eps(*),sig(*),hsv(*),crv(lq1,2,*),cma(*)
      integer nnpcrv(*)
      dimension es(6,*),qmat(3,3)
      logical failel,unsym
      character*5 etype
c
      return
      end
      subroutine utan44(cm,eps,sig,epsp,hsv,dt1,unsym,capa,etype,tt,
     1 temper,es,crv,nnpcrv,failel,cma,qmat)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      include 'nlqparm'
      dimension cm(*),eps(*),sig(*),hsv(*),crv(lq1,2,*),cma(*)
      integer nnpcrv(*)
      dimension es(6,*),qmat(3,3)
      logical failel,unsym
      character*5 etype
c
      PARAMETER NHSV=300
      IDX=NHSV-4
      DO I=1,6
        DO J=1,6
          POS=IDX-((I-1)*6+(J-1))
          ES(I,J)=HSV(POS)
        ENDDO
      ENDDO
      return
      end
      subroutine utan45(cm,eps,sig,epsp,hsv,dt1,unsym,capa,etype,tt,
     1 temper,es,crv,nnpcrv,failel,cma,qmat)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      include 'nlqparm'
      dimension cm(*),eps(*),sig(*),hsv(*)
      dimension es(6,*),crv(lq1,2,*),cma(*),qmat(3,3)
      integer nnpcrv(*)
      logical failel,unsym
      character*5 etype
c
      logical usemodule,usemetal
c
c     See comments in subroutine umat45 for use of *MODULE
c
      usemodule=.false.
      if (usemodule) then
        usemetal=.false.
        if (usemetal) then
          call metaltan(cm,eps,sig,epsp,hsv,dt1,capa,etype,time,temp,
     .          failel,crv,nnpcrv,es)
          return
        endif
      endif
c
c     no history variables, NHV=0
c     deformation gradient stored in hsv(1),...,hsv(9)
c
c     compute jacobian
c
      detf=hsv(1)*(hsv(5)*hsv(9)-hsv(6)*hsv(8))
     1     -hsv(2)*(hsv(4)*hsv(9)-hsv(6)*hsv(7))
     2     +hsv(3)*(hsv(4)*hsv(8)-hsv(5)*hsv(7))
c
c     compute lame parameters
c
      xlambda=cm(1)*cm(2)/((1.+cm(2))*(1.-2.*cm(2)))
      xmu=.5*cm(1)/(1.+cm(2))
c
c     compute tangent stiffness
c     same for both shells and solids
c
      detf=max(detf,1.e-8)
      detfinv=1./detf
      dmu=xmu-xlambda*log(detf)
      es(1,1)=detfinv*(xlambda+2.*dmu)
      es(2,2)=detfinv*(xlambda+2.*dmu)
      es(3,3)=detfinv*(xlambda+2.*dmu)
      es(4,4)=detfinv*dmu
      es(5,5)=detfinv*dmu
      es(6,6)=detfinv*dmu
      es(2,1)=detfinv*xlambda
      es(3,2)=detfinv*xlambda
      es(3,1)=detfinv*xlambda
      es(1,2)=es(2,1)
      es(2,3)=es(3,2)
      es(1,3)=es(3,1)
c
      return
      end
      subroutine utan46(cm,eps,sig,epsp,hsv,dt1,unsym,capa,etype,tt,
     1 temper,es,crv,nnpcrv,failel,cma,qmat)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      include 'nlqparm'
      dimension cm(*),eps(*),sig(*),hsv(*),crv(lq1,2,*),cma(*)
      integer nnpcrv(*)
      dimension es(6,*),qmat(3,3)
      logical failel,unsym
      character*5 etype
c
      return
      end
      subroutine utan47(cm,eps,sig,epsp,hsv,dt1,unsym,capa,etype,tt,
     1 temper,es,crv,nnpcrv,failel,cma,qmat)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      include 'nlqparm'
      dimension cm(*),eps(*),sig(*),hsv(*),crv(lq1,2,*),cma(*)
      integer nnpcrv(*)
      dimension es(6,*),qmat(3,3)
      logical failel,unsym
      character*5 etype
c
      return
      end
      subroutine utan48(cm,eps,sig,epsp,hsv,dt1,unsym,capa,etype,tt,
     1 temper,es,crv,nnpcrv,failel,cma,qmat)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      include 'nlqparm'
      dimension cm(*),eps(*),sig(*),hsv(*),crv(lq1,2,*),cma(*)
      integer nnpcrv(*)
      dimension es(6,*),qmat(3,3)
      logical failel,unsym
      character*5 etype
c
      return
      end
      subroutine utan49(cm,eps,sig,epsp,hsv,dt1,unsym,capa,etype,tt,
     1 temper,es,crv,nnpcrv,failel,cma,qmat)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      include 'nlqparm'
      dimension cm(*),eps(*),sig(*),hsv(*),crv(lq1,2,*),cma(*)
      integer nnpcrv(*)
      dimension es(6,*),qmat(3,3)
      logical failel,unsym
      character*5 etype
c
      return
      end
      subroutine utan50(cm,eps,sig,epsp,hsv,dt1,unsym,capa,etype,tt,
     1 temper,es,crv,nnpcrv,failel,cma,qmat)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      include 'nlqparm'
      dimension cm(*),eps(*),sig(*),hsv(*),crv(lq1,2,*),cma(*)
      integer nnpcrv(*)
      dimension es(6,*),qmat(3,3)
      logical failel,unsym
      character*5 etype
      return
      end
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c
c User Material Model: Vectorized Version of the Tangent Stiffness
c
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
      subroutine utan41v(cm,d1,d2,d3,d4,d5,d6,sig1,sig2,
     . sig3,sig4,sig5,sig6,epsps,hsvs,unsym,lft,llt,dt1siz,capa,
     . etype,tt,temps,dsave,nlqa,crv,nnpcrv,failels,cma,qmat)
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
      dimension d1(*),d2(*),d3(*),d4(*),d5(*),d6(*)
      dimension sig1(*),sig2(*),sig3(*),sig4(*),sig5(*),sig6(*)
      dimension epsps(*),hsvs(nlq,*),dt1siz(*),cm(*),qmat(nlq,3,3)
      dimension temps(*),dsave(nlq,6,*),crv(lq1,2,*),cma(*)
      integer nnpcrv(*)
      logical failels(*),unsym
      character*5 etype
c
      dimension sig(6),eps(6),hsv(NHISVAR),es(6,6)
      logical failel
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
        do k=1,6
          do j=1,6
            es(j,k)=0.
          enddo
        enddo
c
        failel=failels(i)
c
        call utan41(cm,eps,sig,epsps(i),hsv,dt1siz(i),unsym,capa,etype,
     1       tt,temps(i),es,crv,nnpcrv,failel,cma,0)
c
        do k=1,6
          do j=1,6
            dsave(i,j,k)=es(j,k)
          enddo
        enddo
      enddo
c
      return
      end
      subroutine utan42v(cm,d1,d2,d3,d4,d5,d6,sig1,sig2,
     . sig3,sig4,sig5,sig6,epsps,hsvs,unsym,lft,llt,dt1siz,capa,
     . etype,tt,temps,dsave,nlqa,crv,nnpcrv,failels,cma,qmat)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      include 'nlqparm'
      dimension d1(*),d2(*),d3(*),d4(*),d5(*),d6(*)
      dimension sig1(*),sig2(*),sig3(*),sig4(*),sig5(*),sig6(*)
      dimension epsps(*),hsvs(nlq,*),dt1siz(*),cm(*),qmat(nlq,3,3)
      dimension temps(*),dsave(nlq,6,*),crv(lq1,2,*),cma(*)
      integer nnpcrv(*)
      logical failels(*),unsym
      character*5 etype
c
      return
      end
      subroutine utan43v(cm,d1,d2,d3,d4,d5,d6,sig1,sig2,
     . sig3,sig4,sig5,sig6,epsps,hsvs,unsym,lft,llt,dt1siz,capa,
     . etype,tt,temps,dsave,nlqa,crv,nnpcrv,failels,cma,qmat)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      include 'nlqparm'
      dimension d1(*),d2(*),d3(*),d4(*),d5(*),d6(*)
      dimension sig1(*),sig2(*),sig3(*),sig4(*),sig5(*),sig6(*)
      dimension epsps(*),hsvs(nlq,*),dt1siz(*),cm(*),qmat(nlq,3,3)
      dimension temps(*),dsave(nlq,6,*),crv(lq1,2,*),cma(*)
      integer nnpcrv(*)
      logical failels(*),unsym
      character*5 etype
c
      return
      end
      subroutine utan44v(cm,d1,d2,d3,d4,d5,d6,sig1,sig2,
     . sig3,sig4,sig5,sig6,epsps,hsvs,unsym,lft,llt,dt1siz,capa,
     . etype,tt,temps,dsave,nlqa,crv,nnpcrv,failels,cma,qmat)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      include 'nlqparm'
      dimension d1(*),d2(*),d3(*),d4(*),d5(*),d6(*)
      dimension sig1(*),sig2(*),sig3(*),sig4(*),sig5(*),sig6(*)
      dimension epsps(*),hsvs(nlq,*),dt1siz(*),cm(*),qmat(nlq,3,3)
      dimension temps(*),dsave(nlq,6,*),crv(lq1,2,*),cma(*)
      integer nnpcrv(*)
      logical failels(*),unsym
      character*5 etype
c
      return
      end
      subroutine utan45v(cm,d1,d2,d3,d4,d5,d6,sig1,sig2,
     . sig3,sig4,sig5,sig6,epsps,hsvs,unsym,lft,llt,dt1siz,capa,
     . etype,tt,temps,dsave,nlqa,crv,nnpcrv,failels,cma,qmat)
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
      dimension d1(*),d2(*),d3(*),d4(*),d5(*),d6(*)
      dimension sig1(*),sig2(*),sig3(*),sig4(*),sig5(*),sig6(*)
      dimension epsps(*),hsvs(nlq,*),dt1siz(*),cm(*),qmat(nlq,3,3)
      dimension temps(*),dsave(nlq,6,*),crv(lq1,2,*),cma(*)
      integer nnpcrv(*)
      logical failels(*),unsym
      character*5 etype
c
      dimension sig(6),eps(6),hsv(NHISVAR),es(6,6)
      logical failel
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
        do k=1,6
          do j=1,6
            es(j,k)=0.
          enddo
        enddo
c
        failel=failels(i)
c
        call utan45(cm,eps,sig,epsps(i),hsv,dt1siz(i),unsym,capa,etype,
     1       tt,temps(i),es,crv,nnpcrv,failel,cma,0)
c
        do k=1,6
          do j=1,6
            dsave(i,j,k)=es(j,k)
          enddo
        enddo
      enddo
c
      return
      end
      subroutine utan46v(cm,d1,d2,d3,d4,d5,d6,sig1,sig2,
     . sig3,sig4,sig5,sig6,epsps,hsvs,unsym,lft,llt,dt1siz,capa,
     . etype,tt,temps,dsave,nlqa,crv,nnpcrv,failels,cma,qmat)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      include 'nlqparm'
      dimension d1(*),d2(*),d3(*),d4(*),d5(*),d6(*)
      dimension sig1(*),sig2(*),sig3(*),sig4(*),sig5(*),sig6(*)
      dimension epsps(*),hsvs(nlq,*),dt1siz(*),cm(*),qmat(nlq,3,3)
      dimension temps(*),dsave(nlq,6,*),crv(lq1,2,*),cma(*)
      integer nnpcrv(*)
      logical failels(*),unsym
      character*5 etype
c
      return
      end
      subroutine utan47v(cm,d1,d2,d3,d4,d5,d6,sig1,sig2,
     . sig3,sig4,sig5,sig6,epsps,hsvs,unsym,lft,llt,dt1siz,capa,
     . etype,tt,temps,dsave,nlqa,crv,nnpcrv,failels,cma,qmat)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      include 'nlqparm'
      dimension d1(*),d2(*),d3(*),d4(*),d5(*),d6(*)
      dimension sig1(*),sig2(*),sig3(*),sig4(*),sig5(*),sig6(*)
      dimension epsps(*),hsvs(nlq,*),dt1siz(*),cm(*),qmat(nlq,3,3)
      dimension temps(*),dsave(nlq,6,*),crv(lq1,2,*),cma(*)
      integer nnpcrv(*)
      logical failels(*),unsym
      character*5 etype
c
      return
      end
      subroutine utan48v(cm,d1,d2,d3,d4,d5,d6,sig1,sig2,
     . sig3,sig4,sig5,sig6,epsps,hsvs,unsym,lft,llt,dt1siz,capa,
     . etype,tt,temps,dsave,nlqa,crv,nnpcrv,failels,cma,qmat)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      include 'nlqparm'
      dimension d1(*),d2(*),d3(*),d4(*),d5(*),d6(*)
      dimension sig1(*),sig2(*),sig3(*),sig4(*),sig5(*),sig6(*)
      dimension epsps(*),hsvs(nlq,*),dt1siz(*),cm(*),qmat(nlq,3,3)
      dimension temps(*),dsave(nlq,6,*),crv(lq1,2,*),cma(*)
      integer nnpcrv(*)
      logical failels(*),unsym
      character*5 etype
c
      return
      end
      subroutine utan49v(cm,d1,d2,d3,d4,d5,d6,sig1,sig2,
     . sig3,sig4,sig5,sig6,epsps,hsvs,unsym,lft,llt,dt1siz,capa,
     . etype,tt,temps,dsave,nlqa,crv,nnpcrv,failels,cma,qmat)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      include 'nlqparm'
      dimension d1(*),d2(*),d3(*),d4(*),d5(*),d6(*)
      dimension sig1(*),sig2(*),sig3(*),sig4(*),sig5(*),sig6(*)
      dimension epsps(*),hsvs(nlq,*),dt1siz(*),cm(*),qmat(nlq,3,3)
      dimension temps(*),dsave(nlq,6,*),crv(lq1,2,*),cma(*)
      integer nnpcrv(*)
      logical failels(*),unsym
      character*5 etype
c
      return
      end
      subroutine utan50v(cm,d1,d2,d3,d4,d5,d6,sig1,sig2,
     . sig3,sig4,sig5,sig6,epsps,hsvs,unsym,lft,llt,dt1siz,capa,
     . etype,tt,temps,dsave,nlqa,crv,nnpcrv,failels,cma,qmat)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      include 'nlqparm'
      dimension d1(*),d2(*),d3(*),d4(*),d5(*),d6(*)
      dimension sig1(*),sig2(*),sig3(*),sig4(*),sig5(*),sig6(*)
      dimension epsps(*),hsvs(nlq,*),dt1siz(*),cm(*),qmat(nlq,3,3)
      dimension temps(*),dsave(nlq,6,*),crv(lq1,2,*),cma(*)
      integer nnpcrv(*)
      logical failels(*),unsym
      character*5 etype
c
      return
      end
