required_packages <- c(
  "readr", "dplyr", "tidyr", "ggplot2", "lubridate",
  "stringr", "forcats", "scales", "svglite"
)

missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) > 0) {
  install.packages(missing_packages, repos = "https://cloud.r-project.org")
}

invisible(lapply(required_packages, library, character.only = TRUE))

base_dir <- "/Users/jan/Desktop/smieci"
output_dir <- file.path(base_dir, "wykresy")
png_dir <- file.path(output_dir, "png")
svg_dir <- file.path(output_dir, "svg")

dir.create(png_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(svg_dir, recursive = TRUE, showWarnings = FALSE)

input_candidates <- c(
  file.path(base_dir, "satcat.csv"),
  "satcat.csv"
)

input_file <- input_candidates[file.exists(input_candidates)][1]

if (is.na(input_file)) {
  stop(
    "Nie znaleziono pliku satcat.csv."
  )
}

save_plot <- function(plot, number, width = 12, height = 7, dpi = 300) {
  png_path <- file.path(png_dir, paste0(number, ".png"))
  svg_path <- file.path(svg_dir, paste0(number, ".svg"))
  
  ggplot2::ggsave(
    filename = png_path,
    plot = plot,
    width = width,
    height = height,
    dpi = dpi,
    bg = "white"
  )
  
  ggplot2::ggsave(
    filename = svg_path,
    plot = plot,
    width = width,
    height = height,
    device = svglite::svglite,
    bg = "white"
  )
}

satcat_raw <- readr::read_csv(input_file, show_col_types = FALSE)

required_columns <- c(
  "OBJECT_NAME", "OBJECT_ID", "NORAD_CAT_ID", "OBJECT_TYPE", "OPS_STATUS_CODE",
  "OWNER", "LAUNCH_DATE", "LAUNCH_SITE", "DECAY_DATE", "PERIOD",
  "INCLINATION", "APOGEE", "PERIGEE", "RCS", "DATA_STATUS_CODE",
  "ORBIT_CENTER", "ORBIT_TYPE"
)

missing_columns <- setdiff(required_columns, names(satcat_raw))

if (length(missing_columns) > 0) {
  stop("brakuje kolumn: ", paste(missing_columns, collapse = ", "))
}

owner_dictionary <- c(
  "US" = "Stany Zjednoczone",
  "CIS" = "Rosja / ZSRR / WNP",
  "PRC" = "Chiny",
  "FR" = "Francja",
  "JPN" = "Japonia",
  "IND" = "Indie",
  "UK" = "Wielka Brytania",
  "TBD" = "Właściciel do ustalenia",
  "ESA" = "Europejska Agencja Kosmiczna",
  "GER" = "Niemcy",
  "IT" = "Włochy",
  "ITSO" = "ITSO",
  "ISS" = "Międzynarodowa Stacja Kosmiczna",
  "CA" = "Kanada",
  "SPN" = "Hiszpania",
  "ORB" = "Orbcomm",
  "CHBZ" = "Chiny / Brazylia",
  "GLOB" = "Globalstar",
  "SKOR" = "Korea Południowa",
  "ARGN" = "Argentyna",
  "AUS" = "Australia",
  "SES" = "SES",
  "ISRA" = "Izrael",
  "EUTE" = "Eutelsat",
  "TURK" = "Turcja",
  "ROC" = "Tajwan",
  "FIN" = "Finlandia",
  "SEAL" = "Sea Launch",
  "IRAN" = "Iran",
  "UAE" = "Zjednoczone Emiraty Arabskie",
  "O3B" = "O3b Networks",
  "LUXE" = "Luksemburg",
  "NATO" = "NATO",
  "MEX" = "Meksyk",
  "BRAZ" = "Brazylia",
  "SAFR" = "Republika Południowej Afryki",
  "POL" = "Polska"
)

launch_site_dictionary <- c(
  "AFETR" = "Cape Canaveral, USA",
  "PLMSC" = "Plesieck, Rosja",
  "AFWTR" = "Vandenberg, USA",
  "TYMSC" = "Bajkonur, Kazachstan",
  "TAISC" = "Taiyuan, Chiny",
  "FRGUI" = "Kourou, Gujana Francuska",
  "JSC" = "Jiuquan, Chiny",
  "SRILR" = "Sriharikota, Indie",
  "XICLF" = "Xichang, Chiny",
  "TANSC" = "Tanegashima, Japonia",
  "VOSTO" = "Wostocznyj, Rosja",
  "KYMSC" = "Kapustin Jar, Rosja",
  "RLLB" = "Mahia, Nowa Zelandia",
  "WSC" = "Wenchang, Chiny",
  "WLPIS" = "Wallops Island, USA",
  "KSCUT" = "Uchinoura, Japonia",
  "YSLA" = "Morze Żółte, Chiny",
  "DLS" = "Dombarowski, Rosja",
  "SEAL" = "Sea Launch",
  "ERAS" = "Start powietrzny, USA",
  "WRAS" = "Start powietrzny, USA"
)

satcat <- satcat_raw %>%
  rename_with(stringr::str_to_lower) %>%
  mutate(
    object_name = as.character(object_name),
    object_id = as.character(object_id),
    object_type = stringr::str_trim(as.character(object_type)),
    ops_status_code = stringr::str_trim(as.character(ops_status_code)),
    owner = stringr::str_trim(as.character(owner)),
    launch_site = stringr::str_trim(as.character(launch_site)),
    orbit_center = stringr::str_trim(as.character(orbit_center)),
    orbit_type = stringr::str_trim(as.character(orbit_type)),
    data_status_code = stringr::str_trim(as.character(data_status_code)),
    launch_date = lubridate::ymd(launch_date),
    decay_date = lubridate::ymd(decay_date),
    launch_year = lubridate::year(launch_date),
    decay_year = lubridate::year(decay_date),
    owner = if_else(is.na(owner) | owner == "", "BRAK", owner),
    launch_site = if_else(is.na(launch_site) | launch_site == "", "BRAK", launch_site),
    orbit_center = if_else(is.na(orbit_center) | orbit_center == "", "BRAK", orbit_center),
    orbit_type = if_else(is.na(orbit_type) | orbit_type == "", "BRAK", orbit_type),
    owner_label = if_else(
      owner %in% names(owner_dictionary),
      unname(owner_dictionary[owner]),
      paste0(owner, " - kod SATCAT")
    ),
    launch_site_label = if_else(
      launch_site %in% names(launch_site_dictionary),
      unname(launch_site_dictionary[launch_site]),
      paste0(launch_site, " - kod SATCAT")
    ),
    object_type_pl = case_when(
      object_type == "PAY" ~ "Satelita / payload",
      object_type == "R/B" ~ "Człon rakiety",
      object_type == "DEB" ~ "Fragment / debris",
      object_type == "UNK" ~ "Nieznany",
      TRUE ~ "Inne"
    ),
    ops_status_group = case_when(
      ops_status_code == "+" ~ "Operacyjny",
      ops_status_code == "-" ~ "Nieoperacyjny",
      ops_status_code == "P" ~ "Częściowo operacyjny",
      ops_status_code %in% c("B", "S", "X", "p") ~ "Rezerwowy / techniczny",
      is.na(ops_status_code) | ops_status_code == "" ~ "Brak danych",
      TRUE ~ "Inny status"
    ),
    is_decayed = !is.na(decay_date) | ops_status_code == "D" | orbit_type %in% c("IMP", "LAN"),
    current_earth_orbit = orbit_type == "ORB" & orbit_center == "EA" & !is_decayed,
    mean_altitude_km = if_else(
      !is.na(apogee) & !is.na(perigee),
      (apogee + perigee) / 2,
      NA_real_
    ),
    orbit_class = case_when(
      orbit_center != "EA" ~ "Poza orbitą Ziemi",
      is.na(mean_altitude_km) ~ "Brak danych",
      mean_altitude_km < 160 ~ "Bardzo niska (<160 km)",
      mean_altitude_km < 2000 ~ "LEO - niska (<2 000 km)",
      mean_altitude_km < 30000 ~ "MEO - średnia (2 000-30 000 km)",
      mean_altitude_km <= 45000 ~ "GEO/GSO (30 000-45 000 km)",
      TRUE ~ "HEO - bardzo wysoka (>45 000 km)"
    ),
    altitude_bin = case_when(
      is.na(mean_altitude_km) ~ NA_character_,
      mean_altitude_km < 500 ~ "<500 km",
      mean_altitude_km < 800 ~ "500-800 km",
      mean_altitude_km < 1200 ~ "800-1 200 km",
      mean_altitude_km < 2000 ~ "1 200-2 000 km",
      mean_altitude_km < 10000 ~ "2 000-10 000 km",
      mean_altitude_km < 25000 ~ "10 000-25 000 km",
      mean_altitude_km < 33000 ~ "25 000-33 000 km",
      mean_altitude_km < 38000 ~ "33 000-38 000 km",
      mean_altitude_km < 45000 ~ "38 000-45 000 km",
      TRUE ~ ">45 000 km"
    ),
    decade = floor(launch_year / 10) * 10,
    decay_decade = floor(decay_year / 10) * 10
  )

satcat_chart <- satcat %>%
  filter(object_type_pl != "Nieznany")

satcat_launched <- satcat_chart %>%
  filter(!is.na(launch_year))

current_earth <- satcat_chart %>%
  filter(current_earth_orbit)

earth_orbit_with_altitude <- satcat_chart %>%
  filter(
    orbit_center == "EA",
    orbit_type == "ORB",
    !is.na(mean_altitude_km),
    mean_altitude_km >= 0
  )

comma_pl <- scales::label_comma(big.mark = " ", decimal.mark = ",")
percent_pl <- scales::label_percent(decimal.mark = ",", accuracy = 0.1)

decade_label_pl <- function(decade) {
  dplyr::case_when(
    is.na(decade) ~ NA_character_,
    decade < 2000 ~ paste0("lata ", stringr::str_sub(as.character(decade), 3, 4), ". XX w."),
    TRUE ~ paste0("lata ", as.character(decade), ".")
  )
}

common_theme <- theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold", size = 18),
    plot.subtitle = element_blank(),
    plot.caption = element_blank(),
    plot.margin = margin(10, 35, 10, 10),
    axis.title = element_text(size = 12),
    axis.title.y = element_text(angle = 0, vjust = 0.5, margin = margin(r = 18)),
    axis.text.x = element_text(angle = 0, hjust = 0.5, vjust = 0.5),
    axis.text.y = element_text(angle = 0),
    axis.ticks = element_line(color = "grey45", linewidth = 0.3),
    axis.ticks.length = grid::unit(3, "pt"),
    legend.position = "bottom",
    legend.title = element_text(face = "bold"),
    panel.grid.major = element_line(color = "grey86", linewidth = 0.35),
    panel.grid.minor = element_blank()
  )

