eq_by_month <- eq %>%
    group_by(month) %>%
    summarise(count = n())

p <- ggplot(eq_by_month, aes(x = month, y = count)) +
    geom_line(linewidth = 1) +
    theme_minimal() +
    labs(
        title = "Number of earthquakes over time",
        x = "Date",
        y = "Count"
    )
ggsave("C:/Users/papro/Documents/R/wykresy/wykres2.png", width = 10, height = 6, dpi = 300)