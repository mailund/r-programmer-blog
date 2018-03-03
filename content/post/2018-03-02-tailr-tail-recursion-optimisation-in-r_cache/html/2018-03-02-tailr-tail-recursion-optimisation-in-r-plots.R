theme_lab <- function () {
    theme_grey(base_size = 11.5) %+replace%
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
            #axis.title = element_text(family = "Open Sans", size = 11, colour = "#757575", face = "plain", hjust = 1),
            #axis.text = element_text(family = "Open Sans", size = 10, colour = "#757575", face = "plain"),
            legend.title = element_text(size = 12, colour = "#757575"),
            legend.text = element_text(size = 10, colour = "#757575")#,
            #strip.text = element_text(family = "Open Sans", size = 12, colour = "#757575", face = "plain")
        )
}


bm <- microbenchmark::microbenchmark(factorial(n),
                                     loop_factorial(n),
                                     tr_factorial(n))

library(ggplot2)
ggplot(bm, aes(x = expr, y = time, fill = expr, alpha = 0.8)) + # "#fc6721"
    scale_fill_brewer(palette = "Set2") +
    geom_boxplot() +
    scale_y_log10("Microseconds (log-scale)",
                  breaks = seq(0, 2878054, by = 100000),
                  labels = seq(0, 2878054, by = 100000)
    ) +
    scale_x_discrete("Function", labels = c("factorial()", "loop_factorial()", "tr_factorial()")) +
    xlab("Function") +
    theme_lab() + theme(panel.grid.major.x = element_blank(), legend.position = "none")


ggsave("Factorial-running-times.png")


test_llist <- make_llist(100)
bm <- microbenchmark::microbenchmark(llength(test_llist),
                               loop_llength(test_llist),
                               tr_llength(test_llist))

ggplot(bm, aes(x = expr, y = time, fill = expr, alpha = 0.8)) + # "#fc6721"
    scale_fill_brewer(palette = "Set2") +
    geom_boxplot() +
    scale_y_log10("Milliseconds (log-scale)",
                  breaks = seq(33000000, 110000000, by = 10000000),
                  labels = seq(33000000, 110000000, by = 10000000)
                  ) +
    scale_x_discrete("Function", labels = c("llength()", "loop_llength()", "tr_llength()")) +
    xlab("Function") +
    theme_lab() + theme(panel.grid.major.x = element_blank(), legend.position = "none")

ggsave("llength-running-time.png")
