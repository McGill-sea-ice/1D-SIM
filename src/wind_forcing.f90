! defined at the u location

subroutine wind_forcing (tauair, ts)

  use size
  use forcing
  use resolution
  use option

  implicit none
     
  integer :: i
  integer, intent(in) :: ts
  double precision :: period, modulation, pi, apar
  double precision, intent(out) :: tauair(1:nx+1) ! air drag

  period = 6d0*3600d0 ! period of cos in seconds (set to 3 days)
  pi = 3.14159265d0
  apar = 6d0*3600d0

  tauair(1)    = 0d0 ! close bc
  tauair(nx+1) = 0d0 ! close bc

    if (constant_wind) then

       do i = 2, nx ! with apar = 6*3600, tauair is (1-e^-2) after 12 hours.
          tauair(i) = Cda * abs(uwind)*uwind
!	tauair(i) = (Cda * abs(uwind)*uwind)*(1d0-exp(-1d0*ts*Deltat/apar)) ! at n       
       enddo
!       print *, 'tauair', ts, 100d0*tauair(50)/(Cda * abs(uwind)*uwind)
    else
	modulation = sin(2*pi*ts*Deltat/period)
       
       do i = 2, nx
          tauair(i) = modulation * Cda * (uwind)**2d0
       enddo

    endif

  return
end subroutine wind_forcing






