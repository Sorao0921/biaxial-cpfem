# 1 "dyn21umat.F"
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





# 2 "dyn21umat.F" 2 
# 1 ".\define2.inc" 1 



# 3 "dyn21umat.F" 2 

ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c
c User Material Model:
c
c usrmat: Main Driver calls
c   call urmathn : pack/unpack data for elements: solid/thick shell/sph/ ...
c   call urmats  : pack/unpack data for elements: shell/shl2d/IGAshell
c   call urmatb  : pack/unpack data for element: hbeam
c   call urmatd  : pack/unpack data for element: dbeam
c   call urmatt  : pack/unpack data for element: tbeam
c
c   The actual material models are implemented in
c   dyn21umats.F   : the serial version of the user material models
c                    umat41,umat42, ..., umat50
c   dyn21umatv.F   : the vectorized version of the user material models
c                    umat41v,umat42v, ..., umat50v
c
c dyn21utan.F : Tangent Stiffness
c   subroutine urtanb is the main driver for Beam elements
c   subroutine urtans is the main driver for Shell elements
c   subroutine urtanh is the main driver for Solid element
c
c dyn21ueos.F : User EOS
c   subroutine ueoslib is the main driver
c
c dyn21umatc.F : User Cohesive Models
c   subroutine umatc is the main driver
c
c dyn21tumat.F : User Thermal Material Models
c   subroutine thusrmat is the main driver
c
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
      subroutine usrmat (lft,llt,cm,bqs,capa,eltype,mt,ipt,
     . npc,plc,crv,nnpcrv,rcoor,scoor,tcoor,nnm1,nip,ipt_thk)
# 41

      use userinterface
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      include 'nlqparm'
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
# 53 "dyn21umat.F" 2 
# 1 ".\bk08.inc" 1 
      integer n4f,n4g,n4h,n7a,nusir,                                    
     & mpusr,mpubr,n4i,n4j,n4k,n4l,n4m,n4n
      common/bk08/n4f,n4g,n4h,n7a,nusir,                                
     & mpusr,mpubr,n4i,n4j,n4k,n4l,n4m,n4n
# 54 "dyn21umat.F" 2 
      include 'memaia.inc'
      include 'umatss.inc'
      include 'sph.inc'
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
# 58 "dyn21umat.F" 2 
      common/bk00/numnp,numpc,numlp,neq,ndof,nlcur,numcl,numvc,
     1 ndtpts,nelmd,nmmat,numelh,numelb,numels,numelt,numdp,
     2 grvity,idirgv,nodspc,nspcor,numelh10,numels8,numelsx,numnpin,
     3 numelhx,nmuxct
      common/bk01/itherm,itemp,ntmp0,ntmp1,itempan,itempdr,itmpe(44)
      dimension cm(*),bqs(*),crv(lq1,2,*),npc(*),plc(*)
      integer nnpcrv(*)
      character*(*) eltype
      integer, pointer,contiguous :: dm_nshbwp(:), dm_nbmbwp(:)
      integer, pointer,contiguous :: dm_nhxbwp(:), dm_ntsbwp(:)
      integer, pointer,contiguous :: nodsph(:),dm_iqtype(:),dm_ncsave(:)
      real, pointer,contiguous :: dm_eosp(:)
c
# 79

      call getintegerptr('dm_nhxbwp',dm_nhxbwp)
      call getintegerptr('dm_nshbwp',dm_nshbwp)
      call getintegerptr('dm_nbmbwp',dm_nbmbwp)
      call getintegerptr('dm_ntsbwp',dm_ntsbwp)
      call getintegerptr('nodsph',nodsph)
      call getintegerptr('dm_iqtype',dm_iqtype)
      call getintegerptr('dm_ncsave',dm_ncsave)
      call getrealptr('dm_eosp',dm_eosp)
c
      if (eltype.eq.'solid'.or.eltype.eq.'shl_t'.or.
     1     eltype.eq.'sld2d'.or.eltype.eq.'tshel'.or.
     2     eltype.eq.'sldax'.or.eltype.eq.'IGAsolid'.or.
     3     eltype.eq.'sldco') then
        call urmathn (lft,llt,cm,bqs,mt,crv,nnpcrv,npc,plc,nnm1,
     1   rcoor,scoor,tcoor,dm_iqtype(1+3*nmmat),nip,ipt,eltype,
     2   dm_nhxbwp,dm_nshbwp,dm_ntsbwp,dm_ncsave)
      elseif (eltype.eq.'sph  ') then
        call urmathn (lft,llt,cm,bqs,mt,crv,nnpcrv,npc,plc,nnm1,
     1   rcoor,scoor,tcoor,dm_iqtype(1+3*nmmat),nip,ipt,eltype,
     2   nodsph,dm_nshbwp,dm_ntsbwp,dm_ncsave)
      elseif (eltype.eq.'shell'.or.eltype.eq.'shl2d'.or.
     1        eltype.eq.'IGAshell') then
        call urmats (lft,llt,cm,capa,mt,crv,nnpcrv,
     .   ipt,rcoor,scoor,tcoor,
     1   nnm1,dm_iqtype(1+3*nmmat),nip,ipt_thk,npc,plc,eltype,
     2   dm_nshbwp,dm_ncsave)
      elseif (eltype.eq.'hbeam') then
        call urmatb (lft,llt,cm,capa,mt,crv,nnpcrv,
     .   nnm1,dm_iqtype(1+3*nmmat),
     1   npc,plc,eltype,dm_nbmbwp,dm_ncsave)
      elseif (eltype.eq.'dbeam') then
        call urmatd (lft,llt,cm,bqs,mt,crv,nnpcrv,nnm1,
     1   dm_iqtype(1+3*nmmat),
     1   npc,plc,eltype,dm_nbmbwp,dm_ncsave)
      elseif (eltype.eq.'tbeam') then
        call urmatt (lft,llt,cm,bqs,mt,crv,nnpcrv,nnm1,
     1   dm_iqtype(1+3*nmmat),
     1   npc,plc,eltype,dm_nbmbwp,dm_ncsave)
      endif
c
      return
      end
      subroutine urmats(lft,llt,cm,capa,mt,crv,nnpcrv,
     . ipt,rcoor,scoor,tcoor,
     . nnm1,nconstp,nip,ipt_thk,npc,plc,eltype,nshbwp,ncsave)
      use userinterface
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
      include 'bk06.inc'
# 1 ".\bk19.inc" 1 
      integer nconst(2000),lenma,ncneos(50),mtecom(2000),     
     & nhgshl(30)
      common/bk19/nconst,lenma,ncneos,mtecom,nhgshl
# 138 "dyn21umat.F" 2 
      include 'iounits.inc'
      include 'memaia.inc'
      include 'umatss.inc'
      include 'shlioc.inc'
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
# 143 "dyn21umat.F" 2 
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
# 144 "dyn21umat.F" 2 
# 1 ".\bk13.inc" 1 
      integer lc0,lc1h,lc1b,lc1t,lc2,lc3,lc4,lc5,lc6,lc6e,lc6f,lc9,     
     & lc10,lc11,lc12,lc13,lc14,lc15,lc16,lc17,lc18,lb0,lb1,lb2,        
     & lc7a,lc7b,lc7c,lc7d,lc7e,lc7f,lc7g,lc7h,lc7i,lc7j,lc7k,lc7l,     
     & lc7t,lc7x,lc6g,lc6h
      common/bk13/lc0,lc1h,lc1b,lc1t,lc2,lc3,lc4,lc5,lc6,lc6e,lc6f,lc9, 
     & lc10,lc11,lc12,lc13,lc14,lc15,lc16,lc17,lc18,lb0,lb1,lb2,        
     & lc7a,lc7b,lc7c,lc7d,lc7e,lc7f,lc7g,lc7h,lc7i,lc7j,lc7k,lc7l,     
     & lc7t,lc7x,lc6g,lc6h
# 145 "dyn21umat.F" 2 
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

# 146 "dyn21umat.F" 2 
# 1 ".\xfem.inc" 1 
c     Include file for fracture analysis with xfem
c     ictrxfem     0 not an xfem analysis
c                  2 2d/shell only
c                  3 3d only
c                  5 shell and 3d
      integer        ictrxfem,ictrxfem2,iformxfem,icohesive,ixfemgotip,
     &               ixfemerosion,ixfeminit,ixfemrepl,ndimxfem,
     &               ixfempropcr,ixfemcrklen,ixfemdam,ixfemjction
      common/xfemctr/ictrxfem,ictrxfem2,iformxfem,icohesive,ixfemgotip,
     &               ixfemerosion,ixfeminit,ixfemrepl,ndimxfem,
     &               ixfempropcr,ixfemcrklen,ixfemdam,ixfemjction
c
      integer       ixfemmass,ixfemndfc,ixfemsmorder,iformjump,icontip
      common/xfemfm/ixfemmass,ixfemndfc,ixfemsmorder,iformjump,icontip
c
c     cohesive material constants
c     a(ndtype)    mctype(*)
c     a(ndcohm)    cmcoh(48,*)
c     nmtcox       number of internal variables in each xfem
c     nmtcoh       number of internal variables in each cohesive zone
      integer       ndtype,ndcohm,nmtcox,nmtcoh
      common/cohmat/ndtype,ndcohm,nmtcox,nmtcoh
c
c     element status
c     xf_inxfems   inxfems(*) local (xfem parts) eid to global eid
c     xf_ixfems    ixfems(*) for 2d/shell elements
c     xf_isbfem    isbfem(*) =1 boundary elements
c     xf_ckopen    ckopen(35,*) crack opening angle, location & nodal forces
c     xf_neighbors neighbors(4,*) direct front neighboring elements of xfem eid
c     xf_numbors   numbors(4,*) number of corner neighboring elements of xfem eid
c     xf_neighbor2 neighbor2(6,4,*) corner neighboring elements of xfem eid
c     xf_nbjction  nbjction(2,4,*) front neighbors from junction part
c     xf_numjction numjction(4,*) number of corner neighbors from junction
c     xf_nb2jction nb2jction(6,4,*) corner neighbors from junction part
c     xf_thicks    original shell thickness
c     xf_ifails    number of times fem fails but cannot become xfem
c     xf_rfails    ratio of failure value to smoothed value
      integer*8 xf_ixfems,xf_isbfem,xf_ckopen,xf_neighbors,xf_inxfems,
     &       xf_thicks,xf_ifails,xf_rfails,xf_numbors,xf_neighbor2,
     &       xf_nbjction,xf_numjction,xf_nb2jction
      common/xfemsts/xf_ixfems,xf_isbfem,xf_ckopen,xf_neighbors,
     &               xf_inxfems,xf_thicks,xf_ifails,xf_rfails,
     &               xf_numbors,xf_neighbor2,
     &               xf_nbjction,xf_numjction,xf_nb2jction
c
c     xfem part info
c     ngxfem       number of xfem groups (including triangle group for base 16)
c     npxfem       number of xfem parts
c     ntxfem       number of elements in xfem parts
c     xf_nelgxfem       group of eid
c     xf_mxexfem        mxe of the group
c     xf_mxpxfem        mxe of the part
c     xf_itegxfem       starting xfem eid of each group
c     xf_nbpart         number of xfem parts connected to current part
c     xf_nbparts        part ids (among npxfem) of the neighboring xfem parts
c     xf_props          xfem part related data
      integer        ngxfem,ntxfem,npxfem
      integer*8 xf_nelgxfem,xf_mxexfem,xf_mxpxfem,xf_itegxfem,
     &       xf_nbpart,xf_nbparts,xf_props
      common/xfeminfo/ngxfem,ntxfem,npxfem
      common/xfemprts/xf_nelgxfem,xf_mxexfem,xf_mxpxfem,xf_itegxfem,
     &                xf_nbpart,xf_nbparts,xf_props
c
c     non-local strain
c     xf_xeps(2*ntxfem) non-local strain:local strain
c     xf_nipxfem        nip for strain regularization
c     xf_nelxfem        eid in xfem parts for strain reg.
c     xf_dcjp           support
c     xf_xyzc           coordinates of element centers
c     xf_ntipfem        if tip front element, pointed to xytipfem
c     xf_xytipfem       local tip coordinate to reg. strain
c     xf_nipavg         nip for strain center
c     xf_nelavg         eid in xfem parts for strain center
      integer*8 xf_xeps,xf_nipxfem,xf_nelxfem,xf_dcjp,
     &       xf_xyzc,xf_ntipfem,xf_xytipfem,xf_nipavg,xf_nelavg
      common/xfemsmth/xf_xeps,xf_nipxfem,xf_nelxfem,xf_dcjp,
     &                xf_xyzc,xf_ntipfem,xf_xytipfem,xf_nipavg,xf_nelavg
      integer MXFEMIP
c     parameter (MXFEMIP=3500)
      parameter (MXFEMIP=1200)
c
c     crack description
c     ncracks      number of cracks
c     mcracks      allocated number of cracks
c     nxfems       number of xfem elements
c     mxfems       allocated number of xfem elements
c     npnods       number of phantom nodes
c     mpnods       allocated number of phantom nodes
c     nxact        number of active xfems
c     nactcks      number of active cracks (after merging)
      integer      ncracks,nxfems,npnods,mcracks,mxfems,mpnods,
     &             nxact,nprexfem,iphstat,nactcks
      real         crklength
      common/cracks/ncracks,nxfems,npnods,mcracks,mxfems,mpnods,
     &              nxact,nprexfem,iphstat,nactcks,crklength
c     ck_nxfems    number of xfems for each crack
c     ck_pairs     element pairs (orig & phantom) for cracks
c     ck_x         crack position in reference coordinates
c     ck_nside     element edges cut by crack
c     ck_ixesta    crack start element (xfem id)
c     ck_ixeend    crack end element (xfem id)
c     ck_cracks    crack id for active cracks
      integer*8 ck_nxfems,ck_pairs,ck_x,ck_ixesta,ck_ixeend,ck_cracks,
     &       ck_nside
      common/ckindex/ck_nxfems,ck_pairs,ck_x,ck_ixesta,ck_ixeend,
     &               ck_cracks,ck_nside
c
c     xfem database
c     xf_phnods    phantom nodes ids
c     xf_m         phantom node mass
c     xf_mr        phantom node mass (rotation)
c     xf_x         phantom node position
c     xf_disp      phantom node displacements
c     xf_v         phantom node velocities
c     xf_a         phantom node acceleration/rhs
c     xf_nbc       boundary conditions on phantom nodes
c     xf_nphsta    phamtom node status
c     xf_npcxfm    nodal constraint at crack tip
c     xf_cpcxfm    nodal constraint parameter at crack tip
c     xf_mast      added mass for phantom node
c     xf_masr      added mass for phantom node (rotation)
c     xf_dt        time step for xfem
      integer*8 xf_phnods,xf_m,xf_x,xf_disp,xf_v,xf_a,xf_nbc,xf_mr
      integer*8 xf_nphsta,xf_npcxfm,xf_cpcxfm,xf_mast,xf_masr,xf_dt
      common/xfnods/xf_phnods,xf_m,xf_x,xf_disp,xf_v,xf_a,xf_nbc,xf_mr,
     &  xf_nphsta,xf_npcxfm,xf_cpcxfm,xf_mast,xf_masr,xf_dt
c     xf_phelms    phantom element connectivity
c     xf_auxvec    memory for internal variables in phantom elements
c     xf_lavn      start location for internal variables in ph-elements
c     xf_auxcoh    memory for internal variables in cohesive interface
c     xf_lavcoh    start location for int. variables in cohesive zone
c     xf_aratio    area ratios of the two sub-region to whole element
c     xf_ipxfem    number of integration points for xfem (subdomain)
c     xf_ndxfem    nodal numbers in subdomains
      integer*8 xf_phelms,xf_auxvec,xf_lavn,xf_auxcoh,xf_lavcoh,
     &       xf_aratio,xf_ipxfem,xf_ndxfem
      common/xfelms/xf_phelms,xf_auxvec,xf_lavn,xf_auxcoh,xf_lavcoh,
     &              xf_aratio,xf_ipxfem,xf_ndxfem
c
      integer        ntncog,ncoir
      common/coeleir/ntncog,ncoir(20)
      integer nxfemco,nxfem2
      common/xfemtype2/nxfemco,nxfem2(20)
# 165

# 147 "dyn21umat.F" 2 
# 1 ".\implicit1.inc" 1 
!   ... implicit common ...
!
      character*80    sc_filename, moddyn_filename, modal_op2_filename, 
     &                rv_filename
      character*10    sc_mass, sc_damp, sc_stiff, sc_inert
      common/bki01ch/ sc_filename, sc_mass, sc_damp, sc_stiff, sc_inert,
     &                moddyn_filename(2), modal_op2_filename,           
     &                rv_filename
!
      integer imauto,iteopt,lauto,mthsol,ilimit,maxref,icnvrg,          
     & igdiv,nwebuf,neql,neqt,imterm,imphas,nbfgs,                      
     & numupd,istif,itrlas,imerr,imdof,neqtgl,ilsmtd,lsdir,ptr_aspc_h,  
     & impcntctl,ipmaxx,igpx,itermp,itermp1,h_lp,h_rd,ptr_rf_data_h,    
     & moddyn_flag, moddyn_mdrange, moddyn_mdlen, moddyn_mdfreq,        
     & moddyn_mdfrqlen, moddyn_aux,                                     
     & mf2_ptrnum_f95, mf2_ptrsym_f95, h_rsvc, im_numnp, mpp_im_numnp,  
     & h_frf
      common/bki01i/imauto,iteopt,lauto,mthsol,ilimit,maxref,icnvrg,    
     & igdiv,nwebuf,neql,neqt,imterm,imphas,nbfgs,                      
     & numupd,istif,itrlas,imerr,imdof,neqtgl,ilsmtd,lsdir,ptr_aspc_h,  
     & impcntctl,ipmaxx,igpx,itermp,itermp1,h_lp,h_rd,ptr_rf_data_h,    
     & moddyn_flag, moddyn_mdrange, moddyn_mdlen, moddyn_mdfreq,        
     & moddyn_mdfrqlen, moddyn_aux(13),                                 
     & mf2_ptrnum_f95, mf2_ptrsym_f95, h_rsvc, im_numnp, mpp_im_numnp,  
     & h_frf
!
      real dtimp,dtimp0,timeim,dtmnim,dtmxim,cvtl,ectl,rctl,            
     & tolls,dnorm2,dtprnt,dtplot,dtiter,dtrefm,ppmax,pmaxr,errord,umax,
     & sumx,xrte,moddyn_valdmp,moddyn_output_time,ctmxs,htmxs,xkei,     
     & tollls,pretim
      common/bki01r/dtimp,dtimp0,timeim,dtmnim,dtmxim,cvtl,ectl,rctl,   
     & tolls,dnorm2,dtprnt(2),dtplot(2),dtiter(2),dtrefm(2),            
     & ppmax,pmaxr,errord,umax,sumx,xrte,moddyn_valdmp,                 
     & moddyn_output_time(2),ctmxs(8),htmxs(8),xkei(-2:2),tollls,pretim
!
      real ascntl,r78tags
      common/bki02r/ascntl(200),r78tags(20)
!
      logical lsensw,jlsmtd
      common/bki01l/lsensw(20),jlsmtd
!
      integer imip,isolvr,icwrb,elem_tbl,i78tags,moddyn_fast,numsmv
      common/bki02i/imip(300),isolvr(500),icwrb(50),elem_tbl(4,65),     
     & i78tags(20),moddyn_fast,numsmv
# 148 "dyn21umat.F" 2 
# 1 ".\usermat_vendor.inc" 1 
c
      integer user_iform
      character*10 vendor
      common /usermat_vendor/ user_iform,vendor
# 149 "dyn21umat.F" 2 
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
      common/bk00/numnp,numpc,numlp,neq,ndof,nlcur,numcl,numvc,
     1 ndtpts,nelmd,nmmat,numelh,numelb,numels,numelt,numdp,
     2 grvity,idirgv,nodspc,nspcor,numelh10,numels8,numelsx,numnpin,
     3 numelhx,nmuxct,ndscmxh,ndscmxs,numnurb2d,nvcbox,lscmh,numnurb3d
      common/bk36loc/index
      common/bux13loc/eps(6),sig(6),hsv(NHISVAR),temps(nlq)
# 1 ".\failcmloc.inc" 1 
c     include this file when failur IS used in element/material routines,
c     or in other words when a loop is multi threaded
      integer ifail
      logical failur,failgl,failst
      common/failcm/failst,failgl
      common/failcmloc/ifail(nlq),failur
# 185 "dyn21umat.F" 2 
      common/failuloc/sieu(nlq),fail(nlq),ifaili(nlq),nfipts(nlq),
     . msgfail(nlq),def_ele_eros(nlq)
      common/frozloc/yhat(nlq,3,4),qloc(nlq,3,3),qmat(nlq,3,3)
      common/hourgloc/ym(nlq),gm(nlq),ifsv(nlq)
      common/shloptloc/ibelyt
c
      common/bk01/itherm,itemp,ntmp0,ntmp1,itempan,itempdr,itmpe(14),
     . itempe(10),nthxp,ithxp(19)
      common/bk26/begtim,nintcy
      common/bk28/summss,xke,xpe,tt,xte0,erodeke,erodeie,selie,selke,
     . erodehg,eintcnt,engjnt
      common/numcpu/ncpu,ncpua,ncpub,lenvec(9)
      integer istrn,istupd_flag,ibelyts,miter,ipstpd,intsts,nodsts,
     & intstn,
     1 nodstn,jstrn,nddet,nsout01,nsout02,nsout03,nsout04,
     2 nsout05,nsout06
      real wrpang
      common/shlopt/istrn,istupd_flag,ibelytt,miter,wrpang,
     1 ipstpd,intsts,nodsts,intstn,nodstn,jstrn,nddet,nsout01,
     2 nsout02,nsout03,nsout04,nsout05,nsout06,mporlk,lporlk,
     3 istrn_t,istrn_p
      common/sidesloc/sidmn(nlq)
      common/soundloc/ss(nlq),sndsp(nlq),diagm(nlq),sarea(nlq),
     . dxl(nlq)
      common/subtssloc/dt1siz(nlq)
      common/thropt/itopaz(101)
c
      dimension cm(*),crv(lq1,2,*),nconstp(*),npc(*),plc(*)
      integer nnpcrv(*)
c     dimension eps(6),sig(6),hsv(NHISVAR),temps(nlq)
      dimension qmats(3,3)
      character*(*)eltype
      dimension nshbwp(*)
      dimension thhsv(nlq,100),thhsvi(100)
      dimension elsizv(nlq)
      logical failel,failels(nlq),reject
      logical xfempart
      integer lqfinv8,lqfmiv8
      integer idelev(nlq),idele
      integer*8 ptr_usrcf
      real*8, pointer,contiguous :: dm_x(:),dm_rots(:)
      real, pointer,contiguous :: dm_s_fibl(:),dm_s_uhat(:),dm_s_uthk(:)
      dimension ncsave(*)
