# =====================================================
# 08_recal_figure.R
# Recalibration result: rolling fixes calibration decay, static backfires.
# One panel - lgbm_full ECE across 8 quarters:
#   uncalibrated (grey, climbs) | static (red, climbs worse)
#   | rolling (green, stays low). Methods near-identical -> show beta only.
# Prerequisite: `recal` table in memory (from 07_recalibration.R).
# =====================================================
library(data.table)
stopifnot(exists("recal"))
dir.create("figures", showWarnings = FALSE)
M <- "lgbm_full"
d <- recal[model == M]
quarters <- sort(unique(d$quarter))
xq <- seq_along(quarters)
getline <- function(k) d[key == k][order(quarter)]$ECE   # NA-safe, ordered
uncal   <- getline("uncalibrated")
static  <- getline("beta_static")
# rolling has no Q1 value (no predecessor) -> pad to length 8, aligned by quarter
rolling <- recal[model == M & key == "beta_rolling"][order(quarter)]
rolling <- rolling[match(quarters, quarter)]$ECE   # NA where quarter missing (Q1)
render <- function(path, png = FALSE) {
  if (png) png(path, width = 1500, height = 1000, res = 200)
  else     pdf(path, width = 7.2, height = 4.8)
  par(mar = c(6.5, 4.6, 2.4, 1))
  
  ylim <- c(0, max(c(uncal, static), na.rm = TRUE) * 1.08)
  plot(NA, xlim = c(0.8, length(quarters) + 0.2), ylim = ylim,
       xaxt = "n", xlab = "", ylab = "ECE (calibration error)", las = 1)
  axis(1, at = xq, labels = quarters, las = 2, cex.axis = 0.85)
  grid(nx = NA, ny = NULL, col = "grey90")
  
  # anchor: the well-calibrated 2014-Q1 starting level
  abline(h = uncal[1], col = "grey75", lty = 3)
  
  lines(xq, static,  col = "#bc4749", lwd = 2.5, lty = 1)
  points(xq, static, col = "#bc4749", pch = 17, cex = 1.1)
  lines(xq, uncal,   col = "#8d99ae", lwd = 2.5, lty = 2)
  points(xq, uncal,  col = "#8d99ae", pch = 16, cex = 1.1)
  lines(xq, rolling, col = "#2a9d8f", lwd = 2.5, lty = 1)
  points(xq, rolling, col = "#2a9d8f", pch = 15, cex = 1.1)
  
  legend("topleft", bty = "n", cex = 0.85, lwd = 2.5,
         legend = c("Static recalibration (backfires)",
                    "Uncalibrated",
                    "Rolling recalibration (fixes it)"),
         col = c("#bc4749", "#8d99ae", "#2a9d8f"),
         lty = c(1, 2, 1), pch = c(17, 16, 15))
  
  title(main = "Recalibrating on recent data fixes the decay; on stale data it worsens it",
        font.main = 1, cex.main = 0.95, adj = 0)
  mtext("Monotone LightGBM (full), 8 test quarters", side = 1, line = 5.2,
        cex = 0.8, col = "grey40")
  dev.off()
}
render("figures/recal_static_vs_rolling.pdf", png = FALSE)
render("figures/recal_static_vs_rolling.png", png = TRUE)
cat("Wrote figures/recal_static_vs_rolling.{pdf,png}\n")