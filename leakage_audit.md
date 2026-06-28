# Lending Club Leakage Audit — Dictionary-Verified + Data-Verified (Task A2 / Contribution 1)

**Status:** All 151 columns classified, cross-checked against the official Lending Club Data Dictionary (Approved + Notes), and the two genuinely ambiguous fields verified empirically against the loaded data (2,260,701 loans). Dictionary confirmations are marked **[dict]**; empirical confirmations are marked **[data]**.

**Purpose:** classify every column by whether the information was available **at loan origination**. Only origination-time fields may be used as model features. Post-origination fields encode the outcome and cause leakage (the reason many published LC papers report AUC > 0.9; clean features give ~0.68–0.73).

**Three kinds of DROP** (worth distinguishing in Chapter 3): (1) **leakage** — recorded after origination, encodes the outcome; (2) **identifier** — unique label with no predictive meaning; (3) **free text** — unstructured text not used as a feature.

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
| 84 | delinq_amnt | past-due amount on accounts "now" delinquent | KEEP — "now" = application-time bureau pull [dict] |
| 104 | num_tl_120dpd_2m | accounts currently 120 dpd (updated past 2 months) | **KEEP — verified [data]** (see below) |
| 105 | num_tl_30dpd | accounts currently 30 dpd (updated past 2 months) | **KEEP — verified [data]** (see below) |
| 110 | pub_rec_bankruptcies | public-record bankruptcies | bureau at application |
| 111 | tax_liens | number of tax liens | bureau at application |
| 116 | revol_bal_joint | co-borrower revolving balance | application-time (joint) |
| 117–128 | sec_app_* | "**at time of application** for the secondary applicant" [dict] | application-time (joint) — confirmed |
| 144 | disbursement_method | CASH or DIRECT_PAY | set at origination |

---

## RESOLVED — formerly ambiguous, now decided

| # | field | how resolved | resolution |
|---|-------|--------------|------------|
| 84 | delinq_amnt | dictionary [dict] | KEEP — "now delinquent" refers to the application-time bureau pull |
| 104 | num_tl_120dpd_2m | **data verified [data]** | KEEP — see empirical check below |
| 105 | num_tl_30dpd | **data verified [data]** | KEEP — see empirical check below |
| 7, 9, 10 | int_rate / grade / sub_grade | dictionary [dict] | KEEP WITH DISCUSSION — set by LC at origination from its own risk model, so they partly encode a competing PD prediction. Report results with and without them. |

### Empirical verification of `num_tl_30dpd` and `num_tl_120dpd_2m` [data]
The dictionary wording ("currently … updated in past 2 months") left open whether these reflect the application-time pull or a later refresh. Checked directly in the data:

- **Distribution:** overwhelmingly zero (num_tl_30dpd: 2,184,561 of ~2.19M non-missing at 0; num_tl_120dpd_2m: 2,105,738 at 0), tailing off quickly to 1, 2, 3+. This is the expected shape of an application-time "accounts currently past due" bureau field — most applicants have none.
- **Missingness:** 70,309 (~3%) and 153,690 (~7%), concentrated in early vintages (consistent with late-added bureau fields, not leakage).
- **Relationship to outcome (the decisive test):** mean values are near-identical for Fully Paid vs Charged Off loans —
  - num_tl_30dpd: Fully Paid 0.00334 vs Charged Off 0.00374
  - num_tl_120dpd_2m: Fully Paid 0.00080 vs Charged Off 0.00090

  Only a *very slight* elevation for defaulters, as expected of a mild application-time risk signal. No dramatic gap that would indicate the field was refreshed to encode the loan's later trouble.

**Conclusion:** both behave as genuine application-time bureau fields. **Retained.**

*Chapter 3 sentence earned:* "Two fields with ambiguous dictionary wording (`num_tl_30dpd`, `num_tl_120dpd_2m`) were verified empirically; their distributions and near-identical means across paid and defaulted loans confirmed they reflect the application-time credit pull, and they were retained."

---

## DROP — post-origination (leakage), identifiers, or free-text

