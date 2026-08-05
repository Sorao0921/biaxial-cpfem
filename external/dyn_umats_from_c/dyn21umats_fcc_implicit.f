#include "define.inc"
#include "define2.inc"

      subroutine umatSubroutineFccImplicit(cm,eps,sig,epsp,hsv,
     1   dt1,capa,etype,tt,temper,failel,crv,nnpcrv,cma,qmat,
     2   elsiz,idele,reject)
      
c Includes
c      implicit none
      include 'nlqparm'
      include 'bk06.inc'
      include 'iounits.inc'
      include 'CTRLIMPLICIT'

      CHARACTER*8 CMNAME
      EXTERNAL F

      INTEGER,PARAMETER:: ND=12,NTENS=6,NHSV=300,NDI=3,NSHR=3
      
      DOUBLE PRECISION CM(*),HSV(*),EPS(*),SIG(*),CMA(*)
      DOUBLE PRECISION CMHARD(8),R(3,3),RL(6,6),S11(3,12),M11(3,12)

      DOUBLE PRECISION CRSS0,GAMTOL,SLPN,SLPREF
      DOUBLE PRECISION GAMMA(ND),CRSS(ND),GAMCUM(ND),TAU(ND)

      DOUBLE PRECISION CRSS1(ND),GAMMA1(ND),TAUSP1(ND)

      DOUBLE PRECISION QMAT(3,3),SLPDIR(3,ND),SLPNOR(3,ND),
     2  SLPSPN(3,ND),DSPDIR(3,ND),DSPNOR(3,ND),DLOCAL(6,6),D(6,6),
     3  ROTD(6,6),ROTATE(3,3),SLPDEF(6,ND)

      DOUBLE PRECISION ddsdde(ntens,ntens),ddsddt(ntens),drplde(ntens),
     2 stran(ntens),time(2),predef(1),dpred(1),
     3 coords(3),drot(3,3),dfgrd0(3,3),dfgrd1(3,3)

      DOUBLE PRECISION DGRAD(3,3),DGRAD1(3,3),STRAIN(6),STRAIN1(6),
     2         DSTRAIN(6)
      INTEGER,PARAMETER:: IND_DGRAD=250

      DIMENSION ISPDIR(3), ISPNOR(3), NSLIP(3), 
     2          FSLIP(ND), DFDXSP(ND), DDEMSD(6,ND), 
     3          H(ND,ND), DDGDDE(ND,6), 
     4          DSTRES(6), DELATS(6), DSPIN(3), DVGRAD(3,3),
     5          DGAMMA(ND), DTAUSP(ND), DGSLIP(ND), 
     6          WORKST(ND,ND), INDX(ND), TERM(3,3), TRM0(3,3), ITRM(3)

      DIMENSION FSLIP1(ND), STRES1(6),
     2          GSLP1(ND), SPNOR1(3,ND), SPDIR1(3,ND), DDSDE1(6,6),
     3          DSOLD(6), DGAMOD(ND), DTAUOD(ND), DGSPOD(ND), 
     4          DSPNRO(3,ND), DSPDRO(3,ND), 
     5          DHDGDG(ND,ND)

c-----  Init materials constants
c 1~8 --- elastic constants and orientation
      ! CM(1),CM(2) --- Young's modulus
      ! CM(3),CM(4),CM(5) --- Euler anles for orientation
c 9~16 --- hardening parameters
C               PROP(1,i) -- initial hardening modulus H0 in the ith 
C                            set of slip systems
C               PROP(2,i) -- stage I SIG TAUI in the ith set of  
C                            slip systems (or the breakthrough SIG 
C                            where large plastic flow initiates)
C               PROP(3,i) -- initial critical resolved shear SIG 
C                            TAU0 in the ith set of slip systems
c 9~16 --- Hardening parameter
    ! CM(9) --- Hardening law type
      CRSS0=CM(10)
c 17~24 --- slip system constitutive model coeff.
      SLPN=CM(18)
      SLPREF=CM(19)

C-----  Elastic matrix in local cubic crystal system: DLOCAL
C       and its elastic matrix in global crystal systtem: D
      CALL calElasIsoTensor(CM(1),CM(2),DLOCAL)
      CALL ROTMATBYEULER(CM(3),CM(4),CM(5),ROTATE)
      CALL calTransMatFourthOrd(ROTATE,ROTD)
      CALL tranElasTensorLocal2Global(DLOCAL,ROTD,D)

C-----  Init the iteration
      NITRTN=-1

      DO I=1,NTENS
         DSOLD(I)=0.
      END DO

      DO J=1,ND
         DGAMOD(J)=0.
         DTAUOD(J)=0.
         DGSPOD(J)=0.
         DO I=1,3
            DSPNRO(I,J)=0.
            DSPDRO(I,J)=0.
         END DO
      END DO

C-----  Increment of spin associated with the material element: DSPIN
C     (only needed for finite rotation)
C
      IF (NLGEOM.NE.0) THEN
         DO J=1,3
            DO I=1,3
               TERM(I,J)=QMAT(J,I)
               TRM0(I,J)=QMAT(J,I)
            END DO

            TERM(J,J)=TERM(J,J)+1.D0
            TRM0(J,J)=TRM0(J,J)-1.D0
         END DO

         CALL LUDCMP (TERM, 3, 3, ITRM, DDCMP)

         DO J=1,3
            CALL LUBKSB (TERM, 3, 3, ITRM, TRM0(1,J))
         END DO

         DSPIN(1)=TRM0(2,1)-TRM0(1,2)
         DSPIN(2)=TRM0(1,3)-TRM0(3,1)
         DSPIN(3)=TRM0(3,2)-TRM0(2,3)

      END IF