c
c     data temps/nlq*0.0/
c
c$omp threadprivate (/failcmloc/)
c$omp threadprivate (/subtssloc/)
c$omp threadprivate (/soundloc/)
c$omp threadprivate (/sidesloc/)
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
c$omp threadprivate (/usermat_vendor/)
      call getreal8ptr('dm_x',dm_x)
      call getreal8ptr('dm_rots',dm_rots)
      call getrealptr('dm_s_fibl',dm_s_fibl)
      call getrealptr('dm_s_uhat',dm_s_uhat)
      call getrealptr('dm_s_uthk',dm_s_uthk)
c
c     processing elements
c
      mx=48*(mxt(lft)-1)
c     xfem start 20170303
      if (mt.eq.282.or.mt.eq.283) then
      ym(lft)=cm(mx+1)
      pr     =cm(mx+2)
      bk     =ym(lft)/(1.0-2.0*pr)/3.0
      gm(lft)=ym(lft)/(1.0+pr)/2.0
      else
c     xfem end
      gm(lft)=cm(mx+abs(ishrmp(mt)))
      bk=cm(mx+ibulkp(mt))
      pr=(3.*bk-2.*gm(lft))/(2.*(3.*bk+gm(lft)))
      ym(lft)=2.*(1.+pr)*gm(lft)
      endif
      ss(lft)=ym(lft)/(1.-pr*pr)
c
c     xfem start
      xfempart=.false.
      if (ictrxfem.ne.0) then
        do igxfem=1,ngxfem
          mxe=i_mem(xf_mxexfem+igxfem-1)
          if (mxe.gt.nmmat) mxe=mxe-nmmat
          if (mxe.eq.mxt(lft)) then
            xfempart=.true.
            goto 54
          endif
        enddo
  54    continue
      endif
c     xfem end
c
c     Determining number of requested history variables
c
      no_hsvs=ncsave(mxt(lft))
c
      if (ioshl(881).ne.0) then
c contact forces are store under r_mem(3,numnp)
        ptr_usrcf = memh_ptr(ioshl(881))
      endif
c
c     initializing indeces
c
      if(ivumat(mt).ne.0) then
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
        ind_vumat=ind_last+1
        ind_last=ind_vumat+9+6-1
c        ind_last=ind_last+1
      else
        if (iorien(mt).ne.0) then
          if (ihyper(mt).ne.0) then
            ind_defgrad=1+no_hsvs
            ind_ortho=ind_defgrad+9
            if (iabs(ihyper(mt)).eq.3) then
               ind_thick=ind_ortho
               ind_ortho=ind_ortho+4
            endif
            if (iabs(ihyper(mt)).eq.4) ind_ortho=ind_ortho+18
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
            if (iabs(ihyper(mt)).eq.3) then
               ind_thick=ind_last+1
               ind_last=ind_last+4
            endif
            if (iabs(ihyper(mt)).eq.4) ind_last=ind_last+18
          else
            ind_last=no_hsvs
          endif
          if (ifipts(mt).lt.0) then
            ind_fipts=ind_last+1
            ind_last=ind_last+1
          endif
        endif
      endif
c
      if (ind_last.gt.NHISVAR) then
c       write(iotty,900) lqfmiv8(mxt(lft))
c       write(iohsp,900) lqfmiv8(mxt(lft))
c       write(iomsg,900) lqfmiv8(mxt(lft))
c       call adios(2)
        ierdat(1)=lqfmiv8(mxt(lft))
        call lsmsg(3,MSG_SOL+1148,ioall,ierdat,rerdat,cerdat,0)
      endif
c$$$     if (tt.eq.0.0.and.nintcy.eq.0) then
c$$$c
c$$$c      move transformation matrix in history variables array
c$$$c
c$$$       if (iorien(mt).ne.0) then
c$$$         do i=lft,llt
c$$$           hsvs(i,ind_q2)=hsvs(i,2)
c$$$           hsvs(i,ind_q1)=hsvs(i,1)
c$$$         enddo
c$$$         if (no_hsvs.gt.0) then
c$$$           do j=1,no_hsvs
c$$$             do i=lft,llt
c$$$               hsvs(i,j)=0.0
c$$$             enddo
c$$$           enddo
c$$$         endif
c$$$       endif
c$$$     endif
c
      if (ipt.eq.1.and.ifipts(mt).ne.0) then
        do i=lft,llt
          nfipts(i)=0
        enddo
      endif
c
      num_nods=4
      if (ibelyt.eq.0) then
        num_nods=8
        do 10 i=lft,llt
        sign0(i)=sign3(i)+ym(lft)*d3(i)
        sign3(i)=sign0(i)
 10     continue
      endif
c
c     transform stresses and strains to material system
c
      if (iorien(mt).ne.0.and.(ihyper(mt).ge.0.or.ihyper(mt).eq.-2))
     $     then
c     if (iorien(mt).ne.0.and.ihyper(mt).ge.0) then
        do 20 i=lft,llt
        stg5(i)=sig5(i)
        stg6(i)=sig6(i)
        if (ncycle.le.1) then
          rr = 1./sqrt(hsvs(i,ind_q1)**2+hsvs(i,ind_q2)**2)
          hsvs(i,ind_q1)=hsvs(i,ind_q1)*rr
          hsvs(i,ind_q2)=hsvs(i,ind_q2)*rr
        end if
        a11(i) =hsvs(i,ind_q1)*sig1(i)-hsvs(i,ind_q2)*sig4(i)
        a12(i) =hsvs(i,ind_q2)*sig1(i)+hsvs(i,ind_q1)*sig4(i)
        a21(i) =hsvs(i,ind_q1)*sig4(i)-hsvs(i,ind_q2)*sig2(i)
        a22(i) =hsvs(i,ind_q2)*sig4(i)+hsvs(i,ind_q1)*sig2(i)
        sig1(i)=hsvs(i,ind_q1)*a11(i)-hsvs(i,ind_q2)*a21(i)
        sig2(i)=hsvs(i,ind_q2)*a12(i)+hsvs(i,ind_q1)*a22(i)
        sig4(i)=hsvs(i,ind_q1)*a12(i)-hsvs(i,ind_q2)*a22(i)
        sig5(i)=hsvs(i,ind_q2)*stg6(i)+hsvs(i,ind_q1)*stg5(i)
        sig6(i)=hsvs(i,ind_q1)*stg6(i)-hsvs(i,ind_q2)*stg5(i)
 20     continue
c
        do 30 i=lft,llt
        d4(i)  =.5*e4(i)
        a11(i) =hsvs(i,ind_q1)*e1(i)-hsvs(i,ind_q2)*d4(i)
        a12(i) =hsvs(i,ind_q2)*e1(i)+hsvs(i,ind_q1)*d4(i)
        a21(i) =hsvs(i,ind_q1)*d4(i)-hsvs(i,ind_q2)*e2(i)
        a22(i) =hsvs(i,ind_q2)*d4(i)+hsvs(i,ind_q1)*e2(i)
        d1(i)  =hsvs(i,ind_q1)*a11(i)-hsvs(i,ind_q2)*a21(i)
        d2(i)  =hsvs(i,ind_q2)*a12(i)+hsvs(i,ind_q1)*a22(i)
        d4(i)  =2.*(hsvs(i,ind_q1)*a12(i)-hsvs(i,ind_q2)*a22(i))
        d5(i)  =hsvs(i,ind_q2)*e6(i)+hsvs(i,ind_q1)*e5(i)
        d6(i)  =hsvs(i,ind_q1)*e6(i)-hsvs(i,ind_q2)*e5(i)
 30     continue
c
c     element local strains
c
      else
        do i=lft,llt
          d1(i)  =e1(i)
          d2(i)  =e2(i)
          d4(i)  =e4(i)
          d5(i)  =e5(i)
          d6(i)  =e6(i)
        enddo
      endif
c
c     storage of deformation gradient
c
      if (ivumat(mt).ne.0) then
        ifo11=ind_vumat
        ifo21=ind_vumat+1
        ifo31=ind_vumat+2
        ifo12=ind_vumat+3
        ifo22=ind_vumat+4
        ifo32=ind_vumat+5
        ifo13=ind_vumat+6
        ifo23=ind_vumat+7
        ifo33=ind_vumat+8
      endif
      if (ihyper(mt).ne.0) then
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
c       deformation gradient in element system at time = 0
c
        if (tt.eq.begtim.and.nintcy.eq.0) then
          do i=lft,llt
            hsvs(i,if11)=1.0
            hsvs(i,if21)=0.0
            hsvs(i,if31)=0.0
            hsvs(i,if12)=0.0
            hsvs(i,if22)=1.0
            hsvs(i,if32)=0.0
            hsvs(i,if13)=0.0
            hsvs(i,if23)=0.0
            hsvs(i,if33)=1.0
          enddo
          if (ivumat(mt).ne.0) then
            do i=lft,llt
              hsvs(i,ifo11)=1.0
              hsvs(i,ifo21)=0.0
              hsvs(i,ifo31)=0.0
              hsvs(i,ifo12)=0.0
              hsvs(i,ifo22)=1.0
              hsvs(i,ifo32)=0.0
              hsvs(i,ifo13)=0.0
              hsvs(i,ifo23)=0.0
              hsvs(i,ifo33)=1.0
            enddo
          endif
        endif
c
c       store deformation gradient in element system
c
        if (iorien(mt).eq.0) then
          do i=lft,llt
            dfg11(i)=hsvs(i,if11)
            dfg21(i)=hsvs(i,if21)
            dfg31(i)=hsvs(i,if31)
            dfg12(i)=hsvs(i,if12)
            dfg22(i)=hsvs(i,if22)
            dfg32(i)=hsvs(i,if32)
            dfg13(i)=hsvs(i,if13)
            dfg23(i)=hsvs(i,if23)
            dfg33(i)=hsvs(i,if33)
           enddo
        endif
      endif
c
      if (iorien(mt).ne.0) then
c
c       store deformation gradient in material system
c       as F_bar=Q^T*F
c
      if (ihyper(mt).gt.0) then
c        if (ihyper(mt).eq.1) then
          do i=lft,llt
            dfg11(i)=hsvs(i,ind_q1)*hsvs(i,if11)-
     1               hsvs(i,ind_q2)*hsvs(i,if21)
            dfg21(i)=hsvs(i,ind_q2)*hsvs(i,if11)+
     1               hsvs(i,ind_q1)*hsvs(i,if21)
            dfg31(i)=hsvs(i,if31)
            dfg12(i)=hsvs(i,ind_q1)*hsvs(i,if12)-
     1               hsvs(i,ind_q2)*hsvs(i,if22)
            dfg22(i)=hsvs(i,ind_q2)*hsvs(i,if12)+
     1               hsvs(i,ind_q1)*hsvs(i,if22)
            dfg32(i)=hsvs(i,if32)
            dfg13(i)=hsvs(i,ind_q1)*hsvs(i,if13)-
     1               hsvs(i,ind_q2)*hsvs(i,if23)
            dfg23(i)=hsvs(i,ind_q2)*hsvs(i,if13)+
     1               hsvs(i,ind_q1)*hsvs(i,if23)
            dfg33(i)=hsvs(i,if33)
c
            hsvs(i,if11)=dfg11(i)
            hsvs(i,if21)=dfg21(i)
            hsvs(i,if12)=dfg12(i)
            hsvs(i,if22)=dfg22(i)
            hsvs(i,if13)=dfg13(i)
            hsvs(i,if23)=dfg23(i)
          enddo
c
c       store deformation gradient in material system
c       as F_bar=Q^T*F*Q
c
        else if (ihyper(mt).eq.-2) then
          do i=lft,llt
            dfg11(i)=hsvs(i,ind_q1)*hsvs(i,if11)-
     1               hsvs(i,ind_q2)*hsvs(i,if21)
            dfg21(i)=hsvs(i,ind_q2)*hsvs(i,if11)+
     1               hsvs(i,ind_q1)*hsvs(i,if21)
            dfg31(i)=hsvs(i,if31)
            dfg12(i)=hsvs(i,ind_q1)*hsvs(i,if12)-
     1               hsvs(i,ind_q2)*hsvs(i,if22)
            dfg22(i)=hsvs(i,ind_q2)*hsvs(i,if12)+
     1               hsvs(i,ind_q1)*hsvs(i,if22)
            dfg32(i)=hsvs(i,if32)
            dfg13(i)=hsvs(i,ind_q1)*hsvs(i,if13)-
     1               hsvs(i,ind_q2)*hsvs(i,if23)
            dfg23(i)=hsvs(i,ind_q2)*hsvs(i,if13)+
     1               hsvs(i,ind_q1)*hsvs(i,if23)
            dfg33(i)=hsvs(i,if33)
c
            hsvs(i,if11)=dfg11(i)*hsvs(i,ind_q1)-dfg12(i)*hsvs(i,ind_q2)
            hsvs(i,if12)=dfg11(i)*hsvs(i,ind_q2)+dfg12(i)*hsvs(i,ind_q1)
            hsvs(i,if13)=dfg13(i)
            hsvs(i,if21)=dfg21(i)*hsvs(i,ind_q1)-dfg22(i)*hsvs(i,ind_q2)
            hsvs(i,if22)=dfg21(i)*hsvs(i,ind_q2)+dfg22(i)*hsvs(i,ind_q1)
            hsvs(i,if23)=dfg23(i)
            hsvs(i,if31)=dfg31(i)*hsvs(i,ind_q1)-dfg32(i)*hsvs(i,ind_q2)
            hsvs(i,if32)=dfg31(i)*hsvs(i,ind_q2)+dfg32(i)*hsvs(i,ind_q1)
            hsvs(i,if33)=dfg33(i)
            
            dfg11(i)=hsvs(i,if11)
            dfg22(i)=hsvs(i,if22)
            dfg33(i)=hsvs(i,if33)
            dfg12(i)=hsvs(i,if12)
            dfg21(i)=hsvs(i,if21)
            dfg13(i)=hsvs(i,if13)
            dfg31(i)=hsvs(i,if31)
            dfg23(i)=hsvs(i,if23)
            dfg32(i)=hsvs(i,if32)
          enddo
c
c       store deformation gradient in material system
c       as F_bar=F*Q
c
c        else if (ihyper(mt).lt.0) then
        else if (ihyper(mt).eq.-1) then
c         Transform old deformation gradient in new vumat
c         implementation
          if (ivumat(mt).eq.2) then
             do i=lft,llt
                dfg11(i)=hsvs(i,ind_q1)*hsvs(i,ifo11)-
     1               hsvs(i,ind_q2)*hsvs(i,ifo12)
                dfg12(i)=hsvs(i,ind_q2)*hsvs(i,ifo11)+
     1               hsvs(i,ind_q1)*hsvs(i,ifo12)
                dfg13(i)=hsvs(i,ifo13)
                dfg21(i)=hsvs(i,ind_q1)*hsvs(i,ifo21)-
     1               hsvs(i,ind_q2)*hsvs(i,ifo22)
                dfg22(i)=hsvs(i,ind_q2)*hsvs(i,ifo21)+
     1               hsvs(i,ind_q1)*hsvs(i,ifo22)
                dfg23(i)=hsvs(i,ifo23)
                dfg31(i)=hsvs(i,ind_q1)*hsvs(i,ifo31)-
     1               hsvs(i,ind_q2)*hsvs(i,ifo32)
                dfg32(i)=hsvs(i,ind_q2)*hsvs(i,ifo31)+
     1               hsvs(i,ind_q1)*hsvs(i,ifo32)
                dfg33(i)=hsvs(i,ifo33)
c
                hsvs(i,ifo11)=dfg11(i)
                hsvs(i,ifo12)=dfg12(i)
                hsvs(i,ifo21)=dfg21(i)
                hsvs(i,ifo22)=dfg22(i)
                hsvs(i,ifo31)=dfg31(i)
                hsvs(i,ifo32)=dfg32(i)
             enddo
          endif
          do i=lft,llt
            dfg11(i)=hsvs(i,ind_q1)*hsvs(i,if11)-
     1               hsvs(i,ind_q2)*hsvs(i,if12)
            dfg12(i)=hsvs(i,ind_q2)*hsvs(i,if11)+
     1               hsvs(i,ind_q1)*hsvs(i,if12)
            dfg13(i)=hsvs(i,if13)
            dfg21(i)=hsvs(i,ind_q1)*hsvs(i,if21)-
     1               hsvs(i,ind_q2)*hsvs(i,if22)
            dfg22(i)=hsvs(i,ind_q2)*hsvs(i,if21)+
     1               hsvs(i,ind_q1)*hsvs(i,if22)
            dfg23(i)=hsvs(i,if23)
            dfg31(i)=hsvs(i,ind_q1)*hsvs(i,if31)-
     1               hsvs(i,ind_q2)*hsvs(i,if32)
            dfg32(i)=hsvs(i,ind_q2)*hsvs(i,if31)+
     1               hsvs(i,ind_q1)*hsvs(i,if32)
            dfg33(i)=hsvs(i,if33)
c
            hsvs(i,if11)=dfg11(i)
            hsvs(i,if12)=dfg12(i)
            hsvs(i,if21)=dfg21(i)
            hsvs(i,if22)=dfg22(i)
            hsvs(i,if31)=dfg31(i)
            hsvs(i,if32)=dfg32(i)
          enddo
 
       endif
      endif
c
c     update first two rows of deformation gradient at time = n+1
c
      if (ihyper(mt).ne.0) then
        call integf_s(hsvs(1,if11),hsvs(1,if21),hsvs(1,if31),
     &   hsvs(1,if12),hsvs(1,if22),hsvs(1,if32),
     &   hsvs(1,if13),hsvs(1,if23),hsvs(1,if33),lft,llt)
      endif
c
      if (iabs(ihyper(mt)).eq.3.or.iabs(ihyper(mt)).eq.4) then
         if (iabs(ihyper(mt)).eq.3) then
            do i=lft,llt
               d3(i)=0.
            enddo
            if (hsvs(lft,ind_thick).eq.0.) then
               do i=lft,llt
                  hsvs(i,ind_thick  )=dm_s_fibl(9*(nnm1+i-1)+1)
                  hsvs(i,ind_thick+1)=dm_s_fibl(9*(nnm1+i-1)+2)
                  hsvs(i,ind_thick+2)=dm_s_fibl(9*(nnm1+i-1)+3)
                  hsvs(i,ind_thick+3)=dm_s_fibl(9*(nnm1+i-1)+4)
               enddo
            endif
         else
            ind_thick=ind_last+1
            do i=lft,llt
               hsvs(i,ind_last+1)=dm_s_fibl(9*(nnm1+i-1)+1)
               hsvs(i,ind_last+2)=dm_s_fibl(9*(nnm1+i-1)+2)
               hsvs(i,ind_last+3)=dm_s_fibl(9*(nnm1+i-1)+3)
               hsvs(i,ind_last+4)=dm_s_fibl(9*(nnm1+i-1)+4)
            enddo
         endif
         call usrshl_defgrad(hsvs(1,if11),ihyper(mt),
     1        rcoor,scoor,tcoor,
     2        dm_x,dm_rots,
     3        dm_s_uhat(12*nnm1+1),
     4        dm_s_uthk( 4*nnm1+1),
     5        hsvs(1,ind_thick),
     6        lft,-llt)
         do k=1,3
            do j=1,3
               do i=lft,llt
                  qmat(i,j,k)=qloc(i,j,k)
               enddo
            enddo
         enddo
         if (iorien(mt).ne.0) then
            do j=1,3
               do i=lft,llt
                  q1=hsvs(i,ind_q1)*qmat(i,j,1)-
     1                 hsvs(i,ind_q2)*qmat(i,j,2)
                  q2=hsvs(i,ind_q2)*qmat(i,j,1)+
     1                 hsvs(i,ind_q1)*qmat(i,j,2)
                  qmat(i,j,1)=q1
                  qmat(i,j,2)=q2
               enddo
            enddo
         endif
      endif
c
c     if ishrmp(mt).lt.0 then the flag for temperature is active
c     temperatures are stored in the temps array.
c
      if (ishrmp(mt).lt.0) then
        call usr_temps (a(ntmp0+1),a(n19),itemp,temps,lft,llt,ix1,ix2,
     .   ix3,ix4,ixs,ixs(1,2),ixs(1,3),ixs(1,4),num_nods,itopaz,
     .   nnm1,rcoor,scoor,tcoor,itempe(5),ia(nnm1+itempe(9)))
      else
        do i=lft,llt
          temps(i)=0.0
        enddo
      endif
c
c     Get thermal history variables from thermal
c     user material
c
      call get_thhsv(nthhsv,thhsv,itemp,lft,llt,
     1 num_nods,itopaz,nnm1,rcoor,scoor,tcoor)
c
c     energy calculations
c
      do 33 i=lft,llt
      einc(i)=d1(i)*sig1(i)+d2(i)*sig2(i)+d4(i)*sig4(i)+d5(i)*sig5(i)
     1       +d6(i)*sig6(i)
 33   continue
c
c     characteristic element size and element id
      do i=lft,llt
        elsizv(i)=sqrt(sidmn(i))
        ielm=nshbwp(nnm1+i)
        if (ielm.gt.0) idelev(i)=lqfinv8(ielm,4)
      enddo
c
c     memory pointer for extra memory data
      lcma=ncma+nmmat+ia(ncma+mxt(lft)-1)-1
c
c     vectorization flag
c
      ivect=ivectr(mt)
c
c     implicit rejection flag
c
      reject=.false.
c
      mte40=mt-40
c
c     scalar umat
c
      if (ivect.eq.0) then
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
c        print '(6(E10.4,3x))',(eps(ll),ll=1,6)
        sig(1)=sig1(i)
        sig(2)=sig2(i)
        sig(3)=sig3(i)
        sig(4)=sig4(i)
        sig(5)=sig5(i)
        sig(6)=sig6(i)
        epsp=epsps(i)
        temper=temps(i)
        failel=.false.
c       xfem start
        if (.not.xfempart) then
          if (ifipts(mt).lt.0) failel=hsvs(i,ind_fipts).ne.0.
        else
          failel=fail(i).lt.0.01
        endif
c       xfem end
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
             do j=1,4
                hsv(no_hsvs+j+9)=hsvs(i,ind_thick-1+j)
             enddo
          endif
          if (iabs(ihyper(mt)).eq.4) then
          do j=1,18
            hsv(no_hsvs+j+9)=hsvs(i,ind_defgrad-1+j+9)
          enddo
          endif
          if (iabs(ihyper(mt)).eq.3.or.iabs(ihyper(mt)).eq.4) then
             do k=1,3
                do j=1,3
                   qmats(j,k)=qmat(i,j,k)
                enddo
             enddo
          endif
        endif
        if (nthhsv.gt.0) then
          do j=1,nthhsv
            thhsvi(j)=thhsv(i,j)
          enddo
        endif
        elsiz=elsizv(i)
        idele=idelev(i)
