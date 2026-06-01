library(openxlsx)
library(dplyr)
library(tidyr)
library(stringr)
library(lubridate)
library(ggplot2)
library(forcats)
library(scales)
library(sf)
library(rnaturalearth)
library(rnaturalearthdata)
library(ggrepel)
library(zoo)
library(viridis)

xlsx_path <- "erail_database.xlsx"
out_dir <- "/Users/jan/Desktop/wypadki_kolejowe/erail_wykresy_R/"

if (!dir.exists(out_dir)) {
  dir.create(out_dir, recursive = TRUE)
}

theme_set(
  theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(face = "bold", size = 16),
      plot.subtitle = element_text(size = 11, color = "grey35"),
      plot.caption = element_text(size = 9, color = "grey45"),
      panel.grid.minor = element_blank(),
      legend.position = "bottom"
    )
)

save_plot <- function(plot, filename, width = 11, height = 7) {
  ggsave(
    filename = file.path(out_dir, filename),
    plot = plot,
    width = width,
    height = height,
    dpi = 300,
    bg = "white"
  )
}

df_raw <- openxlsx::read.xlsx(
  xlsxFile = xlsx_path,
  sheet = "Investigations",
  detectDates = TRUE,
  check.names = FALSE
)

names(df_raw) <- stringr::str_trim(names(df_raw))
names(df_raw) <- gsub("\\.", " ", names(df_raw))
names(df_raw) <- make.unique(names(df_raw), sep = "_")

parse_date_flexible <- function(x) {
  if (inherits(x, "Date")) return(x)
  x_chr <- as.character(x)
  d1 <- suppressWarnings(parse_date_time(
    x_chr,
    orders = c("ymd", "dmy", "mdy", "ymd HMS", "dmy HMS", "mdy HMS", "ymd HM", "dmy HM", "mdy HM")
  ))
  x_num <- suppressWarnings(as.numeric(x_chr))
  d2 <- suppressWarnings(as.Date(x_num, origin = "1899-12-30"))
  out <- as.Date(d1)
  out[is.na(out) & !is.na(d2)] <- d2[is.na(out) & !is.na(d2)]
  out
}

first_existing <- function(possible_names, data_names) {
  found <- possible_names[possible_names %in% data_names]
  if (length(found) == 0) return(NA_character_)
  found[1]
}

date_col <- first_existing(c("Date of occurrence", "Date occurrence", "Occurrence date"), names(df_raw))
year_col <- first_existing(c("Year", "year"), names(df_raw))

if (is.na(date_col)) stop("Nie znaleziono kolumny z datą zdarzenia. Sprawdź names(df_raw).")
if (date_col != "Date of occurrence") names(df_raw)[names(df_raw) == date_col] <- "Date of occurrence"
if (!is.na(year_col) && year_col != "Year") names(df_raw)[names(df_raw) == year_col] <- "Year"

df <- df_raw %>%
  mutate(
    `Date of occurrence` = parse_date_flexible(`Date of occurrence`),
    year = lubridate::year(`Date of occurrence`)
  )

if ("Year" %in% names(df)) {
  df <- df %>%
    mutate(
      year_from_col = suppressWarnings(as.numeric(Year)),
      year = if_else(is.na(year), year_from_col, as.numeric(year)),
      year = as.integer(year)
    )
} else {
  df <- df %>% mutate(year = as.integer(year))
}

df <- df %>% filter(is.na(year) | between(year, 2004, 2026))

fatal_cols <- c("Passenger fatalities", "Staff fatalities", "LC User fatalities", "Unauthorised person fatalities", "Other fatalities")

injury_cols <- c(
  "Passenger serious injuries", "Staff serious injuries", "LC User serious injuries",
  "Unauth person serious injuries", "Unauth. person serious injuries", "Other serious injuries"
)

if ("Unauth person serious injuries" %in% names(df) && !"Unauth. person serious injuries" %in% names(df)) {
  names(df)[names(df) == "Unauth person serious injuries"] <- "Unauth. person serious injuries"
}

injury_cols <- c("Passenger serious injuries", "Staff serious injuries", "LC User serious injuries", "Unauth. person serious injuries", "Other serious injuries")
numeric_cols <- c(fatal_cols, injury_cols, "Total fatalities", "Total serious injuries", "Delay")

