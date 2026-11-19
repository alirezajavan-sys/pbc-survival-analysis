source(file.path("..", "..", "R", "functions.R"))

test_that("Mayo risk score matches a hand-calculated value", {
  # 50-year-old, bilirubin 1 mg/dL, albumin 1 g/dL, PT 1 s, no oedema: only the age term remains
  expect_equal(mayo_risk_score(50, 1, 1, 1, 0), 0.039 * 50)
  # Typical patient
  expected <- 0.871 * log(2) - 2.53 * log(3.5) + 0.039 * 55 + 2.38 * log(10.7) + 0.859 * 0.5
  expect_equal(mayo_risk_score(55, 2, 3.5, 10.7, 0.5), expected)
})

test_that("Mayo risk score increases with bilirubin and decreases with albumin", {
  expect_gt(mayo_risk_score(55, 5, 3.5, 11, 0), mayo_risk_score(55, 1, 3.5, 11, 0))
  expect_lt(mayo_risk_score(55, 1, 4.0, 11, 0), mayo_risk_score(55, 1, 3.0, 11, 0))
})

test_that("Mayo risk score rejects impossible inputs", {
  expect_error(mayo_risk_score(55, 0, 3.5, 11, 0))
  expect_error(mayo_risk_score(55, 1, 3.5, 11, 2))
})

test_that("prepare_pbc codes events and treatment correctly", {
  data(pbc, package = "survival")
  d <- prepare_pbc(pbc)
  expect_equal(sum(d$death), sum(pbc$status == 2))
  expect_equal(sum(d$randomised), 312)
  expect_setequal(levels(d$event), c("censor", "transplant", "death"))
  expect_true(all(d$years >= 0))
})

test_that("km_to_df starts every curve at survival 1", {
  library(survival)
  data(pbc, package = "survival")
  d <- prepare_pbc(pbc)
  df <- km_to_df(survfit(Surv(years, death) ~ sex, data = d))
  starts <- df[df$time == 0, ]
  expect_true(all(starts$surv == 1))
  expect_setequal(unique(df$strata), c("Female", "Male"))
})

test_that("p-value and HR formatting", {
  expect_equal(fmt_p(0.0001), "<0.001")
  expect_equal(fmt_p(0.0456), "0.046")
  expect_equal(fmt_hr(1.234, 0.9, 1.7), "1.23 (0.90–1.70)")
})