c
c       call user developed subroutines here
c
        go to (41,42,43,44,45,46,47,48,49,50), mte40
   41   call umat41 (cm(mx+1),eps,sig,epsp,hsv,dt1,capa,eltype,tt,
     .   temper,failel,crv,nnpcrv,a(lcma),qmats,elsiz,idele,reject)
        go to 60
   42   call umat42 (cm(mx+1),eps,sig,epsp,hsv,dt1,capa,eltype,tt,
     .   temper,failel,crv,nnpcrv,a(lcma),qmats,elsiz,idele,reject)
        go to 60
   43   call umat43 (cm(mx+1),eps,sig,epsp,hsv,dt1,capa,eltype,tt,
     .   temper,failel,crv,nnpcrv,a(lcma),qmats,elsiz,idele,reject)
        go to 60
   44   call umat44 (cm(mx+1),eps,sig,epsp,hsv,dt1,capa,eltype,tt,
     .   temper,failel,crv,nnpcrv,a(lcma),qmats,elsiz,idele,reject)
        go to 60
   45   call umat45 (cm(mx+1),eps,sig,epsp,hsv,dt1,capa,eltype,tt,
     .   temper,failel,crv,nnpcrv,a(lcma),qmats,elsiz,idele,ihyper(mt),
     .   reject)
        go to 60
   46   call umat46 (cm(mx+1),eps,sig,epsp,hsv,dt1,capa,eltype,tt,
     .   temper,failel,crv,nnpcrv,
     .   a(lcma),thhsvi,nthhsv,qmats,elsiz,idele,reject)
        go to 60
   47   call umat47 (cm(mx+1),eps,sig,epsp,hsv,dt1,capa,eltype,tt,
     .   temper,failel,crv,nnpcrv,a(lcma),qmats,elsiz,idele,reject)
        go to 60
   48   call umat48 (cm(mx+1),eps,sig,epsp,hsv,dt1,capa,eltype,tt,
     .   temper,failel,crv,nnpcrv,a(lcma),qmats,elsiz,idele,reject)
        go to 60
   49   call umat49 (cm(mx+1),eps,sig,epsp,hsv,dt1,capa,eltype,tt,
     .   temper,failel,crv,nnpcrv,a(lcma),qmats,elsiz,idele,reject)
        go to 60
   50   call umat50 (cm(mx+1),eps,sig,epsp,hsv,dt1,capa,eltype,tt,
     .   temper,failel,crv,nnpcrv,a(lcma),qmats,elsiz,idele,reject)
c
c       scattering of variables
c
 60     if (no_hsvs.gt.0) then
          do j=1,no_hsvs
            hsvs(i,j)=hsv(j)
          enddo
        endif
c
        if (ihyper(mt).ne.0) then
          do j=1,9
            hsvs(i,ind_defgrad-1+j)=hsv(no_hsvs+j)
          enddo
          if (iabs(ihyper(mt)).eq.3) then
          do j=1,4
            hsvs(i,ind_thick-1+j)=hsv(no_hsvs+j+9)
          enddo
          endif
          if (iabs(ihyper(mt)).eq.4) then
          do j=1,18
            hsvs(i,ind_defgrad-1+j+9)=hsv(no_hsvs+j+9)
          enddo
          endif
        endif
c
        d3(i)  =eps(3)
c
        if (ifipts(mt).eq.0) failel=.false.
c
        if (failel) then
          if (.not.xfempart) then
          sig1(i)=0.
          sig2(i)=0.
          sig3(i)=0.
          sig4(i)=0.
          sig5(i)=0.
          sig6(i)=0.
          else
          sig1(i)=sig(1)
          sig2(i)=sig(2)
          sig3(i)=sig(3)
          sig4(i)=sig(4)
          sig5(i)=sig(5)
          sig6(i)=sig(6)
          endif
          if (ifipts(mt).lt.0) hsvs(i,ind_fipts)=1.
          nfipts(i)=nfipts(i)+1
          if (ifipts(mt).ge.0) then
          failur=.true.
          def_ele_eros(i)=0.
          ifail(i)=1
          fail(i)=0.
          elseif (nfipts(i).ge.nint(cm(mx-ifipts(mt)))) then
          failur=.true.
          def_ele_eros(i)=0.
          ifail(i)=1
          fail(i)=0.
          endif
        else
          sig1(i)=sig(1)
          sig2(i)=sig(2)
          sig3(i)=sig(3)
          sig4(i)=sig(4)
          sig5(i)=sig(5)
          sig6(i)=sig(6)
        endif
        epsps(i)=epsp
 120    continue
c
c     vector umat
c
      else
c
c       assume no failed elements
c
c       xfem start
        if (.not.xfempart) then
        if (ifipts(mt).ge.0) then
        do i=lft,llt
          failels(i)=.false.
        enddo
        else
          do i=lft,llt
            failels(i)=hsvs(i,ind_fipts).ne.0.
          enddo
        endif
        else
        do i=lft,llt
          failels(i)=fail(i).lt.0.01
        enddo
        endif
c       xfem end
c
c       call user developed subroutines here
c       first history variable is the one requested
c
        if(ivumat(mt).eq.0) then
c
        if (mt.eq.41) then
          call umat41v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,
     .     dt1siz,capa,eltype,tt,temps,failels,nlq,crv,nnpcrv,
     .     a(lcma),qmat,
     .     elsizv,idelev,reject)
        elseif (mt.eq.42) then
          call umat42v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,
     .     dt1siz,capa,eltype,tt,temps,failels,nlq,crv,nnpcrv,
     .     a(lcma),qmat,
     .     elsizv,idelev,reject)
        elseif (mt.eq.43) then
          call umat43v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,
     .     dt1siz,capa,eltype,tt,temps,failels,nlq,crv,nnpcrv,
     .     a(lcma),qmat,
     .     elsizv,idelev,reject)
        elseif (mt.eq.44) then
          call umat44v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,
     .     dt1siz,capa,eltype,tt,temps,failels,nlq,crv,nnpcrv,
     .     a(lcma),qmat,
     .     elsizv,idelev,reject)
        elseif (mt.eq.45) then
          call umat45v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,
     .     dt1siz,capa,eltype,tt,temps,failels,nlq,crv,nnpcrv,
     .     a(lcma),qmat,
     .     elsizv,idelev,ihyper(mt),reject)
        elseif (mt.eq.46) then
          call umat46v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,
     .     dt1siz,capa,eltype,tt,temps,failels,nlq,crv,nnpcrv,a(lcma),
     .     thhsv,nthhsv,qmat,elsizv,idelev,reject)
        elseif (mt.eq.47) then
          call umat47v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,
     .     dt1siz,capa,eltype,tt,temps,failels,nlq,crv,nnpcrv,
     .     a(lcma),qmat,elsizv,idelev,reject)
        elseif (mt.eq.48) then
          call umat48v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,
     .     dt1siz,capa,eltype,tt,temps,failels,nlq,crv,nnpcrv,
     .     a(lcma),qmat,elsizv,idelev,reject,ipt,npc,plc)
        elseif (mt.eq.49) then
          call umat49v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,
     .     dt1siz,capa,eltype,tt,temps,failels,nlq,crv,nnpcrv,
     .     a(lcma),qmat,elsizv,idelev,reject,ipt,npc,plc)
        elseif (mt.eq.50) then
          call umat50v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,
     .     dt1siz,capa,eltype,tt,temps,failels,nlq,crv,nnpcrv,
     .     a(lcma),qmat,
     .     elsizv,idelev,reject)
c
        elseif (mt.eq.281) then
          call mat281s(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,
     .     dt1siz,capa,eltype,tt,temps,failels,nlq,crv,
     .     ipt, npc, plc, nnm1,a(lcma))
        elseif (mt.eq.282) then
          call mat282s(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,
     .     dt1siz,capa,eltype,tt,temps,failels,nlq,crv,
     .     ipt, npc, plc, nnm1,a(lcma),xfempart)
c       elseif (mt.eq.283) then
c         call umat283s(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
c    .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,
c    .     dt1siz,capa,eltype,tt,temps,failels,nlq,crv,
c    .     a(lcma))
        elseif (mt.eq.283) then
          call mat283s(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,
     .     dt1siz,capa,eltype,tt,temps,failels,nlq,crv,
     .     ipt, npc, plc, nnm1,a(lcma), dm_x, xfempart)
        elseif (mt.eq.284) then
          call mat284s(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,
     .     dt1siz,capa,eltype,tt,temps,failels,nlq,crv,
     .     ipt, npc, plc, nnm1,a(lcma))
        elseif (mt.eq.285) then
          call mat285s(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,
     .     dt1siz,capa,eltype,tt,temps,failels,nlq,crv,
     .     ipt, npc, plc, nnm1,a(lcma))
        elseif (mt.eq.286) then
          call mat286s(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,
     .     dt1siz,capa,eltype,tt,temps,failels,nlq,crv,
     .     ipt, npc, plc, nnm1,a(lcma))
        elseif (mt.eq.287) then
          call mat287s(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,
     .     dt1siz,capa,eltype,tt,temps,failels,nlq,crv,
     .    ipt, npc, plc, nnm1,a(lcma))
        elseif (mt.eq.288) then
          call mat288s(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,
     .     dt1siz,capa,eltype,tt,temps,failels,nlq,crv,
     .     ipt, npc, plc, nnm1,a(lcma))
        elseif (mt.eq.289) then
          call mat289s(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,
     .     dt1siz,capa,eltype,tt,temps,failels,nlq,crv,
     .     ipt, npc, plc, nnm1,a(lcma))
        endif
        else
c
c       ALL vecumat interfaces are moved to user_vecumat.F
        endif
c
c       check for failure
c
        if (ifipts(mt).ne.0) then
        do i=lft,llt
          if (failels(i)) then
            if (.not.xfempart) then
            sig1(i)=0.
            sig2(i)=0.
            sig3(i)=0.
            sig4(i)=0.
            sig5(i)=0.
            sig6(i)=0.
            endif
            if (ifipts(mt).lt.0) hsvs(i,ind_fipts)=1.
            nfipts(i)=nfipts(i)+1
            if (ifipts(mt).ge.0) then
            failur=.true.
            def_ele_eros(i)=0.
            ifail(i)=1
            fail(i)=0.
            elseif (nfipts(i).ge.nint(cm(mx-ifipts(mt)))) then
            failur=.true.
            def_ele_eros(i)=0.
            ifail(i)=1
            fail(i)=0.
            endif
           endif
        enddo
      endif
      endif
c
      if (iabs(ihyper(mt)).eq.4) then
         do i=lft,llt
            d3(i)=0.
         enddo
      endif
c
c     energy calculations
c
      do 130 i=lft,llt
      einc(i)=d1(i)*sig1(i)+d2(i)*sig2(i)+d4(i)*sig4(i)+d5(i)*sig5(i)
     1       +d6(i)*sig6(i)+einc(i)
 130  continue
c
      if (iorien(mt).ne.0) then
c
c       transform stresses to element system
c
        if (ihyper(mt).ge.0) then
          do 140 i=lft,llt
          stg5(i)=sig5(i)
          stg6(i)=sig6(i)
          a11(i) = sig1(i)*hsvs(i,ind_q1)+sig4(i)*hsvs(i,ind_q2)
          a12(i) =-sig1(i)*hsvs(i,ind_q2)+sig4(i)*hsvs(i,ind_q1)
          a21(i) = sig4(i)*hsvs(i,ind_q1)+sig2(i)*hsvs(i,ind_q2)
          a22(i) =-sig4(i)*hsvs(i,ind_q2)+sig2(i)*hsvs(i,ind_q1)
          sig1(i)= hsvs(i,ind_q1)*a11(i)+hsvs(i,ind_q2)*a21(i)
          sig2(i)=-hsvs(i,ind_q2)*a12(i)+hsvs(i,ind_q1)*a22(i)
          sig4(i)= hsvs(i,ind_q1)*a12(i)+hsvs(i,ind_q2)*a22(i)
          sig5(i)=-hsvs(i,ind_q2)*stg6(i)+hsvs(i,ind_q1)*stg5(i)
          sig6(i)= hsvs(i,ind_q1)*stg6(i)+hsvs(i,ind_q2)*stg5(i)
 140      continue
        endif
c
c       transform deformation gradient back to element system
c
      if (ihyper(mt).gt.0) then
c        if (ihyper(mt).eq.1) then
          do i=lft,llt
            ftemp=hsvs(i,ind_q1)*hsvs(i,if11)+
     1            hsvs(i,ind_q2)*hsvs(i,if21)
            hsvs(i,if21)=-hsvs(i,ind_q2)*hsvs(i,if11)+
     1                    hsvs(i,ind_q1)*hsvs(i,if21)
            hsvs(i,if11)=ftemp
            ftemp=hsvs(i,ind_q1)*hsvs(i,if12)+
     1            hsvs(i,ind_q2)*hsvs(i,if22)
            hsvs(i,if22)=-hsvs(i,ind_q2)*hsvs(i,if12)+
     1                    hsvs(i,ind_q1)*hsvs(i,if22)
            hsvs(i,if12)=ftemp
            ftemp=hsvs(i,ind_q1)*hsvs(i,if13)+
     1            hsvs(i,ind_q2)*hsvs(i,if23)
            hsvs(i,if23)=-hsvs(i,ind_q2)*hsvs(i,if13)+
     1                    hsvs(i,ind_q1)*hsvs(i,if23)
            hsvs(i,if13)=ftemp
          enddo
c
c
c        transform deformation gradient back to element system
c
        else if (ihyper(mt).eq.-2) then
          do i=lft,llt
            f11=hsvs(i,ind_q1)*hsvs(i,if11)+
     1            hsvs(i,ind_q2)*hsvs(i,if21)
            f21=-hsvs(i,ind_q2)*hsvs(i,if11)+
     1                    hsvs(i,ind_q1)*hsvs(i,if21)
            f31=hsvs(i,if31)
c            hsvs(i,if11)=ftemp
            f12=hsvs(i,ind_q1)*hsvs(i,if12)+
     1            hsvs(i,ind_q2)*hsvs(i,if22)
            f22=-hsvs(i,ind_q2)*hsvs(i,if12)+
     1                    hsvs(i,ind_q1)*hsvs(i,if22)
            f32=hsvs(i,if32)
c            hsvs(i,if12)=ftemp
            f13=hsvs(i,ind_q1)*hsvs(i,if13)+
     1            hsvs(i,ind_q2)*hsvs(i,if23)
            f23=-hsvs(i,ind_q2)*hsvs(i,if13)+
     1                    hsvs(i,ind_q1)*hsvs(i,if23)
            f33=hsvs(i,if33)
c            hsvs(i,if13)=ftemp
            hsvs(i,if11)=f11*hsvs(i,ind_q1)+f12*hsvs(i,ind_q2)
            hsvs(i,if12)=-f11*hsvs(i,ind_q2)+f12*hsvs(i,ind_q1)
            hsvs(i,if13)=f13
            hsvs(i,if21)=f21*hsvs(i,ind_q1)+f22*hsvs(i,ind_q2)
            hsvs(i,if22)=-f21*hsvs(i,ind_q2)+f22*hsvs(i,ind_q1)
            hsvs(i,if23)=f23
            hsvs(i,if31)=f31*hsvs(i,ind_q1)+f32*hsvs(i,ind_q2)
            hsvs(i,if32)=-f31*hsvs(i,ind_q2)+f32*hsvs(i,ind_q1)
            hsvs(i,if33)=f33
          enddo
c
c
c        transform deformation gradient back to element system
c
c         elseif (ihyper(mt).lt.0) then
         elseif (ihyper(mt).eq.-1) then
           do i=lft,llt
            ftemp=hsvs(i,ind_q1)*hsvs(i,if11)+
     1            hsvs(i,ind_q2)*hsvs(i,if12)
            hsvs(i,if12)=-hsvs(i,ind_q2)*hsvs(i,if11)+
     1                    hsvs(i,ind_q1)*hsvs(i,if12)
            hsvs(i,if11)=ftemp
            ftemp=hsvs(i,ind_q1)*hsvs(i,if21)+
     1            hsvs(i,ind_q2)*hsvs(i,if22)
            hsvs(i,if22)=-hsvs(i,ind_q2)*hsvs(i,if21)+
     1                    hsvs(i,ind_q1)*hsvs(i,if22)
            hsvs(i,if21)=ftemp
            ftemp=hsvs(i,ind_q1)*hsvs(i,if31)+
     1            hsvs(i,ind_q2)*hsvs(i,if32)
            hsvs(i,if32)=-hsvs(i,ind_q2)*hsvs(i,if31)+
     1                    hsvs(i,ind_q1)*hsvs(i,if32)
            hsvs(i,if31)=ftemp
c
            enddo
c           Also transform back old deformation gradient in new vumat
c           implementation
            if (ivumat(mt).eq.2) then
               do i=lft,llt
                  ftemp=hsvs(i,ind_q1)*hsvs(i,ifo11)+
     1                 hsvs(i,ind_q2)*hsvs(i,ifo12)
                  hsvs(i,ifo12)=-hsvs(i,ind_q2)*hsvs(i,ifo11)+
     1                 hsvs(i,ind_q1)*hsvs(i,ifo12)
                  hsvs(i,ifo11)=ftemp
                  ftemp=hsvs(i,ind_q1)*hsvs(i,ifo21)+
     1                 hsvs(i,ind_q2)*hsvs(i,ifo22)
                  hsvs(i,ifo22)=-hsvs(i,ind_q2)*hsvs(i,ifo21)+
     1                 hsvs(i,ind_q1)*hsvs(i,ifo22)
                  hsvs(i,ifo21)=ftemp
                  ftemp=hsvs(i,ind_q1)*hsvs(i,ifo31)+
     1                 hsvs(i,ind_q2)*hsvs(i,ifo32)
                  hsvs(i,ifo32)=-hsvs(i,ind_q2)*hsvs(i,ifo31)+
     1                 hsvs(i,ind_q1)*hsvs(i,ifo32)
                  hsvs(i,ifo31)=ftemp
               enddo
            endif
               
         endif
      endif
c
c     flag if material model rejected implicit iterate
      if (isolvr(1).ne.0.and.reject) then
         isolvr(78)=5
         ascntl(150)=-1.e32
      endif
c
      return
c900  format(/
c    1 ' *** Error User defined material in part',i12,
c    2 ' exceeds the current limit'/
c    3 10x,'of history variables for shells.')
      end
      subroutine urmatb (lft,llt,cm,capa,mt,crv,nnpcrv,
     $     nnm1,nconstp,npc,plc,
     $     eltype,nbmbwp,ncsave)
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
# 1256 "dyn21umat.F" 2 
      include 'memaia.inc'
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
# 1259 "dyn21umat.F" 2 
# 1 ".\bk13.inc" 1 
      integer lc0,lc1h,lc1b,lc1t,lc2,lc3,lc4,lc5,lc6,lc6e,lc6f,lc9,     
     & lc10,lc11,lc12,lc13,lc14,lc15,lc16,lc17,lc18,lb0,lb1,lb2,        
     & lc7a,lc7b,lc7c,lc7d,lc7e,lc7f,lc7g,lc7h,lc7i,lc7j,lc7k,lc7l,     
     & lc7t,lc7x,lc6g,lc6h
      common/bk13/lc0,lc1h,lc1b,lc1t,lc2,lc3,lc4,lc5,lc6,lc6e,lc6f,lc9, 
     & lc10,lc11,lc12,lc13,lc14,lc15,lc16,lc17,lc18,lb0,lb1,lb2,        
     & lc7a,lc7b,lc7c,lc7d,lc7e,lc7f,lc7g,lc7h,lc7i,lc7j,lc7k,lc7l,     
     & lc7t,lc7x,lc6g,lc6h
# 1260 "dyn21umat.F" 2 
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

# 1261 "dyn21umat.F" 2 
# 1 ".\implicit1.inc" 1 
!   ... implicit common ...
!
      character*80    sc_filename, moddyn_filename, modal_op2_filename, 
     &                rv_filename
      character*10    sc_mass, sc_damp, sc_stiff, sc_inert
      common/bki01ch/ sc_filename, sc_mass, sc_damp, sc_stiff, sc_inert,
     &                moddyn_filename(2), modal_op2_filename,           
     &                rv_filename
!
      integer imauto,iteopt,lauto,mthsol,ilimit,maxref,icnvrg,          
     & igdiv,nwebuf,neql,neqt,imterm,imphas,nbfgs,                      
     & numupd,istif,itrlas,imerr,imdof,neqtgl,ilsmtd,lsdir,ptr_aspc_h,  
     & impcntctl,ipmaxx,igpx,itermp,itermp1,h_lp,h_rd,ptr_rf_data_h,    
     & moddyn_flag, moddyn_mdrange, moddyn_mdlen, moddyn_mdfreq,        
     & moddyn_mdfrqlen, moddyn_aux,                                     
     & mf2_ptrnum_f95, mf2_ptrsym_f95, h_rsvc, im_numnp, mpp_im_numnp,  
     & h_frf
      common/bki01i/imauto,iteopt,lauto,mthsol,ilimit,maxref,icnvrg,    
     & igdiv,nwebuf,neql,neqt,imterm,imphas,nbfgs,                      
     & numupd,istif,itrlas,imerr,imdof,neqtgl,ilsmtd,lsdir,ptr_aspc_h,  
     & impcntctl,ipmaxx,igpx,itermp,itermp1,h_lp,h_rd,ptr_rf_data_h,    
     & moddyn_flag, moddyn_mdrange, moddyn_mdlen, moddyn_mdfreq,        
     & moddyn_mdfrqlen, moddyn_aux(13),                                 
     & mf2_ptrnum_f95, mf2_ptrsym_f95, h_rsvc, im_numnp, mpp_im_numnp,  
     & h_frf
!
      real dtimp,dtimp0,timeim,dtmnim,dtmxim,cvtl,ectl,rctl,            
     & tolls,dnorm2,dtprnt,dtplot,dtiter,dtrefm,ppmax,pmaxr,errord,umax,
     & sumx,xrte,moddyn_valdmp,moddyn_output_time,ctmxs,htmxs,xkei,     
     & tollls,pretim
      common/bki01r/dtimp,dtimp0,timeim,dtmnim,dtmxim,cvtl,ectl,rctl,   
     & tolls,dnorm2,dtprnt(2),dtplot(2),dtiter(2),dtrefm(2),            
     & ppmax,pmaxr,errord,umax,sumx,xrte,moddyn_valdmp,                 
     & moddyn_output_time(2),ctmxs(8),htmxs(8),xkei(-2:2),tollls,pretim
!
      real ascntl,r78tags
      common/bki02r/ascntl(200),r78tags(20)
!
      logical lsensw,jlsmtd
      common/bki01l/lsensw(20),jlsmtd
!
      integer imip,isolvr,icwrb,elem_tbl,i78tags,moddyn_fast,numsmv
      common/bki02i/imip(300),isolvr(500),icwrb(50),elem_tbl(4,65),     
     & i78tags(20),moddyn_fast,numsmv
# 1262 "dyn21umat.F" 2 
# 1 ".\usermat_vendor.inc" 1 
c
      integer user_iform
      character*10 vendor
      common /usermat_vendor/ user_iform,vendor
# 1263 "dyn21umat.F" 2 
      common/aux2loc/d1(nlq),d2(nlq),d3(nlq),d4(nlq),d5(nlq),d6(nlq),
     1 wzzdt(nlq),wyydt(nlq),wxxdt(nlq),einc(nlq)
      common/aux14loc/
     1 sig1(nlq),sig2(nlq),sig3(nlq),sig4(nlq),
     2 sig5(nlq),sig6(nlq),epsps(nlq),hsvs(nlq,NHISVAR)
      common/aux33loc/
     1 ix1(nlq),ix2(nlq),ix3(nlq),ix4(nlq),ix5(nlq),mxt(nlq)
      common/aux35loc/rhoa(nlq),cb(nlq),davg(nlq),p(nlq)
      common/bux13loc/eps(6),sig(6),hsv(NHISVAR),temps(nlq)
