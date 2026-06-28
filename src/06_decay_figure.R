# =====================================================
# 06_decay_figure.R
# Centrepiece figure: discrimination vs calibration decay.
# Two stacked panels sharing the quarter axis -
#   top:    AUC across quarters (flat-to-rising = discrimination robust)
#   bottom: ECE across quarters (5-10x rise = calibration is first casualty)
# Frozen base models, 8 test quarters (2014-Q1 .. 2015-Q4).
# Prerequisite: `decay` table in memory (from 05_models.R Section 3).
# =====================================================

library(data.table)
stopifnot(exists("decay"))

dir.create("figures", showWarnings = FALSE)

models   <- c("woe_full", "woe_clean", "lgbm_full", "lgbm_clean")
labels   <- c("WOE-logistic (full)", "WOE-logistic (clean)",
              "LightGBM (full)", "LightGBM (clean)")
cols     <- c("#1b4965", "#62b6cb", "#bc4749", "#e09f3e")  # 2 blues, 2 warm
ltys     <- c(1, 2, 1, 2)                                  # full solid, clean dashed
pchs     <- c(16, 17, 16, 17)

quarters <- sort(unique(decay$quarter))
xq       <- seq_along(quarters)

draw_panel <- function(metric, ylab, ylim, nominal = NULL) {
  plot(NA, xlim = c(0.8, length(quarters) + 0.2), ylim = ylim,
       xaxt = "n", xlab = "", ylab = ylab, las = 1, cex.axis = 0.9)
  axis(1, at = xq, labels = quarters, cex.axis = 0.85, las = 2)
  grid(nx = NA, ny = NULL, col = "grey90", lty = 1)
  if (!is.null(nominal)) abline(h = nominal, col = "grey60", lty = 3)
  for (i in seq_along(models)) {
    d <- decay[model == models[i]][order(quarter)]
    lines(xq, d[[metric]], col = cols[i], lty = ltys[i], lwd = 2)
    points(xq, d[[metric]], col = cols[i], pch = pchs[i], cex = 1.1)
  }
}

open_dev <- function(path, png = FALSE) {
  if (png) png(path, width = 1500, height = 1500, res = 200)
  else     pdf(path, width = 7.2, height = 7.2)
}

render <- function(path, png = FALSE) {
  open_dev(path, png)
  par(mfrow = c(2, 1), mar = c(4.2, 4.5, 2.2, 1), oma = c(0, 0, 1.5, 0))
  
  # Top: AUC
  draw_panel("AUC", "AUC (discrimination)", ylim = c(0.66, 0.74))
  title(main = "Discrimination holds", font.main = 1, cex.main = 1.05, adj = 0)
  legend("bottomright", legend = labels, col = cols, lty = ltys, pch = pchs,
         lwd = 2, bty = "n", cex = 0.8, ncol = 2)
  
  # Bottom: ECE
  draw_panel("ECE", "ECE (calibration error)", ylim = c(0, 0.06))
  title(main = "Calibration decays (5-10x)", font.main = 1, cex.main = 1.05, adj = 0)
  
  mtext("Frozen models fit on 2012-2013, evaluated across later quarters",
        outer = TRUE, cex = 0.95, font = 2)
  dev.off()
}

render("figures/decay_auc_vs_ece.pdf", png = FALSE)
render("figures/decay_auc_vs_ece.png", png = TRUE)
cat("Wrote figures/decay_auc_vs_ece.{pdf,png}\n")