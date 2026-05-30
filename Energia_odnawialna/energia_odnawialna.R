library(tidyverse)
library(plotly)
library(gganimate)
library(maps)
library(viridis)


# Do zmienienia: abosutna ścieżka
output_dir <- "C:/Users/papro/Documents/wizualizacja/prez4"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

data <- read.csv("C:/Users/papro/Documents/wizualizacja/prez4/global-data-on-sustainable-energy.csv")

names(data) <- make.names(names(data))

data_clean <- data %>%
  filter(!is.na(Entity), !is.na(Year))

selected_countries <- c("Poland", "China", "India", "Nigeria")

electricity_access <- data_clean %>%
  filter(Entity %in% selected_countries)

plot_electricity_access <- ggplot(electricity_access,
       aes(x = Year,
           y = Access.to.electricity....of.population.,
           color = Entity)) +
  geom_line(size = 1.2) +
  theme_minimal() +
  scale_color_viridis_d(name = "Country", option = "D") +
  labs(
    title = "Access to Electricity Over Time",
    x = "Year",
    y = "Access to electricity (%)"
    )

ggsave(file.path(output_dir, "access_to_electricity.png"), plot_electricity_access, width = 10, height = 6, dpi = 300)
print(plot_electricity_access)

avg_access <- data_clean %>%
  mutate(Year = as.numeric(as.character(Year))) %>%
  group_by(Year) %>%
  summarize(
    mean_access = mean(Access.to.electricity....of.population., na.rm = TRUE),
    median_access = median(Access.to.electricity....of.population., na.rm = TRUE)
  ) %>%
  arrange(Year)

plot_avg <- ggplot(avg_access, aes(x = Year, y = mean_access)) +
  geom_line(aes(y = mean_access, color = "Mean"), size = 1.2) +
  geom_point(aes(y = mean_access, color = "Mean")) +
  geom_line(aes(y = median_access, color = "Median"), size = 1.2, linetype = "dashed") +
  geom_point(aes(y = median_access, color = "Median")) +
  scale_color_manual(name = "Statistic", values = c(Mean = "darkgreen", Median = "darkorange")) +
  theme_minimal() +
  labs(
    title = "Average Access to Electricity (All Countries)",
    x = "Year",
    y = "Access to electricity (%)"
  )

ggsave(file.path(output_dir, "avg_access_all_countries.png"), plot_avg, width = 10, height = 6, dpi = 300)
print(plot_avg)

total_emissions <- data_clean %>%
  mutate(Year = as.numeric(as.character(Year)),
         Value_co2_emissions_kt_by_country = as.numeric(as.character(Value_co2_emissions_kt_by_country))) %>%
  filter(!is.na(Year) & Year != 2020) %>%
  group_by(Year) %>%
  summarize(total_emissions_kt = sum(Value_co2_emissions_kt_by_country, na.rm = TRUE)) %>%
  arrange(Year)

plot_total <- ggplot(total_emissions, aes(x = Year, y = total_emissions_kt)) +
  geom_line(size = 1.2, color = "firebrick") +
  geom_point(color = "firebrick") +
  theme_minimal() +
  scale_y_continuous(labels = scales::comma) +
  labs(
    title = "Total CO2 Emissions (kt) — World",
    x = "Year",
    y = "Total CO2 emissions (kt)"
  )

ggsave(file.path(output_dir, "total_world_emissions.png"), plot_total, width = 10, height = 6, dpi = 300)
print(plot_total)

energy_pc_year <- data_clean %>%
  mutate(Year = as.numeric(as.character(Year)),
         energy_pc = as.numeric(as.character(Primary.energy.consumption.per.capita..kWh.person.))) %>%
  filter(!is.na(Year) & Year != 2020) %>%
  group_by(Year) %>%
  summarize(
    mean_energy_pc = mean(energy_pc, na.rm = TRUE),
    median_energy_pc = median(energy_pc, na.rm = TRUE)
  ) %>%
  arrange(Year)

plot_energy_pc <- ggplot(energy_pc_year, aes(x = Year)) +
  geom_line(aes(y = mean_energy_pc, color = "Mean"), size = 1.2) +
  geom_point(aes(y = mean_energy_pc, color = "Mean")) +
  geom_line(aes(y = median_energy_pc, color = "Median"), size = 1.2, linetype = "dashed") +
  geom_point(aes(y = median_energy_pc, color = "Median")) +
  scale_color_manual(name = "Statistic", values = c(Mean = "steelblue", Median = "orange")) +
  theme_minimal() +
  labs(
    title = "Energy Consumption per Capita — Global (mean and median)",
    x = "Year",
    y = "Primary energy consumption per capita (kWh/person)"
  )