# 1 ".\failcmloc.inc" 1 
c     include this file when failur IS used in element/material routines,
c     or in other words when a loop is multi threaded
      integer ifail
      logical failur,failgl,failst
      common/failcm/failst,failgl
      common/failcmloc/ifail(nlq),failur
# 1281 "dyn21umat.F" 2 
      common/failuloc/sieu(nlq),fail(nlq),ifaili(nlq),nfipts(nlq),
     . msgfail(nlq),def_ele_eros(nlq)
      common/soundloc/ss(nlq),sndsp(nlq),diagm(nlq),sarea(nlq),
     . dxl(nlq)
      common/subtssloc/dt1siz(nlq)
c
      common/bk00/numnp,numpc,numlp,neq,ndof,nlcur,numcl,numvc,
     + ndtpts,nelmd,nmmat,numelh,numelb,numels,numelt,numdp,
     + grvity,idirgv,nodspc,nspcor,nusa
      common/bk01/itherm,itemp,ntmp0,ntmp1,itempan,itempdr,itmpe(14),
     . itempe(10),nthxp,ithxp(19)
      common/bk28/summss,xke,xpe,tt,xte0,erodeke,erodeie
c
      common/thropt/itopaz(101)
c
      dimension cm(*),crv(lq1,2,*),nconstp(*),npc(*),plc(*)
      integer nnpcrv(*)
      character*(*)eltype
      dimension nbmbwp(*)
c     dimension eps(6),sig(6),hsv(NHISVAR),temps(nlq)
      dimension elsizv(nlq),idelev(nlq)
      logical failel,failels(nlq),reject
      integer lqfinv8,idele
      dimension ncsave(*)
c
c     data temps/nlq*0.0/
      data failels/nlq*.false./
c
c$omp threadprivate (/failcmloc/)
c$omp threadprivate (/subtssloc/)
c$omp threadprivate (/soundloc/)
c$omp threadprivate (/failuloc/)
c$omp threadprivate (/bux13loc/)
c$omp threadprivate (/aux35loc/)
c$omp threadprivate (/aux33loc/)
c$omp threadprivate (/aux14loc/)
c$omp threadprivate (/aux2loc/)
c$omp threadprivate (/usermat_vendor/)
      failel=.false.
c
      reject=.false.
      ivect=ivectr(mt)
      mx=48*(mxt(lft)-1)
      gm=cm(mx+abs(ishrmp(mt)))
      bk=cm(mx+ibulkp(mt))
      pr=(3.*bk-2.*gm)/(2.*(3.*bk+gm))
      ym=2.*(1.+pr)*gm
      ss(lft)=ym
      do 10 i=lft,llt
      einc(i)=d1(i)*sig1(i)+d4(i)*sig4(i)+d6(i)*sig6(i)
      cb(i)=ss(lft)
   10 continue
c
c     Determining number of requested history variables
c
      no_hsvs=ncsave(mxt(lft))
c
c     if ishrmp(mt).lt.0 then the flag for temperature is active
c     temperatures are stored in the temps array.
c
      if (ishrmp(mt).lt.0) then
        num_nods=2
        call usr_temps (a(ntmp0+1),a(n19),itemp,temps,lft,llt,ix1,
     .   ix2,ix3,ix4,ix4,ix4,ix4,ix4,num_nods,itopaz,0,0.,0.,0.,
     .   itempe(4),ia(nnm1+itempe(8)))
      else
        do i=lft,llt
          temps(i)=0.0
        enddo
      endif
c
c     characteristic element size and element id
      do i=lft,llt
        elsizv(i)=diagm(i)
        ielm=nbmbwp(nnm1+i)
        if (ielm.gt.0) idelev(i)=lqfinv8(ielm,3)
      enddo
c
c     memory pointer for extra memory data
      lcma=ncma+nmmat+ia(ncma+mxt(lft)-1)-1
c
      mte40=mt-40
c
      if (ivect.eq.0) then
        do 120 i=lft,llt
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
          do 20 j=1,no_hsvs
          hsv(j)=hsvs(i,j)
 20       continue
        endif
        elsiz=elsizv(i)
        idele=idelev(i)
c
c       call user developed subroutines here
c
        go to (41,42,43,44,45,46,47,48,49,50), mte40
   41   call umat41 (cm(mx+1),eps,sig,epsp,hsv,dt1,capa,eltype,tt,
     1   temper,failel,crv,nnpcrv,a(lcma),0,elsiz,idele,reject)
        go to 60
   42   call umat42 (cm(mx+1),eps,sig,epsp,hsv,dt1,capa,eltype,tt,
     1   temper,failel,crv,nnpcrv,a(lcma),0,elsiz,idele,reject)
        go to 60
   43   call umat43 (cm(mx+1),eps,sig,epsp,hsv,dt1,capa,eltype,tt,
     1   temper,failel,crv,nnpcrv,a(lcma),0,elsiz,idele,reject)
        go to 60
   44   call umat44 (cm(mx+1),eps,sig,epsp,hsv,dt1,capa,eltype,tt,
     1   temper,failel,crv,nnpcrv,a(lcma),0,elsiz,idele,reject)
        go to 60
   45   call umat45 (cm(mx+1),eps,sig,epsp,hsv,dt1,capa,eltype,tt,
     1   temper,failel,crv,nnpcrv,a(lcma),0,elsiz,idele,0,reject)
        go to 60
   46   call umat46 (cm(mx+1),eps,sig,epsp,hsv,dt1,capa,eltype,tt,
     1   temper,failel,crv,nnpcrv,a(lcma),0.0,0,0,elsiz,idele,reject)
        go to 60
   47   call umat47 (cm(mx+1),eps,sig,epsp,hsv,dt1,capa,eltype,tt,
     1   temper,failel,crv,nnpcrv,a(lcma),0,elsiz,idele,reject)
        go to 60
   48   call umat48 (cm(mx+1),eps,sig,epsp,hsv,dt1,capa,eltype,tt,
     1   temper,failel,crv,nnpcrv,a(lcma),0,elsiz,idele,reject)
        go to 60
   49   call umat49 (cm(mx+1),eps,sig,epsp,hsv,dt1,capa,eltype,tt,
     1   temper,failel,crv,nnpcrv,a(lcma),0,elsiz,idele,reject)
        go to 60
   50   call umat50 (cm(mx+1),eps,sig,epsp,hsv,dt1,capa,eltype,tt,
     1   temper,failel,crv,nnpcrv,a(lcma),0,elsiz,idele,reject)
 60     continue
c
        if (no_hsvs.gt.0) then
          do 100 j=1,no_hsvs
          hsvs(i,j)=hsv(j)
 100      continue
        endif
        d2(i)  =eps(2)
        d3(i)  =eps(3)
        epsps(i)=epsp
        if (failel) then
          sig1(i)=0.
          sig2(i)=0.
          sig3(i)=0.
          sig4(i)=0.
          sig5(i)=0.
          sig6(i)=0.
          failur=.true.
          def_ele_eros(i)=0.
          ifail(i)=1
          fail(i)=0.
        else
          sig1(i)=sig(1)
          sig2(i)=sig(2)
          sig3(i)=sig(3)
          sig4(i)=sig(4)
          sig5(i)=sig(5)
          sig6(i)=sig(6)
        endif
 120    continue
c
c     vector umat
c
      else
c
        if (ivumat(mt).eq.0) then
c
        do i=lft,llt
          failels(i)=.false.
        enddo
c
        if (mt.eq.41) then
          call umat41v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,dt1siz,capa,
     .     eltype,tt,temps,failels,nlq,crv,nnpcrv,
     .     a(lcma),0,elsizv,idelev,reject)
        elseif (mt.eq.42) then
          call umat42v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,dt1siz,capa,
     .     eltype,tt,temps,failels,nlq,crv,nnpcrv,
     .     a(lcma),0,elsizv,idelev,reject)
        elseif (mt.eq.43) then
          call umat43v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,dt1siz,capa,
     .     eltype,tt,temps,failels,nlq,crv,nnpcrv,
     .     a(lcma),0,elsizv,idelev,reject)
        elseif (mt.eq.44) then
          call umat44v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .   sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,dt1siz,capa,
     .   eltype,tt,temps,failels,nlq,crv,nnpcrv,
     .   a(lcma),0,elsizv,idelev,reject)
        elseif (mt.eq.45) then
          call umat45v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,dt1siz,capa,
     .     eltype,tt,temps,failels,nlq,crv,nnpcrv,
     .     a(lcma),0,elsizv,idelev,0,reject)
        elseif (mt.eq.46) then
          call umat46v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,dt1siz,capa,
     .     eltype,tt,temps,failels,nlq,crv,nnpcrv,
     .     a(lcma),0.0,0,0,elsizv,
     .     idelev,reject)
        elseif (mt.eq.47) then
          call umat47v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,dt1siz,capa,
     .     eltype,tt,temps,failels,nlq,crv,nnpcrv,
     .     a(lcma),0,elsizv,idelev,reject)
        elseif (mt.eq.48) then
          call umat48v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,dt1siz,capa,
     .     eltype,tt,temps,failels,nlq,crv,nnpcrv,
     .     a(lcma),0,elsizv,idelev,reject,ipt,npc,plc)
        elseif (mt.eq.49) then
          call umat49v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,dt1siz,capa,
     .     eltype,tt,temps,failels,nlq,crv,nnpcrv,
     .     a(lcma),0,elsizv,idelev,reject,ipt,npc,plc)
        elseif (mt.eq.50) then
          call umat50v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,dt1siz,capa,
     .     eltype,tt,temps,failels,nlq,crv,nnpcrv,
     .     a(lcma),0,elsizv,idelev,reject)
        endif
        else
c
c       ALL vecumat interfaces are moved to user_vecumat.F
        endif
      endif
c
      do 130 i=lft,llt
      einc(i)=d1(i)*sig1(i)+d4(i)*sig4(i)+d6(i)*sig6(i)+einc(i)
 130  continue
c
c     flag if material model rejected implicit iterate
      if (isolvr(1).ne.0.and.reject) then
         isolvr(78)=5
         ascntl(150)=-1.e32
      endif
c
      return
      end
      subroutine urmatd (lft,llt,cm,capa,mt,crv,nnpcrv,
     $     nnm1,nconstp,npc,plc,
     $     eltype,nbmbwp,ncsave)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     For now, call only vectorized umat routines for discrte beam.
c     umat47v includes curves
c
      include 'nlqparm'
      include 'nhisparm.inc'
# 1 ".\bk19.inc" 1 
      integer nconst(2000),lenma,ncneos(50),mtecom(2000),     
     & nhgshl(30)
      common/bk19/nconst,lenma,ncneos,mtecom,nhgshl
# 1540 "dyn21umat.F" 2 
      include 'memaia.inc'
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
# 1543 "dyn21umat.F" 2 
# 1 ".\bk13.inc" 1 
      integer lc0,lc1h,lc1b,lc1t,lc2,lc3,lc4,lc5,lc6,lc6e,lc6f,lc9,     
     & lc10,lc11,lc12,lc13,lc14,lc15,lc16,lc17,lc18,lb0,lb1,lb2,        
     & lc7a,lc7b,lc7c,lc7d,lc7e,lc7f,lc7g,lc7h,lc7i,lc7j,lc7k,lc7l,     
     & lc7t,lc7x,lc6g,lc6h
      common/bk13/lc0,lc1h,lc1b,lc1t,lc2,lc3,lc4,lc5,lc6,lc6e,lc6f,lc9, 
     & lc10,lc11,lc12,lc13,lc14,lc15,lc16,lc17,lc18,lb0,lb1,lb2,        
     & lc7a,lc7b,lc7c,lc7d,lc7e,lc7f,lc7g,lc7h,lc7i,lc7j,lc7k,lc7l,     
     & lc7t,lc7x,lc6g,lc6h
# 1544 "dyn21umat.F" 2 
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

# 1545 "dyn21umat.F" 2 
# 1 ".\implicit1.inc" 1 
!   ... implicit common ...
!
      character*80    sc_filename, moddyn_filename, modal_op2_filename, 
     &                rv_filename
      character*10    sc_mass, sc_damp, sc_stiff, sc_inert
      common/bki01ch/ sc_filename, sc_mass, sc_damp, sc_stiff, sc_inert,
     &                moddyn_filename(2), modal_op2_filename,           
     &                rv_filename
!
      integer imauto,iteopt,lauto,mthsol,ilimit,maxref,icnvrg,          
     & igdiv,nwebuf,neql,neqt,imterm,imphas,nbfgs,                      
     & numupd,istif,itrlas,imerr,imdof,neqtgl,ilsmtd,lsdir,ptr_aspc_h,  
     & impcntctl,ipmaxx,igpx,itermp,itermp1,h_lp,h_rd,ptr_rf_data_h,    
     & moddyn_flag, moddyn_mdrange, moddyn_mdlen, moddyn_mdfreq,        
     & moddyn_mdfrqlen, moddyn_aux,                                     
     & mf2_ptrnum_f95, mf2_ptrsym_f95, h_rsvc, im_numnp, mpp_im_numnp,  
     & h_frf
      common/bki01i/imauto,iteopt,lauto,mthsol,ilimit,maxref,icnvrg,    
     & igdiv,nwebuf,neql,neqt,imterm,imphas,nbfgs,                      
     & numupd,istif,itrlas,imerr,imdof,neqtgl,ilsmtd,lsdir,ptr_aspc_h,  
     & impcntctl,ipmaxx,igpx,itermp,itermp1,h_lp,h_rd,ptr_rf_data_h,    
     & moddyn_flag, moddyn_mdrange, moddyn_mdlen, moddyn_mdfreq,        
     & moddyn_mdfrqlen, moddyn_aux(13),                                 
     & mf2_ptrnum_f95, mf2_ptrsym_f95, h_rsvc, im_numnp, mpp_im_numnp,  
     & h_frf
!
      real dtimp,dtimp0,timeim,dtmnim,dtmxim,cvtl,ectl,rctl,            
     & tolls,dnorm2,dtprnt,dtplot,dtiter,dtrefm,ppmax,pmaxr,errord,umax,
     & sumx,xrte,moddyn_valdmp,moddyn_output_time,ctmxs,htmxs,xkei,     
     & tollls,pretim
      common/bki01r/dtimp,dtimp0,timeim,dtmnim,dtmxim,cvtl,ectl,rctl,   
     & tolls,dnorm2,dtprnt(2),dtplot(2),dtiter(2),dtrefm(2),            
     & ppmax,pmaxr,errord,umax,sumx,xrte,moddyn_valdmp,                 
     & moddyn_output_time(2),ctmxs(8),htmxs(8),xkei(-2:2),tollls,pretim
!
      real ascntl,r78tags
      common/bki02r/ascntl(200),r78tags(20)
!
      logical lsensw,jlsmtd
      common/bki01l/lsensw(20),jlsmtd
!
      integer imip,isolvr,icwrb,elem_tbl,i78tags,moddyn_fast,numsmv
      common/bki02i/imip(300),isolvr(500),icwrb(50),elem_tbl(4,65),     
     & i78tags(20),moddyn_fast,numsmv
# 1546 "dyn21umat.F" 2 
# 1 ".\usermat_vendor.inc" 1 
c
      integer user_iform
      character*10 vendor
      common /usermat_vendor/ user_iform,vendor
# 1547 "dyn21umat.F" 2 
      common/aux2loc/d1(nlq),d2(nlq),d3(nlq),d4(nlq),d5(nlq),d6(nlq),
     1 wzzdt(nlq),wyydt(nlq),wxxdt(nlq),einc(nlq)
      common/aux14loc/
     1 sig1(nlq),sig2(nlq),sig3(nlq),sig4(nlq),
     2 sig5(nlq),sig6(nlq),epsps(nlq),hsvs(nlq,NHISVAR)
      common/aux33loc/
     1 ix1(nlq),ix2(nlq),ix3(nlq),ix4(nlq),ix5(nlq),mxt(nlq)
      common/aux35loc/rhoa(nlq),cb(nlq),davg(nlq),p(nlq)
      common/bux13loc/ eps(6),sig(6),hsv(NHISVAR),temps(nlq)
      common/soundloc/ss(nlq),sndsp(nlq),diagm(nlq),sarea(nlq),
     . dxl(nlq)
      common/subtssloc/dt1siz(nlq)
c
      common/bk00/numnp,numpc,numlp,neq,ndof,nlcur,numcl,numvc,
     + ndtpts,nelmd,nmmat,numelh,numelb,numels,numelt,numdp,
     + grvity,idirgv,nodspc,nspcor,nusa
      common/bk01/itherm,itemp,ntmp0,ntmp1,itempan,itempdr,itmpe(14),
     . itempe(10),nthxp,ithxp(19)
      common/bk28/summss,xke,xpe,tt,xte0,erodeke,erodeie
      include 'slcntr.inc'
      common/thropt/itopaz(101)
c
c     capa here is ies in conmd6 and bqs in usrmat (all are internal energy)
c     real capa
      dimension capa(*),cm(*),crv(lq1,2,*),nconstp(*),npc(*),plc(*)
      integer nnpcrv(*)
c     dimension eps(6),sig(6),hsv(6),temps(nlq)
      dimension nbmbwp(*)
      character*(*)eltype
      dimension elsizv(nlq)
      logical failel,failels(nlq),reject
      integer lqfinv8
      integer idelev(nlq),idele
      dimension ncsave(*)
c
c     data temps/nlq*0.0/
      data failels/nlq*.false./
c
c$omp threadprivate (/subtssloc/)
c$omp threadprivate (/soundloc/)
c$omp threadprivate (/bux13loc/)
c$omp threadprivate (/aux35loc/)
c$omp threadprivate (/aux33loc/)
c$omp threadprivate (/aux14loc/)
c$omp threadprivate (/aux2loc/)
c$omp threadprivate (/usermat_vendor/)
      failel=.false.
      reject=.false.
      ivect=ivectr(mt)
      mx=48*(mxt(lft)-1)
c
c     Determining number of requested history variables
c
      no_hsvs=ncsave(mxt(lft))
c
c     if ishrmp(mt).lt.0 then the flag for temperature is active
c     temperatures are stored in the temps array.
c
      if (ishrmp(mt).lt.0) then
        num_nods=2
        call usr_temps (a(ntmp0+1),a(n19),itemp,temps,lft,llt,
     .   ix1,ix2,ix3,ix4,ix4,ix4,ix4,ix4,num_nods,itopaz,0,
     .   0.,0.,0.,itempe(4),ia(nnm1+itempe(8)))
      else
        do i=lft,llt
          temps(i)=0.0
        enddo
      endif
c
c     characteristic element size and element id
      do i=lft,llt
        elsizv(i)=diagm(i)
        ielm=nbmbwp(nnm1+i)
        if (ielm.gt.0) idelev(i)=lqfinv8(ielm,3)
      enddo
c
c     memory pointer for extra memory data
      lcma=ncma+nmmat+ia(ncma+mxt(lft)-1)-1
c
      mte40=mt-40
c
      if (ivect.eq.0) then
        do 120 i=lft,llt
        dt1   =dt1siz(i)
        eps(1)=d1(i)
        eps(2)=d2(i)
        eps(3)=d3(i)
        eps(4)=wxxdt(i)
        eps(5)=wyydt(i)
        eps(6)=wzzdt(i)
        sig(1)=sig1(i)
        sig(2)=sig2(i)
        sig(3)=sig3(i)
        sig(4)=sig4(i)
        sig(5)=sig5(i)
        sig(6)=sig6(i)
        temper=temps(i)
        epsp=epsps(i)
        if (no_hsvs.gt.0) then
          do 20 j=1,no_hsvs
          hsv(j)=hsvs(i,j)
 20       continue
        endif
        elsiz=elsizv(i)
        idele=idelev(i)
c
c       call user developed subroutines here
c
        go to (41,42,43,44,45,46,47,48,49,50), mte40
   41   call umat41 (cm(mx+1),eps,sig,epsp,hsv,dt1,capa,'dbeam',tt,
     1   temper,failel,crv,nnpcrv,a(lcma),0,elsiz,idele,reject)
        go to 60
   42   call umat42 (cm(mx+1),eps,sig,epsp,hsv,dt1,capa,'dbeam',tt,
     1   temper,failel,crv,nnpcrv,a(lcma),0,elsiz,idele,reject)
        go to 60
   43   call umat43 (cm(mx+1),eps,sig,epsp,hsv,dt1,capa,'dbeam',tt,
     1   temper,failel,crv,nnpcrv,a(lcma),0,elsiz,idele,reject)
        go to 60
   44   call umat44 (cm(mx+1),eps,sig,epsp,hsv,dt1,capa,'dbeam',tt,
     1   temper,failel,crv,nnpcrv,a(lcma),0,elsiz,idele,reject)
        go to 60
   45   call umat45 (cm(mx+1),eps,sig,epsp,hsv,dt1,capa,'dbeam',tt,
     1   temper,failel,crv,nnpcrv,a(lcma),0,elsiz,idele,0,reject)
        go to 60
   46   call umat46 (cm(mx+1),eps,sig,epsp,hsv,dt1,capa,'dbeam',tt,
     1   temper,failel,crv,nnpcrv,0.0,0,a(lcma),0,elsiz,idele,reject)
        go to 60
   47   call umat47 (cm(mx+1),eps,sig,epsp,hsv,dt1,capa,'dbeam',tt,
     1   temper,failel,crv,nnpcrv,a(lcma),0,elsiz,idele,reject)
        go to 60
   48   call umat48 (cm(mx+1),eps,sig,epsp,hsv,dt1,capa,'dbeam',tt,
     1   temper,failel,crv,nnpcrv,a(lcma),0,elsiz,idele,reject)
        go to 60
   49   call umat49 (cm(mx+1),eps,sig,epsp,hsv,dt1,capa,'dbeam',tt,
     1   temper,failel,crv,nnpcrv,a(lcma),0,elsiz,idele,reject)
        go to 60
   50   call umat50 (cm(mx+1),eps,sig,epsp,hsv,dt1,capa,'dbeam',tt,
     1   temper,failel,crv,nnpcrv,a(lcma),0,elsiz,idele,reject)
 60     continue
c
        if (no_hsvs.gt.0) then
          do 100 j=1,no_hsvs
          hsvs(i,j)=hsv(j)
 100      continue
        endif
        sig1(i)=sig(1)
        sig2(i)=sig(2)
        sig3(i)=sig(3)
        sig4(i)=sig(4)
        sig5(i)=sig(5)
        sig6(i)=sig(6)
        epsps(i)=epsp
 120  continue
