library("stringr")
library("rjson")
library("RMariaDB")

rm(list = ls())
setwd("~/")

#Handling args
#####################################################################################
inputFile = commandArgs(TRUE)
inputFile = c(inputFile[1], inputFile[2])
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
  output_to_script <- TRUE
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
MaxId <- dbGetQuery(con, "Select Max(discourse_id) from Discourse;")
MaxId <- abs(MaxId[[1,1]]) + 1
  
comment_data <- read.csv(inputFile[1], stringsAsFactors = FALSE)
post_data <- read.csv(inputFile[2], stringsAsFactors = FALSE)
post_data$numeric_id = MaxId + 1:nrow(post_data)

post_numeric_id = comment_data$post_id
for(i in 1:length(post_numeric_id)){
  current_id = post_numeric_id[i]
  for(z in 1:nrow(post_data)){
    if(post_data[[z, "id"]] == current_id){
      post_numeric_id[i] <- post_data[[z, "numeric_id"]]
    }
  }
}
comment_data$post_numeric_id <- post_numeric_id

data <- rbind(
  data.frame(discourse_id = "NULL", 
          content = comment_data$text,
          source_id = source_id,
          region = "King County",
          country_code = "USA",
          created_time = comment_data$created_time,
          imported_time = "NOW()",
          secondary_content = "NULL",
          isPost = 0,
          post_id = comment_data$post_numeric_id,
          ori_id = comment_data$id,
          url = paste0("reddit.com", comment_data$url),
          stringsAsFactors = FALSE),
  data.frame(discourse_id = "NULL", 
           content = post_data$text,
           source_id = source_id,
           region = "King County",
           country_code = "USA",
           created_time = post_data$created_time,
           imported_time = "NOW()",
           secondary_content = "NULL",
           isPost = 1,
           post_id = post_data$numeric_id,
           ori_id = post_data$id,
           url = paste0("reddit.com",post_data$url),
           stringsAsFactors = FALSE),
  stringsAsFactors = FALSE
)
print("querying into DB. . . ")
createSQLInserts("Discourse", data)

post_IDs <- unique(data$post_id)
post_IDs <- post_IDs[!is.na(post_IDs)]

print("fixing post_ids. . .")
for(id in post_IDs){
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
dbDisconnect(con)
print("done!")