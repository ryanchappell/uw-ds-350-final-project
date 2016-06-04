# NLP
library(jsonlite)
library(logging)
library(plyr)
library(pryr)
library(stringr)
library(data.table)
library(openNLP)
library(openNLPdata)
library(tm)
library(RTextTools)
library(e1071)
library(caret)

source('helpers.R')

loginfo("Starting up!")

loginfo("Running unit tests")
getDateUtc_Test()
getTimestampFromFilename_Test()
addTimestamp_Test()
removeReviews_Test()
cleanAndStemText_Test()
removeReviews_Test()

if (interactive()) {
  # log settings
  #basicConfig("DEBUG")
  basicConfig("INFO")
  addHandler(writeToFile, file = "predict-new-to-front-with-nlp.log")
  
  loginfo("Starting up!")
  loginfo("Running unit tests")
  getTimestampFromFilename_Test()
  addTimestamp_Test()
  
  # directory to read reddit results from 
  npDir = 'C:/reddit-csv/new every 30/'
  fpDir = 'C:/reddit-csv/front every 30/'
  
  # read entries
  loginfo("start read npData")
  npData <- readAllCsvFilesInDirectory(npDir)
  loginfo("start read fpData")
  fpData <- readAllCsvFilesInDirectory(fpDir)

  # convert to dt
  fpData <- data.table(fpData)
  npData <- data.table(npData)
  
  setkey(fpData,id)
  setkey(npData,id)
  
  loginfo("Cleaning and stemming posts (this may take a while)")
  npData = cleanAndStemText(npData)

  # get unique posts. it looks like the unique method
  # will use the setkey id to determine uniqueness. the variable values
  # here (e.g. upvotes, score) can be ignored for the purposes of getting unique posts
  npData <- unique(npData)

  loginfo(paste0("Unique new page posts ", nrow(npData)))
  
  npMatrix = createDTMatrix(npData)
  
  # Look at frequencies of words across all documents
  #word_freq = sort(colSums(npMatrix))
  
  # Most common:
  #tail(word_freq, n=20)
  
  # add front page indicator
  # Least Common:
  #head(word_freq, n=20)
  
  npTermDt = data.table(npMatrix)

  
  loginfo("Get front page and new page id intersection")
  fpNpIntersection <- intersect(fpData$id, npData$id)

  npPost <- npData[paste(fpNpIntersection),]
  fpPost <- fpData[paste(fpNpIntersection),]
  
  npTermDt$front_indicator = npData$id %in% fpNpIntersection
  
  # add other factors
  npTermDt$is_self = npData$is_self
  npTermDt$has_thumbnail = npData$thumbnail != ""
  npTermDt$media_type = sapply(npData$media.type, FUN = function(x){
    if (is.na(x))
    {
      return("none")
    } else {
      return(x)
    }
  })
  npTermDt$subreddit = npData$subreddit
  npTermDt$over_18 = npData$over_18
  npTermDt$hour = format(as.POSIXct(npData[,created_utc], origin = "1970-01-01"), "%H")
  
  npTermDt = as.data.table(lapply(npTermDt, as.factor))
    
  totalNp = nrow(npTermDt)
  totalIntersection = nrow(npTermDt[front_indicator == TRUE,])
  
  loginfo(paste0("Total new page entries: ", totalNp))
  loginfo(paste0("Total new page entries that made it to the front page: ", totalIntersection))
  
  # Split into train/test set
  train_ind = sample(1:nrow(npTermDt), round(0.8*nrow(npTermDt)))
  train_set = npTermDt[train_ind,]
  test_set = npTermDt[-train_ind,]
  
  # Compute Naive Bayes Model
  reviewStyleNb = naiveBayes(as.factor(front_indicator) ~ ., data = train_set)
  loginfo("Creating predictions (this may take a while)")
  reviewStylePredictions = predict(reviewStyleNb, newdata = test_set, type="class")
  
  # THE PERFORMANCE OF THIS IS HORRIBLE. :(
  confMat = confusionMatrix(reviewStylePredictions, as.factor(test_set$front_indicator))
  loginfo("Plotting confusion matrix using fourfoldplot")
  fourfoldplot(confMat$table, color = c("#CC6666", "#99CC99"), conf.level = 0, std = "all.max",
               main = paste0("Confusion matrix for predictions of new page to front page"))
}
