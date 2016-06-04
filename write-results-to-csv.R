library(jsonlite)
library(logging)
library(plyr)
library(stringr)

source('helpers.R')

# log settings
#basicConfig("DEBUG")
basicConfig("INFO")
addHandler(writeToFile, file = "project.log")

loginfo("Starting up!")

loginfo("Running unit tests")
getTimestampFromFilename_Test()
addTimestamp_Test()

# directory to read reddit results from 
readFromDir = 'C:/Program Files (x86)/Jenkins/workspace/reddit new page/results/'
readFromDir = 'C:/Program Files (x86)/Jenkins/workspace/reddit front page/results/'

maxFileBatchSize = 250
beginTimestamp = 1462110365184

# reads JSON results from Reddit API and writes them to csv files (each loop is a batch of 
# JSON files converted to one csv file)
while(TRUE)
{
  loginfo(paste0("start reading ", maxFileBatchSize, " files from timestamp ", beginTimestamp))
  all <- readFilesInDirectory(readFromDir, maxToRead = maxFileBatchSize, every = 5, beginTimestamp = beginTimestamp)
  loginfo("end read")   
  
  maxTimestamp = max(all$timestamp)
  #writeFile = paste0("C:/reddit-csv/front every 30/hot-", min(all$timestamp),"-", maxTimestamp,".csv")
  writeFile = paste0("C:/reddit-csv/front every 5/hot-", min(all$timestamp),"-", maxTimestamp,".csv")
  write.csv(all, file = writeFile)
  
  totalProcessed = length(unique(all$timestamp))
  print(paste0("total files processed ", totalProcessed))
  
  if (totalProcessed < maxFileBatchSize){
    break
  }
  
  beginTimestamp = maxTimestamp
}