p1_data <- satcat_launched %>%
  count(launch_year, object_type_pl, name = "liczba") %>%
  complete(
    launch_year = seq(min(launch_year, na.rm = TRUE), max(launch_year, na.rm = TRUE), by = 1),
    object_type_pl,
    fill = list(liczba = 0)
  ) %>%
  mutate(
    object_type_pl = factor(
      object_type_pl,
      levels = c("Satelita / payload", "Fragment / debris", "Człon rakiety", "Inne")
    )
  ) %>%
  filter(!is.na(object_type_pl))

p1 <- ggplot(p1_data, aes(x = launch_year, y = liczba)) +
  geom_col(width = 0.85, fill = "#2C7FB8") +
  facet_wrap(~ object_type_pl, ncol = 1, scales = "free_y") +
  scale_x_continuous(
    breaks = seq(1960, max(p1_data$launch_year, na.rm = TRUE), by = 5),
    expand = expansion(mult = c(0.01, 0.02))
  ) +
  scale_y_continuous(
    labels = comma_pl,
    breaks = scales::breaks_pretty(n = 6),
    expand = expansion(mult = c(0, 0.10))
  ) +
  labs(
    title = "Ile obiektów danego typu wysyłano w kolejnych latach?",
    x = "Rok startu",
    y = "Liczba obiektów"
  ) +
  common_theme +
  theme(
    strip.text = element_text(face = "bold", size = 13),
    panel.spacing.y = grid::unit(1.1, "lines"),
    legend.position = "none"
  )

