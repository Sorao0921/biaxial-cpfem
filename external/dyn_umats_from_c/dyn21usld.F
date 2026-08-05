# 1 "dyn21usld.F"
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





# 2 "dyn21usld.F" 2 

ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c
c User Solid Elements
c two main driver subroutines: usrsld & usldmass
c
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
      subroutine usrsld(mtype,cm,u,v,fv,x,auxvec,eosp,tnew,fval,ener,
     . npc,pld,hgforc,ies,bqs,nhxbwp,hgener,mte,nmtcon,lav,ihg,
     . nnm2,lft,llt,ibq,nes,idmp,kp,nnm1,mxe,iehgfg,strains,rhssav,
     . volfrc,cmaux,eig,eign,idam,damag,lpwphv,rots,hges,lochvh,ithxpid,
     . ietyp,cmusr,xipn,lochvq,auxmeh)
# 17

      use userinterface
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     main routine for the user defined solid
c
      include 'nlqparm'
      include 'adjcom.inc'
c     include 'alecom.inc'
      include 'alemisc.inc'
      include 'implicit1.inc'
      include 'memaia.inc'
      include 'nikcpl.inc'
      include 'nhisparm.inc'
      include 'shlioc.inc'
      include 'subcyc.inc'
      include 'umatss.inc'
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
# 41 "dyn21usld.F" 2 
# 1 ".\bk08.inc" 1 
      integer n4f,n4g,n4h,n7a,nusir,                                    
     & mpusr,mpubr,n4i,n4j,n4k,n4l,n4m,n4n
      common/bk08/n4f,n4g,n4h,n7a,nusir,                                
     & mpusr,mpubr,n4i,n4j,n4k,n4l,n4m,n4n
# 42 "dyn21usld.F" 2 
# 1 ".\bk13.inc" 1 
      integer lc0,lc1h,lc1b,lc1t,lc2,lc3,lc4,lc5,lc6,lc6e,lc6f,lc9,     
     & lc10,lc11,lc12,lc13,lc14,lc15,lc16,lc17,lc18,lb0,lb1,lb2,        
     & lc7a,lc7b,lc7c,lc7d,lc7e,lc7f,lc7g,lc7h,lc7i,lc7j,lc7k,lc7l,     
     & lc7t,lc7x,lc6g,lc6h
      common/bk13/lc0,lc1h,lc1b,lc1t,lc2,lc3,lc4,lc5,lc6,lc6e,lc6f,lc9, 
     & lc10,lc11,lc12,lc13,lc14,lc15,lc16,lc17,lc18,lb0,lb1,lb2,        
     & lc7a,lc7b,lc7c,lc7d,lc7e,lc7f,lc7g,lc7h,lc7i,lc7j,lc7k,lc7l,     
     & lc7t,lc7x,lc6g,lc6h
# 43 "dyn21usld.F" 2 
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

# 44 "dyn21usld.F" 2 
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
# 45 "dyn21usld.F" 2 
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
# 46 "dyn21usld.F" 2 
# 1 ".\sorter.inc" 1 
c$omp threadprivate (/bki04iloc/)
c$omp threadprivate (/bki03rloc/)
c$omp threadprivate (/bki03iloc/)
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
# 47 "dyn21usld.F" 2 
c
      common/hour12loc/dmgvals(nlq,2)
      common/aux2loc/
     & d1(nlq),d2(nlq),d3(nlq),d4(nlq),d5(nlq),d6(nlq),
     & wzzdt(nlq),wyydt(nlq),wxxdt(nlq),einc(nlq)
      common/aux8loc/
     & x1(nlq),x2(nlq),x3(nlq),x4(nlq),
     & x5(nlq),x6(nlq),x7(nlq),x8(nlq),
     & y1(nlq),y2(nlq),y3(nlq),y4(nlq),
     & y5(nlq),y6(nlq),y7(nlq),y8(nlq),
     & z1(nlq),z2(nlq),z3(nlq),z4(nlq),
     & z5(nlq),z6(nlq),z7(nlq),z8(nlq)
      common/aux9loc/vlrho(nlq),voln(nlq)
      common/aux10loc/
     1 px1(nlq),px2(nlq),px3(nlq),px4(nlq),
     & px5(nlq),px6(nlq),px7(nlq),px8(nlq),
     2 py1(nlq),py2(nlq),py3(nlq),py4(nlq),
     & py5(nlq),py6(nlq),py7(nlq),py8(nlq),
     3 pz1(nlq),pz2(nlq),pz3(nlq),pz4(nlq),
     & pz5(nlq),pz6(nlq),pz7(nlq),pz8(nlq),
     4 vx1(nlq),vx2(nlq),vx3(nlq),vx4(nlq),
     5 vx5(nlq),vx6(nlq),vx7(nlq),vx8(nlq),
     6 vy1(nlq),vy2(nlq),vy3(nlq),vy4(nlq),
     7 vy5(nlq),vy6(nlq),vy7(nlq),vy8(nlq),
     8 vz1(nlq),vz2(nlq),vz3(nlq),vz4(nlq),
     9 vz5(nlq),vz6(nlq),vz7(nlq),vz8(nlq)
      common/aux13loc/
     1 p11(nlq),p12(nlq),p13(nlq),p14(nlq),
     2 p15(nlq),p16(nlq),p17(nlq),p18(nlq),
     3 p21(nlq),p22(nlq),p23(nlq),p24(nlq),
     4 p25(nlq),p26(nlq),p27(nlq),p28(nlq),
     5 p31(nlq),p32(nlq),p33(nlq),p34(nlq),
     6 p35(nlq),p36(nlq),p37(nlq),p38(nlq),
     . hgforq(12,nlq)
      common/aux14loc/ax(nlq,7+NHISVAR)
      common/aux15loc/qp(nlq),specen(nlq),dvol(nlq),volold(nlq)
      common/aux16cntloc/idmgmdl
      common/aux18loc/dd(nlq),dfe(nlq),ddq(nlq)
      common/aux33loc/ix1(nlq),ix2(nlq),ix3(nlq),ix4(nlq),ix5(nlq),
     1 ix6(nlq),ix7(nlq),ix8(nlq),mxt(nlq)
      common/aux35loc/rhoa(nlq),cb(nlq)
      common/aux37loc/ad(nlq),vol3rd(nlq),qx(nlq),dtx(nlq)
      common/aux43loc/xm(nlq),p(nlq),xmua(nlq)
      common/bel8loc/uehisv(nlq,2*(NHISVUE+45))
      common/bel8aloc/iuehup(nlq,2*(NHISVUE+45))
      common/frozloc/vfroz,tfroz,
     . vfrzn(nlq),tfrzn(nlq),dtold(nlq),
     1 x1f(nlq),x2f(nlq),x3f(nlq),x4f(nlq),
     1 x5f(nlq),x6f(nlq),x7f(nlq),x8f(nlq),
     1 y1f(nlq),y2f(nlq),y3f(nlq),y4f(nlq),
     2 y5f(nlq),y6f(nlq),y7f(nlq),y8f(nlq),
     2 z1f(nlq),z2f(nlq),z3f(nlq),z4f(nlq),
     3 z5f(nlq),z6f(nlq),z7f(nlq),z8f(nlq)
      common/numcpuloc/lenvec8,lenvech
      common/prescloc/voltot(nlq)
      common/rayleiloc/betav
      common/scr01loc/
     1 spx1(nlq),spx2(nlq),spx3(nlq),spx4(nlq),
     & spx5(nlq),spx6(nlq),spx7(nlq),spx8(nlq),
     2 spy1(nlq),spy2(nlq),spy3(nlq),spy4(nlq),
     & spy5(nlq),spy6(nlq),spy7(nlq),spy8(nlq),
     3 spz1(nlq),spz2(nlq),spz3(nlq),spz4(nlq),
     & spz5(nlq),spz6(nlq),spz7(nlq),spz8(nlq),
     & sx1(nlq),sx2(nlq),sx3(nlq),sx4(nlq),
     & sx5(nlq),sx6(nlq),sx7(nlq),sx8(nlq),
     & sy1(nlq),sy2(nlq),sy3(nlq),sy4(nlq),
     & sy5(nlq),sy6(nlq),sy7(nlq),sy8(nlq),
     & sz1(nlq),sz2(nlq),sz3(nlq),sz4(nlq),
     & sz5(nlq),sz6(nlq),sz7(nlq),sz8(nlq),volm(nlq)
      common/shloptloc/ibelyt
      common/subtssloc/dt1siz(nlq)
      common/vect2loc/vlinc(nlq),pmean(nlq)
      common/vect8loc/dsave(nlq,6,6)
      common/bel7loc/ixsld(nlq,8,5),ixshl(nlq,4,5)
     .,bmtrx(nlq,3,3,8*(3+NXDOFUE)),
     . cmtrx(nlq,3,3,8*(3+NXDOFUE)),xdof(nlq,8,NXDOFUE),
     . dxdof(nlq,8,NXDOFUE),xhdof(nlq,8,NXDOFUE),
     . bvec(nlq,8*(3+NXDOFUE)),cvec(nlq,8*(3+NXDOFUE)),
     . frc(nlq,8*(3+NXDOFUE)),
     . stiff(nlq,64*(3+NXDOFUE)*(3+NXDOFUE)),
     . sigv(nlq),
     . gmtrx(nlq,3,3),hmtrx(nlq,3,3),cvltot(nlq),
     . xh1(nlq),xh2(nlq),xh3(nlq),xh4(nlq),
     . xh5(nlq),xh6(nlq),xh7(nlq),xh8(nlq),
     . yh1(nlq),yh2(nlq),yh3(nlq),yh4(nlq),
     . yh5(nlq),yh6(nlq),yh7(nlq),yh8(nlq),
     . zh1(nlq),zh2(nlq),zh3(nlq),zh4(nlq),
     . zh5(nlq),zh6(nlq),zh7(nlq),zh8(nlq),
     . hl11(nlq),hl12(nlq),hl13(nlq),hl21(nlq),hl22(nlq),
     . hl23(nlq),hl31(nlq),hl32(nlq),hl33(nlq),
     . xx1(nlq),xx2(nlq),xx3(nlq),xx4(nlq),
     . xx5(nlq),xx6(nlq),xx7(nlq),xx8(nlq),
     . yy1(nlq),yy2(nlq),yy3(nlq),yy4(nlq),
     . yy5(nlq),yy6(nlq),yy7(nlq),yy8(nlq),
     . zz1(nlq),zz2(nlq),zz3(nlq),zz4(nlq),
     . zz5(nlq),zz6(nlq),zz7(nlq),zz8(nlq),vlm(nlq)
c
      common/bk00/numnp,numpc,numlp,neq,ndof,nlcur,numcl,numvc,
     1 ndtpts,nelmd,nmmat,numelh,numelb,numels,numelt,numdp,
     2 grvity,idirgv,nodspc,nspcor
      common/bk26/begtim,nintcy
      common/bk28/summss,xke,xpe,tt,xte0,erodeke,erodeie,selie,selke,
     1 erodehg
      common/bttn/ntnwf,ixa(50)
c
c     common/comrbbr/ishrub(300),icompf(300),mhyper(300)
      common/csforc/ncs1,ncs2,ncs3,ncs4,ncs5,ncs6,ncs7,ncs8,ncs9,
     . ncs10,ncs11,ncs12,ncs13,ncs14,ncs15,
     . numcsd,csdinc,csdout,output,sldef,future(2),issfmx,istos,
     . ifls,iflm,nsntl,nmntl
      common/eigvc/eke,eme,rsav,dt2std,isavdt2,iegflg,iegflg0(10)
      common/feedbck/ifdbck(41)
      common/numcpu/ncpu,ncpua,ncpub,lenvec(9)
      common/shlopt/istrn,istupd_flag,
     & ibelyts,miter,wrpang,ipstpd,intsts,
     1 nodsts,intstn,nodstn,jstrn
      common/slcntr/islcnt(21)
c
      real ies
      real*8 x,rots
      dimension mtype(1),cm(48,1),u(1),v(3,1),fv(1),x(3,1),auxvec(1),
     . eosp(1),tnew(1),fval(1),ener(1),npc(1),pld(1),hgforc(12,1),
     . ies(*),bqs(*),nhxbwp(*),hgener(*),strains(6,*),idam(*),
     . rhssav(27,*),volfrc(*),cmaux(*),eig(3,*),eign(3,*),damag(135,*),
     . rots(*),hges(*),lochvh(*),lochvq(*),auxmeh(*)
      dimension cmusr(48,*),xipn(4,100,*)
      dimension sigm(nlq)
c
      logical iamusrmat
      external iamusrmat
      integer, pointer,contiguous :: dm_ncrshf(:)
      integer, pointer,contiguous :: dm_ixh(:),dm_h_lochv(:),dm_isadj(:)
      integer, pointer,contiguous :: cs_icsd(:),cs_mnmx(:),cs_nhhxs(:)
      integer, pointer,contiguous :: cs_nhx(:),dm_iqtype(:)
      real, pointer,contiguous :: cs_rdsav(:),dm_ro(:),dm_eosp(:)
c
      data o64th/0.0156250/
c
c$omp threadprivate (/hour12loc/)
c$omp threadprivate (/vect8loc/)
c$omp threadprivate (/vect2loc/)
c$omp threadprivate (/subtssloc/)
c$omp threadprivate (/shloptloc/)
c$omp threadprivate (/scr01loc/)
c$omp threadprivate (/rayleiloc/)
c$omp threadprivate (/prescloc/)
c$omp threadprivate (/numcpuloc/)
c$omp threadprivate (/frozloc/)
c$omp threadprivate (/bel8aloc/)
c$omp threadprivate (/bel8loc/)
c$omp threadprivate (/bel7loc/)
c$omp threadprivate (/aux43loc/)
c$omp threadprivate (/aux37loc/)
c$omp threadprivate (/aux35loc/)
c$omp threadprivate (/aux33loc/)
c$omp threadprivate (/aux18loc/)
c$omp threadprivate (/aux16cntloc/)
c$omp threadprivate (/aux15loc/)
c$omp threadprivate (/aux14loc/)
c$omp threadprivate (/aux13loc/)
c$omp threadprivate (/aux10loc/)
c$omp threadprivate (/aux9loc/)
c$omp threadprivate (/aux8loc/)
c$omp threadprivate (/aux2loc/)
      call getintegerptr('dm_ncrshf',dm_ncrshf)
      call getintegerptr('dm_ixh',dm_ixh)
      call getintegerptr('dm_h_lochv',dm_h_lochv)
      call getintegerptr('dm_isadj',dm_isadj)
      call getintegerptr('dm_iqtype',dm_iqtype)
      call getrealptr('dm_ro',dm_ro)
      call getrealptr('dm_eosp',dm_eosp)
      if (ioshl(68).gt.0) then
        call getintegerptr('cs_icsd',cs_icsd)
        call getintegerptr('cs_mnmx',cs_mnmx)
        call getintegerptr('cs_nhhxs',cs_nhhxs)
        call getintegerptr('cs_nhx',cs_nhx)
        call getrealptr('cs_rdsav',cs_rdsav)
      endif
c
c     Number of integration points
c
      nip=nint(cmusr(1,mxe))
c
      nessav=nes
c
c     Number of extra degrees of freedom
c
      nxdof=nint(cmusr(2,mxe))
c
c     Flag for requesting hourglass stiffness
c
      ihgf=nint(cmusr(4,mxe))
      if (nip.eq.0) ihgf=0
c
c     Flag determining how to input data for integrated element
c
      itaj=nint(cmusr(5,mxe))
c
c     Number of property constants
c
      lmc=nint(cmusr(6,mxe))
c
c     Number of history variables
c
      nhsv=nint(cmusr(7,mxe))
c
c     Pointer to crv array
c
      islcnt16=islcnt(16)
c
c     Parameter used for hourglass
c
      nnm3=1
c
c     No support of vref and tref in material 126
c
c     For hourglass treatment
c
      if (nik3d(9).gt.0) nnm3=nnm2
c
c     mat_add_erosion
c
      if (ioshl(481).eq.1) then
        lenmaeh=ioshl(485)*nip
        lavmaeh=lochvq(nnm1+lft)
      else
        lenmaeh=1
        lavmaeh=1
      endif
c
c     Gather nodal coordinates and velocities
c
c     xi,yi,zi       = Nodal coordinates at t_{n+1}
c     xhi,yhi,zhi    = Nodal coordinates at t_{n+1/2}
c     vxi,vyi,vzi    = Translational velocities
c
      do i=lft,llt
c
         x1(i)=x(1,ix1(i))
         y1(i)=x(2,ix1(i))
         z1(i)=x(3,ix1(i))
         x2(i)=x(1,ix2(i))
         y2(i)=x(2,ix2(i))
         z2(i)=x(3,ix2(i))
         x3(i)=x(1,ix3(i))
         y3(i)=x(2,ix3(i))
         z3(i)=x(3,ix3(i))
         x4(i)=x(1,ix4(i))
         y4(i)=x(2,ix4(i))
         z4(i)=x(3,ix4(i))
         x5(i)=x(1,ix5(i))
         y5(i)=x(2,ix5(i))
         z5(i)=x(3,ix5(i))
         x6(i)=x(1,ix6(i))
         y6(i)=x(2,ix6(i))
         z6(i)=x(3,ix6(i))
         x7(i)=x(1,ix7(i))
         y7(i)=x(2,ix7(i))
         z7(i)=x(3,ix7(i))
         x8(i)=x(1,ix8(i))
         y8(i)=x(2,ix8(i))
         z8(i)=x(3,ix8(i))
c
         vx1(i)=v(1,ix1(i))
         vy1(i)=v(2,ix1(i))
         vz1(i)=v(3,ix1(i))
         vx2(i)=v(1,ix2(i))
         vy2(i)=v(2,ix2(i))
         vz2(i)=v(3,ix2(i))
         vx3(i)=v(1,ix3(i))
         vy3(i)=v(2,ix3(i))
         vz3(i)=v(3,ix3(i))
         vx4(i)=v(1,ix4(i))
         vy4(i)=v(2,ix4(i))
         vz4(i)=v(3,ix4(i))
         vx5(i)=v(1,ix5(i))
         vy5(i)=v(2,ix5(i))
         vz5(i)=v(3,ix5(i))
         vx6(i)=v(1,ix6(i))
         vy6(i)=v(2,ix6(i))
         vz6(i)=v(3,ix6(i))
         vx7(i)=v(1,ix7(i))
         vy7(i)=v(2,ix7(i))
         vz7(i)=v(3,ix7(i))
         vx8(i)=v(1,ix8(i))
         vy8(i)=v(2,ix8(i))
         vz8(i)=v(3,ix8(i))
c
      enddo
c
      if (nxdof.gt.0) then
         do k=1,8
            do j=1,nxdof
               nsnd=(j-1)/3+1
               nsdf=j-3*(nsnd-1)
               do i=lft,llt
                  xdof(i,k,j)=x(nsdf,ixsld(i,k,nsnd))
                  dxdof(i,k,j)=v(nsdf,ixsld(i,k,nsnd))
               enddo
            enddo
         enddo
      endif
c
      if (lenvec8.ne.0) then
c
c     Accuracy option is on, compute half step geometry
c
         do i=lft,llt
c
            sx1(i)=x1(i)-.5*vx1(i)*dt1siz(i)
            sy1(i)=y1(i)-.5*vy1(i)*dt1siz(i)
            sz1(i)=z1(i)-.5*vz1(i)*dt1siz(i)
            sx2(i)=x2(i)-.5*vx2(i)*dt1siz(i)
            sy2(i)=y2(i)-.5*vy2(i)*dt1siz(i)
            sz2(i)=z2(i)-.5*vz2(i)*dt1siz(i)
            sx3(i)=x3(i)-.5*vx3(i)*dt1siz(i)
            sy3(i)=y3(i)-.5*vy3(i)*dt1siz(i)
            sz3(i)=z3(i)-.5*vz3(i)*dt1siz(i)
            sx4(i)=x4(i)-.5*vx4(i)*dt1siz(i)
            sy4(i)=y4(i)-.5*vy4(i)*dt1siz(i)
            sz4(i)=z4(i)-.5*vz4(i)*dt1siz(i)
            sx5(i)=x5(i)-.5*vx5(i)*dt1siz(i)
            sy5(i)=y5(i)-.5*vy5(i)*dt1siz(i)
            sz5(i)=z5(i)-.5*vz5(i)*dt1siz(i)
            sx6(i)=x6(i)-.5*vx6(i)*dt1siz(i)
            sy6(i)=y6(i)-.5*vy6(i)*dt1siz(i)
            sz6(i)=z6(i)-.5*vz6(i)*dt1siz(i)
            sx7(i)=x7(i)-.5*vx7(i)*dt1siz(i)
            sy7(i)=y7(i)-.5*vy7(i)*dt1siz(i)
            sz7(i)=z7(i)-.5*vz7(i)*dt1siz(i)
            sx8(i)=x8(i)-.5*vx8(i)*dt1siz(i)
            sy8(i)=y8(i)-.5*vy8(i)*dt1siz(i)
            sz8(i)=z8(i)-.5*vz8(i)*dt1siz(i)
c
            xh1(i)=sx1(i)
            yh1(i)=sy1(i)
            zh1(i)=sz1(i)
            xh2(i)=sx2(i)
            yh2(i)=sy2(i)
            zh2(i)=sz2(i)
            xh3(i)=sx3(i)
            yh3(i)=sy3(i)
            zh3(i)=sz3(i)
            xh4(i)=sx4(i)
            yh4(i)=sy4(i)
            zh4(i)=sz4(i)
            xh5(i)=sx5(i)
            yh5(i)=sy5(i)
            zh5(i)=sz5(i)
            xh6(i)=sx6(i)
            yh6(i)=sy6(i)
            zh6(i)=sz6(i)
            xh7(i)=sx7(i)
            yh7(i)=sy7(i)
            zh7(i)=sz7(i)
            xh8(i)=sx8(i)
            yh8(i)=sy8(i)
            zh8(i)=sz8(i)
c
         enddo
c
         if (nxdof.gt.0) then
            do k=1,8
               do j=1,nxdof
                  do i=lft,llt
                     xhdof(i,k,j)=xdof(i,k,j)-
     1                    .5*dxdof(i,k,j)*dt1siz(i)
                  enddo
               enddo
            enddo
         endif
c
      endif
c
      if (nip.eq.1.and.ihgf.eq.1) then
c
c     LS-DYNA hourglass requested for single point integrated solid
c
         if (lenvec8.ne.0) then
c
            do i=lft,llt
c
               x1(i)=sx1(i)
               y1(i)=sy1(i)
               z1(i)=sz1(i)
               x2(i)=sx2(i)
               y2(i)=sy2(i)
               z2(i)=sz2(i)
               x3(i)=sx3(i)
               y3(i)=sy3(i)
               z3(i)=sz3(i)
               x4(i)=sx4(i)
               y4(i)=sy4(i)
               z4(i)=sz4(i)
               x5(i)=sx5(i)
               y5(i)=sy5(i)
               z5(i)=sz5(i)
               x6(i)=sx6(i)
               y6(i)=sy6(i)
               z6(i)=sz6(i)
               x7(i)=sx7(i)
               y7(i)=sy7(i)
               z7(i)=sz7(i)
               x8(i)=sx8(i)
               y8(i)=sy8(i)
               z8(i)=sz8(i)
c
            enddo
c
         endif
c
         if (ihg.ne.3.and.ihg.ne.5.and.ihg.ne.6) then
            call prtal(lft,llt)
         else
            call prtalf(lft,llt)
         endif
c
         if (lenvec8.ne.0) then
c
            do i=lft,llt
               spx1(i)=px1(i)
               spx2(i)=px2(i)
               spx3(i)=px3(i)
               spx4(i)=px4(i)
               spx5(i)=px5(i)
               spx6(i)=px6(i)
               spx7(i)=px7(i)
               spx8(i)=px8(i)
               spy1(i)=py1(i)
               spy2(i)=py2(i)
               spy3(i)=py3(i)
               spy4(i)=py4(i)
               spy5(i)=py5(i)
               spy6(i)=py6(i)
               spy7(i)=py7(i)
               spy8(i)=py8(i)
               spz1(i)=pz1(i)
               spz2(i)=pz2(i)
               spz3(i)=pz3(i)
               spz4(i)=pz4(i)
               spz5(i)=pz5(i)
               spz6(i)=pz6(i)
               spz7(i)=pz7(i)
               spz8(i)=pz8(i)
               volm(i)=voln(i)
               x1(i)=x(1,ix1(i))
               y1(i)=x(2,ix1(i))
               z1(i)=x(3,ix1(i))
               x2(i)=x(1,ix2(i))
               y2(i)=x(2,ix2(i))
               z2(i)=x(3,ix2(i))
               x3(i)=x(1,ix3(i))
               y3(i)=x(2,ix3(i))
               z3(i)=x(3,ix3(i))
               x4(i)=x(1,ix4(i))
               y4(i)=x(2,ix4(i))
               z4(i)=x(3,ix4(i))
               x5(i)=x(1,ix5(i))
               y5(i)=x(2,ix5(i))
               z5(i)=x(3,ix5(i))
               x6(i)=x(1,ix6(i))
               y6(i)=x(2,ix6(i))
               z6(i)=x(3,ix6(i))
               x7(i)=x(1,ix7(i))
               y7(i)=x(2,ix7(i))
               z7(i)=x(3,ix7(i))
               x8(i)=x(1,ix8(i))
               y8(i)=x(2,ix8(i))
               z8(i)=x(3,ix8(i))
            enddo
c
            if (ihg.ne.3.and.ihg.ne.5.and.ihg.ne.6) then
               call prtal(lft,llt)
            else
               call prtalf(lft,llt)
            endif
c
         endif
c
      else
c
c     Compute volume of element
c
         do i=lft,llt
            x17=x7(i)-x1(i)
            x28=x8(i)-x2(i)
            x35=x5(i)-x3(i)
            x46=x6(i)-x4(i)
            y17=y7(i)-y1(i)
            y28=y8(i)-y2(i)
            y35=y5(i)-y3(i)
            y46=y6(i)-y4(i)
            z17=z7(i)-z1(i)
            z28=z8(i)-z2(i)
            z35=z5(i)-z3(i)
            z46=z6(i)-z4(i)
            aj1=x17+x28-x35-x46
            aj2=y17+y28-y35-y46
            aj3=z17+z28-z35-z46
            a17=x17+x46
            a28=x28+x35
            b17=y17+y46
            b28=y28+y35
            c17=z17+z46
            c28=z28+z35
            aj4=a17+a28
            aj5=b17+b28
            aj6=c17+c28
            aj7=a17-a28
            aj8=b17-b28
            aj9=c17-c28
            aj5968=aj5*aj9-aj6*aj8
            aj6749=aj6*aj7-aj4*aj9
            aj4857=aj4*aj8-aj5*aj7
            voln(i)=o64th*(aj1*aj5968+aj2*aj6749+aj3*aj4857)
         enddo
c
      endif
c
c     Compute parameters used in material routines
c
      crho=.0625*rhoa(lft)
c
      do i=lft,llt
         voloi=u(nnm2+i-1)
         xm(i)=1./voloi
         vlrho(i)=crho*voloi
         dfe(i)=voln(i)*xm(i)
      enddo
c
c     Compute characteristic length used for
c     time step calculations
c
      call felen (lft,llt)
c
c     Initialize some parameters
c
      do i=lft,llt
c     volume at t_{n+1/2} and t_{n+1}
         voltot(i)=0.
         cvltot(i)=0.
         dd(i)=0.
         ddq(i)=0.
      enddo
c
c     Zero internal force vector
c
      ndtot=8*(3+nxdof)
      do j=1,ndtot
         do i=lft,llt
            frc(i,j)=0.
         enddo
      enddo
c
      if (nip.gt.0) then
c
c     Loop over integration points
c
      do ipt=1,nip
c
c     Gather parental coordinates and weights
c
         xiipt=xipn(1,ipt,mxe)
         etaipt=xipn(2,ipt,mxe)
         zetaipt=xipn(3,ipt,mxe)
         wgt=xipn(4,ipt,mxe)
c
c     Pointer to first item in history variables array
c
         lavloc=(ipt-1)*nmtcon+lav
         locstn=lavloc+nmtcon-6*jstrn
c
c     Compute b-matrix and g-matrix
c
         call usrsld_b(ietyp,xiipt,etaipt,zetaipt,lft,llt)
c
c     Compute volume of integration point and "real" b-matrix
c
         call usrsld_b2b(itaj,nxdof,wgt,lft,llt)
         do i=lft,llt
            vlm(i)=vlm(i)*wgt
         enddo
c
c     Compute strain and rotational increments
c
         call usrsld_str(nxdof,lft,llt)
c
c     Zero energy increments
c
         do i=lft,llt
            einc(i)=0.
         enddo
c
c     Compute deformation gradient if necessary
c
         call usrsld_grd(rots,nxdof,ietyp,mte,
     1        xiipt,etaipt,zetaipt,lft,llt)
c
         if (ihgf.eq.1.and.nip.eq.1) then
c
            if (ihg.gt.3.and.ihg.lt.6) then
c
c     Rotation of hourglass tensor related to the
c     Flanagan-Belytschko stiffness form
c
               call hgfrot (hgforc(1,nnm2),lft,llt)
c
            endif
c
         endif
c
c     icpf.ne.0 not supported
c
c     Gather history variables
c
         nc=nip*nmtcon
         if (mte.eq.126) nc=nc+27
c
         do j=1,nmtcon
            do i=lft,llt
               ax(i,j)=auxvec(lavloc+nc*(i-lft)+(j-1))
            enddo
         enddo
c
c     Rayleigh damping
c
         if (abs(betav).gt.0.000)  then
            call rydmp1 (lft,llt)
            if (lenvec(5).eq.1) then
               call rydmp5 (lft,llt,ax(1,nmtcon-5),ax(1,nmtcon-4),
     .              ax(1,nmtcon-3),ax(1,nmtcon-2),ax(1,nmtcon-1),
     .              ax(1,nmtcon),ies(nnm2),1,ax)
            endif
         endif
c
c     mat_add_erosion
c
      if (idmgmdl.gt.1) call mad_cpyhis(lft,llt,1)
c
c     Process thermal expansion
c
         if (ithxpid.ne.0) then
            call adthstr(lft,llt,1)
            if (icompf(mte).eq.mte)
     .           call mlthjc(lft,llt)
         endif
c
c     Constitutive matrix
c
         if (is17loc.ne.0.or.ihgf.eq.3) then
            call cmatsi3d (cm,lft,llt,mte,npc,pld,tnew,fval)
         endif
c
         if (lenvec8.ne.0) then
c
c     Accuracy option is on, set up for
c     half-step rotation of stresses
c
            do i=lft,llt
               wxxdt(i)=.50*wxxdt(i)
               wyydt(i)=.50*wyydt(i)
               wzzdt(i)=.50*wzzdt(i)
            enddo
            lenvech=1
c
         endif
c
         if (istrn.ne.0) then
            if (isolvr(18).eq.0) then
c
c     Rotate strains for post-processing
c
               call usrsld_rstr(strains(1,nnm2),lft,llt,ipt,nip,wgt)
               if (jstrn.eq.1) call qrttrs (auxvec(locstn),lft,llt,nc)
               if (cm(5,mxt(lft)).lt.0..and.
c                 need updated strain for usrmat_24
     .            (mte.eq.24.or.mte.eq.114.or.mte.eq.123.or.
     .             mte.eq.124.or.mte.eq.155.or.mte.eq.182.or.
     .             mte.eq.238.or.mte.eq.255))
     .         call sldeps4um (auxvec(locstn),lft,llt,nc)
c
            endif
         endif
c
c     For passing correct hourglass ID
c
         if (nip.eq.1.and.ihgf.eq.1) then
            ihgp=ihg
         else
            ihgp=5
         endif
c
c     Stress contribution from *INITIAL_STRESS_SECTION
c
      if (ioshl(68).gt.0) then
         call acmfch_00 (cm,mte,cs_icsd,cs_mnmx,cs_nhhxs,cs_nhx,
     $        numcsd,nnm1,lft,llt,auxvec,fval,ia(ioshl(69))
     $        ,ia(ioshl(70)), cs_rdsav,
     $        ia(ioshl(71)),ies(nnm2)
     $        ,nmmat,0,0, a(n8+nlcur+1),ia(ioshl(1059)),
     &        dm_ro(mxe+5*nmmat),dm_ro(6*nmmat+mxe),a(ioshl(1060))
     $        ,ax(1,1),ax(1,2),ax(1,3),ax(1,4),ax(1,5),ax(1,6)
     $        ,ax(1,7),ax(1,8))
      endif
c
c     mat_add_erosion
c
      if (nessav.ne.0.and.(idmgmdl.lt.0.or.idmgmdl.eq.2)) then
        do i=lft,llt
          sigm(i)=(ax(i,1)+ax(i,2)+ax(i,3))/3.
        enddo
      endif
c
      if(idmgmdl.eq.4) then
        call damgen1_sld(lft,llt,mte)
      elseif(idmgmdl.eq.2) then
        call dmgadd1(damag(1,mxt(lft)),lft,llt,
     .   ax(1,1),ax(1,2),ax(1,3),ax(1,4),ax(1,5),ax(1,6),ax(1,7),
     .   ax(1,8))
        call mae_energy(ies(nnm2),lft,llt)
      elseif (idmgmdl.lt.0) then
        call dmgadd(damag(1,mxt(lft)),lft,llt,a(islcnt(16)),
     .   i_mem(mezp(34)),x,v,ipt,1,0,2,strains(1,nnm2),0.,nnm1,nhxbwp,
     .   ax(1,1),ax(1,2),ax(1,3),ax(1,4),ax(1,5),ax(1,6),ax(1,7),
     .   ax(1,8))
      endif
