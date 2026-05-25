suppressPackageStartupMessages({
  library(readxl)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(ggrepel)
  library(scales)
  library(viridis)
  library(forcats)
  library(stringr)
  library(patchwork)
})


CB_PALETTE <- c(
  "#E69F00", "#56B4E9", "#009E73", "#F0E442",
  "#0072B2", "#D55E00", "#CC79A7", "#000000"
)

FIXED_COUNTRIES <- c("Poland", "Germany", "France", "Sweden",
                     "Bulgaria", "Denmark", "Italy", "Romania")

EU27 <- c(
  "Belgium", "Bulgaria", "Czechia", "Denmark", "Germany",
  "Estonia", "Ireland", "Greece", "Spain", "France",
  "Croatia", "Italy", "Cyprus", "Latvia", "Lithuania",
  "Luxembourg", "Hungary", "Malta", "Netherlands", "Austria",
  "Poland", "Portugal", "Romania", "Slovenia", "Slovakia",
  "Finland", "Sweden"
)

THEME_BASE <- theme_minimal(base_size = 14) +
  theme(
    plot.title    = element_text(face = "bold", size = 16, margin = margin(b = 8)),
    plot.subtitle = element_text(size = 13, color = "grey35", margin = margin(b = 10)),
    plot.caption  = element_text(size = 10, color = "grey50"),
    axis.title    = element_text(size = 13, face = "bold"),
    axis.text     = element_text(size = 11),
    legend.title  = element_text(size = 12, face = "bold"),
    legend.text   = element_text(size = 11),
    panel.grid.minor = element_blank(),
    plot.margin   = margin(16, 16, 12, 16)
  )

DATA_DIR <- "Statystyki_wykorzystania_internetu/data-folder"

DATASETS <- list(
  full_usage    = list(file = "tin00028_page_spreadsheet - full usage.xlsx",     label = "Ogólne korzystanie z internetu"),
  emails        = list(file = "tin00094_page_spreadsheet - emails.xlsx",          label = "Wysyłanie/odbiór e-maili"),
  goods         = list(file = "tin00095_page_spreadsheet - goods and services.xlsx", label = "Wyszukiwanie towarów i usług"),
  banking       = list(file = "tin00099_page_spreadsheet - banking.xlsx",         label = "Bankowość internetowa"),
  health        = list(file = "tin00101_page_spreadsheet - health-related.xlsx",  label = "Informacje zdrowotne"),
  job           = list(file = "tin00102_page_spreadsheet - job.xlsx",             label = "Poszukiwanie pracy"),
  social_media  = list(file = "tin00127_page_spreadsheet - social media.xlsx",    label = "Media społecznościowe"),
  consult_vote  = list(file = "tin00129_page_spreadsheet - consult or vote.xlsx", label = "Konsultacje / głosowanie online")
)

parse_eurostat_sheet <- function(path, label) {
  raw <- read_excel(path, sheet = "Sheet 1", col_names = FALSE)
  year_row  <- as.character(unlist(raw[10, ]))
  year_idx  <- which(!is.na(year_row) & grepl("^20", year_row))
  years     <- as.integer(year_row[year_idx])

  data_rows <- raw[12:nrow(raw), ]
  data_rows <- data_rows[
    !is.na(data_rows[[1]]) &
      !grepl("^Euro area|Special value|Observation|not available|break in time", data_rows[[1]]),
  ]

  result <- data.frame(country = as.character(data_rows[[1]]), stringsAsFactors = FALSE)
  for (i in seq_along(year_idx)) {
    col_val <- as.character(data_rows[[year_idx[i]]])
    col_val <- gsub("[^0-9.]", "", col_val)  # usuń flagi 'b', 'e'
    result[[as.character(years[i])]] <- suppressWarnings(as.numeric(col_val))
  }

  long <- result |>
    pivot_longer(-country, names_to = "year", values_to = "pct") |>
    mutate(year = as.integer(year), category = label)

  long
}

all_data <- bind_rows(
  lapply(seq_along(DATASETS), function(i) {
    ds  <- DATASETS[[i]]
    key <- names(DATASETS)[i]
    df  <- parse_eurostat_sheet(file.path(DATA_DIR, ds$file), ds$label)
    df$key <- key
    df
  })
)

eu_data <- all_data |> filter(country %in% EU27)

full <- eu_data |> filter(key == "full_usage")

fixed <- all_data |> filter(country %in% FIXED_COUNTRIES)

cat("Wczytano dane:", nrow(all_data), "wierszy\n")
cat("Lata:", paste(sort(unique(eu_data$year)), collapse = ", "), "\n")
cat("Kraje EU27:", length(unique(eu_data$country)), "\n")


