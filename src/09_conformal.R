# =====================================================
# 09_conformal.R  — Section 1: Split conformal + coverage decay (A8, E3)
# -----------------------------------------------------
# Split (inductive) conformal for binary default prediction, RAW scores.
#   nonconformity(loan) = 1 - p(true class)
#   threshold = finite-sample-corrected (1-alpha) quantile on calib set
#   set(loan) = { labels whose nonconformity <= threshold }
# Measure across 8 test quarters: marginal coverage (target 1-alpha),
#   mean set size, % uncertain {good,bad} sets, and per-class coverage
#   (the class-conditional view that previews E4).
# Prereq: 02->04->05 + 07 helpers in memory (models, test sets, score_set).
# =====================================================

library(data.table)
stopifnot(exists("models_spec"), exists("score_set"), exists("test_vq"),
          exists("calib_woe"), exists("calib_lgb"))

alpha   <- 0.10                      # target 90% coverage
quarters <- sort(unique(test_vq))

# Nonconformity for each loan given p(default)=p and label y:
#   score for the TRUE class = 1 - p(true class)
#   p(good=0) = 1-p ; p(bad=1) = p
score_true <- function(p, y) ifelse(y == 1, 1 - p, p)   # =1-p(true class)

# Conformal threshold: finite-sample corrected (1-alpha) quantile of calib scores
conf_threshold <- function(cal_scores, alpha) {
  n <- length(cal_scores)
  k <- ceiling((n + 1) * (1 - alpha))
  k <- min(k, n)                                  # cap (if alpha tiny)
  sort(cal_scores)[k]
}

# Given threshold q, build the prediction set membership for a test loan with p:
#   include 'good'(0) if its score 1-p(0)=p ... wait: score as good = 1 - p(good)=1-(1-p)=p
#   include 'bad' (1) if score as bad  = 1 - p(bad) = 1 - p  <= q
# So: good in set  <=>  p     <= q
#     bad  in set  <=>  (1-p) <= q
sets_for <- function(p, q) {
  good_in <- p       <= q
  bad_in  <- (1 - p) <= q
  list(good = good_in, bad = bad_in)
}

out <- list()
for (mname in names(models_spec)) {
  spec <- models_spec[[mname]]
  
  # --- Calibrate threshold on 2013-H2 calib set (raw scores) ---
  cal <- score_set(spec, "calib")
  ok  <- is.finite(cal$p) & is.finite(cal$y)
  cal_scores <- score_true(cal$p[ok], cal$y[ok])
  q <- conf_threshold(cal_scores, alpha)
  
  # --- Apply to each test quarter ---
  for (qt in quarters) {
    s  <- score_set(spec, qt)
    okq <- is.finite(s$p) & is.finite(s$y)
    p  <- s$p[okq]; y <- s$y[okq]
    st <- sets_for(p, q)
    
    # coverage = true label is in the set
    covered <- ifelse(y == 1, st$bad, st$good)
    setsize <- as.integer(st$good) + as.integer(st$bad)
    
    out[[length(out)+1]] <- data.table(
      model = mname, quarter = qt, threshold = round(q, 4),
      coverage   = round(mean(covered), 4),
      mean_set   = round(mean(setsize), 3),
      pct_uncert = round(mean(setsize == 2) * 100, 1),   # {good,bad}
      pct_empty  = round(mean(setsize == 0) * 100, 1),   # {}
      cov_good   = round(mean(covered[y == 0]), 4),       # per-class coverage
      cov_bad    = round(mean(covered[y == 1]), 4),
      def_rate   = round(mean(y), 4))
  }
}
conformal <- rbindlist(out)

# ---- Headline: marginal coverage by quarter (target 0.90) ----
cat("\n=== Marginal coverage by quarter (target", 1 - alpha, ") ===\n")
print(dcast(conformal, model ~ quarter, value.var = "coverage"))

# ---- Per-class coverage (previews E4: does one class lose coverage?) ----
cat("\n=== Coverage on GOOD loans (target", 1 - alpha, ") ===\n")
print(dcast(conformal, model ~ quarter, value.var = "cov_good"))
cat("\n=== Coverage on BAD/default loans (target", 1 - alpha, ") ===\n")
print(dcast(conformal, model ~ quarter, value.var = "cov_bad"))