c
      if (mte.gt.10) go to 120
      go to (20,30,40,50,60,70,80,90,100,110), mte
   20 call rstrss (lft,llt)
      call f3dm1 (cm,bqs(nnm2),lft,llt)
      go to 207
   30 call f3dm2 (cm,bqs(nnm2),ihgp,lft,llt,mxe,eosp,cmaux,0)
      go to 207
   40 call rstrss (lft,llt)
      call rstrn (lft,llt)
      if (isolvr(1).ne.0) then
         do i=lft,llt
            dmgvals(i,1)=0.
            dmgvals(i,2)=0.
         enddo
      endif
      call f3dm3 (cm,bqs(nnm2),lft,llt,ipt,nip)
      go to 207
   50 call rstrss (lft,llt)
      call f3dm4 (cm,bqs(nnm2),tnew,fval,lft,llt)
      go to 207
   60 call rstrss (lft,llt)
      call f3dm5 (cm,bqs(nnm2),u(nnm2),0,lft,llt)
      go to 207
   70 call rstrss (lft,llt)
      call rstrnn (lft,llt,1)
      call f3dm6 (cm,bqs(nnm2),lft,llt,ia(islcnt16),i_mem(mezp(34)))
      go to 207
   80 call rstrss (lft,llt)
      call f3dm7 (cm,bqs(nnm2),ihgp,lft,llt)
      go to 207
   90 call f3dm8 (cm,lft,llt)
      if (ipt.eq.nip) then
         call sueos (eosp,mte,nes,lft,llt)
         call bulkq (ibq,nhxbwp(nnm2),lft,llt)
      endif
      if (nip.ne.1) then
         do i=lft,llt
            vlinc(i)=vlm(i)
         enddo
         call heupd8 (lft,llt,ies(nnm2),ipt,ener)
      else
         call hieupd (lft,llt)
      endif
      if (ipt.eq.nip) call eqos (fval,ies(nnm2),mte,nes,lft,llt)
      go to 208
  100 call rstrss (lft,llt)
      call f3dm9 (cm,lft,llt)
      if (ipt.eq.nip) then
         call sueos (eosp,mte,nes,lft,llt)
         call bulkq (ibq,nhxbwp(nnm2),lft,llt)
      endif
      if (nip.ne.1) then
         do i=lft,llt
            vlinc(i)=vlm(i)
         enddo
         call heupd8 (lft,llt,ies(nnm2),ipt,ener)
      else
         call hieupd (lft,llt)
      endif
      if (ipt.eq.nip) call eqos (fval,ies(nnm2),mte,nes,lft,llt)
      go to 208
  110 call rstrss (lft,llt)
      call f3dm10 (cm,lft,llt)
      if (ipt.eq.nip) then
         call sueos (eosp,mte,nes,lft,llt)
         call bulkq (ibq,nhxbwp(nnm2),lft,llt)
      endif
      if (nip.ne.1) then
         do i=lft,llt
            vlinc(i)=vlm(i)
         enddo
         call heupd8 (lft,llt,ies(nnm2),ipt,ener)
      else
         call hieupd (lft,llt)
      endif
      if (ipt.eq.nip) call eqos (fval,ies(nnm2),mte,nes,lft,llt)
      go to 208
  120 if (mte.lt.30) then
      mte10=mte-10
      go to (130,140,150,160,170,180,190,192,194,207,196,197,198,199,
     1 200,204,205),mte10
      else
      if (mte.eq.30) then
      call rstrss (lft,llt)
      call f3dm30(cm,bqs(nnm2),ia(islcnt16),i_mem(mezp(34)),
     . tnew,fval,lft,llt)
      go to 207
      endif
      if (mte.eq.98) then
      call rstrss (lft,llt)
      call f3dm98 (cm,bqs(nnm2),lft,llt)
      go to 207
      endif
      if (mte.eq.159) then
      call rstrss (lft,llt)
      call f3dm159 (cm,cmaux,bqs(nnm2),lft,llt)
      go to 207
      endif
      if (mte.eq.31) then
      call rstrss (lft,llt)
      call f3dm31 (cm,bqs(nnm2),ihgp,lft,llt)
      go to 207
      endif
      if (mte.eq.33) then
      call rstrss (lft,llt)
      call f3dm33 (cm,bqs(nnm2),lft,llt,ia(islcnt(16)),i_mem(mezp(34)))
      go to 207
      endif
      if (mte.eq.35) then
      call rqtat1 (lft,llt)
      call gtvrtm (lft,llt)
      call f3dm35 (cm,bqs(nnm2),lft,llt)
      call rqtat2 (lft,llt)
      go to 207
      endif
      if (mte.eq.36) then
      call rqtat1 (lft,llt)
      call gtvrtm (lft,llt)
      call f3dm36 (cm,lft,llt)
      call rqtat2 (lft,llt)
      go to 207
      endif
      if (mte.eq.38) then
      call rstrss (lft,llt)
      call f3dm38 (cm,bqs(nnm2),ihgp,lft,llt)
      go to 207
      endif
      if (mte.eq.40) then
      call rstrss (lft,llt)
      call f3dm40 (cm,npc,pld,bqs(nnm2),ihgp,lft,llt,cmaux)
      go to 207
      endif
      if (mte.eq.141) then
      call rstrss (lft,llt)
      call rstrn  (lft,llt)
      call f3dm141(cm,bqs(nnm2),lft,llt)
      go to 207
      endif
      if (mte.eq.142) then
      call rstrss (lft,llt)
      call f3dm142(cm,bqs(nnm2),lft,llt,ia(islcnt(16)),i_mem(mezp(34)))
      go to 207
      endif
      if (mte.eq.143) then
      call rstrss (lft,llt)
      call f3dm143(cm,bqs(nnm2),lft,llt)
      go to 207
      endif
      if (mte.eq.51) then
      call rstrss (lft,llt)
      call rstrn (lft,llt)
      call f3dm51(cm,bqs(nnm2),lft,llt)
      go to 207
      endif
      if (mte.eq.52) then
      call rstrss (lft,llt)
      call rstrn (lft,llt)
      call f3dm52 (cm,bqs(nnm2),lft,llt)
      go to 207
      endif
      if (mte.eq.151) then
      call rstrss (lft,llt)
      call rstrn (lft,llt)
      call f3dm151(cm,eosp,bqs(nnm2),lft,llt)
      go to 207
      endif
      if (mte.eq.53) then
      call rstrss (lft,llt)
      call f3dm53 (cm,bqs(nnm2),lft,llt,ia(islcnt16),i_mem(mezp(34)))
      go to 207
      endif
      if (mte.eq.57) then
      call rstrss (lft,llt)
      call gtvrtn (lft,llt)
      if (is17loc.ne.0) then
      call s57main (cm,npc,pld,lft,llt,ia(islcnt16),i_mem(mezp(34)),
     &             a(n8+2*nlcur+1),a(n8+3*nlcur+1))
      endif
      call f3dm57 (cm,bqs(nnm2),npc,pld,lft,llt,ia(islcnt16),
     &             i_mem(mezp(34)),
     &             a(n8+2*nlcur+1),a(n8+3*nlcur+1))
      go to 207
      endif
      if (mte.eq.261) then
      call rstrss (lft,llt)
      call f3dm261(cm,a(n8),a(n9),bqs(nnm2),lft,llt,ipt,nip,
     .             a(islcnt(16)),i_mem(mezp(34)),dm_ncrshf,
     .             a(n8+2*nlcur+1),a(n8+3*nlcur+1))
      go to 207
      endif
      if (mte.eq.262) then
      call rstrss (lft,llt)
      call f3dm262(cm,bqs(nnm2),lft,llt,ipt,nip,a(islcnt(16)),
     .             i_mem(mezp(34)),dm_ncrshf,
     .             a(n8+2*nlcur+1),a(n8+3*nlcur+1),eosp,nnm1,nhxbwp)
      go to 207
      endif
      if (mte.eq.213) then
      call rstrss (lft,llt)
      lcm2=lc2+nint(cm(20,mxe))
      call f3dm213(cm,bqs(nnm2),lft,llt,npc,pld,a(islcnt(16)),
     . i_mem(mezp(34)),a(n8+2*nlcur+1),a(n8+3*nlcur+1),ipt,eosp,
     . a(lcm2),auxvec)
      go to 207
      endif
      if (mte.eq.215) then
      call rstrss (lft,llt)
      call rstrn215 (lft,llt)
      call f3dm215(cm,bqs(nnm2),npc,pld,dm_eosp,
     .             lft,llt,ia(n8+2*nlcur+1),
     .             ia(n8+3*nlcur+1),ia(islcnt(16)),i_mem(mezp(34)),ipt,
     .             u(nnm2))
      go to 207
      endif
      if (mte.eq.250) then
      call rstrss (lft,llt)
      call rstrn250 (lft,llt)
      call f3dm250(cm,bqs(nnm2),npc,pld,dm_eosp,
     .             lft,llt,ia(n8+2*nlcur+1),
     .             ia(n8+3*nlcur+1),ia(islcnt(16)),i_mem(mezp(34)),ipt)
      go to 207
      endif
      if (mte.eq.177) then
      call rstrss (lft,llt)
      call gtvrtn (lft,llt)
      call f3dm177 (cm,bqs(nnm2),lft,llt)
      go to 207
      endif
      if (mte.eq.178) then
      call rstrss (lft,llt)
      call gtvrtn (lft,llt)
      call f3dm178 (cm,bqs(nnm2),lft,llt,eosp)
      go to 207
      endif
      if (mte.eq.179.or.mte.eq.180) then
      call rstrss (lft,llt)
      call gtvrtn (lft,llt)
      call f3dm179 (cm,bqs(nnm2),npc,pld,lft,llt,ia(islcnt16),
     .     i_mem(mezp(34)),mte,
     .     a(n8+2*nlcur+1),a(n8+3*nlcur+1))
      go to 207
      endif
      if (mte.eq.181) then
      call rstrss (lft,llt)
      call gtvrtn (lft,llt)
      call f3dm181 (cm,bqs(nnm2),npc,pld,lft,llt,ia(n8+2*nlcur+1),
     . ia(n8+3*nlcur+1),ia(islcnt(16)),i_mem(mezp(34)),eosp)
      go to 207
      endif
c
      if (mte.eq.187) then
      call rstrss (lft,llt)
      call f3dm187 (cm,nnm1,bqs(nnm2),a(ioshl(332)),a(ioshl(333)),
     &              ipt,lft,llt)
      go to 207
      endif
c
      if (mte.eq.183) then
      call rstrss (lft,llt)
      call gtvrtn (lft,llt)
      call f3dm183 (cm,bqs(nnm2),npc,pld,lft,llt,ia(n8+2*nlcur+1),
     . ia(n8+3*nlcur+1),ia(islcnt(16)),i_mem(mezp(34)))
      go to 207
      endif
      if (mte.eq.100) then
      call rstrss (lft,llt)
      if (isolvr(1).ne.0) then
c     see comments in dyn3a.F
         do i=lft,llt
            dmgvals(i,1)=0.
            dmgvals(i,2)=0.
         enddo
      endif
      call f3dm100 (cm,bqs(nnm2),nhxbwp(nnm2),lft,llt,npc,pld,
     , ia(n8+2*nlcur+1),ia(n8+3*nlcur+1),ia(islcnt(16)),i_mem(mezp(34))
     , )
      go to 207
      endif
      if (mte.eq.73) then
      call rstrss (lft,llt)
      call gtvrtn (lft,llt)
      call f3dm73 (cm,bqs(nnm2),npc,pld,lft,llt,ia(islcnt16),
     . i_mem(mezp(34)))
      go to 207
      endif
      if (mte.eq.83) then
      call rstrss (lft,llt)
      call gtvrtn (lft,llt)
      lthrpr=nint(cm(48,mxe))+lc2
      call f3dm83 (cm,bqs(nnm2),npc,pld,lft,llt,ia(lthrpr),
     . ia(lthrpr+20),ia(n8+2*nlcur+1),ia(n8+3*nlcur+1),
     . ia(islcnt(16)),i_mem(mezp(34)))
      go to 207
      endif
      if (mte.eq.77) then
      call rstrss (lft,llt)
      call gtvrtn (lft,llt)
      call f3dm77 (cm,eosp,bqs(nnm2),npc,pld,lft,llt,ia(islcnt(16)),
     . i_mem(mezp(34)))
      go to 207
      endif
      if (mte.eq.127) then
      call rstrss (lft,llt)
      call gtvrtn (lft,llt)
      call f3dm127 (cm,bqs(nnm2),npc,pld,lft,llt,ia(islcnt(16)))
      go to 207
      endif
      if (mte.eq.129) then
      call rstrss (lft,llt)
      call gtvrtn (lft,llt)
      call f3dm129 (cm,bqs(nnm2),npc,pld,lft,llt,ia(islcnt(16)))
      go to 207
      endif
c
c***  TNO failure models
      if (mte.eq.131) then
      call rstrss (lft,llt)
      call f3dm131(cm,bqs(nnm2),nnm1,lft,llt,nhxbwp(nnm2))
      go to 207
      endif
      if (mte.eq.132) then
      call rstrss (lft,llt)
      call f3dm132(cm,bqs(nnm2),lft,llt,nhxbwp(nnm2),cmaux)
      go to 207
      endif
c
      if (mte.eq.87) then
      call rstrss (lft,llt)
      if (is17loc.ne.0) call bfgs_tan0(lft,llt)
      call gtvrtn (lft,llt)
      call f3dm87 (cm,bqs(nnm2),npc,pld,lft,llt,ia(islcnt(16)))
      go to 207
      endif
      if (mte.eq.147) then
      call rstrss (lft,llt)
      call f3dm147 (cm,bqs(nnm2),lft,llt)
      go to 207
      endif
      if (mte.eq.91) then
        call rstrss (lft,llt)
        call f3dm91(cm,bqs(nnm2),lft,llt)
        go to 207
      endif
      if (mte.eq.92) then
        call rstrss (lft,llt)
        call f3dm92(cm,bqs(nnm2),lft,llt)
        go to 207
      endif
      if (mte.eq.96) then
      call rstrss (lft,llt)
      call rstrn3 (lft,llt)
      call rstrn4 (lft,llt)
      call f3dm96 (cm,bqs(nnm2),lft,llt)
      go to 207
      endif
      if (mte.eq.59) then
      call rstrss (lft,llt)
      call f3dm59(cm,bqs(nnm2),lft,llt)
      go to 207
      endif
      if (mte.eq.80) then
      call rstrss (lft,llt)
      call f3dm80(cm,bqs(nnm2),lft,llt)
      go to 207
      endif
      if (mte.eq.60) then
      call rstrss (lft,llt)
      call f3dm60 (cm,bqs(nnm2),fval,tnew,lft,llt)
      go to 207
      endif
      if (mte.eq.89) then
      call rstrss (lft,llt)
      call rtensor(lft,llt,20,1)
      call rtensor(lft,llt,29,0)
      call f3dm89 (cm,bqs(nnm2),lft,llt,npc,pld,
     1             ipt,ia(n8+2*nlcur+1),ia(n8+3*nlcur+1),ia(islcnt(16)),
     .             i_mem(mezp(34)))
      go to 207
      endif
      if (mte.eq.61) then
      call rstrss (lft,llt)
      call rstrnn61 (lft,llt,2)
      call f3dm61 (cm,bqs(nnm2),lft,llt)
      go to 207
      endif
      if (mte.eq.164) then
      call rstrss (lft,llt)
      call rstrnn61 (lft,llt,2)
      call f3dm164(cm,bqs(nnm2),lft,llt,ies(nnm2),hges(nnm2))
      go to 207
      endif
      if (mte.eq.165) then
      call rstrss (lft,llt)
      call rstrn (lft,llt)
      call f3dm165 (cm,bqs(nnm2),lft,llt)
      go to 207
      endif
      if (mte.eq.62) then
      call rstr62 (lft,llt)
      call f3dm62 (cm,bqs(nnm2),lft,llt)
      go to 207
      endif
      if (mte.eq.75) then
      call rstrss (lft,llt)
      call f3dm75 (cm,bqs(nnm2),lft,llt,ia(islcnt(16)),i_mem(mezp(34)),
     . npc,pld)
      go to 207
      endif
      if (mte.eq.63) then
      call rstrss (lft,llt)
      if (is17loc.ne.0) then
      call s63main (cm,npc,pld,lft,llt,ia(islcnt(16)),i_mem(mezp(34)))
      endif
      call f3dm63 (cm,bqs(nnm2),npc,pld,lft,llt,ia(islcnt(16)),
     . i_mem(mezp(34)))
      go to 207
      endif
      if (mte.eq.64) then
      call rstrss (lft,llt)
      call f3dm64 (cm,bqs(nnm2),npc,pld,lft,llt,1,1,nnm1)
      go to 207
      endif
      if (mte.eq.70) then
      call rstrss (lft,llt)
      call f3dm70 (cm,bqs(nnm2),npc,pld,lft,llt)
      go to 207
      endif
      if (mte.eq.126) then
      call rstrss (lft,llt)
      call f3dm126(cm,bqs(nnm2),npc,pld,lft,llt,ia(islcnt(16)),
     . i_mem(mezp(34)),cmaux)
      go to 207
      endif
      if (mte.eq.76) then
      call rstrss (lft,llt)
      call f3dm76 (cm,eosp,bqs(nnm2),tnew,lft,llt)
      go to 207
      endif
      if (mte.eq.276) then
      call rstrss (lft,llt)
      call f3dm276 (cm,bqs(nnm2),tnew,lft,llt)
      go to 207
      endif
      if (mte.eq.277) then
      call rstrss (lft,llt)
      call f3dm277 (cm,eosp,bqs(nnm2),tnew,lft,llt,ia(islcnt(16)),
     .              i_mem(mezp(34)),ia(n8+2*nlcur+1),ia(n8+3*nlcur+1),
     .              ipt,nnm1)
      go to 207
      endif
      if (mte.eq.307) then
      call rstrss (lft,llt)
      call f3dm307 (cm,eosp,bqs(nnm2),tnew,lft,llt,cmaux,
     .  ia(islcnt(16)),i_mem(mezp(34)),ia(n8+2*nlcur+1),
     .  ia(n8+3*nlcur+1),ipt,nnm1)
      go to 207
      endif
      if (mte.eq.278) then  
      call rstrss (lft,llt)
      call f3dm278 (cm,eosp,lft,llt,cmaux,bqs(nnm2),ia(islcnt(16)),
     .  i_mem(mezp(34)),ia(n8+2*nlcur+1),ia(n8+3*nlcur+1),
     .  ipt,nnm1)
      go to 207
      endif
      if (mte.eq.176) then
      call rstrss (lft,llt)
      call f3dm176 (cm,bqs(nnm2),npc,pld,lft,llt,ia(n8+2*nlcur+1),
     . ia(n8+3*nlcur+1),ia(islcnt(16)),i_mem(mezp(34)))
      go to 207
      endif
      if (mte.eq.78) then
      call rstrss (lft,llt)
      call f3dm78 (cm,bqs(nnm2),0,ia(islcnt(16)),i_mem(mezp(34)),
     . lft,llt)
      go to 207
      endif
      if (mte.eq.79) then
      call rstr79 (lft,llt)
      call f3dm79 (cm,bqs(nnm2),fval,npc,pld,lft,llt,eosp)
      go to 207
      endif
c     Winfrith concrete model not supported
      if (mte.eq.65) then
      call rstrss (lft,llt)
      call f3dm65 (cm,lft,llt)
      if (ipt.eq.nip) then
         call sueos (eosp,mte,nes,lft,llt)
         call bulkq (ibq,nhxbwp(nnm2),lft,llt)
      endif
      if (nip.ne.1) then
         do i=lft,llt
            vlinc(i)=vlm(i)
         enddo
         call heupd8 (lft,llt,ies(nnm2),ipt,ener)
      else
         call hieupd (lft,llt)
      endif
      if (ipt.eq.nip) call eqos (fval,ies(nnm2),mte,nes,lft,llt)
      go to 208
      endif
      if (mte.eq.72) then
      call rstrss (lft,llt)
      lcm2=lc2+nint(cm(7,mxe)-1.)
      call f3dm72 (cm,npc,pld,eosp,mte,nes,ibq,ies(nnm2),fval,
     .             nhxbwp(nnm2),a(lcm2),lft,llt,bqs(nnm2),ipt,nip,nnm1,
     .             dm_iqtype(1+3*nmmat))
      go to 207
      endif
      if (mte.eq.88) then
      call rstrss (lft,llt)
      call f3dm88 (cm,lft,llt)
      if (ipt.eq.nip) then
         call sueos (eosp,mte,nes,lft,llt)
         call bulkq (ibq,nhxbwp(nnm2),lft,llt)
      endif
      if (nip.ne.1) then
         do i=lft,llt
            vlinc(i)=vlm(i)
         enddo
         call heupd8 (lft,llt,ies(nnm2),ipt,ener)
      else
         call hieupd (lft,llt)
      endif
      if (ipt.eq.nip) call eqos (fval,ies(nnm2),mte,nes,lft,llt)
      go to 208
      endif
      if (iamusrmat(mte)) then
      call rstrss (lft,llt)
      call usrmat (lft,llt,cm,bqs(nnm2),capa,'solid',mte,ipt,
     . a(n8),a(n9),a(islcnt(16)),i_mem(mezp(34)),0.,0.,0.,nnm1,nip,ipt)
      if(nes.ne.0) then
         if (ipt.eq.nip) then
            call sueos (eosp,mte,nes,lft,llt)
            call bulkq (ibq,nhxbwp(nnm2),lft,llt)
         endif
         if (nip.ne.1) then
            do i=lft,llt
               vlinc(i)=vlm(i)
            enddo
            call heupd8 (lft,llt,ies(nnm2),ipt,ener)
         else
            call hieupd (lft,llt)
         endif
         if (ipt.eq.nip) call eqos (fval,ies(nnm2),mte,nes,lft,llt)
         goto 208
      else
         go to 207
      endif
      endif
      if (mte.eq.324) then
      call rstrss (lft,llt)
      call f3dm324(cm,bqs(nnm2),npc,pld,lft,llt,ia(n8+2*nlcur+1),
     . ia(n8+3*nlcur+1),ia(islcnt(16)),i_mem(mezp(34)),
     . ia(ifdbck(31)),ipt,nip,
     . nhxbwp(nnm2),dm_ncrshf)
      go to 207
      endif
      if (mte.eq.102) then
      call rstrss (lft,llt)
      call f3dm102 (cm,bqs(nnm2),lft,llt,tnew,fval,ia(islcnt(16)),
     . i_mem(mezp(34)))
      go to 207
      endif
      if (mte.eq.103) then
      call rstrss (lft,llt)
      call f3dm103 (cm,eosp,bqs(nnm2),lft,llt,npc,pld,ia(islcnt(16)),
     .     i_mem(mezp(34)),
     .     ia(n8+2*nlcur+1),ia(n8+3*nlcur+1))
      go to 207
      endif
      if (mte.eq.133) then
      call rstrss (lft,llt)
      call f3dm133(cm,bqs(nnm2),lft,llt,ia(islcnt(16)),i_mem(mezp(34)),
     . ia(n8+2*nlcur+1),ia(n8+3*nlcur+1),eosp,nnm1,nhxbwp(nnm2),npc,pld)
      go to 207
      endif
      if (mte.eq.157) then
      call rstrss (lft,llt)
      call f3dm157 (cm,bqs(nnm2),lft,llt,ia(islcnt(16)),
     .              i_mem(mezp(34)),
     .              ia(n8+2*nlcur+1),ia(n8+3*nlcur+1),eosp,npc,pld)
      go to 207
      endif
      if (mte.eq.122) then
      call rstrss (lft,llt)
      call f3dm122 (cm,eosp,bqs(nnm2),lft,llt,npc,pld,ia(islcnt(16)),
     .     i_mem(mezp(34)),
     .     ia(n8+2*nlcur+1),ia(n8+3*nlcur+1))
      go to 207
      endif
      if (mte.eq.260) then
      call rstrss (lft,llt)
      call f3dm260 (cm,eosp,bqs(nnm2),lft,llt,npc,pld,ia(islcnt(16)),
     .     ia(n8+2*nlcur+1),ia(n8+3*nlcur+1),nes)
      if (nes.eq.0) then
        go to 207
      else
        if (ipt.eq.nip) then
          call sueos (eosp,mte,nes,lft,llt)
          iffg=0
          if (nip.eq.1.and.ihgf.eq.1.and.ihg.eq.6)
     .      call hrgbbc (cm,ia(islcnt(16)),i_mem(mezp(34)),
     .      mte,lft,llt,iffg,x,auxvec,1)
          call bulkq (ibq,nhxbwp(nnm2),lft,llt)
        endif
        if (nip.ne.1) then
           do i=lft,llt
              vlinc(i)=vlm(i)
           enddo
           call heupd8 (lft,llt,ies(nnm2),ipt,ener)
        else
           call hieupd (lft,llt)
        endif
        if (ipt.eq.nip) call eqos (fval,ies(nnm2),mte,nes,lft,llt)
        go to 208
      endif
      end if
      if (mte.eq.104) then
      call rstrss (lft,llt)
      call f3dm104 (cm,eosp,bqs(nnm2),lft,llt,npc,pld,ia(islcnt(16)),
     . i_mem(mezp(34)))
      go to 207
      endif
      if (mte.eq.105) then
      call rstrss (lft,llt)
      call f3dm105 (cm,bqs(nnm2),npc,pld,lft,llt,ia(n8+2*nlcur+1),
     . ia(n8+3*nlcur+1),ia(islcnt(16)),i_mem(mezp(34)))
      go to 207
      endif
      if (mte.eq.106) then
      call rstrss (lft,llt)
      call f3dm106(cm,bqs(nnm2),tnew,fval,lft,llt,ia(islcnt(16)),
     . i_mem(mezp(34)),
     . ia(n8+2*nlcur+1),ia(n8+3*nlcur+1),a(n9),a(n8))
      go to 207
      endif
      if (mte.eq.188) then
      call rstrss (lft,llt)
      call f3dm188(cm,bqs(nnm2),tnew,fval,lft,llt,ia(islcnt(16)),
     . i_mem(mezp(34)),
     . ia(n8+2*nlcur+1),ia(n8+3*nlcur+1))
      go to 207
      endif
      if (mte.eq.107) then
      call rstrss (lft,llt)
      call f3dm107 (cm,bqs(nnm2),lft,llt,tnew,fval)
      go to 207
      endif
      if (mte.eq.109) then
      call rstrss (lft,llt)
      call f3dm109 (cm,bqs(nnm2),lft,llt,ia(islcnt(16)),i_mem(mezp(34))
     . )
      go to 207
      endif
      if (mte.eq.110) then
      call rstrss (lft,llt)
      call f3dm110 (cm,bqs(nnm2),lft,llt)
      go to 207
      endif
      if (mte.eq.232) then
      call rstrss (lft,llt)
      call f3dm232 (cm,bqs(nnm2),lft,llt)
      go to 207
      endif
      if (mte.eq.241) then
      call rstrss (lft,llt)
      call f3dm241 (cm,bqs(nnm2),lft,llt)
      go to 207
      endif
      if (mte.eq.111) then
      call rstrss (lft,llt)
      call f3dm111 (cm,bqs(nnm2),lft,llt)
      go to 207
      endif
      if (mte.eq.269) then
      call rstrss (lft,llt)
      call f3dm269 (cm,bqs(nnm2),lft,llt,ia(islcnt(16)))
      go to 207
      endif
      if (mte.eq.270) then
      call rstrss (lft,llt)
      call f3dm270 (cm,bqs(nnm2),lft,llt,ia(islcnt(16)),i_mem(mezp(34))
     . )
      go to 207
      endif
      if (mte.eq.271) then
      call rstrss (lft,llt)
      call f3dm271 (cm,bqs(nnm2),lft,llt,ia(islcnt(16)),
     . i_mem(mezp(34)),0,0,0)
      go to 207
      endif
      if (mte.eq.272) then
      call rstrss (lft,llt)
      call f3dm272 (cm,bqs(nnm2),lft,llt)
      go to 207
      endif
      if (mte.eq.274) then
         call f3dm274 (cm,bqs(nnm2),lft,llt,ia(islcnt(16)),
     . i_mem(mezp(34)),eosp)
         go to 207
      endif
      if (mte.eq.291) then
         call f3dm291 (cm,bqs(nnm2),lft,llt,ia(islcnt(16)),
     . i_mem(mezp(34)),eosp)
         go to 207
      endif
      if (mte.eq.275) then
      call rstrss (lft,llt)
      call f3dm275 (cm,bqs(nnm2),lft,llt,ia(islcnt(16)))
      go to 207
      endif
      if (mte.eq.112) then
      call rstrss (lft,llt)
      call f3dm112 (cm,bqs(nnm2),npc,pld,lft,llt,ia(n8+2*nlcur+1),
     . ia(n8+3*nlcur+1),ia(islcnt(16)),i_mem(mezp(34)),a(ifdbck(31)))
      go to 207
      endif
      if (mte.eq.115) then
      call rstrss (lft,llt)
      call f3dm115(cm,bqs(nnm2),lft,llt)
      go to 207
      endif
      if (mte.eq.120) then
      call rstrss (lft,llt)
      call f3dm120(cm,bqs(nnm2),lft,llt,ia(islcnt(16)),i_mem(mezp(34)),
     + ia(n8+2*nlcur+1),
     + ia(n8+3*nlcur+1),x,u(nnm2),ipt,eosp)
      go to 207
      endif
      if (mte.eq.123) then
      call rstrss (lft,llt)
      call f3dm123 (cm,bqs(nnm2),npc,pld,lft,llt,ia(n8+2*nlcur+1),
     . ia(n8+3*nlcur+1),ia(islcnt(16)),i_mem(mezp(34)),
     . ia(ifdbck(31)),ipt,nip,0,
     . nhxbwp(nnm2))
      go to 207
      endif
      if (mte.eq.124) then
      call rstrss (lft,llt)
      call f3dm124 (cm,eosp,bqs(nnm2),npc,pld,lft,llt,ia(n8+2*nlcur+1),
     . ia(n8+3*nlcur+1),ia(islcnt(16)),i_mem(mezp(34)),
     . ipt,nip,nhxbwp(nnm2))
      go to 207
      endif
      if (mte.eq.210) then
      call rstrss (lft,llt)
      call f3dm210 (cm,bqs(nnm2),lft,llt)
      go to 207
      endif
      if (mte.eq.244) then
      call rstrss (lft,llt)
      call f3dm244 (cm,eosp,lft,llt,tnew,bqs(nnm2),ia(islcnt(16)),
     $     i_mem(mezp(34)),
     $     npc,pld,a(n8+2*nlcur+1),a(n8+3*nlcur+1),
     $     ipt,nnm1)
      go to 207
      endif
      if (mte.eq.254) then
      call rstrss (lft,llt)
      call f3dm254 (cm,eosp,cmaux,lft,llt,tnew,bqs(nnm2),ia(islcnt(16)),
     $     i_mem(mezp(34)),
     $     npc,pld,a(n8+2*nlcur+1),a(n8+3*nlcur+1),
     $     ipt,nnm1)
      go to 207
      endif
      if (mte.eq.255) then
      call rstrss (lft,llt)
      call f3dm255 (cm,tnew,bqs(nnm2),npc,pld,lft,llt,
     $     ia(n8+2*nlcur+1),ia(n8+3*nlcur+1),ia(islcnt(16)),
     $     i_mem(mezp(34)),ipt,nip,
     $     nhxbwp(nnm2))
      go to 207
      endif
      if (mte.eq.223) then
      call rstrss (lft,llt)
      lcmx=lc2+nint(cm(48,mxe))
      call f3dm223 (cm,a(lcmx),bqs(nnm2),lft,llt,1,1)
      go to 207
      endif
      if (mte.eq.229) then
      call rstrss (lft,llt)
      lcmx=lc2+nint(cm(48,mxe))
      call f3dm229 (cm,a(lcmx),bqs(nnm2),lft,llt,ipt,nip,nnm1)
      go to 207
      endif
      if (mte.eq.233) then
      call rstrss (lft,llt)
      call f3dm233 (cm,bqs(nnm2),lft,llt,ia(islcnt(16)),
     . i_mem(mezp(34)),npc,pld,
     . ia(n8+2*nlcur+1),ia(n8+3*nlcur+1),ipt)
      go to 207
      endif
      if (mte.eq.263) then
      call rstrss (lft,llt)
      call f3dm263 (cm,bqs(nnm2),lft,llt,ia(islcnt(16)),
     . i_mem(mezp(34)),npc,pld,
     . ia(n8+2*nlcur+1),ia(n8+3*nlcur+1),ipt)
      go to 207
      endif
      if (mte.eq.256) then
      call f3dm256 (cm,bqs(nnm2),lft,llt)
      go to 207
      endif
      if (mte.eq.221) then
      call rstrss (lft,llt)
      call f3dm221 (cm,eosp,bqs(nnm2),lft,llt,1,1)
      go to 207
      endif
      if (mte.eq.224) then
      call rstrss (lft,llt)
      call f3dm224 (cm,eosp,bqs(nnm2),npc,pld,lft,llt,ia(n8+2*nlcur+1),
     . ia(n8+3*nlcur+1),ia(islcnt(16)),i_mem(mezp(34)),ipt,nes)
      if (nes.eq.0) then
        go to 207
      else
        if (ipt.eq.nip) then
          call sueos (eosp,mte,nes,lft,llt)
          iffg=0
          if (nip.eq.1.and.ihgf.eq.1.and.ihg.eq.6)
     .      call hrgbbc (cm,ia(islcnt(16)),i_mem(mezp(34)),
     .      mte,lft,llt,iffg,x,auxvec,1)
          call bulkq (ibq,nhxbwp(nnm2),lft,llt)
        endif
        if (nip.ne.1) then
           do i=lft,llt
              vlinc(i)=vlm(i)
           enddo
           call heupd8 (lft,llt,ies(nnm2),ipt,ener)
        else
           call hieupd (lft,llt)
        endif
        if (ipt.eq.nip) call eqos (fval,ies(nnm2),mte,nes,lft,llt)
        go to 208
      endif
      endif
      if (mte.eq.264) then
      call rstrss (lft,llt)
      call f3dm264 (cm,eosp,bqs(nnm2),npc,pld,lft,llt,ia(n8+2*nlcur+1),
     . ia(n8+3*nlcur+1),ia(islcnt(16)),i_mem(mezp(34)),nes)
      go to 207
      endif
      if (mte.eq.225) then
      call rstrss (lft,llt)
      call rstrn225(lft,llt)
      call f3dm225 (cm,bqs(nnm2),npc,pld,lft,llt,ia(n8+2*nlcur+1),
     . ia(n8+3*nlcur+1),ia(islcnt(16)),i_mem(mezp(34)))
      go to 207
      endif
      if (mte.eq.228) then
      call rstrss (lft,llt)
      call f3dm228 (cm,bqs(nnm2),npc,pld,lft,llt,ia(n8+2*nlcur+1),
     . ia(n8+3*nlcur+1),ia(islcnt(16)),i_mem(mezp(34)))
      go to 207
      endif
      if (mte.eq.155) then
      call rstrss (lft,llt)
      call f3dm155(cm,bqs(nnm2),npc,pld,lft,llt,ia(n8+2*nlcur+1),
     . ia(n8+3*nlcur+1),ia(islcnt(16)),i_mem(mezp(34)),
     . ipt,nip,nhxbwp(nnm2))
      if (ipt.eq.nip) then
         call sueos (eosp,mte,nes,lft,llt)
         iffg=0
         if (nip.eq.1.and.ihgf.eq.1.and.ihg.eq.6)
     .     call hrgbbc (cm,ia(islcnt(16)),i_mem(mezp(34)),
     .     mte,lft,llt,iffg,x,auxvec,1)
         call bulkq (ibq,nhxbwp(nnm2),lft,llt)
      endif
      if (nip.ne.1) then
         do i=lft,llt
            vlinc(i)=vlm(i)
         enddo
         call heupd8 (lft,llt,ies(nnm2),ipt,ener)
      else
         call hieupd (lft,llt)
      endif
      if (ipt.eq.nip) call eqos (fval,ies(nnm2),mte,nes,lft,llt)
      go to 208
      endif
      if (mte.eq.128) then
      call rstrss (lft,llt)
      call f3dm128(cm,bqs(nnm2),ihgp,lft,llt)
      go to 207
      endif
      if (mte.eq.144) then
      call rstrss (lft,llt)
      call f3dm144 (cm,bqs(nnm2),lft,llt,ia(islcnt(16)),i_mem(mezp(34))
     . )
      go to 207
      endif
      if (mte.eq.145) then
      call rstrss (lft,llt)
      call f3dm145 (cm,bqs(nnm2),lft,llt,nhxbwp(nnm2))
      go to 207
      endif
      if (mte.eq.152) then
      call rstrss (lft,llt)
      call f3dm152 (cm,bqs(nnm2),lft,llt,ia(islcnt(16)),
     . i_mem(mezp(34)),tnew,fval)
      go to 207
      endif
      if (mte.eq.153) then
      call rstrss (lft,llt)
      call rstrn153 (lft,llt)
      lthrpr=nint(cm(48,mxe))+lc2
      call f3dm153 (cm,bqs(nnm2),npc,pld,lft,llt)
      go to 207
      endif
      if (mte.eq.154) then
      call rstrss (lft,llt)
      call f3dm154 (cm,bqs(nnm2),lft,llt)
      go to 207
      endif
      if (mte.eq.161) then
      call rstrss (lft,llt)
      call f3dm161 (mtype,cm,bqs(nnm2),lft,llt,nnm1,auxvec,dm_h_lochv,
     . nhxbwp,dm_ixh,dm_isadj)
      go to 207
      endif
      if (mte.eq.162) then
      call rstrss (lft,llt)
      lcmaux=nint(cm(48,mxe))+lc2
      call f3dm162 (mtype,cm,bqs(nnm2),lft,llt,nnm1,auxvec,dm_h_lochv,
     . nhxbwp,dm_ixh,dm_isadj,ia(lcmaux))
      go to 207
      endif
      if (mte.eq.163) then
      call rstrss (lft,llt)
      call f3dm163 (cm,bqs(nnm2),npc,pld,lft,llt,ia(islcnt(16)),
     . i_mem(mezp(34)),
     . ia(n8+2*nlcur+1),ia(n8+3*nlcur+1),ihgp)
      go to 207
      endif
      if (mte.eq.167) then
      call rstrss (lft,llt)
      call f3dm167 (cm,bqs(nnm2),lft,llt)
      go to 207
      endif
      if (mte.eq.168) then
      call rstrss (lft,llt)
      call f3dm168 (cm,bqs(nnm2),lft,llt)
      go to 207
      endif
      if (mte.eq.169) then
      call rstrss (lft,llt)
      call f3dm169(cm,bqs(nnm2),lft,llt,i_mem(mezp(191)),nip,ipt,
     &   a(islcnt(16)),nhxbwp(nnm2))
      go to 207
      endif
      if (mte.eq.173) then
      call rstrss (lft,llt)
      call f3dm173(cm,bqs(nnm2),lft,llt,x,fval,npc,pld,ipt,eosp,
     &              0,idummy,0)
      go to 207
      endif
      if (mte.eq.189) then
      call f3dm189(cm,bqs(nnm2),ihgp,lft,llt,
     .             a(islcnt(16)),i_mem(mezp(34)),tnew,fval)
      go to 207
      endif
      if (mte.eq.192) then
      call rstrss (lft,llt)
      call f3dm192(cm,bqs(nnm2),lft,llt,x,nhxbwp(nnm2))
      call m192_store_dtx (lft,llt,0)
      go to 207
      endif
      if (mte.eq.193) then
      call rstrss (lft,llt)
      call f3dm193(cm,bqs(nnm2),lft,llt,x)
      go to 207
      endif
      if (mte.eq.198) then
      call rstrss (lft,llt)
      call f3dm198(cm,bqs(nnm2),lft,llt,x,fval)
      go to 207
      endif
      if (mte.eq.199) then
      call rstrss (lft,llt)
      call f3dm199 (cm,bqs(nnm2),lft,llt,npc,pld,ia(islcnt(16)),
     .     i_mem(mezp(34)),ia(n8+2*nlcur+1),ia(n8+3*nlcur+1))
      go to 207
      endif
      if(mte.eq.200) then
      call rstrss (lft,llt)
      call f3dm200 (cm,npc,pld,eosp,mte,nes,ibq,ies(nnm2),fval,
     .             nhxbwp(nnm2),lft,llt)
      go to 207
      endif
      if (mte.eq.251) then
      call rstrss (lft,llt)
      call f3dm251(cm,bqs(nnm2),npc,pld,lft,llt,ia(n8+2*nlcur+1),
     . ia(n8+3*nlcur+1),ia(islcnt(16)),i_mem(mezp(34)),
     . ia(ifdbck(31)),ipt,nip,nhxbwp(nnm2))
      go to 207
      endif
      if (mte.eq.252) then
      call rstrss (lft,llt)
      call f3dm252 (cm,bqs(nnm2),lft,llt,ia(islcnt(16)),
     . i_mem(mezp(34)),
     . ia(n8+2*nlcur+1),ia(n8+3*nlcur+1),nhxbwp(nnm2),a(n8),a(n9),ipt)
      go to 207
      endif
      if (mte.eq.259) then
      call rstrss (lft,llt)
      lcm2=lc2+nint(cm(7,mxe)-1.)
      call f3dm259 (cm,npc,pld,eosp,mte,nes,ibq,ies(nnm2),fval,
     .             nhxbwp(nnm2),a(lcm2),lft,llt,bqs(nnm2),ipt,nip,nnm1)
      go to 207
      endif
      endif
  130 call rstrss (lft,llt)
      call f3dm11 (cm,lft,llt)
      if (ipt.eq.nip) then
         call sueos (eosp,mte,nes,lft,llt)
         call bulkq (ibq,nhxbwp(nnm2),lft,llt)
      endif
      if (nip.ne.1) then
         do i=lft,llt
            vlinc(i)=vlm(i)
         enddo
         call heupd8 (lft,llt,ies(nnm2),ipt,ener)
      else
         call hieupd (lft,llt)
      endif
      if (ipt.eq.nip) call eqos (fval,ies(nnm2),mte,nes,lft,llt)
      go to 208
  140 call rstrss (lft,llt)
      call f3dm12 (cm,bqs(nnm2),0,lft,llt)
      go to 207
  150 call rstrss (lft,llt)
      call f3dm13 (cm,bqs(nnm2),ibq,nhxbwp(nnm2),lft,llt,1)
      go to 207
  160 call rstrss (lft,llt)
      call f3dm14 (cm,bqs(nnm2),lft,llt)
      go to 207
  170 call rstrss (lft,llt)
      call f3dm15 (cm,lft,llt,1.)
      if (ipt.eq.nip) then
         call sueos (eosp,mte,nes,lft,llt)
         call bulkq (ibq,nhxbwp(nnm2),lft,llt)
      endif
      if (nip.ne.1) then
         do i=lft,llt
            vlinc(i)=vlm(i)
         enddo
         call heupd8 (lft,llt,ies(nnm2),ipt,ener)
      else
         call hieupd (lft,llt)
      endif
      if (ipt.eq.nip) call eqos (fval,ies(nnm2),mte,nes,lft,llt)
      go to 208
  180 call rstrss (lft,llt)
      call f3dm16 (cm,npc,pld,eosp,mte,nes,ibq,ies(nnm2),fval,
     .             nhxbwp(nnm2),lft,llt,ipt,nip)
      go to 207
  190 call rstrss (lft,llt)
      call f3dm17 (cm,x,nnm1,lft,llt,nhxbwp(nnm2),dm_ncrshf)
      if (ipt.eq.nip) then
         call sueos (eosp,mte,nes,lft,llt)
         call bulkq (ibq,nhxbwp(nnm2),lft,llt)
      endif
      if (nip.ne.1) then
         do i=lft,llt
            vlinc(i)=vlm(i)
         enddo
         call heupd8 (lft,llt,ies(nnm2),ipt,ener)
      else
         call hieupd (lft,llt)
      endif
      if (ipt.eq.nip) call eqos (fval,ies(nnm2),mte,nes,lft,llt)
      call fzero (lft,llt)
      go to 208
  192 call rstrss (lft,llt)
      call f3dm18 (cm,bqs(nnm2),lft,llt)
      go to 207
  194 call rstrss (lft,llt)
      call f3dm19 (cm,bqs(nnm2),npc,pld,lft,llt,ia(islcnt(16)))
      go to 207
  196 call f3dm21(cm,eosp,bqs(nnm2),tnew,fval,ihgp,lft,llt,1,1,
     .            a(islcnt(16)),i_mem(mezp(34)),a(n8+2*nlcur+1),
     .            a(n8+3*nlcur+1))
      go to 207
  197 call rstrss (lft,llt)
      call f3dm22(cm,bqs(nnm2),lft,llt)
      go to 207
  198 lthrpr=nint(cm(48,mxe))+lc2
      call f3dm23(cm,bqs(nnm2),tnew,fval,ia(lthrpr),ihgp,lft,llt)
      go to 207
  199 call rstrss (lft,llt)
      call f3dm24(cm,bqs(nnm2),npc,pld,lft,llt,ia(n8+2*nlcur+1),
     . ia(n8+3*nlcur+1),ia(islcnt(16)),i_mem(mezp(34)),
     . ia(ifdbck(31)),ipt,nip,
     . nhxbwp(nnm2))
      go to 207
  200 call rstrss (lft,llt)
      call f3dm25(cm,lft,llt,nhxbwp(nnm2))
      go to 207
  204 call rstrss (lft,llt)
      if (is17loc.ne.0)
     .call s26maini(cm,        npc,pld,lft,llt,ia(islcnt(16)),
     .i_mem(mezp(34)))
      call f3dm26(cm,bqs(nnm2),npc,pld,lft,llt,ia(islcnt(16)),
     . i_mem(mezp(34)))
      go to 207
  205 call rstrss (lft,llt)
      call f3dm27(cm,bqs(nnm2),ihgp,lft,llt)
  207 continue
