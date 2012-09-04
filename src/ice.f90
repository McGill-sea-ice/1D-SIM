!*************************************************************************
!     program ice:
!       1D model that calculate the ice thickness (h), concentration (A) 
!       and ice velocity (u).
!       
!       momentum equation:  rho*h(u^n-u^n-1)/Deltat = f(u^n,h^n-1,A^n-1)
!                           This equation is solved implicitly for u^n
!                           (u). u^n-1 is the previous time step solution.
!
!       continuity equation:h^n = f(h^n-1, u^n)  
!                           The new value of h (and A) is obtained by 
!                           advecting h^n-1 with u^n. 
!       
!       author: JF Lemieux
!       version: 1.0 (20 april 2012)
!
!************************************************************************

program ice

  use size
  use rheology
  use forcing
  use properties
  use resolution
  use global_var
  use numerical
  use EVP_const
  use option
  
  implicit none

  logical :: p_flag, restart
  integer :: i, ii, ts, tsini, nstep, tsfin, k, s, Nmax_OL, solver, precond
  integer :: out_step(5), expnb, expres, ts_res
  integer, save :: Nfail ! nb of failures
  double precision :: e, rhoair, rhowater, Cdair, Cdwater
  double precision :: upts(1:nx+1)      ! u previous time step
  double precision :: tauair(1:nx+1)    ! tauair
  double precision :: b(1:nx+1)         ! b vector
  double precision :: zeta(0:nx+1), eta(0:nx+1), sigma(0:nx+1)
  double precision :: Cw(1:nx+1)
  double precision :: F_uk1(1:nx+1)
  double precision :: meanvalue, time1, time2, timecrap
  double precision :: L2norm, gamma_nl, nl_target, Eo

  out_step = 0
  sigma    = 0d0 ! initial stresses are zero
  Nfail    = 0

!------------------------------------------------------------------------
!     Input by user
!------------------------------------------------------------------------

  linear_drag    = .false.
  linear_viscous = .false. ! linear viscous instead of viscous-plastic
  constant_wind  = .true. ! T: 10m/s, F: spat and temp varying winds
  rep_closure    = .true. ! replacement closure (see Kreysher et al. 2000)
  implicit_solv  = .true. ! T: solvers 1, 2 or 3, F: EVP solver
  restart        = .false.

  solver     = 2        ! 1: Picard+SOR, 2: JFNK
  precond    = 1        ! precond for solver 2, 1: SOR, 2: EVP2

  Deltat     = 900d0   ! time step [s]
  nstep      = 200     ! lenght of the run in nb of time steps
  Nmax_OL    = 500

  if (implicit_solv) then
     N_sub = 25                        ! nb of subcycles for precond
     Deltate = 4d0                     ! EVP as a precond
     Eo    = 0.05d0                    ! Hunke 1997, eq (44)
  elseif (.not. implicit_solv) then
     N_sub = 900                       ! nb of subcycles
     Deltate    = Deltat / (N_sub*1d0) ! EVP as a solver
  endif

  T = 0.36d0*Deltat ! elast. damping time scale (Deltate < T < Deltat)

  omega      = 1.5d0    ! relax parameter for SOR
  tol_SOR    = 1d-06    ! tol for SOR solver
  maxiteSOR  = 10000     ! max nb of ite for SOR
  iteSOR_pre = 10       ! nb of iterations for the SOR precond
  maxiteGMRES= 900      ! max nb of ite for GMRES
  gamma_nl = 1d-03

  expnb      = 3
  expres     = 2
  ts_res     = 50 ! time level of restart (!!! watchout for Deltat !!!)
  out_step(1)= 100   

!------------------------------------------------------------------------ 
!     Set first time level depending on restart specifications                
!------------------------------------------------------------------------

  if (restart) then
     tsini = ts_res + 1
  else
     tsini = 1
  endif
  
  tsfin = tsini - 1 + nstep
  
!------------------------------------------------------------------------
!     Define a flag for the precond (T) or solver (F)
!------------------------------------------------------------------------

  p_flag = .true.
  if (implicit_solv) then
     if (solver .eq. 1) p_flag = .false.
  elseif (.not. implicit_solv) then
     print *, 'check this out one_or_zero!!!', one_or_zero
     one_or_zero = 0d0 ! set to zero to eliminate du/dt term (not du/dte)
     p_flag = .false.
  endif

!------------------------------------------------------------------------
!     Define Deltax and check CFL based on input by user
!------------------------------------------------------------------------

  if ( nx .eq. 100 ) then 
     Deltax   =  20d03  ! grid size [m], the domain is always 2000 km 
  elseif  ( nx .eq. 200 ) then
     Deltax   =  10d03            
  elseif  ( nx .eq. 400 ) then
     Deltax   =  5d03            
  else
     print *,  'Wrong grid size dimenion', nx
     STOP
  endif

  Deltax2 = Deltax ** 2

  if ( 1d0*Deltat .gt. Deltax ) then
     print *, 'CFL condition is not respected'
     stop
  endif