for (col in numeric_cols) {
  if (col %in% names(df)) {
    df[[col]] <- suppressWarnings(as.numeric(df[[col]]))
    df[[col]][is.na(df[[col]])] <- 0
  }
}

if (!"Total fatalities" %in% names(df)) {
  present_fatal_cols <- intersect(fatal_cols, names(df))
  df[["Total fatalities"]] <- rowSums(df[, present_fatal_cols, drop = FALSE], na.rm = TRUE)
}

if (!"Total serious injuries" %in% names(df)) {
  present_injury_cols <- intersect(injury_cols, names(df))
  df[["Total serious injuries"]] <- rowSums(df[, present_injury_cols, drop = FALSE], na.rm = TRUE)
}

text_cols <- c("Country", "Occurrence type", "Movement type", "Location type", "Railway System type", "Line type", "Investigation Status", "Report Type")

for (col in text_cols) {
  if (col %in% names(df)) {
    df[[col]] <- as.character(df[[col]])
    df[[col]] <- str_trim(df[[col]])
    df[[col]][df[[col]] %in% c("", "nan", "0", "NA", "N/A")] <- NA
  }
}

df <- df %>%
  mutate(
    casualties = `Total fatalities` + `Total serious injuries`,
    has_casualties = casualties > 0
  )

country_pl <- c(
  "Finland" = "Finlandia", "The Netherlands" = "Holandia", "Netherlands" = "Holandia",
  "France" = "Francja", "Norway" = "Norwegia", "Sweden" = "Szwecja",
  "Austria" = "Austria", "United Kingdom" = "Wielka Brytania", "Italy" = "Włochy",
  "Czech Republic" = "Czechy", "Czechia" = "Czechy", "Denmark" = "Dania",
  "Germany" = "Niemcy", "Portugal" = "Portugalia", "Slovak Republic" = "Słowacja",
  "Slovakia" = "Słowacja", "Spain" = "Hiszpania", "Hungary" = "Węgry",
  "Romania" = "Rumunia", "Estonia" = "Estonia", "Belgium" = "Belgia",
  "Ireland" = "Irlandia", "Poland" = "Polska", "Latvia" = "Łotwa",
  "Bulgaria" = "Bułgaria", "Slovenia" = "Słowenia", "Greece" = "Grecja",
  "Luxembourg" = "Luksemburg", "Croatia" = "Chorwacja", "Lithuania" = "Litwa",
  "Switzerland" = "Szwajcaria", "Channel Tunnel*" = "Tunel pod La Manche"
)

occurrence_pl <- function(x) {
  s <- str_to_lower(x)
  case_when(
    is.na(s) ~ "Brak danych",
    str_detect(s, "derail") ~ "Wykolejenie",
    str_detect(s, "level crossing") & str_detect(s, "near miss") ~ "Prawie wypadek na przejeździe",
    str_detect(s, "level crossing") ~ "Wypadek na przejeździe",
    str_detect(s, "accident to persons|rs in motion") ~ "Potrącenie przez pojazd kolejowy",
    str_detect(s, "collision") & str_detect(s, "obstacle") ~ "Zderzenie z przeszkodą",
    str_detect(s, "collision") & str_detect(s, "near miss") ~ "Prawie zderzenie pociągów",
    str_detect(s, "collision") ~ "Zderzenie pociągów",
    str_detect(s, "fire") ~ "Pożar taboru",
    str_detect(s, "spad") ~ "Minięcie sygnału / SPAD",
    str_detect(s, "wrong-side|wrong side") ~ "Błąd sygnalizacji",
    str_detect(s, "unauthor") ~ "Nieuprawniony ruch pociągu",
    str_detect(s, "runaway") ~ "Niekontrolowany ruch pojazdu",
    str_detect(s, "broken|track buckle|infrastructure") ~ "Usterka infrastruktury/taboru",
    TRUE ~ x
  )
}

