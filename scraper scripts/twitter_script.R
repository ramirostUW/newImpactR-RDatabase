library("stringr")
library("rjson")
library("RMariaDB")
library("plyr")

rm(list = ls())
setwd("~/pipeline")

#Handling args
#####################################################################################
inputFile = commandArgs(TRUE)
if(is.na(inputFile) || length(inputFile) == 0)
  inputFile <- c("data/11_comments.json", "data/11_posts.json")
source_id = str_split(basename(inputFile[1]), fixed("_"))[[1]][1]

#####################################################################################

#Connecting to SQL
#####################################################################################
#The values of the variables identifying the database location have been removed.
con <- dbConnect(MariaDB(),
                 user = "user",
                 password="pass",
                 dbname="dbname",
                 host = "XX.XXX.XXX.XX",
                 port = 3306)
#####################################################################################

#Helper functions
#####################################################################################

makeInt <- function(df, name_of_col)
{
  col = df[[name_of_col]]
  newcol <- vector()
  for(b in 1:length(col)){
    if(col[b] == "	#N/A"){
      newcol <- append(newcol, NULL)
    }
    else
    {
      newcol <- append(newcol, as.integer(col[[b]]))
    }
    
  }
  df[[name_of_col]] <- newcol
  return(df)
  
}

createSQLInserts <- function(table_name, df){
  #If output_to_script is true, the script will output insert statements to a
  #.sql file instead of inserting to the database itself. This was mostly used 
  #at the beginning of the project, when I did not yet have database credentials,
  #and also to test the scripts as they were updated.
  output_to_script <- FALSE
  dir.create("script_output", showWarnings = FALSE)
  if(file.exists(paste0("script_output/", table_name, ".sql")))
    unlink(paste0("script_output/", table_name, ".sql"))
  queries <- paste0("INSERT INTO ", table_name, " VALUES (")
  for(column in 1:ncol(df)){
    colVector <- df[,column]
    if(typeof(colVector) == "character"){
      colVector <- str_replace_all(colVector, "\\\\\\\\", "")
      colVector <- str_replace_all(colVector, "\\\\\'", "\'")
      colVector <- str_replace_all(colVector, "\'", "\'\'")
      for(i in 1:length(colVector)){
        element <- colVector[i]
        if(!(element %in% c("NULL", "NOW()")))
          colVector[i] <- paste0("'", element, "'")
      }
    }
    if(column!=length(df))
      colVector <- paste0(colVector, ", ")
    queries <- paste0(queries, colVector)
  }
  queries <- paste0(queries, ");")
  if(output_to_script){
    write(queries, 
          file = paste0("script_output/",table_name, ".sql"), append = TRUE)
  } 
  else{
    for(query in queries)
      dbExecute(con, query)
  }
}
#####################################################################################

#Json Processing functions
#####################################################################################
createHashtagsTable <- function(data){
  df <- data.frame(ori_id = c("blank"), hashtag = c("blank"),
                   stringsAsFactors = FALSE)
  currentRow <- 1
  for(tweet in data){
    hashtags <- tweet[["hashtags"]]
    if(length(hashtags) > 0){
      for(hashtag in hashtags){
        if(typeof(hashtag) == "list")
          hashtag <- hashtag[["text"]]
        df[[currentRow, "ori_id"]] <- tweet[["tweet_id"]]
        df[[currentRow, "hashtag"]] <- hashtag
        currentRow <- currentRow + 1
      }
    }
  }
  return(df)
}
createDiscourseTable <- function(data){
  discourse_id <- c()
  content <- c()
  source_id_column <- c()
  region <- c()
  country_code <- c()
  created_time <- c()
  imported_time <- c()
  secondary_content <- c()
  isPost <- c()
  post_id <- c()
  ori_id <- c()
  url <- c()
  for(tweet in data) {
    discourse_id <- c(discourse_id, "NULL")
    content <-c(content, tweet[["text"]])
    source_id_column <- c(source_id_column, source_id)
    region <- c(region, "King County")
    country_code <- c(country_code, 1)
    created_time <- c(created_time, paste(substr(tweet[["timestamp"]], 1, 10),
                                          substr(tweet[["timestamp"]], 12,19)))
    imported_time <- c(imported_time, "NOW()")
    secondary_content <- c(secondary_content, "NULL")
    isPost <- c(isPost, !(tweet[["is_reply_to"]]))
    postIdvar <- tweet[["parent_tweet_id"]]
    if(is.null(postIdvar) || postIdvar == ""){
      postIdvar <- "NULL"
    }
    post_id <- c(post_id, postIdvar)
    ori_id <-c(ori_id, tweet[["tweet_id"]])
    url <- c (url, paste0("twitter.com", tweet[["tweet_url"]]))
  }
  df <- data.frame(discourse_id, content, source_id = source_id_column, region, country_code, 
                   created_time, imported_time, secondary_content, isPost, post_id,
                   ori_id, url, stringsAsFactors = FALSE)
  return(df)
}
#####################################################################################