!------------------------------------------------------------------------
!     Define constants
!------------------------------------------------------------------------

  C          = 20d0         ! ice strength parameter (watchout no A for now)
  Pstar      = 27.5d03      ! ice compression strength parameter
  e          = 2d0          ! ratio long to short axis of ellipse
  e_2        = 1/(e**2d0)   !
  alpha      = sqrt(1d0 + e_2)
  alpha2     = 1d0 + e_2
  zetamin    = 0d0          ! minimum bulk viscosity 
  zmax_par   = 5d08         ! 2x2.5d08 (Hib, 1979). p is p/2 in code  

  Cdair      = 1.2d-03      ! air-ice drag coeffient 
  Cdwater    = 5.5d-03      ! water-ice drag coeffient
  rhoair     = 1.3d0        ! air density
  rho        = 900d0        ! ice density
  rhowater   = 1026d0       ! water density

  Cda        = rhoair   * Cdair
  Cdw        = rhowater * Cdwater

  Estar      = 2d0*Eo*rho*Deltax2 / (Deltate**2d0) ! Hunke 1997, eq (44)

!------------------------------------------------------------------------
!     initial conditions
!------------------------------------------------------------------------

  call ini_get (restart, expres, ts_res)
  
  do ts = tsini, tsfin ! first u calc is at t = 1*Deltat and h at 1.5*Deltat
     
     call cpu_time(timecrap)
     call cpu_time(time1)

     upts = u

!------- Create forcing vector b (independent of u) ----------------------

     call wind_forcing (tauair, ts)
     call ice_strength () ! Pp_half is Pp/2 where Pp is the ice strength

!------- Solves NL mom eqn at specific time step with solver1, 2 or 3
!        F(u) = A(u)u - b(u) = 0, u is the solution vector
!------- Begining of outer loop (OL) or Newton iterations ----------------

     if (implicit_solv) then

     do k = 1, Nmax_OL 
        
        call viscouscoefficient (u, zeta, eta) ! u is u^k-1
        call bvect (tauair, upts, b)
        call Cw_coefficient (u, Cw)            ! u is u^k-1
        call Fu (u, zeta, eta, Cw, b, F_uk1)   ! u is u^k-1

        L2norm = sqrt(DOT_PRODUCT(F_uk1,F_uk1))
        print *, 'L2 norm after k ite is', ts, k-1, L2norm
        if (k .eq. 1) nl_target = gamma_nl*L2norm
        if (L2norm .lt. nl_target) exit

        if (solver .eq. 1) then
           call SOR (b, u, zeta, eta, Cw, p_flag, ts)
        elseif (solver .eq. 2) then
           call prepFGMRES_NK(u, F_uk1, zeta, eta, Cw, upts, tauair, &
                              L2norm, k, ts, precond)
        endif

        if (k .eq. Nmax_OL) Nfail = Nfail + 1

     enddo

     else ! EVP1 solver
        
        call bvect (tauair, upts, b) ! b does not include dP/dx for EVP solver

! watchout b includes rho*h*upts/dt
!        CALL EVP1(b, u, zeta, eta, Cw, .false., ts)

        call viscouscoefficient (u, zeta, eta) ! u is u^k-1
        call Cw_coefficient (u, Cw) 
        CALL EVP2solver(b, u, zeta, eta, Cw, ts)

     endif

      call cpu_time(time2)
      print *, 'cpu time = ', time2-time1

     call upwind_adv ! advection scheme for tracers
!     call meantracer(h,meanvalue)

!------------------------------------------------------------------------
!     output results
!------------------------------------------------------------------------

     if (ts .eq. out_step(1) .or. ts .eq. out_step(2) .or. &
         ts .eq. out_step(3) .or. ts .eq. out_step(4) .or. &
         ts .eq. out_step(5)) then
        print *, 'outputting results'
        call output_results(ts, expnb, zeta, eta)
        call output_file(e, gamma_nl, solver, precond, expnb)
     endif

!------------------------------------------------------------------------
!     calculate diagnostics and check stability conditions            
!------------------------------------------------------------------------

     call check_neg_vel(u)
     call minmaxtracer(h,1)
     call minmaxtracer(A,2)
!     call minmaxtracer(zeta,3)
!     call stab_condition(Cw, zeta)

  enddo
  
  if (solver .eq. 1) then
     print *, 'Nb of failures of Picard: ', Nfail
  elseif (solver .eq. 2) then
     print *, 'Nb of failures of JFNK: ', Nfail
  endif

end program ice
      

