library(tidyverse)
library(lubridate)

eq <- read.csv("C:/Users/papro/Documents/R/earthquakes_2000-01-01_to_2026-05-10.csv")

eq$time <- ymd_hms(eq$time)

eq$date <- as.Date(eq$time)

eq$year <- year(eq$time)

eq$month <- floor_date(eq$time, "month")


