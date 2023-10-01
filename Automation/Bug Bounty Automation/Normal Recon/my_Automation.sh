#!/bin/bash

# Function to perform scans for a domain
perform_scans() {
  local DOMAIN="$1"

  # Step 1: Subfinder
  echo "Starting subfinder scan for $DOMAIN..."
  subfinder -d $DOMAIN -all | httpx -mc 200 | tee subfinder.txt
  echo "<---------------------------------------------Subfinder completed---------------------------------------------->"

  # Step 2: Waybackurls
  echo "Starting waybackurls scan..."
  cat subfinder.txt | waybackurls | httpx -mc 200 | tee waybackurls.txt
  echo "<---------------------------------------------Waybackurls completed---------------------------------------------->"

  # Step 3: gau
  echo "Starting gau scan..."
  cat subfinder.txt | gau --providers wayback,commoncrawl,otx,urlscan | tee gauurls.txt
  echo "<---------------------------------------------Gau completed---------------------------------------------->"

  # Step 4: Hakrawler
  echo "Starting hakrawler scan..."
  cat subfinder.txt | hakrawler -t 1 -d 3 | tee crawl.txt
  echo "<---------------------------------------------Hakrawler completed---------------------------------------------->"
  
  # Step 5: Merge URLs
  echo "Merging URLs..."
  cat gauurls.txt waybackurls.txt crawl.txt | anew finalurls.txt
  echo "<---------------------------------------------Finalurls completed---------------------------------------------->"

  # Step 6: JS URLs
  echo "Extracting JS URLs..."
  cat finalurls.txt | grep ".js$" | tee JSurls.txt
  echo "<---------------------------------------------JSurls completed---------------------------------------------->"
  
  # Step 7: XML URLs
  echo "Extracting XML URLs..."
  cat finalurls.txt | grep ".xml$" | tee XMLurls.txt
  echo "<---------------------------------------------XMLurls completed---------------------------------------------->"
  
  # Step 8: Search for Keywords
  echo "Searching for keywords..."
  for keyword in "mail.com" "token" "config." "access_token" "url=" "redirect_url=" "/api" "api" "id=" "accessUrl=" "payment" "apikey" "api_key" "accesskey" "access" "token" "secret" "data" "eyJ" "config" ".json" ".js" "admin" "prod" "oauth" "username" "password" "xml" "bak" ".zip" "uri" "php" ".tar"; do
    grep -q "$keyword" finalurls.txt && grep "$keyword" finalurls.txt > keywords.txt
  done
  echo "<---------------------------------------------Keywords scan completed---------------------------------------------->"

  # Step 9: Uncover
  echo "Starting uncover scan..."
  uncover -q "$DOMAIN" -e censys,fofa,shodan,shodan-idb | httpx | tee ips.txt
  echo "<---------------------------------------------Uncover completed---------------------------------------------->"

  # Step 10: GF SSRF
  echo "Starting GF SSRF scan..."
  sudo gf ssrf finalurls.txt | grep -E "(http|https)://.*" | qsreplace "=" | xargs -I % sh -c 'curl -s "%" | grep -q "<h1>TESTSSRF</h1>" && echo "%" >> vulnSSRF.txt'
  echo "<---------------------------------------------GF SSRF completed---------------------------------------------->"

  # Step 11: GF XSS
  echo "Starting GF XSS scan..."
  sudo gf xss finalurls.txt | grep -E "(http|https)://.*" | qsreplace "=" | xargs -I % sh -c 'curl -s "%" | grep -q "<h1>TESTXSS</h1>" && echo "%" >> vulnXSS.txt'
  echo "<---------------------------------------------GF XSS completed---------------------------------------------->"

  # Step 12: Nuclei on Subdomains
  echo "Starting nuclei on subdomains scan..."
  cat subfinder.txt | nuclei -s low,medium,high | tee subNuclei.txt
  echo "<---------------------------------------------Nuclei on subdomains completed---------------------------------------------->"

  # Step 13: Nuclei on IPs
  echo "Starting nuclei on IPs scan..."
  cat ips.txt | nuclei -s low,medium,high | tee ipsNuclei.txt
  echo "<---------------------------------------------Nuclei on IPs completed---------------------------------------------->"

  # Step 13: httpx 
  echo "Starting httpx scan..."
  cat subfinder.txt | httpx -cname -ct -sc -server | tee httpx.txt
  echo "<---------------------------------------------httpx completed---------------------------------------------->"

  # Send completion message to Slack
  echo "Scans for domain $DOMAIN are completed." | slackcat -u https://hooks.slack.com/services/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

  echo "<---------------------------------------------------DONE--------------------------------------------------------->"
}

# Check if the domain name or file is provided as a parameter
if [ $# -ne 1 ]; then
  echo "Usage: $0 <domain_name_or_file>"
  exit 1
fi

# Check if the parameter is a file
if [ -f "$1" ]; then
  # If it's a file, read the domain names from the file
  echo "Reading domain names from file..."
  while read -r line; do
    perform_scans "$line"
  done < "$1"
else
  # If it's not a file, assume it's a single domain name
  perform_scans "$1"
fi

# Combine all scan results into a single file
cat subfinder.txt >> all.txt
echo "<---------------------------------------------Subfinder completed---------------------------------------------->" >> all.txt
cat waybackurls.txt >> all.txt
echo "<---------------------------------------------waybackurls completed---------------------------------------------->" >> all.txt
cat gauurls.txt >> all.txt
echo "<---------------------------------------------gauurls completed---------------------------------------------->" >> all.txt
cat crawl.txt >> all.txt
echo "<---------------------------------------------crawl completed---------------------------------------------->" >> all.txt
cat finalurls.txt >> all.txt
echo "<---------------------------------------------finalurls completed---------------------------------------------->" >> all.txt
cat JSurls.txt >> all.txt
echo "<---------------------------------------------JSurls completed---------------------------------------------->" >> all.txt
cat XMLurls.txt >> all.txt
echo "<---------------------------------------------XMLurls completed---------------------------------------------->" >> all.txt
cat keywords.txt >> all.txt
echo "<---------------------------------------------keywords completed---------------------------------------------->" >> all.txt
cat ips.txt >> all.txt
echo "<---------------------------------------------ips completed---------------------------------------------->" >> all.txt
cat vulnSSRF.txt >> all.txt
echo "<---------------------------------------------vulnSSRF completed---------------------------------------------->" >> all.txt
cat vulnXSS.txt >> all.txt
echo "<---------------------------------------------vulnXSS completed---------------------------------------------->" >> all.txt
cat subNuclei.txt >> all.txt
echo "<---------------------------------------------subNuclei completed---------------------------------------------->" >> all.txt
cat ipsNuclei.txt >> all.txt
echo "<---------------------------------------------ipsNuclei completed---------------------------------------------->" >> all.txt
cat httpx.txt >> all.txt
echo "<---------------------------------------------httpx completed---------------------------------------------->" >> all.txt

# Send the combined results to Slack
cat all.txt | slackcat -u your_SlackCat_Webhook_URL
