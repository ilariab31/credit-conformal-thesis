# =====================================================
# 05_models.R
# Base models (A6) + baseline performance (E1).
# -----------------------------------------------------
# Section 1: WOE-logistic scorecard (full vs clean variants).
#   full  = all WOE features, one FICO column (with LC risk view).
#   clean = full minus grade/sub_grade/int_rate (without LC risk view).
# Predict PD on first test quarter (2014-Q1); report E1 metrics.
#
# Prerequisite objects (from 02 -> 03 -> 04):
#   fit_woe, calib_woe, test_woe  (WOE matrices, 28 features + default)
#   analysis                      (carries split_role + vintage_quarter)
# =====================================================

library(data.table)

stopifnot(exists("fit_woe"), exists("test_woe"), exists("analysis"))

fit_woe  <- as.data.table(fit_woe)
test_woe <- as.data.table(test_woe)

# ---- Ensure default is numeric 0/1 (glm + all metrics rely on this) ----
# Coerce safely; error loudly if labels are anything other than 0/1.
fit_woe[,  default := as.numeric(as.character(default))]
test_woe[, default := as.numeric(as.character(default))]
stopifnot(all(fit_woe$default  %in% c(0, 1)),
          all(test_woe$default %in% c(0, 1)))

# ---- Attach vintage_quarter to test rows (row order matches; verified) ----
stopifnot(nrow(test_woe) == nrow(analysis[split_role == "test"]))
test_woe[, vintage_quarter := analysis[split_role == "test", vintage_quarter]]

# ---- Feature sets for the two scorecard variants ----
all_woe   <- setdiff(names(fit_woe), c("default", "vintage_quarter"))
drop_fico <- "fico_range_high_woe"                 # perfectly collinear with low
lc_risk   <- c("sub_grade_woe", "int_rate_woe", "grade_woe")

feats_full  <- setdiff(all_woe, drop_fico)              # 27 features
feats_clean <- setdiff(all_woe, c(drop_fico, lc_risk))  # 24 features
cat("Full scorecard features:", length(feats_full),
    "| Clean scorecard features:", length(feats_clean), "\n")

# ---- Fit logistic regression for each variant (on FIT set only) ----
fit_scorecard <- function(feats) {
  f <- reformulate(feats, response = "default")
  glm(f, data = fit_woe, family = binomial())
}
m_full  <- fit_scorecard(feats_full)
m_clean <- fit_scorecard(feats_clean)

# ---- Predict PD on the first test quarter (2014-Q1) ----
q1 <- test_woe[vintage_quarter == "2014-Q1"]
cat("2014-Q1 test rows:", nrow(q1),
    "| observed default rate:", round(mean(q1$default) * 100, 1), "%\n")

p_full  <- predict(m_full,  newdata = q1, type = "response")
p_clean <- predict(m_clean, newdata = q1, type = "response")

# ---- E1 metrics ----
metrics <- function(p, y) {
  o <- order(p)
  ps <- p[o]; ys <- y[o]
  n1 <- sum(y); n0 <- length(y) - n1
  auc <- (sum(rank(p)[y == 1]) - n1 * (n1 + 1) / 2) / (n1 * n0)   # Mann-Whitney AUC
  cum_bad  <- cumsum(ys == 1) / n1
  cum_good <- cumsum(ys == 0) / n0
  ks <- max(abs(cum_bad - cum_good))
  brier <- mean((p - y)^2)
  bins <- cut(p, breaks = seq(0, 1, 0.1), include.lowest = TRUE)
  ece <- sum(tapply(seq_along(p), bins, function(ix) {
    if (length(ix) == 0) return(0)
    abs(mean(p[ix]) - mean(y[ix])) * length(ix) / length(p)
  }), na.rm = TRUE)
  c(AUC = auc, Gini = 2 * auc - 1, KS = ks, Brier = brier, ECE = ece)
}

e1 <- rbind(
  full  = metrics(p_full,  q1$default),
  clean = metrics(p_clean, q1$default)
)
cat("\n--- E1: WOE-logistic baseline, 2014-Q1 ---\n")
print(round(e1, 4))



