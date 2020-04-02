
load("C:/Users/wooki/Dropbox/milieu/data/milieuData.RData")
load("C:/Users/wooki/Dropbox/milieu/data/contextualData.RData")
load("C:/Users/wooki/Dropbox/milieu/data/milieuSurvey.RData")


uniq<-milieuData[!duplicated(milieuData$GEOID),]
uniq$race_v1
sd(uniq$race_v1,na.rm=T) # As we can see, each census block size varies quite a lot
mean(uniq$race_v1,na.rm=T)


# first get the race percent for each block in milieu data
# in here, I do not group by userId becuase what I will do is get the race percent of each block 
# and get the mean of race percent where an individual traveled.
# To do this, I need race percent of each census block first.

# The difference between my measure and Steven's measure is simulated in "racial measurements comparison"
# The main difference is:
# Steven's race percent measure is based on sum of all population in census block where an individual traveled.
# Lim's race percent measure is percent of each census block first and then get the mean of race measure based on individual's travel.

library(dplyr)


#make weights for each person's census block (new!!)
race<-milieuData %>%
  group_by(userId)%>%
  mutate(sum_pop=sum(race_v1),
         weight_block=(race_v1/sum_pop))


#make weighted mean for race info
race<-race %>%
  mutate(white_percent=weight_block*(race_v2/race_v1)*100,
         black_percent=weight_block*(race_v3/race_v1)*100,
         american_indian_percent=weight_block*(race_v4/race_v1)*100,
         asian_percent=weight_block*(race_v5/race_v1)*100,
         hawaiian_percent=weight_block*(race_v6/race_v1)*100,
         other_percent=weight_block*(race_v7/race_v1)*100,
         two_more_percent=weight_block*(race_v7/race_v1)*100,
         segragation = ((white_percent/100)^2+(black_percent/100)^2+(american_indian_percent/100)^2
                        +(asian_percent/100)^2+(hawaiian_percent/100)^2+(other_percent/100)^2+(two_more_percent/100)^2),
         nonwhtie_percent = (weight_block*(race_v1-race_v2)/race_v1)*100,
         diversity=1-segragation)
        


#In here I get the how many data points exist for an individual
sum<-milieuData %>%
  group_by(userId)%>%
  summarise(count=n())




#I dropped individuals who has less than 10 gps tracking data points
race<-merge(race,sum, by="userId") 
race<-subset(race, race$count>10)

#In here, I get mean of non white percent, segregation measure, and diversity measure for each individual 
#by userId. Now it is useful, and I will merge this with parse data later.

race_summ<-race %>%
  group_by(userId) %>%
  summarize(mean_seg=sum(segragation,na.rm=T),
            mean_nowhite=sum(nonwhtie_percent,na.rm=T),
            mean_seg=sum(segragation,na.rm = T),
            mean_div=sum(diversity,na.rm = T),
            var_nonwhite=var(nonwhtie_percent,na.rm=T),
            var_seg=var(segragation,na.rm=T),
            var_div=var(diversity,na.rm = T))

#race_summ<-race %>%
#  group_by(userId) %>%
#  summarize(mean_seg=mean(segragation,na.rm=T),
#            mean_nowhite=mean(nonwhtie_percent,na.rm=T),
#            mean_div=mean(diversity,na.rm = T),
#            mean_new_div=mean(new_div,na.rm=T),
#            var_nonwhite=var(nonwhtie_percent,na.rm=T),
#            var_seg=var(segragation,na.rm=T),
#            var_div=var(diversity,na.rm = T))


#I bring up contextual_data which has tract, county, state level data created by Steven.
#What I do in here is just get tract, county, state level diversity measure
#The variable called new_div is black percent - white percent. This measure is used by one of the papers, so
#I just include it, but it is not the main variable.
library(dplyr)
tract_county_state<-contextual_data %>%
  mutate(mean_seg_tract=(pct_white_tract/100)^2+
           (pct_black_tract/100)^2+(pct_indian_tract/100)^2+
           (pct_asian_tract/100)^2+(pct_hawaiian_tract/100)^2+(pct_other_tract/100)^2+(pct_mixed_race_tract/100)^2,
         mean_seg_county=(pct_white_county/100)^2+(pct_black_county/100)^2+(pct_indian_county/100)^2+
           (pct_asian_county/100)^2+(pct_hawaiian_county/100)^2+(pct_other_race_county/100)^2+(pct_mixedrace_county/100)^2,
         mean_seg_state=(pct_white_state/100)^2+(pct_black_state/100)^2+(pct_indian_state/100)^2+
           (pct_asian_state/100)^2+(pct_hawaiian_state/100)^2+(pct_other_race_state/100)^2+(pct_mixedrace_state/100)^2,
         mean_div_tract=1-mean_seg_tract,
         mean_div_county=1-mean_seg_county,
         mean_div_state=1-mean_seg_state,
         new_div_tract=pct_black_tract-pct_white_tract,
         new_div_county=pct_black_county-pct_white_county,
         new_div_state=pct_black_state-pct_white_state) 
         