C----- Prepare the state variables
      NSLPTL=12
      NSLIP=12
      IF (NCYCLE.EQ.0) THEN
c----- Current strength of slip sys.
        CRSS(1:12)=CRSS0
        HSV(1:12)=CRSS(1:12)
c----- rotation matrix, slip direciton, slip normals
c       Schmid factor and spin schmid factor
        CALL initCrystal(0,0,CM(3:5),ND,ROTATE,SLPDIR,SLPNOR)
        CALL CALSF(SLPDIR,SLPNOR,ND,SLPDEF)
        ID=0
        DO J=1,ND
            DO I=1,3
                ID=ID+1
                HSV(36+ID)=SLPNOR(I,J)
                HSV(72+ID)=SLPDIR(I,J)
            END DO
        END DO
C-----  Initial value of shear strain in slip systems
CFIX--  Initial value of cumulative shear strain in each slip systems
        GAMMA(1:12)=0.
        HSV(13:24)=GAMMA(1:12)
        GAMCUM(1:12)=0.
        HSV(109:120)=GAMCUM(1:12)
        GAMTOL=0.
        HSV(121)=GAMTOL
C-----  Initial value of the resolved shear stress in slip systems
        CALL calSigRss(SIG(1:6),SLPDEF,ND,TAU)
        HSV(25:36)=TAU(1:12)
C-----  Number of slip system     
        HSV(NHSV)=FLOAT(NSLPTL)
        DO I=1,NSET
           HSV(NHSV-4+I)=FLOAT(NSLIP(I))
        END DO
C----- Init deformation gradient
      DGRAD(1,1)=1.
      DGRAD(2,1)=0.
      DGRAD(3,1)=0.
      DGRAD(1,2)=0.
      DGRAD(2,2)=1.
      DGRAD(3,2)=0.
      DGRAD(1,3)=0.
      DGRAD(2,3)=0.
      DGRAD(3,3)=1.
      ELSE
c----- crss
        CRSS(1:12)=HSV(1:12)
c----- shar strain
        GAMMA(1:12)=HSV(13:24)
C----- obtain rss
        TAU(1:12)=HSV(25:36)
C----- OBTAIN SHEAR STRAIN RATE
        GAMCUM(1:12)=HSV(109:120)
        GAMTOL=HSV(121)
c----- Slip normals and direction
        ID=0
        DO J=1,ND
            DO I=1,3
                ID=ID+1
                SLPNOR(I,J)=HSV(36+ID)
                SLPDIR(I,J)=HSV(72+ID)
            END DO
        END DO
C----- SCHMID FACOTR
        NSLPTL=12
        DO I=1,NSET
            NSLIP(I)=NINT(HSV(NHSV-4+I))
        END DO
C----- Init deformation gradient
      DGRAD(1,1)=HSV(IND_DGRAD+1)
      DGRAD(2,1)=HSV(IND_DGRAD+2)
      DGRAD(3,1)=HSV(IND_DGRAD+3)
      DGRAD(1,2)=HSV(IND_DGRAD+4)
      DGRAD(2,2)=HSV(IND_DGRAD+5)
      DGRAD(3,2)=HSV(IND_DGRAD+6)
      DGRAD(1,3)=HSV(IND_DGRAD+7)
      DGRAD(2,3)=HSV(IND_DGRAD+8)
      DGRAD(3,3)=HSV(IND_DGRAD+9)
      ENDIF

      DGRAD1(1,1)=HSV(NHSV+1)
      DGRAD1(2,1)=HSV(NHSV+2)
      DGRAD1(3,1)=HSV(NHSV+3)
      DGRAD1(1,2)=HSV(NHSV+4)
      DGRAD1(2,2)=HSV(NHSV+5)
      DGRAD1(3,2)=HSV(NHSV+6)
      DGRAD1(1,3)=HSV(NHSV+7)
      DGRAD1(2,3)=HSV(NHSV+8)
      DGRAD1(3,3)=HSV(NHSV+9)

      HSV(IND_DGRAD+1)=DGRAD1(1,1)
      HSV(IND_DGRAD+2)=DGRAD1(2,1)
      HSV(IND_DGRAD+3)=DGRAD1(3,1)
      HSV(IND_DGRAD+4)=DGRAD1(1,2)
      HSV(IND_DGRAD+5)=DGRAD1(2,2)
      HSV(IND_DGRAD+6)=DGRAD1(3,2)
      HSV(IND_DGRAD+7)=DGRAD1(1,3)
      HSV(IND_DGRAD+8)=DGRAD1(2,3)
      HSV(IND_DGRAD+9)=DGRAD1(3,3)

      CALL CALSTRAIN(DGRAD,STRAIN)
      CALL CALSTRAIN(DGRAD1,STRAIN1)

      DO I=1,6
         DSTRAIN(I)=STRAIN1(I)-STRAIN(I)
      ENDDO

      DO I=1,6
         HSV(220+I)=DSTRAIN(I)
         HSV(230+I)=EPS(I)
c         EPS(I)=DSTRAIN(I)
      ENDDO

C-----  Increment of dilatational strain: DEV
      DEV=0.D0
      DO I=1,NDI
         DEV=DEV+EPS(I)
      END DO


C-----  Iteration starts (only when iteration method is used)
1000  CONTINUE

C-----  Parameter NITRTN: number of iterations
C       NITRTN = 0 --- no-iteration solution
C
      NITRTN=NITRTN+1

