# nfl-spatial-analysis

## Description

This ongoing project aims to perform a spatial analysis on the NFL through the observation of team locations and travel schedules. Does having an arduous travel schedule relate to a teams poor performance, or perhaps can we see differing trends from East coast and West coast teams?

## Methods

### Data Collection

The primary coding language for acquiring and cleaning the data is R. Using the `rvest` package, historical schedule data was scraped from https://www.pro-football-reference.com/, dating back to the begining of the SuperBowl era in 1966. Various cleaning operations were performed in order to remove NA values, adjust team names and locations for ease of reading. Franchise names have been listed as their current iterations, while keeping locations consistant with the year in which the game took place. 

In order to accurately locate each game a lookup table was constructed using data from Wikpedia detailing the home stadium locations of all franchises in the NFL since 1966. By creating a unique `loc_ID` to represent each home stadium in a given year, location data for each stadium was joined on to the schedule data. 

### Data Description

The resulting table details every scheduled NFL game from 1966 until the 2020/2021 season, indicating the following variables:

* `game_ID` - Unique game ID representing each game
* `game_ts` - Timestamp of game
* `day` - Day of the week on which the game took place
* `wk` - Season week number
* `home` - Indicates whether the winning team played at home, W indicates a home game for the winning team, L indicates a home game for the losing team, N indicates a neutral location.
* `winner` - Game winning team
* `pts_w` - Points scored by winning team
* `yds_w` - Yards gained by winning team
* `tow` - Turnovers given up by winning team
* `loser` - Game losing team
* `pts_l` - Points scored by losing team
* `yds_w` - Yards gained by losing team
* `tol` - Turnover given up by losing team
* `stadium` - Stadium name
* `location` - Game location
* `geometry` - Point location provided in EPSG:4326

### Questions we want answered

1)  Why the distance travelled by teams has increased over time?
2)  Is there a relationship between team performance and travel schedule?
3)  Are there trends based on geographic location?
