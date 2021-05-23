library(cmdstanr)

# synthetic data for model
syn_data <- list(
    t = 120,
    dt = 30,
    dist_t = 0:30,
    cases_obs = rep(10, 120),
    cases_seq = rep(1000, 120),
    cases_b1672 = rep(0, 120),
    india_cases = rep(100, 120),
    posterior = 0

)

# compile and sample from the prior
model <- cmdstan_model("stan/model.stan")

# run the model without fitting to data
prior <- model$sample(data = syn_data, seed = 12453, chains = 1,
                      iter_warmup = 1000, iter_sampling = 1000,
                      adapt_engaged = TRUE)