# =====================================================
# 05_models.R  —  Section 2: Monotone LightGBM (A6) + E1
# -----------------------------------------------------
# Champion model: gradient-boosted trees on the raw 87-feature frame.
#   - categoricals as native integer codes, missing kept native
#   - monotonicity constraints ONLY where risk direction is definitional
#   - full vs clean variants (clean drops LC risk view: grade/sub_grade/int_rate)
#   - early stopping on calib (2013-H2): time-aware, never touches test
# Prerequisites: 02->03->04, AND Section 1 above (defines metrics() and e1).
# =====================================================
install.packages("lightgbm")
library(data.table)
library(lightgbm)

stopifnot(exists("fit_lgb"), exists("calib_lgb"), exists("test_lgb"),
          exists("analysis"), exists("metrics"), exists("e1"))

fit_lgb   <- as.data.table(fit_lgb)
calib_lgb <- as.data.table(calib_lgb)
test_lgb  <- as.data.table(test_lgb)

# ---- Attach vintage label to test rows (row order matches; verified) ----
stopifnot(nrow(test_lgb) == nrow(analysis[split_role == "test"]))
test_vq <- analysis[split_role == "test", vintage_quarter]

# ---- Feature sets (full = with LC risk view; clean = without) ----
all_feats <- setdiff(names(fit_lgb), "default")          # 87
lc_risk   <- c("grade", "sub_grade", "int_rate")
feats_full_lgb  <- all_feats
feats_clean_lgb <- setdiff(all_feats, lc_risk)
cat("LightGBM features -> full:", length(feats_full_lgb),
    "| clean:", length(feats_clean_lgb), "\n")

cat_all    <- names(fit_lgb)[sapply(fit_lgb, is.factor)] # 11
cats_full  <- intersect(cat_all, feats_full_lgb)
cats_clean <- intersect(cat_all, feats_clean_lgb)

# ---- Safety guard: factor levels identical across fit/calib/test ----
for (cc in cat_all) {
  stopifnot(identical(levels(fit_lgb[[cc]]), levels(test_lgb[[cc]])),
            identical(levels(fit_lgb[[cc]]), levels(calib_lgb[[cc]])))
}

# ---- Monotonicity directions (Chapter 3 decision) ----
# Constrain ONLY where the risk direction is definitionally unambiguous.
# Genuinely ambiguous fields (recent-credit-seeking, utilisation, collection
# dollar amounts) left UNCONSTRAINED (0) so the trees decide.
mono_up <- c("int_rate","dti","delinq_2yrs","inq_last_6mths","pub_rec","revol_util",
             "collections_12_mths_ex_med","acc_now_delinq",
             "pub_rec_bankruptcies","tax_liens","num_tl_30dpd",
             "num_tl_120dpd_2m","num_accts_ever_120_pd","num_tl_90g_dpd_24m")
mono_down <- c("annual_inc","fico_range_low","fico_range_high",
               "pct_tl_nvr_dlq","cr_hist_yrs")
mono_vec_for <- function(cols) {
  m <- integer(length(cols))
  m[cols %in% mono_up]   <-  1L
  m[cols %in% mono_down] <- -1L
  m
}

# ---- Matrix builder: factors -> consistent integer codes ----
mat_for <- function(dt, feats) data.matrix(dt[, ..feats])

# ---- Train one variant (early stop on calib) ----
train_lgb <- function(feats, cats) {
  Xtr <- mat_for(fit_lgb,   feats); ytr <- fit_lgb$default
  Xva <- mat_for(calib_lgb, feats); yva <- calib_lgb$default
  dtr <- lgb.Dataset(Xtr, label = ytr, categorical_feature = cats)
  dva <- lgb.Dataset.create.valid(dtr, Xva, label = yva)
  params <- list(objective = "binary", metric = "auc",
                 learning_rate = 0.05, num_leaves = 31, min_data_in_leaf = 100,
                 feature_fraction = 0.8, bagging_fraction = 0.8, bagging_freq = 1,
                 monotone_constraints = mono_vec_for(feats),
                 verbosity = -1, seed = 42)
  lgb.train(params, dtr, nrounds = 1000,
            valids = list(calib = dva), early_stopping_rounds = 50)
}

