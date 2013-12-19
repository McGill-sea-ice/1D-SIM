MODULE rheology
!
! C : ice strength parameter
! Pstar : ice compression strength parameter
! ell_2 : 1/ellipticity**2
! Tfrac: for tensile strength, T = Tfrac x P
  IMPLICIT NONE
  DOUBLE PRECISION :: C, Pstar, alpha, alpha2, Tfrac
  DOUBLE PRECISION :: e_2, small2

END MODULE rheology

MODULE properties

  IMPLICIT NONE
  DOUBLE PRECISION :: rho

END MODULE properties

MODULE forcing

  IMPLICIT NONE
  DOUBLE PRECISION :: Cda, Cdw, small1

END MODULE forcing

MODULE resolution

  IMPLICIT NONE
  DOUBLE PRECISION :: Deltax, Deltax2
  DOUBLE PRECISION :: Deltat, DtoverDx

END MODULE resolution

MODULE numerical

  IMPLICIT NONE
  INTEGER :: N_sub, maxiteSOR, maxiteGMRES, iteSOR_pre
  DOUBLE PRECISION :: T
  DOUBLE PRECISION :: omega, tol_SOR, dropini

END MODULE numerical