C---- Update schmid factor every iteration since the slip dir.
c   and slip normls are updated
      CALL CALSF(SLPDIR,SLPNOR,ND,SLPDEF)

C-----  Slip spin tensor: SLPSPN (only needed for finite rotation)
      IF (NLGEOM.NE.0) THEN
        CALL CALSFSPIN(SLPDIR,SLPNOR,ND,SLPSPN)
      END IF

C-----  Double dot product of elastic moduli tensor with the slip 
C     deformation tensor (Schmid factors) plus, only for finite 
C     rotation, the dot product of slip spin tensor with the SIG: 
C     DDEMSD
C
        CALL CALDDEMSD(D,SLPDEF,SLPSPN,SIG,NDI,NSHR,
     1 ND,NLGEOM,DDEMSD)

C-----  Shear strain-rate in a slip system at the start of increment: 
C     FSLIP, and its derivative: DFDXSP
C
         CALL STRAINRATE (GAMMA, TAU, 
     2                    CRSS, ND, FSLIP, DFDXSP, 
     3                    SLPN,SLPREF)

C-----  Self- and latent-hardening laws
CFIXA  
       CALL LATENTHARDEN (GAMMA, TAU, 
     2                   CRSS, GAMCUM,
     3                   GAMTOL, CM(25), ND, H)


C-----  LU decomposition to solve the increment of shear strain in a 
C     slip system
C
      TERM1=THETA*DT1
      DO I=1,ND
         X=TAU(I)/CRSS(I)
         TERM2=TERM1*DFDXSP(I)/CRSS(I)
         TERM3=TERM1*X*DFDXSP(I)/CRSS(I)

         DO J=1,ND
            TERM4=0.
            DO K=1,6
               TERM4=TERM4+DDEMSD(K,I)*SLPDEF(K,J)
            END DO

            WORKST(I,J)=TERM2*TERM4+H(I,J)*TERM3*DSIGN(1.D0,FSLIP(J))

            IF (NITRTN.GT.0) WORKST(I,J)=WORKST(I,J)+TERM3*DHDGDG(I,J)

         END DO

         WORKST(I,I)=WORKST(I,I)+1.
      END DO

C-----  Increment of shear strain in a slip system: DGAMMA
      TERM1=THETA*DT1
      DO I=1,NSLPTL

         IF (NITRTN.EQ.0) THEN
            X=TAU(I)/CRSS(I)
            TERM2=TERM1*DFDXSP(I)/CRSS(I)

            DGAMMA(I)=0.
            DO J=1,NDI
               DGAMMA(I)=DGAMMA(I)+DDEMSD(J,I)*EPS(J)
            END DO

            IF (NSHR.GT.0) THEN
               DO J=1,NSHR
                  DGAMMA(I)=DGAMMA(I)+DDEMSD(J+3,I)*EPS(J+NDI)
               END DO
            END IF

            DGAMMA(I)=DGAMMA(I)*TERM2+FSLIP(I)*DT1

         ELSE
            DGAMMA(I)=TERM1*(FSLIP(I)-FSLIP1(I))+FSLIP1(I)*DT1
     2                -DGAMOD(I)

         END IF

      END DO

      CALL LUDCMP (WORKST, ND, ND, INDX, DDCMP)
      CALL LUBKSB (WORKST, ND, ND, INDX, DGAMMA)

      DO I=1,ND
         DGAMMA(I)=DGAMMA(I)+DGAMOD(I)
      END DO

C-----  Update the shear strain in a slip system: HSV(NSLPTL+1) - 
C     HSV(2*NSLPTL)
C
      DO I=1,ND
        GAMMA(I)=GAMMA(I)+DGAMMA(I)-DGAMOD(I)
      END DO

C-----  Increment of current strength in a slip system: DGSLIP
      DO I=1,ND
         DGSLIP(I)=0.
         DO J=1,ND
            DGSLIP(I)=DGSLIP(I)+H(I,J)*ABS(DGAMMA(J))
         END DO
      END DO

C-----  Update the current strength in a slip system: HSV(1) - 
C     HSV(NSLPTL)
C
      DO I=1,ND
        CRSS(I)=CRSS(I)+DGSLIP(I)-DGSPOD(I)
      END DO

C-----  Increment of strain associated with lattice stretching: DELATS
      DO J=1,6
         DELATS(J)=0.
      END DO

      DO J=1,3
         IF (J.LE.NDI) DELATS(J)=EPS(J)
         DO I=1,NSLPTL
            DELATS(J)=DELATS(J)-SLPDEF(J,I)*DGAMMA(I)
         END DO
      END DO

      DO J=1,3
         IF (J.LE.NSHR) DELATS(J+3)=EPS(J+NDI)
         DO I=1,NSLPTL
            DELATS(J+3)=DELATS(J+3)-SLPDEF(J+3,I)*DGAMMA(I)
         END DO
      END DO