ggsave(file.path(output_dir, "energy_consumption_per_capita_global.png"), plot_energy_pc, width = 10, height = 6, dpi = 300)
print(plot_energy_pc)

plot_2_data <- data_clean %>%
  mutate(
    Year = as.numeric(as.character(Year)),
    renewable_share = as.numeric(as.character(Renewable.energy.share.in.the.total.final.energy.consumption....)),
    co2_emissions = as.numeric(as.character(Value_co2_emissions_kt_by_country))
  ) %>%
  filter(Year == 2019, !is.na(renewable_share), !is.na(co2_emissions), co2_emissions > 0)

plot_renewable_co2 <- ggplot(plot_2_data,
       aes(
         x = renewable_share,
         y = co2_emissions
       )) +
  geom_point(alpha = 0.7, color = "steelblue") +
  geom_smooth(method = "lm", se = FALSE, color = "firebrick", linewidth = 1) +
  theme_minimal() +
  scale_y_log10(labels = scales::comma) +
  labs(
    title = "Renewable Energy vs CO2 Emissions",
    x = "Renewable energy share (%)",
    y = "CO2 emissions (kt, log scale)"
    )

ggsave(file.path(output_dir, "renewable_vs_co2.png"), plot_renewable_co2, width = 10, height = 6, dpi = 300)
print(plot_renewable_co2)