#Dataframe Functions
#####################################################################################
fixParentsThatAreComments <- function(df){
  parentIDs <- df$post_id[df$post_id != "NULL"]
  foundCommentParent <- TRUE
  while(foundCommentParent) {
    foundCommentParent <- FALSE
    for(parent in parentIDs){
      postRow <- match(parent, df$ori_id)
      if(!is.na(postRow) && !df[[postRow, "isPost"]]) {
        foundCommentParent <- TRUE
        trueParent <- df[[postRow, "post_id"]]
        matchingRows <- which(df$post_id == parent)
        for(row in matchingRows)
          df[[row, "post_id"]] <- trueParent
      }
    }
    parentIDs <- df$post_id[df$post_id != "NULL"]
  }
  return(df)
}
#####################################################################################


MaxId <- dbGetQuery(con, "Select Max(discourse_id) from Discourse;")
MaxId <- abs(MaxId[[1,1]]) + 1
print("Processing data. . . ")
comment <- fromJSON(file = inputFile[1])
discourse <- createDiscourseTable(comment)


if(length(inputFile) != 1) {
  post <- fromJSON(file = inputFile[2])
  discourse <- rbind(createDiscourseTable(post), discourse, 
                   stringsAsFactors = FALSE)
}

discourse <- fixParentsThatAreComments(discourse)

discourse$rowvar <- (1:nrow(discourse)) + MaxId
db_discourse_ids <- dbGetQuery(con, "Select discourse_id from Discourse;")$discourse_id

commentsWithoutParents <- c()
posts_already_in_db <- c()
for(i in 1:nrow(discourse)){
  if(!discourse[[i, "isPost"]]){
    if(discourse[[i, "post_id"]] %in% discourse$ori_id){
      postRow <- match(paste0(discourse[[i, "post_id"]]), discourse$ori_id)
      discourse[[i, "post_id"]] <- discourse[[postRow, "rowvar"]]
    }
    else{
      if(discourse[[i, "post_id"]] %in% db_discourse_ids) {
        posts_already_in_db <- c(posts_already_in_db, discourse[[i, "post_id"]])
      }
      else {
        commentsWithoutParents <- c(commentsWithoutParents, i)
      }
    }
  }
}

if(!is.null(commentsWithoutParents))
  discourse <- discourse[-commentsWithoutParents, ]

parent_posts <- unique(discourse$post_id[discourse$post_id != "NULL" &&
                      !(discourse$post_id %in% db_discourse_ids)])
for(pseudo_id in parent_posts)
{
  rownum <- match(pseudo_id, discourse$rowvar)
  discourse[[rownum, "post_id"]] <- discourse[[rownum, "rowvar"]]
}

discourse$rowvar <- NULL

print("Uploading to database. . . ")
createSQLInserts("Discourse", discourse)

print("fixing post_ids. . .")
for(id in parent_posts){
  discourses <- dbGetQuery(con, paste0("Select * from Discourse
                                       WHERE post_id = ", id, ";"))
  post <- NULL
  post <- dbGetQuery(con, paste0("Select discourse_id from Discourse
                                       WHERE post_id = ", id, " AND isPost = TRUE;"))
  if(!is.null(post) && nrow(post) != 0){
    post <- post[[1,1]]
    query <- paste0("UPDATE Discourse SET post_id = ", post,
                    " WHERE post_id = ", id, " AND isPost = FALSE;")
    value <- dbExecute(con, query)
    dbExecute(con, paste0("UPDATE Discourse SET post_id = NULL",
                          " WHERE post_id = ", id, " AND isPost = TRUE"))
    
    
  }
}
print("Processing Hashtags. . . ")
DiscourseHashtags <- createHashtagsTable(comment)
if(length(inputFile) != 1) {
  postHashtags <- createHashtagsTable(post)
  DiscourseHashtags <- rbind(DiscourseHashtags, postHashtags)
}
IDMap <- dbGetQuery(con, "Select discourse_id, ori_id from Discourse;")
DiscourseHashtags <- join(x = IDMap, y = DiscourseHashtags, by="ori_id", type = "inner")
DiscourseHashtags$ori_id = NULL
 if(!is.na(DiscourseHashtags) && nrow(DiscourseHashtags) > 0)
   createSQLInserts("DiscourseHashtags", unique(DiscourseHashtags))
dbDisconnect(con)
print("done!")
