*TITLE
$#                                                                         title
LS-DYNA keyword deck by LS-PrePost
*CONTROL_ENERGY
$#    hgen      rwen    slnten     rylen     irgen     maten     drlen     disen
         2         2         2         1         2         1         1         1
*CONTROL_HOURGLASS
$#     ihq        qh
         6       0.1
*CONTROL_TERMINATION
$#  endtim    endcyc     dtmin    endeng    endmas     nosol
     0.333         0       0.0       0.0  1.0000E8         0
*DATABASE_BNDOUT
$#      dt    binary      lcur     ioopt   option1   option2   option3   option4
      0.03         0         0         1       300         0         0         0
*DATABASE_ELOUT
$#      dt    binary      lcur     ioopt   option1   option2   option3   option4
      0.03         0         0         1         0         0         0         0
*DATABASE_GLSTAT
$#      dt    binary      lcur     ioopt
      0.03         0         0         1
*DATABASE_MATSUM
$#      dt    binary      lcur     ioopt
      0.03         0         0         1
*DATABASE_NODFOR
$#      dt    binary      lcur     ioopt
      0.03         0         0         1
*DATABASE_NODOUT
$#      dt    binary      lcur     ioopt   option1   option2
      0.03         0         0         1       0.0         0
*DATABASE_BINARY_D3PLOT
$#      dt      lcdt      beam     npltc    psetid
      0.03         0         0         0         0
$#   ioopt      rate    cutoff    window      type      pset
         0       0.0       0.0       0.0         0         0
*DATABASE_EXTENT_BINARY
$#   neiph     neips    maxint    strflg    sigflg    epsflg    rltflg    engflg
       300         0         3        11         1         1         1         1
$#  cmpflg    ieverp    beamip     dcomp      shge     stssz    n3thdt   ialemat
         0         0         0         1         1         1         2         1
$# nintsld   pkp_sen      sclp     hydro     msscl     therm    intout    nodout
         0         0       1.0         0         0         0          ALL_GL
$#    dtdt    resplt     neipb   quadsld    cubsld   deleres
         0         0         0         0         0         0
