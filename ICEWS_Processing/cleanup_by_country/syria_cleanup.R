# This file cleans the ICEWS data to isolate events between Palestinian dissidents during months that occur during a conflict (or within the chosen window prior to the conflict). It outputs two files to the network_creation directory: one with lists of dates where the nodes are active, and one with the events used to compute edges.

#Import packages and data ----------------------------------------------

library(dplyr)
library(tidyr)
library(stringr)
library(readr)
library(lubridate)
library(zoo)
library(ggplot2)
theme_set(theme_bw())

#import icews w/ group names added for individuals
icews <- read.csv("ICEWS_Processing/icews_with_groups.csv", stringsAsFactors = FALSE)

#fix dates
icews$date <- ymd(icews$date)
#icews$ym <- floor_date(icews$date,"month")
icews$year <- year(icews$date)

#subset to actors likely to be syrian dissidents
syr <- subset(icews, location=="Syria")

syr <- subset(syr, (cow.src==652 & agent.src!="GOV") | (cow.src!=652 & (agent.src=="REB" | agent.src=="GOV" | agent.src=="OPP")))

# Define spells for SAOM ------------------
#syr$spell <- vector(mode = "numeric", length = length())


#Attach Src Individuals to Groups --------------------------------------

#split obs w/ multiple groups into multiple lines (i.e. if an individual is in multiple groups an event is created for each of them)
syr <- separate_rows(syr, src.groups, sep="; ")


#use group name instead of individual name when available
syr$alt.src <- ifelse(is.na(syr$src.groups)==T, syr$alt.src, syr$src.groups)


#in some cases the group names from dictionary aren't helpful, so go back to individual name
syr$alt.src <- ifelse(syr$alt.src=="Protestors / Popular Opposition / Mobs (Syria)", syr$name.src, syr$alt.src)
syr$alt.src <- ifelse(syr$alt.src=="Sunni", syr$name.src, syr$alt.src)
syr$alt.src <- ifelse(syr$alt.src=="Alawi", syr$name.src, syr$alt.src)
syr$alt.src <- ifelse(syr$alt.src=="Elite (Syria)", syr$name.src, syr$alt.src)
syr$alt.src <- ifelse(syr$alt.src=="Exiles (Syria)", syr$name.src, syr$alt.src)
syr$alt.src <- ifelse(syr$alt.src=="Syria", syr$name.src, syr$alt.src)
syr$alt.src <- ifelse(syr$alt.src=="Kurd (Ethnic Group)", syr$name.src, syr$alt.src)
syr$alt.src <- ifelse(syr$alt.src=="Legal (Syria)", syr$name.src, syr$alt.src)
syr$alt.src <- ifelse(syr$alt.src=="General Population / Civilian / Social (Syria)", syr$name.src, syr$alt.src)


#if it is a foreign government, collapse to single actor
syr$alt.src <- ifelse(syr$cow.src!=652 & syr$agent.src=="GOV", paste("Government of ",syr$country.src, sep=""), syr$alt.src)


#remove invalid and non-dissident groups
syr <- subset(syr, alt.src!="Unattributed" & alt.tgt!="Unattributed")
syr <- subset(syr, alt.src!="Palestinian Territory, Occupied")
syr <- subset(syr, alt.src!="Criminals / Gangs (Egypt)")
syr <- subset(syr, alt.src!="Shabiha") #pro-Assad Alawite militias
syr <- subset(syr, alt.src!="International Federation of Red Cross and Red Crescent Societies")
syr <- subset(syr, alt.src!="Al-Baath Party") #Assad's party
syr <- subset(syr, alt.src!="Hafez al-Assad")
syr <- subset(syr, alt.src!="Saleh Dabbakeh") #Red Cross spokesman
syr <- subset(syr, alt.src!="Activist (Alawi)")
syr <- subset(syr, alt.src!="Wael al-Halki") #PM
syr <- subset(syr, alt.src!="Alawi")
syr <- subset(syr, alt.src!="Nawaf al-Fares") #defected from gov, but no events after
syr <- subset(syr, name.src!="Ali Haidar") #minister for reconciliation
syr <- subset(syr, alt.src!="Hassan al-Nouri") #assad's opponent in last election
syr <- subset(syr, alt.src!="Anwar al-Bunni") #human rights lawyer who doesn't seem to be active in any group
syr <- subset(syr, alt.src!="Hafez al-Assad")
syr <- subset(syr, name.src!="Ban Ki Moon")