c
c     vector umat
c
      else
        if (ivumat(mt).eq.0) then
        if (mt.eq.41) then
          call umat41v(cm(mx+1),d1,d2,d3,wxxdt,wyydt,wzzdt,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,dt1siz,capa,
     .     'dbeam',tt,temps,failels,nlq,crv,nnpcrv,
     .     a(lcma),0,elsizv,idelev,reject)
        elseif (mt.eq.42) then
          call umat42v(cm(mx+1),d1,d2,d3,wxxdt,wyydt,wzzdt,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,dt1siz,capa,
     .     'dbeam',tt,temps,failels,nlq,crv,nnpcrv,
     .     a(lcma),0,elsizv,idelev,reject)
        elseif (mt.eq.43) then
          call umat43v(cm(mx+1),d1,d2,d3,wxxdt,wyydt,wzzdt,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,dt1siz,capa,
     .     'dbeam',tt,temps,failels,nlq,crv,nnpcrv,
     .     a(lcma),0,elsizv,idelev,reject)
        elseif (mt.eq.44) then
          call umat44v(cm(mx+1),d1,d2,d3,wxxdt,wyydt,wzzdt,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,dt1siz,capa,
     .     'dbeam',tt,temps,failels,nlq,crv,nnpcrv,
     .     a(lcma),0,elsizv,idelev,reject)
        elseif (mt.eq.45) then
          call umat45v(cm(mx+1),d1,d2,d3,wxxdt,wyydt,wzzdt,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,dt1siz,capa,
     .     'dbeam',tt,temps,failels,nlq,crv,nnpcrv,
     .     a(lcma),0,elsizv,idelev,0,reject)
        elseif (mt.eq.46) then
          call umat46v(cm(mx+1),d1,d2,d3,wxxdt,wyydt,wzzdt,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,dt1siz,capa,
     .     'dbeam',tt,temps,failels,nlq,crv,nnpcrv,
     .     a(lcma),0.0,0,0,elsizv,
     .     idelev,reject)
        elseif (mt.eq.47) then
          call umat47v(cm(mx+1),d1,d2,d3,wxxdt,wyydt,wzzdt,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,dt1siz,capa,
     .     'dbeam',tt,temps,failels,nlq,crv,nnpcrv,
     .     a(lcma),0,elsizv,idelev,reject)
        elseif (mt.eq.48) then
          call umat48v(cm(mx+1),d1,d2,d3,wxxdt,wyydt,wzzdt,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,dt1siz,capa,
     .     'dbeam',tt,temps,failels,nlq,crv,nnpcrv,
     .     a(lcma),0,elsizv,idelev,reject,ipt,npc,plc)
        elseif (mt.eq.49) then
          call umat49v(cm(mx+1),d1,d2,d3,wxxdt,wyydt,wzzdt,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,dt1siz,capa,
     .     'dbeam',tt,temps,failels,nlq,crv,nnpcrv,
     .     a(lcma),0,elsizv,idelev,reject,ipt,npc,plc)
        elseif (mt.eq.50) then
          call umat50v(cm(mx+1),d1,d2,d3,wxxdt,wyydt,wzzdt,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,dt1siz,capa,
     .     'dbeam',tt,temps,failels,nlq,crv,nnpcrv,
     .     a(lcma),0,elsizv,idelev,reject)
        endif
        else
c
c       ALL vecumat interfaces are moved to user_vecumat.F
        endif
      endif
c
      do 130 i=lft,llt
      einc(i)=d1(i)*sig1(i)+d4(i)*sig4(i)+d6(i)*sig6(i)+einc(i)
  130 continue
c
c     flag if material model rejected implicit iterate
      if (isolvr(1).ne.0.and.reject) then
         isolvr(78)=5
         ascntl(150)=-1.e32
      endif
c
      return
      end
      subroutine urmatt (lft,llt,cm,capa,mt,crv,nnpcrv,
     $     nnm1,nconstp,npc,plc,
     $     eltype,nbmbwp,ncsave)
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
# 1788 "dyn21umat.F" 2 
      include 'memaia.inc'
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
# 1791 "dyn21umat.F" 2 
# 1 ".\bk13.inc" 1 
      integer lc0,lc1h,lc1b,lc1t,lc2,lc3,lc4,lc5,lc6,lc6e,lc6f,lc9,     
     & lc10,lc11,lc12,lc13,lc14,lc15,lc16,lc17,lc18,lb0,lb1,lb2,        
     & lc7a,lc7b,lc7c,lc7d,lc7e,lc7f,lc7g,lc7h,lc7i,lc7j,lc7k,lc7l,     
     & lc7t,lc7x,lc6g,lc6h
      common/bk13/lc0,lc1h,lc1b,lc1t,lc2,lc3,lc4,lc5,lc6,lc6e,lc6f,lc9, 
     & lc10,lc11,lc12,lc13,lc14,lc15,lc16,lc17,lc18,lb0,lb1,lb2,        
     & lc7a,lc7b,lc7c,lc7d,lc7e,lc7f,lc7g,lc7h,lc7i,lc7j,lc7k,lc7l,     
     & lc7t,lc7x,lc6g,lc6h
# 1792 "dyn21umat.F" 2 
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

# 1793 "dyn21umat.F" 2 
# 1 ".\implicit1.inc" 1 
!   ... implicit common ...
!
      character*80    sc_filename, moddyn_filename, modal_op2_filename, 
     &                rv_filename
      character*10    sc_mass, sc_damp, sc_stiff, sc_inert
      common/bki01ch/ sc_filename, sc_mass, sc_damp, sc_stiff, sc_inert,
     &                moddyn_filename(2), modal_op2_filename,           
     &                rv_filename
!
      integer imauto,iteopt,lauto,mthsol,ilimit,maxref,icnvrg,          
     & igdiv,nwebuf,neql,neqt,imterm,imphas,nbfgs,                      
     & numupd,istif,itrlas,imerr,imdof,neqtgl,ilsmtd,lsdir,ptr_aspc_h,  
     & impcntctl,ipmaxx,igpx,itermp,itermp1,h_lp,h_rd,ptr_rf_data_h,    
     & moddyn_flag, moddyn_mdrange, moddyn_mdlen, moddyn_mdfreq,        
     & moddyn_mdfrqlen, moddyn_aux,                                     
     & mf2_ptrnum_f95, mf2_ptrsym_f95, h_rsvc, im_numnp, mpp_im_numnp,  
     & h_frf
      common/bki01i/imauto,iteopt,lauto,mthsol,ilimit,maxref,icnvrg,    
     & igdiv,nwebuf,neql,neqt,imterm,imphas,nbfgs,                      
     & numupd,istif,itrlas,imerr,imdof,neqtgl,ilsmtd,lsdir,ptr_aspc_h,  
     & impcntctl,ipmaxx,igpx,itermp,itermp1,h_lp,h_rd,ptr_rf_data_h,    
     & moddyn_flag, moddyn_mdrange, moddyn_mdlen, moddyn_mdfreq,        
     & moddyn_mdfrqlen, moddyn_aux(13),                                 
     & mf2_ptrnum_f95, mf2_ptrsym_f95, h_rsvc, im_numnp, mpp_im_numnp,  
     & h_frf
!
      real dtimp,dtimp0,timeim,dtmnim,dtmxim,cvtl,ectl,rctl,            
     & tolls,dnorm2,dtprnt,dtplot,dtiter,dtrefm,ppmax,pmaxr,errord,umax,
     & sumx,xrte,moddyn_valdmp,moddyn_output_time,ctmxs,htmxs,xkei,     
     & tollls,pretim
      common/bki01r/dtimp,dtimp0,timeim,dtmnim,dtmxim,cvtl,ectl,rctl,   
     & tolls,dnorm2,dtprnt(2),dtplot(2),dtiter(2),dtrefm(2),            
     & ppmax,pmaxr,errord,umax,sumx,xrte,moddyn_valdmp,                 
     & moddyn_output_time(2),ctmxs(8),htmxs(8),xkei(-2:2),tollls,pretim
!
      real ascntl,r78tags
      common/bki02r/ascntl(200),r78tags(20)
!
      logical lsensw,jlsmtd
      common/bki01l/lsensw(20),jlsmtd
!
      integer imip,isolvr,icwrb,elem_tbl,i78tags,moddyn_fast,numsmv
      common/bki02i/imip(300),isolvr(500),icwrb(50),elem_tbl(4,65),     
     & i78tags(20),moddyn_fast,numsmv
# 1794 "dyn21umat.F" 2 
# 1 ".\usermat_vendor.inc" 1 
c
      integer user_iform
      character*10 vendor
      common /usermat_vendor/ user_iform,vendor
# 1795 "dyn21umat.F" 2 
      common/aux2loc/d1(nlq),d2(nlq),d3(nlq),d4(nlq),d5(nlq),d6(nlq),
     1 wzzdt(nlq),wyydt(nlq),wxxdt(nlq),einc(nlq)
      common/aux14loc/
     1 sig1(nlq),sig2(nlq),sig3(nlq),sig4(nlq),
     2 sig5(nlq),sig6(nlq),epsps(nlq),hsvs(nlq,NHISVAR)
      common/aux33loc/
     1 ix1(nlq),ix2(nlq),ix3(nlq),ix4(nlq),ix5(nlq),mxt(nlq)
      common/aux35loc/rhoa(nlq),cb(nlq),davg(nlq),p(nlq)
      common/bux13loc/ eps(6),sig(6),hsv(NHISVAR),temps(nlq)
# 1 ".\failcmloc.inc" 1 
c     include this file when failur IS used in element/material routines,
c     or in other words when a loop is multi threaded
      integer ifail
      logical failur,failgl,failst
      common/failcm/failst,failgl
      common/failcmloc/ifail(nlq),failur
# 1813 "dyn21umat.F" 2 
      common/failuloc/sieu(nlq),fail(nlq),ifaili(nlq),nfipts(nlq),
     . msgfail(nlq),def_ele_eros(nlq)
      common/soundloc/ss(nlq),sndsp(nlq),diagm(nlq),sarea(nlq),
     . dxl(nlq)
      common/subtssloc/dt1siz(nlq)
c
      common/bk00/numnp,numpc,numlp,neq,ndof,nlcur,numcl,numvc,
     + ndtpts,nelmd,nmmat,numelh,numelb,numels,numelt,numdp,
     + grvity,idirgv,nodspc,nspcor,nusa
      common/bk01/itherm,itemp,ntmp0,ntmp1,itempan,itempdr,itmpe(14),
     . itempe(10),nthxp,ithxp(19)
      common/bk28/summss,xke,xpe,tt,xte0,erodeke,erodeie
      common/thropt/itopaz(101)
      include 'slcntr.inc'
c
c     real capa
      dimension capa(*),cm(*),crv(lq1,2,*),nconstp(*),npc(*),plc(*)
      integer nnpcrv(*)
c     dimension eps(6),sig(6),hsv(6),temps(nlq)
      character*(*)eltype
      dimension nbmbwp(*)
      dimension elsizv(nlq)
      logical failel,failels(nlq),reject
      integer lqfinv8
      integer idelev(nlq),idele
      dimension ncsave(*)
c
c     data temps/nlq*0.0/
      data failels/nlq*.false./
c
c$omp threadprivate (/failcmloc/)
c$omp threadprivate (/subtssloc/)
c$omp threadprivate (/soundloc/)
c$omp threadprivate (/failuloc/)
c$omp threadprivate (/aux35loc/)
c$omp threadprivate (/bux13loc/)
c$omp threadprivate (/aux33loc/)
c$omp threadprivate (/aux14loc/)
c$omp threadprivate (/aux2loc/)
c$omp threadprivate (/usermat_vendor/)
      reject=.false.
      ivect=ivectr(mt)
      mx=48*(mxt(lft)-1)
      gm=cm(mx+abs(ishrmp(mt)))
      bk=cm(mx+ibulkp(mt))
      ym=9.*bk*gm/(3.*bk+gm)
      ss(lft)=ym
      do 10 i=lft,llt
      einc(i)=d1(i)*sig1(i)
      cb(i)=ss(lft)
      wxxdt(i)=ym
   10 continue
c
c     Determining number of requested history variables
c
      no_hsvs=ncsave(mxt(lft))
c
c     if ishrmp(mt).lt.0 then the flag for temperature is active
c     temperatures are stored in the temps array.
c
      if (ishrmp(mt).lt.0) then
        num_nods=2
        call usr_temps (a(ntmp0+1),a(n19),itemp,temps,lft,llt,
     .   ix1,ix2,ix3,ix4,ix4,ix4,ix4,ix4,num_nods,itopaz,
     .   0,0.,0.,0.,itempe(4),ia(nnm1+itempe(8)))
      else
        do i=lft,llt
          temps(i)=0.0
        enddo
      endif
c
c     characteristic element size
      do i=lft,llt
        elsizv(i)=diagm(i)
        ielm=nbmbwp(nnm1+i)
        if (ielm.gt.0) idelev(i)=lqfinv8(ielm,3)
      enddo
c
c     memory pointer for extra memory data
      lcma=ncma+nmmat+ia(ncma+mxt(lft)-1)-1
c
      mte40=mt-40
c
      if (ivect.eq.0) then
        do 120 i=lft,llt
        dt1   =dt1siz(i)
        eps(1)=d1(i)
        eps(2)=d2(i)
        eps(3)=d3(i)
        sig(1)=sig1(i)
        sig(2)=sig2(i)
        sig(3)=sig3(i)
        epsp=epsps(i)
        temper=temps(i)
        failel=.false.
        if (no_hsvs.gt.0) then
          do 20 j=1,no_hsvs
          hsv(j)=hsvs(i,j)
 20       continue
        endif
        elsiz=elsizv(i)
        idele=idelev(i)
c
c       call user developed subroutines here
c
        go to (41,42,43,44,45,46,47,48,49,50), mte40
   41   call umat41 (cm(mx+1),eps,sig,epsp,hsv,dt1,capa,'tbeam',tt,
     1   temper,failel,crv,nnpcrv,a(lcma),0,elsiz,idele,reject)
        go to 60
   42   call umat42  (cm(mx+1),eps,sig,epsp,hsv,dt1,capa,'tbeam',tt,
     1   temper,failel,crv,nnpcrv,a(lcma),0,elsiz,idele,reject)
        go to 60
   43   call umat43 (cm(mx+1),eps,sig,epsp,hsv,dt1,capa,'tbeam',tt,
     1   temper,failel,crv,nnpcrv,a(lcma),0,elsiz,idele,reject)
        go to 60
   44   call umat44 (cm(mx+1),eps,sig,epsp,hsv,dt1,capa,'tbeam',tt,
     1   temper,failel,crv,nnpcrv,a(lcma),0,elsiz,idele,reject)
        go to 60
   45   call umat45 (cm(mx+1),eps,sig,epsp,hsv,dt1,capa,'tbeam',tt,
     1   temper,failel,crv,nnpcrv,a(lcma),0,elsiz,idele,0,reject)
        go to 60
   46   call umat46 (cm(mx+1),eps,sig,epsp,hsv,dt1,capa,'tbeam',tt,
     1   temper,failel,crv,nnpcrv,a(lcma),0.0,0,0,elsiz,idele,reject)
        go to 60
   47   call umat47 (cm(mx+1),eps,sig,epsp,hsv,dt1,capa,'tbeam',tt,
     1   temper,failel,crv,nnpcrv,a(lcma),0,elsiz,idele,reject)
        go to 60
   48   call umat48 (cm(mx+1),eps,sig,epsp,hsv,dt1,capa,'tbeam',tt,
     1   temper,failel,crv,nnpcrv,a(lcma),0,elsiz,idele,reject)
        go to 60
   49   call umat49 (cm(mx+1),eps,sig,epsp,hsv,dt1,capa,'tbeam',tt,
     1   temper,failel,crv,nnpcrv,a(lcma),0,elsiz,idele,reject)
        go to 60
   50   call umat50 (cm(mx+1),eps,sig,epsp,hsv,dt1,capa,'tbeam',tt,
     1   temper,failel,crv,nnpcrv,a(lcma),0,elsiz,idele,reject)
 60   continue
c
      if (no_hsvs.gt.0) then
        do 100 j=1,no_hsvs
        hsvs(i,j)=hsv(j)
 100   continue
      endif
c
      if (failel) then
        einc(i)=0.
        sig1(i)=0.
        sig2(i)=0.
        sig3(i)=0.
        failur=.true.
        def_ele_eros(i)=0.
        ifail(i)=1
        fail(i)=0.
      else
        sig1(i)=sig(1)
        sig2(i)=sig(2)
        sig3(i)=sig(3)
      endif
      d2(i)  =eps(2)
      d3(i)  =eps(3)
      epsps(i)=epsp
 120  continue
c
c     vector umat
c
      else
        if (ivumat(mt).eq.0) then
        if (mt.eq.41) then
          call umat41v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,dt1siz,capa,
     .     'tbeam',tt,temps,failels,nlq,crv,nnpcrv,
     .     a(lcma),0,elsizv,idelev,reject)
        elseif (mt.eq.42) then
          call umat42v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,dt1siz,capa,
     .     'tbeam',tt,temps,failels,nlq,crv,nnpcrv,
     .     a(lcma),0,elsizv,idelev,reject)
        elseif (mt.eq.43) then
          call umat43v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,dt1siz,capa,
     .     'tbeam',tt,temps,failels,nlq,crv,nnpcrv,
     .     a(lcma),0,elsizv,idelev,reject)
        elseif (mt.eq.44) then
          call umat44v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,dt1siz,capa,
     .     'tbeam',tt,temps,failels,nlq,crv,nnpcrv,
     .     a(lcma),0,elsizv,idelev,reject)
        elseif (mt.eq.45) then
          call umat45v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,dt1siz,capa,
     .     'tbeam',tt,temps,failels,nlq,crv,nnpcrv,
     .     a(lcma),0,elsizv,idelev,0,reject)
        elseif (mt.eq.46) then
          call umat46v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,dt1siz,capa,
     .     'tbeam',tt,temps,failels,nlq,crv,nnpcrv,
     .     a(lcma),0.0,0,0,elsizv,
     .     idelev,reject)
        elseif (mt.eq.47) then
          call umat47v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,dt1siz,capa,
     .     'tbeam',tt,temps,failels,nlq,crv,nnpcrv,
     .     a(lcma),0,elsizv,idelev,reject)
        elseif (mt.eq.48) then
          call umat48v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,dt1siz,capa,
     .     'tbeam',tt,temps,failels,nlq,crv,nnpcrv,
     .     a(lcma),0,elsizv,idelev,reject,ipt,npc,plc)
        elseif (mt.eq.49) then
          call umat49v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,dt1siz,capa,
     .     'tbeam',tt,temps,failels,nlq,crv,nnpcrv,
     .     a(lcma),0,elsizv,idelev,reject,ipt,npc,plc)
        elseif (mt.eq.50) then
          call umat50v(cm(mx+1),d1,d2,d3,d4,d5,d6,sig1,sig2,
     .     sig3,sig4,sig5,sig6,epsps,hsvs,lft,llt,dt1siz,capa,
     .     'tbeam',tt,temps,failels,nlq,crv,nnpcrv,
     .     a(lcma),0,elsizv,idelev,reject)
        endif
        else
c
c       ALL vecumat interfaces are moved to user_vecumat.F
        endif
c
        do i=lft,llt
          if (failels(i)) then
            sig1(i)=0.
            sig2(i)=0.
            sig3(i)=0.
            fail(i)=0.
            ifail(i)=1
            failur=.true.
            def_ele_eros(i)=0.
         endif
        enddo
      endif
c
      do 130 i=lft,llt
      einc(i)=d1(i)*sig1(i)+einc(i)
 130  continue
c
c     flag if material model rejected implicit iterate
      if (isolvr(1).ne.0.and.reject) then
         isolvr(78)=5
         ascntl(150)=-1.e32
      endif
c
      return
      end
      subroutine urmathn(lft,llt,cm,bqs,mt,crv,nnpcrv,npc,plc,nnm1,
     1 rcoor,scoor,tcoor,nconstp,nip,ipt,eltype,nhxbwp,nshbwp,ntsbwp,
     1 ncsave)
      use userinterface
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
# 2066 "dyn21umat.F" 2 
      include 'iounits.inc'
      include 'memaia.inc'
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
# 2070 "dyn21umat.F" 2 
# 1 ".\bk13.inc" 1 
      integer lc0,lc1h,lc1b,lc1t,lc2,lc3,lc4,lc5,lc6,lc6e,lc6f,lc9,     
     & lc10,lc11,lc12,lc13,lc14,lc15,lc16,lc17,lc18,lb0,lb1,lb2,        
     & lc7a,lc7b,lc7c,lc7d,lc7e,lc7f,lc7g,lc7h,lc7i,lc7j,lc7k,lc7l,     
     & lc7t,lc7x,lc6g,lc6h
      common/bk13/lc0,lc1h,lc1b,lc1t,lc2,lc3,lc4,lc5,lc6,lc6e,lc6f,lc9, 
     & lc10,lc11,lc12,lc13,lc14,lc15,lc16,lc17,lc18,lb0,lb1,lb2,        
     & lc7a,lc7b,lc7c,lc7d,lc7e,lc7f,lc7g,lc7h,lc7i,lc7j,lc7k,lc7l,     
     & lc7t,lc7x,lc6g,lc6h
# 2071 "dyn21umat.F" 2 
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

# 2072 "dyn21umat.F" 2 
# 1 ".\implicit1.inc" 1 
!   ... implicit common ...
!
      character*80    sc_filename, moddyn_filename, modal_op2_filename, 
     &                rv_filename
      character*10    sc_mass, sc_damp, sc_stiff, sc_inert
      common/bki01ch/ sc_filename, sc_mass, sc_damp, sc_stiff, sc_inert,
     &                moddyn_filename(2), modal_op2_filename,           
     &                rv_filename
!
      integer imauto,iteopt,lauto,mthsol,ilimit,maxref,icnvrg,          
     & igdiv,nwebuf,neql,neqt,imterm,imphas,nbfgs,                      
     & numupd,istif,itrlas,imerr,imdof,neqtgl,ilsmtd,lsdir,ptr_aspc_h,  
     & impcntctl,ipmaxx,igpx,itermp,itermp1,h_lp,h_rd,ptr_rf_data_h,    
     & moddyn_flag, moddyn_mdrange, moddyn_mdlen, moddyn_mdfreq,        
     & moddyn_mdfrqlen, moddyn_aux,                                     
     & mf2_ptrnum_f95, mf2_ptrsym_f95, h_rsvc, im_numnp, mpp_im_numnp,  
     & h_frf
      common/bki01i/imauto,iteopt,lauto,mthsol,ilimit,maxref,icnvrg,    
     & igdiv,nwebuf,neql,neqt,imterm,imphas,nbfgs,                      
     & numupd,istif,itrlas,imerr,imdof,neqtgl,ilsmtd,lsdir,ptr_aspc_h,  
     & impcntctl,ipmaxx,igpx,itermp,itermp1,h_lp,h_rd,ptr_rf_data_h,    
     & moddyn_flag, moddyn_mdrange, moddyn_mdlen, moddyn_mdfreq,        
     & moddyn_mdfrqlen, moddyn_aux(13),                                 
     & mf2_ptrnum_f95, mf2_ptrsym_f95, h_rsvc, im_numnp, mpp_im_numnp,  
     & h_frf
