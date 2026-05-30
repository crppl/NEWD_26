library(dplyr)
library(stringr)

eq <- eq %>%
    mutate(
        region = str_trim(str_extract(place, "[^,]+$"))
    )
top_regions <- eq %>%
    count(region, sort = TRUE) %>%
    slice(1:10)
eq2 <- eq %>%
    filter(region %in% top_regions$region)
library(ggplot2)

p <- ggplot(eq2, aes(x = reorder(region, mag), y = mag)) +
    geom_boxplot(fill = "orange") +
    coord_flip() +
    theme_minimal() +
    labs(
        title = "Magnitude distribution by region",
        x = "Region",
        y = "Magnitude"
    )

ggsave("C:/Users/papro/Documents/R/wykresy/wykres7.png", width = 10, height = 6, dpi = 300)