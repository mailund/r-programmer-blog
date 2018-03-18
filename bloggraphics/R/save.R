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

