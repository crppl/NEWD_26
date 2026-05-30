library(ggplot2)
library(maps)
library(dplyr)

world <- map_data("world")

# filtr
eq_filtered <- eq %>%
    filter(mag > 5)

p <- ggplot() +

    # mapa świata
    geom_polygon(
        data = world,
        aes(x = long, y = lat, group = group),
        fill = "gray90",
        color = "white",
        linewidth = 0.2
    ) +

    # heatmapa
    geom_bin2d(
        data = eq_filtered,
        aes(x = longitude, y = latitude),
        bins = 60,
        alpha = 0.5
    ) +

    scale_fill_gradient(
        low = "lightblue",
        high = "red",
        name = "Count"
    ) +

    coord_fixed(1.3) +

    theme_minimal() +

    labs(
        title = "Earthquake Density Heatmap (Magnitude > 5)",
        x = "Longitude",
        y = "Latitude"
    )

print(p)

ggsave(
    "C:/Users/papro/Documents/R/wykresy/wykres5.png",
    plot = p,
    width = 10,
    height = 6,
    dpi = 300
)