!
      real dtimp,dtimp0,timeim,dtmnim,dtmxim,cvtl,ectl,rctl,            
     & tolls,dnorm2,dtprnt,dtplot,dtiter,dtrefm,ppmax,pmaxr,errord,umax,
     & sumx,xrte,moddyn_valdmp,moddyn_output_time,ctmxs,htmxs,xkei,     
     & tollls,pretim
      common/bki01r/dtimp,dtimp0,timeim,dtmnim,dtmxim,cvtl,ectl,rctl,   
     & tolls,dnorm2,dtprnt(2),dtplot(2),dtiter(2),dtrefm(2),            
     & ppmax,pmaxr,errord,umax,sumx,xrte,moddyn_valdmp,                 
     & moddyn_output_time(2),ctmxs(8),htmxs(8),xkei(-2:2),tollls,pretim
!
      real ascntl,r78tags
      common/bki02r/ascntl(200),r78tags(20)
!
      logical lsensw,jlsmtd
      common/bki01l/lsensw(20),jlsmtd
!
      integer imip,isolvr,icwrb,elem_tbl,i78tags,moddyn_fast,numsmv
      common/bki02i/imip(300),isolvr(500),icwrb(50),elem_tbl(4,65),     
     & i78tags(20),moddyn_fast,numsmv
# 2073 "dyn21umat.F" 2 
# 1 ".\usermat_vendor.inc" 1 
c
      integer user_iform
      character*10 vendor
      common /usermat_vendor/ user_iform,vendor
# 2074 "dyn21umat.F" 2 
      parameter (MXPOL=9)
      parameter (MXPOL3=(MXPOL+1)*(MXPOL+1)*(MXPOL+1))
      common/bux13loc/ eps(6),sig(6),hsv(NHISVAR),temps(nlq)
      common/aux14loc/sig1(nlq),sig2(nlq),sig3(nlq),sig4(nlq),sig5(nlq),
     & sig6(nlq),epsps(nlq),hsvs(nlq,NHISVAR)
      common/aux16cntloc/idmgmdl
      common/aux18loc/dd(nlq),def(nlq),ddq(nlq)
      common/aux2loc/d1(nlq),d2(nlq),d3(nlq),d4(nlq),d5(nlq),d6(nlq),
     1 wzzdt(nlq),wyydt(nlq),wxxdt(nlq),einc(nlq)
      common/aux33loc/ix1(nlq),ix2(nlq),ix3(nlq),ix4(nlq),ix5(nlq),
     1 ix6(nlq),ix7(nlq),ix8(nlq),mxt(nlq)
      common/aux34loc/xioff(nlq),dx(nlq)
      common/aux35loc/rhoa(nlq),cb(nlq),davg(nlq),p(nlq)
      common/aux40loc/
     1 a11(nlq),a12(nlq),a13(nlq),a21(nlq),a22(nlq),a23(nlq),
     2 a31(nlq),a32(nlq),a33(nlq),z11(nlq),z12(nlq),z13(nlq),
     3 z21(nlq),z22(nlq),z23(nlq),z31(nlq),z32(nlq),z33(nlq)
      common/aux41loc/qq1(nlq),cbb(nlq),aj1(nlq)
      common/bk00/numnp,numpc,numlp,neq,ndof,nlcur,numcl,numvc,
     + ndtpts,nelmd,nmmat,numelh,numelb,numels,numelt,numdp,
     + grvity,idirgv,nodspc,nspcor,nusa
      common/bk36loc/index
      common/soundloc/ss(nlq),sndsp(nlq),diagm(nlq),sarea(nlq),
     . dxl(nlq)
      common/subtssloc/dt1siz(nlq)
      common/vect32loc/g11(nlq),g21(nlq),g31(nlq),g12(nlq),g22(nlq),
     .     g32(nlq),g13(nlq),g23(nlq),g33(nlq),ifg(nlq)
c
      common/bk01/itherm,itemp,ntmp0,ntmp1,itempan,itempdr,itmpe(14),
     . itempe(10),nthxp,ithxp(19)
      common/bk26/begtim,nintcy
      common/bk28/summss,xke,xpe,tt,xte0,erodeke,erodeie
# 1 ".\failcmloc.inc" 1 
c     include this file when failur IS used in element/material routines,
c     or in other words when a loop is multi threaded
      integer ifail
      logical failur,failgl,failst
      common/failcm/failst,failgl
      common/failcmloc/ifail(nlq),failur
# 2123 "dyn21umat.F" 2 
      common/failuloc/sieu(nlq),fail(nlq),ifaili(nlq),nfipts(nlq),
     . msgfail(nlq),def_ele_eros(nlq)
      common/numcpu/ncpu,ncpua,ncpub,lenvec(9)
      include 'shlopt.inc'
      common/thropt/itopaz(101)
      real dndsl(nlq,3,MXPOL3),xiga(nlq,3,MXPOL3)
      pointer (ipdndsl,dndsl),(ipxl,xiga)
      common/igamatloc/nmnp,nmnp2,ipdndsl,ipxl
      common/alecom3/iale_dummy(44),iale_mt41skpinc
c
      dimension cm(*),bqs(*),crv(lq1,2,*),npc(*),plc(*),nconstp(*)
      integer nnpcrv(*)
      character*(*) eltype
      dimension nhxbwp(*),nshbwp(*),ntsbwp(*)
c     dimension eps(6),sig(6),hsv(NHISVAR),temps(nlq)
      dimension q21(nlq),q22(nlq),q23(nlq)
      dimension thhsv(nlq,100),thhsvi(100)
      dimension elsizv(nlq),dloc(nlq,6)
      integer idelev(nlq),idele
c
      real mlt1,mlt2
      real auxvar1(nlq),auxvar2(nlq)
      logical failel,failels(nlq),reject
      integer lqfinv8,lqfmiv8
      real*8, pointer,contiguous :: dm_x(:)
      dimension ncsave(*)
c     data temps/nlq*0.0/
c
c$omp threadprivate (/failcmloc/)
c$omp threadprivate (/igamatloc/)
c$omp threadprivate (/bux13loc/)
c$omp threadprivate (/vect32loc/)
c$omp threadprivate (/subtssloc/)
c$omp threadprivate (/soundloc/)
c$omp threadprivate (/failuloc/)
c$omp threadprivate (/bk36loc/)
c$omp threadprivate (/aux41loc/)
c$omp threadprivate (/aux40loc/)
c$omp threadprivate (/aux35loc/)
c$omp threadprivate (/aux34loc/)
c$omp threadprivate (/aux33loc/)
c$omp threadprivate (/aux18loc/)
c$omp threadprivate (/aux16cntloc/)
c$omp threadprivate (/aux14loc/)
c$omp threadprivate (/aux2loc/)
c$omp threadprivate (/usermat_vendor/)
      capa=0.0
c
c     Processing elements
c
      mx=48*(mxt(lft)-1)
      gm=cm(mx+abs(ishrmp(mt)))
      bk=cm(mx+ibulkp(mt))
      ss(lft)=bk+4.*gm/3.
c
c     Energy calculations
c
      do 20 i=lft,llt
         cb(i)=ss(lft)
         einc(i)=(d1(i)*sig1(i)+d2(i)*sig2(i)+d3(i)*sig3(i)+
     .        d4(i)*sig4(i)+d5(i)*sig5(i)+
     .        d6(i)*sig6(i)+dd(i)*bqs(i))*dt1siz(i)
 20   continue
c
c     Determining number of requested history variables
c
      no_hsvs=ncsave(mxt(lft))
      
c     Initialization of indeces
c
      if(ivumat(mt).ne.0) then
         
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
         ind_vumat=ind_last+1
         ind_last=ind_vumat+9+6-1
c        ind_last=ind_last+1
         
      else
         
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
         
      endif
c
      if (ind_last.gt.NHISVAR) then
         ierdat(1)=lqfmiv8(mxt(lft))
         call lsmsg(3,MSG_SOL+1149,ioall,ierdat,rerdat,cerdat,0)
      endif
c
c$$$      if (tt.eq.begtim.and.nintcy.eq.0) then
c$$$c
c$$$c       move transformation matrix in history variables array
c$$$c
c$$$        if (iorien(mt).ne.0) then
c$$$          do i=lft,llt
c$$$            hsvs(i,ind_q33)=hsvs(i,6)
c$$$            hsvs(i,ind_q32)=hsvs(i,5)
c$$$            hsvs(i,ind_q31)=hsvs(i,4)
c$$$            hsvs(i,ind_q13)=hsvs(i,3)
c$$$            hsvs(i,ind_q12)=hsvs(i,2)
c$$$            hsvs(i,ind_q11)=hsvs(i,1)
c$$$          enddo
c$$$c
c$$$          if (no_hsvs.gt.0) then
c$$$            do j=1,no_hsvs
c$$$              do i=lft,llt
c$$$                hsvs(i,j)=0.0
c$$$              enddo
c$$$            enddo
c$$$          endif
c$$$        endif
c$$$      endif
c
      if (ipt.eq.1.and.ifipts(mt).ne.0) then
         do i=lft,llt
            nfipts(i)=0
         enddo
      endif
c
c     Storage of deformation gradient
c
      if (ivumat(mt).ne.0) then
         ifo11=ind_vumat
         ifo21=ind_vumat+1
         ifo31=ind_vumat+2
         ifo12=ind_vumat+3
         ifo22=ind_vumat+4
         ifo32=ind_vumat+5
         ifo13=ind_vumat+6
         ifo23=ind_vumat+7
         ifo33=ind_vumat+8
      endif
      
      if (ihyper(mt).ne.0) then
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
c        Deformation gradient in global system at time = 0
c
         if (tt.eq.begtim.and.nintcy.eq.0) then
            do i=lft,llt
               hsvs(i,if11)=1.0
               hsvs(i,if21)=0.0
               hsvs(i,if31)=0.0
               hsvs(i,if12)=0.0
               hsvs(i,if22)=1.0
               hsvs(i,if32)=0.0
               hsvs(i,if13)=0.0
               hsvs(i,if23)=0.0
               hsvs(i,if33)=1.0
            enddo
            if (ivumat(mt).ne.0) then
               do i=lft,llt
                  hsvs(i,ifo11)=1.0
                  hsvs(i,ifo21)=0.0
                  hsvs(i,ifo31)=0.0
                  hsvs(i,ifo12)=0.0
                  hsvs(i,ifo22)=1.0
                  hsvs(i,ifo32)=0.0
                  hsvs(i,ifo13)=0.0
                  hsvs(i,ifo23)=0.0
                  hsvs(i,ifo33)=1.0
               enddo
            endif
         endif
c
c        Deformation gradient calculated exactly
c
         if (ifg(lft).eq.1) then
            do i=lft,llt
               hsvs(i,if11)=g11(i)
               hsvs(i,if21)=g21(i)
               hsvs(i,if31)=g31(i)
               hsvs(i,if12)=g12(i)
               hsvs(i,if22)=g22(i)
               hsvs(i,if32)=g32(i)
               hsvs(i,if13)=g13(i)
               hsvs(i,if23)=g23(i)
               hsvs(i,if33)=g33(i)
            enddo
c
c           Update deformation gradient incrementally in global system
c           at time = n+1
c
         else
            
            call integf(hsvs(1,if11),hsvs(1,if21),hsvs(1,if31),
     &           hsvs(1,if12),hsvs(1,if22),hsvs(1,if32),
     &           hsvs(1,if13),hsvs(1,if23),hsvs(1,if33),lft,llt)
         endif
         
      endif
c
c     Set up transformation matrix Z
c
      if (iorien(mt).ne.0) then
c
c        Set up global to element transformation matrix A
         if (ihyper(mt).ge.0.and.eltype.ne.'tshel'.and.
     1                           eltype.ne.'sldco') then
            if (eltype.eq.'IGAsolid') then
              if (idmgmdl.gt.1000) goto 15
              call lcsm22ih(lft,llt,nmnp,xiga,dndsl)
            elseif (eltype.ne.'sld2d'.and.eltype.ne.'sldax') then
               if (idmgmdl.gt.1000) goto 15
               call lcsm22(lft,llt)
            else
               call cs2d_g2l(lft,llt)
            endif
         endif
c
c        Set up element to material transformation matrix Q
         do 10 i=lft,llt
            q21(i)=hsvs(i,ind_q32)*hsvs(i,ind_q13)-
     1           hsvs(i,ind_q12)*hsvs(i,ind_q33)
            q22(i)=hsvs(i,ind_q33)*hsvs(i,ind_q11)-
     1           hsvs(i,ind_q13)*hsvs(i,ind_q31)
            q23(i)=hsvs(i,ind_q31)*hsvs(i,ind_q12)-
     1           hsvs(i,ind_q11)*hsvs(i,ind_q32)
 10      continue
c
c        Set up global to material transformation matrix Z=Q*A at time t
         if (ihyper(mt).ge.0) then
            if (eltype.ne.'tshel'.and.eltype.ne.'sldco') then
               do i=lft,llt
                  z11(i)=a11(i)*hsvs(i,ind_q11)+a21(i)*hsvs(i,ind_q12)+
     1                 a31(i)*hsvs(i,ind_q13)
                  z12(i)=a12(i)*hsvs(i,ind_q11)+a22(i)*hsvs(i,ind_q12)+
     1                 a32(i)*hsvs(i,ind_q13)
                  z13(i)=a13(i)*hsvs(i,ind_q11)+a23(i)*hsvs(i,ind_q12)+
     1                 a33(i)*hsvs(i,ind_q13)
                  z21(i)=a11(i)*q21(i)+a21(i)*q22(i)+a31(i)*q23(i)
                  z22(i)=a12(i)*q21(i)+a22(i)*q22(i)+a32(i)*q23(i)
                  z23(i)=a13(i)*q21(i)+a23(i)*q22(i)+a33(i)*q23(i)
                  z31(i)=a11(i)*hsvs(i,ind_q31)+a21(i)*hsvs(i,ind_q32)+
     1                 a31(i)*hsvs(i,ind_q33)
                  z32(i)=a12(i)*hsvs(i,ind_q31)+a22(i)*hsvs(i,ind_q32)+
     1                 a32(i)*hsvs(i,ind_q33)
                  z33(i)=a13(i)*hsvs(i,ind_q31)+a23(i)*hsvs(i,ind_q32)+
     1                 a33(i)*hsvs(i,ind_q33)
               enddo
            else
               do i=lft,llt
                  z11(i)=hsvs(i,ind_q11)
                  z12(i)=hsvs(i,ind_q12)
                  z13(i)=hsvs(i,ind_q13)
                  z21(i)=q21(i)
                  z22(i)=q22(i)
                  z23(i)=q23(i)
                  z31(i)=hsvs(i,ind_q31)
                  z32(i)=hsvs(i,ind_q32)
                  z33(i)=hsvs(i,ind_q33)
               enddo
            endif
c
c           Transform stresses and strains to local system
            call ldsm22(lft,llt)
            call ldem22(lft,llt)
c
         elseif (ihyper(mt).lt.0) then
c
            if (tt.eq.begtim.and.nintcy.eq.0) then
c
c              Set up global to material transformation matrix Z=QA at t=0
               if (eltype.ne.'tshel'.and.eltype.ne.'sldco') then
c
c                 Set up global to element transformation matrix A
                  if (eltype.eq.'IGAsolid') then
                    call lcsm22ih(lft,llt,nmnp,xiga,dndsl)
                  elseif (eltype.ne.'sld2d'.and.eltype.ne.'sldax'.and.
     1                 eltype.ne.'shl_t') then
                     call lcsm22(lft,llt)
                  elseif (eltype.ne.'shl_t') then
                     call cs2d_g2l(lft,llt)
                  else
                     do i=lft,llt
                        a11(i)=1.
                        a12(i)=0.
                        a13(i)=0.
                        a21(i)=0.
                        a22(i)=1.
                        a23(i)=0.
                        a31(i)=0.
                        a32(i)=0.
                        a33(i)=1.
                     enddo
                  endif
                  do i=lft,llt
                     z11(i)=a11(i)*hsvs(i,ind_q11)+a21(i)*hsvs(i
     $                    ,ind_q12)+a31(i)*hsvs(i,ind_q13)
                     z12(i)=a12(i)*hsvs(i,ind_q11)+a22(i)*hsvs(i
     $                    ,ind_q12)+a32(i)*hsvs(i,ind_q13)
                     z13(i)=a13(i)*hsvs(i,ind_q11)+a23(i)*hsvs(i
     $                    ,ind_q12)+a33(i)*hsvs(i,ind_q13)
                     z21(i)=a11(i)*q21(i)+a21(i)*q22(i)+a31(i)*q23(i)
                     z22(i)=a12(i)*q21(i)+a22(i)*q22(i)+a32(i)*q23(i)
                     z23(i)=a13(i)*q21(i)+a23(i)*q22(i)+a33(i)*q23(i)
                     z31(i)=a11(i)*hsvs(i,ind_q31)+a21(i)*hsvs(i
     $                    ,ind_q32)+a31(i)*hsvs(i,ind_q33)
                     z32(i)=a12(i)*hsvs(i,ind_q31)+a22(i)*hsvs(i
     $                    ,ind_q32)+a32(i)*hsvs(i,ind_q33)
                     z33(i)=a13(i)*hsvs(i,ind_q31)+a23(i)*hsvs(i
     $                    ,ind_q32)+a33(i)*hsvs(i,ind_q33)
                  enddo
                  
               else
                  
                  do i=lft,llt
                     z11(i)=hsvs(i,ind_q11)
                     z12(i)=hsvs(i,ind_q12)
                     z13(i)=hsvs(i,ind_q13)
                     z21(i)=q21(i)
                     z22(i)=q22(i)
                     z23(i)=q23(i)
                     z31(i)=hsvs(i,ind_q31)
                     z32(i)=hsvs(i,ind_q32)
                     z33(i)=hsvs(i,ind_q33)
                  enddo
                  
               endif
c
c              Store correct transformation used for transforming
c              the deformation gradient at t=0
c
               do i=lft,llt
                  hsvs(i,ind_qstore  )=hsvs(i,ind_q11)
                  hsvs(i,ind_qstore+1)=hsvs(i,ind_q12)
                  hsvs(i,ind_qstore+2)=hsvs(i,ind_q13)
                  hsvs(i,ind_qstore+3)=hsvs(i,ind_q31)
                  hsvs(i,ind_qstore+4)=hsvs(i,ind_q32)
                  hsvs(i,ind_qstore+5)=hsvs(i,ind_q33)
                  hsvs(i,ind_q11)=z11(i)
                  hsvs(i,ind_q12)=z12(i)
                  hsvs(i,ind_q13)=z13(i)
                  hsvs(i,ind_q31)=z31(i)
                  hsvs(i,ind_q32)=z32(i)
                  hsvs(i,ind_q33)=z33(i)
               enddo
c
c           Set up element to material transformation matrix Z at t>0
            else
               do i=lft,llt
                  z11(i)=hsvs(i,ind_q11)
                  z12(i)=hsvs(i,ind_q12)
                  z13(i)=hsvs(i,ind_q13)
                  z21(i)=q21(i)
                  z22(i)=q22(i)
                  z23(i)=q23(i)
                  z31(i)=hsvs(i,ind_q31)
                  z32(i)=hsvs(i,ind_q32)
                  z33(i)=hsvs(i,ind_q33)
               enddo
               
            endif
         endif
c
  15     continue
c
c        Transform deformation gradient to desired system
c
c
c        Deformation gradient transformed to local system
c        as F_bar=Z(t)^T*F
c
         if (ihyper(mt).gt.0) then
            do i=lft,llt
               f1=z11(i)*hsvs(i,if11)+
     1              z12(i)*hsvs(i,if21)+z13(i)*hsvs(i,if31)
               f2=z21(i)*hsvs(i,if11)+
     1              z22(i)*hsvs(i,if21)+z23(i)*hsvs(i,if31)
               hsvs(i,if31)=z31(i)*hsvs(i,if11)+
     1              z32(i)*hsvs(i,if21)+z33(i)*hsvs(i,if31)
               hsvs(i,if11)=f1
               hsvs(i,if21)=f2
               f1=z11(i)*hsvs(i,if12)+
     1              z12(i)*hsvs(i,if22)+z13(i)*hsvs(i,if32)
               f2=z21(i)*hsvs(i,if12)+
     1              z22(i)*hsvs(i,if22)+z23(i)*hsvs(i,if32)
               hsvs(i,if32)=z31(i)*hsvs(i,if12)+
     1              z32(i)*hsvs(i,if22)+z33(i)*hsvs(i,if32)
               hsvs(i,if12)=f1
               hsvs(i,if22)=f2
               f1=z11(i)*hsvs(i,if13)+
     1              z12(i)*hsvs(i,if23)+z13(i)*hsvs(i,if33)
               f2=z21(i)*hsvs(i,if13)+
     1              z22(i)*hsvs(i,if23)+z23(i)*hsvs(i,if33)
               hsvs(i,if33)=z31(i)*hsvs(i,if13)+
     1              z32(i)*hsvs(i,if23)+z33(i)*hsvs(i,if33)
               hsvs(i,if13)=f1
               hsvs(i,if23)=f2
            enddo
c
c        Deformation gradient transformed to local system
c        as F_bar=F*Z(0)
c
         else if (ihyper(mt).eq.-1) then
            do i=lft,llt
               f1=z11(i)*hsvs(i,if11)+
     1              z12(i)*hsvs(i,if12)+z13(i)*hsvs(i,if13)
               f2=z21(i)*hsvs(i,if11)+
     1              z22(i)*hsvs(i,if12)+z23(i)*hsvs(i,if13)
               hsvs(i,if13)=z31(i)*hsvs(i,if11)+
     1              z32(i)*hsvs(i,if12)+z33(i)*hsvs(i,if13)
               hsvs(i,if11)=f1
               hsvs(i,if12)=f2
               f1=z11(i)*hsvs(i,if21)+
     1              z12(i)*hsvs(i,if22)+z13(i)*hsvs(i,if23)
               f2=z21(i)*hsvs(i,if21)+
     1              z22(i)*hsvs(i,if22)+z23(i)*hsvs(i,if23)
               hsvs(i,if23)=z31(i)*hsvs(i,if21)+
     1              z32(i)*hsvs(i,if22)+z33(i)*hsvs(i,if23)
               hsvs(i,if21)=f1
               hsvs(i,if22)=f2
               f1=z11(i)*hsvs(i,if31)+
     1              z12(i)*hsvs(i,if32)+z13(i)*hsvs(i,if33)
               f2=z21(i)*hsvs(i,if31)+
     1              z22(i)*hsvs(i,if32)+z23(i)*hsvs(i,if33)
               hsvs(i,if33)=z31(i)*hsvs(i,if31)+
     1              z32(i)*hsvs(i,if32)+z33(i)*hsvs(i,if33)
               hsvs(i,if31)=f1
               hsvs(i,if32)=f2
            enddo