C-----  Increment of deformation gradient associated with lattice 
C     stretching in the current state, i.e. the velocity gradient 
C     (associated with lattice stretching) times the increment of time:
C     DVGRAD (only needed for finite rotation)
C
      IF (NLGEOM.NE.0) THEN
         DO J=1,3
            DO I=1,3
               IF (I.EQ.J) THEN
                  DVGRAD(I,J)=DELATS(I)
               ELSE
                  DVGRAD(I,J)=DELATS(I+J+1)
               END IF
            END DO
         END DO

         DO J=1,3
            DO I=1,J
               IF (J.GT.I) THEN
                  IJ2=I+J-2
                  IF (MOD(IJ2,2).EQ.1) THEN
                     TERM1=1.
                  ELSE
                     TERM1=-1.
                  END IF

                  DVGRAD(I,J)=DVGRAD(I,J)+TERM1*DSPIN(IJ2)
                  DVGRAD(J,I)=DVGRAD(J,I)-TERM1*DSPIN(IJ2)

                  DO K=1,NSLPTL
                     DVGRAD(I,J)=DVGRAD(I,J)-TERM1*DGAMMA(K)*
     2                                       SLPSPN(IJ2,K)
                     DVGRAD(J,I)=DVGRAD(J,I)+TERM1*DGAMMA(K)*
     2                                       SLPSPN(IJ2,K)
                  END DO
               END IF

            END DO
         END DO

      END IF

C-----  Increment of resolved shear SIG in a slip system: DTAUSP
      DO I=1,NSLPTL
         DTAUSP(I)=0.
         DO J=1,6
            DTAUSP(I)=DTAUSP(I)+DDEMSD(J,I)*DELATS(J)
         END DO
      END DO

C-----  Update the resolved shear SIG in a slip system: 
C     HSV(2*NSLPTL+1) - HSV(3*NSLPTL)
C
      DO I=1,NSLPTL
        TAU(I)=TAU(I)+DTAUSP(I)-DTAUOD(I)
      END DO

C-----  Increment of SIG: DSTRES
      IF (NLGEOM.EQ.0) THEN
         DO I=1,NTENS
            DSTRES(I)=0.
         END DO
      ELSE
         DO I=1,NTENS
            DSTRES(I)=-SIG(I)*DEV
         END DO
      END IF

      DO I=1,NDI
         DO J=1,NDI
            DSTRES(I)=DSTRES(I)+D(I,J)*EPS(J)
         END DO

         IF (NSHR.GT.0) THEN
            DO J=1,NSHR
               DSTRES(I)=DSTRES(I)+D(I,J+3)*EPS(J+NDI)
            END DO
         END IF

         DO J=1,NSLPTL
            DSTRES(I)=DSTRES(I)-DDEMSD(I,J)*DGAMMA(J)
         END DO
      END DO

      IF (NSHR.GT.0) THEN
         DO I=1,NSHR

            DO J=1,NDI
               DSTRES(I+NDI)=DSTRES(I+NDI)+D(I+3,J)*EPS(J)
            END DO

            DO J=1,NSHR
               DSTRES(I+NDI)=DSTRES(I+NDI)+D(I+3,J+3)*EPS(J+NDI)
            END DO

            DO J=1,NSLPTL
               DSTRES(I+NDI)=DSTRES(I+NDI)-DDEMSD(I+3,J)*DGAMMA(J)
            END DO

         END DO
      END IF

C-----  Update the SIG: SIG
      DO I=1,NTENS
         SIG(I)=SIG(I)+DSTRES(I)-DSOLD(I)
      END DO

C-----  Increment of normal to a slip plane and a slip direction (only 
C     needed for finite rotation)
C
      IF (NLGEOM.NE.0) THEN
         DO J=1,NSLPTL
            DO I=1,3
               DSPNOR(I,J)=0.
               DSPDIR(I,J)=0.

               DO K=1,3
                  DSPNOR(I,J)=DSPNOR(I,J)-SLPNOR(K,J)*DVGRAD(K,I)
                  DSPDIR(I,J)=DSPDIR(I,J)+SLPDIR(K,J)*DVGRAD(I,K)
               END DO

            END DO
         END DO

C-----  Update the normal to a slip plane and a slip direction (only 
C     needed for finite rotation)
C
         DO J=1,ND
            DO I=1,3
               SLPNOR(I,J)=SLPNOR(I,J)+DSPNOR(I,J)-DSPNRO(I,J)
               SLPDIR(I,J)=SLPDIR(I,J)+DSPDIR(I,J)-DSPDRO(I,J)
            END DO
         END DO

      END IF

C-----  Derivative of shear strain increment in a slip system w.r.t. 
C     strain increment: DDGDDE
C
      TERM1=THETA*DT1
      DO I=1,NTENS
         DO J=1,ND
            X=TAU(J)/CRSS(J)
            TERM2=TERM1*DFDXSP(J)/CRSS(J)
            IF (I.LE.NDI) THEN
               DDGDDE(J,I)=TERM2*DDEMSD(I,J)
            ELSE
               DDGDDE(J,I)=TERM2*DDEMSD(I-NDI+3,J)
            END IF
         END DO

         CALL LUBKSB (WORKST, ND, ND, INDX, DDGDDE(1,I))

      END DO

C-----  Derivative of SIG increment w.r.t. strain increment, i.e. 
C     Jacobian matrix
C
C-----  Jacobian matrix: elastic part
      DO J=1,NTENS
         DO I=1,NTENS
            DDSDDE(I,J)=0.
         END DO
      END DO

      DO J=1,NDI
         DO I=1,NDI
            DDSDDE(I,J)=D(I,J)
            IF (NLGEOM.NE.0) DDSDDE(I,J)=DDSDDE(I,J)-SIG(I)
         END DO
      END DO

      IF (NSHR.GT.0) THEN
         DO J=1,NSHR
            DO I=1,NSHR
               DDSDDE(I+NDI,J+NDI)=D(I+3,J+3)
            END DO

            DO I=1,NDI
               DDSDDE(I,J+NDI)=D(I,J+3)
               DDSDDE(J+NDI,I)=D(J+3,I)
               IF (NLGEOM.NE.0)
     2            DDSDDE(J+NDI,I)=DDSDDE(J+NDI,I)-SIG(J+NDI)
            END DO
         END DO
      END IF