movement_pl <- function(x) {
  s <- str_to_lower(x)
  has_freight <- str_detect(s, "freight")
  has_passenger <- str_detect(s, "passenger|high speed|regional|long distance")
  has_commuter <- str_detect(s, "commuter")
  case_when(
    is.na(s) ~ "Brak danych",
    has_freight & (has_passenger | has_commuter) ~ "Ruch mieszany",
    has_freight ~ "Pociąg towarowy",
    has_commuter ~ "Pociąg podmiejski",
    str_detect(s, "tramway|tram|light rail") ~ "Tramwaj / lekka kolej",
    str_detect(s, "metro") ~ "Metro",
    has_passenger ~ "Pociąg pasażerski",
    str_detect(s, "shunting") ~ "Manewry kolejowe",
    str_detect(s, "infrastructure|works") ~ "Pociąg techniczny",
    str_detect(s, "locomotive running solo") ~ "Lokomotywa bez wagonów",
    str_detect(s, "heritage") ~ "Kolej historyczna",
    TRUE ~ "Inne / nieokreślone"
  )
}

location_pl <- function(x) {
  s <- str_to_lower(x)
  case_when(
    is.na(s) ~ "Brak danych",
    str_detect(s, "station") ~ "Stacja",
    str_detect(s, "marshalling") ~ "Stacja rozrządowa",
    str_detect(s, "siding") ~ "Bocznica",
    str_detect(s, "line|open") ~ "Linia kolejowa",
    str_detect(s, "circuit|test") ~ "Tor testowy",
    str_detect(s, "other") ~ "Inne",
    TRUE ~ "Inne"
  )
}

system_pl <- function(x) {
  s <- str_to_lower(x)
  case_when(
    is.na(s) ~ "Brak danych",
    str_detect(s, "conventional") ~ "Kolej konwencjonalna",
    str_detect(s, "high-speed|high speed") ~ "Kolej dużych prędkości",
    str_detect(s, "metro|tram|light rail") ~ "Transport miejski",
    str_detect(s, "heritage") ~ "Kolej historyczna",
    TRUE ~ "Inne"
  )
}

df <- df %>%
  mutate(
    country_pl = recode(Country, !!!country_pl, .default = Country),
    occurrence_pl = occurrence_pl(`Occurrence type`),
    movement_pl = movement_pl(`Movement type`),
    location_pl = location_pl(`Location type`),
    system_pl = system_pl(`Railway System type`)
  )

world <- ne_countries(scale = "medium", returnclass = "sf")

europe <- world %>%
  filter(continent == "Europe" | admin %in% c("Turkey", "Cyprus", "Russia")) %>%
  st_crop(xmin = -12, xmax = 35, ymin = 35, ymax = 72)

country_map <- tibble::tribble(
  ~Country, ~admin,
  "Finland", "Finland", "The Netherlands", "Netherlands", "Netherlands", "Netherlands",
  "France", "France", "Norway", "Norway", "Sweden", "Sweden", "Austria", "Austria",
  "United Kingdom", "United Kingdom", "Italy", "Italy", "Czech Republic", "Czechia",
  "Czechia", "Czechia", "Denmark", "Denmark", "Germany", "Germany", "Portugal", "Portugal",
  "Slovak Republic", "Slovakia", "Slovakia", "Slovakia", "Spain", "Spain", "Hungary", "Hungary",
  "Romania", "Romania", "Estonia", "Estonia", "Belgium", "Belgium", "Ireland", "Ireland",
  "Poland", "Poland", "Latvia", "Latvia", "Bulgaria", "Bulgaria", "Slovenia", "Slovenia",
  "Greece", "Greece", "Luxembourg", "Luxembourg", "Croatia", "Croatia", "Lithuania", "Lithuania",
  "Switzerland", "Switzerland"
)

map_events <- df %>%
  filter(!is.na(Country)) %>%
  group_by(Country) %>%
  summarise(events = n(), .groups = "drop") %>%
  left_join(country_map, by = "Country")

europe_events <- europe %>% left_join(map_events, by = c("admin" = "admin"))

p01 <- ggplot(europe_events) +
  geom_sf(aes(fill = events), color = "white", linewidth = 0.25) +
  scale_fill_gradientn(colors = c("#eff3ff", "#bdd7e7", "#6baed6", "#3182bd", "#08519c"), na.value = "grey90", labels = label_number(big.mark = " ")) +
  labs(title = "Mapa Europy: liczba zdarzeń kolejowych według kraju", subtitle = "Liczba rekordów przypisanych do danego kraju w bazie ERAIL", fill = "Liczba\nzdarzeń", caption = "Źródło: ERAIL Database, arkusz Investigations") +
  theme_void() + theme(legend.position = "right")

