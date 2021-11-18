library(rvest)
library(xml2)
library(tibble)
library(dplyr)
library(sp)
library(stringr)
library(sf)
library(lubridate)

setwd("C:/Users/paddy/OneDrive - Maynooth University/College/_MSc Data Science & Analytics_/Projects/NFL Spatial Analysis")

# This R file will webscrape NFL schedule data from 1966 (beginning of the SuperBowl era) until 2020

################################################################################

# Section 1) Webscraping from ProFootballReference
################################################################################

base_url <- 'https://www.pro-football-reference.com/years/%s/games.htm'
afl_url <- 'https://www.pro-football-reference.com/years/%s_AFL/games.htm'

table_new <- data.frame()
df <- data.frame()

i <- 1966

# Loop through all NFL season years and parse in the HTML table with the schedule for the year

# From 1966 to 1969 (inclusive) the league was split into the NFL and AFL, hence their schedules
# are listed on different pages

# https://www.pro-football-reference.com/years/1966_AFL/games.htm

while(i < 2021) {
  if(i < 1970 & i >= 1966) {
    new_webpage <- read_html(sprintf(afl_url,i))
    table_new <- html_table(new_webpage)[[1]] %>%
      as_tibble(.name_repair = 'unique')
    table_new$season <- as.character(i)
    df <- rbind(df, table_new)
  }
  new_webpage <- read_html(sprintf(base_url,i))
  table_new <- html_table(new_webpage)[[1]] %>%
    as_tibble(.name_repair = 'unique')
  table_new$season <- as.character(i)
  df <- rbind(df, table_new)
  
  i = i+1
}

# Setting appropriate column names and removing header rows from the data
names(df) <- c("wk", "day", "date", "time", "winner", "home", "loser", "boxscore", "pts_w", "pts_l", "yds_w", "tow", "yds_l", "tol","season")
df1 <- df %>% filter(wk != "Week" & date != "Playoffs")

###############################################################################

# Section 2) Cleaning data
###############################################################################

# dplyr is used to mutate some new variables to the data
# Including a game timestamp, game location, as well as changing the "home" variable
# to represent whether the winning team was at home or not
df2 <- df1 %>% 
  mutate(
    wk = ifelse(
      wk=="WildCard", 25,
      ifelse(
        wk=="Division", 30,
        ifelse(
          wk=="Champ", 40,
          ifelse(
            wk=="ConfChamp",45,
            ifelse(
              wk=="SuperBowl",50,wk
            )
          )
        )
      )
    ),
    time = ifelse(time=="","1:00PM", time),
    game_ts = as.POSIXct(paste(date, time), tz="EST", format='%Y-%m-%d %I:%M%p'),
    home = ifelse(home == '@', 1, ifelse(home == "N", 2, 0)),
    game_location = ifelse(home == 0, str_extract(winner, '\\w+$'), str_extract(loser, '\\w+$')),
    year = as.numeric(substr(date,1,4))
  ) %>%
  select(-c(boxscore))

# This .csv file lists the old/new names of all 32 teams, this is joined to the schedlue data to consistently name
# each franchiese by it's current team name (as of October 2021)
old_names <- read.csv("nfl_names.csv")

df2a <- df2 %>% rename(team_name=winner) %>% left_join(old_names, by="team_name") %>% mutate(team_name= ifelse(is.na(team_name_new), team_name, team_name_new)) %>% select(-c(team_name_new)) %>% rename(winner=team_name)
df2b <- df2a %>% rename(team_name=loser) %>% left_join(old_names, by="team_name") %>% mutate(team_name= ifelse(is.na(team_name_new), team_name, team_name_new)) %>% select(-c(team_name_new)) %>% rename(loser=team_name)

df2c <- df2b %>% arrange(wk) %>% arrange(game_ts) %>% mutate(game_ID = row_number())

# wk is changed to a numeric value earlier for the sake of sorting the rows correctly
# they are changed back here to show clearly in the dataset the occurences of division games, conference championships etc.

df2d <- df2c %>% mutate(
  game_location = ifelse(home == 0, str_extract(winner, '\\w+$'), str_extract(loser, '\\w+$')),
  wk = ifelse(
    wk=="25", "WildCard",
    ifelse(
      wk=="30", "Division",
      ifelse(
        wk=="40", "Champ",
        ifelse(
          wk=="45","ConfChamp",
          ifelse(
            wk=="50","SuperBowl",wk
          )
        )
      )
    )
  )
  )