c           Also transform old deformation gradient in new vumat
c           implementation
            if (ivumat(mt).eq.2) then
               do i=lft,llt
                  f1=z11(i)*hsvs(i,ifo11)+
     1                 z12(i)*hsvs(i,ifo12)+z13(i)*hsvs(i,ifo13)
                  f2=z21(i)*hsvs(i,ifo11)+
     1                 z22(i)*hsvs(i,ifo12)+z23(i)*hsvs(i,ifo13)
                  hsvs(i,ifo13)=z31(i)*hsvs(i,ifo11)+
     1                 z32(i)*hsvs(i,ifo12)+z33(i)*hsvs(i,ifo13)
                  hsvs(i,ifo11)=f1
                  hsvs(i,ifo12)=f2
                  f1=z11(i)*hsvs(i,ifo21)+
     1                 z12(i)*hsvs(i,ifo22)+z13(i)*hsvs(i,ifo23)
                  f2=z21(i)*hsvs(i,ifo21)+
     1                 z22(i)*hsvs(i,ifo22)+z23(i)*hsvs(i,ifo23)
                  hsvs(i,ifo23)=z31(i)*hsvs(i,ifo21)+
     1                 z32(i)*hsvs(i,ifo22)+z33(i)*hsvs(i,ifo23)
                  hsvs(i,ifo21)=f1
                  hsvs(i,ifo22)=f2
                  f1=z11(i)*hsvs(i,ifo31)+
     1                 z12(i)*hsvs(i,ifo32)+z13(i)*hsvs(i,ifo33)
                  f2=z21(i)*hsvs(i,ifo31)+
     1                 z22(i)*hsvs(i,ifo32)+z23(i)*hsvs(i,ifo33)
                  hsvs(i,ifo33)=z31(i)*hsvs(i,ifo31)+
     1                 z32(i)*hsvs(i,ifo32)+z33(i)*hsvs(i,ifo33)
                  hsvs(i,ifo31)=f1
                  hsvs(i,ifo32)=f2
               enddo
            endif
c
c        Deformation gradient transformed to co-rotated coordinate system
c        as F_bar=Z(t)^T*F*Z(0) (suggested by Richard Hamm, P&G 2011)
c
         else if (ihyper(mt).eq.-2) then
            do i=lft,llt
               f11=z11(i)*hsvs(i,if11)+
     1              z12(i)*hsvs(i,if21)+z13(i)*hsvs(i,if31)
               f21=z21(i)*hsvs(i,if11)+
     1              z22(i)*hsvs(i,if21)+z23(i)*hsvs(i,if31)
               f31=z31(i)*hsvs(i,if11)+
     1              z32(i)*hsvs(i,if21)+z33(i)*hsvs(i,if31)
               f12=z11(i)*hsvs(i,if12)+
     1              z12(i)*hsvs(i,if22)+z13(i)*hsvs(i,if32)
               f22=z21(i)*hsvs(i,if12)+
     1              z22(i)*hsvs(i,if22)+z23(i)*hsvs(i,if32)
               f32=z31(i)*hsvs(i,if12)+
     1              z32(i)*hsvs(i,if22)+z33(i)*hsvs(i,if32)
               f13=z11(i)*hsvs(i,if13)+
     1              z12(i)*hsvs(i,if23)+z13(i)*hsvs(i,if33)
               f23=z21(i)*hsvs(i,if13)+
     1              z22(i)*hsvs(i,if23)+z23(i)*hsvs(i,if33)
               f33=z31(i)*hsvs(i,if13)+
     1              z32(i)*hsvs(i,if23)+z33(i)*hsvs(i,if33)
               hsvs(i,if11)=f11*z11(i)+f12*z12(i)+f13*z13(i)
               hsvs(i,if12)=f11*z21(i)+f12*z22(i)+f13*z23(i)
               hsvs(i,if13)=f11*z31(i)+f12*z32(i)+f13*z33(i)
               hsvs(i,if21)=f21*z11(i)+f22*z12(i)+f23*z13(i)
               hsvs(i,if22)=f21*z21(i)+f22*z22(i)+f23*z23(i)
               hsvs(i,if23)=f21*z31(i)+f22*z32(i)+f23*z33(i)
               hsvs(i,if31)=f31*z11(i)+f32*z12(i)+f33*z13(i)
               hsvs(i,if32)=f31*z21(i)+f32*z22(i)+f33*z23(i)
               hsvs(i,if33)=f31*z31(i)+f32*z32(i)+f33*z33(i)
            enddo
         endif
         
c     End of transformation
      endif
      
c
c     If ishrmp(mt).lt.0 then the flag for temperature is active
c     temperatures are stored in the temps array.
c
      num_nods=8
      if (eltype.eq.'shl_t') num_nods=4
      if (eltype.eq.'sld2d'.or.eltype.eq.'sldax') num_nods=4
      if (ishrmp(mt).lt.0) then
        if (eltype.eq.'solid') then
          call usr_temps (a(ntmp0+1),a(n19),itemp,temps,lft,llt,ix1,ix2,
     .        ix3,ix4,ix5,ix6,ix7,ix8,num_nods,itopaz,0,0.,0.,0.,
     .        itempe(3),ia(nnm1+itempe(7)))
        elseif (eltype.eq.'tshel'.or.eltype.eq.'sldco') then
          call usr_temps (a(ntmp0+1),a(n19),itemp,temps,lft,llt,ix1,ix2,
     .        ix3,ix4,ix5,ix6,ix7,ix8,num_nods,itopaz,0,0.,0.,0.,
     .        itempe(6),ia(nnm1+itempe(10)))
        elseif (eltype.eq.'sph  ') then
          call usr_tempsph (a(ntmp0+1),a(n19),itemp,temps,lft,llt,nnm1,
     .        nhxbwp,itopaz)
        else  
          call usr_temps (a(ntmp0+1),a(n19),itemp,temps,lft,llt,ix1,ix2,
     .        ix3,ix4,ix5,ix6,ix7,ix8,num_nods,itopaz,0,0.,0.,0.,
     .        0,ia(nnm1+itempe(7)))
        endif
      else
         do i=lft,llt
            temps(i)=0.0
         enddo
      endif
c
c     Store rates
      do i=lft,llt
        dloc(i,1)=d1(i)
        dloc(i,2)=d2(i)
        dloc(i,3)=d3(i)
        dloc(i,4)=d4(i)
        dloc(i,5)=d5(i)
        dloc(i,6)=d6(i)
      enddo
c
c     Convert rates to increments
c
      if (iale_mt41skpinc.ge.0) then
      iale_mt41skpinc=-iale_mt41skpinc
      do i=lft,llt
         d1(i)=d1(i)*dt1siz(i)
         d2(i)=d2(i)*dt1siz(i)
         if (eltype.eq.'sld2d') then
            d3(i)=0.0
         else
            d3(i)=d3(i)*dt1siz(i)
         endif
         d4(i)=d4(i)*dt1siz(i)
         d5(i)=d5(i)*dt1siz(i)
         d6(i)=d6(i)*dt1siz(i)
      enddo
      endif
c
c     Get thermal history variables from thermal
c     user material
c
      if (eltype.eq.'sph  ') then
c     currently no support of thermal user material for sph
      else
      call get_thhsv(nthhsv,thhsv,itemp,lft,llt,
     1     num_nods,itopaz,nnm1,rcoor,scoor,tcoor)
      endif
c
c     Characteristic element size
      do i=lft,llt
         elsizv(i)=dx(i)
      enddo
c
c     Element id
      if (eltype.eq.'shl_t'.or.eltype.eq.'sld2d'.or.
     &     eltype.eq.'sldax') then
         do i=lft,llt
            ielm=nshbwp(nnm1+i)
            if (ielm.gt.0) idelev(i)=lqfinv8(ielm,4)
         enddo
      elseif (eltype.eq.'tshel') then
         do i=lft,llt
            ielm=ntsbwp(nnm1+i)
            if (ielm.gt.0) idelev(i)=lqfinv8(ielm,5)
         enddo
      elseif (eltype.eq.'sph  ') then
         do i=lft,llt
            ielm=nhxbwp(nnm1+i)
            if (ielm.gt.0) idelev(i)=lqfinv8(ielm,1)
         enddo
      elseif (eltype.eq.'IGAsolid') then
         do i=lft,llt
            idelev(i)=lqfinv8(nnm1+i,1)
         enddo
      else
         do i=lft,llt
            ielm=nhxbwp(nnm1+i)
            if (ielm.gt.0) idelev(i)=lqfinv8(ielm,2)
         enddo
      endif
c
c     Memory pointer for extra memory data
      lcma=ncma+nmmat+ia(ncma+mxt(lft)-1)-1
c
c     Vector parameter
      ivect=ivectr(mt)
c
c     Implicit rejection flag
      reject=.false.
c
      mte40=mt-40
c
c     Scalar/vector umat
c
      if (ivect.eq.0) then
c
c        Scalar umat
c
         do 90 i=lft,llt
c
c           Gathering of variables
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
 30            continue
            endif
            if (ihyper(mt).ne.0) then
               do 40 j=1,9
                  hsv(no_hsvs+j)=hsvs(i,ind_defgrad-1+j)
 40            continue
            endif
            if (nthhsv.gt.0) then
               do j=1,nthhsv
                  thhsvi(j)=thhsv(i,j)
               enddo
            endif
            elsiz=elsizv(i)
            idele=idelev(i)
c
c           Call user developed subroutines here
c
            go to (41,42,43,44,45,46,47,48,49,50), mte40
 41         call umat41 (cm(mx+1),eps,sig,epsp,hsv,dt1,
     1           capa,eltype,tt,temper,failel,crv,nnpcrv,a(lcma),0,elsiz
     2           ,idele,reject)
            go to 60
 42         call umat42 (cm(mx+1),eps,sig,epsp,hsv,dt1,
     1           capa,eltype,tt,temper,failel,crv,nnpcrv,a(lcma),0,elsiz
     2           ,idele,reject)
            go to 60
 43         call umat43 (cm(mx+1),eps,sig,epsp,hsv,dt1,
     1           capa,eltype,tt,temper,failel,crv,nnpcrv,a(lcma),0,elsiz
     2           ,idele,reject)
            go to 60
 44         call umat44 (cm(mx+1),eps,sig,epsp,hsv,dt1,
     1           capa,eltype,tt,temper,failel,crv,nnpcrv,a(lcma),0,elsiz
     2           ,idele,reject)
            go to 60
 45         call umat45 (cm(mx+1),eps,sig,epsp,hsv,dt1,
     1           capa,eltype,tt,temper,failel,crv,nnpcrv,a(lcma),0,elsiz
     2           ,idele,0,reject)
            go to 60
 46         call umat46 (cm(mx+1),eps,sig,epsp,hsv,dt1,
     1           capa,eltype,tt,temper,failel,crv,nnpcrv,
     2           a(lcma),thhsvi,nthhsv,0,elsiz,idele,reject)
            go to 60
 47         call umat47 (cm(mx+1),eps,sig,epsp,hsv,dt1,
     1           capa,eltype,tt,temper,failel,crv,nnpcrv,a(lcma),0,elsiz
     2           ,idele,reject)
            go to 60
 48         call umat48 (cm(mx+1),eps,sig,epsp,hsv,dt1,
     1           capa,eltype,tt,temper,failel,crv,nnpcrv,a(lcma),0,elsiz
     2           ,idele,reject)
            go to 60
 49         call umat49 (cm(mx+1),eps,sig,epsp,hsv,dt1,
     1           capa,eltype,tt,temper,failel,crv,nnpcrv,a(lcma),0,elsiz
     2           ,idele,reject)
            go to 60
 50         call umat50 (cm(mx+1),eps,sig,epsp,hsv,dt1,
     1           capa,eltype,tt,temper,failel,crv,nnpcrv,a(lcma),0,elsiz
     2           ,idele,reject)
c
c           Scattering of variables
c
 60         if (no_hsvs.gt.0) then
               do j=1,no_hsvs
                  hsvs(i,j)=hsv(j)
               enddo
            endif
            if (ihyper(mt).ne.0) then
               do j=1,9
                  hsvs(i,ind_defgrad-1+j)=hsv(no_hsvs+j)
               enddo
            endif
c
            if (ifipts(mt).eq.0) failel=.false.
c
            if (failel) then
               sig1(i)=0.
               sig2(i)=0.
               sig3(i)=0.
               sig4(i)=0.
               sig5(i)=0.
               sig6(i)=0.
               if (ifipts(mt).lt.0) hsvs(i,ind_fipts)=1.
               nfipts(i)=nfipts(i)+1
               if (ifipts(mt).ge.0) then
                  failur=.true.
                  def_ele_eros(i)=0.
                  ifail(i)=1
                  fail(i)=0.
               elseif (nfipts(i).ge.nint(cm(mx-ifipts(mt)))) then
                  failur=.true.
                  def_ele_eros(i)=0.
                  ifail(i)=1
                  fail(i)=0.
               endif
            else
               sig1(i)=sig(1)
               sig2(i)=sig(2)
               sig3(i)=sig(3)
               sig4(i)=sig(4)
               sig5(i)=sig(5)
               sig6(i)=sig(6)
            endif
            epsps(i)=epsp
 90      continue
      else
c
c        Vector umat
c
c        Assume no failed elements
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
c        Call user defined subroutines here
c        First history variable is the one requested
c
         if(ivumat(mt).eq.0) then
c
            if (mt.eq.41) then
               call umat41v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .              sig1,sig2,sig3,sig4,
     .              sig5,sig6,epsps,hsvs,
     .              lft,llt,dt1siz,capa,eltype,tt,temps,failels,nlq,crv,
     .              nnpcrv,a(lcma),
     .              0,elsizv,idelev,reject)
            elseif (mt.eq.42) then
               call umat42v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .              sig1,sig2,sig3,sig4,
     .              sig5,sig6,epsps,hsvs,
     .              lft,llt,dt1siz,capa,eltype,tt,temps,failels,nlq,crv,
     .              nnpcrv,a(lcma),
     .              0,elsizv,idelev,reject)
            elseif (mt.eq.43) then
               call umat43v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .              sig1,sig2,sig3,sig4,
     .              sig5,sig6,epsps,hsvs,
     .              lft,llt,dt1siz,capa,eltype,tt,temps,failels,nlq,crv,
     .              nnpcrv,a(lcma),
     .              0,elsizv,idelev,reject)
            elseif (mt.eq.44) then
               call umat44v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .              sig1,sig2,sig3,sig4,
     .              sig5,sig6,epsps,hsvs,
     .              lft,llt,dt1siz,capa,eltype,tt,temps,failels,nlq,crv,
     .              nnpcrv,a(lcma),
     .              0,elsizv,idelev,reject)
            elseif (mt.eq.45) then
               call umat45v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .              sig1,sig2,sig3,sig4,
     .              sig5,sig6,epsps,hsvs,
     .              lft,llt,dt1siz,capa,eltype,tt,temps,failels,nlq,crv,
     .              nnpcrv,a(lcma),
     .              0,elsizv,idelev,0,reject)
            elseif (mt.eq.46) then
               call umat46v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .              sig1,sig2,sig3,sig4,
     .              sig5,sig6,epsps,hsvs,
     .              lft,llt,dt1siz,capa,eltype,tt,temps,failels,nlq,crv,
     .              nnpcrv,a(lcma),
     .              thhsv,nthhsv,0,elsizv,idelev,reject)
            elseif (mt.eq.47) then
               call umat47v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .              sig1,sig2,sig3,sig4,
     .              sig5,sig6,epsps,hsvs,
     .              lft,llt,dt1siz,capa,eltype,tt,temps,failels,nlq,crv,
     .              nnpcrv,a(lcma),
     .              0,elsizv,idelev,reject)
            elseif (mt.eq.48) then
c              ipt=1
               call umat48v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .              sig1,sig2,sig3,sig4,
     .              sig5,sig6,epsps,hsvs,
     .              lft,llt,dt1siz,capa,eltype,tt,temps,failels,nlq,crv,
     .              nnpcrv,a(lcma),
     .              0,elsizv,idelev,reject,ipt,npc,plc)
            elseif (mt.eq.49) then
c              ipt=1
               call umat49v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .              sig1,sig2,sig3,sig4,
     .              sig5,sig6,epsps,hsvs,
     .              lft,llt,dt1siz,capa,eltype,tt,temps,failels,nlq,crv,
     .              nnpcrv,a(lcma),
     .              0,elsizv,idelev,reject,ipt,npc,plc)
            elseif (mt.eq.50) then
               call umat50v(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .              sig1,sig2,sig3,sig4,
     .              sig5,sig6,epsps,hsvs,
     .              lft,llt,dt1siz,capa,eltype,tt,temps,failels,nlq,crv,
     .              nnpcrv,a(lcma),
     .              0,elsizv,idelev,reject)
            elseif (mt.eq.281) then
c              ipt=1
               call mat281h(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .              sig1,sig2,sig3,sig4,
     .              sig5,sig6,epsps,hsvs,
     .              lft,llt,dt1siz,capa,eltype,tt,temps,failels,nlq,crv,
     .              ipt, npc, plc, nnm1,a(lcma))
            elseif (mt.eq.282) then
c
c              ipt=1
               call enhvar282(1,lft,llt,ipt,nconstp,mxt,
     &                        auxvar1,auxvar2)
c
               call mat282h(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .              sig1,sig2,sig3,sig4,
     .              sig5,sig6,epsps,hsvs,
     .              lft,llt,dt1siz,capa,eltype,tt,temps,failels,nlq,crv,
     .              ipt, npc, plc, nnm1,a(lcma),nip,auxvar1,auxvar2,
     .              idelev)
c
               call enhvar282(2,lft,llt,ipt,nconstp,mxt,
     &                        auxvar1,auxvar2)
c
            elseif (mt.eq.283) then
               call getreal8ptr('dm_x',dm_x)
               call mat283h(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .              sig1,sig2,sig3,sig4,
     .              sig5,sig6,epsps,hsvs,
     .              lft,llt,dt1siz,capa,eltype,tt,temps,failels,nlq,crv,
     .              ipt, npc, plc, nnm1,a(lcma),dm_x)
            elseif (mt.eq.284) then
c              ipt=1
               call mat284h(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .              sig1,sig2,sig3,sig4,
     .              sig5,sig6,epsps,hsvs,
     .              lft,llt,dt1siz,capa,eltype,tt,temps,failels,nlq,crv,
     .              ipt, npc, plc, nnm1,a(lcma))
c              elseif (mt.eq.285) then
c              call umat285h(cm(mx+1),d1,d2,d3,d4,d5,d6,
c              .     sig1,sig2,sig3,sig4,
c              .     sig5,sig6,epsps,hsvs,
c              .     lft,llt,dt1siz,capa,eltype,tt,temps,failels,nlq,crv)
            elseif (mt.eq.286) then
c              ipt=1
               call mat286h(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .              sig1,sig2,sig3,sig4,
     .              sig5,sig6,epsps,hsvs,
     .              lft,llt,dt1siz,capa,eltype,tt,temps,failels,nlq,crv,
     .              ipt, npc, plc, nnm1,a(lcma))
            elseif (mt.eq.287) then
c              ipt=1
               call mat287h(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .              sig1,sig2,sig3,sig4,
     .              sig5,sig6,epsps,hsvs,
     .              lft,llt,dt1siz,capa,eltype,tt,temps,failels,nlq,crv,
     .              ipt, npc, plc, nnm1,a(lcma))
            elseif (mt.eq.288) then
c              ipt=1
               call mat288h(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .              sig1,sig2,sig3,sig4,
     .              sig5,sig6,epsps,hsvs,
     .              lft,llt,dt1siz,capa,eltype,tt,temps,failels,nlq,crv,
     .              ipt, npc, plc, nnm1,a(lcma))
            elseif (mt.eq.289) then
c              ipt=1
               call mat289h(cm(mx+1),d1,d2,d3,d4,d5,d6,
     .              sig1,sig2,sig3,sig4,
     .              sig5,sig6,epsps,hsvs,
     .              lft,llt,dt1siz,capa,eltype,tt,temps,failels,nlq,crv,
     .              ipt, npc, plc, nnm1,a(lcma))
            endif
         else
c
c       ALL vecumat interfaces are moved to user_vecumat.F
c
         endif
c
         if (ifipts(mt).ne.0) then
            do i=lft,llt
               if (failels(i)) then
                  sig1(i)=0.
                  sig2(i)=0.
                  sig3(i)=0.
                  sig4(i)=0.
                  sig5(i)=0.
                  sig6(i)=0.
                  if (ifipts(mt).lt.0) hsvs(i,ind_fipts)=1.
                  nfipts(i)=nfipts(i)+1
                  if (ifipts(mt).ge.0) then
                     failur=.true.
                     def_ele_eros(i)=0.
                     ifail(i)=1
                     fail(i)=0.
                  elseif (nfipts(i).ge.nint(cm(mx-ifipts(mt)))) then
                     failur=.true.
                     def_ele_eros(i)=0.
                     ifail(i)=1
                     fail(i)=0.
                  endif
               endif
            enddo
         endif
c     End of scalar/vector umat switch
      endif
c
c     Energy calculations
c
      do 100 i=lft,llt
         einc(i)=(d1(i)*sig1(i)+d2(i)*sig2(i)+d3(i)*sig3(i)+
     .        d4(i)*sig4(i)+d5(i)*sig5(i)+d6(i)*sig6(i))+einc(i)
 100  continue
c
c     Restore strain rates
      do i=lft,llt
        d1(i)=dloc(i,1)
        d2(i)=dloc(i,2)
        d3(i)=dloc(i,3)
        d4(i)=dloc(i,4)
        d5(i)=dloc(i,5)
        d6(i)=dloc(i,6)
      enddo
c
      if (iorien(mt).ne.0) then
c
c        Transform stresses back to global system
c
         if (ihyper(mt).ge.0) then
            call gblm22 (lft,llt)
         endif
c
c        Transform back deformation gradient
c
         if (ihyper(mt).gt.0) then
c
c           Deformation gradient stored in global system
            if (ifg(lft).eq.1) then
               do i=lft,llt
                  hsvs(i,if11)=g11(i)
                  hsvs(i,if21)=g21(i)
                  hsvs(i,if31)=g31(i)
                  hsvs(i,if12)=g12(i)
                  hsvs(i,if22)=g22(i)
                  hsvs(i,if32)=g32(i)
                  hsvs(i,if13)=g13(i)
                  hsvs(i,if23)=g23(i)
                  hsvs(i,if33)=g33(i)
               enddo
c
c           Deformation gradient transformed back to global system,
c           F=Z(t)*Fbar
            else
               do i=lft,llt
                  f1=z11(i)*hsvs(i,if11)+
     1                 z21(i)*hsvs(i,if21)+z31(i)*hsvs(i,if31)
                  f2=z12(i)*hsvs(i,if11)+
     1                 z22(i)*hsvs(i,if21)+z32(i)*hsvs(i,if31)
                  hsvs(i,if31)=z13(i)*hsvs(i,if11)+
     1                 z23(i)*hsvs(i,if21)+z33(i)*hsvs(i,if31)
                  hsvs(i,if11)=f1
                  hsvs(i,if21)=f2
                  f1=z11(i)*hsvs(i,if12)+
     1                 z21(i)*hsvs(i,if22)+z31(i)*hsvs(i,if32)
                  f2=z12(i)*hsvs(i,if12)+
     1                 z22(i)*hsvs(i,if22)+z32(i)*hsvs(i,if32)
                  hsvs(i,if32)=z13(i)*hsvs(i,if12)+
     1                 z23(i)*hsvs(i,if22)+z33(i)*hsvs(i,if32)
                  hsvs(i,if12)=f1
                  hsvs(i,if22)=f2
                  f1=z11(i)*hsvs(i,if13)+
     1                 z21(i)*hsvs(i,if23)+z31(i)*hsvs(i,if33)
                  f2=z12(i)*hsvs(i,if13)+
     1                 z22(i)*hsvs(i,if23)+z32(i)*hsvs(i,if33)
                  hsvs(i,if33)=z13(i)*hsvs(i,if13)+
     1                 z23(i)*hsvs(i,if23)+z33(i)*hsvs(i,if33)
                  hsvs(i,if13)=f1
                  hsvs(i,if23)=f2
               enddo
            endif
            
         elseif (ihyper(mt).eq.-1) then
