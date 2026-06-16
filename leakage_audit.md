# Lending Club Leakage Audit — Dictionary-Verified (Task A2 / Contribution 1)

**Status:** All 151 columns classified, then cross-checked against the official Lending Club Data Dictionary (Approved + Notes). Corrections and confirmations from the dictionary are marked **[dict]**.

**Purpose:** classify every column by whether the information was available **at loan origination**. Only origination-time fields may be used as model features. Post-origination fields encode the outcome and cause leakage (the reason many published LC papers report AUC > 0.9; clean features give ~0.68–0.73).

**Three verdicts:** KEEP (available at application), DROP (recorded after origination → leakage, or unusable identifier/free-text), AMBIGUOUS-RESOLVED (the dictionary settled it).

**Note on missingness (separate from leakage):** the detailed bureau fields (#64 onward) and the `sec_app_*` joint-applicant fields were added to LC's data later and/or only apply to joint applications, so they are heavily missing in pre-2012 vintages. KEEP them in principle, but decide per-vintage whether to include them; missingness is handled after this audit.

---

## SPECIAL — target and time fields (not features, but essential)

| # | field | dictionary description | role |
|---|-------|------------------------|------|
| 16 | issue_d | "The month which the loan was funded" | **VINTAGE / time index** for temporal splits — not a feature |
| 17 | loan_status | "Current status of the loan" | **OUTCOME → default TARGET** — not a feature |
| 20 | desc | "Loan description provided by the borrower" | free text; out of scope (the "When Words Sweat" angle) — not used |

---

## KEEP — origination-time features (model inputs), dictionary-confirmed

| # | field | dictionary description (paraphrased) | note |
|---|-------|--------------------------------------|------|
| 3 | loan_amnt | listed amount applied for | available at application |
| 6 | term | 36 or 60 months | available at application |
| 7 | int_rate | interest rate on the loan | KEEP — see discussion (encodes LC's own risk view) |
| 8 | installment | monthly payment "if the loan originates" | origination-time |
| 9 | grade | LC assigned loan grade | KEEP — see discussion |
| 10 | sub_grade | LC assigned subgrade | KEEP — see discussion |
| 12 | emp_length | employment length in years | stated at application |
| 13 | home_ownership | ownership status at registration / credit report | application-time |
| 14 | annual_inc | self-reported income at registration | application-time |
| 15 | verification_status | whether income was verified | application-time |
| 21 | purpose | borrower's stated loan category | application-time |
| 23 | zip_code | first 3 digits from the application | application-time |
| 24 | addr_state | state from the application | application-time |
| 25 | dti | debt-to-income ratio | application-time |
| 26 | delinq_2yrs | 30+ dpd incidences in last 2 yrs | bureau at application |
| 27 | earliest_cr_line | month earliest credit line opened | bureau at application |
| 28 | fico_range_low | **FICO at loan origination** (low) [dict] | bureau at application |
| 29 | fico_range_high | **FICO at loan origination** (high) [dict] | bureau at application |
| 30 | inq_last_6mths | inquiries in past 6 months | bureau at application |
| 31 | mths_since_last_delinq | months since last delinquency | bureau at application |
| 32 | mths_since_last_record | months since last public record | bureau at application |
| 33 | open_acc | open credit lines | bureau at application |
| 34 | pub_rec | derogatory public records | bureau at application |
| 35 | revol_bal | revolving balance | bureau at application |
| 36 | revol_util | revolving utilisation | bureau at application |
| 37 | total_acc | total credit lines | bureau at application |
| 54 | collections_12_mths_ex_med | collections in 12m ex-medical | bureau at application |
| 55 | mths_since_last_major_derog | months since 90-day+ rating | bureau at application |
| 57 | application_type | individual or joint | application-time |
| 58 | annual_inc_joint | combined co-borrower income | application-time (joint) |
| 59 | dti_joint | joint DTI | application-time (joint) |
| 60 | verification_status_joint | joint income verified | application-time (joint) |
| 61 | acc_now_delinq | accounts now delinquent (bureau pull) | bureau at application |
| 62 | tot_coll_amt | total collection amounts ever owed | bureau at application |
| 63 | tot_cur_bal | total current balance | bureau at application |
| 64–115 | detailed bureau attributes (open_acc_6m, il_util, all_util, avg_cur_bal, bc_util, mo_sin_*, num_*, pct_tl_nvr_dlq, tot_hi_cred_lim, total_bal_ex_mort, total_bc_limit, total_il_high_credit_limit, etc.) | credit-bureau attributes | KEEP — heavily missing pre-2012 (verify per vintage) |
| 110 | pub_rec_bankruptcies | public-record bankruptcies | bureau at application |
| 111 | tax_liens | number of tax liens | bureau at application |
| 116 | revol_bal_joint | co-borrower revolving balance | application-time (joint) |
| 117–128 | sec_app_* | "**at time of application** for the secondary applicant" [dict] | application-time (joint) — confirmed |
| 144 | disbursement_method | CASH or DIRECT_PAY | set at origination |

---

## AMBIGUOUS → RESOLVED by the dictionary

| # | field | dictionary text | resolution |
|---|-------|-----------------|------------|
| 84 | delinq_amnt | "past-due amount owed for the accounts on which the borrower is **now** delinquent" | **KEEP** — "now" = the application-time bureau pull; it sits among bureau fields |
| 104 | num_tl_120dpd_2m | "accounts **currently** 120 dpd (updated in past 2 months)" | **KEEP-BUT-VERIFY** — "currently/updated in past 2 months" should reflect the application pull; confirm it is populated at origination and not refreshed later |
| 105 | num_tl_30dpd | "accounts **currently** 30 dpd (updated in past 2 months)" | **KEEP-BUT-VERIFY** — same caveat as #104 |
| 7, 9, 10 | int_rate / grade / sub_grade | terse ("Interest Rate on the loan" / "LC assigned grade") | **KEEP WITH DISCUSSION** — set by LC at origination from its own risk model, so they partly encode a competing PD prediction. Report results with and without them. |

---

## DROP — post-origination (leakage), identifiers, or free-text

| # | field | dictionary text → why dropped |
|---|-------|------------------------------|
| 1 | id | "unique LC assigned ID" — identifier |
| 2 | member_id | "unique LC assigned Id for the borrower" — identifier (also all-NA here) |
| 4 | funded_amnt | "amount committed **at that point in time**" — post-decision |
| 5 | funded_amnt_inv | investor-funded amount — post-decision |
| 11 | emp_title | "job title supplied" — free text; note [dict]: replaced Employer Name after 9/23/2013 (inconsistent over time) |
| 18 | pymnt_plan | "if a payment plan has been put in place" — later servicing |
| 19 | url | "URL for the LC listing" — not a feature |
| 22 | title | "loan title provided by the borrower" — free text (use `purpose`) |
| 38 | initial_list_status | listing status W/F — operational, not borrower risk; drop (optional) |
| 39 | out_prncp | "**Remaining** outstanding principal" — updates over loan life |
| 40 | out_prncp_inv | remaining outstanding principal (investors) — same |
| 41 | total_pymnt | "Payments received **to date**" — encodes outcome |
| 42 | total_pymnt_inv | payments received to date (investors) — encodes outcome |
| 43 | total_rec_prncp | "Principal received **to date**" — encodes outcome |
| 44 | total_rec_int | "Interest received **to date**" — encodes outcome |
| 45 | total_rec_late_fee | "Late fees received **to date**" — encodes outcome |
| 46 | recoveries | "**post charge off** gross recovery" — DEFINES default |
| 47 | collection_recovery_fee | "**post charge off** collection fee" — DEFINES default |
| 48 | last_pymnt_d | "Last month payment was received" — post-origination |
| 49 | last_pymnt_amnt | "Last total payment amount received" — post-origination |
| 50 | next_pymnt_d | "Next scheduled payment date" — post-origination |
| 51 | last_credit_pull_d | "most recent month LC pulled credit" — post-origination |
| 52 | last_fico_range_high | "borrowers **last** FICO pulled" — post-origination |
| 53 | last_fico_range_low | "borrowers **last** FICO pulled" — post-origination |
| 56 | policy_code | admin/constant (publicly-available flag) |
| 83 | chargeoff_within_12_mths | "charge-offs within 12 months" — outcome-adjacent; drop to be safe |
| 129–143 | hardship_* (flag, type, reason, status, deferral_term, amount, start/end dates, length, dpd, loan_status, payment_plan_start_date, orig_projected_additional_accrued_interest, hardship_payoff_balance_amount, hardship_last_payment_amount) | hardship-plan data — only exists if the loan struggled **after** origination |
| 145 | debt_settlement_flag | "borrower, **who has charged-off**, working with settlement company" — post-default |
| 146 | debt_settlement_flag_date | most recent date flag was set — post-origination |
| 147–151 | settlement_* (status, date, amount, percentage, term) | settlement details — only exist post-default |

**The most dangerous (produce the fake ~0.95 AUC):** `recoveries`, `collection_recovery_fee`, `total_rec_prncp`, `total_pymnt`, `last_pymnt_amnt`, `last_fico_range_*`, and the `hardship_*` / `settlement_*` blocks. Each is a direct fingerprint of the outcome.

---

## Summary after dictionary verification
- **No major corrections required** — the original audit was sound. The dictionary confirmed every dangerous drop and resolved the four judgement calls.
- **KEEP (features):** application + bureau fields above (~85 columns; fewer in practice once heavily-missing late-added bureau fields are excluded for early vintages).
- **DROP:** ~50 columns — all payment/recovery/hardship/settlement/last-* fields plus IDs, URL, and free-text titles.
- **SPECIAL:** `issue_d` (vintage), `loan_status` (target), `desc` (out of scope).
- **VERIFY in data:** `num_tl_120dpd_2m`, `num_tl_30dpd` (confirm they reflect the application-time pull, not a later refresh).
- **DISCUSS in Chapter 3:** `int_rate`, `grade`, `sub_grade` (run models with and without them).

**Chapter 3 sentence you've earned:** *"Feature timing was classified by hand and verified against the official Lending Club Data Dictionary; only fields available at loan origination were retained, and outcome-encoding fields (payments, recoveries, hardship and settlement records, and most-recent credit pulls) were excluded to prevent target leakage."*

**Next step:** build the `ORIGINATION_FEATURES` vector in R from the KEEP list, then define the default target from `loan_status` and the vintage from `issue_d`.