set.seed(42)
lgb_full  <- train_lgb(feats_full_lgb,  cats_full)
lgb_clean <- train_lgb(feats_clean_lgb, cats_clean)
cat("Best iterations -> full:", lgb_full$best_iter,
    "| clean:", lgb_clean$best_iter, "\n")

# ---- Predict PD on 2014-Q1 ----
is_q1 <- test_vq == "2014-Q1"
yq1   <- test_lgb$default[is_q1]
pl_full  <- predict(lgb_full,  mat_for(test_lgb, feats_full_lgb)[is_q1, ],
                    num_iteration = lgb_full$best_iter)
pl_clean <- predict(lgb_clean, mat_for(test_lgb, feats_clean_lgb)[is_q1, ],
                    num_iteration = lgb_clean$best_iter)

# ---- Combined E1 table (relabel Section 1 WOE rows for clarity) ----
e1_woe <- e1; rownames(e1_woe) <- c("woe_full", "woe_clean")
e1_all <- rbind(e1_woe,
                lgbm_full  = metrics(pl_full,  yq1),
                lgbm_clean = metrics(pl_clean, yq1))
cat("\n--- E1: base models, 2014-Q1 ---\n")
print(round(e1_all, 4))


# =====================================================
# 05_models.R  —  Section 3: Rolling evaluation across all 8 test quarters
# -----------------------------------------------------
# Frozen models (fit on 2012-2013) predict on each later quarter in turn.
# No retraining: any metric change across quarters is pure model-ageing /
# drift. This is the first view of the thesis's central decay phenomenon,
# and the harness reused by all downstream experiments.
# Prerequisites: Sections 1-2 of this script have run in this session.
# =====================================================

stopifnot(exists("m_full"), exists("m_clean"),
          exists("lgb_full"), exists("lgb_clean"),
          exists("test_woe"), exists("test_lgb"), exists("test_vq"),
          exists("metrics"),
          exists("feats_full"), exists("feats_clean"),
          exists("feats_full_lgb"), exists("feats_clean_lgb"))

quarters <- sort(unique(test_vq))

# Predict-and-score one model on one quarter, return the 5 metrics.
score_quarter <- function(model_kind, q) {
  if (model_kind %in% c("woe_full", "woe_clean")) {
    rows <- test_woe[vintage_quarter == q]
    y <- rows$default
    p <- if (model_kind == "woe_full")
      predict(m_full,  newdata = rows, type = "response")
    else
      predict(m_clean, newdata = rows, type = "response")
  } else {
    sel <- test_vq == q
    y <- test_lgb$default[sel]
    if (model_kind == "lgbm_full") {
      p <- predict(lgb_full, mat_for(test_lgb, feats_full_lgb)[sel, ],
                   num_iteration = lgb_full$best_iter)
    } else {
      p <- predict(lgb_clean, mat_for(test_lgb, feats_clean_lgb)[sel, ],
                   num_iteration = lgb_clean$best_iter)
    }
  }
  as.list(metrics(p, y))
}

models <- c("woe_full", "woe_clean", "lgbm_full", "lgbm_clean")

decay <- rbindlist(lapply(models, function(mk) {
  rbindlist(lapply(quarters, function(q) {
    m <- score_quarter(mk, q)
    data.table(model = mk, quarter = q,
               n = if (mk %in% c("woe_full","woe_clean"))
                 nrow(test_woe[vintage_quarter == q])
               else sum(test_vq == q),
               def_rate = round(if (mk %in% c("woe_full","woe_clean"))
                 mean(test_woe[vintage_quarter == q]$default)
                 else mean(test_lgb$default[test_vq == q]), 4),
               AUC = round(m$AUC, 4), Gini = round(m$Gini, 4),
               KS = round(m$KS, 4), Brier = round(m$Brier, 4),
               ECE = round(m$ECE, 4))
  }))
}))

# ---- Console preview: the two trajectories that matter most ----
cat("\n=== AUC across quarters (discrimination decay) ===\n")
print(dcast(decay, model ~ quarter, value.var = "AUC"))
cat("\n=== ECE across quarters (calibration decay) ===\n")
print(dcast(decay, model ~ quarter, value.var = "ECE"))
cat("\n=== Observed default rate by quarter (context) ===\n")
print(decay[model == "woe_full", .(quarter, def_rate, n)])