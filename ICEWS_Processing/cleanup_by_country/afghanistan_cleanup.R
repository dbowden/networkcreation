##############################################
#### Create Afghan Dissident Network ####
##############################################
library(dplyr)
library(tidyr)
library(stringr)
library(readr)
library(lubridate)
library(zoo)
library(ggplot2)
theme_set(theme_bw())

#import icews w/ group names added for individuals
icews <- read.csv("~/Google Drive/Dissertation Data/networkcreation/icews_groups.csv", stringsAsFactors = FALSE)

#fix dates
icews$date <- ymd(icews$date)
icews$ym <- floor_date(icews$date,"month")

#subset to actors likely to be afghan dissidents
afg.diss <- subset(icews, cow.src==700 & agent.src!="BUS" & cow.tgt==700 & agent.src!="GOV")

#### 1. Attach Src Individuals to Groups ####

#split obs w/ multiple groups into multiple lines (i.e. if an individual is in multiple groups an event is created for each of them)
afg.diss <- afg.diss %>%
  mutate(src.groups=strsplit(src.groups,"; ")) %>%
  unnest(src.groups)

#use group name instead of individual name when available
afg.diss$alt.src <- ifelse(is.na(afg.diss$src.groups)==T, afg.diss$alt.src, afg.diss$src.groups)

#remove extraneous/invalid groups
afg.diss <- subset(afg.diss, alt.src!="Elite (Afghanistan)" & alt.src!="Tajik" & alt.src!="Uzbek" & alt.src!="Pashtun" & alt.src!="Muslim" & alt.src!="Agency Co-ordinating Body for Afghan Relief" & alt.src!="Shia" & alt.src!="Shia (Afghanistan)" & alt.src!="(National) Minor Party (Afghanistan)" & alt.src!="Mohammad Daoud" & alt.src!="Ministry of Foreign Affairs")

#code a few individuals that weren't in the dictionary
afg.diss$alt.src[afg.diss$name.src=="Burhanuddin Rabbani" & afg.diss$date < "1996-09-28"] <- "Government"
afg.diss$alt.src[afg.diss$name.src=="Burhanuddin Rabbani" & afg.diss$date > "1996-09-27" & afg.diss$date < "2001-11-13"] <- "Jamiat-e Islami"
afg.diss$alt.src[afg.diss$name.src=="Burhanuddin Rabbani" & afg.diss$date < "2001-12-23" & afg.diss$date > "2001-11-12"] <- "Government"
afg.diss$alt.src[afg.diss$name.src=="Burhanuddin Rabbani" & afg.diss$date > "2001-12-22"] <- "Jamiat-e Islami"
afg.diss$alt.src[afg.diss$name.src=="Abdullah Abdullah" & afg.diss$alt.src=="(National) Major Party (Afghanistan)"] <- "National Coaltion of Afghanistan"
afg.diss$alt.src[afg.diss$name.src=="Abdullah Abdullah" & afg.diss$date > "2014-09-13"] <- "Government"
afg.diss$alt.src[afg.diss$name.src=="Abdullah Abdullah" & afg.diss$date > "2001-10-01" & afg.diss$date < "2005-04-21"] <- "Government"
afg.diss$alt.src[afg.diss$name.src=="Atta Mohammed Nur" & afg.diss$date > "2004-01-01"] <- "Government"
afg.diss$alt.src[afg.diss$name.src=="Gulbuddin Hekmatyar" & afg.diss$date > "1996-06-25" & afg.diss$date < "1996-09-28"] <- "Government"
afg.diss$alt.src[afg.diss$name.src=="Ahmad Shah Masood" & afg.diss$date < "1996-09-28"] <- "Government"
afg.diss$alt.src[afg.diss$name.src=="Mohammed Omar" & afg.diss$date > "1996-09-26" & afg.diss$date < "2001-11-14"] <- "Government"
afg.diss$alt.src[afg.diss$name.src=="Abdul Qadir" & afg.diss$date > "2001-11-13"] <- "Government"
afg.diss$alt.src[afg.diss$name.src=="Hamid Karzai" & afg.diss$date > "2001-12-21"] <- "Government"
afg.diss$alt.src[afg.diss$name.src=="Abdul Rashid Dostum" & afg.diss$date > "2001-11-13"] <- "Government"
afg.diss$alt.src[afg.diss$alt.src=="Taliban" & afg.diss$date > "1996-09-28" & afg.diss$date < "2001-11-13"] <- "Government"
afg.diss$alt.src[afg.diss$alt.src=="Karim Khalili"] <- "Government"
afg.diss$alt.src[afg.diss$alt.src=="Opposition Major Party (Out Of Government) (United National Front)"] <- "United National Front"
afg.diss$alt.src[afg.diss$alt.src=="Zalmai Rassoul"] <- "Government"
afg.diss$alt.src[afg.diss$alt.src=="Ismail Khan"] <- "Jamiat-e Islami"
afg.diss$alt.src[afg.diss$alt.src=="Mohammad Yunus Khalis"] <- "Hizb-e-Islami Khalis"
afg.diss$alt.src[afg.diss$alt.src=="Sayed Raz Mohammad Agha"] <- "Taliban"

#split again
afg.diss <- afg.diss %>%
  mutate(alt.src=strsplit(alt.src,"; ")) %>%
  unnest(alt.src)

#### 2. ID which groups are dissidents - Nodes for Networks ####

group.months <- afg.diss

#id anti-gov events
group.months$gov.gold <- ifelse((group.months$cow.tgt == 666) , group.months$goldstein, NA)

