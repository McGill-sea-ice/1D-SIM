!****************************************************************************
! calculates utp = M^-1(rhs) where rhs is wk1. du=utp= 0 is the initial
! guess when used as a precond. utp is the solution sent back. 
! see p. 3-58 and 3-59
!****************************************************************************

subroutine EVP2Bprecond (rhs, utp, zeta, eta, Cw, ts, gamma_nl, upts, uk1)
  use size
  use resolution
  use properties
  use global_var
  use numerical
  use rheology
  use EVP_const

  implicit none
      
  integer :: i, s
  integer, intent(in) :: ts
  double precision, intent(in)  :: rhs(1:nx+1), upts(1:nx+1), uk1(1:nx+1)
  double precision, intent(inout) :: utp(1:nx+1)
  double precision :: Cw(1:nx+1), F_uk1(1:nx+1)
  double precision :: sigma(0:nx+1), zeta(0:nx+1), eta(0:nx+1), h_at_u(0:nx+1)
  double precision :: B1, gamma, right, left, L2norm, gamma_nl, nl_target

  left  = 1d0/(Deltate) + ( 1d0 )/(T*alpha2) ! no change during subcycling

!------------------------------------------------------------------------
! initial value of sigma and utp
!------------------------------------------------------------------------
  
  utp = 0d0   ! initial guess for precond (in fact du)
  sigma = 0d0 ! initial guess for precond (in fact dsigma)

  do i = 1, nx ! could be improved

     h_at_u(i) = ( h(i) + h(i-1) ) / 2d0 ! no change during subcycling
      
  enddo

!------------------------------------------------------------------------
! beginning of subcycling loop 
!------------------------------------------------------------------------

  do s = 1, N_sub ! subcycling loop

!------------------------------------------------------------------------
! time step sigma
!------------------------------------------------------------------------
 
     do i = 1, nx ! for tracer points

        right = (zeta(i)/ T )*( utp(i+1) - utp(i) ) / Deltax &
              + sigma(i) / Deltate

        sigma(i) = right / left

     enddo

!------------------------------------------------------------------------
! time step velocity
!------------------------------------------------------------------------

     do i = 2, nx
     
!------------------------------------------------------------------------
!     B1: air drag
!------------------------------------------------------------------------
        
        B1 = rhs(i)

!------------------------------------------------------------------------
!     B1: rho*h*du^p-1 / Deltate
!------------------------------------------------------------------------

        B1 = B1 + ( rho * h_at_u(i) * utp(i) ) / Deltate

!------------------------------------------------------------------------
!     B1: rho*h*(u^k-1-u^n-1) / Deltat
!------------------------------------------------------------------------
 
        B1 = B1 + ( rho * h_at_u(i) * (uk1(i)-upts(i))) / Deltat

!------------------------------------------------------------------------
!     B1: dsigma/dx
!------------------------------------------------------------------------
     
        B1 = B1 + ( sigma(i) - sigma(i-1) )/ Deltax 
     
!------------------------------------------------------------------------
!     advance u from u^p-1 to u^p
!------------------------------------------------------------------------

        gamma = rho * h_at_u(i) / Deltate + Cw(i)
        
        utp(i) = B1 / gamma

     enddo

  enddo

  return
end subroutine EVP2Bprecond






