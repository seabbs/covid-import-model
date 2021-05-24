library(cmdstanr)
library(posterior)
library(bayesplot)
library(data.table)

# synthetic data for model
syn_data <- list(
    t = 120,
    dt = 30,
    dist_t = 0:30,
    cases_obs = rep(100, 120),
    cases_seq = rep(100, 120),
    cases_b1672 = rep(0, 120),
    india_cases = rep(100, 120),
    posterior = 0

)

# compile and sample from the prior
model <- cmdstan_model("stan/model.stan")

# run the model without fitting to data
prior <- model$sample(data = syn_data, seed = 12453, chains = 1,
                      iter_warmup = 1000, iter_sampling = 1000)

# summarise priors
prior$summary()

# extract into data frame
prior_array <- prior$draws()
prior_df <- as_draws_df(prior_array)
prior_draw_df <- subset_draws(prior_df, chain = 1, iteration = 100)

# extract into stan format
prior_data <- syn_data
prior_data$cases_b1672 <- as.vector(unlist(
    as_draws_matrix(prior$draws("exp_cases_b1672"))[100, ]
))
prior_data$cases_obs <- as.vector(unlist(
    as_draws_matrix(prior$draws("exp_cases_obs"))[100, ]
))
prior_data$posterior <- 1

# run the model fitting to a prior sample
posterior <- model$sample(data = prior_data, seed = 12453,
                          chains = 4, parallel_chains = 4)

# compare prior data draw and posterior
summarise_draws(prior_draw_df)
posterior$summary()