OUT_DIR <- "Statystyki_wykorzystania_internetu/phts"
dir.create(OUT_DIR, showWarnings = FALSE)

save_plot <- function(p, filename, w = 14, h = 9) {
  ggsave(
    file.path(OUT_DIR, filename),
    plot = p, width = w, height = h, dpi = 150,
    bg = "white"
  )
  cat("  Zapisano:", filename, "\n")
}


cat("\n--- Generowanie wykresów ---\n")

eu27_avg <- full |>
  filter(!is.na(pct)) |>
  group_by(year) |>
  summarise(avg = mean(pct), .groups = "drop")

p01 <- ggplot(eu27_avg, aes(x = year, y = avg)) +
  geom_area(alpha = 0.15, fill = CB_PALETTE[3]) +
  geom_line(linewidth = 1.5, color = CB_PALETTE[3]) +
  geom_point(size = 3.5, color = CB_PALETTE[3]) +
  geom_text(aes(label = paste0(round(avg, 1), "%")),
            vjust = -1, size = 3.5, fontface = "bold") +
  scale_y_continuous(limits = c(0, 105), labels = label_percent(scale = 1),
                     breaks = seq(0, 100, 20)) +
  scale_x_continuous(breaks = 2014:2025) +
  labs(
    title    = "Ogólne korzystanie z internetu – średnia UE-27",
    subtitle = "Odsetek osób (16–74 lata) korzystających z internetu w ciągu ostatnich 3 miesięcy",
    x = "Rok", y = "Odsetek [%]",
    caption = "Źródło: Eurostat (tin00028)"
  ) +
  THEME_BASE

save_plot(p01, "01_eu27_trend_full_usage.png")

heat_df <- full |>
  filter(!is.na(pct)) |>
  mutate(country = fct_reorder(country, pct, .fun = mean, .na_rm = TRUE))

p02 <- ggplot(heat_df, aes(x = year, y = country, fill = pct)) +
  geom_tile(color = "white", linewidth = 0.4) +
  scale_fill_viridis_c(option = "plasma", name = "Odsetek [%]",
                       limits = c(0, 100), breaks = seq(0, 100, 20)) +
  scale_x_continuous(breaks = 2014:2025) +
  labs(
    title    = "Intensywność korzystania z internetu w UE-27 (2014–2025)",
    subtitle = "Każda komórka = odsetek użytkowników internetu w danym kraju i roku",
    x = "Rok", y = NULL,
    caption = "Źródło: Eurostat (tin00028)"
  ) +
  THEME_BASE +
  theme(axis.text.y = element_text(size = 10),
        panel.grid = element_blank())

save_plot(p02, "02_heatmap_all_countries.png", w = 14, h = 10)

rank_2025 <- full |>
  filter(year == 2025, !is.na(pct)) |>
  mutate(country = fct_reorder(country, pct),
         highlight = country %in% c("Poland"))

p03 <- ggplot(rank_2025, aes(x = pct, y = country, color = highlight)) +
  geom_segment(aes(x = 0, xend = pct, y = country, yend = country),
               linewidth = 1, alpha = 0.7) +
  geom_point(size = 4) +
  geom_text(aes(label = paste0(round(pct, 1), "%")), hjust = -0.25, size = 3.5) +
  scale_color_manual(values = c("FALSE" = CB_PALETTE[2], "TRUE" = CB_PALETTE[6]),
                     guide = "none") +
  scale_x_continuous(limits = c(0, 110), labels = label_percent(scale = 1)) +
  labs(
    title    = "Ranking krajów UE-27 – korzystanie z internetu (2025)",
    subtitle = "Pomarańczowy = Polska i Niemcy; niebieski = pozostałe kraje",
    x = "Odsetek [%]", y = NULL,
    caption = "Źródło: Eurostat (tin00028)"
  ) +
  THEME_BASE

save_plot(p03, "03_ranking_2025.png", w = 12, h = 10)

growth_df <- full |>
  filter(year %in% c(2014, 2025), !is.na(pct)) |>
  pivot_wider(names_from = year, values_from = pct, names_prefix = "y") |>
  filter(!is.na(y2014) & !is.na(y2025)) |>
  mutate(growth = y2025 - y2014,
         country = fct_reorder(country, growth))

p04 <- ggplot(growth_df, aes(x = growth, y = country,
                              fill = growth > mean(growth))) +
  geom_col(alpha = 0.85) +
  geom_text(aes(label = paste0("+", round(growth, 1), "pp")),
            hjust = -0.1, size = 3.5) +
  scale_fill_manual(values = c("FALSE" = CB_PALETTE[2], "TRUE" = CB_PALETTE[3]),
                    guide = "none") +
  scale_x_continuous(limits = c(0, 45), labels = label_number(suffix = " pp")) +
  labs(
    title    = "Przyrost korzystania z internetu 2014→2025",
    subtitle = "Różnica w punktach procentowych; zielony = powyżej średniej UE-27",
    x = "Przyrost [pp]", y = NULL,
    caption = "Źródło: Eurostat (tin00028)"
  ) +
  THEME_BASE