C-----  Jacobian matrix: plastic part (slip)
      DO J=1,NDI
         DO I=1,NDI
            DO K=1,NSLPTL
               DDSDDE(I,J)=DDSDDE(I,J)-DDEMSD(I,K)*DDGDDE(K,J)
            END DO
         END DO
      END DO

      IF (NSHR.GT.0) THEN
         DO J=1,NSHR

            DO I=1,NSHR
               DO K=1,NSLPTL
                  DDSDDE(I+NDI,J+NDI)=DDSDDE(I+NDI,J+NDI)-
     2                                DDEMSD(I+3,K)*DDGDDE(K,J+NDI)
               END DO
            END DO

            DO I=1,NDI
               DO K=1,NSLPTL
                  DDSDDE(I,J+NDI)=DDSDDE(I,J+NDI)-
     2                            DDEMSD(I,K)*DDGDDE(K,J+NDI)
                  DDSDDE(J+NDI,I)=DDSDDE(J+NDI,I)-
     2                            DDEMSD(J+3,K)*DDGDDE(K,I)
               END DO
            END DO

         END DO
      END IF

        DO J=1,NTENS
            DO I=1,NTENS
                DDSDDE(I,J)=DDSDDE(I,J)/(1.+DEV)
            END DO
        END DO



C-----  Save solutions (without iteration):
C            Shear strain-rate in a slip system FSLIP1
C            Current strength in a slip system GSLP1
C            Shear strain in a slip system GAMMA1
C            Resolved shear SIG in a slip system TAUSP1
C            Normal to a slip plane SPNOR1
C            Slip direction SPDIR1
C            SIG STRES1
C            Jacobian matrix DDSDE1
C
         IF (NITRTN.EQ.0) THEN

            DO J=1,ND
               FSLIP1(J)=FSLIP(J)
               CRSS1(J)=CRSS(J)
               GAMMA1(J)=HSV(12+J)
               TAUSP1(J)=HSV(24+J)
               DO I=1,3
                  SPNOR1(I,J)=SLPNOR(I,J)
                  SPDIR1(I,J)=SLPDIR(I,J)
               END DO
            END DO

            DO J=1,NTENS
               STRES1(J)=SIG(J)
               DO I=1,NTENS
                  DDSDE1(I,J)=DDSDDE(I,J)
               END DO
            END DO

         END IF

C-----  Increments of SIG DSOLD, and solution dependent state 
C     variables DGAMOD, DTAUOD, DGSPOD, DSPNRO, DSPDRO (for the next 
C     iteration)
C
         DO I=1,NTENS
            DSOLD(I)=DSTRES(I)
         END DO

         DO J=1,NSLPTL
            DGAMOD(J)=DGAMMA(J)
            DTAUOD(J)=DTAUSP(J)
            DGSPOD(J)=DGSLIP(J)
            DO I=1,3
               DSPNRO(I,J)=DSPNOR(I,J)
               DSPDRO(I,J)=DSPDIR(I,J)
            END DO
         END DO

C-----  Check if the iteration solution converges
         IDBACK=0
         ID=0
            DO J=1,ND
               ID=ID+1
               X=TAU(ID)/CRSS(ID)
               RESIDU=THETA*DT1*F(X,SLPN,SLPREF)+
     2                DT1*(1.0-THETA)*FSLIP1(ID)-DGAMMA(ID)
               IF (ABS(RESIDU).GT.GAMERR) IDBACK=1
            END DO
C-----  Decision
        IF (NITRTN.LT.ITRMAX) THEN
            IF(IDBACK.EQ.1)THEN ! Not convergence, continue iter
                CALL ITERATION (GAMMA, TAU, CRSS, GAMCUM, 
     2                      GAMTOL, ND, CM(25), DGAMOD, DHDGDG)
            GO TO 1000
            ELSE ! Convergence, save result
                HSV(1:12)=CRSS(1:12)
                HSV(13:24)=GAMMA(1:12)
                HSV(25:36)=TAU(1:12)
                ID=0
                DO J=1,12
                    DO I=1,3
                        ID=ID+1
                        HSV(36+ID)=SLPNOR(I,J)
                        HSV(72+ID)=SLPDIR(I,J)
                    ENDDO
                ENDDO
            ENDIF
        ELSE ! Over the limit of step, use initial guess result
            PRINT *,'WARNING: EXCEED THE ITERATION!'
            DO J=1,NTENS
               SIG(J)=STRES1(J)
               DO I=1,NTENS
                  DDSDDE(I,J)=DDSDE1(I,J)
               END DO
            END DO
            IDNOR=36
            IDDIR=72
            DO J=1,NSLPTL
               HSV(J)=CRSS1(J)
               HSV(12+J)=GAMMA1(J)
               HSV(24+J)=TAUSP1(J)

               DO I=1,3
                  IDNOR=IDNOR+1
                  HSV(IDNOR)=SPNOR1(I,J)

                  IDDIR=IDDIR+1
                  HSV(IDDIR)=SPDIR1(I,J)
               END DO
            END DO

        ENDIF

        




C-----  Total cumulative shear strains on all slip systems (sum of the 
C       absolute values of shear strains in all slip systems)
CFIX--  Total cumulative shear strains on each slip system (sum of the 
CFIX    absolute values of shear strains in each individual slip system)
C
      DO I=1,ND
        GAMCUM(I)=GAMCUM(I)+ABS(DGAMMA(I))
        GAMTOL=GAMTOL+ABS(DGAMMA(I))
      END DO
      HSV(109:120)=GAMCUM(1:12)
      HSV(121)=GAMTOL

