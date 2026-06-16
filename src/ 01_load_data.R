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