#create monthly summaries of mean gold vs. gov
group.months <- group.months %>%
  group_by(alt.src,ym) %>%
  summarize(gov.gold = mean(gov.gold,na.rm = T))

#calculate time since last month w/ events
group.months <- group.months %>%
  group_by(alt.src) %>%
  mutate(last=lag(ym))

group.months$last <- ifelse(is.na(group.months$last)==T, paste(group.months$ym), paste(group.months$last))

group.months$last <- ymd(group.months$last)

#create end date + 24mos
group.months <- group.months %>%
  group_by(alt.src) %>%
  mutate(end=max(ym))

group.months$end <- group.months$end + month(24)

group.months$end <- ifelse(group.months$end > ymd("2014-09-01"), paste("2014-09-01"), paste(group.months$end))

group.months$end <- ymd(group.months$end)

#create empty frame of all months while a group is active
frame <- group.months %>%
  group_by(alt.src) %>%
  summarize(start=min(ym),end=max(end)) %>%
  rowwise() %>%
  do(data.frame(alt.src=.$alt.src, ym=seq(.$start, .$end, by="1 month")))

#merge
group.months <- merge(frame,group.months,all=T)
rm(frame)

#roll last obs forward
group.months <- group.months %>%
  group_by(alt.src) %>%
  do(na.locf(.))

group.months$gov.gold <- as.numeric(group.months$gov.gold)

#get size of gap from last obs, drop if more than 18
elapsed_months <- function(end_date, start_date) {
  ed <- as.POSIXlt(end_date)
  sd <- as.POSIXlt(start_date)
  12 * (ed$year - sd$year) + (ed$mon - sd$mon)
}

group.months$gov.gold <- ifelse(elapsed_months(group.months$ym,group.months$last)>24, NA, group.months$gov.gold)
rm(elapsed_months)

#remove non-diss obs
group.months <- subset(group.months,gov.gold<0)


## Use frame as list of nodes ##
write.csv(group.months, "~/Google Drive/Dissertation Data/networkcreation/Network_Creation/nodes/afgestine_nodes.csv")

## Use frame to remove events that occur while a group is out of dissident network ##

#create group-month id
group.months$conmo <- paste(group.months$alt.src, group.months$ym, sep="")

#subset
afg.diss$conmo <- paste(afg.diss$alt.src, afg.diss$ym, sep="")

afg.diss <- subset(afg.diss, conmo %in% group.months$conmo)


#### 3. Attach TGT invididuals to Groups ####

#give individuals with multiple groups an obs for each group
afg.diss <- afg.diss %>%
  mutate(tgt.groups = strsplit(tgt.groups,"; ")) %>%
  unnest(tgt.groups)

#use group instead of individual name when available
afg.diss$alt.tgt <- ifelse(is.na(afg.diss$tgt.groups) == T, afg.diss$alt.tgt, afg.diss$tgt.groups)


#code a few that the dictionary doesn't take care of
afg.diss$alt.tgt[afg.diss$alt.tgt=="afgestinian Islamic Jihad"] <- "Islamic Jihad"
afg.diss$alt.tgt[afg.diss$alt.tgt=="Yasir Arafat"] <- "afgestine Liberation Organization; Fatah"
afg.diss$alt.tgt[afg.diss$alt.tgt=="Majid Faraj"] <- "afgestinian Preventive Security Agency"
afg.diss$alt.tgt[afg.diss$alt.tgt=="Mohammed Deif"] <- "Izz ad-Din al-Qassam Brigades"
afg.diss$alt.tgt[afg.diss$name.tgt=="Ahmed Qureia"] <- "Fatah"
afg.diss$alt.tgt[afg.diss$name.tgt=="Mahmoud Abbas"] <- "afgestine Liberation Organization; Fatah"
afg.diss$alt.tgt[afg.diss$name.tgt=="Salam Fayyad" & afg.diss$date < "2005-12-01"] <- "Fatah"
afg.diss$alt.tgt[afg.diss$name.tgt=="Salam Fayyad" & afg.diss$date > "2005-12-01"] <- "Third Way"
afg.diss$alt.tgt[afg.diss$name.tgt=="Ismail Haniya"] <- "Hamas"
afg.diss$alt.tgt[afg.diss$name.tgt=="Yasir Arafat"] <- "afgestine Liberation Organization; Fatah"
afg.diss$alt.tgt[afg.diss$name.tgt=="Rami Hamdallah"] <- "Fatah"
afg.diss$alt.tgt[afg.diss$name.tgt=="Tayyib Abd-al-Rahim"] <- "Fatah"
afg.diss$alt.tgt[afg.diss$name.tgt=="Nabil Abu-Rudaynah"] <- "Fatah"
afg.diss$alt.tgt[afg.diss$name.tgt=="Riyad al-Malki"] <- "Fatah"
afg.diss$alt.tgt[afg.diss$alt.tgt=="Abdel Razak Al-Yahya"] <- "Fatah"

#unnest again
afg.diss <- afg.diss %>%
  mutate(tgt.groups=strsplit(tgt.groups,"; ")) %>%
  unnest(tgt.groups)

## remove events that don't occur during dissident period
afg.diss$conmo <- paste(afg.diss$alt.tgt, afg.diss$ym, sep="")

afg.diss <- subset(afg.diss, conmo %in% group.months$conmo)

#remove events w/ self
afg.diss <- subset(afg.diss, alt.src!=alt.tgt)

#write
write_csv(afg.diss,"~/Google Drive/Dissertation Data/networkcreation/Network_Creation/edges/afgestine_edge_events.csv")

rm(group.months, afg.diss)
