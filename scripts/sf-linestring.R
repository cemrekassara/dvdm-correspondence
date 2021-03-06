### Create sf linestring object for routes ###

# Use sf methods to create linestring for routes Key move is to create id column
# for groups and use gather to have all cities in one column. This makes it
# possible to have only one sf geometry column. Lines are made with
# group_by() and summarise(), along with st_cast() to create linestring

library(tidyverse)
library(sf)
library(units)

letters <- read_csv("data/dvdm-correspondence-1591.csv")
locations <- read_csv("data/locations-1591.csv") %>% 
  select(place:lat) # simplify locations data to only necessary variables

## Routes and create id column
routes <- letters %>%
  group_by(source, destination) %>% 
  summarise() %>% 
  drop_na() %>% 
  ungroup()%>% 
  rowid_to_column("id")

## Gather to make long tibble go from source and destination as variables to
# place and whether it is source or destination. This makes it so there is only
# one set of longitude and latitude columns and so only one sfc column
routes_long <- routes %>% gather(type, place, -id)

# Add latitude and longitude data
routes_geo <- left_join(routes_long, locations, by = "place")

# Create sf object with sfc points
routes_points <- st_as_sf(routes_geo, coords = c("lon", "lat"), crs = 4326)

# Make lines through group_by() and summarise() This keeps order of source and
# destination, because destination is later in the table. do_union = FALSE makes
# geometry a multipoint, which can then be turned into linestring.
routes_lines <- routes_points %>% 
  group_by(id) %>% 
  summarise(do_union = FALSE) %>% 
  st_cast("LINESTRING")

# Add back in source and destination columns with city names
routes_lines <- left_join(routes_lines, routes, by = "id")

# Make great circles
# set_units function is from dfMaxLength argument
# It gives the maximum length of a segment. The function uses
# gcIntermediate to calculate actual segmentation
routes_gcircles <- routes_lines %>% st_segmentize(units::set_units(20, km))

## Distance measurements of routes with units package
# Rounded totals for km and miles since locations are not exact
distance <- st_length(routes_gcircles) %>% 
  as_tibble() %>% 
  add_column(id = 1:nrow(routes)) %>% 
  rename(meters = value) %>% 
  mutate(km = round(set_units(meters, km)),
         miles = round(set_units(meters, miles))) %>% 
  select(id, everything())

routes_distance <- left_join(routes_gcircles, distance, by = "id")

### Plot
library(mapview)

# Map routes by distance
mapview(routes_distance, zcol = "miles", legend = TRUE)