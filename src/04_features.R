# =====================================================
# 04_features.R
# Feature processing for the two model pipelines (A5).
# -----------------------------------------------------
#   WOE pipeline (scorecard): bin -> Weight of Evidence -> IV screen, learned
#     on the FIT set only, then APPLIED to calib/test (leakage-safe).
#   LightGBM pipeline: raw features, categoricals as factors, NaN kept native.
#
# Prerequisite: `analysis` (with split_role, from 03_splits.R) and
#   ORIGINATION_FEATURES (from 02_prepare_data.R) must be in memory.
#   Standalone order: source 02_prepare_data.R -> 03_splits.R -> this.
# =====================================================

library(data.table)
library(scorecard)
library(lubridate)

stopifnot(exists("analysis"), exists("ORIGINATION_FEATURES"))

# ---- Derive credit-history length (earliest_cr_line is a "Mon-YYYY" string) ----
analysis[, cr_hist_yrs := time_length(
  interval(my(earliest_cr_line), issue_date), "years"
)]

# ---- Feature universe for both pipelines ----
# Drop zip_code (~900 levels, impractical) and the raw earliest_cr_line string;
# add the derived numeric cr_hist_yrs.
feature_set <- setdiff(c(ORIGINATION_FEATURES, "cr_hist_yrs"),
                       c("zip_code", "earliest_cr_line"))

fit_dt   <- analysis[split_role == "fit",   c(feature_set, "default"), with = FALSE]
calib_dt <- analysis[split_role == "calib", c(feature_set, "default"), with = FALSE]
test_dt  <- analysis[split_role == "test",  c(feature_set, "default"), with = FALSE]
cat("Roles -> fit:", nrow(fit_dt), "| calib:", nrow(calib_dt),
    "| test:", nrow(test_dt), "\n")

# =====================================================
# WOE pipeline (scorecard)
# =====================================================
# Bin + WOE learned on the FIT set only (never calib/test).
bins_all <- woebin(fit_dt, y = "default", x = feature_set)

# Information Value per feature (predictive strength), sorted
iv_table <- rbindlist(lapply(names(bins_all), function(v)
  data.table(variable = v, iv = round(bins_all[[v]]$total_iv[1], 3))
))[order(-iv)]
print(iv_table)

# Screen: keep IV >= 0.02 (scorecard convention), reuse the bins already computed
keep_woe <- iv_table[iv >= 0.02, variable]
bins     <- bins_all[keep_woe]
cat("WOE features after IV>=0.02 screen:", length(keep_woe), "\n")

# Apply the FIT-learned bins to all three sets (woebin_ply only applies -> safe)
fit_woe   <- woebin_ply(fit_dt[,   c(keep_woe, "default"), with = FALSE], bins)
calib_woe <- woebin_ply(calib_dt[, c(keep_woe, "default"), with = FALSE], bins)
test_woe  <- woebin_ply(test_dt[,  c(keep_woe, "default"), with = FALSE], bins)
cat("WOE matrices -> fit:", nrow(fit_woe), "x", ncol(fit_woe), "\n")

# =====================================================
# LightGBM pipeline
# =====================================================
# Raw features, categoricals as factors (shared levels), NaN kept native.
cat_features <- names(which(sapply(analysis[, ..feature_set], is.character)))

lgb_dt <- copy(analysis[, c(feature_set, "default", "split_role"), with = FALSE])
lgb_dt[, (cat_features) := lapply(.SD, factor), .SDcols = cat_features]

fit_lgb   <- lgb_dt[split_role == "fit",   c(feature_set, "default"), with = FALSE]
calib_lgb <- lgb_dt[split_role == "calib", c(feature_set, "default"), with = FALSE]
test_lgb  <- lgb_dt[split_role == "test",  c(feature_set, "default"), with = FALSE]
cat("LightGBM frames -> fit:", nrow(fit_lgb), "| calib:", nrow(calib_lgb),
    "| test:", nrow(test_lgb), "| features:", length(feature_set),
    "| categorical:", length(cat_features), "\n")