save_plot(p01, "01_mapa_liczba_zdarzen_blue.png", 11, 8)

map_casualties <- df %>%
  filter(!is.na(Country)) %>%
  group_by(Country) %>%
  summarise(
    fatalities = sum(`Total fatalities`, na.rm = TRUE),
    serious_injuries = sum(`Total serious injuries`, na.rm = TRUE),
    casualties = fatalities + serious_injuries,
    .groups = "drop"
  ) %>%
  left_join(country_map, by = "Country")

europe_casualties <- europe %>% left_join(map_casualties, by = c("admin" = "admin"))

p02 <- ggplot(europe_casualties) +
  geom_sf(aes(fill = casualties), color = "white", linewidth = 0.25) +
  scale_fill_gradientn(colors = c("#fff5eb", "#fdd0a2", "#fdae6b", "#f16913", "#a63603"), na.value = "grey90", labels = label_number(big.mark = " ")) +
  labs(title = "Mapa Europy: liczba poważnie poszkodowanych według kraju", subtitle = "Suma ofiar śmiertelnych i ciężko rannych w bazie ERAIL", fill = "Liczba\nposzkodowanych", caption = "Źródło: ERAIL Database, arkusz Investigations") +
  theme_void() + theme(legend.position = "right")

save_plot(p02, "02_mapa_liczba_poszkodowanych.png", 11, 8)

year_counts <- df %>%
  filter(!is.na(year), year >= 2006, year <= 2025) %>%
  count(year, name = "events") %>%
  complete(year = 2006:2025, fill = list(events = 0)) %>%
  arrange(year) %>%
  mutate(ma3 = zoo::rollmean(events, k = 3, fill = NA, align = "center"))

p03 <- ggplot(year_counts, aes(year, events)) +
  geom_col(fill = "#a6cee3", width = 0.75) +
  geom_line(aes(y = ma3), color = "#e31a1c", linewidth = 1.2, na.rm = TRUE) +
  geom_point(aes(y = ma3), color = "#e31a1c", size = 2, na.rm = TRUE) +
  scale_x_continuous(breaks = seq(2006, 2025, by = 2)) +
  labs(title = "Trend liczby zdarzeń kolejowych w czasie", x = "Rok zdarzenia", y = "Liczba rekordów") +
  theme(axis.text.x = element_text(angle = 0, hjust = 0.5), axis.title.y = element_text(angle = 0, vjust = 0.5), axis.title.y.left = element_text(margin = margin(r = 20)))

save_plot(p03, "03_trend_roczny_2006_2025.png")

casualties_year <- df %>%
  filter(!is.na(year), year >= 2006, year <= 2025) %>%
  group_by(year) %>%
  summarise(fatalities = sum(`Total fatalities`, na.rm = TRUE), serious_injuries = sum(`Total serious injuries`, na.rm = TRUE), .groups = "drop") %>%
  filter(fatalities + serious_injuries > 0) %>%
  pivot_longer(cols = c(fatalities, serious_injuries), names_to = "type", values_to = "value") %>%
  mutate(type = recode(type, "fatalities" = "Ofiary śmiertelne", "serious_injuries" = "Ciężko ranni"))

p04 <- ggplot(casualties_year, aes(year, value, color = type)) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 2) +
  scale_color_manual(values = c("Ofiary śmiertelne" = "#e31a1c", "Ciężko ranni" = "#1f78b4")) +
  scale_x_continuous(breaks = seq(2006, 2025, by = 2)) +
  labs(title = "Skutki zdarzeń w czasie", x = "Rok", y = "Liczba osób", color = "") +
  theme(axis.text.x = element_text(angle = 0, hjust = 0.5), axis.title.y = element_text(angle = 0, vjust = 0.5), axis.title.y.left = element_text(margin = margin(r = 20)))

save_plot(p04, "04_poszkodowani_w_czasie.png")

