# Assign number / mean weight based on formulae
g3a_initialconditions <- function (stock, num_f, wgt_f, run_at = 0) {
    return(g3a_renewal(stock, num_f, wgt_f,
        run_f = ~cur_time == 0L,
        run_at = run_at))
}

# Steps to set up renewal of stocks on first step
g3a_initialconditions_normalparam <- function (stock, factor_f, mean_f, stddev_f, alpha_f, beta_f, run_at = 0) {
    return(g3a_renewal_normalparam(stock, factor_f, mean_f, stddev_f, alpha_f, beta_f,
        run_f = ~cur_time == 0L,
        run_at = run_at))
}

# Assign number / mean weight based on formulae
g3a_renewal <- function (stock, num_f, wgt_f, run_f = ~TRUE, run_at = 8) {
    out <- list()
    out[[step_id(run_at, stock)]] <- stock_step(f_substitute(~if (cur_time == 0L) {
        stock_comment("g3a_renewal for ", stock)
        stock_iterate(stock, {
            stock__num[stock__iter] <- num_f
            stock__wgt[stock__iter] <- wgt_f
        })
    }, list(num_f = num_f, wgt_f = wgt_f)))
    return(out)
}

# Steps to set up renewal of stocks on any stock
g3a_renewal_normalparam <- function (stock, factor_f, mean_f, stddev_f, alpha_f, beta_f, run_f = ~TRUE, run_at = 8) {
    # See InitialCond::Initialise
    # TODO: Scaling from initialcond values to "real" values
    renewal_dnorm <- array(dim = length(stock_definition(stock, 'stock__meanlen')))
    renewal_scaler <- 0.0

    out <- list()
    out[[step_id(run_at, stock)]] <- stock_step(f_substitute(~{
        stock_comment("g3a_renewal_normalparam for ", stock)
        stock_iterate(stock, if (run_f) {
            renewal_dnorm <- (stock__meanlen - mean_f) * (1.0 / stddev_f)
            stock__num[stock__iter] <- exp(-(renewal_dnorm ** 2) * 0.5)
            renewal_scaler <- 10000.0 / sum(stock__num[stock__iter])
            stock__num[stock__iter] <- stock__num[stock__iter] * renewal_scaler * factor_f
            stock__wgt[stock__iter] <- alpha_f * stock__meanlen ** beta_f
        })
    }, list(
        run_f = run_f,
        factor_f = factor_f,
        mean_f = mean_f,
        stddev_f = stddev_f,
        alpha_f = alpha_f,
        beta_f = beta_f)))
    return(out)
}