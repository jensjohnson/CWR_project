###########
library(tidyverse)
library(sf)
library(jsonlite)

############################################################
# in order to conduct a GAP ANALYSIS, we need to determine the ecoregion and province
# represented by each of the CWR ex situ accessions in our gardens data sets.
# then this ex situ conservation coverage must be compared against the native range.


###################################################################
# Section 1 Load and format GBIF native range data
###################################################################

# Load CWR master list. Length tells us how many taxa in our inventory
cwr_list <- read.csv("./Input_Data_and_Files/master_list_apr_3.csv")
cwr_list <- cwr_list %>% rename("sci_nam" = "sci_name")
number_of_CWRs_in_our_checklist <- nrow(cwr_list)

# the "GBIF_by_province.csv" dataset includes a row for each unique 
# combination of ecoregion and province that a CWR naturally occurs in (given GBIF data), 
# and one coordinate point for each of those unique ecoregion and 
# province combinations to facilitate mapping.

# Load data and format so that it can be changed into a projected shapefile
#df <- read.csv("./Input_Data_and_Files/GBIF_long.csv")

# this file is too big to upload to github
# IMPORTANT!!! You will need to store this file on a local directory and read
# it from the local directory here. Make sure to edit the directory in fromJSON()
# to match your local directory
df <- fromJSON("long_GBIF_2.json") %>% as.data.frame 


# group by species
# and then take one row per native province
GBIF_province_new <- df %>%
  group_by(sci_nam) %>%
  distinct(PRENAME, .keep_all = TRUE) %>%
  dplyr::select(sci_nam, PRENAME) %>%
  # distinct(sci_nam) # this line just to see how many species (remove for actual processing)
  # has a bunch of extra species?
  # join with cwr_list to pair it down?
  left_join(cwr_list, .)

GBIF_ecoregion_new <- df %>%
  group_by(sci_nam) %>%
  distinct(ECO_NAM, .keep_all = TRUE) %>%
  dplyr::select(sci_nam, ECO_NAM) %>%
  rename("ECO_NAME" = "ECO_NAM") %>%
  left_join(cwr_list, .) 
  
  # use this to see how many species with a range (373)
  # filter(!is.na(ECO_NAME)) %>%
  # distinct(sci_nam, .keep_all = TRUE) 
  
native_occurrence_df_province_formatted <- GBIF_province_new %>%
  rename("province" = "PRENAME", "crop" = "Crop", "species" = "sci_nam") 

native_occurrence_df_ecoregion_formatted <- GBIF_ecoregion_new %>%
  rename("crop" = "Crop", "species" = "sci_nam")

#########################################################################################
# Section 2 Load and format garden collection data                                
#########################################################################################


##########
# compile garden data and append ecoregion or province
# when lat/long was given

# load data from garden collections (already filtered to only CWRs)
# update and add new gardens as we receive additional datasets
cwr_ubc <- read.csv("./Garden_Data/CWR_of_UBC.csv", na.strings=c("","NA"))
cwr_rbg <- read.csv("./Garden_Data/CWR_of_RBG.csv", na.strings=c("","NA"))
cwr_montreal <- read.csv("./Garden_Data/CWR_of_MontrealBG.csv", na.strings=c("","NA"))
cwr_guelph <- read.csv("./Garden_Data/CWR_of_UofGuelph.csv", na.strings=c("","NA"))
cwr_mountp <- read.csv("./Garden_Data/CWR_of_MountPleasantGroup.csv", na.strings=c("","NA"))
cwr_vandusen <- read.csv("./Garden_Data/CWR_of_VanDusenBG.csv", na.strings=c("","NA"))
# cwr_pgrc <- read.csv("./Garden_Data/CWR_Amelanchier_PGRC.csv") # removing these subsetted data sets for now
# cwr_usask <- read.csv("Amelanchier_UofSask.csv") # removing these subsetted data sets for now
cwr_readerrock <- read.csv("./Garden_Data/CWR_of_ReaderRock.csv", na.strings=c("","NA"))

# join all garden data into one long table
# update and add new gardens as we receive additional datasets
garden_accessions <- rbind(cwr_ubc, cwr_rbg, cwr_montreal, cwr_guelph, cwr_mountp, cwr_vandusen,
                           cwr_readerrock, cwr_pgrc)
garden_accessions <- garden_accessions %>% # format columns
  mutate(latitude = as.numeric(latitude), 
         longitude = as.numeric(longitude)) # %>%
  # for now, we want to filter our data for coverage of ONLY CANADIAN ecoregions/admin districts
  # delete the follwoing line of code if the focus expands to North America or world
  # filter(country == "Canada")