c
c     mat_add_erosion
c
      if (nessav.ne.0.and.(idmgmdl.lt.0.or.idmgmdl.eq.2)) then
        do i=lft,llt
          sigmi=(ax(i,1)+ax(i,2)+ax(i,3))/3.
          ax(i,1)=ax(i,1)-sigmi+sigm(i)
          ax(i,2)=ax(i,2)-sigmi+sigm(i)
          ax(i,3)=ax(i,3)-sigmi+sigm(i)
          sigm(i)=sigmi
        enddo
      endif
c
      if(idmgmdl.eq.4) then
        call damgen2_sld(lft,llt,ipt,a(islcnt(16)),i_mem(mezp(34)),
     .   x,u(nnm2),ia(n8+2*nlcur+1),ia(n8+3*nlcur+1),a(n8),a(n9),
     .   nnm1,ies(nnm2),nhxbwp,mte,0)
      elseif(idmgmdl.eq.2) then
        call dmgadd2_sld(damag(1,mxt(lft)),lft,llt,ipt,a(islcnt(16)),
     .   i_mem(mezp(34)),x,u(nnm2),ia(n8+2*nlcur+1),ia(n8+3*nlcur+1),
     .   a(n8),a(n9),nnm1,ies(nnm2),nhxbwp,dm_ncrshf,
     .   ax(1,1),ax(1,2),ax(1,3),ax(1,4),ax(1,5),ax(1,6),ax(1,7),
     .   ax(1,8),0)
      elseif(idmgmdl.lt.0) then
        call dmgadd(damag(1,mxt(lft)),lft,llt,a(islcnt(16)),
     .   i_mem(mezp(34)),x,v,ipt,1,1,2,strains(1,nnm2),0.,nnm1,nhxbwp,
     .   ax(1,1),ax(1,2),ax(1,3),ax(1,4),ax(1,5),ax(1,6),ax(1,7),
     .   ax(1,8))
      endif
c
      if (nessav.ne.0.and.(idmgmdl.lt.0.or.idmgmdl.eq.2)) then
        do i=lft,llt
          sigmi=(ax(i,1)+ax(i,2)+ax(i,3))/3.
          ax(i,1)=ax(i,1)-sigmi+sigm(i)
          ax(i,2)=ax(i,2)-sigmi+sigm(i)
          ax(i,3)=ax(i,3)-sigmi+sigm(i)
        enddo
      endif
c
c     Compute bulk viscosity
c
      if (mte.ne.100) then
         if (ipt.eq.1) call bulkq (ibq,nhxbwp(nnm2),lft,llt)
      else
         if (ipt.eq.1) call bulkq_sw (ibq,nhxbwp(nnm2),lft,llt)
      endif
c
      if (mte.eq.192) call m192_store_dtx (lft,llt,1)
c
c     Update internal energy and bulk stress
c
      if (isolvr(18).eq.0) then
         do i=lft,llt
            ies(nnm2+i-1)=ies(nnm2+i-1)+
     1           .5*vlm(i)*(einc(i)+dt1siz(i)*dd(i)*qp(i))
            bqs(nnm2+i-1)=qp(i)
         enddo
      endif
 208  continue
c
c     borrvall, thermal expansion
c
      if (ithxpid.ne.0) then
         call sbthstr(lft,llt,1)
         if (icompf(mte).eq.mte)
     .        call dvthjc(lft,llt)
      endif
c
      if (lenvec8.ne.0) then
c
c     Accuracy option is on, rotate stress from n+1/2 to n+1
c
         if (iabs(mhyper(mte)).ne.57) then
c
            call rstrss (lft,llt)
c
c     Rotation of back stress & similar tensors
c
            if (mte.eq.6) then
               call rstrnn   (lft,llt,1)
            elseif (mte.eq.3.or.mte.eq.51.or.
     .              mte.eq.52.or.mte.eq.141.or.mte.eq.165) then
               call rstrn    (lft,llt)
            elseif (mte.eq.225 ) then
               call rstrn225 (lft,llt)
            elseif (mte.eq.61) then
               call rstrnn61 (lft,llt,2)
            elseif (mte.eq.62) then
               call rstr62   (lft,llt)
            elseif (mte.eq.79) then
               call rstr79   (lft,llt)
            elseif (mte.eq.89) then
               call rtensor(lft,llt,20,1)
               call rtensor(lft,llt,29,0)
            elseif (mte.eq.96) then
               call rstrn3   (lft,llt)
               call rstrn4   (lft,llt)
            elseif (mte.eq.153 ) then
               call rstrn153 (lft,llt)
            endif
         endif
      endif
c
c     No interior contact supported
c
      if (ioshl(68).gt.0) then
c
c     Adjust strains for *INITIAL_STRESS_SECTION
c
         call acmfch_01 (cm,mte,cs_icsd,cs_mnmx,cs_nhhxs,cs_nhx,
     $        numcsd,nnm1,lft,llt,auxvec,fval,ia(ioshl(69))
     $        ,ia(ioshl(70)), cs_rdsav,
     $        ia(ioshl(71)),ies(nnm2)
     $        ,nmmat,0,0, a(n8+nlcur+1),ia(ioshl(1059)),a(ioshl(1060))
     $        ,ax(1,1),ax(1,2),ax(1,3),ax(1,4),ax(1,5),ax(1,6)
     $        ,ax(1,7),ax(1,8))
      endif
c
      if (is17loc.ne.0.or.ihgf.eq.3) then
c
c     Constitutive matrix
c
         call cmats3d (cm,lft,llt,mte,npc,pld,ia(islcnt(16)),
     .    i_mem(mezp(34)),mxe,nnm1,
     .    ia(1),1,0,1,0,1.,1.,0.)
c
c     ALE not supported
c
      endif
c
      if (ihgf.eq.3) then
         if (ipt.eq.1) then
            do j=1,21
               do i=lft,llt
                  uehisv(i,nhsv+j)=uehisv(i,nhsv+j-21)
               enddo
            enddo
            index=1
            do j=1,6
               do k=1,j
                  do i=lft,llt
                     uehisv(i,nhsv+index-21)=dsave(i,j,k)*vlm(i)
                  enddo
                  index=index+1
               enddo
            enddo
         else
            index=1
            do j=1,6
               do k=1,j
                  do i=lft,llt
                     uehisv(i,nhsv+index-21)=uehisv(i,nhsv+index-21)+
     .                    dsave(i,j,k)*vlm(i)
                  enddo
                  index=index+1
               enddo
            enddo
         endif
         if (ipt.eq.nip) then
            fact=.5
            dsum=0.
            do j=1,21
               dsum=dsum+abs(uehisv(lft,nhsv+j))
            enddo
            if (dsum.lt.1.e-20) fact=1.
            do j=1,21
               do i=lft,llt
                  uehisv(i,nhsv+j)=
     .                 fact*(uehisv(i,nhsv+j)+uehisv(i,nhsv+j-21))
               enddo
            enddo
         endif
      endif
c
c     mat_add_erosion
c
      if (idmgmdl.ne.0) then
        call failtst_sld (damag(1,mxt(lft)),lenmaeh,lft,llt,
     .   auxmeh(lavmaeh),ipt,nip,ia(islcnt(16)),i_mem(mezp(34)),mte)
        lavmaeh=lavmaeh+ioshl(485)
      endif
c
c     Rayleigh damping
c
      if (abs(betav).gt.0.000) then
         if (lenvec(5).eq.1) then
            call rydmp5 (lft,llt,ax(1,nmtcon-5),ax(1,nmtcon-4),
     .           ax(1,nmtcon-3),ax(1,nmtcon-2),ax(1,nmtcon-1),
     .           ax(1,nmtcon),ies(nnm2),2,ax)
         endif
      endif
c
c     mat_add_erosion
c
      if (idmgmdl.gt.1) call mad_cpyhis(lft,llt,2)
c
c     Scatter history variables
c
      if (isolvr(18).eq.0) then
         do j=1,nmtcon
            do i=lft,llt
               auxvec(lavloc+nc*(i-lft)+(j-1))=ax(i,j)
            enddo
         enddo
      endif
c
c     icpf.ne.0 not supported
c
c     tied nodes with failure not supported
c
c     Rayleigh damping
c
      if (abs(betav).gt.0.000) then
         if (lenvec(5).eq.0) then
            call rydmp6 (lft,llt)
         else
            call rydmp4 (lft,llt,ax(1,nmtcon-5),ax(1,nmtcon-4),
     .           ax(1,nmtcon-3),ax(1,nmtcon-2),ax(1,nmtcon-1),
     .           ax(1,nmtcon))
         endif
      endif
c
      if (ihgf.eq.1.and.nip.eq.1) then
c
         if (ihg.ne.3.and.ihg.ne.5.and.ihg.ne.6) then
            if (ihg.eq. 2.or.ihg.eq.4) then
               if (lenvec8.eq.0.or.ihg.eq.2) then
                  call hrgfb (ihg,lft,llt,hgener,hgforc(1,nnm3),iehgfg)
               else
                  call hrgfbp(ihg,lft,llt,hgener,hgforc(1,nnm3),iehgfg)
               endif
            else
               call hrgmd (lft,llt,hgener,hgforc(1,nnm3),iehgfg)
            endif
         else
            if (ihg.eq.6) then
               iffg=0
               call hrgbbc (cm,ia(islcnt(16)),i_mem(mezp(34)),
     .          mte,lft,llt,iffg,x,
     .          auxvec,1)
               call hrgbb (lft,llt,hgener,hgforc(1,nnm3),iehgfg,mte,0)
            else
               if (lenvec8.eq.0.or.ihg.eq.3) then
                  call hrgffb (ihg,lft,llt,hgener,hgforc(1,nnm3),iehgfg)
               else
                  call hrgffbp(ihg,lft,llt,hgener,hgforc(1,nnm3),iehgfg)
               endif
            endif
         endif
c
      else
c
         do i=lft,llt
            p11(i)=0.0
            p12(i)=0.0
            p13(i)=0.0
            p14(i)=0.0
            p15(i)=0.0
            p16(i)=0.0
            p17(i)=0.0
            p18(i)=0.0
            p21(i)=0.0
            p22(i)=0.0
            p23(i)=0.0
            p24(i)=0.0
            p25(i)=0.0
            p26(i)=0.0
            p27(i)=0.0
            p28(i)=0.0
            p31(i)=0.0
            p32(i)=0.0
            p33(i)=0.0
            p34(i)=0.0
            p35(i)=0.0
            p36(i)=0.0
            p37(i)=0.0
            p38(i)=0.0
         enddo
c
      endif
c
c     Internal force assembly
c
      call usrsld_frc(nxdof,lft,llt)
c
      if (is17loc.ne.0) then
c
c     Compute tangent stiffness matrix
c
         if (nip.eq.1.and.ihgf.eq.1.and.isolvr(91).ne.2) then
c
c     Store hourglass forces or it will be overwritten
c
            do i=lft,llt
               x1f(i)=p11(i)
               x2f(i)=p12(i)
               x3f(i)=p13(i)
               x4f(i)=p14(i)
               x5f(i)=p15(i)
               x6f(i)=p16(i)
               x7f(i)=p17(i)
               x8f(i)=p18(i)
               y1f(i)=p21(i)
               y2f(i)=p22(i)
               y3f(i)=p23(i)
               y4f(i)=p24(i)
               y5f(i)=p25(i)
               y6f(i)=p26(i)
               y7f(i)=p27(i)
               y8f(i)=p28(i)
               z1f(i)=p31(i)
               z2f(i)=p32(i)
               z3f(i)=p33(i)
               z4f(i)=p34(i)
               z5f(i)=p35(i)
               z6f(i)=p36(i)
               z7f(i)=p37(i)
               z8f(i)=p38(i)
            enddo
            call hrgbbk(ske,lft,llt)
            do i=lft,llt
               p11(i)=x1f(i)
               p12(i)=x2f(i)
               p13(i)=x3f(i)
               p14(i)=x4f(i)
               p15(i)=x5f(i)
               p16(i)=x6f(i)
               p17(i)=x7f(i)
               p18(i)=x8f(i)
               p21(i)=y1f(i)
               p22(i)=y2f(i)
               p23(i)=y3f(i)
               p24(i)=y4f(i)
               p25(i)=y5f(i)
               p26(i)=y6f(i)
               p27(i)=y7f(i)
               p28(i)=y8f(i)
               p31(i)=z1f(i)
               p32(i)=z2f(i)
               p33(i)=z3f(i)
               p34(i)=z4f(i)
               p35(i)=z5f(i)
               p36(i)=z6f(i)
               p37(i)=z7f(i)
               p38(i)=z8f(i)
            enddo
         endif
         if (isolvr(91).ne.2) call usrsld_kmt(ske,nxdof,lft,llt)
         isolvr21=isolvr(21)
         if (isolvr21.eq.3) isolvr21=i_mem(mezp(209)+mxt(lft)-1)
         if (isolvr21.eq.1) call usrsld_kgm(ske,nxdof,lft,llt)
c
      endif
c
      enddo
c
      else
c
c     Resultant element
c
         do i=lft,llt
            cb(i)=cm(1,mxe)
            p11(i)=0.0
            p12(i)=0.0
            p13(i)=0.0
            p14(i)=0.0
            p15(i)=0.0
            p16(i)=0.0
            p17(i)=0.0
            p18(i)=0.0
            p21(i)=0.0
            p22(i)=0.0
            p23(i)=0.0
            p24(i)=0.0
            p25(i)=0.0
            p26(i)=0.0
            p27(i)=0.0
            p28(i)=0.0
            p31(i)=0.0
            p32(i)=0.0
            p33(i)=0.0
            p34(i)=0.0
            p35(i)=0.0
            p36(i)=0.0
            p37(i)=0.0
            p38(i)=0.0
         enddo
         call bulkq (ibq,nhxbwp(nnm2),lft,llt)
         call usrsld_h(ietyp,cmusr(9,mxe),lmc,nhsv,nxdof,lft,llt,ihgf,
     1        ies(nnm2))
c
      endif
c
      if (ihgf.eq.2.or.ihgf.eq.3) then
c
c     User defined hourglass force requested
c
         do i=lft,llt
            hgener(i)=0.
         enddo
         call usrsld_h(ietyp,cmusr(9,mxe),lmc,nhsv,nxdof,lft,llt,ihgf,
     1        hgener)
c
      endif
c
      if (lenvec(1).ne.0) then
         call usrsld_fs(nxdof,rhssav(1,nnm1+1),lft,llt)
      else
         call usrsld_ft(nxdof,fv,lft,llt)
      endif
c
      nes=nessav
c
c     Spotweld failure not supported
c
      if (is17loc.ne.0) then
c
c     Compute tangent stiffness matrix
c
         ndofpn=3
         nsnd=0
         if (nxdof.ne.0) nsnd=(nxdof-1)/3+1
         nnpke=8+8*nsnd
         imlft=lft
         imllt=llt
         melemt=llt-lft+1
         do i=lft,llt
            lnodim(i,1)=ix1(i)
            lnodim(i,2)=ix2(i)
            lnodim(i,3)=ix3(i)
            lnodim(i,4)=ix4(i)
            lnodim(i,5)=ix5(i)
            lnodim(i,6)=ix6(i)
            lnodim(i,7)=ix7(i)
            lnodim(i,8)=ix8(i)
         enddo
         do j=1,nsnd
           do i=lft,llt
             do k=1,8
               ij=8+8*(j-1)+k
               lnodim(i,ij)=ixsld(i,k,j)
             enddo
           enddo
         enddo
c
         if (isolvr(77).ne.3.or.nip.ne.0) then
         call imasem
         else
         call imasem_unsym
         endif
c
      endif
c
      return
      end
      subroutine usrsld_b2b(itaj,nxdof,wgt,lft,llt)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     transform b-matrix
c
      include 'nlqparm'
      include 'nhisparm.inc'
      common/numcpuloc/lenvec8,lenvech
      common/prescloc/voltot(nlq)
      common/bel7loc/ixsld(nlq,8,5),ixshl(nlq,4,5)
     .,bmtrx(nlq,3,3,8*(3+NXDOFUE)),
     . cmtrx(nlq,3,3,8*(3+NXDOFUE)),xdof(nlq,8,NXDOFUE),
     . dxdof(nlq,8,NXDOFUE),xhdof(nlq,8,NXDOFUE),
     . bvec(nlq,8*(3+NXDOFUE)),cvec(nlq,8*(3+NXDOFUE)),
     . frc(nlq,8*(3+NXDOFUE)),
     . stiff(nlq,64*(3+NXDOFUE)*(3+NXDOFUE)),
     . sigv(nlq),
     . gmtrx(nlq,3,3),hmtrx(nlq,3,3),cvltot(nlq),
     . xh1(nlq),xh2(nlq),xh3(nlq),xh4(nlq),
     . xh5(nlq),xh6(nlq),xh7(nlq),xh8(nlq),
     . yh1(nlq),yh2(nlq),yh3(nlq),yh4(nlq),
     . yh5(nlq),yh6(nlq),yh7(nlq),yh8(nlq),
     . zh1(nlq),zh2(nlq),zh3(nlq),zh4(nlq),
     . zh5(nlq),zh6(nlq),zh7(nlq),zh8(nlq),
     . hl11(nlq),hl12(nlq),hl13(nlq),hl21(nlq),hl22(nlq),
     . hl23(nlq),hl31(nlq),hl32(nlq),hl33(nlq),
     . xx1(nlq),xx2(nlq),xx3(nlq),xx4(nlq),
     . xx5(nlq),xx6(nlq),xx7(nlq),xx8(nlq),
     . yy1(nlq),yy2(nlq),yy3(nlq),yy4(nlq),
     . yy5(nlq),yy6(nlq),yy7(nlq),yy8(nlq),
     . zz1(nlq),zz2(nlq),zz3(nlq),zz4(nlq),
     . zz5(nlq),zz6(nlq),zz7(nlq),zz8(nlq),vlm(nlq)
c
c$omp threadprivate (/numcpuloc/)
c$omp threadprivate (/prescloc/)
c$omp threadprivate (/bel7loc/)
      if (itaj.eq.0) then
         call usrsld_b2b_old(nxdof,wgt,lft,llt)
         return
      endif
c
      if (lenvec8.ne.0) then
c
      do i=lft,llt
c
         vlm(i)=gmtrx(i,1,1)
         voltot(i)=voltot(i)+vlm(i)*wgt
c
      enddo
c
      endif
c
      do i=lft,llt
c
         vlm(i)=hmtrx(i,1,1)
         cvltot(i)=cvltot(i)+vlm(i)*wgt
c
      enddo
c
      if (lenvec8.eq.0) then
         do i=lft,llt
            voltot(i)=cvltot(i)
            gmtrx(i,1,1)=hmtrx(i,1,1)
         enddo
      endif
c
c     Compute "real" b-matrix
c
      if (lenvec8.eq.0) then
         do l=1,8*(3+NXDOFUE)
            do k=1,3
               do j=1,3
                  do i=lft,llt
                     bmtrx(i,j,k,l)=cmtrx(i,j,k,l)
                  enddo
               enddo
            enddo
         enddo
      endif
c
      return
      end
      subroutine usrsld_b2b_old(nxdof,wgt,lft,llt)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     transform b-matrix
c
      include 'nlqparm'
      include 'nhisparm.inc'
      common/numcpuloc/lenvec8,lenvech
      common/bel7loc/ixsld(nlq,8,5),ixshl(nlq,4,5)
     .,bmtrx(nlq,3,3,8*(3+NXDOFUE)),
     . cmtrx(nlq,3,3,8*(3+NXDOFUE)),xdof(nlq,8,NXDOFUE),
     . dxdof(nlq,8,NXDOFUE),xhdof(nlq,8,NXDOFUE),
     . bvec(nlq,8*(3+NXDOFUE)),cvec(nlq,8*(3+NXDOFUE)),
     . frc(nlq,8*(3+NXDOFUE)),
     . stiff(nlq,64*(3+NXDOFUE)*(3+NXDOFUE)),
     . sigv(nlq),
     . gmtrx(nlq,3,3),hmtrx(nlq,3,3),cvltot(nlq),
     . xh1(nlq),xh2(nlq),xh3(nlq),xh4(nlq),
     . xh5(nlq),xh6(nlq),xh7(nlq),xh8(nlq),
     . yh1(nlq),yh2(nlq),yh3(nlq),yh4(nlq),
     . yh5(nlq),yh6(nlq),yh7(nlq),yh8(nlq),
     . zh1(nlq),zh2(nlq),zh3(nlq),zh4(nlq),
     . zh5(nlq),zh6(nlq),zh7(nlq),zh8(nlq),
     . hl11(nlq),hl12(nlq),hl13(nlq),hl21(nlq),hl22(nlq),
     . hl23(nlq),hl31(nlq),hl32(nlq),hl33(nlq),
     . xx1(nlq),xx2(nlq),xx3(nlq),xx4(nlq),
     . xx5(nlq),xx6(nlq),xx7(nlq),xx8(nlq),
     . yy1(nlq),yy2(nlq),yy3(nlq),yy4(nlq),
     . yy5(nlq),yy6(nlq),yy7(nlq),yy8(nlq),
     . zz1(nlq),zz2(nlq),zz3(nlq),zz4(nlq),
     . zz5(nlq),zz6(nlq),zz7(nlq),zz8(nlq),vlm(nlq)
      common/prescloc/voltot(nlq)