save_plot(p1, "5.1", width = 13, height = 10)

years_all <- tibble(
  year = seq(
    min(satcat_launched$launch_year, na.rm = TRUE),
    max(satcat_launched$launch_year, na.rm = TRUE),
    by = 1
  )
)

launched_by_year <- satcat_launched %>%
  count(launch_year, name = "launched") %>%
  rename(year = launch_year)

decayed_by_year <- satcat_chart %>%
  filter(!is.na(decay_year)) %>%
  count(decay_year, name = "decayed") %>%
  rename(year = decay_year)

p2_data <- years_all %>%
  left_join(launched_by_year, by = "year") %>%
  left_join(decayed_by_year, by = "year") %>%
  mutate(
    launched = replace_na(launched, 0),
    decayed = replace_na(decayed, 0),
    total_launched = cumsum(launched),
    estimated_still_in_orbit = cumsum(launched - decayed)
  ) %>%
  pivot_longer(
    cols = c(total_launched, estimated_still_in_orbit),
    names_to = "metryka",
    values_to = "liczba"
  ) %>%
  mutate(
    metryka = recode(
      metryka,
      total_launched = "Łącznie w katalogu",
      estimated_still_in_orbit = "Nadal na orbicie"
    )
  )

p2 <- ggplot(p2_data, aes(x = year, y = liczba, color = metryka)) +
  geom_line(linewidth = 1.25) +
  scale_x_continuous(breaks = seq(1960, max(p2_data$year, na.rm = TRUE), by = 5)) +
  scale_y_continuous(labels = comma_pl, breaks = scales::breaks_pretty(n = 8)) +
  labs(
    title = "Narastanie katalogu obiektów orbitalnych",
    x = "Rok",
    y = "Liczba obiektów",
    color = NULL
  ) +
  common_theme

