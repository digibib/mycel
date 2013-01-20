#!/bin/bash
cat logs/production.log | awk -F\" '{OFS="\"";for(i=2;i<NF;i+=2)gsub(/ /,"@",$i);print}' | awk '$9 ~ /log-on|log-off/'| sort -k7n -s | sed '/log-on/ {N;/\n.*log-on/D;}' | sed '/log-off/ {N;/\n.*log-off/D;}' | paste - - -d" " | awk '{ print "\""$2,$3"\"", "\""$2,$16"\"",$6,$7,$8,$10,$11,$12,$13}' | awk -F\" '{OFS="\"";for(i=2;i<NF;i+=2)gsub(/ /,"@",$i);print}' | sed  's/\s\+/,/g' | tr @ " " >> logs/stats/2013.csv
cat logs/stats/2013.csv | (read -r; printf "%s\n" "$REPLY"; sort -u) > logs/stats/2013_.csv
mv logs/stats/2013_.csv logs/stats/2013.csv
