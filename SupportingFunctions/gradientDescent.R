################################################################################
# Peform projected gradient descent to solve
# min_{rho,s} (lambda'*(T-mu(rho)))^2 / lambda' Sigma(rho) lambda
# s.t. " " (See Cohen, Olson, and Fogart 2018)
#
# INPUTS:
#     Q, T, index: see "driver.R" for an example of what these look like
#     Gamma:
#     rho0, s0: initial feasible points
#     step: stepsize
#     maxIter: max iterations
#     betam: momentum term for gradient update
################################################################################

gradientDescent_Constrained <- function(Q, TS, index, Gamma, rho0, s0, step,
                                        maxIter, betam, alpha, Z){
  I <- length(index) #number of strata
  N <- dim(Q)[2] #population size
  rho <- rho0; #initial rho
  s <- s0 #initial s
  iter <- 1; #start the iteration counter at 1
  tt <- step #initialize the gradient time-adjusted step-length
  fval <- rep(0, maxIter) #the optimal value history initialized to 0
  fBest <- Inf #the optimal value overall
  rhoBest <- rep(NA, N) #the rho corresponding to the optimal objective
  sBest <- rep(NA, I) #the s corresponding to the optimal objective

  rhoOld <- rho0
  sOld <- s0

  
  K <- length(TS) #number of outcome variables
  
  #upper bounds
  pvalUBcenter = function(stat, K, alpha)
  {
    .5 * pchisq(stat, df = K, lower.tail = FALSE) + .5 * pchisq(stat, df = K-1,lower.tail = FALSE) - alpha #naive upper bound
  }
  critvalub = function(K, alpha)
  {
    if(K==1){
      qchisq(1-alpha, K) #univariate case
    }
    else{uniroot(pvalUBcenter, c(qchisq(1-alpha,K-1), qchisq(1-alpha, K)), K = K, alpha = alpha)$root #multivariate case
    }
    
  }
  
  #recover matched set assignments from 'index'
  matchedSetAssignments = rep(0, N)
  for(ind in 1:length(index))
  {
    matchedSetAssignments[unlist(index[ind])] = ind
  }
  
  if(K != 1) #multivariate case (K > 1)
  {
    crit = maxCritChiBarUB(t(Q), matchedSetAssignments, Gamma, alpha)
  }
  if(K == 1) #univariate case (K = 1)
  {
    crit =  qchisq(1-alpha, K)
  }
  
  
  while(iter <= maxIter){
    # find lambdastar and objective value
    outLambda <- innerSolve(rho, Q, TS, index)

    if(outLambda$optval < sqrt(crit)-1e-3)
    {
      fBest = outLambda$optval 
      sBest <- s
      rhoBest <- rho
      iter = maxIter + 1 #break out of the loop
    }
    
    if(iter <= maxIter)
    {
      Lmat = matrix(outLambda$lambda, length(matchedSetAssignments), K, byrow=T)
      qlam = rowSums(Lmat*t(Q))
      rr = univariateRoot(Gamma, matchedSetAssignments, qlam, Z, kappa = crit, alternative = "G")
      if(rr > 0)
      {
        fBest = 2*sqrt(crit)
        iter = maxIter + 1
      }
    }
    
    if(iter <= maxIter)
    {
      fval[iter] <- outLambda$optval
      
      if(fval[iter] < fBest){
        fBest <- fval[iter]
        sBest <- s
        rhoBest <- rho
      }
      
      if(iter <= maxIter){
        # find the gradient
        outGrad <- gradient(rho, outLambda$lambda, Q, TS, index)
        
        # project gradient step
        for(i in 1:I){
          
          ix <- index[[i]]
          gstep <- c(rho[ix], s[i]) - (1-betam)*tt*c(outGrad$grad[ix], 0) +
            betam*(c(rho[ix], s[i]) - c(rhoOld[ix],sOld[i]))
          
          outProject <- constraintProject(Gamma, gstep)
          rhoOld[ix] <- rho[ix]
          sOld[i] <- s[i]
          rho[ix] <- outProject$x
          s[i] <- outProject$s
        }
        
        # iteration processing
        if(iter %% 10 == 0 && verbose == TRUE)
          cat("Iter: ", iter, "    Obj. Val:", fval[iter], "\n")
        iter <- iter + 1
        tt <- step/sqrt(iter)
      }else{
        iter = maxIter + 1#when we can't take gradients because we are at lambda = (0, 0)  we quit the loop
      }
    }
  }
  reject = (fBest > sqrt(crit))
  
  list(fval=fBest, rho=rhoBest, s=sBest, lambdas = outLambda$lambda, reject = reject, critval = sqrt(crit))
}