#In here, I merge tract_county_state data(tract, county, state level diversity measure) and 
#race_sum data (diversity measure of each individuals by userId)
final<-merge(tract_county_state,race_summ,by="userId")

#steven codes

library(car)
# merge data together
context <- left_join(parseDataWide, final, by = "userId")
context$mean_div_tract
# fix racial resentment measure (higher scores = higher racial resentment)
# "Over the past few years, blacks have gotten less than they deserve."
context$racialResentment1 <- recode(context$racialResentment1,
                                    "'Strongly Agree'=0;
                                    'Agree'=1;
                                    'Neither Agree nor Disagree'=2;
                                    'Disagree'=3;
                                    'Strongly Disagree'=4")

# "Most blacks who receive money from welfare programs could get along without it if they tried."
context$racialResentment2 <- recode(context$racialResentment2,
                                    "'Strongly Disagree'=0;
                                    'Disagree'=1;
                                    'Neither Agree nor Disagree'=2;
                                    'Agree'=3;
                                    'Strongly Agree'=4")

# "It's really a matter of some people not trying hard enough; if blacks would only try harder they could be just as well-off as whites."
context$racialResentment3 <- recode(context$racialResentment3,
                                    "'Strongly Disagree'=0;
                                    'Disagree'=1;
                                    'Neither Agree nor Disagree'=2;
                                    'Agree'=3;
                                    'Strongly Agree'=4")

# "Irish, Italian, Jewish, and many other minorities overcame prejudice and worked their way up.  Blacks should do the same without any special favors."
context$racialResentment4 <- recode(context$racialResentment4,
                                    "'Strongly Disagree'=0;
                                    'Disagree'=1;
                                    'Neither Agree nor Disagree'=2;
                                    'Agree'=3;
                                    'Strongly Agree'=4") 

# "Government officials usually pay less attention to a request or complaint from a black person than from a white person."
context$racialResentment5 <- recode(context$racialResentment5,
                                    "'Strongly Agree'=0;
                                    'Agree'=1;
                                    'Neither Agree nor Disagree'=2;
                                    'Disagree'=3;
                                    'Strongly Disagree'=4")

# "Generations of slavery and discrimination have created conditions that make it difficult for blacks to work their way out of the lower class."
context$racialResentment6 <- recode(context$racialResentment6,
                                    "'Strongly Agree'=0;
                                    'Agree'=1;
                                    'Neither Agree nor Disagree'=2;
                                    'Disagree'=3;
                                    'Strongly Disagree'=4")

context <- context %>%
  mutate(racial_resentment = racialResentment1 + racialResentment2 + racialResentment3 + racialResentment4 + racialResentment5 + racialResentment6)

# party dummies
context <- context %>%
  mutate(democrat = as.numeric(pid3 == "Democrat"),
         republican = as.numeric(pid3 == "Republican"))

# ideology 
context <- context %>%
  mutate(ideo5 = case_when(
    ideology == "Very liberal" ~ 1,
    ideology == "Somewhat liberal" ~ 2,
    ideology == "Moderate" ~ 3,
    ideology == "Somewhat conservative" ~ 4,
    ideology == "Very conservative" ~ 5
  ))

# income
context$income <- as.factor(context$income)

# gender
context <- context %>%
  mutate(female = as.numeric(gender == "Female"))

# non-white
context <- context %>%
  mutate(pct_nonwhite_county = 100 - pct_white_county,
         pct_nonwhite_state = 100 - pct_white_state,
         pct_nonwhite_tract = 100 - pct_white_tract)


# education
context$bachelors <- as.numeric(context$education=="College graduate")
context$education <- as.factor(context$education)



# race
context$nonwhite <- as.numeric(context$race != "White")
context$race <- as.factor(context$race)
context$black<-as.numeric((context$race=="Black"))

# confederate flag
context <- context %>%
  mutate(confed_racism = as.numeric(confederateFlag == "Racism"))

# age
context$birthyear <- as.numeric(context$yearBorn)
context <- context %>%
  mutate(age = 2018 - birthyear)


# views on immigration (higher values = increase immigration)
context <- context %>%
  mutate(immigration = case_when(
    immigrantsAmount == "Reduced a lot" ~ 0,
    immigrantsAmount == "Reduced a little" ~ 1,
    immigrantsAmount == "Remain the same as it is" ~ 2,
    immigrantsAmount == "Increased a little" ~ 3,
    immigrantsAmount == "Increased a lot" ~ 4
  ))



# social trust
context <- context %>%
  mutate(trust = as.numeric(socialTrust == "Most people can be trusted"))

# build new prisons
context <- context %>% mutate(new_prisons = as.numeric(prisons == "New prisons"))

#Lim vs Steven measure
com<-lm(context$mean_nowhite~context$pct_nonwhite_cbgd)
summary(com)
library(stargazer)
stargazer(com)
##############################################################################
##############################################################################
#############################################################################
table(context$race)
library(ggplot2)
p2<-ggplot(context, aes(mean_div)) + geom_density() + 
  labs(x="Degree of racial diversity",y="Density")+
  theme_classic()
p2+theme(plot.title=element_text(hjust=0.5))

c<-lm(context$mean_div~context$var_div)
summary(c)

stargazer(c)


#variance not mean
rr_gps <- lm(racial_resentment ~ democrat + republican +ideo5  + income + female + bachelors + age + nonwhite + var_nonwhite, data = context)
summary(rr_gps)
rr_gps1 <- lm(racial_resentment ~ democrat + republican +ideo5  + income + female + bachelors + age + nonwhite + var_div, data = context)
summary(rr_gps)

star

cf_gps <- lm(confed_racism ~ democrat + republican +ideo5  + income + female + bachelors + age + nonwhite + var_nonwhite, data = context)
cf_gps1 <- lm(confed_racism ~ democrat + republican +ideo5  + income + female + bachelors + age + nonwhite + var_div, data = context)
summary(cf_gps1)

cf_gps <- lm(confed_racism ~ democrat + republican +ideo5  + income + female + bachelors + age + nonwhite + var_nonwhite, data = context)
cf_gps1 <- lm(confed_racism ~ democrat + republican +ideo5  + income + female + bachelors + age + nonwhite + var_div, data = context)
summary(cf_gps1)

stargazer(cf_gps,cf_gps1)

im_gps <- lm(immigration ~ democrat + republican +ideo5  + income + female + bachelors + age + nonwhite + var_nonwhite, data = context)
im_gps1 <- lm(immigration ~ democrat + republican +ideo5  + income + female + bachelors + age + nonwhite + var_div, data = context)
summary(im_gps)

trust_gps <- lm(trust ~ democrat + republican +ideo5  + income + female + bachelors + age + nonwhite + var_nonwhite, data = context)
trust_gps1 <- lm(trust ~ democrat + republican +ideo5  + income + female + bachelors + age + nonwhite + var_div, data = context)
summary(trust_gps)

library(stargazer)
#models rr
# racial resentment
rr_dbg <- lm(racial_resentment ~ democrat + republican  +ideo5 + income + female + bachelors + age + nonwhite + pct_nonwhite_cbgd, data = context)
rr_tract <- lm(racial_resentment ~ democrat  + republican +ideo5  + income + female + bachelors + age + nonwhite + pct_nonwhite_tract, data = context)
rr_county <- lm(racial_resentment ~ democrat  + republican+ideo5   + income + female + bachelors + age + nonwhite + pct_nonwhite_county, data = context)
rr_state <- lm(racial_resentment ~ democrat + republican +ideo5  + income + female + bachelors + age + nonwhite + pct_nonwhite_state, data = context)
rr_gps <- lm(racial_resentment ~ democrat + republican +ideo5  + income + female + bachelors + age + nonwhite + mean_nowhite, data = context)
rr_gps_reverse <- lm(mean_nowhite ~ racial_resentment+democrat + republican +ideo5  + income + female + bachelors + age + nonwhite , data = context)

summary(rr_gps)
rr_models <- list(rr_gps,rr_dbg, rr_tract, rr_county, rr_state)

print_rr_models <- stargazer(rr_models,
                             type = "latex",
                             style = "apsr",
                             title = "Models of Racial Resentment",
                             dep.var.labels = "Racial Resentment",
                             covariate.labels = c("Democrat","Republican","Ideology","Income >= $200k","Income $25k-50k","Income $50k-75k","Income $75k-100k","Income < $25k","Female","Bachleors Degree","Age","Non-white"),
                             keep.stat = c("n","rsq"),
                             notes = "\\parbox[t]{\\linewidth}{This table displays models predicting scores of racial resentment. Higher scores indicate more racial resentment.}",
                             font.size = "footnotesize")



# confederate flag
cf_dbg <- lm(confed_racism ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite + pct_nonwhite_cbgd, data = context)
cf_tract <- lm(confed_racism ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite + pct_nonwhite_tract, data = context)
cf_county <- lm(confed_racism ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite + pct_nonwhite_county, data = context)
cf_state <- lm(confed_racism ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite + pct_nonwhite_state, data = context)
cf_gps <- lm(confed_racism ~ democrat + republican +ideo5  + income + female + bachelors + age + nonwhite + mean_nowhite, data = context)

cf_models <- list(cf_gps,cf_dbg, cf_tract, cf_county, cf_state)

print_cf_models <- stargazer(cf_models,
                             type = "latex",
                             style = "apsr",
                             title = "Models of Views on the Confederate Flag",
                             dep.var.labels = "Confederate Flag a Racist Symobl",
                             covariate.labels = c("Democrat","Republican","Ideology","Income >= $200k","Income $25k-50k","Income $50k-75k","Income $75k-100k","Income < $25k","Female","Bachleors Degree","Age","Non-white"),
                             keep.stat = c("n","rsq"),
                             notes = "\\parbox[t]{\\linewidth}{This table displays linear probability models predicting whether an individual believes the Confederate flag is a symbol of racism.}",
                             font.size = "footnotesize")

# views on immigration levels
im_dbg <- lm(immigration ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite + pct_nonwhite_cbgd, data = context)
im_tract <- lm(immigration ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite + pct_nonwhite_tract, data = context)
im_county <- lm(immigration ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite + pct_nonwhite_county, data = context)
im_state <- lm(immigration ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite + pct_nonwhite_state, data = context)
im_gps <- lm(immigration ~ democrat + republican +ideo5  + income + female + bachelors + age + nonwhite + mean_nowhite, data = context)

im_models <- list(im_gps,im_dbg, im_tract, im_county, im_state)

print_im_models <- stargazer(im_models,
                             type = "latex",
                             style = "apsr",
                             title = "Models of Views on Immigration Levels",
                             dep.var.labels = "Immigration Levels",
                             covariate.labels = c("Democrat","Republican","Ideology","Income >= $200k","Income $25k-50k","Income $50k-75k","Income $75k-100k","Income < $25k","Female","Bachleors Degree","Age","Non-white"),
                             keep.stat = c("n","rsq"),
                             notes = "\\parbox[t]{\\linewidth}{This table displays models predicting individuals' views on immigration levels. The dependent variable ranges from 0-4, where higher values indicate a preference for higher levels of immigration into the United States.}",
                             font.size = "footnotesize")

# can other people be trusted?
trust_dbg <- lm(trust ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite + pct_nonwhite_cbgd, data = context)
trust_tract <- lm(trust ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite + pct_nonwhite_tract, data = context)
trust_county <- lm(trust ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite + pct_nonwhite_county, data = context)
trust_state <- lm(trust ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite + pct_nonwhite_state, data = context)
trust_gps <- lm(trust ~ democrat + republican +ideo5  + income + female + bachelors + age + nonwhite + mean_nowhite, data = context)

trust_models <- list(trust_gps ,trust_dbg, trust_tract, trust_county, trust_state)

print_trust_models <- stargazer(trust_models,
                                type = "latex",
                                style = "apsr",
                                title = "Models of Views on Whether People Can Be Trusted",
                                dep.var.labels = "Can Most People be Trusted?",
                                covariate.labels = c("Democrat","Republican","Ideology","Income >= $200k","Income $25k-50k","Income $50k-75k","Income $75k-100k","Income < $25k","Female","Bachleors Degree","Age","Non-white"),
                                keep.stat = c("n","rsq"),
                                notes = "\\parbox[t]{\\linewidth}{This table displays linear probability models predicted whether individuals believe others can be trusted.}",
                                font.size = "footnotesize")

# build new prisons
prisons_dbg <- lm(new_prisons ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite + pct_nonwhite_cbgd, data = context)
prisons_tract <- lm(new_prisons ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite + pct_nonwhite_tract, data = context)
prisons_county <- lm(new_prisons ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite + pct_nonwhite_county, data = context)
prisons_state <- lm(new_prisons ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite + pct_nonwhite_state, data = context)
prisons_gps <- lm(new_prisons ~ democrat + republican +ideo5  + income + female + bachelors + age + nonwhite + mean_nowhite, data = context)

prisons_models <- list(prisons_gps,prisons_dbg, prisons_tract, prisons_county, prisons_state)

print_prisons_models <- stargazer(prisons_models,
                                  type = "latex",
                                  style = "apsr",
                                  title = "Models of Views on Whether New Prisons Should be Built",
                                  dep.var.labels = "Build New Prisons",
                                  covariate.labels = c("Democrat","Republican","Ideology","Income >= $200k","Income $25k-50k","Income $50k-75k","Income $75k-100k","Income < $25k","Female","Bachleors Degree","Age","Non-white"),
                                  keep.stat = c("n","rsq"),
                                  notes = "\\parbox[t]{\\linewidth}{This table displays linear probability models predicted whether individuals believe funds should be used to build new prisons rather than to develop anti-poverty programs.}",
                                  font.size = "footnotesize")


##############################segragation and diversity#############################
####################################################################################

rr_tract_div <- lm(racial_resentment ~ democrat  + republican +ideo5  + income + female + bachelors + age + nonwhite + mean_div_tract, data = context)
rr_county_div <- lm(racial_resentment ~ democrat  + republican+ideo5   + income + female + bachelors + age + nonwhite + mean_div_county, data = context)
rr_state_div<- lm(racial_resentment ~ democrat + republican +ideo5  + income + female + bachelors + age + nonwhite + mean_div_state, data = context)
rr_gps_div <- lm(racial_resentment ~ democrat + republican +ideo5   + income + female + bachelors + age + nonwhite + mean_div, data = context)
summary(rr_gps_div)

rr_gps_div_reverse <- lm(mean_div ~ racial_resentment+ democrat + republican +ideo5  + income + female + bachelors + age + nonwhite , data = context)
summary(rr_gps_div_reverse)

rr_models_div <- list(rr_gps_div, rr_tract_div, rr_county_div, rr_state_div)

print_rr_models <- stargazer(rr_models_div,
                             type = "latex",
                             style = "apsr",
                             title = "Models of Racial Resentment",
                             dep.var.labels = "Racial Resentment",
                             covariate.labels = c("Democrat","Republican","Ideology","Income >= $200k","Income $25k-50k","Income $50k-75k","Income $75k-100k","Income < $25k","Female","Bachleors Degree","Age","Non-white"),
                             keep.stat = c("n","rsq"),
                             notes = "\\parbox[t]{\\linewidth}{This table displays models predicting scores of racial resentment. Higher scores indicate more racial resentment.}",
                             font.size = "footnotesize")



# confederate flag
cf_tract_div <- lm(confed_racism ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite +mean_div_tract, data = context)
cf_county_div <- lm(confed_racism ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite + mean_div_county, data = context)
cf_state_div <- lm(confed_racism ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite + mean_div_state, data = context)
cf_gps_div <- lm(confed_racism ~ democrat + republican +ideo5  + income + female + bachelors + age + nonwhite + mean_div, data = context)

cf_models_div <- list(cf_gps_div, cf_tract_div, cf_county_div, cf_state_div)

print_cf_models <- stargazer(cf_models_div,
                             type = "latex",
                             style = "apsr",
                             title = "Models of Views on the Confederate Flag",
                             dep.var.labels = "Confederate Flag a Racist Symobl",
                             covariate.labels = c("Democrat","Republican","Ideology","Income >= $200k","Income $25k-50k","Income $50k-75k","Income $75k-100k","Income < $25k","Female","Bachleors Degree","Age","Non-white"),
                             keep.stat = c("n","rsq"),
                             notes = "\\parbox[t]{\\linewidth}{This table displays linear probability models predicting whether an individual believes the Confederate flag is a symbol of racism.}",
                             font.size = "footnotesize")

# views on immigration levels
im_tract_div <- lm(immigration ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite +mean_div_tract, data = context)
im_county_div <- lm(immigration ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite + mean_div_county, data = context)
im_state_div <- lm(immigration ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite +mean_div_state, data = context)
im_gps_div <- lm(immigration ~ democrat + republican +ideo5  + income + female + bachelors + age + nonwhite + mean_div, data = context)

im_models_div <- list(im_gps_div, im_tract_div, im_county_div, im_state_div)

print_im_models <- stargazer(im_models_div,
                             type = "latex",
                             style = "apsr",
                             title = "Models of Views on Immigration Levels",
                             dep.var.labels = "Immigration Levels",
                             covariate.labels = c("Democrat","Republican","Ideology","Income >= $200k","Income $25k-50k","Income $50k-75k","Income $75k-100k","Income < $25k","Female","Bachleors Degree","Age","Non-white"),
                             keep.stat = c("n","rsq"),
                             notes = "\\parbox[t]{\\linewidth}{This table displays models predicting individuals' views on immigration levels. The dependent variable ranges from 0-4, where higher values indicate a preference for higher levels of immigration into the United States.}",
                             font.size = "footnotesize")

# can other people be trusted?
trust_tract_div <- lm(trust ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite + mean_div_tract, data = context)
trust_county_div <- lm(trust ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite + mean_div_county, data = context)
trust_state_div <- lm(trust ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite + mean_div_state, data = context)
trust_gps_div <- lm(trust ~ democrat + republican +ideo5  + income + female + bachelors + age + nonwhite + mean_div, data = context)

trust_models_div <- list(trust_gps_div , trust_tract_div, trust_county_div, trust_state_div)

print_trust_models <- stargazer(trust_models_div,
                                type = "latex",
                                style = "apsr",
                                title = "Models of Views on Whether People Can Be Trusted",
                                dep.var.labels = "Can Most People be Trusted?",
                                covariate.labels = c("Democrat","Republican","Ideology","Income >= $200k","Income $25k-50k","Income $50k-75k","Income $75k-100k","Income < $25k","Female","Bachleors Degree","Age","Non-white"),
                                keep.stat = c("n","rsq"),
                                notes = "\\parbox[t]{\\linewidth}{This table displays linear probability models predicted whether individuals believe others can be trusted.}",
                                font.size = "footnotesize")

# build new prisons
prisons_tract_div <- lm(new_prisons ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite + mean_div_tract, data = context)
prisons_county_div <- lm(new_prisons ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite + mean_div_county, data = context)
prisons_state_div <- lm(new_prisons ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite + mean_div_state, data = context)
prisons_gps_div <- lm(new_prisons ~ democrat + republican +ideo5  + income + female + bachelors + age + nonwhite + mean_div, data = context)

prisons_models_div <- list(prisons_gps_div, prisons_tract_div, prisons_county_div, prisons_state_div)

print_prisons_models <- stargazer(prisons_models_div,
                                  type = "latex",
                                  style = "apsr",
                                  title = "Models of Views on Whether New Prisons Should be Built",
                                  dep.var.labels = "Build New Prisons",
                                  covariate.labels = c("Democrat","Republican","Ideology","Income >= $200k","Income $25k-50k","Income $50k-75k","Income $75k-100k","Income < $25k","Female","Bachleors Degree","Age","Non-white"),
                                  keep.stat = c("n","rsq"),
                                  notes = "\\parbox[t]{\\linewidth}{This table displays linear probability models predicted whether individuals believe funds should be used to build new prisons rather than to develop anti-poverty programs.}",
                                  font.size = "footnotesize")




######################################################
library(stargazer)
table(context$homeOwnership)
context <- context %>%
  mutate(homeownership = as.numeric(homeOwnership == "Own"))

table(context$employment)
context <- context %>%
  mutate(unemployed = as.numeric(employment == "Out of work"))

#Immigrants are getting too demanding in their push for right
context <- context %>%
  mutate(immigration2 = case_when(
    immigrantsRights == "Strongly Disagree" ~ 0,
    immigrantsRights == "Disagree" ~ 1,
    immigrantsRights == "Neither Agree nor Disagree" ~ 2,
    immigrantsRights == "Agree" ~ 3,
    immigrantsRights == "Strongly Agree" ~ 4
  ))


#imm
context <- context %>%
  mutate(immigration_together = immigration + immigration2 )

#police murder
#After the recent shooting of a black man by a white police officer in North Charleston, South Carolina, a grand jury indicted the officer with murder.  
#Do you approve or disapprove of this decision?'
context <- context %>%
  mutate(policemurder = case_when(
    scMurder == "Strongly Approve" ~ 0,
    scMurder == "Approve" ~ 1,
    scMurder == "Neither Approve nor Disapprove" ~ 2,
    scMurder == "Disapprove" ~ 3,
    scMurder == "Strongly Disapprov" ~ 4
  ))
table(context$scMurder)


#household econ status
table(context$econHouseholdProspective)
context <- context %>%
  mutate(econhousestatus = case_when(
    econHouseholdProspective == "Getting much worse" ~ 0,
    econHouseholdProspective == "Getting somewhat worse" ~ 1,
    econHouseholdProspective == "Not changing much" ~ 2,
    econHouseholdProspective == "Getting somewhat better" ~ 3,
    econHouseholdProspective == "Getting much better" ~ 4
  ))


#immigration with homeownership and unempoloyment
immigration_tract_div <- lm(immigration ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite +homeownership+unemployed+ mean_div_tract, data = context)
immigration_county_div <- lm(immigration ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite  +homeownership+unemployed+ mean_div_county, data = context)
immigration_state_div <- lm(immigration ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite  +homeownership+unemployed+ mean_div_state, data = context)
immigration_gps_div <- lm(immigration ~ democrat + republican +ideo5  + income + female + bachelors + age + nonwhite  +homeownership+unemployed+ mean_div, data = context)

immigration_models_div <- list(immigration_gps_div, immigration_tract_div, immigration_county_div, immigration_state_div)

print_immigration_models <- stargazer(immigration_models_div,
                                  type = "latex",
                                  style = "apsr",
                                  title = "Models of Views on immigration amount",
                                  dep.var.labels = "immigration amount",
                                  covariate.labels = c("Democrat","Republican","Ideology","Income >= $200k","Income $25k-50k","Income $50k-75k","Income $75k-100k","Income < $25k","Female","Bachleors Degree","Age","Non-white", "Homeownership","Unemployed"),
                                  keep.stat = c("n","rsq"),
                                  notes = "\\parbox[t]{\\linewidth}{This table displays models predicting individuals' views on immigration levels. The dependent variable ranges from 0-4, where higher values indicate a preference for higher levels of immigration into the United States.}",
                                  font.size = "footnotesize")


# immigration2
immigration2_tract_div <- lm(immigration2 ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite +homeownership+unemployed+ mean_div_tract, data = context)
immigration2_county_div <- lm(immigration2 ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite  +homeownership+unemployed+ mean_div_county, data = context)
immigration2_state_div <- lm(immigration2 ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite  +homeownership+unemployed+ mean_div_state, data = context)
immigration2_gps_div <- lm(immigration2 ~ democrat + republican +ideo5  + income + female + bachelors + age + nonwhite  +homeownership+unemployed+ mean_div, data = context)

immigration2_models_div <- list(immigration2_gps_div, immigration2_tract_div, immigration2_county_div, immigration2_state_div)

print_immigration2_models <- stargazer(immigration2_models_div,
                                      type = "latex",
                                      style = "apsr",
                                      title = "Models of Views on immigration right",
                                      dep.var.labels = "immigration right",
                                      covariate.labels = c("Democrat","Republican","Ideology","Income >= $200k","Income $25k-50k","Income $50k-75k","Income $75k-100k","Income < $25k","Female","Bachleors Degree","Age","Non-white", "Homeownership","Unemployed"),
                                      keep.stat = c("n","rsq"),
                                      notes = "\\parbox[t]{\\linewidth}{DV: immigrants are too demanding.}",
                                      font.size = "footnotesize")


#immigration together: immigration + immigration2
imm_tract_div <- lm(immigration_together ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite +homeownership+unemployed+ mean_div_tract, data = context)
imm_county_div <- lm(immigration_together ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite  +homeownership+unemployed+ mean_div_county, data = context)
imm_state_div <- lm(immigration_together ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite  +homeownership+unemployed+ mean_div_state, data = context)
imm_gps_div <- lm(immigration_together ~ democrat + republican +ideo5  + income + female + bachelors + age + nonwhite  +homeownership+unemployed+ mean_div, data = context)

imm_models_div <- list(imm_gps_div, imm_tract_div, imm_county_div, imm_state_div)

print_immigration_models <- stargazer(imm_models_div,
                                      type = "latex",
                                      style = "apsr",
                                      title = "Models of Views on immigration together",
                                      dep.var.labels = "immigration amount + immigration right",
                                      covariate.labels = c("Democrat","Republican","Ideology","Income >= $200k","Income $25k-50k","Income $50k-75k","Income $75k-100k","Income < $25k","Female","Bachleors Degree","Age","Non-white", "Homeownership","Unemployed"),
                                      keep.stat = c("n","rsq"),
                                      notes = "\\parbox[t]{\\linewidth}{DV: immigration + immigration2}",
                                      font.size = "footnotesize")



#immigration with new_div
immigration_tract_div <- lm(immigration ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite + new_div_tract, data = context)
immigration_county_div <- lm(immigration ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite  + new_div_county, data = context)
immigration_state_div <- lm(immigration ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite  + new_div_state, data = context)
immigration_gps_div <- lm(immigration ~ democrat + republican +ideo5  + income + female + bachelors + age + nonwhite  + mean_new_div, data = context)

immigration_models_div <- list(immigration_gps_div, immigration_tract_div, immigration_county_div, immigration_state_div)

print_immigration_models <- stargazer(immigration_models_div,
                                      type = "latex",
                                      style = "apsr",
                                      title = "Models of Views on immigration amount",
                                      dep.var.labels = "immigration amount",
                                      covariate.labels = c("Democrat","Republican","Ideology","Income >= $200k","Income $25k-50k","Income $50k-75k","Income $75k-100k","Income < $25k","Female","Bachleors Degree","Age","Non-white"),
                                      keep.stat = c("n","rsq"),
                                      notes = "\\parbox[t]{\\linewidth}{Used new diversity measurement: black percent - white percent (by Weber, Christopher R., Lavine, Howard, Huddy, Leonie, and Christopher M. Federico.)}",
                                      font.size = "footnotesize")


#racial_resentment with new_div
immigration_tract_div <- lm(racial_resentment ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite + new_div_tract, data = context)
immigration_county_div <- lm(racial_resentment ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite  + new_div_county, data = context)
immigration_state_div <- lm(racial_resentment ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite  + new_div_state, data = context)
immigration_gps_div <- lm(racial_resentment ~ democrat + republican +ideo5  + income + female + bachelors + age + nonwhite  + mean_new_div, data = context)

immigration_models_div <- list(immigration_gps_div, immigration_tract_div, immigration_county_div, immigration_state_div)

print_immigration_models <- stargazer(immigration_models_div,
                                      type = "latex",
                                      style = "apsr",
                                      title = "Models of Views on racial resentment",
                                      dep.var.labels = "racial resentment",
                                      covariate.labels = c("Democrat","Republican","Ideology","Income >= $200k","Income $25k-50k","Income $50k-75k","Income $75k-100k","Income < $25k","Female","Bachleors Degree","Age","Non-white"),
                                      keep.stat = c("n","rsq"),
                                      notes = "\\parbox[t]{\\linewidth}{Used new diversity measurement: black percent - white percent (by Weber, Christopher R., Lavine, Howard, Huddy, Leonie, and Christopher M. Federico.)}",
                                      font.size = "footnotesize")

table(context$buildBasketball)
context <- context %>%
  mutate(basketball = case_when(
    buildBasketball == "Strongly Disapprove" ~ 0,
    buildBasketball == "Disapprove" ~ 1,
    buildBasketball == "Neither Approve nor Disapprove" ~ 2,
    buildBasketball == "Approve" ~ 3,
    buildBasketball == "Strongly Approve" ~ 4
  ))

#basket with new_div
immigration_tract_div <- lm(basketball ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite + new_div_tract, data = context)
immigration_county_div <- lm(basketball ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite  + new_div_county, data = context)
immigration_state_div <- lm(basketball ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite  + new_div_state, data = context)
immigration_gps_div <- lm(basketball ~ democrat + republican +ideo5  + income + female + bachelors + age + nonwhite  + mean_new_div, data = context)

immigration_models_div <- list(immigration_gps_div, immigration_tract_div, immigration_county_div, immigration_state_div)

print_immigration_models <- stargazer(immigration_models_div,
                                      type = "latex",
                                      style = "apsr",
                                      title = "Models of Views on buidling basketball",
                                      dep.var.labels = "buidling basketball",
                                      covariate.labels = c("Democrat","Republican","Ideology","Income >= $200k","Income $25k-50k","Income $50k-75k","Income $75k-100k","Income < $25k","Female","Bachleors Degree","Age","Non-white"),
                                      keep.stat = c("n","rsq"),
                                      notes = "\\parbox[t]{\\linewidth}{Used new diversity measurement: black percent - white percent (by Weber, Christopher R., Lavine, Howard, Huddy, Leonie, and Christopher M. Federico.) I thought building basketball court is racial policy favored by Black.}",
                                      font.size = "footnotesize")
context$new_prisons
#basket with new_div
immigration_tract_div <- lm(new_prisons ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite + new_div_tract, data = context)
immigration_county_div <- lm(new_prisons ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite  + new_div_county, data = context)
immigration_state_div <- lm(new_prisons ~ democrat + republican + ideo5 + income + female + bachelors + age + nonwhite  + new_div_state, data = context)
immigration_gps_div <- lm(new_prisons ~ democrat + republican +ideo5  + income + female + bachelors + age + nonwhite  + mean_new_div, data = context)

immigration_models_div <- list(immigration_gps_div, immigration_tract_div, immigration_county_div, immigration_state_div)

print_immigration_models <- stargazer(immigration_models_div,
                                      type = "latex",
                                      style = "apsr",
                                      title = "Models of Views on new prisons",
                                      dep.var.labels = "buidling new prisons",
                                      covariate.labels = c("Democrat","Republican","Ideology","Income >= $200k","Income $25k-50k","Income $50k-75k","Income $75k-100k","Income < $25k","Female","Bachleors Degree","Age","Non-white"),
                                      keep.stat = c("n","rsq"),
                                      notes = "\\parbox[t]{\\linewidth}{Used new diversity measurement: black percent - white percent (by Weber, Christopher R., Lavine, Howard, Huddy, Leonie, and Christopher M. Federico.) I thought building basketball court is racial policy favored by Black.}",
                                      font.size = "footnotesize")