save_plot(p04, "04_growth_2014_2025.png", w = 12, h = 10)

p05 <- ggplot(full |> filter(!is.na(pct)), aes(x = factor(year), y = pct)) +
  geom_boxplot(fill = CB_PALETTE[2], color = "grey30",
               alpha = 0.7, outlier.color = CB_PALETTE[6], outlier.size = 2.5) +
  stat_summary(fun = mean, geom = "point", shape = 18, size = 4, color = CB_PALETTE[6]) +
  scale_y_continuous(limits = c(0, 105), labels = label_percent(scale = 1),
                     breaks = seq(0, 100, 20)) +
  labs(
    title    = "Rozkład korzystania z internetu w UE-27 – boxplot (2014–2025)",
    subtitle = "Romb = średnia; krawędzie = Q1/Q3; wąsy = 1.5×IQR; punkty = obserwacje odstające",
    x = "Rok", y = "Odsetek [%]",
    caption = "Źródło: Eurostat (tin00028)"
  ) +
  THEME_BASE

save_plot(p05, "05_boxplot_full_usage.png")

years_sel <- c(2015, 2019, 2025)
violin_df <- full |> filter(year %in% years_sel, !is.na(pct))

p06 <- ggplot(violin_df, aes(x = factor(year), y = pct, fill = factor(year))) +
  geom_violin(alpha = 0.6, trim = FALSE) +
  geom_boxplot(width = 0.15, fill = "white", alpha = 0.9, outlier.shape = NA) +
  geom_jitter(width = 0.07, size = 1.8, alpha = 0.5, color = "grey30") +
  scale_fill_manual(values = CB_PALETTE[c(1, 3, 6)], guide = "none") +
  scale_y_continuous(limits = c(0, 107), labels = label_percent(scale = 1),
                     breaks = seq(0, 100, 20)) +
  labs(
    title    = "Rozkład korzystania z internetu – violin plot (2015, 2019, 2025)",
    subtitle = "Szerokość skrzypiec = gęstość rozkładu; wewnątrz: mediana i kwartyle",
    x = "Rok", y = "Odsetek [%]",
    caption = "Źródło: Eurostat (tin00028)"
  ) +
  THEME_BASE

save_plot(p06, "06_violin_selected_years.png", w = 10, h = 8)

cat_box_df <- eu_data |>
  filter(year == 2023, !is.na(pct)) |>
  mutate(category = str_wrap(category, width = 22))

p07 <- ggplot(cat_box_df, aes(x = reorder(category, pct, FUN = median),
                               y = pct, fill = category)) +
  geom_boxplot(alpha = 0.75, outlier.size = 2, outlier.alpha = 0.6) +
  scale_fill_viridis_d(guide = "none") +
  scale_y_continuous(limits = c(0, 107), labels = label_percent(scale = 1),
                     breaks = seq(0, 100, 20)) +
  coord_flip() +
  labs(
    title    = "Porównanie kategorii użycia internetu – rozkład w UE-27 (2023)",
    subtitle = "Każdy boxplot = 27 krajów; posortowane wg mediany",
    x = NULL, y = "Odsetek [%]",
    caption = "Źródło: Eurostat"
  ) +
  THEME_BASE

save_plot(p07, "07_boxplot_categories_2023.png", w = 14, h = 8)

poland_data <- eu_data |>
  filter(country == "Poland", !is.na(pct))

p08 <- ggplot(poland_data, aes(x = year, y = pct, color = category, group = category)) +
  geom_line(linewidth = 1.3) +
  geom_point(size = 2.5) +
  scale_color_manual(values = CB_PALETTE, name = "Kategoria") +
  scale_y_continuous(limits = c(0, 105), labels = label_percent(scale = 1),
                     breaks = seq(0, 100, 20)) +
  scale_x_continuous(breaks = 2014:2025) +
  labs(
    title    = "Polska – trend korzystania z internetu wg kategorii (2014–2025)",
    subtitle = "Odsetek osób 16–74 lata korzystających z internetu w ostatnich 3 miesiącach",
    x = "Rok", y = "Odsetek [%]",
    caption = "Źródło: Eurostat"
  ) +
  THEME_BASE +
  theme(legend.position = "right")

save_plot(p08, "08_poland_all_categories.png", w = 14, h = 8)

