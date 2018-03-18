name_prefix <- "2018-03-18-transforming-functions-with-cases-calls-"

library(pmatch)

tree := L(num) | T(left : tree, right : tree)

is_leaf <- function(tree) {
    cases(tree,
          L(x) -> TRUE,
          otherwise -> FALSE)
}

is_leaf_tr <- transform_cases_function(is_leaf)
is_leaf_tr_bc <- compiler::cmpfun(is_leaf_tr)

bm <- microbenchmark::microbenchmark(
    is_leaf(L(1)), is_leaf_tr(L(1)), is_leaf_tr_bc(L(1))
)

library(ggplot2)
library(bloggraphics)

ggplot(bm, aes(x = expr, y = time, fill=expr)) +
    scale_y_log10("Time (log-scale)") +
    geom_boxplot(width = .2, outlier.shape = NA, alpha = 0.5) +
    geom_point(position = position_jitter(width = .1), size = .5, alpha = 0.8) +
    scale_x_discrete(
        "Function",
        labels = c(
            "plain is_empty", "+ transform", "+transform\n+byte-compile"
    )) +
    scale_fill_brewer(palette = "Set2") +
    blog_theme() + theme(legend.position="none")

save_for_blog <- function(name_prefix, name) {
    filename <- paste0(
        "/Users/mailund/Projects/r-programmer-blog/static/images/",
        name_prefix, "_", name, ".png"
    )
    image_url <- paste0(
        "https://mailund.github.io/r-programmer-blog/images/",
        name_prefix, "_", name, ".png"
    )
    ggsave(filename, units="cm", width=15, height=10)
    cat(image_url)
    invisible(image_url)
}

save_for_blog(name_prefix, "is_empty_benchmarks")