| # | field | kind | dictionary text → why dropped |
|---|-------|------|------------------------------|
| 1 | id | identifier | "unique LC assigned ID" — no predictive meaning; possible time-proxy |
| 2 | member_id | identifier | "unique LC assigned Id for the borrower" — also all-NA here |
| 4 | funded_amnt | leakage | "amount committed **at that point in time**" — post-decision |
| 5 | funded_amnt_inv | leakage | investor-funded amount — post-decision |
| 11 | emp_title | free text | "job title supplied" — note [dict]: replaced Employer Name after 9/23/2013 (inconsistent over time) |
| 18 | pymnt_plan | leakage | "if a payment plan has been put in place" — later servicing |
| 19 | url | identifier | "URL for the LC listing" — not a feature |
| 22 | title | free text | "loan title provided by the borrower" — use `purpose` instead |
| 38 | initial_list_status | other | listing status W/F — operational, not borrower risk; drop (optional) |
| 39 | out_prncp | leakage | "**Remaining** outstanding principal" — updates over loan life |
| 40 | out_prncp_inv | leakage | remaining outstanding principal (investors) — same |
| 41 | total_pymnt | leakage | "Payments received **to date**" — encodes outcome |
| 42 | total_pymnt_inv | leakage | payments received to date (investors) — encodes outcome |
| 43 | total_rec_prncp | leakage | "Principal received **to date**" — encodes outcome |
| 44 | total_rec_int | leakage | "Interest received **to date**" — encodes outcome |
| 45 | total_rec_late_fee | leakage | "Late fees received **to date**" — encodes outcome |
| 46 | recoveries | leakage | "**post charge off** gross recovery" — DEFINES default |
| 47 | collection_recovery_fee | leakage | "**post charge off** collection fee" — DEFINES default |
| 48 | last_pymnt_d | leakage | "Last month payment was received" — post-origination |
| 49 | last_pymnt_amnt | leakage | "Last total payment amount received" — post-origination |
| 50 | next_pymnt_d | leakage | "Next scheduled payment date" — post-origination |
| 51 | last_credit_pull_d | leakage | "most recent month LC pulled credit" — post-origination |
| 52 | last_fico_range_high | leakage | "borrowers **last** FICO pulled" — post-origination |
| 53 | last_fico_range_low | leakage | "borrowers **last** FICO pulled" — post-origination |
| 56 | policy_code | other | admin/constant (publicly-available flag) |
| 83 | chargeoff_within_12_mths | leakage | "charge-offs within 12 months" — outcome-adjacent; drop to be safe |
| 129–143 | hardship_* (flag, type, reason, status, deferral_term, amount, start/end dates, length, dpd, loan_status, payment_plan_start_date, orig_projected_additional_accrued_interest, hardship_payoff_balance_amount, hardship_last_payment_amount) | leakage | hardship-plan data — only exists if the loan struggled **after** origination |
| 145 | debt_settlement_flag | leakage | "borrower, **who has charged-off**, working with settlement company" — post-default |
| 146 | debt_settlement_flag_date | leakage | most recent date flag was set — post-origination |
| 147–151 | settlement_* (status, date, amount, percentage, term) | leakage | settlement details — only exist post-default |

**The most dangerous (produce the fake ~0.95 AUC):** `recoveries`, `collection_recovery_fee`, `total_rec_prncp`, `total_pymnt`, `last_pymnt_amnt`, `last_fico_range_*`, and the `hardship_*` / `settlement_*` blocks. Each is a direct fingerprint of the outcome.

---

## Summary after dictionary + data verification
- **No major corrections required** — the original audit was sound. The dictionary confirmed every dangerous drop; the two genuinely ambiguous fields were resolved by direct data checks.
- **KEEP (features):** application + bureau fields above (~85 columns; fewer in practice once heavily-missing late-added bureau fields are excluded for early vintages).
- **DROP:** ~50 columns — leakage (payment/recovery/hardship/settlement/last-* fields), identifiers (id, member_id, url), and free text (emp_title, title).
- **SPECIAL:** `issue_d` (vintage), `loan_status` (target), `desc` (out of scope).
- **VERIFIED in data:** `num_tl_30dpd`, `num_tl_120dpd_2m` — retained (behave as application-time bureau fields).
- **DISCUSS in Chapter 3:** `int_rate`, `grade`, `sub_grade` (run models with and without them).

**Chapter 3 sentence you've earned:** *"Feature timing was classified by hand, verified against the official Lending Club Data Dictionary, and — for two fields with ambiguous wording — confirmed empirically against the data; only fields available at loan origination were retained, and outcome-encoding fields (payments, recoveries, hardship and settlement records, and most-recent credit pulls) were excluded to prevent target leakage."*

**Next step:** build the `ORIGINATION_FEATURES` vector in R from the KEEP list, then define the default target from `loan_status` and the vintage from `issue_d`.