germany_data <- eu_data |>
  filter(country == "Germany", !is.na(pct))

p09 <- ggplot(germany_data, aes(x = year, y = pct, color = category, group = category)) +
  geom_line(linewidth = 1.3) +
  geom_point(size = 2.5) +
  scale_color_manual(values = CB_PALETTE, name = "Kategoria") +
  scale_y_continuous(limits = c(0, 105), labels = label_percent(scale = 1),
                     breaks = seq(0, 100, 20)) +
  scale_x_continuous(breaks = 2014:2025) +
  labs(
    title    = "Niemcy – trend korzystania z internetu wg kategorii (2014–2025)",
    subtitle = "Odsetek osób 16–74 lata korzystających z internetu w ostatnich 3 miesiącach",
    x = "Rok", y = "Odsetek [%]",
    caption = "Źródło: Eurostat"
  ) +
  THEME_BASE +
  theme(legend.position = "right")

save_plot(p09, "09_germany_all_categories.png", w = 14, h = 8)

pl_de <- eu_data |>
  filter(country %in% c("Poland", "Germany"), key == "full_usage", !is.na(pct))

p10 <- ggplot(pl_de, aes(x = year, y = pct, color = country, group = country)) +
  geom_line(linewidth = 2) +
  geom_point(size = 4) +
  geom_text_repel(
    data = pl_de |> filter(year == 2025),
    aes(label = paste0(country, "\n", round(pct, 1), "%")),
    size = 4, fontface = "bold", nudge_x = 0.3, segment.size = 0.4
  ) +
  scale_color_manual(values = c("Poland" = CB_PALETTE[6], "Germany" = CB_PALETTE[5]),
                     name = NULL) +
  scale_y_continuous(limits = c(0, 105), labels = label_percent(scale = 1),
                     breaks = seq(0, 100, 20)) +
  scale_x_continuous(breaks = 2014:2025) +
  labs(
    title    = "Polska vs Niemcy – ogólne korzystanie z internetu",
    subtitle = "Porównanie trendu 2014–2025",
    x = "Rok", y = "Odsetek [%]",
    caption = "Źródło: Eurostat (tin00028)"
  ) +
  THEME_BASE + theme(legend.position = "none")

save_plot(p10, "10_poland_vs_germany_full.png")

matrix_df <- all_data |>
  filter(country %in% FIXED_COUNTRIES, year == 2025, !is.na(pct)) |>
  mutate(
    category = str_wrap(category, 18),
    country  = factor(country, levels = FIXED_COUNTRIES)
  )

p11 <- ggplot(matrix_df, aes(x = category, y = pct, fill = country)) +
  geom_col(position = "dodge", alpha = 0.85) +
  scale_fill_manual(values = CB_PALETTE, name = "Kraj") +
  scale_y_continuous(limits = c(0, 105), labels = label_percent(scale = 1),
                     breaks = seq(0, 100, 20)) +
  labs(
    title    = "Porównanie wybranych krajów wg kategorii (2025)",
    subtitle = "8 krajów; każda grupa słupków = jedna kategoria użycia internetu",
    x = NULL, y = "Odsetek [%]",
    caption = "Źródło: Eurostat"
  ) +
  THEME_BASE +
  theme(axis.text.x = element_text(angle = 35, hjust = 1, size = 10))

save_plot(p11, "11_fixed_countries_categories_2025.png", w = 16, h = 8)

two_cat <- all_data |>
  filter(country %in% FIXED_COUNTRIES,
         key %in% c("banking", "social_media"), !is.na(pct))

p12 <- ggplot(two_cat, aes(x = year, y = pct, color = country, group = country)) +
  geom_line(linewidth = 1.4) +
  geom_point(size = 2.5) +
  facet_wrap(~ category, scales = "fixed", ncol = 2) +
  scale_color_manual(values = CB_PALETTE, name = "Kraj") +
  scale_y_continuous(limits = c(0, 105), labels = label_percent(scale = 1),
                     breaks = seq(0, 100, 20)) +
  scale_x_continuous(breaks = c(2014, 2017, 2020, 2023, 2025)) +
  labs(
    title    = "Bankowość vs Media społecznościowe – wybrane kraje (2014–2025)",
    subtitle = "Każda linia = jeden kraj",
    x = "Rok", y = "Odsetek [%]",
    caption = "Źródło: Eurostat"
  ) +
  THEME_BASE

save_plot(p12, "12_banking_vs_social_selected.png", w = 14, h = 7)

scatter_df <- eu_data |>
  filter(year == 2025, key %in% c("banking", "social_media")) |>
  select(country, key, pct) |>
  pivot_wider(names_from = key, values_from = pct) |>
  filter(!is.na(banking) & !is.na(social_media)) |>
  mutate(highlight = country %in% c("Poland", "Germany"))