c
c$omp threadprivate (/prescloc/)
c$omp threadprivate (/numcpuloc/)
c$omp threadprivate (/bel7loc/)
      if (lenvec8.ne.0) then
c
      do i=lft,llt
c
         vlm(i)=gmtrx(i,1,1)*(gmtrx(i,2,2)*gmtrx(i,3,3)-
     1        gmtrx(i,3,2)*gmtrx(i,2,3))+
     2        gmtrx(i,2,1)*(gmtrx(i,3,2)*gmtrx(i,1,3)-
     3        gmtrx(i,1,2)*gmtrx(i,3,3))+
     4        gmtrx(i,3,1)*(gmtrx(i,1,2)*gmtrx(i,2,3)-
     5        gmtrx(i,2,2)*gmtrx(i,1,3))
         voltot(i)=voltot(i)+vlm(i)*wgt
         gjac=1./vlm(i)
         g11i=gmtrx(i,2,2)*gmtrx(i,3,3)-gmtrx(i,2,3)*gmtrx(i,3,2)
         g12i=gmtrx(i,3,2)*gmtrx(i,1,3)-gmtrx(i,3,3)*gmtrx(i,1,2)
         g13i=gmtrx(i,1,2)*gmtrx(i,2,3)-gmtrx(i,1,3)*gmtrx(i,2,2)
         g21i=gmtrx(i,2,3)*gmtrx(i,3,1)-gmtrx(i,2,1)*gmtrx(i,3,3)
         g22i=gmtrx(i,3,3)*gmtrx(i,1,1)-gmtrx(i,3,1)*gmtrx(i,1,3)
         g23i=gmtrx(i,1,3)*gmtrx(i,2,1)-gmtrx(i,1,1)*gmtrx(i,2,3)
         g31i=gmtrx(i,2,1)*gmtrx(i,3,2)-gmtrx(i,2,2)*gmtrx(i,3,1)
         g32i=gmtrx(i,3,1)*gmtrx(i,1,2)-gmtrx(i,3,2)*gmtrx(i,1,1)
         g33i=gmtrx(i,1,1)*gmtrx(i,2,2)-gmtrx(i,1,2)*gmtrx(i,2,1)
         gmtrx(i,1,1)=gjac*g11i
         gmtrx(i,2,1)=gjac*g21i
         gmtrx(i,3,1)=gjac*g31i
         gmtrx(i,1,2)=gjac*g12i
         gmtrx(i,2,2)=gjac*g22i
         gmtrx(i,3,2)=gjac*g32i
         gmtrx(i,1,3)=gjac*g13i
         gmtrx(i,2,3)=gjac*g23i
         gmtrx(i,3,3)=gjac*g33i
c
      enddo
c
      endif
c
      do i=lft,llt
c
         vlm(i)=hmtrx(i,1,1)*(hmtrx(i,2,2)*hmtrx(i,3,3)-
     1        hmtrx(i,3,2)*hmtrx(i,2,3))+
     2        hmtrx(i,2,1)*(hmtrx(i,3,2)*hmtrx(i,1,3)-
     3        hmtrx(i,1,2)*hmtrx(i,3,3))+
     4        hmtrx(i,3,1)*(hmtrx(i,1,2)*hmtrx(i,2,3)-
     5        hmtrx(i,2,2)*hmtrx(i,1,3))
         cvltot(i)=cvltot(i)+vlm(i)*wgt
         hjac=1./vlm(i)
         h11i=hmtrx(i,2,2)*hmtrx(i,3,3)-hmtrx(i,2,3)*hmtrx(i,3,2)
         h12i=hmtrx(i,3,2)*hmtrx(i,1,3)-hmtrx(i,3,3)*hmtrx(i,1,2)
         h13i=hmtrx(i,1,2)*hmtrx(i,2,3)-hmtrx(i,1,3)*hmtrx(i,2,2)
         h21i=hmtrx(i,2,3)*hmtrx(i,3,1)-hmtrx(i,2,1)*hmtrx(i,3,3)
         h22i=hmtrx(i,3,3)*hmtrx(i,1,1)-hmtrx(i,3,1)*hmtrx(i,1,3)
         h23i=hmtrx(i,1,3)*hmtrx(i,2,1)-hmtrx(i,1,1)*hmtrx(i,2,3)
         h31i=hmtrx(i,2,1)*hmtrx(i,3,2)-hmtrx(i,2,2)*hmtrx(i,3,1)
         h32i=hmtrx(i,3,1)*hmtrx(i,1,2)-hmtrx(i,3,2)*hmtrx(i,1,1)
         h33i=hmtrx(i,1,1)*hmtrx(i,2,2)-hmtrx(i,1,2)*hmtrx(i,2,1)
         hmtrx(i,1,1)=hjac*h11i
         hmtrx(i,2,1)=hjac*h21i
         hmtrx(i,3,1)=hjac*h31i
         hmtrx(i,1,2)=hjac*h12i
         hmtrx(i,2,2)=hjac*h22i
         hmtrx(i,3,2)=hjac*h32i
         hmtrx(i,1,3)=hjac*h13i
         hmtrx(i,2,3)=hjac*h23i
         hmtrx(i,3,3)=hjac*h33i
c
      enddo
c
      if (lenvec8.eq.0) then
         do i=lft,llt
            voltot(i)=cvltot(i)
         enddo
         do k=1,3
            do j=1,3
               do i=lft,llt
                  gmtrx(i,j,k)=hmtrx(i,j,k)
               enddo
            enddo
         enddo
      endif
c
c     Compute "real" b-matrix
c
      if (lenvec8.ne.0) then
c
      ndtot=8*(3+nxdof)
      do l=1,ndtot
         do j=1,3
            do i=lft,llt
c
               b1=bmtrx(i,j,1,l)*gmtrx(i,1,1)+
     1              bmtrx(i,j,2,l)*gmtrx(i,2,1)+
     2              bmtrx(i,j,3,l)*gmtrx(i,3,1)
               b2=bmtrx(i,j,1,l)*gmtrx(i,1,2)+
     1              bmtrx(i,j,2,l)*gmtrx(i,2,2)+
     2              bmtrx(i,j,3,l)*gmtrx(i,3,2)
               b3=bmtrx(i,j,1,l)*gmtrx(i,1,3)+
     1              bmtrx(i,j,2,l)*gmtrx(i,2,3)+
     2              bmtrx(i,j,3,l)*gmtrx(i,3,3)
               bmtrx(i,j,1,l)=b1
               bmtrx(i,j,2,l)=b2
               bmtrx(i,j,3,l)=b3
c
            enddo
         enddo
      enddo
c
      endif
c
c     Compute "real" c-matrix
c
      ndtot=8*(3+nxdof)
      do l=1,ndtot
         do j=1,3
            do i=lft,llt
c
               c1=cmtrx(i,j,1,l)*hmtrx(i,1,1)+
     1              cmtrx(i,j,2,l)*hmtrx(i,2,1)+
     2              cmtrx(i,j,3,l)*hmtrx(i,3,1)
               c2=cmtrx(i,j,1,l)*hmtrx(i,1,2)+
     1              cmtrx(i,j,2,l)*hmtrx(i,2,2)+
     2              cmtrx(i,j,3,l)*hmtrx(i,3,2)
               c3=cmtrx(i,j,1,l)*hmtrx(i,1,3)+
     1              cmtrx(i,j,2,l)*hmtrx(i,2,3)+
     2              cmtrx(i,j,3,l)*hmtrx(i,3,3)
               cmtrx(i,j,1,l)=c1
               cmtrx(i,j,2,l)=c2
               cmtrx(i,j,3,l)=c3
c
            enddo
         enddo
      enddo
c
      if (lenvec8.eq.0) then
      do l=1,8*(3+NXDOFUE)
         do k=1,3
            do j=1,3
               do i=lft,llt
                  bmtrx(i,j,k,l)=cmtrx(i,j,k,l)
               enddo
            enddo
         enddo
      enddo
      endif
c
      return
      end
      subroutine usrsld_str(nxdof,lft,llt)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     compute strain increments and spin
c     increments for user defined solid
c
      include 'nlqparm'
      include 'nhisparm.inc'
      common/aux2loc/dstrn(nlq,6),wdt(nlq,3),einc(nlq)
      common/aux10loc/
     1 px1(nlq),px2(nlq),px3(nlq),px4(nlq),
     & px5(nlq),px6(nlq),px7(nlq),px8(nlq),
     2 py1(nlq),py2(nlq),py3(nlq),py4(nlq),
     & py5(nlq),py6(nlq),py7(nlq),py8(nlq),
     3 pz1(nlq),pz2(nlq),pz3(nlq),pz4(nlq),
     & pz5(nlq),pz6(nlq),pz7(nlq),pz8(nlq),
     4 dx1(nlq),dx2(nlq),dx3(nlq),dx4(nlq),
     5 dx5(nlq),dx6(nlq),dx7(nlq),dx8(nlq),
     6 dy1(nlq),dy2(nlq),dy3(nlq),dy4(nlq),
     7 dy5(nlq),dy6(nlq),dy7(nlq),dy8(nlq),
     8 dz1(nlq),dz2(nlq),dz3(nlq),dz4(nlq),
     9 dz5(nlq),dz6(nlq),dz7(nlq),dz8(nlq)
      common/bel7loc/ixsld(nlq,8,5),ixshl(nlq,4,5)
     .,bmtrx(nlq,3,3,8*(3+NXDOFUE)),
     . cmtrx(nlq,3,3,8*(3+NXDOFUE)),xdof(nlq,8,NXDOFUE),
     . dxdof(nlq,8,NXDOFUE),xhdof(nlq,8,NXDOFUE),
     . bvec(nlq,8*(3+NXDOFUE)),cvec(nlq,8*(3+NXDOFUE)),
     . frc(nlq,8*(3+NXDOFUE)),
     . stiff(nlq,64*(3+NXDOFUE)*(3+NXDOFUE)),
     . sigv(nlq),
     . gmtrx(nlq,3,3),hmtrx(nlq,3,3),cvltot(nlq),
     . xh1(nlq),xh2(nlq),xh3(nlq),xh4(nlq),
     . xh5(nlq),xh6(nlq),xh7(nlq),xh8(nlq),
     . yh1(nlq),yh2(nlq),yh3(nlq),yh4(nlq),
     . yh5(nlq),yh6(nlq),yh7(nlq),yh8(nlq),
     . zh1(nlq),zh2(nlq),zh3(nlq),zh4(nlq),
     . zh5(nlq),zh6(nlq),zh7(nlq),zh8(nlq),
     . hl11(nlq),hl12(nlq),hl13(nlq),hl21(nlq),hl22(nlq),
     . hl23(nlq),hl31(nlq),hl32(nlq),hl33(nlq),
     . xx1(nlq),xx2(nlq),xx3(nlq),xx4(nlq),
     . xx5(nlq),xx6(nlq),xx7(nlq),xx8(nlq),
     . yy1(nlq),yy2(nlq),yy3(nlq),yy4(nlq),
     . yy5(nlq),yy6(nlq),yy7(nlq),yy8(nlq),
     . zz1(nlq),zz2(nlq),zz3(nlq),zz4(nlq),
     . zz5(nlq),zz6(nlq),zz7(nlq),zz8(nlq),vlm(nlq)
c
      common/subtssloc/dt1siz(nlq)
c$omp threadprivate (/subtssloc/)
c$omp threadprivate (/bel7loc/)
c$omp threadprivate (/aux2loc/)
c$omp threadprivate (/aux10loc/)
      ndtot=8*(3+nxdof)
c
      do j=1,6
c
         if (j.le.3) then
            do k=1,ndtot
               do i=lft,llt
                  bvec(i,k)=bmtrx(i,j,j,k)
               enddo
            enddo
         else
            j1=2
            j2=1
            if (j.eq.5) then
               j1=3
               j2=2
            elseif (j.eq.6) then
               j1=1
               j2=3
            endif
            do k=1,ndtot
               do i=lft,llt
                  bvec(i,k)=bmtrx(i,j1,j2,k)+bmtrx(i,j2,j1,k)
               enddo
            enddo
         endif
c
         do i=lft,llt
c
            dstrn(i,j)=
     1           bvec(i,1)*dx1(i)+
     2           bvec(i,2)*dy1(i)+
     3           bvec(i,3)*dz1(i)+
     4           bvec(i,4+nxdof)*dx2(i)+
     5           bvec(i,5+nxdof)*dy2(i)+
     6           bvec(i,6+nxdof)*dz2(i)+
     7           bvec(i,7+2*nxdof)*dx3(i)+
     8           bvec(i,8+2*nxdof)*dy3(i)+
     9           bvec(i,9+2*nxdof)*dz3(i)+
     .           bvec(i,10+3*nxdof)*dx4(i)+
     1           bvec(i,11+3*nxdof)*dy4(i)+
     2           bvec(i,12+3*nxdof)*dz4(i)+
     3           bvec(i,13+4*nxdof)*dx5(i)+
     4           bvec(i,14+4*nxdof)*dy5(i)+
     5           bvec(i,15+4*nxdof)*dz5(i)+
     6           bvec(i,16+5*nxdof)*dx6(i)+
     7           bvec(i,17+5*nxdof)*dy6(i)+
     8           bvec(i,18+5*nxdof)*dz6(i)+
     9           bvec(i,19+6*nxdof)*dx7(i)+
     .           bvec(i,20+6*nxdof)*dy7(i)+
     1           bvec(i,21+6*nxdof)*dz7(i)+
     2           bvec(i,22+7*nxdof)*dx8(i)+
     3           bvec(i,23+7*nxdof)*dy8(i)+
     4           bvec(i,24+7*nxdof)*dz8(i)
c
         enddo
c
         if (nxdof.gt.0) then
            do k=1,nxdof
               k1=3+k
               k2=6+nxdof+k
               k3=9+2*nxdof+k
               k4=12+3*nxdof+k
               k5=15+4*nxdof+k
               k6=18+5*nxdof+k
               k7=21+6*nxdof+k
               k8=24+7*nxdof+k
               do i=lft,llt
c
                  dstrn(i,j)=dstrn(i,j)+
     1                 bvec(i,k1)*dxdof(i,1,k)+
     2                 bvec(i,k2)*dxdof(i,2,k)+
     3                 bvec(i,k3)*dxdof(i,3,k)+
     4                 bvec(i,k4)*dxdof(i,4,k)+
     5                 bvec(i,k5)*dxdof(i,5,k)+
     6                 bvec(i,k6)*dxdof(i,6,k)+
     7                 bvec(i,k7)*dxdof(i,7,k)+
     8                 bvec(i,k8)*dxdof(i,8,k)
c
               enddo
            enddo
         endif
c
         if (j.gt.3) then
c
            jj=1
            if (j.eq.5) jj=3
            if (j.eq.6) jj=2
c
            do k=1,ndtot
               do i=lft,llt
                  bvec(i,k)=.5*(bmtrx(i,j1,j2,k)-bmtrx(i,j2,j1,k))*
     1                 dt1siz(i)
               enddo
            enddo
c
            do i=lft,llt
c
               wdt(i,jj)=
     1           bvec(i,1)*dx1(i)+
     2           bvec(i,2)*dy1(i)+
     3           bvec(i,3)*dz1(i)+
     4           bvec(i,4+nxdof)*dx2(i)+
     5           bvec(i,5+nxdof)*dy2(i)+
     6           bvec(i,6+nxdof)*dz2(i)+
     7           bvec(i,7+2*nxdof)*dx3(i)+
     8           bvec(i,8+2*nxdof)*dy3(i)+
     9           bvec(i,9+2*nxdof)*dz3(i)+
     .           bvec(i,10+3*nxdof)*dx4(i)+
     1           bvec(i,11+3*nxdof)*dy4(i)+
     2           bvec(i,12+3*nxdof)*dz4(i)+
     3           bvec(i,13+4*nxdof)*dx5(i)+
     4           bvec(i,14+4*nxdof)*dy5(i)+
     5           bvec(i,15+4*nxdof)*dz5(i)+
     6           bvec(i,16+5*nxdof)*dx6(i)+
     7           bvec(i,17+5*nxdof)*dy6(i)+
     8           bvec(i,18+5*nxdof)*dz6(i)+
     9           bvec(i,19+6*nxdof)*dx7(i)+
     .           bvec(i,20+6*nxdof)*dy7(i)+
     1           bvec(i,21+6*nxdof)*dz7(i)+
     2           bvec(i,22+7*nxdof)*dx8(i)+
     3           bvec(i,23+7*nxdof)*dy8(i)+
     4           bvec(i,24+7*nxdof)*dz8(i)
c
            enddo
c
            if (nxdof.gt.0) then
               do k=1,nxdof
                  k1=3+k
                  k2=6+nxdof+k
                  k3=9+2*nxdof+k
                  k4=12+3*nxdof+k
                  k5=15+4*nxdof+k
                  k6=18+5*nxdof+k
                  k7=21+6*nxdof+k
                  k8=24+7*nxdof+k
                  do i=lft,llt
c
                     wdt(i,jj)=wdt(i,jj)+
     1                 bvec(i,k1)*dxdof(i,1,k)+
     2                 bvec(i,k2)*dxdof(i,2,k)+
     3                 bvec(i,k3)*dxdof(i,3,k)+
     4                 bvec(i,k4)*dxdof(i,4,k)+
     5                 bvec(i,k5)*dxdof(i,5,k)+
     6                 bvec(i,k6)*dxdof(i,6,k)+
     7                 bvec(i,k7)*dxdof(i,7,k)+
     8                 bvec(i,k8)*dxdof(i,8,k)
c
                  enddo
               enddo
            endif
c
         endif
c
      enddo
c
      return
      end
      subroutine usrsld_grd(x,nxdof,ietyp,mte,xi,eta,zeta,lft,llt)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     compute deformation gradient
c
      include 'nlqparm'
      include 'nhisparm.inc'
      include 'umatss.inc'
      common/aux2loc/dstrn(nlq,6)
      common/aux33loc/ix1(nlq),ix2(nlq),ix3(nlq),ix4(nlq),ix5(nlq),
     1 ix6(nlq),ix7(nlq),ix8(nlq),mxt(nlq)
      common/aux18loc/dd(nlq),dfe(nlq),ddq(nlq)
      common/bel7loc/ixsld(nlq,8,5),ixshl(nlq,4,5)
     .,bmtrx(nlq,3,3,8*(3+NXDOFUE)),
     . cmtrx(nlq,3,3,8*(3+NXDOFUE)),xdof(nlq,8,NXDOFUE),
     . dxdof(nlq,8,NXDOFUE),xhdof(nlq,8,NXDOFUE),
     . bvec(nlq,8*(3+NXDOFUE)),cvec(nlq,8*(3+NXDOFUE)),
     . frc(nlq,8*(3+NXDOFUE)),
     . stiff(nlq,64*(3+NXDOFUE)*(3+NXDOFUE)),
     . sigv(nlq),
     . gmtrx(nlq,3,3),hmtrx(nlq,3,3),cvltot(nlq),
     . xh1(nlq),xh2(nlq),xh3(nlq),xh4(nlq),
     . xh5(nlq),xh6(nlq),xh7(nlq),xh8(nlq),
     . yh1(nlq),yh2(nlq),yh3(nlq),yh4(nlq),
     . yh5(nlq),yh6(nlq),yh7(nlq),yh8(nlq),
     . zh1(nlq),zh2(nlq),zh3(nlq),zh4(nlq),
     . zh5(nlq),zh6(nlq),zh7(nlq),zh8(nlq),
     . hl11(nlq),hl12(nlq),hl13(nlq),hl21(nlq),hl22(nlq),
     . hl23(nlq),hl31(nlq),hl32(nlq),hl33(nlq),
     . xx1(nlq),xx2(nlq),xx3(nlq),xx4(nlq),
     . xx5(nlq),xx6(nlq),xx7(nlq),xx8(nlq),
     . yy1(nlq),yy2(nlq),yy3(nlq),yy4(nlq),
     . yy5(nlq),yy6(nlq),yy7(nlq),yy8(nlq),
     . zz1(nlq),zz2(nlq),zz3(nlq),zz4(nlq),
     . zz5(nlq),zz6(nlq),zz7(nlq),zz8(nlq),vlm(nlq)
c     common/comrbbr/ishrub(300),icompf(300),mhyper(300)
      common/vect32loc/g11(nlq),g21(nlq),g31(nlq),g12(nlq),g22(nlq),
     . g32(nlq),g13(nlq),g23(nlq),g33(nlq),ifg(nlq)
c
      real*8 x
      dimension x(3,1)
      dimension xx(nlq,8*(3+NXDOFUE))
c
c$omp threadprivate (/vect32loc/)
c$omp threadprivate (/bel7loc/)
c$omp threadprivate (/aux2loc/)
c$omp threadprivate (/aux33loc/)
c$omp threadprivate (/aux18loc/)
      do j=1,3
         do i=lft,llt
            xx(i,j)=x(j,ix1(i))
            xx(i,3+nxdof+j)=x(j,ix2(i))
            xx(i,6+2*nxdof+j)=x(j,ix3(i))
            xx(i,9+3*nxdof+j)=x(j,ix4(i))
            xx(i,12+4*nxdof+j)=x(j,ix5(i))
            xx(i,15+5*nxdof+j)=x(j,ix6(i))
            xx(i,18+6*nxdof+j)=x(j,ix7(i))
            xx(i,21+7*nxdof+j)=x(j,ix8(i))
         enddo
      enddo
      if (nxdof.gt.0) then
         do k=1,8
            do j=1,nxdof
               indx=3+(3+nxdof)*(k-1)+j
               nsnd=(j-1)/3+1
               nsdf=j-(nsnd-1)*3
               do i=lft,llt
                  xx(i,indx)=x(nsdf,ixsld(i,k,nsnd))
               enddo
            enddo
         enddo
      endif
c
      do i=lft,llt
         dd(i)=-dstrn(i,1)-dstrn(i,2)-dstrn(i,3)
         ddq(i)=dd(i)
         g11(i)=0.
         g21(i)=0.
         g31(i)=0.
         g12(i)=0.
         g22(i)=0.
         g32(i)=0.
         g13(i)=0.
         g23(i)=0.
         g33(i)=0.
      enddo
c
      ndtot=8*(3+nxdof)
c
      do j=1,ndtot
         do i=lft,llt
            g11(i)=g11(i)+cmtrx(i,1,1,j)*xx(i,j)
            g21(i)=g21(i)+cmtrx(i,2,1,j)*xx(i,j)
            g31(i)=g31(i)+cmtrx(i,3,1,j)*xx(i,j)
            g12(i)=g12(i)+cmtrx(i,1,2,j)*xx(i,j)
            g22(i)=g22(i)+cmtrx(i,2,2,j)*xx(i,j)
            g32(i)=g32(i)+cmtrx(i,3,2,j)*xx(i,j)
            g13(i)=g13(i)+cmtrx(i,1,3,j)*xx(i,j)
            g23(i)=g23(i)+cmtrx(i,2,3,j)*xx(i,j)
            g33(i)=g33(i)+cmtrx(i,3,3,j)*xx(i,j)
         enddo
      enddo
c
      do i=lft,llt
c
         dfe(i)=1./(g11(i)*(g22(i)*g33(i)-
     1        g32(i)*g23(i))+
     2        g21(i)*(g32(i)*g13(i)-
     3        g12(i)*g33(i))+
     4        g31(i)*(g12(i)*g23(i)-
     5        g22(i)*g13(i)))
         g11i=g22(i)*g33(i)-g23(i)*g32(i)
         g12i=g32(i)*g13(i)-g33(i)*g12(i)
         g13i=g12(i)*g23(i)-g13(i)*g22(i)
         g21i=g23(i)*g31(i)-g21(i)*g33(i)
         g22i=g33(i)*g11(i)-g31(i)*g13(i)
         g23i=g13(i)*g21(i)-g11(i)*g23(i)
         g31i=g21(i)*g32(i)-g22(i)*g31(i)
         g32i=g31(i)*g12(i)-g32(i)*g11(i)
         g33i=g11(i)*g22(i)-g12(i)*g21(i)
         g11(i)=dfe(i)*g11i
         g21(i)=dfe(i)*g21i
         g31(i)=dfe(i)*g31i
         g12(i)=dfe(i)*g12i
         g22(i)=dfe(i)*g22i
         g32(i)=dfe(i)*g32i
         g13(i)=dfe(i)*g13i
         g23(i)=dfe(i)*g23i
         g33(i)=dfe(i)*g33i
      enddo
c
      if (icompf(mte).eq.mte) ifg(lft)=1
c
      return
      end
      subroutine usrsld_rstr(strain,lft,llt,ipt,nip,wgt)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     rotate strains for output
c
      include 'nlqparm'
      common/strsavloc/wzza(nlq),wyya(nlq),wxxa(nlq),d1av(nlq),
     . d2av(nlq),d3av(nlq),d4av(nlq),d5av(nlq),d6av(nlq)
      common/aux2loc/d1(nlq),d2(nlq),d3(nlq),d4(nlq),d5(nlq),d6(nlq),
     1 wzz(nlq),wyy(nlq),wxx(nlq),ener(nlq)
      common/numcpuloc/lenvec8,lenvech
      common/subtssloc/dt1siz(nlq)
      dimension strain(6,*)
c
c$omp threadprivate (/strsavloc/)
c$omp threadprivate (/subtssloc/)
c$omp threadprivate (/numcpuloc/)
c$omp threadprivate (/aux2loc/)
      if (ipt.eq.1) then
      do 10 i=lft,llt
      wzza(i)=wgt*wzz(i)
      wyya(i)=wgt*wyy(i)
      wxxa(i)=wgt*wxx(i)
      d1av(i)=wgt*d1(i)
      d2av(i)=wgt*d2(i)
      d3av(i)=wgt*d3(i)
      d4av(i)=wgt*d4(i)
      d5av(i)=wgt*d5(i)
      d6av(i)=wgt*d6(i)
   10 continue
      else
      do 20 i=lft,llt
      wzza(i)=wzza(i)+wgt*wzz(i)
      wyya(i)=wyya(i)+wgt*wyy(i)
      wxxa(i)=wxxa(i)+wgt*wxx(i)
      d1av(i)=d1av(i)+wgt*d1(i)
      d2av(i)=d2av(i)+wgt*d2(i)
      d3av(i)=d3av(i)+wgt*d3(i)
      d4av(i)=d4av(i)+wgt*d4(i)
      d5av(i)=d5av(i)+wgt*d5(i)
      d6av(i)=d6av(i)+wgt*d6(i)
   20 continue
      endif
      if (ipt.ne.nip) return
      fact=.125
      if (lenvech.eq.1) fact=0.250
      do 30 i=lft,llt
      wzzi=fact*wzza(i)
      wyyi=fact*wyya(i)
      wxxi=fact*wxxa(i)
      d1i =.125*d1av(i)
      d2i =.125*d2av(i)
      d3i =.125*d3av(i)
      d4i =.125*d4av(i)
      d5i =.125*d5av(i)
      d6i =.125*d6av(i)
      s1=strain(1,i)
      s2=strain(2,i)
      s3=strain(3,i)
      s4=strain(4,i)
      s5=strain(5,i)
      s6=strain(6,i)
      q1=2.*s4*wzzi
      q2=2.*s6*wyyi
      q3=2.*s5*wxxi
      dt1s=.5*dt1siz(i)
      strain(1,i)=s1-q1+q2+dt1siz(i)*d1i
      strain(2,i)=s2+q1-q3+dt1siz(i)*d2i
      strain(3,i)=s3-q2+q3+dt1siz(i)*d3i
      strain(4,i)=s4+wzzi*(s1-s2)+wyyi*s5-wxxi*s6+dt1s*d4i
      strain(5,i)=s5+wxxi*(s2-s3)+wzzi*s6-wyyi*s4+dt1s*d5i
   30 strain(6,i)=s6+wyyi*(s3-s1)+wxxi*s4-wzzi*s5+dt1s*d6i
      return
      end
      subroutine usrsld_frc(nxdof,lft,llt)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     computes internal force for user defined solid
c
      include 'nlqparm'
      include 'nhisparm.inc'
      common/aux14loc/sig(nlq,6)
      common/aux15loc/qp(nlq),specen(nlq),dvol(nlq),volold(nlq)
      common/bel7loc/ixsld(nlq,8,5),ixshl(nlq,4,5)
     .,bmtrx(nlq,3,3,8*(3+NXDOFUE)),
     . cmtrx(nlq,3,3,8*(3+NXDOFUE)),xdof(nlq,8,NXDOFUE),
     . dxdof(nlq,8,NXDOFUE),xhdof(nlq,8,NXDOFUE),
     . bvec(nlq,8*(3+NXDOFUE)),cvec(nlq,8*(3+NXDOFUE)),
     . frc(nlq,8*(3+NXDOFUE)),
     . stiff(nlq,64*(3+NXDOFUE)*(3+NXDOFUE)),
     . sigv(nlq),
     . gmtrx(nlq,3,3),hmtrx(nlq,3,3),cvltot(nlq),
     . xh1(nlq),xh2(nlq),xh3(nlq),xh4(nlq),
     . xh5(nlq),xh6(nlq),xh7(nlq),xh8(nlq),
     . yh1(nlq),yh2(nlq),yh3(nlq),yh4(nlq),
     . yh5(nlq),yh6(nlq),yh7(nlq),yh8(nlq),
     . zh1(nlq),zh2(nlq),zh3(nlq),zh4(nlq),
     . zh5(nlq),zh6(nlq),zh7(nlq),zh8(nlq),
     . hl11(nlq),hl12(nlq),hl13(nlq),hl21(nlq),hl22(nlq),
     . hl23(nlq),hl31(nlq),hl32(nlq),hl33(nlq),
     . xx1(nlq),xx2(nlq),xx3(nlq),xx4(nlq),
     . xx5(nlq),xx6(nlq),xx7(nlq),xx8(nlq),
     . yy1(nlq),yy2(nlq),yy3(nlq),yy4(nlq),
     . yy5(nlq),yy6(nlq),yy7(nlq),yy8(nlq),
     . zz1(nlq),zz2(nlq),zz3(nlq),zz4(nlq),
     . zz5(nlq),zz6(nlq),zz7(nlq),zz8(nlq),vlm(nlq)
c
c     Number of degrees of freedom in the solid
c
c$omp threadprivate (/bel7loc/)
c$omp threadprivate (/aux15loc/)
c$omp threadprivate (/aux14loc/)
      ndtot=8*(3+nxdof)
c
c     Assumes zero internal force vector on first entry
c
      do j=1,6
c
c     Stress times volume
c
         if (j.le.3) then
            do i=lft,llt
               sigv(i)=(sig(i,j)-qp(i))*vlm(i)
            enddo
         else
            do i=lft,llt
               sigv(i)=sig(i,j)*vlm(i)
            enddo
         endif
c
         if (j.le.3) then
            do k=1,ndtot
               do i=lft,llt
                  bvec(i,k)=cmtrx(i,j,j,k)
               enddo
            enddo
         else
            j1=1
            j2=2
            if (j.eq.5) then
               j1=3
            elseif (j.eq.6) then
               j2=3
            endif
            do k=1,ndtot
               do i=lft,llt
                  bvec(i,k)=cmtrx(i,j1,j2,k)+cmtrx(i,j2,j1,k)
               enddo
            enddo
         endif
c
         do k=1,ndtot
            do i=lft,llt
               frc(i,k)=frc(i,k)+bvec(i,k)*sigv(i)
            enddo
         enddo
c
      enddo
c
      return
      end
      subroutine usrsld_kmt(ske,nxdof,lft,llt)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     assembles material stiffness matrix
c
      include 'nlqparm'
      include 'nhisparm.inc'
      common/vect8loc/dsave(nlq,6,6)
      common/bel7loc/ixsld(nlq,8,5),ixshl(nlq,4,5)
     .,bmtrx(nlq,3,3,8*(3+NXDOFUE)),
     . cmtrx(nlq,3,3,8*(3+NXDOFUE)),xdof(nlq,8,NXDOFUE),
     . dxdof(nlq,8,NXDOFUE),xhdof(nlq,8,NXDOFUE),
     . bvec(nlq,8*(3+NXDOFUE)),cvec(nlq,8*(3+NXDOFUE)),
     . frc(nlq,8*(3+NXDOFUE)),
     . stiff(nlq,64*(3+NXDOFUE)*(3+NXDOFUE)),
     . sigv(nlq),
     . gmtrx(nlq,3,3),hmtrx(nlq,3,3),cvltot(nlq),
     . xh1(nlq),xh2(nlq),xh3(nlq),xh4(nlq),
     . xh5(nlq),xh6(nlq),xh7(nlq),xh8(nlq),
     . yh1(nlq),yh2(nlq),yh3(nlq),yh4(nlq),
     . yh5(nlq),yh6(nlq),yh7(nlq),yh8(nlq),
     . zh1(nlq),zh2(nlq),zh3(nlq),zh4(nlq),
     . zh5(nlq),zh6(nlq),zh7(nlq),zh8(nlq),
     . hl11(nlq),hl12(nlq),hl13(nlq),hl21(nlq),hl22(nlq),
     . hl23(nlq),hl31(nlq),hl32(nlq),hl33(nlq),
     . xx1(nlq),xx2(nlq),xx3(nlq),xx4(nlq),
     . xx5(nlq),xx6(nlq),xx7(nlq),xx8(nlq),
     . yy1(nlq),yy2(nlq),yy3(nlq),yy4(nlq),
     . yy5(nlq),yy6(nlq),yy7(nlq),yy8(nlq),
     . zz1(nlq),zz2(nlq),zz3(nlq),zz4(nlq),
     . zz5(nlq),zz6(nlq),zz7(nlq),zz8(nlq),vlm(nlq)
