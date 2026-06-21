# =====================================================
# 02 — Prepare data: define origination features, target, vintage
# =====================================================
# Builds the leakage-free feature set from the dictionary- and data-verified
# leakage audit (see leakage_audit.md). Only fields available at loan
# origination are included.

library(data.table)

# ---- ORIGINATION_FEATURES: the leakage-free model inputs ----
# Every column here was classified KEEP in the leakage audit.
# Grouped by type purely for readability.

ORIGINATION_FEATURES <- c(
  # --- Loan terms set at origination ---
  "loan_amnt", "term", "int_rate", "installment", "grade", "sub_grade",
  
  # --- Applicant-stated information ---
  "emp_length", "home_ownership", "annual_inc", "verification_status",
  "purpose", "zip_code", "addr_state", "dti",
  
  # --- Credit-bureau attributes at application ---
  "delinq_2yrs", "earliest_cr_line", "fico_range_low", "fico_range_high",
  "inq_last_6mths", "mths_since_last_delinq", "mths_since_last_record",
  "open_acc", "pub_rec", "revol_bal", "revol_util", "total_acc",
  "collections_12_mths_ex_med", "mths_since_last_major_derog",
  "acc_now_delinq", "tot_coll_amt", "tot_cur_bal",
  "pub_rec_bankruptcies", "tax_liens",
  "delinq_amnt", "num_tl_30dpd", "num_tl_120dpd_2m",
  
  # --- Joint / secondary applicant (only populated for joint apps) ---
  "application_type", "annual_inc_joint", "dti_joint",
  "verification_status_joint", "revol_bal_joint",
  
  # --- Detailed bureau attributes (added later; missing pre-2012) ---
  "open_acc_6m", "open_act_il", "open_il_12m", "open_il_24m",
  "mths_since_rcnt_il", "total_bal_il", "il_util", "open_rv_12m",
  "open_rv_24m", "max_bal_bc", "all_util", "total_rev_hi_lim", "inq_fi",
  "total_cu_tl", "inq_last_12m", "acc_open_past_24mths", "avg_cur_bal",
  "bc_open_to_buy", "bc_util", "mo_sin_old_il_acct", "mo_sin_old_rev_tl_op",
  "mo_sin_rcnt_rev_tl_op", "mo_sin_rcnt_tl", "mort_acc",
  "mths_since_recent_bc", "mths_since_recent_bc_dlq", "mths_since_recent_inq",
  "mths_since_recent_revol_delinq", "num_accts_ever_120_pd", "num_actv_bc_tl",
  "num_actv_rev_tl", "num_bc_sats", "num_bc_tl", "num_il_tl",
  "num_op_rev_tl", "num_rev_accts", "num_rev_tl_bal_gt_0", "num_sats",
  "num_tl_90g_dpd_24m", "num_tl_op_past_12m", "pct_tl_nvr_dlq",
  "percent_bc_gt_75", "tot_hi_cred_lim", "total_bal_ex_mort",
  "total_bc_limit", "total_il_high_credit_limit",
  
  # --- Disbursement ---
  "disbursement_method"
)

# ---- Sanity checks ----
cat("Number of origination features:", length(ORIGINATION_FEATURES), "\n")

# Check every feature actually exists in the data (catches typos)
missing_cols <- setdiff(ORIGINATION_FEATURES, names(loans_raw))
if (length(missing_cols) == 0) {
  cat("All features found in the data. \n")
} else {
  cat("WARNING - these names are not in the data:\n")
  print(missing_cols)
}
----------------------------------------------------------

# ---- Define the binary default target ----
# Good (0): Fully Paid. Bad (1): Charged Off, Default.
# Everything else is excluded: outcome not yet resolved (Current, Late,
# In Grace Period), blank, or legacy "does not meet credit policy" groups.

good_status <- c("Fully Paid")
bad_status  <- c("Charged Off", "Default")

# Keep only loans with a resolved outcome
loans <- loans_raw[loan_status %in% c(good_status, bad_status)]

# Create the target: 1 = default (bad), 0 = good
loans[, default := as.integer(loan_status %in% bad_status)]

# ---- Report ----
cat("Loans before filtering:", nrow(loans_raw), "\n")
cat("Loans after keeping resolved outcomes:", nrow(loans), "\n")
cat("Default rate:", round(mean(loans$default) * 100, 2), "%\n")

# Sanity check: cross-tab of status vs target
loans[, .N, by = .(loan_status, default)][order(-N)]


------------------------------------------------------

# ---- Build the vintage (origination time) from issue_d ----
# issue_d looks like "Dec-2015". We parse it to a real date, then extract
# the year (primary analysis unit) and year-quarter (kept for robustness).

library(lubridate)

# Parse "Mon-YYYY" into a proper date (1st of that month)
loans[, issue_date := lubridate::my(issue_d)]   # my() = month-year parser

# Primary vintage: year of origination
loans[, vintage_year := year(issue_date)]

# Secondary (kept in reserve): year-quarter, e.g. "2015-Q4"
loans[, vintage_quarter := paste0(year(issue_date), "-Q", quarter(issue_date))]

# ---- Report: how many loans per year? ----
loans[, .(
  n_loans = .N,
  default_rate = round(mean(default) * 100, 1)
), by = vintage_year][order(vintage_year)]


-----------------------------------------------------
  # ---- Measure maturity per vintage ----
# How much observation time has each vintage had, relative to the data
# cutoff? Loans need roughly their full term (36 or 60 months) to mature.

# Data cutoff: the dataset ends 2018-Q4, so latest issue ~ Dec 2018.
cutoff_date <- max(loans$issue_date, na.rm = TRUE)
cat("Latest issue date in data:", format(cutoff_date), "\n\n")

# Months of observation available for each loan (issue date -> cutoff)
loans[, months_observed := lubridate::interval(issue_date, cutoff_date) %/% months(1)]

# Summarise by vintage year: loan counts, term mix, observation time
# Recompute maturity table with the confirmed term spelling
maturity_by_vintage <- loans[, .(
  n_loans          = .N,
  pct_60mth        = round(mean(term == "60 months") * 100, 1),
  avg_months_obs   = round(mean(months_observed), 0),
  default_rate     = round(mean(default) * 100, 1)
), by = vintage_year][order(vintage_year)]

print(maturity_by_vintage)