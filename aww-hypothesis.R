###### Hypothesis: /r/aww on the front page
#- H0 /r/aww composes less than 10% of the subreddits on the front page
#- Ha /r/aww composes 10% or more of the subreddits on the front page

library(jsonlite)
library(logging)
library(plyr)
library(stringr)
library(data.table)
source('helpers.R')

# log settings
#basicConfig("DEBUG")
basicConfig("INFO")
addHandler(writeToFile, file = "aww-hypothesis.log")

loginfo("Starting up!")

loginfo("Running unit tests")
getDateUtc_Test()
getTimestampFromFilename_Test()
addTimestamp_Test()
removeReviews_Test()
cleanAndStemText_Test()
removeReviews_Test()

# directory to read reddit results from 
allCsvDir = 'C:/reddit-csv/front every 30/'

# read entries
loginfo(paste0("Reading files from directory ", allCsvDir))
all <- readAllCsvFilesInDirectory(allCsvDir)
loginfo("Done reading")

subData <- data.frame(list(subreddit = all$subreddit, score = all$score, id = all$id, timestamp = all$timestamp))

# convert to number for later use
subData$timestamp <- as.numeric(subData$timestamp)

# aggregate the subreddit count
loginfo(paste0("Aggregating the count of each subreddit on the front page\r\n by sample date, this may take a while."))
aggSub <- aggregate(subData$subreddit, by = list(subreddit = subData$subreddit, timestamp = subData$timestamp), FUN = function(count){
  #print('is.(x)')
  #Sys.sleep(0.5)
  return(length(count))
})

loginfo("Prepping data for horizontal bar plot of subreddit percentage on frontpage")
# aggregate subreddit count by timestamp,
# this will give us the sum count by subreddit over time
aggSubTimeSum <- aggregate(aggSub$x, by = list(subreddit = aggSub$subreddit), FUN = sum)

# sort by count descending
aggSubTimeSum <- aggSubTimeSum[order(aggSubTimeSum$x),]

# percent of each subreddit
aggSubTimePercent = aggSubTimeSum$x / sum(aggSubTimeSum$x)

whichPage <- "front"

firstSampleDate = as.POSIXct(min(subData$timestamp) / 1000, origin="1970-01-01")
lastSampleDate = as.POSIXct(max(subData$timestamp) / 1000, origin="1970-01-01")
                       
#paste0("From ", length(unique(subData$timestamp)),
#" observations, percent subreddits on ", whichPage ," page from\r\n",
aggSubBarTitleText = paste0("Percent subreddits on ", whichPage ," page from\r\n",
                            firstSampleDate, " to ", lastSampleDate)

barX = aggSubTimePercent
awwPercent = aggSubTimePercent[aggSubTimeSum$subreddit == "aww"]
barColors = sapply(aggSubTimeSum$subreddit, function(x){
  if (x == "aww")
  {
    return("blue")
  } else {
    return("grey")
  }
});


maxX = c(0, 0.08)
loginfo("Plot a horizontal bar chart showing the percentage of subreddits on the front page")
par(mai=c(0.5,2,0.5,1))
midpoints = barplot(barX, horiz = TRUE, 
        names.arg = aggSubTimeSum$subreddit,
        las = 1,
        main = aggSubBarTitleText,
        xlim = maxX, col = barColors)
grid(col = 'black',ny = NA)

# draw label and line for aww percentage
abline(v = awwPercent, col = "blue", lty = 2)
#axis(1,at = c(awwPercent), labels = (round(awwPercent, 3)))
yLabelPos = which(aggSubTimeSum$subreddit == "aww")
text(awwPercent, midpoints[yLabelPos], round(awwPercent, 3), 
     pos = 4, cex=0.7, col = "blue")
par(mai=c(1,1,1,1))


loginfo("Preparing data for ks test of sample against a Poisson distribution")
# get the counts of aww subreddit for each timestamp
# so we can check for normality
awwCounts = sort(aggSub[aggSub$subreddit == "aww",]$x)
meanawwCount = mean(awwCounts)
awwPercent = meanawwCount / 100 # since our observations are 100 posts each

# determine if the counts come from a poisson distribution
randAwwPois = rpois(length(awwCounts), mean(awwCounts))

loginfo("Plotting emirical cumulative distribution function for the sample and the theoretical Poisson distribution")
plot(ecdf(randAwwPois), col='blue')
lines(ecdf(awwCounts), col='red')
loginfo("Plotting qqplot of the sample and the theoretical Poisson distribution ")
qqplot(awwCounts, randAwwPois)

loginfo("Preparing data for ks test of sample against a Poisson distribution")
test = ks.test(awwCounts, randAwwPois)
 
# repeatedly create Poisson distribution samples
# from observations and compare to empirical distribution
ksStatResult = sapply(1:500, function(i){
 dist_a = rpois(length(awwCounts), mean(awwCounts))
 ks = ks.test(dist_a, awwCounts)
 return(ks$statistic)
})

loginfo("Creating histogram of k-s statistic from 500 theoretical Poisson distribution samples against our empirical data.")
hist(ksStatResult)
lines(density(ksStatResult))

awwPVal = 1 - ppois(10, lambda = mean(awwCounts))

loginfo(paste0("#### Summary for hypothesis /r/aww on the front page:\r\n",
               "#- H0 /r/aww composes less than 10% of the subreddits on the front page\r\n",
               "#- Ha /r/aww composes 10% or more of the subreddits on the front page\r\n",
               "Of ", nrow(subData) / 100 ," samples of the samples reddit front page (100 posts each sample)",
               " from ", firstSampleDate, " to ", lastSampleDate,
               ", the aww subreddit makes up ", round(meanawwCount, 2), "% of the subreddits on the front page. In",
               " order to confirm statistical significance of the sample, I tested it against ", 
               "a Poisson distribution. The p-value for /r/aww making up ",
               round(meanawwCount, 2), "% of the subreddits on the front page is ", awwPVal, 
               ". Therefore, we fail to reject the null hypothesis."))