p13 <- ggplot(scatter_df, aes(x = banking, y = social_media)) +
  geom_point(aes(color = highlight), size = 4, alpha = 0.8) +
  geom_smooth(method = "lm", se = TRUE, color = "grey50", linetype = "dashed",
              linewidth = 1) +
  geom_text_repel(aes(label = country), size = 3.5, max.overlaps = 20) +
  scale_color_manual(values = c("FALSE" = CB_PALETTE[2], "TRUE" = CB_PALETTE[6]),
                     guide = "none") +
  scale_x_continuous(limits = c(0, 105), labels = label_percent(scale = 1),
                     breaks = seq(0, 100, 20)) +
  scale_y_continuous(limits = c(0, 105), labels = label_percent(scale = 1),
                     breaks = seq(0, 100, 20)) +
  labs(
    title    = "Bankowość internetowa vs Media społecznościowe w UE-27 (2025)",
    subtitle = "Każdy punkt = kraj UE-27; pomarańczowy = Polska/Niemcy; linia = regresja liniowa",
    x = "Bankowość internetowa [%]", y = "Media społecznościowe [%]",
    caption = "Źródło: Eurostat"
  ) +
  THEME_BASE

save_plot(p13, "13_scatter_banking_vs_social.png")

scatter2_df <- eu_data |>
  filter(year == 2025, key %in% c("full_usage", "job")) |>
  select(country, key, pct) |>
  pivot_wider(names_from = key, values_from = pct) |>
  filter(!is.na(full_usage) & !is.na(job)) |>
  mutate(highlight = country %in% c("Poland", "Germany"))

p14 <- ggplot(scatter2_df, aes(x = full_usage, y = job)) +
  geom_point(aes(color = highlight), size = 4, alpha = 0.8) +
  geom_smooth(method = "lm", se = TRUE, color = "grey50",
              linetype = "dashed", linewidth = 1) +
  geom_text_repel(aes(label = country), size = 3.5, max.overlaps = 20) +
  scale_color_manual(values = c("FALSE" = CB_PALETTE[3], "TRUE" = CB_PALETTE[6]),
                     guide = "none") +
  scale_x_continuous(limits = c(0, 105), labels = label_percent(scale = 1),
                     breaks = seq(0, 100, 20)) +
  scale_y_continuous(limits = c(0, 55), labels = label_percent(scale = 1),
                     breaks = seq(0, 50, 10)) +
  labs(
    title    = "Ogólne użycie internetu vs Poszukiwanie pracy online (2025)",
    subtitle = "Kraje z wyższym ogólnym użyciem internetu – czy więcej szuka pracy online?",
    x = "Ogólne korzystanie z internetu [%]", y = "Poszukiwanie pracy online [%]",
    caption = "Źródło: Eurostat"
  ) +
  THEME_BASE

save_plot(p14, "14_scatter_full_vs_job.png")

poland_bar <- all_data |>
  filter(country == "Poland", year %in% c(2015, 2018, 2021, 2025), !is.na(pct)) |>
  mutate(category = str_wrap(category, 20))

p15 <- ggplot(poland_bar, aes(x = factor(year), y = pct, fill = category)) +
  geom_col(position = "dodge", alpha = 0.85) +
  geom_text(aes(label = paste0(round(pct), "%")),
            position = position_dodge(width = 0.9),
            vjust = -0.4, size = 3, fontface = "bold") +
  scale_fill_manual(values = CB_PALETTE, name = "Kategoria") +
  scale_y_continuous(limits = c(0, 105), labels = label_percent(scale = 1),
                     breaks = seq(0, 100, 20)) +
  labs(
    title    = "Polska – korzystanie z internetu wg kategorii (wybrane lata)",
    subtitle = "Porównanie 4 przekrojów czasowych",
    x = "Rok", y = "Odsetek [%]",
    caption = "Źródło: Eurostat"
  ) +
  THEME_BASE +
  theme(legend.position = "bottom",
        legend.text = element_text(size = 9)) +
  guides(fill = guide_legend(nrow = 2))

save_plot(p15, "15_poland_bar_categories_years.png", w = 16, h = 9)

job_fixed <- all_data |>
  filter(country %in% FIXED_COUNTRIES, key == "job", !is.na(pct))

