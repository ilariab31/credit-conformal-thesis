# =====================================================
# 07_recalibration.R  —  Recalibration arm (A7) + E2
# -----------------------------------------------------
# Can a CHEAP post-hoc correction fix the calibration decay from A6?
# Three methods x two regimes, applied to all four frozen base models.
#   Methods:  Platt (logistic re-map) | Isotonic (monotone staircase)
#             | Beta (Kull et al. 2017, logistic on log p / log(1-p))
#   Regimes:  static  = fit once on calib (2013-H2), apply to all quarters
#             rolling = fit on the PREVIOUS test quarter, apply to current
#                       (drift-fighting; starts at 2014-Q2, no Q1 predecessor)
# Calibration is monotone -> ranking (AUC) unchanged; we report ECE & Brier.
# Prereq: 02->03->04->05 in memory.
# =====================================================

library(data.table)
stopifnot(exists("m_full"), exists("lgb_full"), exists("metrics"),
          exists("mat_for"), exists("test_woe"), exists("test_lgb"),
          exists("test_vq"), exists("calib_woe"), exists("calib_lgb"))

# ---- Make calib sets safe (default numeric 0/1; data.table) ----
calib_woe <- as.data.table(calib_woe)
calib_lgb <- as.data.table(calib_lgb)
calib_woe[, default := as.numeric(as.character(default))]
calib_lgb[, default := as.numeric(as.character(default))]
stopifnot(all(calib_woe$default %in% c(0,1)), all(calib_lgb$default %in% c(0,1)))

# ---- Numerical guards ----
clip <- function(p, eps = 1e-6) pmin(pmax(p, eps), 1 - eps)
# Drop pairs where p or y is NA/non-finite (isoreg + honest metrics require this)
ok_pairs <- function(p, y) is.finite(p) & is.finite(y)

# ---- Calibration methods: each has fit(p,y) -> object, apply(object,p) -> p' ----
fit_platt <- function(p, y) {
  k <- ok_pairs(p, y); z <- qlogis(clip(p[k]))
  glm(y[k] ~ z, family = binomial())
}
apply_platt <- function(o, p)
  as.numeric(predict(o, newdata = data.frame(z = qlogis(clip(p))), type = "response"))

fit_beta <- function(p, y) {
  k <- ok_pairs(p, y); pc <- clip(p[k])
  glm(y[k] ~ lp + l1mp,
      data = data.frame(lp = log(pc), l1mp = log(1 - pc)), family = binomial())
}
apply_beta <- function(o, p) {
  pc <- clip(p)
  as.numeric(predict(o, newdata = data.frame(lp = log(pc), l1mp = log(1 - pc)),
                     type = "response"))
}

fit_isotonic <- function(p, y) {
  k <- ok_pairs(p, y); pk <- p[k]; yk <- y[k]
  o  <- order(pk); xs <- pk[o]
  yf <- isoreg(xs, yk[o])$yf
  keep <- !duplicated(xs, fromLast = TRUE)
  approxfun(xs[keep], yf[keep], method = "linear", rule = 2)
}
apply_isotonic <- function(fn, p) pmin(pmax(fn(p), 0), 1)

cal_methods <- list(
  platt    = list(fit = fit_platt,    apply = apply_platt),
  isotonic = list(fit = fit_isotonic, apply = apply_isotonic),
  beta     = list(fit = fit_beta,     apply = apply_beta)
)

# ---- Model registry ----
models_spec <- list(
  woe_full   = list(type="woe",  model=m_full,    feats=feats_full),
  woe_clean  = list(type="woe",  model=m_clean,   feats=feats_clean),
  lgbm_full  = list(type="lgbm", model=lgb_full,  feats=feats_full_lgb),
  lgbm_clean = list(type="lgbm", model=lgb_clean, feats=feats_clean_lgb)
)

# ---- Score a model on the calib set or one test quarter -> (p, y) ----
score_set <- function(spec, which) {
  if (spec$type == "woe") {
    dt <- if (which == "calib") calib_woe else test_woe[vintage_quarter == which]
    p  <- predict(spec$model, newdata = dt, type = "response"); y <- dt$default
  } else {
    if (which == "calib") { X <- mat_for(calib_lgb, spec$feats); y <- calib_lgb$default }
    else { sel <- test_vq == which
    X <- mat_for(test_lgb, spec$feats)[sel, ]; y <- test_lgb$default[sel] }
    p <- predict(spec$model, X, num_iteration = spec$model$best_iter)
  }
  list(p = as.numeric(p), y = as.numeric(y))
}

ece_of <- function(p, y) { k <- ok_pairs(p, y); as.numeric(metrics(p[k], y[k])["ECE"]) }
brier_of <- function(p, y) { k <- ok_pairs(p, y); as.numeric(metrics(p[k], y[k])["Brier"]) }

# ---- Main: uncalibrated vs each method, static + rolling, every quarter ----
quarters <- sort(unique(test_vq))
out <- list()
for (mname in names(models_spec)) {
  spec  <- models_spec[[mname]]
  scal  <- score_set(spec, "calib")                       # for static fit
  sq    <- lapply(quarters, function(q) score_set(spec, q)); names(sq) <- quarters
  stat  <- lapply(cal_methods, function(cm) cm$fit(scal$p, scal$y))  # static calibrators
  
  for (qi in seq_along(quarters)) {
    q <- quarters[qi]; s <- sq[[q]]
    out[[length(out)+1]] <- data.table(model=mname, method="none", regime="uncal",
                                       quarter=q, ECE=ece_of(s$p,s$y), Brier=brier_of(s$p,s$y))
    for (cn in names(cal_methods)) {
      cm <- cal_methods[[cn]]
      ps <- cm$apply(stat[[cn]], s$p)                     # static
      out[[length(out)+1]] <- data.table(model=mname, method=cn, regime="static",
                                         quarter=q, ECE=ece_of(ps,s$y), Brier=brier_of(ps,s$y))
      if (qi >= 2) {                                      # rolling: fit on prev quarter
        prev <- sq[[quarters[qi-1]]]
        pr <- cm$apply(cm$fit(prev$p, prev$y), s$p)
        out[[length(out)+1]] <- data.table(model=mname, method=cn, regime="rolling",
                                           quarter=q, ECE=ece_of(pr,s$y), Brier=brier_of(pr,s$y))
      }
    }
  }
}
recal <- rbindlist(out)
recal[, `:=`(ECE = round(ECE, 4), Brier = round(Brier, 5))]
recal[, key := fifelse(regime == "uncal", "uncalibrated", paste(method, regime, sep="_"))]

# ---- Focal: worst-calibrated model, ECE per quarter, all variants ----
cat("\n=== lgbm_full: ECE by quarter (uncalibrated vs recalibrated) ===\n")
print(dcast(recal[model == "lgbm_full"], quarter ~ key, value.var = "ECE"))

# ---- Summary: mean ECE across quarters, every model x method x regime ----
cat("\n=== Mean ECE across quarters (lower = better calibrated) ===\n")
summ <- recal[, .(mean_ECE = round(mean(ECE), 4)), by = .(model, regime, method)]
setorder(summ, model, regime, method)
print(summ)