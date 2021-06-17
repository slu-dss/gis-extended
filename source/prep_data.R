# prepare data ####

## dependencies ####
library(dplyr)
library(janitor)
library(readr)
library(sf)
library(tidycensus)

## crime data ####
### read data, tidy names and subset columns
crimes <- read_csv("source/raw_data/chicago_crimes_raw.csv") %>%
  clean_names() %>%
  select(case_number, date_of_occurrence, primary_description, latitude, longitude) 

### subset observations and create alternate names for arsons
homicide <- filter(crimes, primary_description == "HOMICIDE")
arson <- crimes %>%
  filter(primary_description == "ARSON") %>%
  rename(
    case = case_number,
    date = date_of_occurrence,
    descrip = primary_description,
    lat = latitude,
    long = longitude
  )

### create very small subset of homicides in Woodlawn 
homicide_small <- homicide %>%
  mutate(x = longitude, y = latitude)
homicide_small <- st_as_sf(homicide_small, coords = c("x", "y"), crs = 4269)
homicide_small <- st_transform(homicide_small, crs = 3528)

nhoods <- st_read("source/raw_data/chicago_neighborhoods.geojson") %>%
  filter(sec_neigh == "WOODLAWN") %>%
  select(pri_neigh) %>%
  rename(nhd = pri_neigh)

nhoods <- st_transform(nhoods, crs = 3528)

homicide_small <- st_intersection(homicide_small, nhoods)
st_geometry(homicide_small) <- NULL
homicide_small <- select(homicide_small, -nhd)

### write data
write_csv(arson, "data/chicago_arson.csv")
write_csv(homicide, "data/chicago_homicide.csv")
write_csv(homicide_small, "data/woodlawn_homicide.csv")

### clean-up global environment
rm(arson, crimes, homicide, homicide_small, nhoods)

## covid data ####
### load and prep covid data
covid <- read_csv("source/raw_data/chicago_covid_raw.csv") %>%
  clean_names() %>%
  filter(week_end == "06/12/2021") %>%
  select(zip_code, cases_cumulative, case_rate_cumulative, deaths_cumulative, death_rate_cumulative) %>%
  rename(
    zip = zip_code,
    cases = cases_cumulative,
    case_rate = case_rate_cumulative,
    deaths = deaths_cumulative,
    death_rate = death_rate_cumulative
  ) %>%
  mutate(zip = as.character(zip))

### load and pre zip code data
zips <- st_read("source/raw_data/chicago_zips_raw.geojson") %>%
  select(zip)

### join
covid <- left_join(zips, covid, by = "zip")

### write data
st_write(covid, "data/chicago_covid.geojson")

### clean-up global environment
rm(covid, zips)

## demographic data ####
### get ACS data
race <- get_acs(year = 2019, geography = "tract", table = "B02001", 
                state = 17, county = "Cook", output = "wide", geometry = TRUE)

### prep ACS data
race %>%
  rename(
    total_pop = B02001_001E,
    total_pop_moe = B02001_001M,
    black_pop = B02001_003E,
    black_pop_moe = B02001_003M
  ) %>%
  select(GEOID, total_pop, total_pop_moe, black_pop, black_pop_moe) %>%
  mutate(black_rate = black_pop/total_pop*1000, .after = black_pop_moe) -> race

### write data
st_write(race, "data/chicago_black_pop.geojson")

### clean-up global environment
rm(race)


