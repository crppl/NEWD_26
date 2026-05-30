library(dplyr)
library(lubridate)

eq$time <- as.POSIXct(eq$time, origin = "1970-01-01")
eq$year <- year(eq$time)

eq_filtered <- eq %>%
    filter(mag > 5) %>%
    mutate(year = as.integer(year)) %>%   # ważne: integer, nie factor
    group_by(year, longitude, latitude) %>%  # eliminuje duplikaty klatek
    summarise(
        mag = mean(mag),
        depth = mean(depth),
        .groups = "drop"
    )

library(ggplot2)
library(gganimate)

p <- ggplot(eq_filtered, aes(longitude, latitude)) +
    borders("world", colour = "gray70") +
    geom_point(
        aes(size = mag, color = depth),
        alpha = 0.7
    ) +
    scale_color_gradient(low = "yellow", high = "red") +
    theme_minimal() +
    transition_states(
        year,
        state_length = 1,
        transition_length = 0
    ) +
    labs(
        title = "Earthquakes: {closest_state}"
    )

print(animate(p, fps =  10, width = 1000, height = 600))