top_countries <- df %>%
  filter(!is.na(country_pl)) %>%
  count(country_pl, name = "events", sort = TRUE) %>%
  slice_head(n = 12) %>%
  mutate(country_pl = fct_reorder(country_pl, events))

p05 <- ggplot(top_countries, aes(events, country_pl, fill = events)) +
  geom_col(width = 0.72) +
  geom_text(aes(label = events), hjust = -0.1, size = 3.5, color = "grey20") +
  scale_fill_gradient(low = "#cfe8f3", high = "#08519c", guide = "none") +
  scale_x_continuous(expand = expansion(mult = c(0, 0.12)), labels = label_number(big.mark = " ")) +
  labs(title = "Top 12 krajów według liczby rekordów w bazie ERAIL", x = "Liczba rekordów w bazie", y = "Kraj") +
  theme(axis.title.y = element_text(angle = 0, vjust = 0.5), axis.title.y.left = element_text(margin = margin(r = 20)), panel.grid.major.y = element_blank())

save_plot(p05, "05_top12_kraje_rekordy_erail.png")

top_types <- df %>%
  count(occurrence_pl, name = "events", sort = TRUE) %>%
  slice_head(n = 7) %>%
  mutate(occurrence_pl = fct_reorder(str_wrap(occurrence_pl, 35), events))

p06 <- ggplot(top_types, aes(events, occurrence_pl, fill = events)) +
  geom_col(width = 0.72) +
  geom_text(aes(label = events), hjust = -0.1, size = 3.4, color = "grey20") +
  scale_fill_gradientn(colors = c("#fff5eb", "#fdd0a2", "#fdae6b", "#f16913", "#a63603"), guide = "none") +
  scale_x_continuous(expand = expansion(mult = c(0, 0.13)), labels = label_number(big.mark = " ")) +
  labs(title = "Top 7 najczęstszych typów zdarzeń", x = "Liczba rekordów", y = "Typ zdarzenia") +
  theme(axis.title.y = element_text(angle = 0, vjust = 0.5), axis.title.y.left = element_text(margin = margin(r = 20)), panel.grid.major.y = element_blank())

save_plot(p06, "06_top7_typy_zdarzen.png")

severity_type <- df %>%
  filter(!is.na(occurrence_pl), !str_detect(str_to_lower(occurrence_pl), "other"), !str_detect(str_to_lower(occurrence_pl), "inne")) %>%
  group_by(occurrence_pl) %>%
  summarise(fatalities = sum(`Total fatalities`, na.rm = TRUE), serious_injuries = sum(`Total serious injuries`, na.rm = TRUE), total = fatalities + serious_injuries, .groups = "drop") %>%
  filter(total > 0) %>%
  arrange(desc(total)) %>%
  slice_head(n = 5) %>%
  mutate(occurrence_pl = fct_reorder(str_wrap(occurrence_pl, 35), total)) %>%
  pivot_longer(cols = c(serious_injuries, fatalities), names_to = "type", values_to = "value") %>%
  mutate(type = recode(type, "fatalities" = "Ofiary śmiertelne", "serious_injuries" = "Ciężko ranni"))

p07 <- ggplot(severity_type, aes(value, occurrence_pl, fill = type)) +
  geom_col(width = 0.72) +
  geom_text(aes(label = if_else(value > 0, as.character(round(value)), "")), position = position_stack(vjust = 0.5), color = "white", size = 3.3) +
  scale_fill_manual(values = c("Ciężko ranni" = "#fdae6b", "Ofiary śmiertelne" = "#a63603")) +
  scale_x_continuous(expand = expansion(mult = c(0, 0.13)), labels = label_number(big.mark = " ")) +
  labs(title = "Top 5 typów zdarzeń według liczby poszkodowanych", x = "Liczba osób", y = "Typ zdarzenia", fill = NULL) +
  theme(axis.title.y = element_text(angle = 0, vjust = 0.5), axis.title.y.left = element_text(margin = margin(r = 20)), panel.grid.major.y = element_blank(), legend.position = "bottom")

save_plot(p07, "07_top5_skutki_wedlug_typu_zdarzenia.png")

movement_counts <- df %>%
  count(movement_pl, name = "events", sort = TRUE) %>%
  mutate(movement_pl = fct_reorder(str_wrap(movement_pl, 28), events))