save_plot(p2, "5.2")

p3_data <- satcat_chart %>%
  count(object_type_pl, name = "liczba") %>%
  mutate(
    udzial = liczba / sum(liczba),
    etykieta = paste0(comma(liczba, big.mark = " "), " / ", percent_pl(udzial)),
    object_type_pl = fct_reorder(object_type_pl, liczba)
  )

p3 <- ggplot(p3_data, aes(x = object_type_pl, y = liczba, fill = object_type_pl)) +
  geom_col(show.legend = FALSE) +
  geom_text(aes(label = etykieta), hjust = -0.06, size = 4) +
  coord_flip(clip = "off") +
  scale_y_continuous(
    labels = comma_pl,
    breaks = scales::breaks_pretty(n = 8),
    expand = expansion(mult = c(0, 0.22))
  ) +
  labs(
    title = "Co znajduje się w katalogu SATCAT?",
    x = "Typ obiektu",
    y = "Liczba obiektów"
  ) +
  common_theme

save_plot(p3, "5.3")

p4_data <- satcat_chart %>%
  filter(owner_label != "Właściciel do ustalenia") %>%
  count(owner_label, sort = TRUE, name = "liczba") %>%
  slice_head(n = 15) %>%
  mutate(owner_label = fct_reorder(owner_label, liczba))

p4 <- ggplot(p4_data, aes(x = owner_label, y = liczba)) +
  geom_col(fill = "#3182BD") +
  geom_text(aes(label = comma(liczba, big.mark = " ")), hjust = -0.08, size = 3.8) +
  coord_flip(clip = "off") +
  scale_y_continuous(
    labels = comma_pl,
    breaks = scales::breaks_pretty(n = 8),
    expand = expansion(mult = c(0, 0.18))
  ) +
  labs(
    title = "Kto ma najwięcej obiektów w katalogu?",
    x = "Właściciel / kraj / organizacja",
    y = "Liczba obiektów"
  ) +
  common_theme

save_plot(p4, "5.4", width = 13, height = 8)

p5_data <- current_earth %>%
  filter(owner_label != "Właściciel do ustalenia") %>%
  count(owner_label, sort = TRUE, name = "liczba") %>%
  slice_head(n = 15) %>%
  mutate(owner_label = fct_reorder(owner_label, liczba))

