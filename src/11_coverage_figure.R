# =====================================================
# 11_coverage_figure.R
# CENTREPIECE: conformal bad-loan coverage across the credit cycle.
# Two panels (shared quarter axis), focal model lgbm_full:
#   TOP   : split conformal's class-conditional FAILURE (~0.35) - why a fix is needed
#   BOTTOM: the three drift responses zoomed near nominal 0.90 -
#           frozen Mondrian (leaks), weighted CP (partial), ACI (holds)
# The whole conformal contribution in one figure: naive fails -> conditional
# leaks -> two adaptive methods, with ACI maintaining coverage most tightly.
# Prereq: conformal, mondrian, aci_res, weighted_res in memory (09 sections).
# =====================================================

library(data.table)
stopifnot(exists("conformal"), exists("mondrian"),
          exists("aci_res"), exists("weighted_res"))
dir.create("figures", showWarnings = FALSE)

M <- "lgbm_full"
quarters <- sort(unique(conformal$quarter))
xq <- seq_along(quarters)

split_bad <- conformal[model == M][order(quarter)]$cov_bad      # ~0.35, fails
mon_bad   <- mondrian[model == M][order(quarter)]$cov_bad       # leaks 0.91->0.865
aci_bad   <- aci_res[gamma == 0.02][order(quarter)]$cov_bad     # flat 0.90
wt_bad    <- weighted_res[lambda == 0.5][order(quarter)]$cov_bad# partial fix

col_split <- "#7d2e46"   # failure
col_mon   <- "#e09f3e"   # frozen Mondrian
col_wt    <- "#5e60ce"   # weighted CP
col_aci   <- "#2a9d8f"   # ACI

render <- function(path, png = FALSE) {
  if (png) png(path, width = 1400, height = 1500, res = 200)
  else     pdf(path, width = 7, height = 7.5)
  par(mfrow = c(2, 1), mar = c(2.2, 4.6, 2.4, 1), oma = c(4.5, 0, 2, 0))
  
  # --- TOP: split conformal's failure ---
  plot(NA, xlim = c(0.8, length(quarters) + 0.2), ylim = c(0.30, 0.95),
       xaxt = "n", xlab = "", ylab = "Bad-loan coverage", las = 1, cex.axis = 0.9)
  grid(nx = NA, ny = NULL, col = "grey90")
  abline(h = 0.90, col = "grey55", lty = 3)
  lines(xq, split_bad, col = col_split, lwd = 2.5)
  points(xq, split_bad, col = col_split, pch = 16, cex = 1.1)
  text(length(quarters)/2, 0.90, "nominal 0.90", pos = 3, cex = 0.8, col = "grey40")
  title(main = "Split conformal fails on defaulters (marginal coverage masks it)",
        font.main = 1, cex.main = 0.97, adj = 0)
  legend("right", bty = "n", cex = 0.85, lwd = 2.5,
         legend = "Split conformal", col = col_split, pch = 16)
  
  # --- BOTTOM: the three fixes, zoomed ---
  plot(NA, xlim = c(0.8, length(quarters) + 0.2), ylim = c(0.84, 0.93),
       xaxt = "n", xlab = "", ylab = "Bad-loan coverage", las = 1, cex.axis = 0.9)
  grid(nx = NA, ny = NULL, col = "grey90")
  abline(h = 0.90, col = "grey55", lty = 3)
  lines(xq, mon_bad, col = col_mon, lwd = 2.5); points(xq, mon_bad, col = col_mon, pch = 15, cex = 1.1)
  lines(xq, wt_bad,  col = col_wt,  lwd = 2.5); points(xq, wt_bad,  col = col_wt,  pch = 17, cex = 1.1)
  lines(xq, aci_bad, col = col_aci, lwd = 2.5); points(xq, aci_bad, col = col_aci, pch = 18, cex = 1.3)
  title(main = "Drift responses: ACI holds nominal; weighted partial; Mondrian leaks",
        font.main = 1, cex.main = 0.97, adj = 0)
  legend("bottomleft", bty = "n", cex = 0.82, lwd = 2.5,
         legend = c("Frozen Mondrian (leaks)", "Weighted CP (partial)",
                    "ACI (holds 0.90)", "nominal 0.90"),
         col = c(col_mon, col_wt, col_aci, "grey55"),
         lty = c(1, 1, 1, 3), pch = c(15, 17, 18, NA), ncol = 2)
  
  axis(1, at = xq, labels = quarters, las = 2, cex.axis = 0.85)
  mtext("Monotone LightGBM (full), frozen on 2012-2013, across 8 test quarters",
        outer = TRUE, side = 3, cex = 0.95, font = 2)
  mtext("Note: panels use different y-axis scales", outer = TRUE, side = 1,
        line = 3.2, cex = 0.72, col = "grey45")
  dev.off()
}

render("figures/coverage_over_time.pdf", png = FALSE)
render("figures/coverage_over_time.png", png = TRUE)
cat("Wrote figures/coverage_over_time.{pdf,png}\n")