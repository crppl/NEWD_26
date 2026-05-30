library(ggplot2)
library(maps)
library(dplyr)

world <- map_data("world")

eq_filtered <- eq %>%
    filter(mag > 5)

p <- ggplot() +
    geom_map(
        data = world,
        map = world,
        aes(long, lat, map_id = region),
        fill = "gray90",
        color = "white"
    ) +
    geom_point(
        data = eq_filtered,
        aes(
            x = longitude,
            y = latitude,
            size = mag,
            color = depth
        ),
        alpha = 0.7
    ) +
    scale_size_continuous(name = "Magnitude") +
    scale_color_gradient(low = "yellow", high = "red") +
    coord_fixed(1.3) +
    theme_minimal() +
    labs(
        title = "Earthquakes around the world",
        x = "Longitude",
        y = "Latitude"
    )

ggsave("C:/Users/papro/Documents/R/wykresy/wykres1.png", width = 10, height = 6, dpi = 300)