#standardize group names
syr$alt.src[syr$alt.src=="Media (National Coalition for Syrian Revolutionary and Opposition Forces)"] <- "National Coalition for Syrian Revolutionary and Opposition Forces"
syr$alt.src[syr$alt.src=="Military (Jabhat al-Nusra)"] <- "Jabhat al-Nusra"
syr$alt.src[syr$alt.src=="Syrian Kurds"] <- "People's Protection Units"
syr$alt.src[syr$alt.src=="Popular Front for the Liberation of Palestine – General Command"] <- "Popular Front for the Liberation of Palestine"
syr$alt.src[syr$alt.src=="Palestine Liberation Organization"] <- "Government of Occupied Palestinian Territory"


#code individuals that the dictionary didn't get
syr$alt.src[syr$alt.src=="Burhan Ghalioun"] <- "Syrian National Council"
syr$alt.src[syr$alt.src=="Rami Abdulrahman"] <- "Syrian Observatory for Human Rights" #maybe should be excluded
syr$alt.src[syr$alt.src=="Abdul Halim Khaddam"] <- "National Salvation Front"
syr$alt.src[syr$alt.src=="George Sabra"] <- "Syrian National Council; National Coalition for Syrian Revolutionary and Opposition Forces"
syr$alt.src[syr$alt.src=="Michel Kilo"] <- "National Coordination Body for Democratic Change"
syr$alt.src[syr$alt.src=="Manaf Tlass"] <- "Free Syrian Army" #defector who supports FSA
syr$alt.src[syr$alt.src=="Riyad Farid Hijab"] <- "High Negotiation Committee" #elected to represent opp in geneva
syr$alt.src[syr$alt.src=="Ausama Monajed"] <- "Syrian National Council"
syr$alt.src[syr$alt.src=="Riad Seif"] <- "National Coalition for Syrian Revolutionary and Opposition Forces"
syr$alt.src[syr$alt.src=="Moaz al-Khatib"] <- "National Coalition for Syrian Revolutionary and Opposition Forces"
syr$alt.src[syr$alt.src=="Salim Idris"] <- "Free Syrian Army"
syr$alt.src[syr$alt.src=="Kamal al-Labwani"] <- "Syrian National Council"
syr$alt.src[syr$alt.src=="Ghassan Hitto"] <- "National Coalition for Syrian Revolutionary and Opposition Forces"
syr$alt.src[syr$alt.src=="Ahmad Jarba"] <- "National Coalition for Syrian Revolutionary and Opposition Forces; Syrian National Council"
syr$alt.src[syr$alt.src=="Samir Nashar"] <- "Syrian Free National Party"
syr$alt.src[syr$alt.src=="Hadi al-Bahra"] <- "National Coalition for Syrian Revolutionary and Opposition Forces"


#split again
syr <- separate_rows(syr, alt.src, sep="; ")


# get min and max goldstein scores to exclude foreign actors with no material events ------------------------------------------------------
syr <- syr %>% 
  group_by(alt.src) %>%
  mutate(min.gold=min(goldstein),max.gold=max(goldstein))

syr <- subset(syr, cow.src==652 | min.gold < -5 | max.gold > 5)


# get anti-gov events to use as DV, remove pro-gov foreign actors ------------------------------

syr$gov.gold <- ifelse(syr$cow.tgt==652 & syr$agent.tgt=="GOV", syr$goldstein, NA)

syr <- syr %>% 
  group_by(alt.src) %>% 
  mutate(median.gov.gold=median(gov.gold,na.rm=T))

syr <- subset(syr, cow.src==652 | median.gov.gold < 0)

# create group numbers
nums <- data.frame(alt.src=unique(syr$alt.src))
nums$srcnum <- seq(1:length(nums$alt.src))

syr <- merge(syr, nums)

#keep anti-gov events
dv <- subset(syr, gov.gold < 0)

write_csv(dv,"Network_Creation/dv/syr_dv.csv")
rm(dv)

# Get network composition by year ---------------------

nodes <- syr %>% 
  group_by(srcnum) %>% 
  summarize(start=min(year),end=max(year))

write.csv(nodes, "Network_Creation/nodes/syria_nodes.csv", row.names = F)
rm(nodes)

#Attach TGT invididuals to Groups --------------------------------------

#split obs w/ multiple groups into multiple lines (i.e. if an individual is in multiple groups an event is created for each of them)
syr <- separate_rows(syr, tgt.groups, sep="; ")

#use group instead of individual name when available
syr$alt.tgt <- ifelse(is.na(syr$tgt.groups) == T, syr$alt.tgt, syr$tgt.groups)