top_emitters <- data_clean %>%
  mutate(
    Year = as.numeric(as.character(Year)),
    Value_co2_emissions_kt_by_country = as.numeric(as.character(Value_co2_emissions_kt_by_country))
  ) %>%
  group_by(Entity) %>%
  filter(!is.na(Value_co2_emissions_kt_by_country)) %>%
  slice_max(order_by = Year, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  slice_max(order_by = Value_co2_emissions_kt_by_country, n = 10, with_ties = FALSE)

plot_top_emitters <- ggplot(top_emitters,
       aes(
         x = reorder(Entity, Value_co2_emissions_kt_by_country),
         y = Value_co2_emissions_kt_by_country
       )) +
  geom_col(fill = "darkred") +
  coord_flip() +
  theme_minimal() +
  scale_y_continuous(labels = scales::comma) +
  labs(
    title = "Top 10 CO2 Emitters",
    x = "Country",
    y = "CO2 emissions"
  )

ggsave(file.path(output_dir, "top_co2_emitters.png"), plot_top_emitters, width = 10, height = 6, dpi = 300)
print(plot_top_emitters)

nuclear_year <- data_clean %>%
  mutate(Year = as.numeric(as.character(Year)),
         nuclear_twh = as.numeric(as.character(Electricity.from.nuclear..TWh.))) %>%
  # exclude year 2020 as requested
  filter(!is.na(Year) & Year != 2020) %>%
  group_by(Year) %>%
  summarize(total_nuclear_twh = sum(nuclear_twh, na.rm = TRUE)) %>%
  arrange(Year)

plot_nuclear <- ggplot(nuclear_year, aes(x = Year, y = total_nuclear_twh)) +
  geom_line(color = "darkblue", size = 1.2) +
  geom_point(color = "darkblue") +
  theme_minimal() +
  scale_y_continuous(labels = scales::comma) +
  labs(
    title = "Global Nuclear Electricity Production (TWh)",
    x = "Year",
    y = "Electricity from nuclear (TWh)"
  )

ggsave(file.path(output_dir, "nuclear_energy_production_global.png"), plot_nuclear, width = 10, height = 6, dpi = 300)
print(plot_nuclear)

top_renewables <- data_clean %>%
  mutate(
    Year = as.numeric(as.character(Year)),
    renewable_share = as.numeric(as.character(Renewable.energy.share.in.the.total.final.energy.consumption....))
  ) %>%
  filter(!is.na(Year), !is.na(renewable_share)) %>%
  group_by(Entity) %>%
  slice_max(order_by = Year, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  slice_max(order_by = renewable_share, n = 10, with_ties = FALSE)

plot_renewables <- ggplot(top_renewables,
       aes(
         x = reorder(Entity, renewable_share),
         y = renewable_share
       )) +
  geom_col(fill = "seagreen4") +
  coord_flip() +
  theme_minimal() +
  scale_y_continuous(labels = scales::comma) +
  labs(
    title = "Top 10 Countries by Renewable Energy Share",
    x = "Country",
    y = "Renewable energy share (%)"
  )

ggsave(file.path(output_dir, "top_10_renewable_energy_share.png"), plot_renewables, width = 10, height = 6, dpi = 300)
print(plot_renewables)

bottom_renewables <- data_clean %>%
  mutate(
    Year = as.numeric(as.character(Year)),
    renewable_share = as.numeric(as.character(Renewable.energy.share.in.the.total.final.energy.consumption....))
  ) %>%
  filter(!is.na(Year), !is.na(renewable_share)) %>%
  group_by(Entity) %>%
  slice_max(order_by = Year, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  slice_min(order_by = renewable_share, n = 10, with_ties = FALSE)

plot_bottom_renewables <- ggplot(bottom_renewables,
       aes(
         x = reorder(Entity, renewable_share),
         y = renewable_share
       )) +
  geom_col(fill = "firebrick3") +
  coord_flip() +
  theme_minimal() +
  scale_y_continuous(labels = scales::comma) +
  labs(
    title = "Bottom 10 Countries by Renewable Energy Share",
    x = "Country",
    y = "Renewable energy share (%)"
  )

ggsave(file.path(output_dir, "bottom_10_renewable_energy_share.png"), plot_bottom_renewables, width = 10, height = 6, dpi = 300)
print(plot_bottom_renewables)

nuclear_share_latest <- data_clean %>%
  mutate(
    Year = as.numeric(as.character(Year)),
    nuclear_twh = as.numeric(as.character(Electricity.from.nuclear..TWh.)),
    fossil_twh = as.numeric(as.character(Electricity.from.fossil.fuels..TWh.)),
    renew_twh = as.numeric(as.character(Electricity.from.renewables..TWh.))
  ) %>%
  # compute total electricity from the three reported sources; keep NA if any component missing
  mutate(total_electricity = rowSums(across(c(nuclear_twh, fossil_twh, renew_twh)), na.rm = FALSE)) %>%
  mutate(nuclear_share_pct = ifelse(!is.na(total_electricity) & total_electricity > 0,
                                    nuclear_twh / total_electricity * 100,
                                    NA)) %>%
  filter(!is.na(Year), !is.na(nuclear_share_pct)) %>%
  group_by(Entity) %>%
  # take latest available year per country
  slice_max(order_by = Year, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  slice_max(order_by = nuclear_share_pct, n = 10, with_ties = FALSE)

plot_nuclear_share <- ggplot(nuclear_share_latest,
       aes(
         x = reorder(Entity, nuclear_share_pct),
         y = nuclear_share_pct
       )) +
  geom_col(fill = "navy") +
  coord_flip() +
  theme_minimal() +
  labs(
    title = "Top 10 krajów według udziału energii nuklearnej w produkcji elektryczności (%)",
    x = "Państwo",
    y = "Udział energii nuklearnej (%)"
  )

ggsave(file.path(output_dir, "top_10_nuclear_energy_share.png"), plot_nuclear_share, width = 10, height = 6, dpi = 300)
print(plot_nuclear_share)

co2_per_capita_latest <- data_clean %>%
  mutate(
    Year = as.numeric(as.character(Year)),
    density = as.numeric(as.character(select(., contains("Density"))[[1]])),
    land_area_km2 = as.numeric(as.character(select(., contains("Land.Area"))[[1]])),
    population = density * land_area_km2,
    emissions_kt = as.numeric(as.character(Value_co2_emissions_kt_by_country))
  ) %>%
  filter(!is.na(Year), !is.na(population), population > 0, !is.na(emissions_kt)) %>%
  group_by(Entity) %>%
  slice_max(order_by = Year, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  mutate(emissions_t_per_person = emissions_kt * 1000 / population) %>%
  slice_max(order_by = emissions_t_per_person, n = 10, with_ties = FALSE)

plot_co2_pc <- ggplot(co2_per_capita_latest,
       aes(
         x = reorder(Entity, emissions_t_per_person),
         y = emissions_t_per_person
       )) +
  geom_col(fill = "darkorange") +
  coord_flip() +
  theme_minimal() +
  scale_y_continuous(labels = scales::comma) +
  labs(
    title = "Top 10 countries by CO2 emissions per capita",
    x = "Country",
    y = "CO2 emissions per capita (t/person)"
  )

ggsave(file.path(output_dir, "top_10_co2_per_capita.png"), plot_co2_pc, width = 10, height = 6, dpi = 300)
print(plot_co2_pc)