p16 <- ggplot(job_fixed, aes(x = year, y = pct, color = country, group = country)) +
  geom_line(linewidth = 1.5) +
  geom_point(size = 3) +
  geom_text_repel(
    data = job_fixed |> filter(year == 2025),
    aes(label = paste0(country, " ", round(pct, 1), "%")),
    size = 3.5, nudge_x = 0.4
  ) +
  scale_color_manual(values = CB_PALETTE, name = "Kraj") +
  scale_y_continuous(limits = c(0, 55), labels = label_percent(scale = 1),
                     breaks = seq(0, 50, 10)) +
  scale_x_continuous(breaks = 2014:2025) +
  labs(
    title    = "Poszukiwanie pracy online – wybrane kraje (2014–2025)",
    subtitle = "Polska, Niemcy i 6 innych krajów UE",
    x = "Rok", y = "Odsetek [%]",
    caption = "Źródło: Eurostat (tin00102)"
  ) +
  THEME_BASE + theme(legend.position = "none")

save_plot(p16, "16_job_search_fixed_countries.png", w = 14, h = 8)

two_cats2 <- all_data |>
  filter(country %in% FIXED_COUNTRIES,
         key %in% c("emails", "consult_vote"), !is.na(pct))

p17 <- ggplot(two_cats2, aes(x = year, y = pct, color = category, group = category)) +
  geom_line(linewidth = 1.3) +
  geom_point(size = 2.5) +
  facet_wrap(~ country, ncol = 4) +
  scale_color_manual(values = CB_PALETTE[c(1, 5)], name = "Kategoria") +
  scale_y_continuous(limits = c(0, 105), labels = label_percent(scale = 1),
                     breaks = seq(0, 100, 25)) +
  scale_x_continuous(breaks = c(2015, 2019, 2023)) +
  labs(
    title    = "E-maile vs Konsultacje online – wybrane kraje (2014–2025)",
    subtitle = "Każdy panel = kraj; żółty = e-maile, niebieski = konsultacje/głosowanie",
    x = "Rok", y = "Odsetek [%]",
    caption = "Źródło: Eurostat"
  ) +
  THEME_BASE +
  theme(legend.position = "bottom",
        strip.text = element_text(face = "bold", size = 11))

save_plot(p17, "17_email_vs_consult_facet.png", w = 16, h = 10)

bank_growth <- all_data |>
  filter(key == "banking", country %in% EU27, year %in% c(2014, 2025)) |>
  pivot_wider(names_from = year, values_from = pct, names_prefix = "y") |>
  filter(!is.na(y2014) & !is.na(y2025)) |>
  mutate(growth = y2025 - y2014,
         country = fct_reorder(country, growth))

p18 <- ggplot(bank_growth, aes(x = growth, y = country,
                                fill = growth > median(growth, na.rm = TRUE))) +
  geom_col(alpha = 0.85) +
  geom_text(aes(label = paste0("+", round(growth, 1), " pp")),
            hjust = -0.1, size = 3.5) +
  scale_fill_manual(values = c("FALSE" = CB_PALETTE[1], "TRUE" = CB_PALETTE[3]),
                    guide = "none") +
  scale_x_continuous(limits = c(0, 70), labels = label_number(suffix = " pp")) +
  labs(
    title    = "Wzrost bankowości internetowej 2014→2025 (UE-27)",
    subtitle = "Zielony = powyżej mediany wzrostu; żółty = poniżej",
    x = "Wzrost [punkty procentowe]", y = NULL,
    caption = "Źródło: Eurostat (tin00099)"
  ) +
  THEME_BASE

save_plot(p18, "18_banking_growth.png", w = 12, h = 10)

health_eu <- eu_data |>
  filter(key == "health", !is.na(pct)) |>
  group_by(year) |>
  summarise(avg = mean(pct), lo = min(pct), hi = max(pct), .groups = "drop")

health_pl_de <- eu_data |>
  filter(key == "health", country %in% c("Poland", "Germany"), !is.na(pct))

p19 <- ggplot(health_eu, aes(x = year)) +
  geom_ribbon(aes(ymin = lo, ymax = hi), fill = CB_PALETTE[2], alpha = 0.2) +
  geom_line(aes(y = avg), color = CB_PALETTE[2], linewidth = 1.5) +
  geom_line(data = health_pl_de,
            aes(y = pct, color = country, group = country), linewidth = 1.8) +
  geom_point(data = health_pl_de, aes(y = pct, color = country), size = 3) +
  scale_color_manual(values = c("Poland" = CB_PALETTE[6], "Germany" = CB_PALETTE[5]),
                     name = "Kraj") +
  scale_y_continuous(limits = c(0, 105), labels = label_percent(scale = 1),
                     breaks = seq(0, 100, 20)) +
  scale_x_continuous(breaks = 2014:2025) +
  labs(
    title    = "Wyszukiwanie informacji zdrowotnych online (2014–2025)",
    subtitle = "Niebieska wstęga = zakres UE-27 (min–max); linia niebieska = średnia UE; kolor = Polska i Niemcy",
    x = "Rok", y = "Odsetek [%]",
    caption = "Źródło: Eurostat (tin00101)"
  ) +
  THEME_BASE

