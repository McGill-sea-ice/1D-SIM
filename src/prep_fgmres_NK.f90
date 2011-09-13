
      subroutine prepFGMRES_NK(uk1, F_uk1, zeta, eta, Cw, b, tauair, &
                               inires, k, ts, precond, upts)
        use size
        use numerical
        
      implicit none

      integer :: icode, iter, iout, tot_its, i
      integer, intent(in) ::  k, ts, precond

      double precision, intent(inout) :: uk1(1:nx+1)
      double precision, intent(in)  :: F_uk1(1:nx+1), b(1:nx+1), upts(1:nx+1)
      double precision, intent(in)  :: inires
      double precision, intent(in)  :: zeta(0:nx+1), eta(0:nx+1)
      double precision, intent(in)  :: Cw(1:nx+1)
      double precision, intent(in) :: tauair(1:nx+1) 
      double precision :: du(1:nx+1), rhs(1:nx+1)
      double precision :: vv(1:nx+1,img1), wk(1:nx+1,img)!, Funeg(1:nx+1)
      double precision :: wk1(1:nx+1), wk2(1:nx+1)
      double precision :: eps, eta_e, eta_e_ini, epsilon

!      double precision  res_t, eta_e, eta_e_ini, epsilon, phi_e, alp_e

!------------------------------------------------------------------------
!     This routine solves J(u)du = -F(u) where u = u^k, du = du^k using the
!     Jacobian free Newton Krylov method. The Krylov method is the precon-
!     ditioned FGMRES method. The usefull references are:
!
!     Knoll and Keyes, J.of.Comput.Physics, 2004.
!     Eisenstat and Walker, SIAM J.Optimization, 1994.
!     Eisenstat and Walker, SIAM J.Sci.Comput., 1996.
!
!------------------------------------------------------------------------

!------------------------------------------------------------------------
!     Making of the RHS vector : -F(uk1) and calculation of res norm
!------------------------------------------------------------------------

      rhs = -1d0*F_uk1 ! mult by -1 because we solve Jdu = -F(u)

!------------------------------------------------------------------------
!     Initial guess vector: because we solve for du and du is just a 
!     correction, we set the initial guess to zero
!------------------------------------------------------------------------

      du = 0d0

!------------------------------------------------------------------------
!     Choosing the forcing term (eta_e)
!------------------------------------------------------------------------

!      res_t     = 1d-02 ! transition between fast and slow phase
      eta_e_ini = 0.999999d0
!      phi_e     = 1d0
!      alp_e     = 1d0 !      alp_e = (1d0 + 5d0**0.5d0)/2d0 !2d0
 
!      if (k .eq. 1) then

      eta_e = eta_e_ini

    if (ts .gt. 10) then
!      if (k .lt. 20) then
!         eta_e = eta_e_ini
!      else
         eta_e = 0.01d0
!         print * ,'dudeman'
!      endif
      endif
!      elseif (k .gt. 1 .and. res .gt. res_t) then

!         eta_e = eta_e_ini

!      else
!         eta_e = phi_e * (res/resk_1)**alp_e ! Eisenstat, 1996, equ.(2.6)
!         eta_e = min(eta_e_ini,eta_e)
!         eta_e = max(0.3d0,eta_e)
!      endif         

!      resk_1 = res 

!      print *, 'initial norm is', k, res, eta_e

!------------------------------------------------------------------------
!      Begining of FGMRES method    
!------------------------------------------------------------------------

      eps = eta_e * inires ! setting the tolerance for fgmres

      iout   = 0    ! set  higher than 0 to have res(ite)

      icode = 0

 10   CONTINUE
      
      call fgmres (nx+1,img,rhs,du,iter,vv,wk,wk1,wk2, &
                   eps,maxiteGMRES,iout,icode,tot_its)

      IF ( icode == 1 ) THEN
!         CALL identity (wk1,wk2)
         if (precond .eq. 1) then
            CALL SOR (wk1, wk2, zeta, eta, Cw, .true., ts)
         elseif (precond .eq. 2) then
!            CALL EVP1Bprecond(wk1, wk2, zeta, eta, Cw, ts)
            CALL EVP2Dprecond(wk1, wk2, zeta, eta, Cw, ts)
         endif

         GOTO 10
      ELSEIF ( icode >= 2 ) THEN
         epsilon = 1d-06 ! approximates Jv below
         call JacfreeVec (wk1, wk2, F_uk1, uk1, b, epsilon) 
         GOTO 10
      ENDIF

!------------------------------------------------------------------------
!      End of FGMRES method    
!------------------------------------------------------------------------

      if (tot_its .eq. maxiteGMRES) then
         print *,'WARNING: FGMRES has not converged'
         print*, 'Please check the precond relaxation param (wlsor or wsor).'
         stop
      endif

! icode = 0 means that fgmres has finished and sol contains the app. solution

!------------------------------------------------------------------------
!      line search method: add a*du to u (where a = 0.25, 0.5 or 1.0)
!------------------------------------------------------------------------

!         call linesearch(sol, x, res)
!         print *, 'res after linesearch = ', res, eta_e

         uk1 = uk1 + du ! u^k+1 = u^k + du^k

         return
       end subroutine prepFGMRES_NK
      




