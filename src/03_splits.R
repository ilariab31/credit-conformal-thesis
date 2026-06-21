# =====================================================
# 03_splits.R
# Temporal rolling-origin split: strict  fit < calib < test  (no overlap).
# -----------------------------------------------------
#   fit   - model is trained on this (oldest block)
#   calib - held out from fitting; conformal sets thresholds here; placed
#           right before the test period (temporally adjacent for clean coverage)
#   test  - forward quarters we evaluate on, to measure decay with model age
#
# The date cut-offs below are the load-bearing design choices (flag to Andres).
# =====================================================

library(data.table)
stopifnot(exists("loans"))   # expects the clean table (02_prepare_data.R / readRDS)

# ---- Parameters: temporally-ordered  fit < calib < test ----
FIT_START <- as.Date("2012-01-01")  # earliest vintage used
FIT_END   <- as.Date("2013-06-30")  # fit   = 2012 .. 2013-H1
CALIB_END <- as.Date("2013-12-31")  # calib = 2013-H2  (slice right before test)
TEST_END  <- as.Date("2015-12-31")  # test  = 2014 .. 2015

# ---- Restrict to the window and assign strict temporal roles ----
analysis <- loans[issue_date >= FIT_START & issue_date <= TEST_END]

analysis[, split_role := fcase(
  issue_date <= FIT_END,                            "fit",
  issue_date >  FIT_END  & issue_date <= CALIB_END, "calib",
  issue_date >  CALIB_END,                          "test"
)]

# Guard: every row must land in exactly one role
stopifnot(!any(is.na(analysis$split_role)))
cat("Analysis window:", format(FIT_START), "to", format(TEST_END),
    "|", nrow(analysis), "loans\n\n")

# ---- Report 1: size + default count by role ----
role_summary <- analysis[, .(
  n            = .N,
  n_defaults   = sum(default),
  default_rate = round(mean(default) * 100, 1)
), by = split_role][order(factor(split_role, levels = c("fit", "calib", "test")))]
cat("Split roles:\n"); print(role_summary)

# ---- Report 2: forward test quarters (the decay axis) ----
test_summary <- analysis[split_role == "test", .(
  n            = .N,
  n_defaults   = sum(default),
  default_rate = round(mean(default) * 100, 1)
), by = vintage_quarter][order(vintage_quarter)]
cat("\nForward test quarters:\n"); print(test_summary)