save_plot(p19, "19_health_ribbon_pl_de.png", w = 14, h = 7)

social_eu <- eu_data |>
  filter(key == "social_media", !is.na(pct)) |>
  mutate(is_highlight = country %in% c("Poland", "Germany", "Bulgaria", "Denmark"))

p20 <- ggplot(social_eu, aes(x = year, y = pct, group = country)) +
  geom_line(data = social_eu |> filter(!is_highlight),
            color = "grey75", linewidth = 0.7, alpha = 0.7) +
  geom_line(data = social_eu |> filter(is_highlight),
            aes(color = country), linewidth = 2) +
  geom_text_repel(
    data = social_eu |> filter(is_highlight, year == 2025),
    aes(label = country, color = country),
    size = 4, fontface = "bold", nudge_x = 0.5
  ) +
  scale_color_manual(values = CB_PALETTE[c(6, 5, 4, 1)], guide = "none") +
  scale_y_continuous(limits = c(0, 105), labels = label_percent(scale = 1),
                     breaks = seq(0, 100, 20)) +
  scale_x_continuous(breaks = 2014:2025) +
  labs(
    title    = "Media społecznościowe – spaghetti plot UE-27 (2014–2025)",
    subtitle = "Szare linie = wszystkie kraje; wyróżnione = Polska, Niemcy, Bułgaria, Dania",
    x = "Rok", y = "Odsetek [%]",
    caption = "Źródło: Eurostat (tin00127)"
  ) +
  THEME_BASE

save_plot(p20, "20_social_media_spaghetti.png", w = 14, h = 7)

pl_de_2025 <- all_data |>
  filter(country %in% c("Poland", "Germany"), year == 2025, !is.na(pct)) |>
  mutate(category = str_wrap(category, 25)) |>
  arrange(desc(pct))

p21 <- ggplot(pl_de_2025, aes(x = pct, y = reorder(category, pct),
                               color = country, shape = country)) +
  geom_line(aes(group = category), color = "grey70", linewidth = 1.5) +
  geom_point(size = 6, alpha = 0.9) +
  geom_text(aes(label = paste0(round(pct, 1), "%")),
            vjust = -1, size = 3.5, fontface = "bold") +
  scale_color_manual(values = c("Poland" = CB_PALETTE[6], "Germany" = CB_PALETTE[5]),
                     name = "Kraj") +
  scale_shape_manual(values = c("Poland" = 17, "Germany" = 16), name = "Kraj") +
  scale_x_continuous(limits = c(0, 105), labels = label_percent(scale = 1),
                     breaks = seq(0, 100, 20)) +
  labs(
    title    = "Polska vs Niemcy – wszystkie kategorie (2025)",
    subtitle = "Dumbbells: każda linia = jedna kategoria; trójkąt = Polska, kółko = Niemcy",
    x = "Odsetek [%]", y = NULL,
    caption = "Źródło: Eurostat"
  ) +
  THEME_BASE

save_plot(p21, "21_dumbbell_pl_de_2025.png", w = 12, h = 8)

banking_fixed <- all_data |>
  filter(country %in% FIXED_COUNTRIES, key == "banking", !is.na(pct))

p22 <- ggplot(banking_fixed, aes(x = year, y = pct)) +
  geom_area(fill = CB_PALETTE[5], alpha = 0.3) +
  geom_line(color = CB_PALETTE[5], linewidth = 1.3) +
  geom_point(color = CB_PALETTE[5], size = 2.5) +
  geom_text(
    data = banking_fixed |> group_by(country) |> slice_max(year, n = 1),
    aes(label = paste0(round(pct, 0), "%")),
    vjust = -0.8, size = 3.5, fontface = "bold", color = CB_PALETTE[5]
  ) +
  facet_wrap(~ country, ncol = 4) +
  scale_y_continuous(limits = c(0, 105), labels = label_percent(scale = 1),
                     breaks = c(0, 50, 100)) +
  scale_x_continuous(breaks = c(2015, 2020, 2025)) +
  labs(
    title    = "Bankowość internetowa – trendy w wybranych krajach (2014–2025)",
    subtitle = "Każdy panel = kraj; wartość na końcu linii = dane 2025",
    x = "Rok", y = "Odsetek [%]",
    caption = "Źródło: Eurostat (tin00099)"
  ) +
  THEME_BASE +
  theme(strip.text = element_text(face = "bold", size = 11))

save_plot(p22, "22_banking_small_multiples.png", w = 16, h = 8)

