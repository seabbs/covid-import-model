functions{
    // discretised truncated lognormal pmf
    // test: discretised_lognormal_pmf(0:30, 1.65, 0.273, 30) 
    vector discretised_lognormal_pmf(int[] y, real mu, real sigma, int max_val) {
    int n = num_elements(y);
    vector[n] pmf;
    real small = 1e-5;
    real c_sigma = sigma < small ? small : sigma;
    real c_mu = mu < small ? small : mu;
    vector[n] adj_y = to_vector(y) + small;
    vector[n] upper_y = (log(adj_y + 1) - c_mu) / c_sigma;
    vector[n] lower_y = (log(adj_y) - c_mu) / c_sigma;
    real max_cdf = normal_cdf((log(max_val + small) - c_mu) / c_sigma, 0.0, 1.0);
    real min_cdf = normal_cdf((log(small) - c_mu) / c_sigma, 0.0, 1.0);
    real trunc_cdf = max_cdf - min_cdf;
    for (i in 1:n) {
        pmf[i] = (normal_cdf(upper_y[i], 0.0, 1.0) - normal_cdf(lower_y[i], 0.0, 1.0)) /
        trunc_cdf;
    }
    return(pmf);
    }
    // test: convolve(1:100, c(0, 0.5, 0.4, 0.1), 1.1)    
    vector convolve(vector cases, vector pmf, real mod) {
        int t = num_elements(cases);
        int pmf_t = num_elements(pmf);
        vector[t] conv = rep_vector(1e-5, t);
        for (s in 1:t) {
            int index = min(pmf_t, t - s + 1);
            int j = s + index - 1;
            conv[s:j] = conv[s:j] + cases[s] * pmf[1:index] * mod;
        }
        return(conv);
    }
    // test: self_convolve(1:100, c(0, 0.5, 0.4, 0.1), 1.1)   
    vector self_convolve(vector cases, vector pmf, real mod) {
        int t = num_elements(cases);
        int pmf_t = num_elements(pmf);
        vector[t] conv = cases;
        for (s in 1:t) {
            int index = min(pmf_t, t - s + 1);
            int j = s + index - 1;
            conv[s:j] = conv[s:j] + conv[s] * pmf[1:index] * mod;
        }
        return(conv);
    }

}
data {
    int t;
    int dt;
    int dist_t[dt + 1];
    int cases_obs[t];
    int cases_seq[t];
    int cases_b1672[t];
    vector[t] india_cases;
    int posterior;
}

parameters {
    real <lower = 0, upper = 1> imp_frac;
    real si_logmean;
    real <lower = 0> si_logsd;
    real <lower = 0> R;
    real <lower = 0> b1672_mod;
    real <lower = 0> imp_mod;
    real <lower = 0> recip_phi;
}

transformed parameters {
    vector[t] imp_b1672;
    vector[t] imp_linked_b1672;
    vector[t] exp_b1672;
    vector[t] exp_b117;
    vector[t] prob_b117;
    vector[dt + 1] si;
    vector[dt + 1] inc;
    real phi;
    // discretised serial interval
    si = discretised_lognormal_pmf(dist_t, si_logmean, si_logsd, dt);
    // imported cases from india
    imp_b1672 = india_cases * imp_frac; 
    // b1672 cases directly driven by imports
    imp_linked_b1672 = convolve(imp_b1672, si, R * b1672_mod * imp_mod);
    // b1672 cases from transmission starting with import linked
    exp_b1672 = imp_linked_b1672;
    exp_b1672 = self_convolve(exp_b1672, si, R * b1672_mod);
    // add imported cases to total b117 cases
    exp_b1672 = exp_b1672 + imp_b1672;
    // b117 cases from transmission
    exp_b117 = rep_vector(0, t);
    exp_b117[1] = cases_obs[1];
    exp_b117 = self_convolve(exp_b117, si, R);
    prob_b117 = exp_b117 ./ (exp_b117 + exp_b1672);
    // convert overdispersion to correct scale
    phi = 1 ./ sqrt(recip_phi);
}

model {
    // import
    imp_frac ~ beta(1, 1); 
    // serial interval
    si_logmean ~ normal(1.65, 0.1);
    si_logsd ~ normal(0.273, 0.05) T[0,];
    // observation model priors
    recip_phi ~ normal(0, 1) T[0,];
    // effective reproduction no + modifiers
    R ~ lognormal(0, 0.25);
    imp_mod ~ lognormal(0, 1); 
    b1672_mod ~ lognormal(0, 1);
    if (posterior) {
        // observation model
        cases_b1672 ~ binomial(cases_seq, prob_b117);
        cases_obs ~ neg_binomial_2(exp_b1672 + exp_b117, phi);
    }
}

generated quantities {
   int exp_cases_b1672[t];
   int exp_cases_obs[t];

   exp_cases_b1672 = binomial_rng(cases_seq, prob_b117);
   exp_cases_obs = neg_binomial_2_rng(exp_b1672 + exp_b117, phi);
}