#in some cases the group names from dictionary aren't helpful, so go back to individual name
syr$alt.tgt <- ifelse(syr$alt.tgt=="Protestors / Popular Opposition / Mobs (Syria)", syr$name.tgt, syr$alt.tgt)
syr$alt.tgt <- ifelse(syr$alt.tgt=="Sunni", syr$name.tgt, syr$alt.tgt)
syr$alt.tgt <- ifelse(syr$alt.tgt=="Alawi", syr$name.tgt, syr$alt.tgt)
syr$alt.tgt <- ifelse(syr$alt.tgt=="Elite (Syria)", syr$name.tgt, syr$alt.tgt)
syr$alt.tgt <- ifelse(syr$alt.tgt=="Exiles (Syria)", syr$name.tgt, syr$alt.tgt)
syr$alt.tgt <- ifelse(syr$alt.tgt=="Syria", syr$name.tgt, syr$alt.tgt)
syr$alt.tgt <- ifelse(syr$alt.tgt=="Kurd (Ethnic Group)", syr$name.tgt, syr$alt.tgt)
syr$alt.tgt <- ifelse(syr$alt.tgt=="Legal (Syria)", syr$name.tgt, syr$alt.tgt)
syr$alt.tgt <- ifelse(syr$alt.tgt=="General Population / Civilian / Social (Syria)", syr$name.tgt, syr$alt.tgt)
syr$alt.tgt <- ifelse(syr$alt.tgt=="Protestors / Popular Opposition / Mobs (Syria)", syr$name.tgt, syr$alt.tgt)


#if it is a foreign government, collapse to single actor
syr$alt.tgt <- ifelse(syr$cow.tgt!=652 & syr$agent.tgt=="GOV", paste("Government of ",syr$country.tgt, sep=""), syr$alt.tgt)


#standardize group names
syr$alt.tgt[syr$alt.tgt=="Media (National Coalition for Syrian Revolutionary and Opposition Forces)"] <- "National Coalition for Syrian Revolutionary and Opposition Forces"
syr$alt.tgt[syr$alt.tgt=="Military (Jabhat al-Nusra)"] <- "Jabhat al-Nusra"
syr$alt.tgt[syr$alt.tgt=="Syrian Kurds"] <- "People's Protection Units"
syr$alt.tgt[syr$alt.tgt=="Popular Front for the Liberation of Palestine – General Command"] <- "Popular Front for the Liberation of Palestine"
syr$alt.tgt[syr$alt.tgt=="Palestine Liberation Organization"] <- "Government of Occupied Palestinian Territory"


#code individuals that the dictionary didn't get
syr$alt.tgt[syr$alt.tgt=="Burhan Ghalioun"] <- "Syrian National Council"
syr$alt.tgt[syr$alt.tgt=="Rami Abdulrahman"] <- "Syrian Observatory for Human Rights" #maybe should be excluded
syr$alt.tgt[syr$alt.tgt=="Abdul Halim Khaddam"] <- "National Salvation Front"
syr$alt.tgt[syr$alt.tgt=="George Sabra"] <- "Syrian National Council; National Coalition for Syrian Revolutionary and Opposition Forces"
syr$alt.tgt[syr$alt.tgt=="Michel Kilo"] <- "National Coordination Body for Democratic Change"
syr$alt.tgt[syr$alt.tgt=="Manaf Tlass"] <- "Free Syrian Army" #defector who supports FSA
syr$alt.tgt[syr$alt.tgt=="Riyad Farid Hijab"] <- "High Negotiation Committee" #elected to represent opp in geneva
syr$alt.tgt[syr$alt.tgt=="Ausama Monajed"] <- "Syrian National Council"
syr$alt.tgt[syr$alt.tgt=="Riad Seif"] <- "National Coalition for Syrian Revolutionary and Opposition Forces"
syr$alt.tgt[syr$alt.tgt=="Moaz al-Khatib"] <- "National Coalition for Syrian Revolutionary and Opposition Forces"
syr$alt.tgt[syr$alt.tgt=="Salim Idris"] <- "Free Syrian Army"
syr$alt.tgt[syr$alt.tgt=="Kamal al-Labwani"] <- "Syrian National Council"
syr$alt.tgt[syr$alt.tgt=="Ghassan Hitto"] <- "National Coalition for Syrian Revolutionary and Opposition Forces"
syr$alt.tgt[syr$alt.tgt=="Ahmad Jarba"] <- "National Coalition for Syrian Revolutionary and Opposition Forces; Syrian National Council"
syr$alt.tgt[syr$alt.tgt=="Samir Nashar"] <- "Syrian Free National Party"
syr$alt.tgt[syr$alt.tgt=="Hadi al-Bahra"] <- "National Coalition for Syrian Revolutionary and Opposition Forces"
syr$alt.tgt[syr$alt.tgt=="Abu Bakr al-Baghdadi"] <- "Islamic State of Iraq and the Levant"
syr$alt.tgt[syr$alt.tgt=="Ahmad Jibril"] <- "Popular Front for the Liberation of Palestine"


