library(tidyverse)
library(stringr)
library(ggplot2)

# this file is for calculating some summary stats for CWR natural occurrence 
# by operating on the "GBIF_by_province.csv" dataset, which includes a row for
# each unique combination of ecoregion and province that a CWR naturally occurs in (given GBIF data), 
# and one coordinate point for each of those unique ecoregion and province combinations to facilitate mapping.

# Load data and format so that it can be changed into a projected shapefile
df <- read.csv("./Input_Data_and_Files/GBIF_by_Province.csv")
df2 <- df %>%
  dplyr::select(Crop, sci_nam, ECO_CODE, ECO_NAME, PRENAME, geometry, X.1)
# remove "()" and "c" from geometry and X.1, rename as longitude and latitude
# change from chr to numeric
df2$longitude <- as.numeric(str_sub(df2$geometry, 3))  
df2$latitude <- as.numeric(str_remove(df2$X.1, "[)]"))
Native_Range_DF <- df2 %>% # drop unformatted columns, change chr to factor data class
  dplyr::select(-geometry, -X.1) %>%
  mutate(sci_nam = as.factor(sci_nam), Crop = as.factor(Crop), 
         PRENAME = as.factor(PRENAME), ECO_NAME = as.factor(ECO_NAME), 
         ECO_CODE = as.factor(ECO_CODE))





##############################
# Explore Summary Statistics #
##############################

# find ecoregions with the most total native CWRs
# and most endemic native CWRs
total_and_endemic_CWRs_ecoregion <- Native_Range_DF %>%
  # count total CWRs (unique sci_name in each ecoregion)
  # group by ecoregion
  group_by(ECO_NAME) %>%
  # tally the number of unique CWR species
  distinct(sci_nam, .keep_all = TRUE) %>%
  add_tally() %>%
  rename(total_CWRs_in_ecoregion = "n") %>%
  mutate(total_CWRs_in_ecoregion = as.numeric(total_CWRs_in_ecoregion)) %>%
  ungroup() %>%
  
  # count endemic CWRs (sci_name that occurs in only 1 ecoregion)
  group_by(sci_nam) %>%
  # if group is only one row, endemic = 1, else endemic = 0
  add_tally() %>%
  rename("native_ecoregions_for_species" = "n") %>%
  mutate(is_endemic = ifelse(
    native_ecoregions_for_species == 1, 1, 0)) %>%
  ungroup() %>%
  group_by(ECO_NAME) %>%
  mutate(endemic_CWRs_in_ecoregion = sum(is_endemic))

total_CWRs_group_by_ecoregion <- df4 %>% # all I want for a graph is number of CWRS in each province
  group_by(ECO_NAME) %>%
  summarise(CWRs_per_Ecoregion = mean(total_CWRs_in_ecoregion))

CWRs_group_by_ecoregion$ECO_NAME <- # order provinces by number of  CWRs 
  factor(CWRs_group_by_ecoregion$ECO_NAME,
         levels = CWRs_group_by_ecoregion$ECO_NAME[
           order(CWRs_group_by_ecoregion$CWRs_per_Ecoregion)])

# Plot number CWRs in each province (as a histogram)
p <- ggplot(CWRs_group_by_ecoregion, aes(x = CWRs_per_Ecoregion)) + theme_bw() + 
  geom_histogram()
p

# show five ecoregions with most CWRs
top_n(CWRs_group_by_ecoregion, 5, wt = CWRs_per_Ecoregion)
# show five ecoregions with least CWRs
top_n(CWRs_group_by_ecoregion, -5, wt = CWRs_per_Ecoregion) 

# maybe also look for number eco-endemic CWRs using df4?
  

# province with the most CWRs
df5 <- Native_Range_DF %>%
  group_by(PRENAME) %>% # group by province
  distinct(sci_nam, .keep_all = TRUE) %>% # only one CWR per province (if it's in multiple ECOs in the same province can show up >1 times)
  add_tally() %>% # tally number CWRs in tthe province
  rename(num_CWRs_in_Province = "n") %>%
  mutate(num_CWRs_in_Province = as.numeric(num_CWRs_in_Province))