# Transform garden data into a projected shape file
sf_garden_accessions <- garden_accessions %>%
  # na.fail = FALSE to keep all of the accessions (about 80% don't have lat long,
  # but many of these have province at least)
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326, na.fail = FALSE)

####################################################################################
# Section 3 - Load and format shapefile data
####################################################################################

# CRS
crs_string = "+proj=lcc +lat_1=49 +lat_2=77 +lon_0=-91.52 +x_0=0 +y_0=0 +datum=NAD83 +units=m +no_defs" # 2

# add geojson map with province boundaries 
canada_cd <- st_read("./Geo_Data/canada_provinces.geojson", quiet = TRUE) # 1
canada_cd <- canada_cd %>%
  rename("province" = "name")

# add geojson map with all of canada (no inner boundaries)
# we will use this as a boundary for trimming all the ecoregion maps
canada <- st_read("./Geo_Data/canada.geojson", quiet = TRUE) # 1

# add geojson map with ecoregion boundaries
world_eco <- st_read("./Geo_Data/world_ecoregions.geojson", quiet = TRUE)
# Trim geojson world map to canada ecoregions from native_occurrence_df
canada_eco <- semi_join(world_eco, native_occurrence_df_ecoregion_formatted, by=("ECO_NAME")) 

# clip ecoregions to canada national border
canada_eco_subset <- st_intersection(canada_eco, canada)
#geojsonio::geojson_write(canada_eco_subset, file = "canada_ecoregions_clipped.geojson")


######################################################################################
# Section 4 - Project Garden Accessions, Append Geo Data, Format for outputs         #
######################################################################################

# Append Province to accession using lat and longitude
# spatial join to add accession province
points_polygon <- st_join(sf_garden_accessions, canada_cd, left = TRUE)
# spatial join to add accession ecoregion
points_polygon_2 <- st_join(points_polygon, canada_eco_subset, left = TRUE)

# break out new latitude and longitude columns and reformat
all_garden_accessions_shapefile <- points_polygon_2 %>%
  # break coordinates into lat/long
  mutate(longitude=gsub("\\,.*","", geometry)) %>%
  mutate(latitude=gsub(".*,","",geometry)) %>%
  # format to remove "c(" and  ")"
  mutate(longitude = as.numeric(str_sub(longitude, 3)))  %>% 
  mutate(latitude = as.numeric(str_remove(latitude, "[)]"))) %>% 
  
  # select columns that match garden accessions
  dplyr::select(X, garden, species, variant, latitude, longitude, country,
                IUCNRedList, province.x, province.y, ECO_CODE, ECO_NAME) %>%
  #rename(new = province) %>% # add a dummy name for province 
  # take province from cd_canada unless was already provided by garden (just want one column)
  mutate(province = ifelse(is.na(province.x), province.y, province.x)) %>%
  dplyr::select(-province.y, - province.x) 
  

# gardens often give province but no lat/long
accessions_w_province_but_no_geo_data <- all_garden_accessions_shapefile %>%
  filter(!is.na(province)) %>%
  filter(is.na(latitude))
# the province layers don't always catch coastal/island collections bounded by ecoregion
# manually edit these accessions afterwards?
accessions_w_ecoregion_but_no_province <- all_garden_accessions_shapefile %>%
  filter(!is.na(ECO_NAME)) %>%
  filter(is.na(province))
accessions_lat_long <- all_garden_accessions_shapefile %>%
  filter(!is.na(latitude))


province_gap_table <- native_occurrence_df_province_formatted %>%
  full_join(all_garden_accessions_shapefile, by = c("species", "province")) %>%
  # need to rejoin with CWR list to get species crop categories and crop for species that weren't in the range maps
  full_join(cwr_list, by = c("species" = "sci_nam")) %>%
  dplyr::select(-Group.x, -crop) %>%
  rename("Group" = "Group.y", "crop" = "Crop")

ecoregion_gap_table <- native_occurrence_df_ecoregion_formatted %>%
  full_join(all_garden_accessions_shapefile) %>%
  # need to rejoin with CWR list to get species crop categories and crop for species that weren't in the range maps
  full_join(cwr_list, by = c("species" = "sci_nam")) %>%
  dplyr::select(-Group.x, -crop) %>%
  rename("Group" = "Group.y", "crop" = "Crop") 



#################################################################################
# Section 5 Write Output Files                                                  #
#################################################################################

# unselect when these files need to be overwritten
# geojsonio::geojson_write(canada_eco_subset, file = "./Geo_Data/canada_ecoregions_clipped.geojson")
# write.csv(province_gap_table, "./Output_Data_and_Files/province_gap_table.csv")
# write.csv(ecoregion_gap_table, "./Output_Data_and_Files/ecoregion_gap_table.csv")