p5 <- ggplot(p5_data, aes(x = owner_label, y = liczba)) +
  geom_col(fill = "#31A354") +
  geom_text(aes(label = comma(liczba, big.mark = " ")), hjust = -0.08, size = 3.8) +
  coord_flip(clip = "off") +
  scale_y_continuous(
    labels = comma_pl,
    breaks = scales::breaks_pretty(n = 8),
    expand = expansion(mult = c(0, 0.18))
  ) +
  labs(
    title = "Kto ma najwięcej obiektów nadal na orbicie Ziemi?",
    x = "Właściciel / kraj / organizacja",
    y = "Liczba obiektów"
  ) +
  common_theme

save_plot(p5, "5.5", width = 13, height = 8)

p6_data <- current_earth %>%
  filter(ops_status_group != "Brak danych") %>%
  count(ops_status_group, name = "liczba") %>%
  mutate(
    udzial = liczba / sum(liczba),
    etykieta = paste0(comma(liczba, big.mark = " "), " / ", percent_pl(udzial)),
    ops_status_group = factor(
      ops_status_group,
      levels = c("Rezerwowy / techniczny", "Częściowo operacyjny", "Nieoperacyjny", "Operacyjny")
    )
  )

p6 <- ggplot(p6_data, aes(x = ops_status_group, y = liczba, fill = ops_status_group)) +
  geom_col(show.legend = FALSE) +
  geom_text(aes(label = etykieta), hjust = -0.05, size = 4) +
  coord_flip(clip = "off") +
  scale_y_continuous(
    labels = comma_pl,
    breaks = scales::breaks_pretty(n = 8),
    expand = expansion(mult = c(0, 0.22))
  ) +
  labs(
    title = "Ile obiektów nadal na orbicie faktycznie działa?",
    x = "Status operacyjny",
    y = "Liczba obiektów"
  ) +
  common_theme

save_plot(p6, "5.6")

orbit_class_order <- c(
  "LEO - niska (<2 000 km)",
  "MEO - średnia (2 000-30 000 km)",
  "GEO/GSO (30 000-45 000 km)",
  "HEO - bardzo wysoka (>45 000 km)"
)

p7_data <- earth_orbit_with_altitude %>%
  filter(
    orbit_class %in% orbit_class_order,
    object_type_pl %in% c("Satelita / payload", "Fragment / debris", "Człon rakiety")
  ) %>%
  mutate(
    orbit_class = factor(orbit_class, levels = rev(orbit_class_order)),
    object_type_pl = factor(
      object_type_pl,
      levels = c("Satelita / payload", "Fragment / debris", "Człon rakiety")
    )
  ) %>%
  count(orbit_class, object_type_pl, name = "liczba") %>%
  complete(orbit_class, object_type_pl, fill = list(liczba = 0)) %>%
  mutate(
    label = comma(liczba, big.mark = " "),
    text_light = liczba > 0.45 * max(liczba, na.rm = TRUE)
  )

p7 <- ggplot(p7_data, aes(x = object_type_pl, y = orbit_class, fill = liczba)) +
  geom_tile(color = "white", linewidth = 1.1) +
  geom_text(aes(label = label, color = text_light), fontface = "bold", size = 5) +
  scale_color_manual(values = c("FALSE" = "black", "TRUE" = "white"), guide = "none") +
  scale_fill_gradientn(
    colors = c("#F7FBFF", "#C6DBEF", "#6BAED6", "#2171B5", "#08306B"),
    labels = comma_pl,
    breaks = scales::breaks_pretty(n = 5),
    trans = "sqrt",
    guide = "none"
  ) +
  labs(
    title = "Gdzie gromadzą się różne typy obiektów?",
    x = "Typ obiektu",
    y = "Klasa orbity"
  ) +
  common_theme +
  theme(
    axis.text.x = element_text(angle = 0, hjust = 0.5, face = "bold"),
    axis.text.y = element_text(face = "bold"),
    panel.grid.major = element_blank(),
    panel.grid.minor = element_blank(),
    legend.position = "none"
  )

