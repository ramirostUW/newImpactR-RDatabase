# NewImpact Database Documentation and Scripting
This repository contains all the contributions that I (Ramiro Steinmann Petrasso) made towards NewImpact's Community Insights Project. Most of these contributions were made between February nd July of 2020, during which I worked on this project through a for-credit UW research position and met weekly with the other people working on the project. The code for the Community Insights website can be found [here](https://github.com/winwinwiki/CommunityInsights). If you have any questions, please email me at ramirost@live.com

## Database Documentation
The database_documentation.md file explains every aspect of the database created for the project. We all designed the schema together at the very beginning of the project, and tweaked it as the project continued. That file also contains all of the internal SQL queries used by GraphQL (which the frontend uses through Aurora) to pull data from the database.

## Scraper Scripts
These scripts, written in R, take in data from the scrapers we used to get data for social media services, formats it into the required format for the database schema, and inserts the data into the database. They are designed to be used from the terminal, and run daily, and take in paths to data in the format that each scraper uses (in either json or csv files). The correct syntax for the command is 
`Rscript [absolute path to script] [absolute path to first .json or .csv file] [absolute path to optional second .json or .csv file]`
Sample files for testing these scripts are available upon request.

## AI Data Scripts
These scripts take in data outputted by the AI models used to analyze the social media data and idenfity attributes that evaluate what each social media comment is expressing and which topic(s) it addresses. Generally, after each scraper runs and the scripts that upload the scrapers' data are executed, the AI models will evaluate the new data and, finally, these AI Data scripts will insert the models' output into the database as well. Similar to the Scraper scripts, these are meant to be run from the command line and the syntax for doing so is: 
`Rscript [absolute path to script] [absolute path to first .json or .csv file]`
(Note that these only take in one file containing the appropriate data at a time). Sample files for testing these scripts are available upon request.