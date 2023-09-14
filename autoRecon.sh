#!/bin/bash

# Prompt the user for the full path to the domains.txt file
read -p "Enter the full path to domains.txt file: " domains_file

# Prompt the user for a custom message for the notification
read -p "Enter Message to Notify: " msg

# Check if the file exists
if [ ! -f "$domains_file" ]; then
  echo "Error: $domains_file not found."
  exit 1
fi

# Run subfinder and save the output to subfinder.txt
subfinder -dL "$domains_file" -all | tee subfinder.txt

# Run assetfinder and save the output to asset.txt
cat "$domains_file" | assetfinder -subs-only > asset.txt

# Run amass and save the output to amass.txt
amass enum -passive -norecursive -noalts -df "$domains_file" -o amass.txt

# Combine the results into all-subs.txt
cat amass.txt asset.txt subfinder.txt | anew all-subs.txt

# Use httpx to check for live subdomains and save the output to live.txt
cat all-subs.txt | httpx -o live.txt

# Use waybackurls and httpx to fetch URLs from Wayback Machine and filter by status code 200 and content-type
cat live.txt | waybackurls | httpx -mc 200 -ct | tee 200waybackwithCT.txt

# Use httpx to check for status code, content-length, location, and title
cat live.txt | httpx -sc -cl -location -title | tee httpx1.txt

# Use hakrawler to crawl for JavaScript files and save the output to hakcrawlforJS.txt
cat live.txt | hak -t 1 -u -d 3 | tee hakcrawlforJS.txt

# Use getallurls to fetch URLs and exclude certain file types, then save the result to gauresult.txt
cat live.txt | getau --blacklist png,jpg,jpeg,img,svg,mp3,mp4,eot,css | tee gauresult.txt

# Use httpx to collect detailed information about the URLs, including status code, server, IP, and more, and save the result to httpx.json
cat gauresult.txt | httpx -sc -td -server -ip -cname -json -o httpx.json -mc 200 -x POST GET TRACE OPTIONS

# Run nuclei on live.txt and save the output to nucleiLive
nuclei -l live.txt | tee nucleiLive

# Send a notification when the script is completed
echo "$msg" | notify