c
c           Deformation gradient stored in global system
            if (ifg(lft).eq.1) then
               do i=lft,llt
                  hsvs(i,if11)=g11(i)
                  hsvs(i,if21)=g21(i)
                  hsvs(i,if31)=g31(i)
                  hsvs(i,if12)=g12(i)
                  hsvs(i,if22)=g22(i)
                  hsvs(i,if32)=g32(i)
                  hsvs(i,if13)=g13(i)
                  hsvs(i,if23)=g23(i)
                  hsvs(i,if33)=g33(i)
               enddo
c
c           Deformation gradient transformed back to global system,
c           F=Fbar*Z(0)^T
            else
c
               do i=lft,llt
                  f1=z11(i)*hsvs(i,if11)+
     1                 z21(i)*hsvs(i,if12)+z31(i)*hsvs(i,if13)
                  f2=z12(i)*hsvs(i,if11)+
     1                 z22(i)*hsvs(i,if12)+z32(i)*hsvs(i,if13)
                  hsvs(i,if13)=z13(i)*hsvs(i,if11)+
     1                 z23(i)*hsvs(i,if12)+z33(i)*hsvs(i,if13)
                  hsvs(i,if11)=f1
                  hsvs(i,if12)=f2
                  f1=z11(i)*hsvs(i,if21)+
     1                 z21(i)*hsvs(i,if22)+z31(i)*hsvs(i,if23)
                  f2=z12(i)*hsvs(i,if21)+
     1                 z22(i)*hsvs(i,if22)+z32(i)*hsvs(i,if23)
                  hsvs(i,if23)=z13(i)*hsvs(i,if21)+
     1                 z23(i)*hsvs(i,if22)+z33(i)*hsvs(i,if23)
                  hsvs(i,if21)=f1
                  hsvs(i,if22)=f2
                  f1=z11(i)*hsvs(i,if31)+
     1                 z21(i)*hsvs(i,if32)+z31(i)*hsvs(i,if33)
                  f2=z12(i)*hsvs(i,if31)+
     1                 z22(i)*hsvs(i,if32)+z32(i)*hsvs(i,if33)
                  hsvs(i,if33)=z13(i)*hsvs(i,if31)+
     1                 z23(i)*hsvs(i,if32)+z33(i)*hsvs(i,if33)
                  hsvs(i,if31)=f1
                  hsvs(i,if32)=f2
               enddo
c              Also transform back old deformation gradient in new vumat
c              implementation
               if (ivumat(mt).eq.2) then
                  do i=lft,llt
                     f1=z11(i)*hsvs(i,ifo11)+
     1                    z21(i)*hsvs(i,ifo12)+z31(i)*hsvs(i,ifo13)
                     f2=z12(i)*hsvs(i,ifo11)+
     1                    z22(i)*hsvs(i,ifo12)+z32(i)*hsvs(i,ifo13)
                     hsvs(i,ifo13)=z13(i)*hsvs(i,ifo11)+
     1                    z23(i)*hsvs(i,ifo12)+z33(i)*hsvs(i,ifo13)
                     hsvs(i,ifo11)=f1
                     hsvs(i,ifo12)=f2
                     f1=z11(i)*hsvs(i,ifo21)+
     1                    z21(i)*hsvs(i,ifo22)+z31(i)*hsvs(i,ifo23)
                     f2=z12(i)*hsvs(i,ifo21)+
     1                    z22(i)*hsvs(i,ifo22)+z32(i)*hsvs(i,ifo23)
                     hsvs(i,ifo23)=z13(i)*hsvs(i,ifo21)+
     1                    z23(i)*hsvs(i,ifo22)+z33(i)*hsvs(i,ifo23)
                     hsvs(i,ifo21)=f1
                     hsvs(i,ifo22)=f2
                     f1=z11(i)*hsvs(i,ifo31)+
     1                    z21(i)*hsvs(i,ifo32)+z31(i)*hsvs(i,ifo33)
                     f2=z12(i)*hsvs(i,ifo31)+
     1                    z22(i)*hsvs(i,ifo32)+z32(i)*hsvs(i,ifo33)
                     hsvs(i,ifo33)=z13(i)*hsvs(i,ifo31)+
     1                    z23(i)*hsvs(i,ifo32)+z33(i)*hsvs(i,ifo33)
                     hsvs(i,ifo31)=f1
                     hsvs(i,ifo32)=f2
                  enddo
               endif
     
            endif
c
         elseif (ihyper(mt).eq.-2) then
c
c           Deformation gradient stored in global system
            if (ifg(lft).eq.1) then
               do i=lft,llt
                  hsvs(i,if11)=g11(i)
                  hsvs(i,if21)=g21(i)
                  hsvs(i,if31)=g31(i)
                  hsvs(i,if12)=g12(i)
                  hsvs(i,if22)=g22(i)
                  hsvs(i,if32)=g32(i)
                  hsvs(i,if13)=g13(i)
                  hsvs(i,if23)=g23(i)
                  hsvs(i,if33)=g33(i)
               enddo
c
c           Deformation gradient transformed back to global system,
c           F=Z(t)*Fbar*Z(0)^T
            else
               do i=lft,llt
                  f11=z11(i)*hsvs(i,if11)+
     1                 z21(i)*hsvs(i,if21)+z31(i)*hsvs(i,if31)
                  f21=z12(i)*hsvs(i,if11)+
     1                 z22(i)*hsvs(i,if21)+z32(i)*hsvs(i,if31)
                  f31=z13(i)*hsvs(i,if11)+
     1                 z23(i)*hsvs(i,if21)+z33(i)*hsvs(i,if31)
c                 hsvs(i,if11)=f1
c                 hsvs(i,if21)=f2
                  f12=z11(i)*hsvs(i,if12)+
     1                 z21(i)*hsvs(i,if22)+z31(i)*hsvs(i,if32)
                  f22=z12(i)*hsvs(i,if12)+
     1                 z22(i)*hsvs(i,if22)+z32(i)*hsvs(i,if32)
                  f32=z13(i)*hsvs(i,if12)+
     1                 z23(i)*hsvs(i,if22)+z33(i)*hsvs(i,if32)
c                 hsvs(i,if12)=f1
c                 hsvs(i,if22)=f2
                  f13=z11(i)*hsvs(i,if13)+
     1                 z21(i)*hsvs(i,if23)+z31(i)*hsvs(i,if33)
                  f23=z12(i)*hsvs(i,if13)+
     1                 z22(i)*hsvs(i,if23)+z32(i)*hsvs(i,if33)
                  f33=z13(i)*hsvs(i,if13)+
     1                 z23(i)*hsvs(i,if23)+z33(i)*hsvs(i,if33)
c                 hsvs(i,if13)=f1
c                 hsvs(i,if23)=f2
                  hsvs(i,if11)=f11*z11(i)+f12*z21(i)+f13*z31(i)
                  hsvs(i,if12)=f11*z12(i)+f12*z22(i)+f13*z32(i)
                  hsvs(i,if13)=f11*z13(i)+f12*z23(i)+f13*z33(i)
                  hsvs(i,if21)=f21*z11(i)+f22*z21(i)+f23*z31(i)
                  hsvs(i,if22)=f21*z12(i)+f22*z22(i)+f23*z32(i)
                  hsvs(i,if23)=f21*z13(i)+f22*z23(i)+f23*z33(i)
                  hsvs(i,if31)=f31*z11(i)+f32*z21(i)+f33*z31(i)
                  hsvs(i,if32)=f31*z12(i)+f32*z22(i)+f33*z32(i)
                  hsvs(i,if33)=f31*z13(i)+f32*z23(i)+f33*z33(i)
               enddo
               
            endif
         endif
         
      endif
c
c     Flag if material model rejected implicit iterate
      if (isolvr(1).ne.0.and.reject) then
         isolvr(78)=5
         ascntl(150)=-1.e32
      endif
c
      return
c     900  format(/
c    1 ' *** Error User defined material in part',i12,
c    2 ' exceeds the current limit'/
c    3 10x,'of history variables for solids.')
      end
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c
c User Material Model: Initial Check
c
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
      subroutine rwumat(iphase,txt,lmc,ipnt,lmca,ipnta,idfoff,
     . fctmas,fcttim,fctlen,fcttem,incout,mt)
# 3346

c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      include 'memaia.inc'
      include 'iodeg.inc'
c
c     This is the non-default material card reader when MT<0
c
c     In this routine, material parameter cards are read from
c     *MAT_USER_DEFINED_MATERIAL_MODELS in phase 1.
c     In phase 2, the parameters are written as real numbers
c     to the structured input (dyna.str).
c
c     Main variables:
c       iphase : phase flag
c       txt    : incoming text
c       lmc    : number of material constants
c       ipnt   : pointer to material constants
c       lmca   : number of additional material constants
c       ipnta  : pointer to additional material constants
c       mt     : material type (absolute value)
c
c     Offset and transformation factors from *INCLUDE_TRANSFORM
c     can be used in phase 1:
c       idfoff : func id offset number, i.e., load curves and tables
c       fctmas : mass transformation factor
c       fcttim : time transformation factor
c       fctlen : length transformation factor
c       fcttem : temperature transformation factor
c       incout : the transformed included file will be written to dyna.inc
c                =0, no output file
c                =1, dyna.inc includes the complete transformed input
c
      character*200 txt
      character*80 mssg
      character*10 out10(8)
      dimension prop(48)
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
        mssg='readin *MAT_USER_DEFINED_MATERIAL_MODELS'
c
c       default read material constants: LMC
        if (isexample.eq.0) then
          do i=1,lmc,8
            iend=min(i+7,lmc)
            call gttxln (txt,lcount,2,8)
            read (txt,'(8e10.0)',err=900) (a(ipnt+k),k=i,iend)
          enddo
c
c       example: read 5 parameters
c       p1  - real with no unit
c       p2  - real with time unit
c       p3  - real with stress unit
c       ip4 - integer with no unit
c       ip5 - load curve id (stress vs. strain)
        elseif (isexample.eq.1) then
          call gttxln (txt,lcount,2,8)
          read (txt,'(3e10.0,2i10)',err=900) p1,p2,p3,ip4,ip5
          p2=p2*fcttim
          fctfor=fctmas*fctlen/(fcttim*fcttim)
          fctpre=fctfor/(fctlen*fctlen)
          p3=p3*fctpre
          if (ip5.ne.0) then
            ip5=ip5+idfoff
c           adtbmdu : Add TaBle or Curve to be MoDified User-defined
c           sfa = scale factor for abscissa value
c           sf0 = scale factor for ordinate value
            sfa=1.0
            sfo=fctpre
            call adtbmdu(ip5,sfa,sfo,ipnt,ipnta,lmca)
          endif
          a(ipnt+1)=p1
          a(ipnt+2)=p2
          a(ipnt+3)=p3
          ia(ipnt+4)=ip4
          ia(ipnt+5)=ip5
        endif
c
c       read extra material constants: LMCA
        if (lmca.gt.0) then
          do i=1,lmca,8
            iend=min(i+7,lmca)
            call gttxln (txt,lcount,2,8)
            read (txt,'(8e10.0)',err=900) (a(ipnta+k),k=i,iend)
          enddo
        endif
c
c---  PHASE 2: write structured input
c
c     In phase 2, parameters must be transformed to real numbers,
c     before writing them to the structured input. Therefore,
c     external load curve ids should be changed to internal ids
c     as shown in the example.
c
      elseif (iphase.eq.2) then
c
c       default write 48 parameters (LMC max)
        if (isexample.eq.0) then
          do i=1,48,8
            ii=min(48-i+1,8)
            do j=1,ii
              call form10(out10(j),a(ipnt+i+j-1))
            enddo
            write(io,'(8a10)') (out10(j),j=1,ii)
            call wttxsg(1)
          enddo
c
c       example: write 5 parameters and 43 zeros (sum=48!)
c       p1  - real with no unit
c       p2  - real with time unit
c       p3  - real with stress unit
c       ip4 - integer with no unit
c       ip5 - load curve id (stress vs. strain)
        elseif (isexample.eq.1) then
          do i=1,48
            prop(i)=a(ipnt+i)
          enddo
          prop(4)=float(ia(ipnt+4))
c         change load curve id to internal number with lcidi
          lc=ia(ipnt+5)
          prop(5)=float(lcidi(lc))
          do i=1,48,8
            ii=min(48-i+1,8)
            do j=1,ii
c             change to special output format with form10
              call form10(out10(j),prop(i+j-1))
            enddo
            write(io,'(8a10)') (out10(j),j=1,ii)
            call wttxsg(1)
          enddo
        endif
c
c       write extra material constants: LMCA
        if (lmca.gt.0) then
          do i=1,lmca,8
            ii=min(lmca-i+1,8)
            write(io,'(1p8e10.3)') (a(ipnta+i+j-1),j=1,ii)
            call wttxsg(1)
          enddo
        endif
c
      endif
c
      return
  900 call terminn(txt,mssg,lcount,1)
      end
      subroutine umat_setnhvpp(idpart,mt,nhvpp,cm,cma,isutyp)
# 3510

c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp.            |
c|  All rights reserved                                           |
c******************************************************************
c
c     Set number of history variables per part for user materials
c
c     Usually, this number is given by NHV on
c     *MAT_USER_DEFINE_MATERIAL_MODELS. In that case, all user materials
c     with the same material type MT own the same number of history
c     variables. Within this subroutine, that can be changed to a number
c     of history variables on per part basis, e.g., depending on element
c     type or options used (given by cm constants).
c
c     idpart     = internal part id, input
c                  (convert to user part ID with lqfmiv8(idpart) )
c     mt         = material type, input
c     nhvpp      = number of history variables, input/output
c     cm(*)      = material constants array, input
c     cma(*)     = additional material constants array, input
c     isutyp     = stress update type, input
c                  = 0: 3-D (solids and some shells/tshells)
c                  = 1: 1-D (beams)
c                  = 2: 2-D (shells and some tshells)
c
      dimension cm(*),cma(*)
      integer lqfmiv8
c
c
c     Example: NHV gets increased by 5 if cm(6) is less than zero
c              and solid elements are used
c
c     if (isutyp.eq.0. and. cm(6).lt.0.0) then
c       nhvpp = nhvpp + 5
c     endif
c
c
      return
      end
      subroutine chknhue(nhsv)
# 3557

c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      include 'iounits.inc'
      include 'nhisparm.inc'
c
c     check nhsv during reading keywords
c
      if (nhsv.gt.NHISVUE) then
c       write(iotty,100) NHISVUE
c       write(iohsp,100) NHISVUE
c       write(iomsg,100) NHISVUE
        ierdat(1)=NHISVUE
        call lsmsg(1,MSG_KEY+1138,ioall,ierdat,rerdat,cerdat,0)
      endif
      nhsv=min(NHISVUE,nhsv)
c 100 format(/' *** Warning number of user element history variables',
c    .       /'             is limited by NHISVUE in nhisparm.inc:',i10)
c
      return
      end
      subroutine chkusercomm
# 3588

c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     check the length of common block size during initialization
c
      include 'nlqparm'
      include 'nhisparm.inc'
      include 'iounits.inc'
c
      parameter (NBEL8A=max(100,2*(NHISVUE+45)))
      parameter (NBEL7 =max(2601,
     . 1180+576*NXDOFUE+64*NXDOFUE*NXDOFUE+12*5))
      common/aux14loc/ax14zz1(nlq,7+NHISVAR)
      common/bel8loc/bel8lz1(nlq,2*(NHISVUE+45))
      common/bel8aloc/bel8lz2(nlq,NBEL8A)
      common/bel7loc/bel7lz(nlq,NBEL7)
      common/usercom/iusercomm(4)
c
c$omp threadprivate (/bel7loc/)
c$omp threadprivate (/bel8aloc/)
c$omp threadprivate (/bel8loc/)
c$omp threadprivate (/aux14loc/)
      l14=nlq*(7+NHISVAR)
      l8 =nlq*2*(NHISVUE+45)
      l8a=nlq*NBEL8A
      l7 =nlq*NBEL7
c
      if (l14.gt.iusercomm(1)) then
        ierdat(1)=l14
        ierdat(2)=iusercomm(1)
        cerdat(1)='/aux14loc/'
        call lsmsg(2,MSG_OTH+81,iotty,ierdat,rerdat,cerdat,0)
        call cstop('E r r o r   t e r m i n a t i o n',1)
      endif
      if (l8.gt.iusercomm(2)) then
        ierdat(1)=l8
        ierdat(2)=iusercomm(2)
        cerdat(1)='/bel8loc/'
        call lsmsg(2,MSG_OTH+81,iotty,ierdat,rerdat,cerdat,0)
        call cstop('E r r o r   t e r m i n a t i o n',1)
      endif
      if (l8a.gt.iusercomm(3)) then
        ierdat(1)=l8a
        ierdat(2)=iusercomm(3)
        cerdat(1)='/bel8aloc/'
        call lsmsg(2,MSG_OTH+81,iotty,ierdat,rerdat,cerdat,0)
        call cstop('E r r o r   t e r m i n a t i o n',1)
      endif
      if (l7.gt.iusercomm(4)) then
        ierdat(1)=l7
        ierdat(2)=iusercomm(4)
        cerdat(1)='/bel7loc/'
        call lsmsg(2,MSG_OTH+81,iotty,ierdat,rerdat,cerdat,0)
        call cstop('E r r o r   t e r m i n a t i o n',1)
      endif
c
      return
      end
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c
c User Material Model: Utilitity Subroutine
c
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
      subroutine usr_temps (tnew,fval,itemp,ctmp,lft,llt,ix1,ix2,
     . ix3,ix4,ix5,ix6,ix7,ix8,num_nods,itopaz,nnm1,rcoor,scoor,tcoor,
     . nltvel,tltvel)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      common/blk03/sigma,tolb,nummat,numnpt,numel,numsh4,iunits,iband,
     1 nbs,nsl,nslvt,nmsrt,numelst,nprof,irtyp,itmaxb,numeltt,iphase,
     2 igenl,igenm,igene,igend,isotr,iem,isoln,igeom,mcut,numsh12,
     3 ndtot,nsl_th,lenhsv,numel2,numel4,numel6,numel8,numel10,numel20
      dimension tnew(*),fval(*),ctmp(*),ix1(*),ix2(*),ix3(*),ix4(*),
     .          ix5(*),ix6(*),ix7(*),ix8(*),itopaz(*),tltvel(*)
c
c    temperatures at element center
c
      if (itemp.gt.0) then
        tempr=fval(itemp)
        do i=lft,llt
          ctmp(i)=tempr
        enddo
c
      elseif (itemp.lt.0 .or. itopaz(1).eq.999) then
        if (num_nods.eq.8) then
          do i=lft,llt
            ctmp(i) = .125*(tnew(ix1(i))+tnew(ix2(i))+tnew(ix3(i))
     .                      +tnew(ix4(i))+tnew(ix5(i))+tnew(ix6(i))
     .                      +tnew(ix7(i))+tnew(ix8(i)))
          enddo
c
        elseif (num_nods.eq.4) then
          if (numsh12.ne.0) then
           call get_tmp_tpz (ctmp,lft,llt,nnm1,rcoor,scoor,tcoor)
          else
            do i=lft,llt
            ctmp(i)=.25*(tnew(ix1(i))+tnew(ix2(i))
     .                  +tnew(ix3(i))+tnew(ix4(i)))
            enddo
          endif
c
        else
          do i=lft,llt
            ctmp(i)=.50*(tnew(ix1(i))+tnew(ix2(i)))
          enddo
        endif
      endif
      if (nltvel.gt.0) then
        do i=lft,llt
          ctmpt =tltvel(i)
          if (ctmpt.gt.-999.) then
            ctmp(i)=ctmpt
          endif
        enddo
      endif
c
      return
      end
      subroutine usr_tempsph (tnew,fval,itemp,ctmp,lft,llt,
     . nnm1,nodsph,itopaz)
c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
      common/blk03/sigma,tolb,nummat,numnpt,numel,numsh4,iunits,iband,
     1 nbs,nsl,nslvt,nmsrt,numelst,nprof,irtyp,itmaxb,numeltt,iphase,
     2 igenl,igenm,igene,igend,isotr,iem,isoln,igeom,mcut,numsh12,
     3 ndtot,nsl_th,lenhsv,numel2,numel4,numel6,numel8,numel10,numel20
      dimension tnew(*),fval(*),ctmp(*),nodsph(*),itopaz(*)
c
c    temperatures at element center
c
      if (itemp.gt.0) then
        tempr=fval(itemp)
        do i=lft,llt
          ctmp(i)=tempr
        enddo
c
      elseif (itemp.lt.0 .or. itopaz(1).eq.999) then
        do i=lft,llt
          ctmp(i)=tnew(nodsph(nnm1+i))
        enddo
      endif
c
      return
      end
      subroutine ushout(iop,sig,nzgpt,rslt,ix,x,nmtcon,nnel,mx,mte)
# 3754

c
c******************************************************************
c|  Livermore Software Technology Corporation  (LSTC)             |
c|  ------------------------------------------------------------  |
c|  Copyright 1987-2008 Livermore Software Tech. Corp             |
c|  All rights reserved                                           |
c******************************************************************
c
c     rslt(1:8) array of force/moment resultants to be written to
c               the LS-TAURUS database unless changed in this user
c               routine. Components 26-33 in LS-TAURUS.
c
c     rslt(9:9) current shell thickness
c
c     iop       shell formulation flag
c               1=Hughes-Liu
c               2=Belytschko-Tsay
c               3=DKT
c               4=C0
c               5=Membrane
c               6=Hughes-Liu with full integration
c               7=Corotational Hughes-Liu with full integration
c               8=Belytschko-Leviathan
c               9=Membrane with 2 x 2 integratio
c              10=Belytschko-Wong
c              11=Corotational Hughes-Liu
c
c     sig(1:6) Stress array xx, yy, zz, xy, yz, zx
c              if iop=1 or 6 the stresses are in the global
c                            system
c              else          the stresses reference the local element
c                            system
c
c     sig(7:-) Constitutive history variables
c
c     nzgpt    Number of thru thickness integration points
c
c     ix(1:4)  element connectivities
c
c     nmtcon   length of stress+history variables at an integration poitn
c
c     nnel     internal element number
c
c     mx       part ID
c
c     mte      material type
c
      real*8 x
      dimension sig(nmtcon,*),rslt(9),ix(*),x(3,*)
      return
      end