C     GIVEN THE DDSDE TO THE HSV
      IDX=NHSV-4
      DO I=1,6
            DO J=1,6
                  POS=IDX-((I-1)*6+(J-1))
                  HSV(POS)=DDSDDE(I,J)
            ENDDO
      ENDDO

      RETURN


      end subroutine


C----------------------------------------------------------------------


C----------------------------------------------------------------------



C----------------------------------------------------------------------


      SUBROUTINE STRAINRATE (GAMMA, TAU, GSLIP, NSLIP, FSLIP, 
     2                       DFDXSP, SLPN,SLPREF)

C-----  This subroutine calculates the shear strain-rate in each slip 
C     system for a rate-dependent single crystal.  The POWER LAW 
C     relation between shear strain-rate and resolved shear SIG 
C     proposed by Hutchinson, Pan and Rice, is used here.

C-----  The power law exponents are assumed the same for all slip 
C     systems in each set, though they could be different from set to 
C     set, e.g. <110>{111} and <110>{100}.  The strain-rate coefficient
C     in front of the power law form are also assumed the same for all 
C     slip systems in each set. 

C-----  Users who want to use their own constitutive relation may 
C     change the function subprograms F and its derivative DFDX, 
C     where F is the strain hardening law, dGAMMA/dt = F(X), 
C     X=TAU/GSLIP.  The parameters characterizing F are passed into 
C     F and DFDX through array PROP.

C-----  Function subprograms:
C
C       F    -- User-supplied function subprogram which gives shear 
C               strain-rate for each slip system based on current 
C               values of resolved shear SIG and current strength
C
C       DFDX -- User-supplied function subprogram dF/dX, where x is the
C               ratio of resolved shear SIG over current strength

C-----  Variables:
C
C     GAMMA  -- shear strain in each slip system at the start of time 
C               step  (INPUT)
C     TAU -- resolved shear SIG in each slip system (INPUT)
C     GSLIP  -- current strength (INPUT)
C     NSLIP  -- number of slip systems in this set (INPUT)
C
C     FSLIP  -- current value of F for each slip system (OUTPUT)
C     DFDXSP -- current value of DFDX for each slip system (OUTPUT)
C
C     PROP   -- material constants characterizing the strain hardening 
C               law (INPUT)
C
C               For the current power law strain hardening law 
C               PROP(1) -- power law hardening exponent
C               PROP(1) = infinity corresponds to a rate-independent 
C               material
C               PROP(2) -- coefficient in front of power law hardening


C-----  Use single precision on cray
C
      IMPLICIT REAL*8 (A-H,O-Z)
      EXTERNAL F, DFDX
      REAL SLPN,SLPREF
      DIMENSION GAMMA(NSLIP), TAU(NSLIP), GSLIP(NSLIP), 
     2          FSLIP(NSLIP), DFDXSP(NSLIP)

      DO I=1,NSLIP
         X=TAU(I)/GSLIP(I)
         FSLIP(I)=F(X,SLPN,SLPREF)
         DFDXSP(I)=DFDX(X,SLPN,SLPREF)
      END DO

      RETURN
      END


C-----------------------------------


C-----  Use single precision on cray
C
           REAL*8 FUNCTION F(X,SLPN,SLPREF)

C-----     User-supplied function subprogram which gives shear 
C        strain-rate for each slip system based on current values of 
C        resolved shear SIG and current strength
C
C-----  Use single precision on cray
C
           IMPLICIT REAL*8 (A-H,O-Z)
           REAL SLPN,SLPREF

           F=SLPREF*(ABS(X))**SLPN*DSIGN(1.D0,X)

           RETURN
           END


C-----------------------------------


C-----  Use single precision on cray
C
           REAL*8 FUNCTION DFDX(X,SLPN,SLPREF)

C-----     User-supplied function subprogram dF/dX, where x is the 
C        ratio of resolved shear SIG over current strength

C-----  Use single precision on cray
C
           IMPLICIT REAL*8 (A-H,O-Z)
           REAL SLPN,SLPREF

           DFDX=SLPN*SLPREF*(ABS(X))**(SLPN-1.)

           RETURN
           END



CFIXA
      SUBROUTINE LATENTHARDEN (GAMMA, TAU, GSLIP, GAMCUM, GAMTOL, 
     2                         PROP, ND, H)
CFIXB

C-----  This subroutine calculates the current self- and latent-
C     hardening moduli for all slip systems in a rate-dependent single 
C     crystal.  Two kinds of hardening law are used here.  The first 
C     law, proposed by Asaro, and Pierce et al, assumes a HYPER SECANT 
C     relation between self- and latent-hardening moduli and overall 
C     shear strain.  The Bauschinger effect has been neglected.  The 
C     second is Bassani's hardening law, which gives an explicit 
C     expression of slip interactions between slip systems.  The 
C     classical three stage hardening for FCC single crystal could be 
C     simulated.

C-----  The hardening coefficients are assumed the same for all slip 
C     systems in each set, though they could be different from set to 
C     set, e.g. <110>{111} and <110>{100}.

C-----  Users who want to use their own self- and latent-hardening law 
C     may change the function subprograms HSELF (self hardening) and 
C     HLATNT (latent hardening).  The parameters characterizing these 
C     hardening laws are passed into HSELF and HLATNT through array 
C     PROP.