c
      dimension ske(nlq,*)
c
c     Number of degrees of freedom in the solid
c
c$omp threadprivate (/bel7loc/)
c$omp threadprivate (/vect8loc/)
      ndtot=8*(3+nxdof)
c
      do jj=1,6
c
         do j=1,ndtot
            do i=lft,llt
               cvec(i,j)=0.
            enddo
         enddo
c
         do j=1,6
c
c     Stiffness times volume
c
            do i=lft,llt
               dsave(i,j,jj)=dsave(i,j,jj)*vlm(i)
            enddo
c
            if (j.le.3) then
               do k=1,ndtot
                  do i=lft,llt
                     bvec(i,k)=cmtrx(i,j,j,k)
                  enddo
               enddo
            else
               j1=1
               j2=2
               if (j.eq.5) then
                  j1=3
               elseif (j.eq.6) then
                  j2=3
               endif
               do k=1,ndtot
                  do i=lft,llt
                     bvec(i,k)=cmtrx(i,j1,j2,k)+cmtrx(i,j2,j1,k)
                  enddo
               enddo
            endif
c
            do k=1,ndtot
               do i=lft,llt
                  cvec(i,k)=cvec(i,k)+bvec(i,k)*dsave(i,j,jj)
               enddo
            enddo
c
         enddo
c
         if (jj.le.3) then
            do k=1,ndtot
               do i=lft,llt
                  bvec(i,k)=cmtrx(i,jj,jj,k)
               enddo
            enddo
         else
            j1=1
            j2=2
            if (jj.eq.5) then
               j1=3
            elseif (jj.eq.6) then
               j2=3
            endif
            do k=1,ndtot
               do i=lft,llt
                  bvec(i,k)=cmtrx(i,j1,j2,k)+cmtrx(i,j2,j1,k)
               enddo
            enddo
         endif
c
c     Loop over element in stiffness matrix
c
         do ml=1,3
            m=ml
            irow=m*(m-1)/2
            m=ml
            do mr=1,ml
               n=mr
               iske=irow+n
               n=mr
               do i=lft,llt
                  ske(i,iske)=ske(i,iske)+cvec(i,m)*bvec(i,n)
               enddo
            enddo
         enddo
         do nl=2,8
            do ml=1,3
               m=(nl-1)*3+ml
               irow=m*(m-1)/2
               m=(nl-1)*(3+nxdof)+ml
               do nr=1,nl-1
                  do mr=1,3
                     n=(nr-1)*3+mr
                     iske=irow+n
                     n=(nr-1)*(3+nxdof)+mr
                     do i=lft,llt
                        ske(i,iske)=ske(i,iske)+cvec(i,m)*bvec(i,n)
                     enddo
                  enddo
               enddo
               do mr=1,ml
                  n=(nl-1)*3+mr
                  iske=irow+n
                  n=(nl-1)*(3+nxdof)+mr
                  do i=lft,llt
                     ske(i,iske)=ske(i,iske)+cvec(i,m)*bvec(i,n)
                  enddo
               enddo
            enddo
         enddo
         if (nxdof.gt.0) then
           nsnd=(nxdof-1)/3+1
           do isnd=1,nsnd
             nsdf=3
             if (isnd.eq.nsnd) nsdf=nxdof-(nsnd-1)*3
             do irnd=1,8
               do isdf=1,nsdf
                 m=24+24*(isnd-1)+3*(irnd-1)+isdf
                 irow=m*(m-1)/2
                 mm=3+(3+nxdof)*(irnd-1)+3*(isnd-1)+isdf
                 do nr=1,8
                   do mr=1,3
                     n=(nr-1)*3+mr
                     iske=irow+n
                     nn=(nr-1)*(3+nxdof)+mr
                     do i=lft,llt
                       ske(i,iske)=ske(i,iske)+cvec(i,mm)*bvec(i,nn)
                     enddo
                   enddo
                 enddo
                 do jsnd=1,nsnd
                   msdf=3
                   if (jsnd.eq.nsnd) msdf=nxdof-(nsnd-1)*3
                   do jrnd=1,8
                     do 1 jsdf=1,msdf
                       n=24+24*(jsnd-1)+3*(jrnd-1)+jsdf
                       if (n.gt.m) goto 1
                       iske=irow+n
                       nn=3+(3+nxdof)*(jrnd-1)+3*(jsnd-1)+jsdf
                       do i=lft,llt
                         ske(i,iske)=ske(i,iske)+cvec(i,mm)*bvec(i,nn)
                       enddo
 1                   continue
                   enddo
                 enddo
               enddo
             enddo
           enddo
         endif
c
      enddo
c
      return
      end
      subroutine usrsld_kgm(ske,nxdof,lft,llt)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     assembles geometric stiffness matrix
c
      include 'nlqparm'
      include 'nhisparm.inc'
      common/aux14loc/sig(nlq,6)
      common/bel7loc/ixsld(nlq,8,5),ixshl(nlq,4,5)
     .,bmtrx(nlq,3,3,8*(3+NXDOFUE)),
     . cmtrx(nlq,3,3,8*(3+NXDOFUE)),xdof(nlq,8,NXDOFUE),
     . dxdof(nlq,8,NXDOFUE),xhdof(nlq,8,NXDOFUE),
     . bvec(nlq,8*(3+NXDOFUE)),cvec(nlq,8*(3+NXDOFUE)),
     . frc(nlq,8*(3+NXDOFUE)),
     . stiff(nlq,64*(3+NXDOFUE)*(3+NXDOFUE)),
     . sigv(nlq),
     . gmtrx(nlq,3,3),hmtrx(nlq,3,3),cvltot(nlq),
     . xh1(nlq),xh2(nlq),xh3(nlq),xh4(nlq),
     . xh5(nlq),xh6(nlq),xh7(nlq),xh8(nlq),
     . yh1(nlq),yh2(nlq),yh3(nlq),yh4(nlq),
     . yh5(nlq),yh6(nlq),yh7(nlq),yh8(nlq),
     . zh1(nlq),zh2(nlq),zh3(nlq),zh4(nlq),
     . zh5(nlq),zh6(nlq),zh7(nlq),zh8(nlq),
     . hl11(nlq),hl12(nlq),hl13(nlq),hl21(nlq),hl22(nlq),
     . hl23(nlq),hl31(nlq),hl32(nlq),hl33(nlq),
     . xx1(nlq),xx2(nlq),xx3(nlq),xx4(nlq),
     . xx5(nlq),xx6(nlq),xx7(nlq),xx8(nlq),
     . yy1(nlq),yy2(nlq),yy3(nlq),yy4(nlq),
     . yy5(nlq),yy6(nlq),yy7(nlq),yy8(nlq),
     . zz1(nlq),zz2(nlq),zz3(nlq),zz4(nlq),
     . zz5(nlq),zz6(nlq),zz7(nlq),zz8(nlq),vlm(nlq)
c
      dimension ske(nlq,*)
c
c$omp threadprivate (/bel7loc/)
c$omp threadprivate (/aux14loc/)
      do j=1,6
c
c     Stress times volume
c
         do i=lft,llt
            sigv(i)=sig(i,j)*vlm(i)
         enddo
c
         if (j.le.3) then
c
c     Loop over element in stiffness matrix
c
            do ml=1,3
               m=ml
               irow=m*(m-1)/2
               m=ml
               do mr=1,ml
                  n=mr
                  iske=irow+n
                  n=mr
                  do i=lft,llt
                     ske(i,iske)=ske(i,iske)+sigv(i)*
     1                    (cmtrx(i,1,j,m)*cmtrx(i,1,j,n)+
     2                    cmtrx(i,2,j,m)*cmtrx(i,2,j,n)+
     3                    cmtrx(i,3,j,m)*cmtrx(i,3,j,n))
                  enddo
               enddo
            enddo
            do nl=2,8
               do ml=1,3
                  m=(nl-1)*3+ml
                  irow=m*(m-1)/2
                  m=(nl-1)*(3+nxdof)+ml
                  do nr=1,nl-1
                     do mr=1,3
                        n=(nr-1)*3+mr
                        iske=irow+n
                        n=(nr-1)*(3+nxdof)+mr
                        do i=lft,llt
                           ske(i,iske)=ske(i,iske)+sigv(i)*
     1                          (cmtrx(i,1,j,m)*cmtrx(i,1,j,n)+
     2                          cmtrx(i,2,j,m)*cmtrx(i,2,j,n)+
     3                          cmtrx(i,3,j,m)*cmtrx(i,3,j,n))
                        enddo
                     enddo
                  enddo
                  do mr=1,ml
                     n=(nl-1)*3+mr
                     iske=irow+n
                     n=(nl-1)*(3+nxdof)+mr
                     do i=lft,llt
                        ske(i,iske)=ske(i,iske)+sigv(i)*
     1                       (cmtrx(i,1,j,m)*cmtrx(i,1,j,n)+
     2                       cmtrx(i,2,j,m)*cmtrx(i,2,j,n)+
     3                       cmtrx(i,3,j,m)*cmtrx(i,3,j,n))
                     enddo
                  enddo
               enddo
            enddo
            if (nxdof.gt.0) then
              nsnd=(nxdof-1)/3+1
              do isnd=1,nsnd
                nsdf=3
                if (isnd.eq.nsnd) nsdf=nxdof-(nsnd-1)*3
                do irnd=1,8
                  do isdf=1,nsdf
                    m=24+24*(isnd-1)+3*(irnd-1)+isdf
                    irow=m*(m-1)/2
                    mm=3+(3+nxdof)*(irnd-1)+3*(isnd-1)+isdf
                    do nr=1,8
                      do mr=1,3
                        n=(nr-1)*3+mr
                        iske=irow+n
                        nn=(nr-1)*(3+nxdof)+mr
                        do i=lft,llt
                          ske(i,iske)=ske(i,iske)+sigv(i)*
     1                         (cmtrx(i,1,j,mm)*cmtrx(i,1,j,nn)+
     2                         cmtrx(i,2,j,mm)*cmtrx(i,2,j,nn)+
     3                         cmtrx(i,3,j,mm)*cmtrx(i,3,j,nn))
                        enddo
                      enddo
                    enddo
                    do jsnd=1,nsnd
                      msdf=3
                      if (jsnd.eq.nsnd) msdf=nxdof-(nsnd-1)*3
                      do jrnd=1,8
                        do 1 jsdf=1,msdf
                          n=24+24*(jsnd-1)+3*(jrnd-1)+jsdf
                          if (n.gt.m) goto 1
                          iske=irow+n
                          nn=3+(3+nxdof)*(jrnd-1)+3*(jsnd-1)+jsdf
                          do i=lft,llt
                            ske(i,iske)=ske(i,iske)+sigv(i)*
     1                           (cmtrx(i,1,j,mm)*cmtrx(i,1,j,nn)+
     2                           cmtrx(i,2,j,mm)*cmtrx(i,2,j,nn)+
     3                           cmtrx(i,3,j,mm)*cmtrx(i,3,j,nn))
                          enddo
 1                      continue
                      enddo
                    enddo
                  enddo
                enddo
              enddo
            endif
c
         else
c
            j1=1
            j2=2
            if (j.eq.5) then
               j1=3
            elseif (j.eq.6) then
               j2=3
            endif
c
c     Loop over element in stiffness matrix
c
            do ml=1,3
               m=ml
               irow=m*(m-1)/2
               m=ml
               do mr=1,ml
                  n=mr
                  iske=irow+n
                  n=mr
                  do i=lft,llt
                     ske(i,iske)=ske(i,iske)+sigv(i)*
     1                    (cmtrx(i,1,j1,m)*cmtrx(i,1,j2,n)+
     2                    cmtrx(i,1,j2,m)*cmtrx(i,1,j1,n)+
     3                    cmtrx(i,2,j1,m)*cmtrx(i,2,j2,n)+
     4                    cmtrx(i,2,j2,m)*cmtrx(i,2,j1,n)+
     5                    cmtrx(i,3,j1,m)*cmtrx(i,3,j2,n)+
     6                    cmtrx(i,3,j2,m)*cmtrx(i,3,j1,n))
                  enddo
               enddo
            enddo
            do nl=2,8
               do ml=1,3
                  m=(nl-1)*3+ml
                  irow=m*(m-1)/2
                  m=(nl-1)*(3+nxdof)+ml
                  do nr=1,nl-1
                     do mr=1,3
                        n=(nr-1)*3+mr
                        iske=irow+n
                        n=(nr-1)*(3+nxdof)+mr
                        do i=lft,llt
                           ske(i,iske)=ske(i,iske)+sigv(i)*
     1                          (cmtrx(i,1,j1,m)*cmtrx(i,1,j2,n)+
     2                          cmtrx(i,1,j2,m)*cmtrx(i,1,j1,n)+
     3                          cmtrx(i,2,j1,m)*cmtrx(i,2,j2,n)+
     4                          cmtrx(i,2,j2,m)*cmtrx(i,2,j1,n)+
     5                          cmtrx(i,3,j1,m)*cmtrx(i,3,j2,n)+
     6                          cmtrx(i,3,j2,m)*cmtrx(i,3,j1,n))
                        enddo
                     enddo
                  enddo
                  do mr=1,ml
                     n=(nl-1)*3+mr
                     iske=irow+n
                     n=(nl-1)*(3+nxdof)+mr
                     do i=lft,llt
                        ske(i,iske)=ske(i,iske)+sigv(i)*
     1                       (cmtrx(i,1,j1,m)*cmtrx(i,1,j2,n)+
     2                       cmtrx(i,1,j2,m)*cmtrx(i,1,j1,n)+
     3                       cmtrx(i,2,j1,m)*cmtrx(i,2,j2,n)+
     4                       cmtrx(i,2,j2,m)*cmtrx(i,2,j1,n)+
     5                       cmtrx(i,3,j1,m)*cmtrx(i,3,j2,n)+
     6                       cmtrx(i,3,j2,m)*cmtrx(i,3,j1,n))
                     enddo
                  enddo
               enddo
            enddo
            if (nxdof.gt.0) then
              nsnd=(nxdof-1)/3+1
              do isnd=1,nsnd
                nsdf=3
                if (isnd.eq.nsnd) nsdf=nxdof-(nsnd-1)*3
                do irnd=1,8
                  do isdf=1,nsdf
                    m=24+24*(isnd-1)+3*(irnd-1)+isdf
                    irow=m*(m-1)/2
                    mm=3+(3+nxdof)*(irnd-1)+3*(isnd-1)+isdf
                    do nr=1,8
                      do mr=1,3
                        n=(nr-1)*3+mr
                        iske=irow+n
                        nn=(nr-1)*(3+nxdof)+mr
                        do i=lft,llt
                          ske(i,iske)=ske(i,iske)+sigv(i)*
     1                         (cmtrx(i,1,j1,mm)*cmtrx(i,1,j2,nn)+
     2                         cmtrx(i,1,j2,mm)*cmtrx(i,1,j1,nn)+
     3                         cmtrx(i,2,j1,mm)*cmtrx(i,2,j2,nn)+
     4                         cmtrx(i,2,j2,mm)*cmtrx(i,2,j1,nn)+
     5                         cmtrx(i,3,j1,mm)*cmtrx(i,3,j2,nn)+
     6                         cmtrx(i,3,j2,mm)*cmtrx(i,3,j1,nn))
                        enddo
                      enddo
                    enddo
                    do jsnd=1,nsnd
                      msdf=3
                      if (jsnd.eq.nsnd) msdf=nxdof-(nsnd-1)*3
                      do jrnd=1,8
                        do 2 jsdf=1,msdf
                          n=24+24*(jsnd-1)+3*(jrnd-1)+jsdf
                          if (n.gt.m) goto 2
                          iske=irow+n
                          nn=3+(3+nxdof)*(jrnd-1)+3*(jsnd-1)+jsdf
                          do i=lft,llt
                            ske(i,iske)=ske(i,iske)+sigv(i)*
     1                           (cmtrx(i,1,j1,mm)*cmtrx(i,1,j2,nn)+
     2                           cmtrx(i,1,j2,mm)*cmtrx(i,1,j1,nn)+
     3                           cmtrx(i,2,j1,mm)*cmtrx(i,2,j2,nn)+
     4                           cmtrx(i,2,j2,mm)*cmtrx(i,2,j1,nn)+
     5                           cmtrx(i,3,j1,mm)*cmtrx(i,3,j2,nn)+
     6                           cmtrx(i,3,j2,mm)*cmtrx(i,3,j1,nn))
                          enddo
 2                      continue
                      enddo
                    enddo
                  enddo
                enddo
              enddo
            endif
c
         endif
c
      enddo
c
      return
      end
      subroutine usrsld_fs(nxdof,rhs,lft,llt)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      include 'nlqparm'
      include 'memaia.inc'
      include 'nhisparm.inc'
      common/bel7loc/ixsld(nlq,8,5),ixshl(nlq,4,5)
     .,bmtrx(nlq,3,3,8*(3+NXDOFUE)),
     . cmtrx(nlq,3,3,8*(3+NXDOFUE)),xdof(nlq,8,NXDOFUE),
     . dxdof(nlq,8,NXDOFUE),xhdof(nlq,8,NXDOFUE),
     . bvec(nlq,8*(3+NXDOFUE)),cvec(nlq,8*(3+NXDOFUE)),
     . frc(nlq,8*(3+NXDOFUE)),
     . stiff(nlq,64*(3+NXDOFUE)*(3+NXDOFUE)),
     . sigv(nlq),
     . gmtrx(nlq,3,3),hmtrx(nlq,3,3),cvltot(nlq),
     . xh1(nlq),xh2(nlq),xh3(nlq),xh4(nlq),
     . xh5(nlq),xh6(nlq),xh7(nlq),xh8(nlq),
     . yh1(nlq),yh2(nlq),yh3(nlq),yh4(nlq),
     . yh5(nlq),yh6(nlq),yh7(nlq),yh8(nlq),
     . zh1(nlq),zh2(nlq),zh3(nlq),zh4(nlq),
     . zh5(nlq),zh6(nlq),zh7(nlq),zh8(nlq),
     . hl11(nlq),hl12(nlq),hl13(nlq),hl21(nlq),hl22(nlq),
     . hl23(nlq),hl31(nlq),hl32(nlq),hl33(nlq),
     . xx1(nlq),xx2(nlq),xx3(nlq),xx4(nlq),
     . xx5(nlq),xx6(nlq),xx7(nlq),xx8(nlq),
     . yy1(nlq),yy2(nlq),yy3(nlq),yy4(nlq),
     . yy5(nlq),yy6(nlq),yy7(nlq),yy8(nlq),
     . zz1(nlq),zz2(nlq),zz3(nlq),zz4(nlq),
     . zz5(nlq),zz6(nlq),zz7(nlq),zz8(nlq),vlm(nlq)
      common/aux13loc/
     1 p11(nlq),p12(nlq),p13(nlq),p14(nlq),
     2 p15(nlq),p16(nlq),p17(nlq),p18(nlq),
     3 p21(nlq),p22(nlq),p23(nlq),p24(nlq),
     4 p25(nlq),p26(nlq),p27(nlq),p28(nlq),
     5 p31(nlq),p32(nlq),p33(nlq),p34(nlq),
     6 p35(nlq),p36(nlq),p37(nlq),p38(nlq)
      common/aux33loc/ix1(nlq),ix2(nlq),ix3(nlq),ix4(nlq),ix5(nlq),
     1 ix6(nlq),ix7(nlq),ix8(nlq),mxt(nlq)
      common/sorterloc/nnc,lczc
# 1 ".\sorter_noloc.inc" 1 
c$omp threadprivate (/bel7loc/)
c$omp threadprivate (/sorterloc/)
c$omp threadprivate (/aux33loc/)
c$omp threadprivate (/aux13loc/)
!
! NOTE: IF YOU CHANGE THIS FILE PLEASE ALSO CHANGE sorter.inc
! WHICH NEEDS TO BE IDENTICAL EXCEPT FOR znnc->nnc, zlczc->lczc
!
      real znnc,zlczc
      integer                                                           
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
      common/sorter/znnc, zlczc,                                        
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
# 3658 "dyn21usld.F" 2 
c
      dimension rhs(27,1)
c
      do k=1,3
         do j=1,8
            do i=lft,llt
               rhs((j-1)*3+k,i)=-frc(i,(j-1)*(3+nxdof)+k)
            enddo
         enddo
      enddo
c
      return
      end
      subroutine usrsld_ft(nxdof,e,lft,llt)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      include 'nlqparm'
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

# 3682 "dyn21usld.F" 2 
      include 'memaia.inc'
      include 'nhisparm.inc'
      common/bel7loc/ixsld(nlq,8,5),ixshl(nlq,4,5)
     .,bmtrx(nlq,3,3,8*(3+NXDOFUE)),
     . cmtrx(nlq,3,3,8*(3+NXDOFUE)),xdof(nlq,8,NXDOFUE),
     . dxdof(nlq,8,NXDOFUE),xhdof(nlq,8,NXDOFUE),
     . bvec(nlq,8*(3+NXDOFUE)),cvec(nlq,8*(3+NXDOFUE)),
     . frc(nlq,8*(3+NXDOFUE)),
     . stiff(nlq,64*(3+NXDOFUE)*(3+NXDOFUE)),
     . sigv(nlq),
     . gmtrx(nlq,3,3),hmtrx(nlq,3,3),cvltot(nlq),
     . xh1(nlq),xh2(nlq),xh3(nlq),xh4(nlq),
     . xh5(nlq),xh6(nlq),xh7(nlq),xh8(nlq),
     . yh1(nlq),yh2(nlq),yh3(nlq),yh4(nlq),
     . yh5(nlq),yh6(nlq),yh7(nlq),yh8(nlq),
     . zh1(nlq),zh2(nlq),zh3(nlq),zh4(nlq),
     . zh5(nlq),zh6(nlq),zh7(nlq),zh8(nlq),
     . hl11(nlq),hl12(nlq),hl13(nlq),hl21(nlq),hl22(nlq),
     . hl23(nlq),hl31(nlq),hl32(nlq),hl33(nlq),
     . xx1(nlq),xx2(nlq),xx3(nlq),xx4(nlq),
     . xx5(nlq),xx6(nlq),xx7(nlq),xx8(nlq),
     . yy1(nlq),yy2(nlq),yy3(nlq),yy4(nlq),
     . yy5(nlq),yy6(nlq),yy7(nlq),yy8(nlq),
     . zz1(nlq),zz2(nlq),zz3(nlq),zz4(nlq),
     . zz5(nlq),zz6(nlq),zz7(nlq),zz8(nlq),vlm(nlq)
      common/aux13loc/
     1 p11(nlq),p12(nlq),p13(nlq),p14(nlq),
     2 p15(nlq),p16(nlq),p17(nlq),p18(nlq),
     3 p21(nlq),p22(nlq),p23(nlq),p24(nlq),
     4 p25(nlq),p26(nlq),p27(nlq),p28(nlq),
     5 p31(nlq),p32(nlq),p33(nlq),p34(nlq),
     6 p35(nlq),p36(nlq),p37(nlq),p38(nlq)
      common/aux33loc/ix1(nlq),ix2(nlq),ix3(nlq),ix4(nlq),ix5(nlq),
     1 ix6(nlq),ix7(nlq),ix8(nlq),mxt(nlq)
      common/sorterloc/nnc,lczc
# 1 ".\sorter_noloc.inc" 1 
c$omp threadprivate (/bel7loc/)
c$omp threadprivate (/sorterloc/)
c$omp threadprivate (/aux33loc/)
c$omp threadprivate (/aux13loc/)
!
! NOTE: IF YOU CHANGE THIS FILE PLEASE ALSO CHANGE sorter.inc
! WHICH NEEDS TO BE IDENTICAL EXCEPT FOR znnc->nnc, zlczc->lczc
!
      real znnc,zlczc
      integer                                                           
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
      common/sorter/znnc, zlczc,                                        
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
# 3722 "dyn21usld.F" 2 
c
      dimension e(3,1)
c
      do 60 n=1,nnc
c        lcn=lczc+n+nh12-1
c        i0=ia(lcn)
c        i1=ia(lcn+1)-1
         i0=i_mem(dm_hnfegc+lczc+n-1)
         i1=i_mem(dm_hnfegc+lczc+n  )-1
         if (i1.lt.lft) go to 60
         if (i0.gt.llt) go to 70
         i0=max(i0,lft)
         i1=min(i1,llt)
         do i=i0,i1
            e(1,ix1(i))=e(1,ix1(i))+p11(i)-frc(i,1)
            e(2,ix1(i))=e(2,ix1(i))+p21(i)-frc(i,2)
            e(3,ix1(i))=e(3,ix1(i))+p31(i)-frc(i,3)
            e(1,ix2(i))=e(1,ix2(i))+p12(i)-frc(i,4+nxdof)
            e(2,ix2(i))=e(2,ix2(i))+p22(i)-frc(i,5+nxdof)
            e(3,ix2(i))=e(3,ix2(i))+p32(i)-frc(i,6+nxdof)
            e(1,ix3(i))=e(1,ix3(i))+p13(i)-frc(i,7+2*nxdof)
            e(2,ix3(i))=e(2,ix3(i))+p23(i)-frc(i,8+2*nxdof)
            e(3,ix3(i))=e(3,ix3(i))+p33(i)-frc(i,9+2*nxdof)
            e(1,ix4(i))=e(1,ix4(i))+p14(i)-frc(i,10+3*nxdof)
            e(2,ix4(i))=e(2,ix4(i))+p24(i)-frc(i,11+3*nxdof)
            e(3,ix4(i))=e(3,ix4(i))+p34(i)-frc(i,12+3*nxdof)
         enddo
         do  i=i0,i1
            e(1,ix5(i))=e(1,ix5(i))+p15(i)-frc(i,13+4*nxdof)
            e(2,ix5(i))=e(2,ix5(i))+p25(i)-frc(i,14+4*nxdof)
            e(3,ix5(i))=e(3,ix5(i))+p35(i)-frc(i,15+4*nxdof)
         enddo
         do i=i0,i1
            e(1,ix6(i))=e(1,ix6(i))+p16(i)-frc(i,16+5*nxdof)
            e(2,ix6(i))=e(2,ix6(i))+p26(i)-frc(i,17+5*nxdof)
            e(3,ix6(i))=e(3,ix6(i))+p36(i)-frc(i,18+5*nxdof)
         enddo
         do i=i0,i1
            e(1,ix7(i))=e(1,ix7(i))+p17(i)-frc(i,19+6*nxdof)
            e(2,ix7(i))=e(2,ix7(i))+p27(i)-frc(i,20+6*nxdof)
            e(3,ix7(i))=e(3,ix7(i))+p37(i)-frc(i,21+6*nxdof)
         enddo
         do i=i0,i1
            e(1,ix8(i))=e(1,ix8(i))+p18(i)-frc(i,22+7*nxdof)
            e(2,ix8(i))=e(2,ix8(i))+p28(i)-frc(i,23+7*nxdof)
            e(3,ix8(i))=e(3,ix8(i))+p38(i)-frc(i,24+7*nxdof)
         enddo
         if (nxdof.gt.0) then
            do j=1,nxdof
               nsnd=(j-1)/3+1
               nsdf=j-(nsnd-1)*3
               do i=i0,i1
                  e(nsdf,ixsld(i,1,nsnd))=e(nsdf,ixsld(i,1,nsnd))-
     1                frc(i,3+j)
                  e(nsdf,ixsld(i,2,nsnd))=e(nsdf,ixsld(i,2,nsnd))-
     1                 frc(i,6+nxdof+j)
                  e(nsdf,ixsld(i,3,nsnd))=e(nsdf,ixsld(i,3,nsnd))-
     1                 frc(i,9+2*nxdof+j)
                  e(nsdf,ixsld(i,4,nsnd))=e(nsdf,ixsld(i,4,nsnd))-
     1                 frc(i,12+3*nxdof+j)
                  e(nsdf,ixsld(i,5,nsnd))=e(nsdf,ixsld(i,5,nsnd))-
     1                 frc(i,15+4*nxdof+j)
                  e(nsdf,ixsld(i,6,nsnd))=e(nsdf,ixsld(i,6,nsnd))-
     1                 frc(i,18+5*nxdof+j)
                  e(nsdf,ixsld(i,7,nsnd))=e(nsdf,ixsld(i,7,nsnd))-
     1                 frc(i,21+6*nxdof+j)
                  e(nsdf,ixsld(i,8,nsnd))=e(nsdf,ixsld(i,8,nsnd))-
     1                 frc(i,24+7*nxdof+j)
               enddo
            enddo
         endif
 60   continue
 70   continue
      return
      end
      subroutine usrsld_b(ietyp,xi,eta,zeta,lft,llt)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     compute b and g matrix
c
      include 'nlqparm'
      include 'nhisparm.inc'
      common/numcpuloc/lenvec8,lenvech
      common/aux8loc/
     & x1(nlq),x2(nlq),x3(nlq),x4(nlq),
     & x5(nlq),x6(nlq),x7(nlq),x8(nlq),
     & y1(nlq),y2(nlq),y3(nlq),y4(nlq),
     & y5(nlq),y6(nlq),y7(nlq),y8(nlq),
     & z1(nlq),z2(nlq),z3(nlq),z4(nlq),
     & z5(nlq),z6(nlq),z7(nlq),z8(nlq)
      common/bel7loc/ixsld(nlq,8,5),ixshl(nlq,4,5)
     .,bmtrx(nlq,3,3,8*(3+NXDOFUE)),
     . cmtrx(nlq,3,3,8*(3+NXDOFUE)),xdof(nlq,8,NXDOFUE),
     . dxdof(nlq,8,NXDOFUE),xhdof(nlq,8,NXDOFUE),
     . bvec(nlq,8*(3+NXDOFUE)),cvec(nlq,8*(3+NXDOFUE)),
     . frc(nlq,8*(3+NXDOFUE)),
     . stiff(nlq,64*(3+NXDOFUE)*(3+NXDOFUE)),
     . sigv(nlq),
     . gmtrx(nlq,3,3),hmtrx(nlq,3,3),cvltot(nlq),
     . xh1(nlq),xh2(nlq),xh3(nlq),xh4(nlq),
     . xh5(nlq),xh6(nlq),xh7(nlq),xh8(nlq),
     . yh1(nlq),yh2(nlq),yh3(nlq),yh4(nlq),
     . yh5(nlq),yh6(nlq),yh7(nlq),yh8(nlq),
     . zh1(nlq),zh2(nlq),zh3(nlq),zh4(nlq),
     . zh5(nlq),zh6(nlq),zh7(nlq),zh8(nlq),
     . hl11(nlq),hl12(nlq),hl13(nlq),hl21(nlq),hl22(nlq),
     . hl23(nlq),hl31(nlq),hl32(nlq),hl33(nlq),
     . xx1(nlq),xx2(nlq),xx3(nlq),xx4(nlq),
     . xx5(nlq),xx6(nlq),xx7(nlq),xx8(nlq),
     . yy1(nlq),yy2(nlq),yy3(nlq),yy4(nlq),
     . yy5(nlq),yy6(nlq),yy7(nlq),yy8(nlq),
     . zz1(nlq),zz2(nlq),zz3(nlq),zz4(nlq),
     . zz5(nlq),zz6(nlq),zz7(nlq),zz8(nlq),vlm(nlq)
c
      real n1,n2,n3,n4,n5,n6,n7,n8
      real dn1dxi,dn2dxi,dn3dxi,dn4dxi,
     .     dn5dxi,dn6dxi,dn7dxi,dn8dxi
      real dn1deta,dn2deta,dn3deta,dn4deta,
     .     dn5deta,dn6deta,dn7deta,dn8deta
      real dn1dzeta,dn2dzeta,dn3dzeta,dn4dzeta,
     .     dn5dzeta,dn6dzeta,dn7dzeta,dn8dzeta
c
c$omp threadprivate (/numcpuloc/)
c$omp threadprivate (/aux8loc/)
c$omp threadprivate (/bel7loc/)
      n1     =.125*(1.-xi)*(1.-eta)*(1.-zeta)
      n2     =.125*(1.+xi)*(1.-eta)*(1.-zeta)
      n3     =.125*(1.+xi)*(1.+eta)*(1.-zeta)
      n4     =.125*(1.-xi)*(1.+eta)*(1.-zeta)
      n5     =.125*(1.-xi)*(1.-eta)*(1.+zeta)
      n6     =.125*(1.+xi)*(1.-eta)*(1.+zeta)
      n7     =.125*(1.+xi)*(1.+eta)*(1.+zeta)
      n8     =.125*(1.-xi)*(1.+eta)*(1.+zeta)
