top10 <- eq %>%
    arrange(desc(mag)) %>%
    slice(1:10)

p <- ggplot(top10, aes(x = reorder(place, mag), y = mag)) +
    geom_col(fill = "lightblue") +
    coord_flip() +
    theme_minimal() +
    labs(
        title = "Top 10 strongest earthquakes",
        x = "Location",
        y = "Magnitude"
    )
ggsave("C:/Users/papro/Documents/R/wykresy/wykres8.png", width = 10, height = 6, dpi = 300)