#unnest again
syr <- separate_rows(syr, alt.tgt, sep="; ")

## remove events that where target isn't dissident
syr <- subset(syr, (alt.tgt %in% alt.src) | alt.tgt=="Tawhid Brigade")

#remove events w/ self
syr <- subset(syr, alt.src!=alt.tgt)

#remove events w/ unattributed
syr <- subset(syr, alt.src!="Unattributed" & alt.tgt!="Unattributed")

#remove duplicate events
syr <- subset(syr, duplicated(subset(syr,select=c(alt.tgt,alt.src,date,cameo)))==F)

# Aggregate to yearly summaries ---------------------------

## Create directed dyad IDs

# merge numbers
colnames(nums) <- c("alt.tgt","tgtnum")

syr <- merge(syr,nums)

# dyadid
syr$dirdyad <- paste(syr$srcnum, syr$tgtnum, sep="-")

# Create yearly summaries 
syr <- syr %>% 
  group_by(dirdyad, year) %>% 
  summarize(srcnum=first(srcnum), tgtnum=first(tgtnum), mean.gold=mean(goldstein))

syr <- subset(syr, mean.gold > 0)

#write
write.csv(syr,"Network_Creation/edges/syria_edges.csv", row.names = F)
rm(syr)

# save key for id nums ----------------

nums$abbrev <- vector(mode = 'character', length = length(nums$alt.tgt))

#create abbreviations
nums$abbrev[nums$alt.tgt=="Government of United States"] <- "US"
nums$abbrev[nums$alt.tgt=="Syrian National Council"] <- "SNC"
nums$abbrev[nums$alt.tgt=="Free Syrian Army"] <- "FSA"
nums$abbrev[nums$alt.tgt=="Government of Qatar"] <- "Qatar"
nums$abbrev[nums$alt.tgt=="Syrian Revolution General Commission"] <- "SRGC"
nums$abbrev[nums$alt.tgt=="Government of Turkey"] <- "Turkey"
nums$abbrev[nums$alt.tgt=="Government of Israel"] <- "Israel"
nums$abbrev[nums$alt.tgt=="Government of Saudi Arabia"] <- "Saudi Arabia"
nums$abbrev[nums$alt.tgt=="People's Protection Units"] <- "YPG"
nums$abbrev[nums$alt.tgt=="National Coalition for Syrian Revolutionary and Opposition Forces"] <- "NCSROF"
nums$abbrev[nums$alt.tgt=="Hamas"] <- "Hamas"
nums$abbrev[nums$alt.tgt=="High Negotiation Committee"] <- "HNC"
nums$abbrev[nums$alt.tgt=="Government of France"] <- "France"
nums$abbrev[nums$alt.tgt=="Syrian Observatory for Human Rights"] <- "SOHR"
nums$abbrev[nums$alt.tgt=="Jabhat al-Nusra"] <- "Nusra"
nums$abbrev[nums$alt.tgt=="Islamic State of Iraq and the Levant"] <- "ISIL"
nums$abbrev[nums$alt.tgt=="Government of Australia"] <- "Australia"
nums$abbrev[nums$alt.tgt=="Ahrar ash-Sham"] <- "Ahrar ash-Sham"
nums$abbrev[nums$alt.tgt=="Syrian Revolutionary Front"] <- "SRF"
nums$abbrev[nums$alt.tgt=="National Salvation Front"] <- "NSF"
nums$abbrev[nums$alt.tgt=="Popular Front for Change and Liberation"] <- "PFCL"
nums$abbrev[nums$alt.tgt=="Syrian Liberation Army"] <- "SLA"
nums$abbrev[nums$alt.tgt=="National Coordination Body for Democratic Change"] <- "NCBDC"
nums$abbrev[nums$alt.tgt=="People’s Will Party"] <- "PWP"
nums$abbrev[nums$alt.tgt=="Local Coordination Committees of Syria"] <- "LCCS"
nums$abbrev[nums$alt.tgt=="Syrian Free National Party"] <- "SFNP"

write_csv(nums, "Network_Creation/ids/syria_ids.csv")
rm(nums)
