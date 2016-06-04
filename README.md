# UW Data Science 350 final project

For my final project, I decided grab Reddit post data from the front page and on the new page and analyze the results.

## Project Write-up
Ryan-Chappell-UW-DS-350-Data-Analysis-project.pdf

## Analysis R Files
- aww-hypothesis.R
- predict-new-to-front-with-nlp.R
- how-long-on-front-page-pcaic.R

These are the files used to analyze the data in the write-up. They can be run by updating the setwd() and data directory(ies) in code to your environment path(s).

## Supporting R Files
- helpers.R

These are utilities used by analysis files.

## Data Files
- data.zip

This zip contains 4 csv files (two for front page and two for 30 page results). It is 135MB uncompressed (a slice of the original ~26GB data set). Unzipped, the folder structure looks like:

  - data/front every 30/*.csv
  - data/new every 30/*.csv

## Example Analysis Log Files
example-logs/*.log

For reference; these are example log files emitted from each analysis file. They also give an idea of how long each script will run.



## Other
- write-results-to-csv.R

This file was used during data retrieval to convert original JSON data to CSV.

# Node Data Retriever

The Node app that pulled the Reddit data can be found here:
https://github.com/ryanchappell/uw-ds-350-reddit-retriever