# ---- Uncertainty / triage volume ----
cat("\n=== % uncertain {good,bad} sets (triage volume) ===\n")
print(dcast(conformal, model ~ quarter, value.var = "pct_uncert"))



# =====================================================
# 09_conformal.R  —  Section 2: Mondrian (class-conditional) conformal (E4)
# -----------------------------------------------------
# Fix for E3's failure: calibrate a SEPARATE threshold within each class
# (good=0, bad=1), so coverage is guaranteed PER CLASS, not just marginally.
#   - threshold_good from calib good loans; threshold_bad from calib bad loans
#   - a test loan's 'good' membership uses threshold_good; 'bad' uses threshold_bad
# Guarantee (label-conditional): among loans whose true label is c, ~1-alpha
#   have label c in their set. This is the lender-relevant guarantee for
#   catching defaulters. Cost: wider sets / more uncertainty (reported).
# Prereq: Section 1 of this script has run (models_spec, score_set, etc.).
# =====================================================

stopifnot(exists("conformal"))   # Section 1 ran

# Per-class thresholds from the calib set
mondrian_thresholds <- function(p, y, alpha) {
  s_good <- p[y == 0]                 # nonconformity of true-good = 1-p(good) = p
  s_bad  <- 1 - p[y == 1]             # nonconformity of true-bad  = 1-p(bad)  = 1-p
  list(good = conf_threshold(s_good, alpha),
       bad  = conf_threshold(s_bad,  alpha))
}

out_m <- list()
for (mname in names(models_spec)) {
  spec <- models_spec[[mname]]
  
  cal <- score_set(spec, "calib")
  ok  <- is.finite(cal$p) & is.finite(cal$y)
  thr <- mondrian_thresholds(cal$p[ok], cal$y[ok], alpha)
  
  for (qt in quarters) {
    s   <- score_set(spec, qt)
    okq <- is.finite(s$p) & is.finite(s$y)
    p <- s$p[okq]; y <- s$y[okq]
    
    # membership now uses the class-specific thresholds
    good_in <- p       <= thr$good
    bad_in  <- (1 - p) <= thr$bad
    covered <- ifelse(y == 1, bad_in, good_in)
    setsize <- as.integer(good_in) + as.integer(bad_in)
    
    out_m[[length(out_m)+1]] <- data.table(
      model = mname, quarter = qt,
      coverage   = round(mean(covered), 4),
      mean_set   = round(mean(setsize), 3),
      pct_uncert = round(mean(setsize == 2) * 100, 1),
      pct_empty  = round(mean(setsize == 0) * 100, 1),
      cov_good   = round(mean(covered[y == 0]), 4),
      cov_bad    = round(mean(covered[y == 1]), 4))
  }
}
mondrian <- rbindlist(out_m)

cat("\n=== MONDRIAN: coverage on BAD loans (target", 1 - alpha,
    ") -- the fix ===\n")
print(dcast(mondrian, model ~ quarter, value.var = "cov_bad"))
cat("\n=== MONDRIAN: coverage on GOOD loans (target", 1 - alpha, ") ===\n")
print(dcast(mondrian, model ~ quarter, value.var = "cov_good"))
cat("\n=== MONDRIAN: marginal coverage by quarter ===\n")
print(dcast(mondrian, model ~ quarter, value.var = "coverage"))
cat("\n=== MONDRIAN: % uncertain {good,bad} sets (the COST) ===\n")
print(dcast(mondrian, model ~ quarter, value.var = "pct_uncert"))

# ---- Side-by-side: did Mondrian fix bad-loan coverage? ----
cmp <- merge(
  conformal[, .(model, quarter, split_bad = cov_bad)],
  mondrian[,  .(model, quarter, mondrian_bad = cov_bad)],
  by = c("model", "quarter"))
cat("\n=== Bad-loan coverage: split (broken) vs Mondrian (fixed) — lgbm_full ===\n")
print(cmp[model == "lgbm_full"][order(quarter)])
