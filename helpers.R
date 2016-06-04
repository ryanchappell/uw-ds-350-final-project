# project helpers
library(logging)
library(NLP)
library(tm)
library(RTextTools)

omitFields = c("preview.images",
               #secure_media is redundant for media
               "secure_media.type",
               "secure_media.oembed.url",
               "secure_media.oembed.provider_url",
               "secure_media.oembed.description",
               "secure_media.oembed.title",
               "secure_media.oembed.type",
               "secure_media.oembed.thumbnail_width",
               "secure_media.oembed.height",
               "secure_media.oembed.width",
               "secure_media.oembed.html",
               "secure_media.oembed.version",
               "secure_media.oembed.provider_name",
               "secure_media.oembed.thumbnail_url",
               "secure_media.oembed.thumbnail_height",
               "secure_media.oembed.author_name",
               "secure_media.oembed.author_url",
               "secure_media_embed.content",
               "secure_media_embed.width",
               "secure_media_embed.scrolling",
               "secure_media_embed.height",
               # otherwise not used
               "banned_by",
               "user_reports",
               "approved_by",
               "visited",
               "comments",
               "user_reports",
               "mod_reports")

readAllCsvFilesInDirectory = function(dir){
  result = NULL
  filesRead = 0
  for(file in list.files(dir)){
    filePath = paste0(dir, file)
    csvContents = read.csv(filePath)
    
    if (is.null(result)){
      result = csvContents
    } else {
      result = rbind.fill(result, csvContents)
    }
    filesRead = filesRead + 1
    loginfo(paste0("files read: ", filesRead, ", nrow: ", nrow(result)))
  }
  return(result)
}

# dir is the directory from which to read files
# maxToRead is the max number of files to read
# every acts as a skip mechanism (e.g. if every is 5, only every 5th file will be read, including the 1st file)
readFilesInDirectory = function(dir, maxToRead = 10, every = 0, beginTimestamp = -Inf, endTimestamp = Inf){
  result = NULL
  
  count = 0
  filesRead = 0
  for(file in list.files(dir)){
    if (every != 0 && count != 0 && count %% every != 0)
    {
      logdebug(paste0("skip, count: ", count, " filesRead: ", filesRead))
      count = count + 1
      next
    }
    
    timestamp = getTimestampFromFilename(file)
    
    if (timestamp <= beginTimestamp || timestamp >= endTimestamp){
      next
    }
  
    filePath = paste0(dir, file)
    #loginfo(paste0("reading ", dir, "/",file))
    jsonContents = fromJSON(txt=filePath, flatten = TRUE)
    
    # omit unused fields
    jsonContents = jsonContents[,!names(jsonContents) %in% omitFields]

    jsonContents = addTimestamp(jsonContents, timestamp)
    
    # assign to result (or add if result is not null)
    if (is.null(result)){
      result = jsonContents
    } else {
      #loginfo(paste0("rbind.fill"))
      result = rbind.fill(result, jsonContents)
    }
    
    filesRead = filesRead + 1
    count = count + 1
    
    if(filesRead %% 100 == 0){
      loginfo(paste0("########### processing file number ", filesRead,
                   " count is ", count))
    }
    
    if (filesRead >= maxToRead){
      return(result)
    }
  }
  
  return(result)
}

# dir is the directory from which to read timestamps from the filenames
readTimestampsFromFileNamesInDirectory = function(dir){
  result = NULL
  
  count = 0
  filesRead = 0
  for(file in list.files(dir)){
    logdebug(paste0("skip, count: ", count, " filesRead: ", filesRead))
    count = count + 1
    filesRead = filesRead + 1
    
    #if(filesRead %% 100 == 0){
    #  print(paste0("########### processing file number ", filesRead))
    #}
    
    filePath = paste0(dir, file)
    logdebug(paste0("reading ", dir, "/",file))
    timestamp = getTimestampFromFilename(file)
    logdebug(timestamp)
    # assign to result (or add if result is not null)
    if (is.null(result)){
      result = timestamp
    } else {
      result = c(result, timestamp)
    }
    logdebug(length(result))
  }
  return(result)
}

