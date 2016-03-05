#!/bin/sh

#this code is tested un fresh 2015-11-21-raspbian-jessie-lite Raspberry Pi image
#by default this script should be located in two subdirecotries under the home

#sudo apt-get update -y && sudo apt-get upgrade -y
#sudo apt-get install git -y
#mkdir -p /home/pi/detect && cd /home/pi/detect
#git clone https://github.com/catonrug/picasa-detect.git && cd picasa-detect && chmod +x check.sh && ./check.sh

#check if script is located in /home direcotry
pwd | grep "^/home/" > /dev/null
if [ $? -ne 0 ]; then
  echo script must be located in /home direcotry
  return
fi

#it is highly recommended to place this directory in another directory
deep=$(pwd | sed "s/\//\n/g" | grep -v "^$" | wc -l)
if [ $deep -lt 4 ]; then
  echo please place this script in deeper directory
  return
fi

#set application name based on directory name
#this will be used for future temp directory, database name, google upload config, archiving
appname=$(pwd | sed "s/^.*\///g")

#set temp directory in variable based on application name
tmp=$(echo ../tmp/$appname)

#create temp directory
if [ ! -d "$tmp" ]; then
  mkdir -p "$tmp"
fi

#check if database directory has prepared 
if [ ! -d "../db" ]; then
  mkdir -p "../db"
fi

#set database variable
db=$(echo ../db/$appname.db)

#if database file do not exist then create one
if [ ! -f "$db" ]; then
  touch "$db"
fi

#check if google drive config directory has been made
#if the config file exists then use it to upload file in google drive
#if no config file is in the directory there no upload will happen
if [ ! -d "../gd" ]; then
  mkdir -p "../gd"
fi

#set name
name=$(echo "Picasa")

#set home page
home=$(echo "https://picasa.google.com/")

changes=$(echo "https://support.google.com/picasa/answer/53209?hl=en")

#download home page to check if it is alive
wget -S --spider -o $tmp/output.log "$home"

grep -A99 "^Resolving" $tmp/output.log | grep "HTTP.*200 OK"
if [ $? -eq 0 ]; then
#if file request retrieve http code 200 this means OK

#search for picasa installer
url=$(wget -qO- "$home" | sed "s/\d034/\n/g" | grep exe)
echo "$url" | grep "http.*picasa.*exe$"
if [ $? -eq 0 ]; then
echo

#download all info about installer link
wget -S --spider -o $tmp/output.log "$url"

grep -A99 "^Resolving" $tmp/output.log | grep "Last-Modified" 
if [ $? -eq 0 ]; then
#if there is such thing as Last-Modified
echo

lastmodified=$(grep -A99 "^Resolving" $tmp/output.log | grep "Last-Modified" | sed "s/^.*: //")

#check if this last modified file name is in database
grep "$lastmodified" $db > /dev/null
if [ $? -ne 0 ]; then

echo new $name version detected!
echo

#calculate filename
filename=$(echo $url | sed "s/^.*\///g")

#download file
echo Downloading $filename
wget $url -O $tmp/$filename -q

#check downloded file size if it is fair enought
size=$(du -b $tmp/$filename | sed "s/\s.*$//g")
if [ $size -gt 2048000 ]; then

echo creating md5 checksum of file..
md5=$(md5sum $tmp/$filename | sed "s/\s.*//g")
echo

echo creating sha1 checksum of file..
sha1=$(sha1sum $tmp/$filename | sed "s/\s.*//g")
echo

echo detect exact verison of $name
version=$(pestr $tmp/$filename | grep -m1 -A1 "ProductVersion" | grep -v "ProductVersion" | sed "s/\.[0-9]\+//3")
echo $version | grep "^[0-9]\+[\., ]\+[0-9]\+[\., ]\+[0-9]\+"
if [ $? -eq 0 ]; then
echo

echo looking for change log..
wget -qO- "$changes" | grep -A99 -m1 "$version" | grep -B99 -m2 "</strong>" | grep -v "<strong>" | sed -e "s/<[^>]*>//g" | sed "s/^[ \t]*//g" | grep -v "^$" | sed "s/^/- /"  > $tmp/change.log

#check if even something has been created
if [ -f $tmp/change.log ]; then

#calculate how many lines log file contains
lines=$(cat $tmp/change.log | wc -l)
if [ $lines -gt 0 ]; then
echo change log found:
echo
cat $tmp/change.log
echo

echo "$lastmodified">> $db
echo "$version">> $db
echo "$md5">> $db
echo "$sha1">> $db
echo >> $db

#create unique filename for google upload
newfilename=$(echo $filename | sed "s/\.exe/_`echo $version`\.exe/")
mv $tmp/$filename $tmp/$newfilename

#if google drive config exists then upload and delete file:
if [ -f "../gd/$appname.cfg" ]
then
echo Uploading $newfilename to Google Drive..
echo Make sure you have created \"$appname\" direcotry inside it!
../uploader.py "../gd/$appname.cfg" "$tmp/$newfilename"
echo
fi

#lets send emails to all people in "posting" file
emails=$(cat ../posting | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "$name $version" "$url 
https://0c53195112e2f6ecec4f01f0f753376ef704bf3c.googledrive.com/host/0B_3uBwg3RcdVOXF3Vkw0RG40bjg/$newfilename 
$md5
$sha1

Change log:
`cat $tmp/change.log`"
} done
echo


else
#changes.log file has created but changes is mission
echo changes.log file has created but changes is mission
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "changes.log file has created but changes is mission: 
$version 
$changes "
} done
fi

else
#changes.log has not been created
echo changes.log has not been created
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "changes.log has not been created: 
$version 
$changes "
} done
fi

else
#version do not match version pattern
echo version do not match version pattern
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "Version do not match version pattern: 
$download "
} done
fi

else
#downloaded file size is to small
echo downloaded file size is to small
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "Downloaded file size is to small: 
$url 
$size"
} done
fi

else
#file is already in database
echo file is already in database
fi

else
#Last-Modified field no included
echo Last-Modified field no included
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "the following link do not include Last-Modified: 
$url "
} done
echo 
echo
fi

else
#installer not found
echo $name installer not found
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "$name installer not found: 
$home 
$url "
} done
echo 
echo
fi

else
#if http statis code is not 200 ok
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "the following link do not retrieve good http status code: 
$url"
} done
echo 
echo
fi

#clean and remove whole temp direcotry
rm $tmp -rf > /dev/null