CWRS_group_by_province <- df5 %>% # all I want for a graph is number of CWRS in each province
  group_by(PRENAME) %>%
  summarise(CWRs = mean(num_CWRs_in_Province))

CWRS_group_by_province$PRENAME <- # order provinces by number of  CWRs 
  factor(CWRS_group_by_province$PRENAME,
         levels = CWRS_group_by_province$PRENAME[
           order(CWRS_group_by_province$CWRs)])

# Plot number CWRs in each province
q <- ggplot(CWRS_group_by_province, aes(x = PRENAME, y = CWRs)) + theme_bw() + 
  geom_bar(stat = "identity") + theme(axis.text.x=element_text(angle=45, hjust=1))
q

# ecoregion with the most Amelanchier CWRs
df6 <- Native_Range_DF %>%
  group_by(ECO_NAME) %>%
  filter(grepl('Amelanchier', sci_nam)) %>%
  distinct(sci_nam, .keep_all = TRUE) %>%
  add_tally() %>%
  rename(num_Amelanchier_relatives_in_Ecoregion = "n") %>%
  mutate(num_Amelanchier_relatives_in_Ecoregion = as.numeric(num_Amelanchier_relatives_in_Ecoregion))

Amelanchier_group_by_ecoregion <- df6 %>% # all I want for a graph is number of CWRS in each province
  group_by(ECO_CODE) %>%
  summarise(Amelanchier_relatives = mean(num_Amelanchier_relatives_in_Ecoregion))

Amelanchier_group_by_ecoregion$ECO_CODE <- # order provinces by number of  CWRs 
  factor(Amelanchier_group_by_ecoregion$ECO_CODE,
         levels = Amelanchier_group_by_ecoregion$ECO_CODE[
           order(Amelanchier_group_by_ecoregion$Amelanchier_relatives)])

# Plot number CWRs in each province
r <- ggplot(Amelanchier_group_by_ecoregion, aes(x = ECO_CODE, y = Amelanchier_relatives)) + theme_bw() + 
  geom_bar(stat = "identity") + theme(axis.text.x=element_text(angle=45, hjust=1))
r

# show five ecoregions with most CWRs
top_n(Amelanchier_group_by_ecoregion, 5, wt = Amelanchier_relatives)
# show five ecoregions with least CWRs
top_n(Amelanchier_group_by_ecoregion, -5, wt = Amelanchier_relatives) 


# province with the most Amelanchier CWRs
df7 <- Native_Range_DF %>%
  group_by(PRENAME) %>%
  filter(grepl('Amelanchier', sci_nam)) %>%
  distinct(sci_nam, .keep_all = TRUE) %>%
  add_tally() %>%
  rename(num_Amelanchier_relatives_in_Province = "n") %>%
  mutate(num_Amelanchier_relatives_in_Province = as.numeric(num_Amelanchier_relatives_in_Province))

Amelanchier_group_by_Province <- df7 %>% # all I want for a graph is number of CWRS in each province
  group_by(PRENAME) %>%
  summarise(Amelanchier_relatives = mean(num_Amelanchier_relatives_in_Province))

Amelanchier_group_by_Province$PRENAME <- # order provinces by number of  CWRs 
  factor(Amelanchier_group_by_Province$PRENAME,
         levels = Amelanchier_group_by_Province$PRENAME[
           order(Amelanchier_group_by_Province$Amelanchier_relatives)])

# Plot number CWRs in each province
s <- ggplot(Amelanchier_group_by_Province, aes(x = PRENAME, y = Amelanchier_relatives)) + theme_bw() + 
  geom_bar(stat = "identity") + theme(axis.text.x=element_text(angle=45, hjust=1))
s

# lat/long of one GBIF occurrence per species per ecoregion
plot(Native_Range_DF$long, Native_Range_DF$lat)