c
      dn1dxi =-.125*(1.-eta)*(1.-zeta)
      dn2dxi = .125*(1.-eta)*(1.-zeta)
      dn3dxi = .125*(1.+eta)*(1.-zeta)
      dn4dxi =-.125*(1.+eta)*(1.-zeta)
      dn5dxi =-.125*(1.-eta)*(1.+zeta)
      dn6dxi = .125*(1.-eta)*(1.+zeta)
      dn7dxi = .125*(1.+eta)*(1.+zeta)
      dn8dxi =-.125*(1.+eta)*(1.+zeta)
c
      dn1deta=-.125*(1.-xi)*(1.-zeta)
      dn2deta=-.125*(1.+xi)*(1.-zeta)
      dn3deta= .125*(1.+xi)*(1.-zeta)
      dn4deta= .125*(1.-xi)*(1.-zeta)
      dn5deta=-.125*(1.-xi)*(1.+zeta)
      dn6deta=-.125*(1.+xi)*(1.+zeta)
      dn7deta= .125*(1.+xi)*(1.+zeta)
      dn8deta= .125*(1.-xi)*(1.+zeta)
c
      dn1dzeta=-.125*(1.-xi)*(1.-eta)
      dn2dzeta=-.125*(1.+xi)*(1.-eta)
      dn3dzeta=-.125*(1.+xi)*(1.+eta)
      dn4dzeta=-.125*(1.-xi)*(1.+eta)
      dn5dzeta= .125*(1.-xi)*(1.-eta)
      dn6dzeta= .125*(1.+xi)*(1.-eta)
      dn7dzeta= .125*(1.+xi)*(1.+eta)
      dn8dzeta= .125*(1.-xi)*(1.+eta)
c
      if (lenvec8.ne.0) then
c
      do l=1,8*(3+NXDOFUE)
         do k=1,3
            do j=1,3
               do i=lft,llt
                  bmtrx(i,j,k,l)=0.
               enddo
            enddo
         enddo
      enddo
c
      if (ietyp.eq.101) then
         call usld_b101(bmtrx,gmtrx,gmtrx,
     1        xi,eta,zeta,
     2        n1,n2,n3,n4,n5,n6,n7,n8,
     3        dn1dxi,dn2dxi,dn3dxi,dn4dxi,
     4        dn5dxi,dn6dxi,dn7dxi,dn8dxi,
     5        dn1deta,dn2deta,dn3deta,dn4deta,
     6        dn5deta,dn6deta,dn7deta,dn8deta,
     7        dn1dzeta,dn2dzeta,dn3dzeta,dn4dzeta,
     8        dn5dzeta,dn6dzeta,dn7dzeta,dn8dzeta,
     9        xh1,xh2,xh3,xh4,xh5,xh6,xh7,xh8,
     .        yh1,yh2,yh3,yh4,yh5,yh6,yh7,yh8,
     .        zh1,zh2,zh3,zh4,zh5,zh6,zh7,zh8,
     .        xhdof,
     .        lft,llt)
      elseif (ietyp.eq.102) then
         call usld_b102(bmtrx,gmtrx,gmtrx,
     1        xi,eta,zeta,
     2        n1,n2,n3,n4,n5,n6,n7,n8,
     3        dn1dxi,dn2dxi,dn3dxi,dn4dxi,
     4        dn5dxi,dn6dxi,dn7dxi,dn8dxi,
     5        dn1deta,dn2deta,dn3deta,dn4deta,
     6        dn5deta,dn6deta,dn7deta,dn8deta,
     7        dn1dzeta,dn2dzeta,dn3dzeta,dn4dzeta,
     8        dn5dzeta,dn6dzeta,dn7dzeta,dn8dzeta,
     9        xh1,xh2,xh3,xh4,xh5,xh6,xh7,xh8,
     .        yh1,yh2,yh3,yh4,yh5,yh6,yh7,yh8,
     .        zh1,zh2,zh3,zh4,zh5,zh6,zh7,zh8,
     .        xhdof,
     .        lft,llt)
      elseif (ietyp.eq.103) then
         call usld_b103(bmtrx,gmtrx,gmtrx,
     1        xi,eta,zeta,
     2        n1,n2,n3,n4,n5,n6,n7,n8,
     3        dn1dxi,dn2dxi,dn3dxi,dn4dxi,
     4        dn5dxi,dn6dxi,dn7dxi,dn8dxi,
     5        dn1deta,dn2deta,dn3deta,dn4deta,
     6        dn5deta,dn6deta,dn7deta,dn8deta,
     7        dn1dzeta,dn2dzeta,dn3dzeta,dn4dzeta,
     8        dn5dzeta,dn6dzeta,dn7dzeta,dn8dzeta,
     9        xh1,xh2,xh3,xh4,xh5,xh6,xh7,xh8,
     .        yh1,yh2,yh3,yh4,yh5,yh6,yh7,yh8,
     .        zh1,zh2,zh3,zh4,zh5,zh6,zh7,zh8,
     .        xhdof,
     .        lft,llt)
      elseif (ietyp.eq.104) then
         call usld_b104(bmtrx,gmtrx,gmtrx,
     1        xi,eta,zeta,
     2        n1,n2,n3,n4,n5,n6,n7,n8,
     3        dn1dxi,dn2dxi,dn3dxi,dn4dxi,
     4        dn5dxi,dn6dxi,dn7dxi,dn8dxi,
     5        dn1deta,dn2deta,dn3deta,dn4deta,
     6        dn5deta,dn6deta,dn7deta,dn8deta,
     7        dn1dzeta,dn2dzeta,dn3dzeta,dn4dzeta,
     8        dn5dzeta,dn6dzeta,dn7dzeta,dn8dzeta,
     9        xh1,xh2,xh3,xh4,xh5,xh6,xh7,xh8,
     .        yh1,yh2,yh3,yh4,yh5,yh6,yh7,yh8,
     .        zh1,zh2,zh3,zh4,zh5,zh6,zh7,zh8,
     .        xhdof,
     .        lft,llt)
      elseif (ietyp.eq.105) then
         call usld_b105(bmtrx,gmtrx,gmtrx,
     1        xi,eta,zeta,
     2        n1,n2,n3,n4,n5,n6,n7,n8,
     3        dn1dxi,dn2dxi,dn3dxi,dn4dxi,
     4        dn5dxi,dn6dxi,dn7dxi,dn8dxi,
     5        dn1deta,dn2deta,dn3deta,dn4deta,
     6        dn5deta,dn6deta,dn7deta,dn8deta,
     7        dn1dzeta,dn2dzeta,dn3dzeta,dn4dzeta,
     8        dn5dzeta,dn6dzeta,dn7dzeta,dn8dzeta,
     9        xh1,xh2,xh3,xh4,xh5,xh6,xh7,xh8,
     .        yh1,yh2,yh3,yh4,yh5,yh6,yh7,yh8,
     .        zh1,zh2,zh3,zh4,zh5,zh6,zh7,zh8,
     .        xhdof,
     .        lft,llt)
      endif
c
      endif
c
      do l=1,8*(3+NXDOFUE)
         do k=1,3
            do j=1,3
               do i=lft,llt
                  cmtrx(i,j,k,l)=0.
               enddo
            enddo
         enddo
      enddo
c
      if (ietyp.eq.101) then
         call usld_b101(cmtrx,hmtrx,hmtrx,
     1        xi,eta,zeta,
     2        n1,n2,n3,n4,n5,n6,n7,n8,
     3        dn1dxi,dn2dxi,dn3dxi,dn4dxi,
     4        dn5dxi,dn6dxi,dn7dxi,dn8dxi,
     5        dn1deta,dn2deta,dn3deta,dn4deta,
     6        dn5deta,dn6deta,dn7deta,dn8deta,
     7        dn1dzeta,dn2dzeta,dn3dzeta,dn4dzeta,
     8        dn5dzeta,dn6dzeta,dn7dzeta,dn8dzeta,
     9        x1,x2,x3,x4,x5,x6,x7,x8,
     .        y1,y2,y3,y4,y5,y6,y7,y8,
     .        z1,z2,z3,z4,z5,z6,z7,z8,
     .        xdof,
     .        lft,llt)
      elseif (ietyp.eq.102) then
         call usld_b102(cmtrx,hmtrx,hmtrx,
     1        xi,eta,zeta,
     2        n1,n2,n3,n4,n5,n6,n7,n8,
     3        dn1dxi,dn2dxi,dn3dxi,dn4dxi,
     4        dn5dxi,dn6dxi,dn7dxi,dn8dxi,
     5        dn1deta,dn2deta,dn3deta,dn4deta,
     6        dn5deta,dn6deta,dn7deta,dn8deta,
     7        dn1dzeta,dn2dzeta,dn3dzeta,dn4dzeta,
     8        dn5dzeta,dn6dzeta,dn7dzeta,dn8dzeta,
     9        x1,x2,x3,x4,x5,x6,x7,x8,
     .        y1,y2,y3,y4,y5,y6,y7,y8,
     .        z1,z2,z3,z4,z5,z6,z7,z8,
     .        xdof,
     .        lft,llt)
      elseif (ietyp.eq.103) then
         call usld_b103(cmtrx,hmtrx,hmtrx,
     1        xi,eta,zeta,
     2        n1,n2,n3,n4,n5,n6,n7,n8,
     3        dn1dxi,dn2dxi,dn3dxi,dn4dxi,
     4        dn5dxi,dn6dxi,dn7dxi,dn8dxi,
     5        dn1deta,dn2deta,dn3deta,dn4deta,
     6        dn5deta,dn6deta,dn7deta,dn8deta,
     7        dn1dzeta,dn2dzeta,dn3dzeta,dn4dzeta,
     8        dn5dzeta,dn6dzeta,dn7dzeta,dn8dzeta,
     9        x1,x2,x3,x4,x5,x6,x7,x8,
     .        y1,y2,y3,y4,y5,y6,y7,y8,
     .        z1,z2,z3,z4,z5,z6,z7,z8,
     .        xdof,
     .        lft,llt)
      elseif (ietyp.eq.104) then
         call usld_b104(cmtrx,hmtrx,hmtrx,
     1        xi,eta,zeta,
     2        n1,n2,n3,n4,n5,n6,n7,n8,
     3        dn1dxi,dn2dxi,dn3dxi,dn4dxi,
     4        dn5dxi,dn6dxi,dn7dxi,dn8dxi,
     5        dn1deta,dn2deta,dn3deta,dn4deta,
     6        dn5deta,dn6deta,dn7deta,dn8deta,
     7        dn1dzeta,dn2dzeta,dn3dzeta,dn4dzeta,
     8        dn5dzeta,dn6dzeta,dn7dzeta,dn8dzeta,
     9        x1,x2,x3,x4,x5,x6,x7,x8,
     .        y1,y2,y3,y4,y5,y6,y7,y8,
     .        z1,z2,z3,z4,z5,z6,z7,z8,
     .        xdof,
     .        lft,llt)
      elseif (ietyp.eq.105) then
         call usld_b105(cmtrx,hmtrx,hmtrx,
     1        xi,eta,zeta,
     2        n1,n2,n3,n4,n5,n6,n7,n8,
     3        dn1dxi,dn2dxi,dn3dxi,dn4dxi,
     4        dn5dxi,dn6dxi,dn7dxi,dn8dxi,
     5        dn1deta,dn2deta,dn3deta,dn4deta,
     6        dn5deta,dn6deta,dn7deta,dn8deta,
     7        dn1dzeta,dn2dzeta,dn3dzeta,dn4dzeta,
     8        dn5dzeta,dn6dzeta,dn7dzeta,dn8dzeta,
     9        x1,x2,x3,x4,x5,x6,x7,x8,
     .        y1,y2,y3,y4,y5,y6,y7,y8,
     .        z1,z2,z3,z4,z5,z6,z7,z8,
     .        xdof,
     .        lft,llt)
      endif
c
      if (lenvec8.eq.0) then
      do l=1,8*(3+NXDOFUE)
         do k=1,3
            do j=1,3
               do i=lft,llt
                  bmtrx(i,j,k,l)=cmtrx(i,j,k,l)
               enddo
            enddo
         enddo
      enddo
      endif
c
      return
      end
      subroutine usld_b101(bmtrx,gmtrx,gjac,
     1 xi,eta,zeta,
     2 n1,n2,n3,n4,n5,n6,n7,n8,
     3 dn1dxi,dn2dxi,dn3dxi,dn4dxi,
     4 dn5dxi,dn6dxi,dn7dxi,dn8dxi,
     5 dn1deta,dn2deta,dn3deta,dn4deta,
     6 dn5deta,dn6deta,dn7deta,dn8deta,
     7 dn1dzeta,dn2dzeta,dn3dzeta,dn4dzeta,
     8 dn5dzeta,dn6dzeta,dn7dzeta,dn8dzeta,
     9 x1,x2,x3,x4,x5,x6,x7,x8,
     . y1,y2,y3,y4,y5,y6,y7,y8,
     . z1,z2,z3,z4,z5,z6,z7,z8,
     . xdof,
     . lft,llt)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     compute b and g matrix for user defined solid 101
c
      include 'nlqparm'
      dimension bmtrx(nlq,3,3,*),gmtrx(nlq,3,3),gjac(nlq)
      real n1,n2,n3,n4,n5,n6,n7,n8
      dimension x1(nlq),x2(nlq),x3(nlq),x4(nlq)
      dimension x5(nlq),x6(nlq),x7(nlq),x8(nlq)
      dimension y1(nlq),y2(nlq),y3(nlq),y4(nlq)
      dimension y5(nlq),y6(nlq),y7(nlq),y8(nlq)
      dimension z1(nlq),z2(nlq),z3(nlq),z4(nlq)
      dimension z5(nlq),z6(nlq),z7(nlq),z8(nlq)
      dimension xdof(nlq,8,*)
c
c     Variable description
c
c     outputs:
c
c     bmtrx = gradient-displacement matrix
c     gmtrx = jacobian matrix (ITAJ=0)
c     gjac  = jacobian determinant (ITAJ=1)
c
c     inputs:
c
c     xi,eta,zeta                     = parental coordinates
c     n1,n2,n3,n4,n5,n6,n7,n8         = nodal shape function values
c     dn1dxi,dn2dxi,dn3dxi,dn4dxi,
c     dn5dxi,dn6dxi,dn7dxi,dn8dxi     = nodal shape function derivatives
c                                       w.r.t. first parental coordinate
c     dn1deta,dn2deta,dn3deta,dn4deta,
c     dn5deta,dn6deta,dn7deta,dn8deta = nodal shape function derivatives
c                                       w.r.t. second parental coordinate
c     dn1dzeta,dn2dzeta,
c     dn3dzeta,dn4dzeta,
c     dn5dzeta,dn6dzeta,
c     dn7dzeta,dn8dzeta               = nodal shape function derivatives
c                                       w.r.t. third parental coordinate
c     x1,x2,x3,x4,x5,x6,x7,x8         = x-coordinates of nodes
c     y1,y2,y3,y4,y5,y6,y7,y8         = y-coordinates of nodes
c     z1,z2,z3,z4,z5,z6,z7,z8         = z-coordinates of nodes
c     xdof                            = values corresponding to
c                                       extra degrees of freedom (NXDOF.GT.0)
c
      do i=lft,llt
c
         bmtrx(i,1,1,1) =dn1dxi
         bmtrx(i,1,1,4) =dn2dxi
         bmtrx(i,1,1,7) =dn3dxi
         bmtrx(i,1,1,10)=dn4dxi
         bmtrx(i,1,1,13)=dn5dxi
         bmtrx(i,1,1,16)=dn6dxi
         bmtrx(i,1,1,19)=dn7dxi
         bmtrx(i,1,1,22)=dn8dxi
c
         bmtrx(i,2,1,2) =dn1dxi
         bmtrx(i,2,1,5) =dn2dxi
         bmtrx(i,2,1,8) =dn3dxi
         bmtrx(i,2,1,11)=dn4dxi
         bmtrx(i,2,1,14)=dn5dxi
         bmtrx(i,2,1,17)=dn6dxi
         bmtrx(i,2,1,20)=dn7dxi
         bmtrx(i,2,1,23)=dn8dxi
c
         bmtrx(i,3,1,3) =dn1dxi
         bmtrx(i,3,1,6) =dn2dxi
         bmtrx(i,3,1,9) =dn3dxi
         bmtrx(i,3,1,12)=dn4dxi
         bmtrx(i,3,1,15)=dn5dxi
         bmtrx(i,3,1,18)=dn6dxi
         bmtrx(i,3,1,21)=dn7dxi
         bmtrx(i,3,1,24)=dn8dxi
c
         bmtrx(i,1,2,1) =dn1deta
         bmtrx(i,1,2,4) =dn2deta
         bmtrx(i,1,2,7) =dn3deta
         bmtrx(i,1,2,10)=dn4deta
         bmtrx(i,1,2,13)=dn5deta
         bmtrx(i,1,2,16)=dn6deta
         bmtrx(i,1,2,19)=dn7deta
         bmtrx(i,1,2,22)=dn8deta
c
         bmtrx(i,2,2,2) =dn1deta
         bmtrx(i,2,2,5) =dn2deta
         bmtrx(i,2,2,8) =dn3deta
         bmtrx(i,2,2,11)=dn4deta
         bmtrx(i,2,2,14)=dn5deta
         bmtrx(i,2,2,17)=dn6deta
         bmtrx(i,2,2,20)=dn7deta
         bmtrx(i,2,2,23)=dn8deta
c
         bmtrx(i,3,2,3) =dn1deta
         bmtrx(i,3,2,6) =dn2deta
         bmtrx(i,3,2,9) =dn3deta
         bmtrx(i,3,2,12)=dn4deta
         bmtrx(i,3,2,15)=dn5deta
         bmtrx(i,3,2,18)=dn6deta
         bmtrx(i,3,2,21)=dn7deta
         bmtrx(i,3,2,24)=dn8deta
c
         bmtrx(i,1,3,1) =dn1dzeta
         bmtrx(i,1,3,4) =dn2dzeta
         bmtrx(i,1,3,7) =dn3dzeta
         bmtrx(i,1,3,10)=dn4dzeta
         bmtrx(i,1,3,13)=dn5dzeta
         bmtrx(i,1,3,16)=dn6dzeta
         bmtrx(i,1,3,19)=dn7dzeta
         bmtrx(i,1,3,22)=dn8dzeta
c
         bmtrx(i,2,3,2) =dn1dzeta
         bmtrx(i,2,3,5) =dn2dzeta
         bmtrx(i,2,3,8) =dn3dzeta
         bmtrx(i,2,3,11)=dn4dzeta
         bmtrx(i,2,3,14)=dn5dzeta
         bmtrx(i,2,3,17)=dn6dzeta
         bmtrx(i,2,3,20)=dn7dzeta
         bmtrx(i,2,3,23)=dn8dzeta
c
         bmtrx(i,3,3,3) =dn1dzeta
         bmtrx(i,3,3,6) =dn2dzeta
         bmtrx(i,3,3,9) =dn3dzeta
         bmtrx(i,3,3,12)=dn4dzeta
         bmtrx(i,3,3,15)=dn5dzeta
         bmtrx(i,3,3,18)=dn6dzeta
         bmtrx(i,3,3,21)=dn7dzeta
         bmtrx(i,3,3,24)=dn8dzeta
c
         gmtrx(i,1,1)=x1(i)*dn1dxi+x2(i)*dn2dxi+
     1        x3(i)*dn3dxi+x4(i)*dn4dxi+
     2        x5(i)*dn5dxi+x6(i)*dn6dxi+
     3        x7(i)*dn7dxi+x8(i)*dn8dxi
         gmtrx(i,2,1)=y1(i)*dn1dxi+y2(i)*dn2dxi+
     1        y3(i)*dn3dxi+y4(i)*dn4dxi+
     2        y5(i)*dn5dxi+y6(i)*dn6dxi+
     3        y7(i)*dn7dxi+y8(i)*dn8dxi
         gmtrx(i,3,1)=z1(i)*dn1dxi+z2(i)*dn2dxi+
     1        z3(i)*dn3dxi+z4(i)*dn4dxi+
     2        z5(i)*dn5dxi+z6(i)*dn6dxi+
     3        z7(i)*dn7dxi+z8(i)*dn8dxi
         gmtrx(i,1,2)=x1(i)*dn1deta+x2(i)*dn2deta+
     1        x3(i)*dn3deta+x4(i)*dn4deta+
     2        x5(i)*dn5deta+x6(i)*dn6deta+
     3        x7(i)*dn7deta+x8(i)*dn8deta
         gmtrx(i,2,2)=y1(i)*dn1deta+y2(i)*dn2deta+
     1        y3(i)*dn3deta+y4(i)*dn4deta+
     2        y5(i)*dn5deta+y6(i)*dn6deta+
     3        y7(i)*dn7deta+y8(i)*dn8deta
         gmtrx(i,3,2)=z1(i)*dn1deta+z2(i)*dn2deta+
     1        z3(i)*dn3deta+z4(i)*dn4deta+
     2        z5(i)*dn5deta+z6(i)*dn6deta+
     3        z7(i)*dn7deta+z8(i)*dn8deta
         gmtrx(i,1,3)=x1(i)*dn1dzeta+x2(i)*dn2dzeta+
     1        x3(i)*dn3dzeta+x4(i)*dn4dzeta+
     2        x5(i)*dn5dzeta+x6(i)*dn6dzeta+
     3        x7(i)*dn7dzeta+x8(i)*dn8dzeta
         gmtrx(i,2,3)=y1(i)*dn1dzeta+y2(i)*dn2dzeta+
     1        y3(i)*dn3dzeta+y4(i)*dn4dzeta+
     2        y5(i)*dn5dzeta+y6(i)*dn6dzeta+
     3        y7(i)*dn7dzeta+y8(i)*dn8dzeta
         gmtrx(i,3,3)=z1(i)*dn1dzeta+z2(i)*dn2dzeta+
     1        z3(i)*dn3dzeta+z4(i)*dn4dzeta+
     2        z5(i)*dn5dzeta+z6(i)*dn6dzeta+
     3        z7(i)*dn7dzeta+z8(i)*dn8dzeta
c
      enddo
c
      return
      end
      subroutine usld_b102(bmtrx,gmtrx,gjac,
     1 xi,eta,zeta,
     2 n1,n2,n3,n4,n5,n6,n7,n8,
     3 dn1dxi,dn2dxi,dn3dxi,dn4dxi,
     4 dn5dxi,dn6dxi,dn7dxi,dn8dxi,
     5 dn1deta,dn2deta,dn3deta,dn4deta,
     6 dn5deta,dn6deta,dn7deta,dn8deta,
     7 dn1dzeta,dn2dzeta,dn3dzeta,dn4dzeta,
     8 dn5dzeta,dn6dzeta,dn7dzeta,dn8dzeta,
     9 x1,x2,x3,x4,x5,x6,x7,x8,
     . y1,y2,y3,y4,y5,y6,y7,y8,
     . z1,z2,z3,z4,z5,z6,z7,z8,
     . xdof,
     . lft,llt)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     compute b and g matrix for user defined solid 102
c
c     This is an example of a constant stress solid, see Vol I, Appendix
c     C, of the user manual.
c
      include 'nlqparm'
      dimension bmtrx(nlq,3,3,*),gmtrx(nlq,3,3),gjac(nlq)
      real n1,n2,n3,n4,n5,n6,n7,n8
      dimension x1(nlq),x2(nlq),x3(nlq),x4(nlq)
      dimension x5(nlq),x6(nlq),x7(nlq),x8(nlq)
      dimension y1(nlq),y2(nlq),y3(nlq),y4(nlq)
      dimension y5(nlq),y6(nlq),y7(nlq),y8(nlq)
      dimension z1(nlq),z2(nlq),z3(nlq),z4(nlq)
      dimension z5(nlq),z6(nlq),z7(nlq),z8(nlq)
      dimension xdof(nlq,8,*)
c
c     Variable description
c
c     outputs:
c
c     bmtrx = gradient-displacement matrix
c     gmtrx = jacobian matrix (ITAJ=0)
c     gjac  = jacobian determinant (ITAJ=1)
c
c     inputs:
c
c     xi,eta,zeta                     = parental coordinates
c     n1,n2,n3,n4,n5,n6,n7,n8         = nodal shape function values
c     dn1dxi,dn2dxi,dn3dxi,dn4dxi,
c     dn5dxi,dn6dxi,dn7dxi,dn8dxi     = nodal shape function derivatives
c                                       w.r.t. first parental coordinate
c     dn1deta,dn2deta,dn3deta,dn4deta,
c     dn5deta,dn6deta,dn7deta,dn8deta = nodal shape function derivatives
c                                       w.r.t. second parental coordinate
c     dn1dzeta,dn2dzeta,
c     dn3dzeta,dn4dzeta,
c     dn5dzeta,dn6dzeta,
c     dn7dzeta,dn8dzeta               = nodal shape function derivatives
c                                       w.r.t. third parental coordinate
c     x1,x2,x3,x4,x5,x6,x7,x8         = x-coordinates of nodes
c     y1,y2,y3,y4,y5,y6,y7,y8         = y-coordinates of nodes
c     z1,z2,z3,z4,z5,z6,z7,z8         = z-coordinates of nodes
c     xdof                            = values corresponding to
c                                       extra degrees of freedom (NXDOF.GT.0)
c
      dimension factor(nlq),gitrx(nlq,3,3),dvec(nlq,24)
c
c     Shape function at origin wrt isoparametric coord: dN_I(0)/dxi_j
      dm1dxi =-.125
      dm2dxi = .125
      dm3dxi = .125
      dm4dxi =-.125
      dm5dxi =-.125
      dm6dxi = .125
      dm7dxi = .125
      dm8dxi =-.125
c
      dm1deta=-.125
      dm2deta=-.125
      dm3deta= .125
      dm4deta= .125
      dm5deta=-.125
      dm6deta=-.125
      dm7deta= .125
      dm8deta= .125
c
      dm1dzeta=-.125
      dm2dzeta=-.125
      dm3dzeta=-.125
      dm4dzeta=-.125
      dm5dzeta= .125
      dm6dzeta= .125
      dm7dzeta= .125
      dm8dzeta= .125
c
c     Gradient displacement matrix in origin wrt isoparametric coord:
c     B_ijIk(0) = dN_I(0)/dxi_j*delta_ik
      do i=lft,llt
c
         bmtrx(i,1,1,1) =dm1dxi
         bmtrx(i,1,1,4) =dm2dxi
         bmtrx(i,1,1,7) =dm3dxi
         bmtrx(i,1,1,10)=dm4dxi
         bmtrx(i,1,1,13)=dm5dxi
         bmtrx(i,1,1,16)=dm6dxi
         bmtrx(i,1,1,19)=dm7dxi
         bmtrx(i,1,1,22)=dm8dxi
c
         bmtrx(i,2,1,2) =dm1dxi
         bmtrx(i,2,1,5) =dm2dxi
         bmtrx(i,2,1,8) =dm3dxi
         bmtrx(i,2,1,11)=dm4dxi
         bmtrx(i,2,1,14)=dm5dxi
         bmtrx(i,2,1,17)=dm6dxi
         bmtrx(i,2,1,20)=dm7dxi
         bmtrx(i,2,1,23)=dm8dxi
c
         bmtrx(i,3,1,3) =dm1dxi
         bmtrx(i,3,1,6) =dm2dxi
         bmtrx(i,3,1,9) =dm3dxi
         bmtrx(i,3,1,12)=dm4dxi
         bmtrx(i,3,1,15)=dm5dxi
         bmtrx(i,3,1,18)=dm6dxi
         bmtrx(i,3,1,21)=dm7dxi
         bmtrx(i,3,1,24)=dm8dxi
c
         bmtrx(i,1,2,1) =dm1deta
         bmtrx(i,1,2,4) =dm2deta
         bmtrx(i,1,2,7) =dm3deta
         bmtrx(i,1,2,10)=dm4deta
         bmtrx(i,1,2,13)=dm5deta
         bmtrx(i,1,2,16)=dm6deta
         bmtrx(i,1,2,19)=dm7deta
         bmtrx(i,1,2,22)=dm8deta
c
         bmtrx(i,2,2,2) =dm1deta
         bmtrx(i,2,2,5) =dm2deta
         bmtrx(i,2,2,8) =dm3deta
         bmtrx(i,2,2,11)=dm4deta
         bmtrx(i,2,2,14)=dm5deta
         bmtrx(i,2,2,17)=dm6deta
         bmtrx(i,2,2,20)=dm7deta
         bmtrx(i,2,2,23)=dm8deta
c
         bmtrx(i,3,2,3) =dm1deta
         bmtrx(i,3,2,6) =dm2deta
         bmtrx(i,3,2,9) =dm3deta
         bmtrx(i,3,2,12)=dm4deta
         bmtrx(i,3,2,15)=dm5deta
         bmtrx(i,3,2,18)=dm6deta
         bmtrx(i,3,2,21)=dm7deta
         bmtrx(i,3,2,24)=dm8deta
c
         bmtrx(i,1,3,1) =dm1dzeta
         bmtrx(i,1,3,4) =dm2dzeta
         bmtrx(i,1,3,7) =dm3dzeta
         bmtrx(i,1,3,10)=dm4dzeta
         bmtrx(i,1,3,13)=dm5dzeta
         bmtrx(i,1,3,16)=dm6dzeta
         bmtrx(i,1,3,19)=dm7dzeta
         bmtrx(i,1,3,22)=dm8dzeta
c
         bmtrx(i,2,3,2) =dm1dzeta
         bmtrx(i,2,3,5) =dm2dzeta
         bmtrx(i,2,3,8) =dm3dzeta
         bmtrx(i,2,3,11)=dm4dzeta
         bmtrx(i,2,3,14)=dm5dzeta
         bmtrx(i,2,3,17)=dm6dzeta
         bmtrx(i,2,3,20)=dm7dzeta
         bmtrx(i,2,3,23)=dm8dzeta
c
         bmtrx(i,3,3,3) =dm1dzeta
         bmtrx(i,3,3,6) =dm2dzeta
         bmtrx(i,3,3,9) =dm3dzeta
         bmtrx(i,3,3,12)=dm4dzeta
         bmtrx(i,3,3,15)=dm5dzeta
         bmtrx(i,3,3,18)=dm6dzeta
         bmtrx(i,3,3,21)=dm7dzeta
         bmtrx(i,3,3,24)=dm8dzeta
c
      enddo
c
c     Jacobian at origin wrt isoparametric coord:
c     g_ij(0) = dx_i(0)/dxi_j = dx_Ii*dN_I(0)/dxi_j
      do i=lft,llt
c
         gmtrx(i,1,1)=x1(i)*dm1dxi+x2(i)*dm2dxi+
     1        x3(i)*dm3dxi+x4(i)*dm4dxi+
     2        x5(i)*dm5dxi+x6(i)*dm6dxi+
     3        x7(i)*dm7dxi+x8(i)*dm8dxi
         gmtrx(i,2,1)=y1(i)*dm1dxi+y2(i)*dm2dxi+
     1        y3(i)*dm3dxi+y4(i)*dm4dxi+
     2        y5(i)*dm5dxi+y6(i)*dm6dxi+
     3        y7(i)*dm7dxi+y8(i)*dm8dxi
         gmtrx(i,3,1)=z1(i)*dm1dxi+z2(i)*dm2dxi+
     1        z3(i)*dm3dxi+z4(i)*dm4dxi+
     2        z5(i)*dm5dxi+z6(i)*dm6dxi+
     3        z7(i)*dm7dxi+z8(i)*dm8dxi
         gmtrx(i,1,2)=x1(i)*dm1deta+x2(i)*dm2deta+
     1        x3(i)*dm3deta+x4(i)*dm4deta+
     2        x5(i)*dm5deta+x6(i)*dm6deta+
     3        x7(i)*dm7deta+x8(i)*dm8deta
         gmtrx(i,2,2)=y1(i)*dm1deta+y2(i)*dm2deta+
     1        y3(i)*dm3deta+y4(i)*dm4deta+
     2        y5(i)*dm5deta+y6(i)*dm6deta+
     3        y7(i)*dm7deta+y8(i)*dm8deta
         gmtrx(i,3,2)=z1(i)*dm1deta+z2(i)*dm2deta+
     1        z3(i)*dm3deta+z4(i)*dm4deta+
     2        z5(i)*dm5deta+z6(i)*dm6deta+
     3        z7(i)*dm7deta+z8(i)*dm8deta
         gmtrx(i,1,3)=x1(i)*dm1dzeta+x2(i)*dm2dzeta+
     1        x3(i)*dm3dzeta+x4(i)*dm4dzeta+
     2        x5(i)*dm5dzeta+x6(i)*dm6dzeta+
     3        x7(i)*dm7dzeta+x8(i)*dm8dzeta
         gmtrx(i,2,3)=y1(i)*dm1dzeta+y2(i)*dm2dzeta+
     1        y3(i)*dm3dzeta+y4(i)*dm4dzeta+
     2        y5(i)*dm5dzeta+y6(i)*dm6dzeta+
     3        y7(i)*dm7dzeta+y8(i)*dm8dzeta
         gmtrx(i,3,3)=z1(i)*dm1dzeta+z2(i)*dm2dzeta+
     1        z3(i)*dm3dzeta+z4(i)*dm4dzeta+
     2        z5(i)*dm5dzeta+z6(i)*dm6dzeta+
     3        z7(i)*dm7dzeta+z8(i)*dm8dzeta
c
      enddo
c
c     Inverse Jacobian
      do i=lft,llt
