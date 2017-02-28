MODULE shallow_water
use size
! etaw    : sea surface height [m]
! uice : ice velocity               [m/s]

!   h(0)--u(1)--h(1)--u(2)--...u(n)--h(n)--u(n+1)--h(n+1)
!   h(0) and h(n+1) are used for open bcs

  IMPLICIT NONE

  DOUBLE PRECISION, allocatable :: etawn1(:), etawn2(:)
  DOUBLE PRECISION, allocatable :: uwn1(:), uwn2(:)
  DOUBLE PRECISION :: Hw, bw, Cdairw ! Cdair:over ice, Cdairw: over water
  LOGICAL :: implicitDrag
  
END MODULE shallow_water

MODULE MOMeqSW_output
use size

  IMPLICIT NONE

  DOUBLE PRECISION, allocatable :: duwdt(:), gedetawdx(:)
  DOUBLE PRECISION, allocatable :: tauiw(:), tauaw(:), buw(:)
!------------------------------------------------------------------------
!     Subroutine for advecting etaw
!------------------------------------------------------------------------
  
END MODULE MOMeqSW_output

subroutine advect_etaw (etaw)
  
  use size
  use resolution
  use shallow_water
  
  implicit none
  
  double precision, intent(inout) :: etaw(0:nx+1)
  double precision :: RHS, Htleft, Htright ! Ht=Hw+etaw
  integer :: i
  
  ! leapfrog approach with centered (n1) term on the RHS
  
  do i = 1, nx
  
   Htleft  = Hw + ( etawn1(i-1) + etawn1(i) ) /2d0
   Htright = Hw + ( etawn1(i+1) + etawn1(i) ) /2d0
   RHS     = -1d0*( uwn1(i+1)*Htright - uwn1(i)*Htleft ) / Deltax
   etaw(i) = etawn2(i) + 2d0*Deltat*RHS
  
  enddo
  
end subroutine advect_etaw

subroutine momentum_uw (tauair, Cdair, Cw, Atp, utp)
  
  use size
  use resolution
  use properties
  use global_var
  use shallow_water
  use MOMeqSW_output
  
  implicit none
  
  double precision, intent(in) :: tauair(1:nx+1), Cw(1:nx+1), Cdair
  double precision, intent(in) :: Atp(0:nx+1), utp(1:nx+1)
  double precision :: invtwodt, RHS, LHS, Ht_at_u, A_At_u, Diocoeff ! Ht=Hw+etaw
  integer :: i
  
  invtwodt = 1d0 / ( 2d0*Deltat )
  ! leapfrog approach with centered (n1) term on the RHS
  
  do i = 2, nx
  
   RHS=0d0
   LHS=0d0
   RHS = RHS + invtwodt * uwn2(i)                        ! part of inertial term
   RHS = RHS - ge * ( etawn1(i) - etawn1(i-1) ) / Deltax ! pressure gradient
!   RHS = RHS - bw * uwn1(i)                              ! basal friction
   
   A_at_u = ( A(i) + A(i-1) ) / 2d0  
   Ht_at_u = Hw + ( etawn1(i) + etawn1(i-1) ) / 2d0 
   RHS = RHS + ( 1d0 - A_at_u ) * Cdairw * tauair(i) / ( Cdair * Ht_at_u * rhowater ) 
   ! rescaled if Cdairw .ne. Cdair
   
   Diocoeff = ( A_At_u * Cw(i) ) / ( Ht_at_u * rhowater )
   
   if (implicitDrag) then ! basal friction is always implicit (as in NEMO, FD)
    LHS = invtwodt + bw + Diocoeff
    RHS = RHS + Diocoeff * utp(i)
   else
    LHS = invtwodt + bw   ! basal friction is always implicit (as in NEMO, FD)
    RHS = RHS - Diocoeff * ( uwn1(i) - utp(i) )
   endif
   
   uw(i) = RHS / LHS
  
!----- MOM eq terms...just for outputs ---------
   duwdt(i)= invtwodt * ( uw(i) - uwn2(i) )
   gedetawdx(i) = - ge * ( etawn1(i) - etawn1(i-1) ) / Deltax
   tauaw(i) = ( 1d0 - A_at_u ) * Cdairw * tauair(i) / ( Cdair * Ht_at_u * rhowater ) 
   if (implicitDrag) then
    tauiw(i)= -1d0 * Diocoeff * ( uw(i) - utp(i) )
   else
    tauiw(i)= -1d0 * Diocoeff * ( uwn1(i) - utp(i) )
   endif
   buw(i) = -1d0 * bw * uw(i)
!-----------------------------------------------
  
  enddo
  
end subroutine momentum_uw