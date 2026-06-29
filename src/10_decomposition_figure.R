# =====================================================
# 10_decomposition_figure.R
# C3 CAPSTONE: decay decomposition for lgbm_full across 8 quarters.
# Three stacked panels, natural units, sharing the quarter axis:
#   1. Discrimination (AUC)         -> holds
#   2. Calibration (ECE)            -> decays
#   3. Validity (conformal coverage)-> frozen Mondrian leaks; ACI holds
# Shows the full thesis: discrimination is robust, calibration is the first
# casualty, validity decays but an adaptive method repairs it.
# Prereq: decay, mondrian, aci_res in memory (05 + 09 sections).
# =====================================================

library(data.table)
stopifnot(exists("decay"), exists("mondrian"), exists("aci_res"))
dir.create("figures", showWarnings = FALSE)

M <- "lgbm_full"
quarters <- sort(unique(decay$quarter))
xq <- seq_along(quarters)

# Pull each curve, ordered by quarter
d_auc <- decay[model == M][order(quarter)]$AUC
d_ece <- decay[model == M][order(quarter)]$ECE
d_mon <- mondrian[model == M][order(quarter)]$cov_bad          # frozen Mondrian, leaks
d_aci <- aci_res[gamma == 0.02][order(quarter)]$cov_bad        # ACI, holds

col_hold <- "#1b4965"   # discrimination
col_ece  <- "#bc4749"   # calibration (the casualty)
col_mon  <- "#e09f3e"   # frozen Mondrian (leaking)
col_aci  <- "#2a9d8f"   # ACI (repaired)

panel <- function(yv, ylab, ylim, col, pch = 16, title_txt = "") {
  plot(NA, xlim = c(0.8, length(quarters) + 0.2), ylim = ylim,
       xaxt = "n", xlab = "", ylab = ylab, las = 1, cex.axis = 0.9)
  grid(nx = NA, ny = NULL, col = "grey90")
  lines(xq, yv, col = col, lwd = 2.5); points(xq, yv, col = col, pch = pch, cex = 1.1)
  if (nzchar(title_txt)) title(main = title_txt, font.main = 1, cex.main = 1, adj = 0)
}

render <- function(path, png = FALSE) {
  if (png) png(path, width = 1400, height = 1700, res = 200)
  else     pdf(path, width = 7, height = 8.5)
  par(mfrow = c(3, 1), mar = c(2.4, 4.6, 2.2, 1), oma = c(4, 0, 2, 0))
  
  # 1. Discrimination
  panel(d_auc, "AUC", ylim = c(0.66, 0.74), col = col_hold,
        title_txt = "Discrimination holds")
  
  # 2. Calibration
  panel(d_ece, "ECE", ylim = c(0, max(d_ece) * 1.1), col = col_ece, pch = 17,
        title_txt = "Calibration decays (the first casualty)")
  
  # 3. Validity: Mondrian (leaks) vs ACI (holds)
  plot(NA, xlim = c(0.8, length(quarters) + 0.2), ylim = c(0.83, 0.93),
       xaxt = "n", xlab = "", ylab = "Bad-loan coverage", las = 1, cex.axis = 0.9)
  grid(nx = NA, ny = NULL, col = "grey90")
  abline(h = 0.90, col = "grey55", lty = 3)                    # nominal target
  lines(xq, d_mon, col = col_mon, lwd = 2.5, lty = 1)
  points(xq, d_mon, col = col_mon, pch = 15, cex = 1.1)
  lines(xq, d_aci, col = col_aci, lwd = 2.5, lty = 1)
  points(xq, d_aci, col = col_aci, pch = 18, cex = 1.3)
  title(main = "Validity decays - but ACI repairs it", font.main = 1,
        cex.main = 1, adj = 0)
  legend("bottomleft", bty = "n", cex = 0.85, lwd = 2.5,
         legend = c("Frozen Mondrian (leaks)", "Adaptive ACI (holds 0.90)",
                    "Nominal 0.90"),
         col = c(col_mon, col_aci, "grey55"),
         lty = c(1, 1, 3), pch = c(15, 18, NA))
  
  axis(1, at = xq, labels = quarters, las = 2, cex.axis = 0.85)
  mtext("Monotone LightGBM (full), frozen on 2012-2013, across 8 test quarters",
        outer = TRUE, side = 3, cex = 0.95, font = 2)
  dev.off()
}

render("figures/decay_decomposition.pdf", png = FALSE)
render("figures/decay_decomposition.png", png = TRUE)
cat("Wrote figures/decay_decomposition.{pdf,png}\n")