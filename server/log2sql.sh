#!/bin/bash
cat logs/production.log | awk -F\" '{OFS="\"";for(i=2;i<NF;i+=2)gsub(/ /,"@",$i);print}' | awk '$9 ~ /log-on|log-off/'| sort -k7n -s | sed '/log-on/ {N;/\n.*log-on/D;}' | sed '/log-off/ {N;/\n.*log-off/D;}' | paste - - -d" " | awk '{ print "\""$2,$3"\"", "\""$2,$16"\"",$6,$7,$8,$10,$11,$12}' | awk -F\" '{OFS="\"";for(i=2;i<NF;i+=2)gsub(/ /,"@",$i);print}' | sed  's/\s\+/,/g' | tr @ " " | sed s/\"//g > temp.csv
comm -13 <(sort logs/stats/2013.csv) <(sort temp.csv) > logs/stats/insert.csv
sqlite3 logs/stats/stats.db < logs/stats/import.sql
cat logs/stats/insert.csv >> logs/stats/2013.csv
rm temp.csv