C-----  Function subprograms:
C
C       HSELF  -- User-supplied self-hardening function in a slip 
C                 system
C
C       HLATNT -- User-supplied latent-hardening function

C-----  Variables:
C
C     GAMMA  -- shear strain in all slip systems at the start of time 
C               step  (INPUT)
C     TAU -- resolved shear SIG in all slip systems (INPUT)
C     GSLIP  -- current strength (INPUT)
CFIX  GAMCUM -- total cumulative shear strains on each individual slip system 
CFIX            (INPUT)
C     GAMTOL -- total cumulative shear strains over all slip systems 
C               (INPUT)
C     NSLIP  -- number of slip systems in each set (INPUT)
C     NSLPTL -- total number of slip systems in all the sets (INPUT)
C     NSET   -- number of sets of slip systems (INPUT)
C
C     H      -- current value of self- and latent-hardening moduli 
C               (OUTPUT)
C               H(i,i) -- self-hardening modulus of the ith slip system
C                         (no sum over i)
C               H(i,j) -- latent-hardening molulus of the ith slip 
C                         system due to a slip in the jth slip system 
C                         (i not equal j)
C
C     PROP   -- material constants characterizing the self- and latent-
C               hardening law (INPUT)
C
C               For the HYPER SECANT hardening law 
C               PROP(2) -- initial hardening modulus H0 in the ith 
C                            set of slip systems
C               PROP(3) -- saturation SIG TAUs in the ith set of  
C                            slip systems
C               PROP(4) -- initial critical resolved shear SIG 
C                            TAU0 in the ith set of slip systems
C               PROP(5) -- ratio of latent to self-hardening Q in the
C                            ith set of slip systems
C
C     ND     -- leading dimension of arrays defined in subroutine UMAT 
C               (INPUT) 


C-----  Use single precision on cray
C
      IMPLICIT REAL*8 (A-H,O-Z)
CFIXA
      DIMENSION GAMMA(ND), TAU(ND), GAMCUM(ND),
     2          GSLIP(ND), PROP(16), 
     3          H(ND,ND)
      REAL TERM1,TERM2
CFIXB

C-----  CHECK=0   --  HYPER SECANT hardening law
C       otherwise --  Bassani's hardening law

        TERM1=PROP(2)*GAMTOL/(PROP(3)-PROP(4))
        TERM2=2.*EXP(-TERM1)/(1.+EXP(-2.*TERM1))
        ISELF=0
         DO J=1,ND
            ISELF=ISELF+1
            DO LATENT=1,ND
               IF (LATENT.EQ.ISELF) THEN
                  H(LATENT,ISELF)=PROP(2)*TERM2**2
               ELSE
                  H(LATENT,ISELF)=PROP(2)*TERM2**2*PROP(5)
               END IF
            END DO

         END DO

      RETURN
      END



C----------------------------------------------------------------------

CFIXA
      SUBROUTINE ITERATION (GAMMA, TAU, GSLIP, GAMCUM, GAMTOL, 
     2                      ND, PROP, DGAMOD, 
     3                      DHDGDG)
CFIXB

C-----  This subroutine generates arrays for the Newton-Rhapson 
C     iteration method.

C-----  Users who want to use their own self- and latent-hardening law 
C     may change the function subprograms DHSELF (self hardening) and 
C     DHLATN (latent hardening).  The parameters characterizing these 
C     hardening laws are passed into DHSELF and DHLATN through array 
C     PROP.


C-----  Function subprograms:
C
C       DHSELF -- User-supplied function of the derivative of self-
C                 hardening moduli
C
C       DHLATN -- User-supplied function of the derivative of latent-
C                 hardening moduli

C-----  Variables:
C
C     GAMMA  -- shear strain in all slip systems at the start of time 
C               step  (INPUT)
C     TAU -- resolved shear SIG in all slip systems (INPUT)
C     GSLIP  -- current strength (INPUT)
CFIX  GAMCUM -- total cumulative shear strains on each individual slip system 
CFIX            (INPUT)
C     GAMTOL -- total cumulative shear strains over all slip systems 
C               (INPUT)
C     NSLPTL -- total number of slip systems in all the sets (INPUT)
C     NSET   -- number of sets of slip systems (INPUT)
C     NSLIP  -- number of slip systems in each set (INPUT)
C     ND     -- leading dimension of arrays defined in subroutine UMAT 
C               (INPUT) 
C
C     PROP   -- material constants characterizing the self- and latent-
C               hardening law (INPUT)
C
C               For the HYPER SECANT hardening law 
C               PROP(2,i) -- initial hardening modulus H0 in the ith 
C                            set of slip systems
C               PROP(3,i) -- saturation SIG TAUs in the ith set of  
C                            slip systems
C               PROP(4,i) -- initial critical resolved shear SIG 
C                            TAU0 in the ith set of slip systems
C               PROP(5,i) -- ratio of latent to self-hardening Q in the
C                            ith set of slip systems
C
C-----  Arrays for iteration:
C
C       DGAMOD (INPUT)
C
C       DHDGDG (OUTPUT)
C

C-----  Use single precision on cray
C
      IMPLICIT REAL*8 (A-H,O-Z)
CFIXA
      REAL ND
      DIMENSION GAMMA(ND), TAU(ND), GAMCUM(ND),
     2          GSLIP(ND), PROP(16), 
     3          DGAMOD(ND), DHDGDG(ND,ND)
CFIXB