addTimestamp = function(data, timestamp){
  return(cbind(data, timestamp = rep(as.numeric(timestamp), size = nrow(data))))
}

addTimestamp_Test = function(){
  df <- data.frame(list(one = c(1:10), two = c(11:20)))
  
  result <- addTimestamp(df, '123456')
  
  stopifnot("timestamp" %in% names(result))
  stopifnot(result[,"timestamp"] == 123456)
}

getTimestampFromFilename = function(filename)
{
  result <- str_extract(filename, '[0-9]+')
  
  return(result)
}

getTimestampFromFilename_Test = function()
{
  filename <- 'hot-1462029844169.json'
  
  timestamp <- str_extract(filename, '[0-9]+')
  
  stopifnot(timestamp == '1462029844169')
}

getDateUtc = function(millisecondTimestamp){
  result = as.POSIXct(millisecondTimestamp / 1000, origin = "1970-01-01", tz = "GMT")
  return(result)
}

getDateUtc_Test = function(){
  
  timestamps = c(353039493345, 1462020944169)
  
  actual = getDateUtc(timestamps)
  
  stopifnot(actual[[1]] != "1981-03-10 02:31:33 GMT")
  stopifnot(actual[[2]] != "2016-04-30 12:55:44 GMT")
}

trimWhitespace = function(text){
  # remove leading and trailing whitespace, pulled from
  # http://stackoverflow.com/questions/2261079/how-to-trim-leading-and-trailing-whitespace-in-r
  result = gsub("^\\s+|\\s+$", "", text)
  return(result)
}

trimWhitespace_Test = function(){
  expected = "yup    okay"
  actual = trimWhitespace("   yup    okay   ")
  stopifnot(expected == actual)
}

cleanAndStemText = function(pageDf, customStops = c()){
  # Normalize Data:
  # Change to lower case:
  pageDf$title = tolower(pageDf$title)
  
  # Remove punctuation
  # Better to take care of the apostrophe first
  pageDf$title = sapply(pageDf$title, function(x) gsub("'", "", x))
  # Now the rest of the punctuation
  pageDf$title = sapply(pageDf$title, function(x) gsub("[[:punct:]]", " ", x))
  
  # Remove numbers
  pageDf$title = sapply(pageDf$title, function(x) gsub("\\d","",x))
  
  # Remove extra white space, so we can split words by spaces
  pageDf$title = sapply(pageDf$title, function(x) gsub("[ ]+"," ",x))
  
  # trim it (above gsub wil leave leading and trailing white space)
  pageDf$title = trimWhitespace(pageDf$title)
  
  # Remove non-ascii
  pageDf$title = iconv(pageDf$title, from="latin1", to="ASCII", sub="")
  
  # get stopwords to remove
  stopwords()
  my_stops = as.character(sapply(stopwords(), function(x) gsub("'","",x)))
  my_stops = c(my_stops, customStops)
  #loginfo(my_stops)
  
  # remove stop words
  pageDf$title = sapply(pageDf$title, function(x){
    paste(setdiff(strsplit(x," ")[[1]],my_stops),collapse=" ")
  })# Wait a minute for this to complete
  
  # Remove extra white space again:
  pageDf$title = sapply(pageDf$title, function(x) gsub("[ ]+"," ",x))
  
  # trim it (above gsub wil leave leading and trailing white space)
  pageDf$title = trimWhitespace(pageDf$title)
  
  # Stem words:
  pageDf$title_stem = sapply(pageDf$title, function(x){
    paste(setdiff(wordStem(strsplit(x," ")[[1]]),""),collapse=" ")
  })
  
  return(pageDf)
}