parallel_df <- all_data |>
  filter(country %in% FIXED_COUNTRIES, year == 2025, !is.na(pct)) |>
  mutate(cat_short = case_when(
    key == "full_usage"   ~ "Ogólne",
    key == "emails"       ~ "E-maile",
    key == "goods"        ~ "Towary",
    key == "banking"      ~ "Bankowość",
    key == "health"       ~ "Zdrowie",
    key == "job"          ~ "Praca",
    key == "social_media" ~ "Social",
    key == "consult_vote" ~ "Głosowanie",
    TRUE ~ key
  ),
  cat_short = factor(cat_short, levels = c(
    "Ogólne","E-maile","Towary","Bankowość","Zdrowie","Praca","Social","Głosowanie"
  )))

p23 <- ggplot(parallel_df, aes(x = cat_short, y = pct,
                                color = country, group = country)) +
  geom_line(linewidth = 1.5, alpha = 0.85) +
  geom_point(size = 3.5) +
  scale_color_manual(values = CB_PALETTE, name = "Kraj") +
  scale_y_continuous(limits = c(0, 105), labels = label_percent(scale = 1),
                     breaks = seq(0, 100, 20)) +
  labs(
    title    = "Profil cyfrowy wybranych krajów – wszystkie kategorie (2025)",
    subtitle = "Każda linia = kraj; punkty = wartości wg kategorii użycia internetu",
    x = NULL, y = "Odsetek [%]",
    caption = "Źródło: Eurostat"
  ) +
  THEME_BASE +
  theme(axis.text.x = element_text(angle = 20, hjust = 1, size = 11))

save_plot(p23, "23_parallel_coordinates_2025.png", w = 14, h = 7)

conv_df <- eu_data |>
  filter(!is.na(pct)) |>
  group_by(year, category) |>
  summarise(sd_pct = sd(pct, na.rm = TRUE), .groups = "drop") |>
  mutate(category = str_wrap(category, 22))

p24 <- ggplot(conv_df, aes(x = year, y = sd_pct, color = category, group = category)) +
  geom_line(linewidth = 1.3) +
  geom_point(size = 2.5) +
  scale_color_manual(values = CB_PALETTE, name = "Kategoria") +
  scale_y_continuous(limits = c(0, NA), labels = label_number(suffix = " pp"),
                     breaks = seq(0, 20, 5)) +
  scale_x_continuous(breaks = 2014:2025) +
  labs(
    title    = "Konwergencja cyfrowa w UE-27 – odchylenie standardowe wg kategorii",
    subtitle = "Malejące SD = kraje upodabniają się do siebie; rosnące = dywergencja",
    x = "Rok", y = "Odchylenie standardowe [pp]",
    caption = "Źródło: Eurostat"
  ) +
  THEME_BASE

save_plot(p24, "24_convergence_sd.png", w = 14, h = 7)

tile_df <- all_data |>
  filter(country %in% FIXED_COUNTRIES, year == 2025, !is.na(pct)) |>
  mutate(cat_short = case_when(
    key == "full_usage"   ~ "Ogólne",
    key == "emails"       ~ "E-maile",
    key == "goods"        ~ "Towary",
    key == "banking"      ~ "Bankowość",
    key == "health"       ~ "Zdrowie",
    key == "job"          ~ "Praca",
    key == "social_media" ~ "Social media",
    key == "consult_vote" ~ "Głosowanie",
    TRUE ~ key
  ))

p25 <- ggplot(tile_df, aes(x = cat_short, y = reorder(country, pct, mean),
                            fill = pct)) +
  geom_tile(color = "white", linewidth = 0.8) +
  geom_text(aes(label = paste0(round(pct, 0), "%")),
            size = 4.5, fontface = "bold",
            color = ifelse(tile_df$pct < 60, "white", "grey20")) +
  scale_fill_viridis_c(option = "cividis", name = "Odsetek [%]",
                       limits = c(0, 100), breaks = seq(0, 100, 25)) +
  labs(
    title    = "Mapa ciepła – profil cyfrowy wybranych krajów (2025)",
    subtitle = "Wartości = odsetek użytkowników danej usługi; sortowanie wg średniej",
    x = NULL, y = NULL,
    caption = "Źródło: Eurostat"
  ) +
  THEME_BASE +
  theme(axis.text.x = element_text(angle = 25, hjust = 1, size = 12),
        axis.text.y = element_text(size = 12),
        panel.grid = element_blank())

save_plot(p25, "25_heatmap_countries_categories_2025.png", w = 14, h = 8)

cat("\n=== Zakończono generowanie 25 wykresów ===\n")
cat("Pliki PNG zapisano w:", OUT_DIR, "\n")
