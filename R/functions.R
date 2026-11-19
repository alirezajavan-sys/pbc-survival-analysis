# Helper functions for the PBC survival analysis.
# Kept separate from analysis.R so they can be unit-tested (tests/testthat).

#' Mayo Clinic PBC risk score (Dickson et al., Hepatology 1989).
#'
#' R = 0.871 log(bilirubin) - 2.53 log(albumin) + 0.039 age
#'     + 2.38 log(prothrombin time) + 0.859 edema
#'
#' @param age      years
#' @param bili     serum bilirubin, mg/dL
#' @param albumin  serum albumin, g/dL
#' @param protime  prothrombin time, seconds
#' @param edema    0 = none, 0.5 = untreated or resolved by diuretics, 1 = despite diuretics
mayo_risk_score <- function(age, bili, albumin, protime, edema) {
  stopifnot(all(bili > 0, na.rm = TRUE), all(albumin > 0, na.rm = TRUE),
            all(protime > 0, na.rm = TRUE), all(edema %in% c(0, 0.5, 1, NA)))
  0.871 * log(bili) - 2.53 * log(albumin) + 0.039 * age +
    2.38 * log(protime) + 0.859 * edema
}

#' Recode the raw `survival::pbc` data into analysis-ready form.
#'
#' * time in years
#' * `death`: 1 = died, 0 = censored or transplanted (transplant treated as censoring
#'   in the primary analysis, as in the original Mayo model)
#' * `event`: 3-level factor for the competing-risks analysis
prepare_pbc <- function(pbc) {
  within(pbc, {
    years   <- time / 365.25
    death   <- as.integer(status == 2)
    event   <- factor(status, levels = 0:2, labels = c("censor", "transplant", "death"))
    treatment <- factor(trt, levels = 1:2, labels = c("D-penicillamine", "Placebo"))
    sex     <- factor(sex, levels = c("f", "m"), labels = c("Female", "Male"))
    edema_f <- factor(edema, levels = c(0, 0.5, 1),
                      labels = c("None", "Untreated/resolved", "Despite diuretics"))
    randomised <- !is.na(trt)
  })
}

#' Turn a survfit object into a tidy data frame suitable for ggplot step curves.
#' Adds the time-zero row for every stratum so curves start at 1.
km_to_df <- function(fit) {
  s <- summary(fit, censored = TRUE)
  strata <- if (is.null(s$strata)) rep("All", length(s$time)) else as.character(s$strata)
  df <- data.frame(time = s$time, surv = s$surv, lower = s$lower, upper = s$upper,
                   n.censor = s$n.censor, strata = strata)
  starts <- data.frame(time = 0, surv = 1, lower = 1, upper = 1, n.censor = 0,
                       strata = unique(df$strata))
  df <- rbind(starts, df)
  df$strata <- sub("^.*?=", "", df$strata)
  df[order(df$strata, df$time), ]
}

#' Rectangles for a stepped confidence band (one per KM step), for geom_rect.
step_band <- function(km_df) {
  do.call(rbind, lapply(split(km_df, km_df$strata), function(d) {
    d <- d[order(d$time), ]
    data.frame(strata = d$strata[-nrow(d)], xmin = d$time[-nrow(d)], xmax = d$time[-1],
               lower = d$lower[-nrow(d)], upper = d$upper[-nrow(d)])
  }))
}

#' Numbers at risk at chosen time points, per stratum.
risk_table <- function(fit, times) {
  s <- summary(fit, times = times, extend = TRUE)
  strata <- if (is.null(s$strata)) rep("All", length(s$time)) else sub("^.*?=", "", as.character(s$strata))
  data.frame(strata = strata, time = s$time, n.risk = s$n.risk)
}

#' Format a hazard ratio with its 95% CI.
fmt_hr <- function(hr, lo, hi, digits = 2) {
  sprintf(paste0("%.", digits, "f (%.", digits, "f–%.", digits, "f)"), hr, lo, hi)
}

#' Format a p-value the way journals expect.
fmt_p <- function(p) {
  ifelse(p < 0.001, "<0.001", sprintf("%.3f", p))
}