###############################################################################

# Section 3) Setting the Location of each game
###############################################################################

# A unique location ID is set for each team depending on the year - many franchises
# have changed location/stadium over the years and this needs to be reflected in the data

nfl_std <- as_tibble(read.csv("stadiums.csv"))

nfl_names <- levels(as.factor(df2d$winner))

df3 <- df2d %>% mutate(loc_ID="blank")

current_df <- data.frame()
new_df <- data.frame()

# Loop using the stadiums lookup table, assigning the apporpriate stadium depending
# on the location of the game

i <- 1
while(i <= 32) {
  current <- nfl_names[i]
  current_df <- df3 %>% filter(game_location==str_extract(current, '\\w+$'))
  j <- 1
  while(j <= dim(current_df)[1]) {
    current_year <- current_df$year[j]
    current_loc_ID <- as.character(nfl_std %>% filter((current_year >= from & current_year <= to) & (current==team_name)) %>% select(loc_ID))
    current_df$loc_ID[j] <- current_loc_ID
    j <- j+1
  }
  new_df <- rbind(new_df, current_df)
  current_df <- data.frame()
  i <- i + 1
}

df4 <- new_df %>% arrange(game_ID)

tail(df4)
glimpse(df4)

## One factor not accounted for is teams that played temporarily in a stadium for less than a full year or season
# See New York Giants, this is minor and will be looked at again later. Any cases where this has happened the 
# temporary stadium was geographically very close to the next/previous stadium, reducing the effect on our inferences

# This code will not take into account the few special cases where teams play in a different stadium
# once a year - see Bills @ Toronto Skydome

########################################################

# Section 4) Creation of the home stadiums table
########################################################

stad <- as_tibble(read.csv('stadiums.csv'))

sf_stad <- st_as_sf(stad, coords=c("long","lat"), crs=4326, remove=FALSE)

# Start with just joinging the Stadium location on to the schedule data

stad_loc <- sf_stad %>% select(c("stadium","location","loc_ID","lat","long", "geometry"))

df5 <- df4 %>% full_join(stad_loc, by=c("loc_ID"))

########################################################

# Section 5) Final Column selection and SHapefile Output
#############################################################

nfl_sf <- df5 %>%
  mutate(game_ts=as.character(game_ts), home= ifelse(home=="0", "W", ifelse(home=="1", "L", "N"))) %>%
  select(c("game_ID","game_ts", "season", "day", "wk", "home", "winner", "pts_w", "yds_w", "tow", "loser", "pts_l", "yds_l", "tol", "stadium", "location","loc_ID","lat","long", "geometry"))

int_games <- as_tibble(read.csv("int_games.csv"))
names(int_games)[1] <- "year"

#sf_nfl <- sf_nfl %>% mutate(game_ts = as.POSIXct(game_ts)) 

x_date <- int_games$date
x_winner <- int_games$winner
x_loser <- int_games$loser

df <- data.frame()

for(i in 1:nrow(int_games)) {
  current <- data.frame()
  
  x_date <- int_games$date[i]
  x_winner <- int_games$winner[i]
  x_loser <- int_games$loser[i]
  
  current <- nfl_sf %>% filter(date(game_ts)==x_date & winner==x_winner & loser==x_loser)
  df <- rbind(df, current)
}

int_ids <- cbind(int_games, df$game_ID)# %>% select(c(df$game_ID, long, lat, stadium, city))
names(int_ids)[10] <- "game_ID"

int_join <- int_ids %>% select(c(game_ID, stadium, city, long, lat))

nfl_sf_int <- full_join(nfl_sf, int_join, by="game_ID")

nfl_sf_int <- nfl_sf_int %>% mutate(
  stadium.x = ifelse(is.na(stadium.y), stadium.x, stadium.y),
  location = ifelse(is.na(city), location, city),
  lat.x = ifelse(is.na(lat.y), lat.x, lat.y),
  long.x = ifelse(is.na(long.y), long.x, long.y),
  loc_ID = "INT"
)

nfl_sf_output <- nfl_sf_int %>% rename(stadium=stadium.x, lat=lat.x, long=long.x) %>% st_as_sf(coords=c("long","lat"), crs=4326, remove=FALSE) %>% select(-c(stadium.y, city, long.y, lat.y))

st_write(nfl_sf_output, "nfl_sf_schedule.shp", driver="ESRI Shapefile", append=FALSE)
