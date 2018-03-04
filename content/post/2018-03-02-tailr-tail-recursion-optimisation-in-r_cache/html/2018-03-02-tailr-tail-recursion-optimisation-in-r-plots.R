
library(ggplot2)

theme_blog <- function () {
    theme_gray(base_size = 11.5, base_family = "Roboto") %+replace%
        theme(
            # add padding to the plot
            plot.margin = unit(rep(0.5, 4), "cm"),
            # remove the plot background and border
            plot.background = element_blank(),
            panel.background = element_blank(),
            panel.border = element_blank(),
            # make the legend and strip background transparent
            legend.background = element_rect(fill = "transparent", colour = NA),
            legend.key = element_rect(fill = "transparent", colour = NA),
            strip.background = element_rect(fill = "transparent", colour = NA),
            # add light, dotted major grid lines only
            panel.grid.major = element_line(linetype = "dotted", colour = "#757575", size = 0.3),
            panel.grid.minor = element_blank(),
            # remove the axis tick marks and hide axis lines
            axis.ticks = element_blank(),
            axis.line = element_line(color = "#FFFFFF", size = 0.3),
            # modify the bottom margins of the title and subtitle
            plot.title = element_text(size = 18, colour = "#757575", hjust = 0, margin = margin(b = 4)),
            plot.subtitle = element_text(size = 12, colour = "#757575", hjust = 0, margin = margin(b = 10)),
            # add padding to the caption
            plot.caption = element_text(size = 10, colour = "#212121", hjust = 1, margin = margin(t = 15)),
            # change to Open Sans for axes titles, tick labels, legend title and legend key, and strip text
            axis.title = element_text(family = "Open Sans", size = 11, colour = "#757575", face = "plain", hjust = 1),
            axis.text = element_text(family = "Open Sans", size = 10, colour = "#757575", face = "plain"),
            legend.title = element_text(size = 12, colour = "#757575"),
            legend.text = element_text(size = 10, colour = "#757575"),
            strip.text = element_text(family = "Open Sans", size = 12, colour = "#757575", face = "plain")
        )
}

roundUp <- function(x) 10^ceiling(log10(x))
roundDown <- function(x) 10^floor(log10(x))

log10_ticks <- function(elms) {
    bottom <- roundDown(min(elms))
    top <- roundUp(max(elms))
    orders_of_mag <- log10(top) - log10(bottom)
    if (orders_of_mag < 0) orders_of_mag <- 1

    # it is slightly easier to compute it this way, where
    # I have some zeroes when changing order of magnitude
    # that I can just delete again later
    ticks <- vector("numeric", length = 10*orders_of_mag)
    m <- bottom
    for (i in 1:orders_of_mag) {
        for (j in 1:9) {
            ticks[10*(i-1) + j] <- m * j
        }
        m <- 10 * m
    }
    ticks[10*i] <- m
    ticks[ticks != 0]
}

log10_ticks(bm$time)

bm <- microbenchmark::microbenchmark(factorial(n),
                                     loop_factorial(n),
                                     tr_factorial(n))

ggplot(bm, aes(x = expr, y = time, fill = "#fc6721", alpha = 0.2)) + # "#fc6721"
    geom_boxplot() +
    scale_y_log10("Microseconds (log-scale)") + #, breaks = log10_ticks(bm$time)) +
    scale_x_discrete("Function", labels = c("factorial()", "loop_factorial()", "tr_factorial()")) +
    xlab("Function") +
    annotation_logticks(sides = "l", linetype = "solid") +
    theme_blog() + theme(panel.grid.major.x = element_blank(), legend.position = "none")

# ggsave("Factorial-running-times.png")
#
#
# test_llist <- make_llist(100)
# bm <- microbenchmark::microbenchmark(llength(test_llist),
#                                loop_llength(test_llist),
#                                tr_llength(test_llist))
#
# ggplot(bm, aes(x = expr, y = time, fill = expr, alpha = 0.8)) + # "#fc6721"
#     scale_fill_brewer(palette = "Set2") +
#     geom_boxplot() +
#     scale_y_log10("Milliseconds (log-scale)", breaks = log10_ticks(bm$time)) +
#     scale_x_discrete("Function", labels = c("llength()", "loop_llength()", "tr_llength()")) +
#     xlab("Function") +
#     theme_blog() + theme(panel.grid.major.x = element_blank(), legend.position = "none")
#
# ggsave("llength-running-time.png")
