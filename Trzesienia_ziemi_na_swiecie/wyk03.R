p <- ggplot(eq, aes(x = mag)) +
    geom_histogram(
        binwidth = 0.2,
        fill = "steelblue",
        color = "black"
    ) +
    theme_minimal() +
    labs(
        title = "Distribution of earthquake magnitudes",
        x = "Magnitude",
        y = "Count"
    )
ggsave("C:/Users/papro/Documents/R/wykresy/wykres3.png", width = 10, height = 6, dpi = 300)