cleanAndStemText_Test = function(){
  dirty = data.frame(list(title = c("Myself? I enjoy Sound Brewery beer very much.",
                                     "I think Kool Keith is excellent, don't you?",
                                     "Some non-ascii    and other stuff こんにちわ 9000",
                                     "  Stops beer pour glass mug tulip snifter brewery")))
  
  expected = data.frame(list(title = c("enjoy sound much",
                                        "think kool keith excellent",
                                        "non ascii stuff",
                                        "stops"),
                             title_stem = c("enjoy sound much",
                                            "think kool keith excel",
                                            "non ascii stuff",
                                            "stop")))
  
  clean = cleanAndStemText(dirty, c("beer", "pour", "glass", "mug", "tulip", "snifter", "brewery"))
  
  stopifnot(expected == clean)
}

removeReviews = function(pageDf, minCharLength){
  # remove items shorter than minCharLength
  pageDf = pageDf[nchar(pageDf$title_stem) > minCharLength,]
  return(pageDf)
}

removeReviews_Test = function(){
  reviews = data.frame(list(title_stem = c("","short","notsoshort", "a bit longer",
                                           "a bit longer still")), stringsAsFactors = FALSE)
  
  actual = removeReviews(reviews, 0)
  stopifnot(nrow(actual) == 4)
  actual = removeReviews(reviews, 5)
  stopifnot(nrow(actual) == 3)
  actual = removeReviews(reviews, 10)
  stopifnot(nrow(actual) == 2)
  actual = removeReviews(reviews, 15)
  stopifnot(nrow(actual) == 1)
  actual = removeReviews(reviews, 20)
  stopifnot(nrow(actual) == 0)
}

createDTMatrix = function(pageData){
  loginfo("Creating review corpus")
  reviewCorpus = Corpus(VectorSource(pageData$title_stem))
  loginfo("Creating review DTM (this may take a while)")
  reviewDocTermMatrix = DocumentTermMatrix(reviewCorpus)
  
  initialMatSize = dim(reviewDocTermMatrix)
  
  loginfo(paste0("Initial matrix size: ", initialMatSize[1], " x " ,
                 initialMatSize[2], "; removing sparse terms"))
  reviewDocTermMatrix = removeSparseTerms(reviewDocTermMatrix, 0.995)
  
  finalMatSize = dim(reviewDocTermMatrix)
  
  loginfo(paste0("New matrix size: ", finalMatSize[1], " x " ,
                 finalMatSize[2]))
  
  # NOTE BE CAREFUL DOING THIS WITH LARGER DATA SETS!!!!!!
  loginfo("Converting DTM to matrix (this may take a while)")
  reviewTermMatrix = as.matrix(reviewDocTermMatrix)
  return(reviewTermMatrix)
}

getSubredditPercentages = function(data){
  subData <- data.frame(list(subreddit = data$subreddit, score = data$score, id = data$id, timestamp = data$timestamp))
  
  # convert to number for later use
  subData$timestamp <- as.numeric(subData$timestamp)
  
  # aggregate the subreddit count
  loginfo(paste0("Aggregating the count of each subreddit on the front page\r\n by sample date, this may take a while."))
  aggSub <- aggregate(subData$subreddit, by = list(subreddit = subData$subreddit, timestamp = subData$timestamp), FUN = function(count){
    #print('is.(x)')
    #Sys.sleep(0.5)
    return(length(count))
  })
  
  loginfo("Prepping data subreddit percentage on frontpage")
  # aggregate subreddit count by timestamp,
  # this will give us the sum count by subreddit over time
  aggSubTimeSum <- aggregate(aggSub$x, by = list(subreddit = aggSub$subreddit), FUN = sum)
  
  # sort by count descending
  aggSubTimeSum <- aggSubTimeSum[order(aggSubTimeSum$x),]
  
  # percent of each subreddit
  aggSubTimeSum$percent = aggSubTimeSum$x / sum(aggSubTimeSum$x)
  
  return(aggSubTimeSum)
}