p08 <- ggplot(movement_counts, aes(events, movement_pl, fill = events)) +
  geom_col(width = 0.72) +
  geom_text(aes(label = events), hjust = -0.12, size = 3.5, color = "grey20") +
  scale_fill_gradientn(colors = c("#b7e4c7", "#74c69d", "#40916c", "#2d6a4f", "#081c15"), guide = "none") +
  scale_x_continuous(expand = expansion(mult = c(0, 0.16)), labels = label_number(big.mark = " ")) +
  labs(title = "Zdarzenia według typu ruchu szynowego", x = "Liczba rekordów", y = "Typ ruchu") +
  theme(axis.title.y = element_text(angle = 0, vjust = 0.5), axis.title.y.left = element_text(margin = margin(r = 20)), panel.grid.major.y = element_blank())

save_plot(p08, "08_typ_ruchu_szynowego.png")

location_counts <- df %>%
  count(location_pl, name = "events", sort = TRUE) %>%
  mutate(percent = 100 * events / sum(events), location_pl = fct_reorder(location_pl, events))

p09 <- ggplot(location_counts, aes(events, location_pl, fill = events)) +
  geom_col(width = 0.72) +
  geom_text(aes(label = paste0(events, " (", round(percent, 1), "%)")), hjust = -0.08, size = 3.4, color = "grey20") +
  scale_fill_gradientn(colors = c("#bde0fe", "#74c0fc", "#339af0", "#1c7ed6", "#0b5394"), guide = "none") +
  scale_x_continuous(expand = expansion(mult = c(0, 0.22)), labels = label_number(big.mark = " ")) +
  labs(title = "Zdarzenia według typu lokalizacji", x = "Liczba rekordów", y = "Typ lokalizacji") +
  theme(axis.title.y = element_text(angle = 0, vjust = 0.5), axis.title.y.left = element_text(margin = margin(r = 20)), panel.grid.major.y = element_blank())

save_plot(p09, "09_typ_lokalizacji.png")

movement_casualty_rate <- df %>%
  group_by(movement_pl) %>%
  summarise(events = n(), events_with_casualties = sum(has_casualties, na.rm = TRUE), percent_with_casualties = 100 * events_with_casualties / events, .groups = "drop") %>%
  filter(events >= 20) %>%
  mutate(movement_pl = fct_reorder(str_wrap(movement_pl, 28), percent_with_casualties))

p10 <- ggplot(movement_casualty_rate, aes(percent_with_casualties, movement_pl, fill = percent_with_casualties)) +
  geom_col(width = 0.72) +
  geom_text(aes(label = paste0(round(percent_with_casualties, 1), "%  (n=", events, ")")), hjust = -0.08, size = 3.4, color = "grey20") +
  scale_fill_gradientn(colors = c("#fdd0a2", "#fdae6b", "#f16913", "#d94801", "#7f2704"), guide = "none") +
  scale_x_continuous(labels = function(x) paste0(x, "%"), expand = expansion(mult = c(0, 0.25))) +
  labs(title = "Odsetek zdarzeń z poszkodowanymi według typu ruchu", x = "Zdarzenia z ofiarą śmiertelną lub ciężko rannym", y = "Typ ruchu") +
  theme(axis.title.y = element_text(angle = 0, vjust = 0.5), axis.title.y.left = element_text(margin = margin(r = 20)), panel.grid.major.y = element_blank())

save_plot(p10, "10_odsetek_z_poszkodowanymi_typ_ruchu.png")

top6 <- df %>%
  filter(!is.na(country_pl)) %>%
  count(country_pl, sort = TRUE) %>%
  slice_head(n = 6) %>%
  pull(country_pl)

small_multiples <- df %>%
  filter(country_pl %in% top6, !is.na(year), year >= 2006, year <= 2025) %>%
  count(country_pl, year, name = "events") %>%
  complete(country_pl, year = 2006:2025, fill = list(events = 0))