c
         factor(i)=gmtrx(i,1,1)*(gmtrx(i,2,2)*gmtrx(i,3,3)-
     1        gmtrx(i,3,2)*gmtrx(i,2,3))+
     2        gmtrx(i,2,1)*(gmtrx(i,3,2)*gmtrx(i,1,3)-
     3        gmtrx(i,1,2)*gmtrx(i,3,3))+
     4        gmtrx(i,3,1)*(gmtrx(i,1,2)*gmtrx(i,2,3)-
     5        gmtrx(i,2,2)*gmtrx(i,1,3))
c
         gjc=1./factor(i)
         g11i=gmtrx(i,2,2)*gmtrx(i,3,3)-gmtrx(i,2,3)*gmtrx(i,3,2)
         g12i=gmtrx(i,3,2)*gmtrx(i,1,3)-gmtrx(i,3,3)*gmtrx(i,1,2)
         g13i=gmtrx(i,1,2)*gmtrx(i,2,3)-gmtrx(i,1,3)*gmtrx(i,2,2)
         g21i=gmtrx(i,2,3)*gmtrx(i,3,1)-gmtrx(i,2,1)*gmtrx(i,3,3)
         g22i=gmtrx(i,3,3)*gmtrx(i,1,1)-gmtrx(i,3,1)*gmtrx(i,1,3)
         g23i=gmtrx(i,1,3)*gmtrx(i,2,1)-gmtrx(i,1,1)*gmtrx(i,2,3)
         g31i=gmtrx(i,2,1)*gmtrx(i,3,2)-gmtrx(i,2,2)*gmtrx(i,3,1)
         g32i=gmtrx(i,3,1)*gmtrx(i,1,2)-gmtrx(i,3,2)*gmtrx(i,1,1)
         g33i=gmtrx(i,1,1)*gmtrx(i,2,2)-gmtrx(i,1,2)*gmtrx(i,2,1)
         gitrx(i,1,1)=gjc*g11i
         gitrx(i,2,1)=gjc*g21i
         gitrx(i,3,1)=gjc*g31i
         gitrx(i,1,2)=gjc*g12i
         gitrx(i,2,2)=gjc*g22i
         gitrx(i,3,2)=gjc*g32i
         gitrx(i,1,3)=gjc*g13i
         gitrx(i,2,3)=gjc*g23i
         gitrx(i,3,3)=gjc*g33i
c
      enddo
c
c     Summation of gradient displacement matrix wrt pysical coord at each node:
c     dvec_Il = B_ijIk(0)*(g_ij(0))^-1 = dN_I(0)/dxi_k
      do j=1,24
         do i=lft,llt
            dvec(i,j)=0.
         enddo
      enddo
      do l=1,24
         do k=1,3
            do j=1,3
               do i=lft,llt
                  dvec(i,l)=dvec(i,l)+bmtrx(i,j,k,l)*gitrx(i,k,j)
               enddo
            enddo
         enddo
      enddo
c
c     Gradient displacement matrix wrt isoparametric coord:
c     B_ijIk = dN_I/dxi_j*delta_ik
      do i=lft,llt
c
         bmtrx(i,1,1,1) =dn1dxi
         bmtrx(i,1,1,4) =dn2dxi
         bmtrx(i,1,1,7) =dn3dxi
         bmtrx(i,1,1,10)=dn4dxi
         bmtrx(i,1,1,13)=dn5dxi
         bmtrx(i,1,1,16)=dn6dxi
         bmtrx(i,1,1,19)=dn7dxi
         bmtrx(i,1,1,22)=dn8dxi
c
         bmtrx(i,2,1,2) =dn1dxi
         bmtrx(i,2,1,5) =dn2dxi
         bmtrx(i,2,1,8) =dn3dxi
         bmtrx(i,2,1,11)=dn4dxi
         bmtrx(i,2,1,14)=dn5dxi
         bmtrx(i,2,1,17)=dn6dxi
         bmtrx(i,2,1,20)=dn7dxi
         bmtrx(i,2,1,23)=dn8dxi
c
         bmtrx(i,3,1,3) =dn1dxi
         bmtrx(i,3,1,6) =dn2dxi
         bmtrx(i,3,1,9) =dn3dxi
         bmtrx(i,3,1,12)=dn4dxi
         bmtrx(i,3,1,15)=dn5dxi
         bmtrx(i,3,1,18)=dn6dxi
         bmtrx(i,3,1,21)=dn7dxi
         bmtrx(i,3,1,24)=dn8dxi
c
         bmtrx(i,1,2,1) =dn1deta
         bmtrx(i,1,2,4) =dn2deta
         bmtrx(i,1,2,7) =dn3deta
         bmtrx(i,1,2,10)=dn4deta
         bmtrx(i,1,2,13)=dn5deta
         bmtrx(i,1,2,16)=dn6deta
         bmtrx(i,1,2,19)=dn7deta
         bmtrx(i,1,2,22)=dn8deta
c
         bmtrx(i,2,2,2) =dn1deta
         bmtrx(i,2,2,5) =dn2deta
         bmtrx(i,2,2,8) =dn3deta
         bmtrx(i,2,2,11)=dn4deta
         bmtrx(i,2,2,14)=dn5deta
         bmtrx(i,2,2,17)=dn6deta
         bmtrx(i,2,2,20)=dn7deta
         bmtrx(i,2,2,23)=dn8deta
c
         bmtrx(i,3,2,3) =dn1deta
         bmtrx(i,3,2,6) =dn2deta
         bmtrx(i,3,2,9) =dn3deta
         bmtrx(i,3,2,12)=dn4deta
         bmtrx(i,3,2,15)=dn5deta
         bmtrx(i,3,2,18)=dn6deta
         bmtrx(i,3,2,21)=dn7deta
         bmtrx(i,3,2,24)=dn8deta
c
         bmtrx(i,1,3,1) =dn1dzeta
         bmtrx(i,1,3,4) =dn2dzeta
         bmtrx(i,1,3,7) =dn3dzeta
         bmtrx(i,1,3,10)=dn4dzeta
         bmtrx(i,1,3,13)=dn5dzeta
         bmtrx(i,1,3,16)=dn6dzeta
         bmtrx(i,1,3,19)=dn7dzeta
         bmtrx(i,1,3,22)=dn8dzeta
c
         bmtrx(i,2,3,2) =dn1dzeta
         bmtrx(i,2,3,5) =dn2dzeta
         bmtrx(i,2,3,8) =dn3dzeta
         bmtrx(i,2,3,11)=dn4dzeta
         bmtrx(i,2,3,14)=dn5dzeta
         bmtrx(i,2,3,17)=dn6dzeta
         bmtrx(i,2,3,20)=dn7dzeta
         bmtrx(i,2,3,23)=dn8dzeta
c
         bmtrx(i,3,3,3) =dn1dzeta
         bmtrx(i,3,3,6) =dn2dzeta
         bmtrx(i,3,3,9) =dn3dzeta
         bmtrx(i,3,3,12)=dn4dzeta
         bmtrx(i,3,3,15)=dn5dzeta
         bmtrx(i,3,3,18)=dn6dzeta
         bmtrx(i,3,3,21)=dn7dzeta
         bmtrx(i,3,3,24)=dn8dzeta
c
      enddo
c     Jacobian wrt isoparametric coord:
c     g_ij = dx_i/dxi_j = dx_Ii*dN_I/dxi_j
      do i=lft,llt
c
         gmtrx(i,1,1)=x1(i)*dn1dxi+x2(i)*dn2dxi+
     1        x3(i)*dn3dxi+x4(i)*dn4dxi+
     2        x5(i)*dn5dxi+x6(i)*dn6dxi+
     3        x7(i)*dn7dxi+x8(i)*dn8dxi
         gmtrx(i,2,1)=y1(i)*dn1dxi+y2(i)*dn2dxi+
     1        y3(i)*dn3dxi+y4(i)*dn4dxi+
     2        y5(i)*dn5dxi+y6(i)*dn6dxi+
     3        y7(i)*dn7dxi+y8(i)*dn8dxi
         gmtrx(i,3,1)=z1(i)*dn1dxi+z2(i)*dn2dxi+
     1        z3(i)*dn3dxi+z4(i)*dn4dxi+
     2        z5(i)*dn5dxi+z6(i)*dn6dxi+
     3        z7(i)*dn7dxi+z8(i)*dn8dxi
         gmtrx(i,1,2)=x1(i)*dn1deta+x2(i)*dn2deta+
     1        x3(i)*dn3deta+x4(i)*dn4deta+
     2        x5(i)*dn5deta+x6(i)*dn6deta+
     3        x7(i)*dn7deta+x8(i)*dn8deta
         gmtrx(i,2,2)=y1(i)*dn1deta+y2(i)*dn2deta+
     1        y3(i)*dn3deta+y4(i)*dn4deta+
     2        y5(i)*dn5deta+y6(i)*dn6deta+
     3        y7(i)*dn7deta+y8(i)*dn8deta
         gmtrx(i,3,2)=z1(i)*dn1deta+z2(i)*dn2deta+
     1        z3(i)*dn3deta+z4(i)*dn4deta+
     2        z5(i)*dn5deta+z6(i)*dn6deta+
     3        z7(i)*dn7deta+z8(i)*dn8deta
         gmtrx(i,1,3)=x1(i)*dn1dzeta+x2(i)*dn2dzeta+
     1        x3(i)*dn3dzeta+x4(i)*dn4dzeta+
     2        x5(i)*dn5dzeta+x6(i)*dn6dzeta+
     3        x7(i)*dn7dzeta+x8(i)*dn8dzeta
         gmtrx(i,2,3)=y1(i)*dn1dzeta+y2(i)*dn2dzeta+
     1        y3(i)*dn3dzeta+y4(i)*dn4dzeta+
     2        y5(i)*dn5dzeta+y6(i)*dn6dzeta+
     3        y7(i)*dn7dzeta+y8(i)*dn8dzeta
         gmtrx(i,3,3)=z1(i)*dn1dzeta+z2(i)*dn2dzeta+
     1        z3(i)*dn3dzeta+z4(i)*dn4dzeta+
     2        z5(i)*dn5dzeta+z6(i)*dn6dzeta+
     3        z7(i)*dn7dzeta+z8(i)*dn8dzeta
c
      enddo
c
      do i=lft,llt
c
c        Determinant of Jacobian
         xjn=gmtrx(i,1,1)*(gmtrx(i,2,2)*gmtrx(i,3,3)-
     1        gmtrx(i,3,2)*gmtrx(i,2,3))+
     2        gmtrx(i,2,1)*(gmtrx(i,3,2)*gmtrx(i,1,3)-
     3        gmtrx(i,1,2)*gmtrx(i,3,3))+
     4        gmtrx(i,3,1)*(gmtrx(i,1,2)*gmtrx(i,2,3)-
     5        gmtrx(i,2,2)*gmtrx(i,1,3))
c
c        Inverse
         gjc=1./xjn
         g11i=gmtrx(i,2,2)*gmtrx(i,3,3)-gmtrx(i,2,3)*gmtrx(i,3,2)
         g12i=gmtrx(i,3,2)*gmtrx(i,1,3)-gmtrx(i,3,3)*gmtrx(i,1,2)
         g13i=gmtrx(i,1,2)*gmtrx(i,2,3)-gmtrx(i,1,3)*gmtrx(i,2,2)
         g21i=gmtrx(i,2,3)*gmtrx(i,3,1)-gmtrx(i,2,1)*gmtrx(i,3,3)
         g22i=gmtrx(i,3,3)*gmtrx(i,1,1)-gmtrx(i,3,1)*gmtrx(i,1,3)
         g23i=gmtrx(i,1,3)*gmtrx(i,2,1)-gmtrx(i,1,1)*gmtrx(i,2,3)
         g31i=gmtrx(i,2,1)*gmtrx(i,3,2)-gmtrx(i,2,2)*gmtrx(i,3,1)
         g32i=gmtrx(i,3,1)*gmtrx(i,1,2)-gmtrx(i,3,2)*gmtrx(i,1,1)
         g33i=gmtrx(i,1,1)*gmtrx(i,2,2)-gmtrx(i,1,2)*gmtrx(i,2,1)
         gitrx(i,1,1)=gjc*g11i
         gitrx(i,2,1)=gjc*g21i
         gitrx(i,3,1)=gjc*g31i
         gitrx(i,1,2)=gjc*g12i
         gitrx(i,2,2)=gjc*g22i
         gitrx(i,3,2)=gjc*g32i
         gitrx(i,1,3)=gjc*g13i
         gitrx(i,2,3)=gjc*g23i
         gitrx(i,3,3)=gjc*g33i
c
c        Scaled Jacobian: J_scaled = ( det(J(0))/det(J) )^(1/3) * J
c        This results in det(J_scaled) = det(J(0))
         factor(i)=(factor(i)/xjn)**(1./3.)
         gmtrx(i,1,1)=factor(i)*gmtrx(i,1,1)
         gmtrx(i,2,1)=factor(i)*gmtrx(i,2,1)
         gmtrx(i,3,1)=factor(i)*gmtrx(i,3,1)
         gmtrx(i,1,2)=factor(i)*gmtrx(i,1,2)
         gmtrx(i,2,2)=factor(i)*gmtrx(i,2,2)
         gmtrx(i,3,2)=factor(i)*gmtrx(i,3,2)
         gmtrx(i,1,3)=factor(i)*gmtrx(i,1,3)
         gmtrx(i,2,3)=factor(i)*gmtrx(i,2,3)
         gmtrx(i,3,3)=factor(i)*gmtrx(i,3,3)
c
      enddo
c
c     Summation of gradient displacement matrix wrt pysical coord at each node:
c     dvec_Il = 1/3*(B_ijIk(0)*(g_ij(0))^-1 - B_ijIk*(g_ij)^-1)
      do l=1,24
         do k=1,3
            do j=1,3
               do i=lft,llt
                  dvec(i,l)=dvec(i,l)-bmtrx(i,j,k,l)*gitrx(i,k,j)
               enddo
            enddo
         enddo
      enddo
      do j=1,24
         do i=lft,llt
            dvec(i,j)=dvec(i,j)/3.
         enddo
      enddo
c
c     Scaled B-matrix
      do l=1,24
         do k=1,3
            do j=1,3
               do i=lft,llt
                  bmtrx(i,j,k,l)=factor(i)*bmtrx(i,j,k,l)
               enddo
            enddo
         enddo
      enddo
c
c     B-bar matrix wrt isoparametric coord:
c     Bbar_ijIk = B_ijIk + (B_llIk(0)-B_llIk)*delta_ij/3
      do l=1,24
         do k=1,3
            do j=1,3
               do i=lft,llt
                  bmtrx(i,j,k,l)=bmtrx(i,j,k,l)+
     1                 dvec(i,l)*gmtrx(i,j,k)
               enddo
            enddo
         enddo
      enddo
c
      return
      end
      subroutine usld_b103(bmtrx,gmtrx,gjac,
     1 xi,eta,zeta,
     2 n1,n2,n3,n4,n5,n6,n7,n8,
     3 dn1dxi,dn2dxi,dn3dxi,dn4dxi,
     4 dn5dxi,dn6dxi,dn7dxi,dn8dxi,
     5 dn1deta,dn2deta,dn3deta,dn4deta,
     6 dn5deta,dn6deta,dn7deta,dn8deta,
     7 dn1dzeta,dn2dzeta,dn3dzeta,dn4dzeta,
     8 dn5dzeta,dn6dzeta,dn7dzeta,dn8dzeta,
     9 x1,x2,x3,x4,x5,x6,x7,x8,
     . y1,y2,y3,y4,y5,y6,y7,y8,
     . z1,z2,z3,z4,z5,z6,z7,z8,
     . xdof,
     . lft,llt)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     compute b and g matrix for user defined solid 103
c
      include 'nlqparm'
      dimension bmtrx(nlq,3,3,*),gmtrx(nlq,3,3),gjac(nlq)
      real n1,n2,n3,n4,n5,n6,n7,n8
      dimension x1(nlq),x2(nlq),x3(nlq),x4(nlq)
      dimension x5(nlq),x6(nlq),x7(nlq),x8(nlq)
      dimension y1(nlq),y2(nlq),y3(nlq),y4(nlq)
      dimension y5(nlq),y6(nlq),y7(nlq),y8(nlq)
      dimension z1(nlq),z2(nlq),z3(nlq),z4(nlq)
      dimension z5(nlq),z6(nlq),z7(nlq),z8(nlq)
      dimension xdof(nlq,8,*)
c
c     Variable description
c
c     outputs:
c
c     bmtrx = gradient-displacement matrix
c     gmtrx = jacobian matrix (ITAJ=0)
c     gjac  = jacobian determinant (ITAJ=1)
c
c     inputs:
c
c     xi,eta,zeta                     = parental coordinates
c     n1,n2,n3,n4,n5,n6,n7,n8         = nodal shape function values
c     dn1dxi,dn2dxi,dn3dxi,dn4dxi,
c     dn5dxi,dn6dxi,dn7dxi,dn8dxi     = nodal shape function derivatives
c                                       w.r.t. first parental coordinate
c     dn1deta,dn2deta,dn3deta,dn4deta,
c     dn5deta,dn6deta,dn7deta,dn8deta = nodal shape function derivatives
c                                       w.r.t. second parental coordinate
c     dn1dzeta,dn2dzeta,
c     dn3dzeta,dn4dzeta,
c     dn5dzeta,dn6dzeta,
c     dn7dzeta,dn8dzeta               = nodal shape function derivatives
c                                       w.r.t. third parental coordinate
c     x1,x2,x3,x4,x5,x6,x7,x8         = x-coordinates of nodes
c     y1,y2,y3,y4,y5,y6,y7,y8         = y-coordinates of nodes
c     z1,z2,z3,z4,z5,z6,z7,z8         = z-coordinates of nodes
c     xdof                            = values corresponding to
c                                       extra degrees of freedom (NXDOF.GT.0)
c
      return
      end
      subroutine usld_b104(bmtrx,gmtrx,gjac,
     1 xi,eta,zeta,
     2 n1,n2,n3,n4,n5,n6,n7,n8,
     3 dn1dxi,dn2dxi,dn3dxi,dn4dxi,
     4 dn5dxi,dn6dxi,dn7dxi,dn8dxi,
     5 dn1deta,dn2deta,dn3deta,dn4deta,
     6 dn5deta,dn6deta,dn7deta,dn8deta,
     7 dn1dzeta,dn2dzeta,dn3dzeta,dn4dzeta,
     8 dn5dzeta,dn6dzeta,dn7dzeta,dn8dzeta,
     9 x1,x2,x3,x4,x5,x6,x7,x8,
     . y1,y2,y3,y4,y5,y6,y7,y8,
     . z1,z2,z3,z4,z5,z6,z7,z8,
     . xdof,
     . lft,llt)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     compute b and g matrix for user defined solid 104
c
      include 'nlqparm'
      dimension bmtrx(nlq,3,3,*),gmtrx(nlq,3,3),gjac(nlq)
      real n1,n2,n3,n4,n5,n6,n7,n8
      dimension x1(nlq),x2(nlq),x3(nlq),x4(nlq)
      dimension x5(nlq),x6(nlq),x7(nlq),x8(nlq)
      dimension y1(nlq),y2(nlq),y3(nlq),y4(nlq)
      dimension y5(nlq),y6(nlq),y7(nlq),y8(nlq)
      dimension z1(nlq),z2(nlq),z3(nlq),z4(nlq)
      dimension z5(nlq),z6(nlq),z7(nlq),z8(nlq)
      dimension xdof(nlq,8,*)
c
c     Variable description
c
c     outputs:
c
c     bmtrx = gradient-displacement matrix
c     gmtrx = jacobian matrix (ITAJ=0)
c     gjac  = jacobian determinant (ITAJ=1)
c
c     inputs:
c
c     xi,eta,zeta                     = parental coordinates
c     n1,n2,n3,n4,n5,n6,n7,n8         = nodal shape function values
c     dn1dxi,dn2dxi,dn3dxi,dn4dxi,
c     dn5dxi,dn6dxi,dn7dxi,dn8dxi     = nodal shape function derivatives
c                                       w.r.t. first parental coordinate
c     dn1deta,dn2deta,dn3deta,dn4deta,
c     dn5deta,dn6deta,dn7deta,dn8deta = nodal shape function derivatives
c                                       w.r.t. second parental coordinate
c     dn1dzeta,dn2dzeta,
c     dn3dzeta,dn4dzeta,
c     dn5dzeta,dn6dzeta,
c     dn7dzeta,dn8dzeta               = nodal shape function derivatives
c                                       w.r.t. third parental coordinate
c     x1,x2,x3,x4,x5,x6,x7,x8         = x-coordinates of nodes
c     y1,y2,y3,y4,y5,y6,y7,y8         = y-coordinates of nodes
c     z1,z2,z3,z4,z5,z6,z7,z8         = z-coordinates of nodes
c     xdof                            = values corresponding to
c                                       extra degrees of freedom (NXDOF.GT.0)
c
      return
      end
      subroutine usld_b105(bmtrx,gmtrx,gjac,
     1 xi,eta,zeta,
     2 n1,n2,n3,n4,n5,n6,n7,n8,
     3 dn1dxi,dn2dxi,dn3dxi,dn4dxi,
     4 dn5dxi,dn6dxi,dn7dxi,dn8dxi,
     5 dn1deta,dn2deta,dn3deta,dn4deta,
     6 dn5deta,dn6deta,dn7deta,dn8deta,
     7 dn1dzeta,dn2dzeta,dn3dzeta,dn4dzeta,
     8 dn5dzeta,dn6dzeta,dn7dzeta,dn8dzeta,
     9 x1,x2,x3,x4,x5,x6,x7,x8,
     . y1,y2,y3,y4,y5,y6,y7,y8,
     . z1,z2,z3,z4,z5,z6,z7,z8,
     . xdof,
     . lft,llt)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     compute b and g matrix for user defined solid 105
c
      include 'nlqparm'
      dimension bmtrx(nlq,3,3,*),gmtrx(nlq,3,3),gjac(nlq)
      real n1,n2,n3,n4,n5,n6,n7,n8
      dimension x1(nlq),x2(nlq),x3(nlq),x4(nlq)
      dimension x5(nlq),x6(nlq),x7(nlq),x8(nlq)
      dimension y1(nlq),y2(nlq),y3(nlq),y4(nlq)
      dimension y5(nlq),y6(nlq),y7(nlq),y8(nlq)
      dimension z1(nlq),z2(nlq),z3(nlq),z4(nlq)
      dimension z5(nlq),z6(nlq),z7(nlq),z8(nlq)
      dimension xdof(nlq,8,*)
c
c     Variable description
c
c     outputs:
c
c     bmtrx = gradient-displacement matrix
c     gmtrx = jacobian matrix (ITAJ=0)
c     gjac  = jacobian determinant (ITAJ=1)
c
c     inputs:
c
c     xi,eta,zeta                     = parental coordinates
c     n1,n2,n3,n4,n5,n6,n7,n8         = nodal shape function values
c     dn1dxi,dn2dxi,dn3dxi,dn4dxi,
c     dn5dxi,dn6dxi,dn7dxi,dn8dxi     = nodal shape function derivatives
c                                       w.r.t. first parental coordinate
c     dn1deta,dn2deta,dn3deta,dn4deta,
c     dn5deta,dn6deta,dn7deta,dn8deta = nodal shape function derivatives
c                                       w.r.t. second parental coordinate
c     dn1dzeta,dn2dzeta,
c     dn3dzeta,dn4dzeta,
c     dn5dzeta,dn6dzeta,
c     dn7dzeta,dn8dzeta               = nodal shape function derivatives
c                                       w.r.t. third parental coordinate
c     x1,x2,x3,x4,x5,x6,x7,x8         = x-coordinates of nodes
c     y1,y2,y3,y4,y5,y6,y7,y8         = y-coordinates of nodes
c     z1,z2,z3,z4,z5,z6,z7,z8         = z-coordinates of nodes
c     xdof                            = values corresponding to
c                                       extra degrees of freedom (NXDOF.GT.0)
c
      return
      end
      subroutine usrsld_h(ietyp,cm,lmc,nhsv,nxdof,lft,llt,ihgf,dener)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      include 'nlqparm'
      include 'implicit1.inc'
      include 'nhisparm.inc'
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
# 4974 "dyn21usld.F" 2 
c
      common/aux10loc/
     1 px1(nlq),px2(nlq),px3(nlq),px4(nlq),
     & px5(nlq),px6(nlq),px7(nlq),px8(nlq),
     2 py1(nlq),py2(nlq),py3(nlq),py4(nlq),
     & py5(nlq),py6(nlq),py7(nlq),py8(nlq),
     3 pz1(nlq),pz2(nlq),pz3(nlq),pz4(nlq),
     & pz5(nlq),pz6(nlq),pz7(nlq),pz8(nlq),
     4 vx1(nlq),vx2(nlq),vx3(nlq),vx4(nlq),
     5 vx5(nlq),vx6(nlq),vx7(nlq),vx8(nlq),
     6 vy1(nlq),vy2(nlq),vy3(nlq),vy4(nlq),
     7 vy5(nlq),vy6(nlq),vy7(nlq),vy8(nlq),
     8 vz1(nlq),vz2(nlq),vz3(nlq),vz4(nlq),
     9 vz5(nlq),vz6(nlq),vz7(nlq),vz8(nlq)
      common/aux35loc/rhoa(nlq),cb(nlq),davg(nlq),p(nlq)
      common/subtssloc/dt1siz(nlq)
      common/aux8loc/
     & x1(nlq),x2(nlq),x3(nlq),x4(nlq),
     & x5(nlq),x6(nlq),x7(nlq),x8(nlq),
     & y1(nlq),y2(nlq),y3(nlq),y4(nlq),
     & y5(nlq),y6(nlq),y7(nlq),y8(nlq),
     & z1(nlq),z2(nlq),z3(nlq),z4(nlq),
     & z5(nlq),z6(nlq),z7(nlq),z8(nlq)
      common/bel7loc/ixsld(nlq,8,5),ixshl(nlq,4,5)
     .,bmtrx(nlq,3,3,8*(3+NXDOFUE)),
     . cmtrx(nlq,3,3,8*(3+NXDOFUE)),xdof(nlq,8,NXDOFUE),
     . dxdof(nlq,8,NXDOFUE),xhdof(nlq,8,NXDOFUE),
     . bvec(nlq,8*(3+NXDOFUE)),cvec(nlq,8*(3+NXDOFUE)),
     . frc(nlq,8*(3+NXDOFUE)),
     . stiff(nlq,64*(3+NXDOFUE)*(3+NXDOFUE)),
     . sigv(nlq),
     . gmtrx(nlq,3,3),hmtrx(nlq,3,3),cvltot(nlq),
     . xh1(nlq),xh2(nlq),xh3(nlq),xh4(nlq),
     . xh5(nlq),xh6(nlq),xh7(nlq),xh8(nlq),
     . yh1(nlq),yh2(nlq),yh3(nlq),yh4(nlq),
     . yh5(nlq),yh6(nlq),yh7(nlq),yh8(nlq),
     . zh1(nlq),zh2(nlq),zh3(nlq),zh4(nlq),
     . zh5(nlq),zh6(nlq),zh7(nlq),zh8(nlq),
     . hl11(nlq),hl12(nlq),hl13(nlq),hl21(nlq),hl22(nlq),
     . hl23(nlq),hl31(nlq),hl32(nlq),hl33(nlq),
     . xx1(nlq),xx2(nlq),xx3(nlq),xx4(nlq),
     . xx5(nlq),xx6(nlq),xx7(nlq),xx8(nlq),
     . yy1(nlq),yy2(nlq),yy3(nlq),yy4(nlq),
     . yy5(nlq),yy6(nlq),yy7(nlq),yy8(nlq),
     . zz1(nlq),zz2(nlq),zz3(nlq),zz4(nlq),
     . zz5(nlq),zz6(nlq),zz7(nlq),zz8(nlq),vlm(nlq)
      common/bel8loc/uehisv(nlq,2*(NHISVUE+45))
      common/bel8aloc/iuehup(nlq,2*(NHISVUE+45))
c
      dimension dener(*)
      dimension cm(lmc)
      dimension force(nlq,8*(3+NXDOFUE))
c
c$omp threadprivate (/aux35loc/)
c$omp threadprivate (/subtssloc/)
c$omp threadprivate (/aux10loc/)
c$omp threadprivate (/aux8loc/)
c$omp threadprivate (/bel8aloc/)
c$omp threadprivate (/bel8loc/)
c$omp threadprivate (/bel7loc/)
c$omp threadprivate (/bki04iloc/)
c$omp threadprivate (/bki03rloc/)
c$omp threadprivate (/bki03iloc/)
      ndtot=8*(3+nxdof)
      do j=1,ndtot
         do i=lft,llt
            force(i,j)=0.
            stiff(i,j)=0.
         enddo
      enddo
      ndtot2=ndtot*ndtot
      do j=ndtot+1,ndtot2
         do i=lft,llt
            stiff(i,j)=0.
         enddo
      enddo
c
      nadd1=0
      if (ihgf.eq.3) nadd1=21
c
      do i=lft,llt
         vx1(i)=vx1(i)*dt1siz(i)
         vy1(i)=vy1(i)*dt1siz(i)
         vz1(i)=vz1(i)*dt1siz(i)
         vx2(i)=vx2(i)*dt1siz(i)
         vy2(i)=vy2(i)*dt1siz(i)
         vz2(i)=vz2(i)*dt1siz(i)
         vx3(i)=vx3(i)*dt1siz(i)
         vy3(i)=vy3(i)*dt1siz(i)
         vz3(i)=vz3(i)*dt1siz(i)
         vx4(i)=vx4(i)*dt1siz(i)
         vy4(i)=vy4(i)*dt1siz(i)
         vz4(i)=vz4(i)*dt1siz(i)
         vx5(i)=vx5(i)*dt1siz(i)
         vy5(i)=vy5(i)*dt1siz(i)
         vz5(i)=vz5(i)*dt1siz(i)
         vx6(i)=vx6(i)*dt1siz(i)
         vy6(i)=vy6(i)*dt1siz(i)
         vz6(i)=vz6(i)*dt1siz(i)
         vx7(i)=vx7(i)*dt1siz(i)
         vy7(i)=vy7(i)*dt1siz(i)
         vz7(i)=vz7(i)*dt1siz(i)
         vx8(i)=vx8(i)*dt1siz(i)
         vy8(i)=vy8(i)*dt1siz(i)
         vz8(i)=vz8(i)*dt1siz(i)
      enddo
c
      if (nxdof.gt.0) then
         do k=1,8
            do j=1,nxdof
               do i=lft,llt
                  dxdof(i,k,j)=dxdof(i,k,j)*dt1siz(i)
               enddo
            enddo
         enddo
      endif
c
      if (ietyp.eq.101) then
         call usld_e101(force,stiff,ndtot,is17loc,
     .        x1,x2,x3,x4,x5,x6,x7,x8,
     .        y1,y2,y3,y4,y5,y6,y7,y8,
     .        z1,z2,z3,z4,z5,z6,z7,z8,
     .        xdof,
     .        vx1,vx2,vx3,vx4,vx5,vx6,vx7,vx8,
     .        vy1,vy2,vy3,vy4,vy5,vy6,vy7,vy8,
     .        vz1,vz2,vz3,vz4,vz5,vz6,vz7,vz8,
     .        dxdof,
     .        uehisv,iuehup,nhsv-nadd1,
     .        cm,lmc,
     .        uehisv(1,nhsv+1),lft,llt,dener)
      elseif (ietyp.eq.102) then
         call usld_e102(force,stiff,ndtot,is17loc,
     .        x1,x2,x3,x4,x5,x6,x7,x8,
     .        y1,y2,y3,y4,y5,y6,y7,y8,
     .        z1,z2,z3,z4,z5,z6,z7,z8,
     .        xdof,
     .        vx1,vx2,vx3,vx4,vx5,vx6,vx7,vx8,
     .        vy1,vy2,vy3,vy4,vy5,vy6,vy7,vy8,
     .        vz1,vz2,vz3,vz4,vz5,vz6,vz7,vz8,
     .        dxdof,
     .        uehisv,iuehup,nhsv-nadd1,
     .        cm,lmc,
     .        uehisv(1,nhsv+1),lft,llt,dener)
      elseif (ietyp.eq.103) then
         call usld_e103(force,stiff,ndtot,is17loc,
     .        x1,x2,x3,x4,x5,x6,x7,x8,
     .        y1,y2,y3,y4,y5,y6,y7,y8,
     .        z1,z2,z3,z4,z5,z6,z7,z8,
     .        xdof,
     .        vx1,vx2,vx3,vx4,vx5,vx6,vx7,vx8,
     .        vy1,vy2,vy3,vy4,vy5,vy6,vy7,vy8,
     .        vz1,vz2,vz3,vz4,vz5,vz6,vz7,vz8,
     .        dxdof,
     .        uehisv,iuehup,nhsv-nadd1,
     .        cm,lmc,
     .        uehisv(1,nhsv+1),lft,llt,dener)
      elseif (ietyp.eq.104) then
         call usld_e104(force,stiff,ndtot,is17loc,
     .        x1,x2,x3,x4,x5,x6,x7,x8,
     .        y1,y2,y3,y4,y5,y6,y7,y8,
     .        z1,z2,z3,z4,z5,z6,z7,z8,
     .        xdof,
     .        vx1,vx2,vx3,vx4,vx5,vx6,vx7,vx8,
     .        vy1,vy2,vy3,vy4,vy5,vy6,vy7,vy8,
     .        vz1,vz2,vz3,vz4,vz5,vz6,vz7,vz8,
     .        dxdof,
     .        uehisv,iuehup,nhsv-nadd1,
     .        cm,lmc,
     .        uehisv(1,nhsv+1),lft,llt,dener)
      elseif (ietyp.eq.105) then
         call usld_e105(force,stiff,ndtot,is17loc,
     .        x1,x2,x3,x4,x5,x6,x7,x8,
     .        y1,y2,y3,y4,y5,y6,y7,y8,
     .        z1,z2,z3,z4,z5,z6,z7,z8,
     .        xdof,
     .        vx1,vx2,vx3,vx4,vx5,vx6,vx7,vx8,
     .        vy1,vy2,vy3,vy4,vy5,vy6,vy7,vy8,
     .        vz1,vz2,vz3,vz4,vz5,vz6,vz7,vz8,
     .        dxdof,
     .        uehisv,iuehup,nhsv-nadd1,
     .        cm,lmc,
     .        uehisv(1,nhsv+1),lft,llt,dener)
      endif
