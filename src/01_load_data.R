# =====================================================
# A1 — Load and inspect the Lending Club accepted-loans data
# =====================================================

library(data.table)

# Load the raw accepted-loans file (this takes a minute - it's large)
loans_raw <- fread("data/raw/accepted_2007_to_2018q4.csv/accepted_2007_to_2018Q4 2.csv")
# How big is it? (rows, columns)
cat("Rows:", nrow(loans_raw), "\n")
cat("Columns:", ncol(loans_raw), "\n")

# What are the column names?
names(loans_raw)

-------
  
  # Distribution of values and missingness for the two fields
  loans_raw[, .N, by = num_tl_30dpd][order(num_tl_30dpd)]
loans_raw[, .N, by = num_tl_120dpd_2m][order(num_tl_120dpd_2m)]

# How many are missing (NA)?
cat("num_tl_30dpd missing:", sum(is.na(loans_raw$num_tl_30dpd)), "\n")
cat("num_tl_120dpd_2m missing:", sum(is.na(loans_raw$num_tl_120dpd_2m)), "\n")

------
  
  # Average value of each field, split by whether the loan was charged off
  loans_raw[, .(
    avg_30dpd = mean(num_tl_30dpd, na.rm = TRUE),
    avg_120dpd = mean(num_tl_120dpd_2m, na.rm = TRUE),
    n = .N
  ), by = loan_status][order(-n)]