p11 <- ggplot(small_multiples, aes(year, events, fill = events)) +
  geom_col(width = 0.78) +
  facet_wrap(~ country_pl, scales = "free_y", ncol = 3) +
  scale_fill_gradient(low = "#cfe8f3", high = "#08519c", guide = "none") +
  scale_x_continuous(breaks = seq(2006, 2025, by = 4)) +
  scale_y_continuous(labels = label_number(big.mark = " ")) +
  labs(title = "Trend liczby rekordów w krajach z największą liczbą zdarzeń", x = "Rok", y = "Liczba rekordów") +
  theme(axis.text.x = element_text(angle = 0, hjust = 0.5), axis.title.y = element_text(angle = 0, vjust = 0.5), axis.title.y.left = element_text(margin = margin(r = 18)), strip.text = element_text(face = "bold"), panel.grid.major.x = element_blank())

save_plot(p11, "11_trend_top6_kraje_bez_linii.png", 13, 7)

dow_labels <- c("pon", "wt", "śr", "czw", "pt", "sob", "niedz")

dow_counts <- df %>%
  mutate(dow = wday(`Date of occurrence`, week_start = 1)) %>%
  filter(!is.na(dow)) %>%
  count(dow, name = "events") %>%
  mutate(dow = factor(dow_labels[dow], levels = dow_labels))

p12 <- ggplot(dow_counts, aes(dow, events, fill = events)) +
  geom_col(width = 0.72) +
  geom_text(aes(label = events), vjust = -0.25, size = 3.4, color = "grey20") +
  scale_fill_gradientn(colors = c("#e5f5e0", "#a1d99b", "#41ab5d", "#238b45", "#005a32"), guide = "none") +
  scale_y_continuous(expand = expansion(mult = c(0, 0.13)), labels = label_number(big.mark = " ")) +
  labs(title = "Zdarzenia według dnia tygodnia", x = "Dzień tygodnia", y = "Liczba rekordów") +
  theme(axis.title.y = element_text(angle = 0, vjust = 0.5), axis.title.y.left = element_text(margin = margin(r = 18)), panel.grid.major.x = element_blank())

save_plot(p12, "12_dzien_tygodnia.png")

top_occ <- df %>%
  filter(!is.na(occurrence_pl), !str_detect(str_to_lower(occurrence_pl), "other|inne")) %>%
  count(occurrence_pl, sort = TRUE) %>%
  slice_head(n = 5) %>%
  pull(occurrence_pl)

location_occ <- df %>%
  filter(!is.na(location_pl), location_pl != "Brak danych", location_pl %in% c("Stacja", "Linia kolejowa", "Stacja rozrządowa", "Bocznica")) %>%
  mutate(occ_group = if_else(occurrence_pl %in% top_occ, occurrence_pl, "Inne typy")) %>%
  count(location_pl, occ_group, name = "events") %>%
  group_by(location_pl) %>%
  mutate(percent = 100 * events / sum(events)) %>%
  ungroup() %>%
  mutate(location_pl = fct_reorder(location_pl, percent, .fun = sum))

p13 <- ggplot(location_occ, aes(percent, location_pl, fill = occ_group)) +
  geom_col(width = 0.72) +
  scale_fill_brewer(palette = "Set2") +
  scale_x_continuous(labels = function(x) paste0(x, "%")) +
  labs(title = "Struktura typów zdarzeń według lokalizacji", x = "Odsetek zdarzeń", y = "Typ lokalizacji", fill = "Typ zdarzenia") +
  theme(axis.title.y = element_text(angle = 0, vjust = 0.5), axis.title.y.left = element_text(margin = margin(r = 20)), panel.grid.major.y = element_blank(), legend.position = "bottom")

save_plot(p13, "13_lokalizacja_vs_typ_zdarzenia_stacked.png", 12, 7)

p14 <- ggplot(month_counts, aes(month, events, fill = events)) +
  geom_col(width = 0.85, color = "white") +
  coord_polar() +
  scale_fill_gradientn(colors = c("#bde0fe", "#74c0fc", "#339af0", "#1c7ed6", "#0b5394"), guide = "none") +
  labs(title = "Sezonowość zdarzeń kolejowych", x = NULL, y = NULL) +
  theme(axis.text.y = element_blank(), panel.grid.major.x = element_blank())

save_plot(p14, "14_radial_miesiace_zdarzen.png", 8.5, 8.5)