c
      do j=1,ndtot
         do i=lft,llt
            frc(i,j)=frc(i,j)+force(i,j)
         enddo
      enddo
c
      if (is17loc.ne.0) then
        nsnd=0
        if (nxdof.gt.0) nsnd=(nxdof-1)/3+1
        do isnd=1,1+nsnd
          nsdf=3
          if (isnd.gt.1) then
            if (isnd.eq.1+nsnd) nsdf=nxdof-(nsnd-1)*3
          endif
          do irnd=1,8
            do isdf=1,nsdf
              m=24*(isnd-1)+3*(irnd-1)+isdf
              irow=m*(m-1)/2
              mm=(3+nxdof)*(irnd-1)+3*(isnd-1)+isdf
              do jsnd=1,1+nsnd
                msdf=3
                if (jsnd.gt.1) then
                  if (jsnd.eq.1+nsnd) msdf=nxdof-(nsnd-1)*3
                endif
                do jrnd=1,8
                  do 1 jsdf=1,msdf
                    n=24*(jsnd-1)+3*(jrnd-1)+jsdf
                    if (isolvr(77).ne.3.or.ihgf.ne.0) then
                    if (n.gt.m) goto 1
                    iske=irow+n
                    nn=(3+nxdof)*(jrnd-1)+3*(jsnd-1)+jsdf
                    do i=lft,llt
                      ske(i,iske)=ske(i,iske)+stiff(i,(mm-1)*ndtot+nn)
                    enddo
                    else
                    nn=(3+nxdof)*(jrnd-1)+3*(jsnd-1)+jsdf
                    do i=lft,llt
                      ske_unsym(i,n,m)=ske_unsym(i,n,m)+
     1                      stiff(i,(mm-1)*ndtot+nn)
                    enddo
                    endif
 1                continue
                enddo
              enddo
            enddo
          enddo
        enddo
      endif
c
      return
      end
      subroutine usld_e101(force,stiff,ndtot,istif,
     . x1,x2,x3,x4,x5,x6,x7,x8,
     . y1,y2,y3,y4,y5,y6,y7,y8,
     . z1,z2,z3,z4,z5,z6,z7,z8,
     . xdof,
     . dx1,dx2,dx3,dx4,dx5,dx6,dx7,dx8,
     . dy1,dy2,dy3,dy4,dy5,dy6,dy7,dy8,
     . dz1,dz2,dz3,dz4,dz5,dz6,dz7,dz8,
     . dxdof,
     . hsv,ihsv,nhsv,
     . cm,lmc,
     . cmtrx,lft,llt,dener)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     compute force (and stiffness) for user defined solid 101
c
      include 'nlqparm'
c     dimension force(nlq,ndtot),stiff(nlq,ndtot,ndtot)
      dimension force(nlq,*),stiff(nlq,ndtot,*)
      dimension x1(nlq),x2(nlq),x3(nlq),x4(nlq)
      dimension x5(nlq),x6(nlq),x7(nlq),x8(nlq)
      dimension y1(nlq),y2(nlq),y3(nlq),y4(nlq)
      dimension y5(nlq),y6(nlq),y7(nlq),y8(nlq)
      dimension z1(nlq),z2(nlq),z3(nlq),z4(nlq)
      dimension z5(nlq),z6(nlq),z7(nlq),z8(nlq)
      dimension xdof(nlq,8,*)
      dimension dx1(nlq),dx2(nlq),dx3(nlq),dx4(nlq)
      dimension dx5(nlq),dx6(nlq),dx7(nlq),dx8(nlq)
      dimension dy1(nlq),dy2(nlq),dy3(nlq),dy4(nlq)
      dimension dy5(nlq),dy6(nlq),dy7(nlq),dy8(nlq)
      dimension dz1(nlq),dz2(nlq),dz3(nlq),dz4(nlq)
      dimension dz5(nlq),dz6(nlq),dz7(nlq),dz8(nlq)
      dimension dxdof(nlq,8,*)
      dimension hsv(nlq,nhsv),ihsv(nlq,nhsv),cm(lmc)
      dimension cmtrx(nlq,21)
      dimension dener(nlq)
c
c     Variable description
c
c     outputs:
c
c     force                           = force
c     stiff                           = stiffness
c     hsv                             = history variables
c     ihsv                            = put to 1 to force history variable update regardless of convergence
c     dener                           = internal or hourglass energy, to be incremented
c
c     inputs:
c
c     istif                           = flag for setting up
c                                       stiffness matrix (0 or 1)
c
c     x1,x2,x3,x4,x5,x6,x7,x8         = x-coordinates of nodes
c     y1,y2,y3,y4,y5,y6,y7,y8         = y-coordinates of nodes
c     z1,z2,z3,z4,z5,z6,z7,z8         = z-coordinates of nodes
c     xdof                            = values corresponding to
c                                       extra degrees of freedom (NXDOF.GT.0)
c     dx1,dx2,dx3,dx4,dx5,dx6,dx7,dx8 = x-displacements of nodes
c     dy1,dy2,dy3,dy4,dy5,dy6,dy7,dy8 = y-displacements of nodes
c     dz1,dz2,dz3,dz4,dz5,dz6,dz7,dz8 = z-displacements of nodes
c     dxdof                           = displacements corresponding to
c                                       extra degrees of freedom (NXDOF.GT.0)
c     hsv                             = history variables
c     ihsv                            = 0 on input
c     cm                              = property parameters
c     cmtrx                           = resultant tangent modulus
c
c     Silly useless element implemented for the purpose of
c     checking the resultant user element interface
c
      dimension q(3)
      dimension x(8),y(8),z(8),dx(8),dy(8),dz(8)
      e=cm(1)
      do i=lft,llt
         x(1)=x1(i)
         x(2)=x2(i)
         x(3)=x3(i)
         x(4)=x4(i)
         x(5)=x5(i)
         x(6)=x6(i)
         x(7)=x7(i)
         x(8)=x8(i)
         y(1)=y1(i)
         y(2)=y2(i)
         y(3)=y3(i)
         y(4)=y4(i)
         y(5)=y5(i)
         y(6)=y6(i)
         y(7)=y7(i)
         y(8)=y8(i)
         z(1)=z1(i)
         z(2)=z2(i)
         z(3)=z3(i)
         z(4)=z4(i)
         z(5)=z5(i)
         z(6)=z6(i)
         z(7)=z7(i)
         z(8)=z8(i)
         dx(1)=dx1(i)
         dx(2)=dx2(i)
         dx(3)=dx3(i)
         dx(4)=dx4(i)
         dx(5)=dx5(i)
         dx(6)=dx6(i)
         dx(7)=dx7(i)
         dx(8)=dx8(i)
         dy(1)=dy1(i)
         dy(2)=dy2(i)
         dy(3)=dy3(i)
         dy(4)=dy4(i)
         dy(5)=dy5(i)
         dy(6)=dy6(i)
         dy(7)=dy7(i)
         dy(8)=dy8(i)
         dz(1)=dz1(i)
         dz(2)=dz2(i)
         dz(3)=dz3(i)
         dz(4)=dz4(i)
         dz(5)=dz5(i)
         dz(6)=dz6(i)
         dz(7)=dz7(i)
         dz(8)=dz8(i)
         do j=1,24
            force(i,j)=hsv(i,j)
         enddo
         do j=1,7
            do k=j+1,8
               eps=(dx(k)-dx(j))*(x(k)-x(j))+
     .              (dy(k)-dy(j))*(y(k)-y(j))+
     .              (dz(k)-dz(j))*(z(k)-z(j))
               enrm=sqrt((x(k)-x(j))**2+
     .              (y(k)-y(j))**2+
     .              (z(k)-z(j))**2)
               eeps=e*eps/enrm**2
               q(1)=(x(k)-x(j))/enrm
               q(2)=(y(k)-y(j))/enrm
               q(3)=(z(k)-z(j))/enrm
               force(i,(k-1)*3+1)=force(i,(k-1)*3+1)+eeps*q(1)
               force(i,(k-1)*3+2)=force(i,(k-1)*3+2)+eeps*q(2)
               force(i,(k-1)*3+3)=force(i,(k-1)*3+3)+eeps*q(3)
               force(i,(j-1)*3+1)=force(i,(j-1)*3+1)-eeps*q(1)
               force(i,(j-1)*3+2)=force(i,(j-1)*3+2)-eeps*q(2)
               force(i,(j-1)*3+3)=force(i,(j-1)*3+3)-eeps*q(3)
               if (istif.eq.1) then
                  do kk=1,3
                     do jj=1,3
                        stiff(i,(k-1)*3+kk,(j-1)*3+jj)=
     .                       stiff(i,(k-1)*3+kk,(j-1)*3+jj)-
     .                       e*q(kk)*q(jj)/enrm
                        stiff(i,(j-1)*3+kk,(k-1)*3+jj)=
     .                       stiff(i,(j-1)*3+kk,(k-1)*3+jj)-
     .                       e*q(kk)*q(jj)/enrm
                        stiff(i,(k-1)*3+kk,(k-1)*3+jj)=
     .                       stiff(i,(k-1)*3+kk,(k-1)*3+jj)+
     .                       e*q(kk)*q(jj)/enrm
                        stiff(i,(j-1)*3+kk,(j-1)*3+jj)=
     .                       stiff(i,(j-1)*3+kk,(j-1)*3+jj)+
     .                       e*q(kk)*q(jj)/enrm
                     enddo
                  enddo
               endif
            enddo
         enddo
         do j=1,24
            hsv(i,j)=force(i,j)
         enddo
c
      enddo
      return
      end
      subroutine usld_e102(force,stiff,ndtot,istif,
     . x1,x2,x3,x4,x5,x6,x7,x8,
     . y1,y2,y3,y4,y5,y6,y7,y8,
     . z1,z2,z3,z4,z5,z6,z7,z8,
     . xdof,
     . dx1,dx2,dx3,dx4,dx5,dx6,dx7,dx8,
     . dy1,dy2,dy3,dy4,dy5,dy6,dy7,dy8,
     . dz1,dz2,dz3,dz4,dz5,dz6,dz7,dz8,
     . dxdof,
     . hsv,ihsv,nhsv,
     . cm,lmc,
     . cmtrx,lft,llt,dener)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     compute force (and stiffness) for user defined solid 102
c
      include 'nlqparm'
      dimension force(nlq,ndtot),stiff(nlq,ndtot,ndtot)
      dimension x1(nlq),x2(nlq),x3(nlq),x4(nlq)
      dimension x5(nlq),x6(nlq),x7(nlq),x8(nlq)
      dimension y1(nlq),y2(nlq),y3(nlq),y4(nlq)
      dimension y5(nlq),y6(nlq),y7(nlq),y8(nlq)
      dimension z1(nlq),z2(nlq),z3(nlq),z4(nlq)
      dimension z5(nlq),z6(nlq),z7(nlq),z8(nlq)
      dimension xdof(nlq,8,*)
      dimension dx1(nlq),dx2(nlq),dx3(nlq),dx4(nlq)
      dimension dx5(nlq),dx6(nlq),dx7(nlq),dx8(nlq)
      dimension dy1(nlq),dy2(nlq),dy3(nlq),dy4(nlq)
      dimension dy5(nlq),dy6(nlq),dy7(nlq),dy8(nlq)
      dimension dz1(nlq),dz2(nlq),dz3(nlq),dz4(nlq)
      dimension dz5(nlq),dz6(nlq),dz7(nlq),dz8(nlq)
      dimension dxdof(nlq,8,*)
      dimension hsv(nlq,nhsv),ihsv(nlq,nhsv),cm(lmc)
      dimension cmtrx(nlq,21)
      dimension dener(nlq)
c
c     Variable description
c
c     outputs:
c
c     force                           = force
c     stiff                           = stiffness
c     hsv                             = history variables
c     ihsv                            = put to 1 to force history variable update regardless of convergence
c     dener                           = internal or hourglass energy, to be incremented
c
c     inputs:
c
c     istif                           = flag for setting up
c                                       stiffness matrix (0 or 1)
c
c     x1,x2,x3,x4,x5,x6,x7,x8         = x-coordinates of nodes
c     y1,y2,y3,y4,y5,y6,y7,y8         = y-coordinates of nodes
c     z1,z2,z3,z4,z5,z6,z7,z8         = z-coordinates of nodes
c     xdof                            = values corresponding to
c                                       extra degrees of freedom (NXDOF.GT.0)
c     dx1,dx2,dx3,dx4,dx5,dx6,dx7,dx8 = x-displacements of nodes
c     dy1,dy2,dy3,dy4,dy5,dy6,dy7,dy8 = y-displacements of nodes
c     dz1,dz2,dz3,dz4,dz5,dz6,dz7,dz8 = z-displacements of nodes
c     dxdof                           = displacements corresponding to
c                                       extra degrees of freedom (NXDOF.GT.0)
c     hsv                             = history variables
c     ihsv                            = 0 on input
c     cm                              = property parameters
c     cmtrx                           = resultant tangent modulus
c
c     Default solid element 102, replace this call with own code
c
      call usld_e102_d(force,stiff,ndtot,istif,
     . x1,x2,x3,x4,x5,x6,x7,x8,
     . y1,y2,y3,y4,y5,y6,y7,y8,
     . z1,z2,z3,z4,z5,z6,z7,z8,
     . xdof,
     . dx1,dx2,dx3,dx4,dx5,dx6,dx7,dx8,
     . dy1,dy2,dy3,dy4,dy5,dy6,dy7,dy8,
     . dz1,dz2,dz3,dz4,dz5,dz6,dz7,dz8,
     . dxdof,
     . hsv,ihsv,nhsv,
     . cm,lmc,
     . cmtrx,lft,llt,dener)
c
      return
      end
      subroutine usld_e103(force,stiff,ndtot,istif,
     . x1,x2,x3,x4,x5,x6,x7,x8,
     . y1,y2,y3,y4,y5,y6,y7,y8,
     . z1,z2,z3,z4,z5,z6,z7,z8,
     . xdof,
     . dx1,dx2,dx3,dx4,dx5,dx6,dx7,dx8,
     . dy1,dy2,dy3,dy4,dy5,dy6,dy7,dy8,
     . dz1,dz2,dz3,dz4,dz5,dz6,dz7,dz8,
     . dxdof,
     . hsv,ihsv,nhsv,
     . cm,lmc,
     . cmtrx,lft,llt,dener)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     compute force (and stiffness) for user defined solid 103
c
      include 'nlqparm'
      dimension force(nlq,ndtot),stiff(nlq,ndtot,ndtot)
      dimension x1(nlq),x2(nlq),x3(nlq),x4(nlq)
      dimension x5(nlq),x6(nlq),x7(nlq),x8(nlq)
      dimension y1(nlq),y2(nlq),y3(nlq),y4(nlq)
      dimension y5(nlq),y6(nlq),y7(nlq),y8(nlq)
      dimension z1(nlq),z2(nlq),z3(nlq),z4(nlq)
      dimension z5(nlq),z6(nlq),z7(nlq),z8(nlq)
      dimension xdof(nlq,8,*)
      dimension dx1(nlq),dx2(nlq),dx3(nlq),dx4(nlq)
      dimension dx5(nlq),dx6(nlq),dx7(nlq),dx8(nlq)
      dimension dy1(nlq),dy2(nlq),dy3(nlq),dy4(nlq)
      dimension dy5(nlq),dy6(nlq),dy7(nlq),dy8(nlq)
      dimension dz1(nlq),dz2(nlq),dz3(nlq),dz4(nlq)
      dimension dz5(nlq),dz6(nlq),dz7(nlq),dz8(nlq)
      dimension dxdof(nlq,8,*)
      dimension hsv(nlq,nhsv),ihsv(nlq,nhsv),cm(lmc)
      dimension cmtrx(nlq,21)
      dimension dener(nlq)
c
c     Variable description
c
c     outputs:
c
c     force                           = force
c     stiff                           = stiffness
c     hsv                             = history variables
c     ihsv                            = put to 1 to force history variable update regardless of convergence
c     dener                           = internal or hourglass energy, to be incremented
c
c     inputs:
c
c     istif                           = flag for setting up
c                                       stiffness matrix (0 or 1)
c
c     x1,x2,x3,x4,x5,x6,x7,x8         = x-coordinates of nodes
c     y1,y2,y3,y4,y5,y6,y7,y8         = y-coordinates of nodes
c     z1,z2,z3,z4,z5,z6,z7,z8         = z-coordinates of nodes
c     xdof                            = values corresponding to
c                                       extra degrees of freedom (NXDOF.GT.0)
c     dx1,dx2,dx3,dx4,dx5,dx6,dx7,dx8 = x-displacements of nodes
c     dy1,dy2,dy3,dy4,dy5,dy6,dy7,dy8 = y-displacements of nodes
c     dz1,dz2,dz3,dz4,dz5,dz6,dz7,dz8 = z-displacements of nodes
c     dxdof                           = displacements corresponding to
c                                       extra degrees of freedom (NXDOF.GT.0)
c     hsv                             = history variables
c     ihsv                            = 0 on input
c     cm                              = property parameters
c     cmtrx                           = resultant tangent modulus
c

c     Test routine for *USER_NONLOCAL_SEARCH - replace with your own routine
      call usld_e103test(force,x1,x2,x3,x4,x5,x6,x7,x8,y1,y2,y3,y4,y5,y6
     $     ,y7,y8,z1,z2,z3,z4,z5,z6,z7,z8,hsv,ihsv,nhsv,lft,llt)

      return
      end
      subroutine usld_e103test(force,x1,x2,x3,x4,x5,x6,x7,x8,y1,y2,y3,y4
     $     ,y5,y6,y7,y8,z1,z2,z3,z4,z5,z6,z7,z8,hsv,ihsv,nhsv,lft,llt)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     compute force (and stiffness) for user defined solid 103
c
      include 'nlqparm'
      include 'bk06.inc'
      dimension force(nlq,*)
      dimension x1(nlq),x2(nlq),x3(nlq),x4(nlq)
      dimension x5(nlq),x6(nlq),x7(nlq),x8(nlq)
      dimension y1(nlq),y2(nlq),y3(nlq),y4(nlq)
      dimension y5(nlq),y6(nlq),y7(nlq),y8(nlq)
      dimension z1(nlq),z2(nlq),z3(nlq),z4(nlq)
      dimension z5(nlq),z6(nlq),z7(nlq),z8(nlq)
      dimension hsv(nlq,nhsv),ihsv(nlq,nhsv)
      dimension x(8),y(8),z(8)

c     Test routine for *USER_NONLOCAL_SEARCH - returns distances to
c     origin in HSV

      do i=lft,llt
            
         if (ncycle.eq.0) then
            x(1) = x1(i)
            x(2) = x2(i)
            x(3) = x3(i)
            x(4) = x4(i)
            x(5) = x5(i)
            x(6) = x6(i)
            x(7) = x7(i)
            x(8) = x8(i)
            y(1) = y1(i)
            y(2) = y2(i)
            y(3) = y3(i)
            y(4) = y4(i)
            y(5) = y5(i)
            y(6) = y6(i)
            y(7) = y7(i)
            y(8) = y8(i)
            z(1) = z1(i)
            z(2) = z2(i)
            z(3) = z3(i)
            z(4) = z4(i)
            z(5) = z5(i)
            z(6) = z6(i)
            z(7) = z7(i)
            z(8) = z8(i)            
c           Midpoint x-distance
            hsv(i,1) = sum(x)/8.
c           Midpoint y-distance
            hsv(i,2) = sum(y)/8.
c           Midpoint z-distance
            hsv(i,3) = sum(z)/8.
         endif
         
      enddo

      return
      end
      subroutine usld_e104(force,stiff,ndtot,istif,
     . x1,x2,x3,x4,x5,x6,x7,x8,
     . y1,y2,y3,y4,y5,y6,y7,y8,
     . z1,z2,z3,z4,z5,z6,z7,z8,
     . xdof,
     . dx1,dx2,dx3,dx4,dx5,dx6,dx7,dx8,
     . dy1,dy2,dy3,dy4,dy5,dy6,dy7,dy8,
     . dz1,dz2,dz3,dz4,dz5,dz6,dz7,dz8,
     . dxdof,
     . hsv,ihsv,nhsv,
     . cm,lmc,
     . cmtrx,lft,llt,dener)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     compute force (and stiffness) for user defined solid 104
c
      include 'nlqparm'
      dimension force(nlq,ndtot),stiff(nlq,ndtot,ndtot)
      dimension x1(nlq),x2(nlq),x3(nlq),x4(nlq)
      dimension x5(nlq),x6(nlq),x7(nlq),x8(nlq)
      dimension y1(nlq),y2(nlq),y3(nlq),y4(nlq)
      dimension y5(nlq),y6(nlq),y7(nlq),y8(nlq)
      dimension z1(nlq),z2(nlq),z3(nlq),z4(nlq)
      dimension z5(nlq),z6(nlq),z7(nlq),z8(nlq)
      dimension xdof(nlq,8,*)
      dimension dx1(nlq),dx2(nlq),dx3(nlq),dx4(nlq)
      dimension dx5(nlq),dx6(nlq),dx7(nlq),dx8(nlq)
      dimension dy1(nlq),dy2(nlq),dy3(nlq),dy4(nlq)
      dimension dy5(nlq),dy6(nlq),dy7(nlq),dy8(nlq)
      dimension dz1(nlq),dz2(nlq),dz3(nlq),dz4(nlq)
      dimension dz5(nlq),dz6(nlq),dz7(nlq),dz8(nlq)
      dimension dxdof(nlq,8,*)
      dimension hsv(nlq,nhsv),ihsv(nlq,nhsv),cm(lmc)
      dimension cmtrx(nlq,21)
      dimension dener(nlq)
c
c     Variable description
c
c     outputs:
c
c     force                           = force
c     stiff                           = stiffness
c     hsv                             = history variables
c     ihsv                            = put to 1 to force history variable update regardless of convergence
c     dener                           = internal or hourglass energy, to be incremented
c
c     inputs:
c
c     istif                           = flag for setting up
c                                       stiffness matrix (0 or 1)
c
c     x1,x2,x3,x4,x5,x6,x7,x8         = x-coordinates of nodes
c     y1,y2,y3,y4,y5,y6,y7,y8         = y-coordinates of nodes
c     z1,z2,z3,z4,z5,z6,z7,z8         = z-coordinates of nodes
c     xdof                            = values corresponding to
c                                       extra degrees of freedom (NXDOF.GT.0)
c     dx1,dx2,dx3,dx4,dx5,dx6,dx7,dx8 = x-displacements of nodes
c     dy1,dy2,dy3,dy4,dy5,dy6,dy7,dy8 = y-displacements of nodes
c     dz1,dz2,dz3,dz4,dz5,dz6,dz7,dz8 = z-displacements of nodes
c     dxdof                           = displacements corresponding to
c                                       extra degrees of freedom (NXDOF.GT.0)
c     hsv                             = history variables
c     ihsv                            = 0 on input
c     cm                              = property parameters
c     cmtrx                           = resultant tangent modulus
c
      dimension xcur(11,8),xref(11,8)
      nxdof=3
      do i=lft,llt
        xcur(1,1)=x1(i)
        xcur(1,2)=x2(i)
        xcur(1,3)=x3(i)
        xcur(1,4)=x4(i)
        xcur(1,5)=x5(i)
        xcur(1,6)=x6(i)
        xcur(1,7)=x7(i)
        xcur(1,8)=x8(i)
        xcur(2,1)=y1(i)
        xcur(2,2)=y2(i)
        xcur(2,3)=y3(i)
        xcur(2,4)=y4(i)
        xcur(2,5)=y5(i)
        xcur(2,6)=y6(i)
        xcur(2,7)=y7(i)
        xcur(2,8)=y8(i)
        xcur(3,1)=z1(i)
        xcur(3,2)=z2(i)
        xcur(3,3)=z3(i)
        xcur(3,4)=z4(i)
        xcur(3,5)=z5(i)
        xcur(3,6)=z6(i)
        xcur(3,7)=z7(i)
        xcur(3,8)=z8(i)
        do j=1,nxdof
          do k=1,8
            xcur(3+j,k)=xdof(i,k,j)
          enddo
        enddo
        if (hsv(i,1).ne.1.) then
          hsv(i,1)=1.
          ijk=1
          do j=1,8
            do k=1,3+nxdof
              ijk=ijk+1
              hsv(i,ijk)=xcur(k,j)
            enddo
          enddo
        endif
        ijk=1
        do j=1,8
          do k=1,3+nxdof
            ijk=ijk+1
            xref(k,j)=hsv(i,ijk)
          enddo
        enddo
        do j=1,ndtot
          force(i,j)=0.
          do k=1,ndtot
            jk=iabs(j-k)
            stiff(i,j,k)=.5**jk
            if (jk.ne.0) stiff(i,j,k)=-stiff(i,j,k)*.5
            knod=(k-1)/(3+nxdof)+1
            kdof=k-(knod-1)*(3+nxdof)
            force(i,j)=force(i,j)+stiff(i,j,k)*
     1           (xcur(kdof,knod)-xref(kdof,knod))
          enddo
        enddo
      enddo
c
      return
      end
      subroutine usld_e105(force,stiff,ndtot,istif,
     . x1,x2,x3,x4,x5,x6,x7,x8,
     . y1,y2,y3,y4,y5,y6,y7,y8,
     . z1,z2,z3,z4,z5,z6,z7,z8,
     . xdof,
     . dx1,dx2,dx3,dx4,dx5,dx6,dx7,dx8,
     . dy1,dy2,dy3,dy4,dy5,dy6,dy7,dy8,
     . dz1,dz2,dz3,dz4,dz5,dz6,dz7,dz8,
     . dxdof,
     . hsv,ihsv,nhsv,
     . cm,lmc,
     . cmtrx,lft,llt,dener)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     compute force (and stiffness) for user defined solid 105
c
      include 'nlqparm'
      dimension force(nlq,ndtot),stiff(nlq,ndtot,ndtot)
      dimension x1(nlq),x2(nlq),x3(nlq),x4(nlq)
      dimension x5(nlq),x6(nlq),x7(nlq),x8(nlq)
      dimension y1(nlq),y2(nlq),y3(nlq),y4(nlq)
      dimension y5(nlq),y6(nlq),y7(nlq),y8(nlq)
      dimension z1(nlq),z2(nlq),z3(nlq),z4(nlq)
      dimension z5(nlq),z6(nlq),z7(nlq),z8(nlq)
      dimension xdof(nlq,8,*)
      dimension dx1(nlq),dx2(nlq),dx3(nlq),dx4(nlq)
      dimension dx5(nlq),dx6(nlq),dx7(nlq),dx8(nlq)
      dimension dy1(nlq),dy2(nlq),dy3(nlq),dy4(nlq)
      dimension dy5(nlq),dy6(nlq),dy7(nlq),dy8(nlq)
      dimension dz1(nlq),dz2(nlq),dz3(nlq),dz4(nlq)
      dimension dz5(nlq),dz6(nlq),dz7(nlq),dz8(nlq)
      dimension dxdof(nlq,8,*)
      dimension hsv(nlq,nhsv),ihsv(nlq,nhsv),cm(lmc)
      dimension cmtrx(nlq,21)
      dimension dener(nlq)
c
c     Variable description
c
c     outputs:
c
c     force                           = force
c     stiff                           = stiffness
c     hsv                             = history variables
c     ihsv                            = put to 1 to force history variable update regardless of convergence
c     dener                           = internal or hourglass energy, to be incremented
c
c     inputs:
c
c     istif                           = flag for setting up
c                                       stiffness matrix (0 or 1)
c
c     x1,x2,x3,x4,x5,x6,x7,x8         = x-coordinates of nodes
c     y1,y2,y3,y4,y5,y6,y7,y8         = y-coordinates of nodes
c     z1,z2,z3,z4,z5,z6,z7,z8         = z-coordinates of nodes
c     xdof                            = values corresponding to
c                                       extra degrees of freedom (NXDOF.GT.0)
c     dx1,dx2,dx3,dx4,dx5,dx6,dx7,dx8 = x-displacements of nodes
c     dy1,dy2,dy3,dy4,dy5,dy6,dy7,dy8 = y-displacements of nodes
c     dz1,dz2,dz3,dz4,dz5,dz6,dz7,dz8 = z-displacements of nodes
c     dxdof                           = displacements corresponding to
c                                       extra degrees of freedom (NXDOF.GT.0)
c     hsv                             = history variables
c     ihsv                            = 0 on input
c     cm                              = property parameters
c     cmtrx                           = resultant tangent modulus
c
      return
      end
      subroutine usldmass(iop,w,nxdof,x,rho,cm,lmc)
# 5831

      if (iop.eq.101) then
        call usld_m101(w,nxdof,x,rho,cm,lmc)
      elseif (iop.eq.102) then
        call usld_m102(w,nxdof,x,rho,cm,lmc)
      elseif (iop.eq.103) then
        call usld_m103(w,nxdof,x,rho,cm,lmc)
      elseif (iop.eq.104) then
        call usld_m104(w,nxdof,x,rho,cm,lmc)
      elseif (iop.eq.105) then
        call usld_m105(w,nxdof,x,rho,cm,lmc)
      endif
      return
      end
      subroutine usld_m101(w,nxdof,x,rho,cm,lmc)
c
c     Compute mass for extra dofs for user solid 101
c
      dimension w(nxdof,8),x(3,8),cm(lmc)
c
c     Variable description
c
c     outputs:
c
c     w(nxdof,8)           = mass vector for extra dofs, first index
c                            corresponds to dof and second to local node
c                            of element
c
c     inputs:
c
c     nxdof                = number of extra dofs for this element
c     x(3,8)               = nodal coordinates for element, first index
c                            corresponds to dof and second to local node
c                            of element
c     rho                  = density of material for this element
c     cm(lmc)              = property parameter array
c     lmc                  = length of cm
c
      return
      end
c
      subroutine usld_m102(w,nxdof,x,rho,cm,lmc)
c
c     Compute mass for extra dofs for user solid 102
c
      dimension w(nxdof,8),x(3,8),cm(lmc)
c
c     Variable description
c
c     outputs:
c
c     w(nxdof,8)           = mass vector for extra dofs, first index
c                            corresponds to dof and second to local node
c                            of element
c
c     inputs:
c
c     nxdof                = number of extra dofs for this element
c     x(3,8)               = nodal coordinates for element, first index
c                            corresponds to dof and second to local node
c                            of element
c     rho                  = density of material for this element
c     cm(lmc)              = property parameter array
c     lmc                  = length of cm
c
      return
      end
c
      subroutine usld_m103(w,nxdof,x,rho,cm,lmc)
c
c     Compute mass for extra dofs for user solid 103
c
      dimension w(nxdof,8),x(3,8),cm(lmc)
c
c     Variable description
c
c     outputs:
c
c     w(nxdof,8)           = mass vector for extra dofs, first index
c                            corresponds to dof and second to local node
c                            of element
c
c     inputs:
c
c     nxdof                = number of extra dofs for this element
c     x(3,8)               = nodal coordinates for element, first index
c                            corresponds to dof and second to local node
c                            of element
c     rho                  = density of material for this element
c     cm(lmc)              = property parameter array
c     lmc                  = length of cm
c
      return
      end
c
      subroutine usld_m104(w,nxdof,x,rho,cm,lmc)
c
c     Compute mass for extra dofs for user solid 104
c
      dimension w(nxdof,8),x(3,8),cm(lmc)
c
c     Variable description
c
c     outputs:
c
c     w(nxdof,8)           = mass vector for extra dofs, first index
c                            corresponds to dof and second to local node
c                            of element
c
c     inputs:
c
c     nxdof                = number of extra dofs for this element
c     x(3,8)               = nodal coordinates for element, first index
c                            corresponds to dof and second to local node
c                            of element
c     rho                  = density of material for this element
c     cm(lmc)              = property parameter array
c     lmc                  = length of cm
c
      do i=1,8
        do j=1,nxdof
          w(j,i)=100.
        enddo
      enddo
c
      return
      end
c
      subroutine usld_m105(w,nxdof,x,rho,cm,lmc)
c
c     Compute mass for extra dofs for user solid 105
c
      dimension w(nxdof,8),x(3,8),cm(lmc)
c
c     Variable description
c
c     outputs:
c
c     w(nxdof,8)           = mass vector for extra dofs, first index
c                            corresponds to dof and second to local node
c                            of element
c
c     inputs:
c
c     nxdof                = number of extra dofs for this element
c     x(3,8)               = nodal coordinates for element, first index
c                            corresponds to dof and second to local node
c                            of element
c     rho                  = density of material for this element
c     cm(lmc)              = property parameter array
c     lmc                  = length of cm
c
      return
      end
