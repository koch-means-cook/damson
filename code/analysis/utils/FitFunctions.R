# Function to get SSE
MySse = function(fit, data) {
  se = (data - fit)^2
  sse = sum(se)
  return(sse)
}

# Cost function, here likelihood assuming arbitrary SD of 0.25 of normally 
# distributed error term 
MyCost = function(fit, data) {
  se = (data - fit)^2
  sse = sum(se)
  like = 1/sqrt(2*pi*0.25^2) * exp(-se/(2*0.25^2))
  LL = -sum(log(like))
  return(LL)
}

# Define Gauss function 
MyGauss = function(params, angle) {
  m = 0
  sd = params[1]
  fit = exp(-0.5 * ((angle - m)*sd)^2)
  fit = fit/sum(fit)
  return(fit)
}

# Wrapper for Gauss cost
MyGauss_sse = function(params, angle, data, cidx) {
  fit = MyGauss(params, angle)
  LL = MyCost(fit[cidx], data[cidx])
}

# Fitting functions combining previous functions
GaussFit <- function(confusion_mat, angles, fit_cols){
  optim(c(0.01),
        function(params) {MyGauss_sse(params,
                                      angles,
                                      confusion_mat,
                                      fit_cols)},
        method = 'L-BFGS-B',
        lower = 0,
        upper = 1)
}

# Define uniform function
MyUniform = function(params, angle) {
  peak = params[1]
  fit = rep((1-peak)/5, 6)
  fit[3] = peak
  return(fit)
}

# Wrapper for uniform cost
MyUniform_sse = function(params, angle, data, cidx) {
  fit = MyUniform(params, angle)
  LL = MyCost(fit[cidx], data[cidx])
  return(LL) 
}

# Fitting functions combining previous functions
UniFit <- function(confusion_mat, angles, fit_cols){
  optim(c(0.01),
        function(params) {MyUniform_sse(params,
                                        angles,
                                        confusion_mat,
                                        fit_cols)},
        method="L-BFGS-B",
        lower = 0,
        upper = 1)
}