save_plot(p7, "5.7", width = 12, height = 7)

altitude_bin_order <- c(
  "<500 km", "500-800 km", "800-1 200 km", "1 200-2 000 km",
  "2 000-10 000 km", "10 000-25 000 km", "25 000-33 000 km",
  "33 000-38 000 km", "38 000-45 000 km", ">45 000 km"
)

p8_data <- current_earth %>%
  filter(!is.na(altitude_bin)) %>%
  count(altitude_bin, name = "liczba") %>%
  mutate(
    altitude_bin = factor(altitude_bin, levels = altitude_bin_order),
    etykieta = comma(liczba, big.mark = " "),
    altitude_bin_sorted = forcats::fct_reorder(altitude_bin, liczba)
  )

p8 <- ggplot(p8_data, aes(x = altitude_bin_sorted, y = liczba)) +
  geom_col(fill = "#756BB1", width = 0.72) +
  geom_text(aes(label = etykieta), hjust = -0.08, size = 3.8) +
  coord_flip(clip = "off") +
  scale_y_continuous(
    labels = comma_pl,
    breaks = scales::breaks_pretty(n = 8),
    expand = expansion(mult = c(0, 0.20))
  ) +
  labs(
    title = "Ranking wysokości orbit według liczby obiektów",
    x = "Przedział średniej wysokości orbity",
    y = "Liczba obiektów"
  ) +
  common_theme +
  theme(
    panel.grid.major.y = element_blank()
  )

save_plot(p8, "5.8", width = 13, height = 7)

p9_data <- satcat_launched %>%
  count(launch_site_label, sort = TRUE, name = "liczba") %>%
  slice_head(n = 12) %>%
  mutate(launch_site_label = fct_reorder(launch_site_label, liczba))

p9 <- ggplot(p9_data, aes(x = launch_site_label, y = liczba)) +
  geom_col(fill = "#E6550D") +
  geom_text(aes(label = comma(liczba, big.mark = " ")), hjust = -0.08, size = 3.7) +
  coord_flip(clip = "off") +
  scale_y_continuous(
    labels = comma_pl,
    breaks = scales::breaks_pretty(n = 8),
    expand = expansion(mult = c(0, 0.18))
  ) +
  labs(
    title = "Z których kosmodromów startowało najwięcej obiektów?",
    x = "Kosmodrom / miejsce startu",
    y = "Liczba obiektów"
  ) +
  common_theme

save_plot(p9, "5.9", width = 13, height = 8)

decade_levels <- satcat_chart %>%
  filter(!is.na(decay_decade)) %>%
  pull(decay_decade) %>%
  unique() %>%
  sort()

p10_data <- satcat_chart %>%
  filter(!is.na(decay_decade)) %>%
  count(decay_decade, object_type_pl, name = "liczba") %>%
  mutate(
    decay_decade_label = decade_label_pl(decay_decade),
    decay_decade_label = factor(
      decay_decade_label,
      levels = decade_label_pl(decade_levels)
    ),
    object_type_pl = factor(
      object_type_pl,
      levels = c("Satelita / payload", "Fragment / debris", "Człon rakiety", "Inne")
    )
  ) %>%
  filter(!is.na(object_type_pl))

p10 <- ggplot(p10_data, aes(x = decay_decade_label, y = liczba)) +
  geom_col(fill = "#636363") +
  facet_wrap(~ object_type_pl, ncol = 1, scales = "free_y") +
  scale_y_continuous(
    labels = comma_pl,
    breaks = scales::breaks_pretty(n = 7),
    expand = expansion(mult = c(0, 0.10))
  ) +
  labs(
    title = "Kiedy obiekty schodziły z orbity?",
    x = "Dekada zejścia z orbity",
    y = "Liczba obiektów"
  ) +
  common_theme +
  theme(
    strip.text = element_text(face = "bold", size = 13),
    panel.spacing.y = grid::unit(1.1, "lines"),
    legend.position = "none",
    axis.text.x = element_text(angle = 0, hjust = 0.5, size = 10)
  )

save_plot(p10, "5.10", width = 12, height = 9)
