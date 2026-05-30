p <- ggplot(eq, aes(x = depth, y = mag)) +
    geom_point(
        alpha = 0.5,
        color = "darkred"
    ) +
    theme_minimal() +
    labs(
        title = "Depth vs Magnitude",
        x = "Depth (km)",
        y = "Magnitude"
    )
ggsave("C:/Users/papro/Documents/R/wykresy/wykres4.png", width = 10, height = 6, dpi = 300)