C-----  CHECK=0   --  HYPER SECANT hardening law
C       otherwise --  Bassani's hardening law

      TERM1=PROP(2)*GAMTOL/(PROP(3)-PROP(4))
      TERM2=2.*EXP(-TERM1)/(1.+EXP(-2.*TERM1))
      TERM3=PROP(2)/(PROP(3)-PROP(4))*DSIGN(1.D0,GAMMA(KDERIV))
      ISELF=0

         DO J=1,ND
            ISELF=J

            DO KDERIV=1,ND
               DHDGDG(ISELF,KDERIV)=0.

               DO LATENT=1,ND
                  IF (LATENT.EQ.ISELF) THEN
                     DHDG=-2.*PROP(2)*TERM2**2*TANH(TERM1)*TERM3
                  ELSE
                     DHDG=-2.*PROP(2)*TERM2**2*TANH(TERM1)*TERM3*PROP(5)
                  END IF
                  DHDGDG(ISELF,KDERIV)=DHDGDG(ISELF,KDERIV)+
     2                                 DHDG*ABS(DGAMOD(LATENT))
               END DO

            END DO
         END DO


      RETURN
      END


C----------------------------------------------------------------------

      SUBROUTINE CALDDEMSD(D,SLPDEF,SLPSPN,SIG,NDI,NSHR,
     1 NSLPTL,NLGEOM,DDEMSD)
C-----  Double dot product of elastic moduli tensor with the slip 
C     deformation tensor (Schmid factors) plus, only for finite 
C     rotation, the dot product of slip spin tensor with the SIG: 
C     DDEMSD
        IMPLICIT NONE
        INTEGER I,J,K
        INTEGER NDI,NSHR,NSLPTL
        INTEGER NLGEOM
        DOUBLE PRECISION D(6,6),SLPDEF(6,NSLPTL),SLPSPN(3,NSLPTL)
        DOUBLE PRECISION DDEMSD(6,6)
        DOUBLE PRECISION SIG(6)

        DO J=1,NSLPTL
            DO I=1,6
               DDEMSD(I,J)=0.
               DO K=1,6
                  DDEMSD(I,J)=DDEMSD(I,J)+D(K,I)*SLPDEF(K,J)
               END DO
            END DO
         END DO
   
         IF (NLGEOM.NE.0) THEN
            DO J=1,NSLPTL
   
               DDEMSD(4,J)=DDEMSD(4,J)-SLPSPN(1,J)*SIG(1)
               DDEMSD(5,J)=DDEMSD(5,J)+SLPSPN(2,J)*SIG(1)
   
               IF (NDI.GT.1) THEN
                  DDEMSD(4,J)=DDEMSD(4,J)+SLPSPN(1,J)*SIG(2)
                  DDEMSD(6,J)=DDEMSD(6,J)-SLPSPN(3,J)*SIG(2)
               END IF
   
               IF (NDI.GT.2) THEN
                  DDEMSD(5,J)=DDEMSD(5,J)-SLPSPN(2,J)*SIG(3)
                  DDEMSD(6,J)=DDEMSD(6,J)+SLPSPN(3,J)*SIG(3)
               END IF
   
               IF (NSHR.GE.1) THEN
                  DDEMSD(1,J)=DDEMSD(1,J)+SLPSPN(1,J)*SIG(NDI+1)
                  DDEMSD(2,J)=DDEMSD(2,J)-SLPSPN(1,J)*SIG(NDI+1)
                  DDEMSD(5,J)=DDEMSD(5,J)-SLPSPN(3,J)*SIG(NDI+1)
                  DDEMSD(6,J)=DDEMSD(6,J)+SLPSPN(2,J)*SIG(NDI+1)
               END IF
   
               IF (NSHR.GE.2) THEN
                  DDEMSD(1,J)=DDEMSD(1,J)-SLPSPN(2,J)*SIG(NDI+2)
                  DDEMSD(3,J)=DDEMSD(3,J)+SLPSPN(2,J)*SIG(NDI+2)
                  DDEMSD(4,J)=DDEMSD(4,J)+SLPSPN(3,J)*SIG(NDI+2)
                  DDEMSD(6,J)=DDEMSD(6,J)-SLPSPN(1,J)*SIG(NDI+2)
               END IF
   
               IF (NSHR.EQ.3) THEN
                  DDEMSD(2,J)=DDEMSD(2,J)+SLPSPN(3,J)*SIG(NDI+3)
                  DDEMSD(3,J)=DDEMSD(3,J)-SLPSPN(3,J)*SIG(NDI+3)
                  DDEMSD(4,J)=DDEMSD(4,J)-SLPSPN(2,J)*SIG(NDI+3)
                  DDEMSD(5,J)=DDEMSD(5,J)+SLPSPN(1,J)*SIG(NDI+3)
               END IF
   
            END DO
         END IF

        END SUBROUTINE
      
      SUBROUTINE CALSTRAIN(DGRAD,STRAIN)
         IMPLICIT NONE
         DOUBLE PRECISION DGRAD(3,3),DGRADT(3,3),STRAINMAT(3,3)
         DOUBLE PRECISION STRAIN(6)

         call matTranspose(DGRAD,3,3,DGRADT)
         call matInnProd(DGRAD,DGRADT,3,3,3,STRAINMAT)


         STRAIN(1)=0.5*(STRAINMAT(1,1)-1.)
         STRAIN(2)=0.5*(STRAINMAT(2,2)-1.)
         STRAIN(3)=0.5*(STRAINMAT(3,3)-1.)
         STRAIN(4)=0.5*STRAINMAT(1,2)
         STRAIN(5)=0.5*STRAINMAT(2,3)
         STRAIN(6)=0.5*STRAINMAT(1,3)

      END SUBROUTINE