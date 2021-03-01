library("stringr")
library("rjson")
library("RMariaDB")
library("plyr")
rm(list = ls())
setwd("~/")

#Handling args
#####################################################################################
inputFile = commandArgs(TRUE)
if(is.na(inputFile) || length(inputFile) == 0)
  inputFile <- "data/sentiments.csv"
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
  output_to_script <- FALSE;
  
  #print(deparse(substitute(table_name)))
  if(file.exists(paste0("script_output/", table_name, ".sql")))
    unlink(paste0("script_output/", table_name, ".sql"))
  if(file.exists(paste0("script_output/",table_name, ".csv")))
    unlink(paste0("script_output/",table_name, ".csv"))
  for(a in 1:nrow(df)){
    row <- df[a, ]
    for(b in 1:ncol(row)){
      if(is.na(row[[b]]))
        row[[b]] <- "NULL"
      if(typeof(row[[b]]) == "character" && row[[b]]!="NOW()" && row[[b]]!="NULL"){
        row[[b]] <- str_replace_all(row[[b]], "\\\\\\\\", "")
        row[[b]] <- str_replace_all(row[[b]], "\\\\\'", "\'")
        row[[b]] <- str_replace_all(row[[b]], "\'", "\'\'")
        row[[b]] <- paste0("\'", row[[b]], "\'")
      }
    }
    df[a, ] <- row
    col_names <- colnames(row)
    elements <- ""
    for(name in col_names){
      elements <- paste0(elements, row[[name]], ", ")
    }
    elements<- substr(elements, 1, nchar(elements)-2)
    insert_statement = paste0("INSERT INTO ", table_name, 
                              " VALUES (",elements, ");")
    print(paste("Completing query ", a))
    if(!output_to_script){
      dbExecute(con, insert_statement)
    } else{
      write(insert_statement, 
            file = paste0("script_output/",table_name, ".sql"), append = TRUE)
    }
  }
  #return(df)
  write.csv(df, paste0("script_output/",table_name, ".csv"))
}
#####################################################################################
sentiment <- read.csv(inputFile, stringsAsFactors = FALSE)
IDMap <- dbGetQuery(con, "Select discourse_id, ori_id as id from Discourse;")
DiscourseSentiment <- join(x = IDMap, y = sentiment, by="id", type = "inner")
DiscourseSentiment$id <- NULL;
sentiment <- c()
for(i in 1:nrow(DiscourseSentiment)) {
  values <- c(DiscourseSentiment[[i, "pos"]], DiscourseSentiment[[i, "neu"]], 
              DiscourseSentiment[[i, "neg"]])
  new_value <- 2 - (which.max(values))
  sentiment <- c(sentiment, new_value)
}
DiscourseSentiment <- data.frame(discourse_id = DiscourseSentiment$discourse_id,
                                 sentiment, positive_prob = DiscourseSentiment$pos,
                                 netural_prob = DiscourseSentiment$neu,
                                 negative_prob = DiscourseSentiment$neg,
                                 model_id = 2, stringsAsFactors = FALSE)
 createSQLInserts("DiscourseSentiment", DiscourseSentiment)
# dbDisconnect(con)
# print("done!")
