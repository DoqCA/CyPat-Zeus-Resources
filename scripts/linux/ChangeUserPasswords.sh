#!/bin/bash

#Script made by Rohan Bhargava. For team Zeus use only.

echo "Hello, this script changes the password of many users to a SINGLE password. This script must be run as root or using sudo. This script was made by Rohan Bhargava."
echo ""
echo "Number of users' passwords you would like to change:"
read usernum
echo "Enter in the new password:"
read password
#use the chpasswd commad. This is the temporary file created to do the job.
touch /home/temp.txt
count=0

#Loop that runs until it has changed the number of users specified.
until [ $count -eq $usernum ]; do
echo "Enter in the user name"
read user
echo $user:$password > /home/temp.txt
chpasswd < /home/temp.txt
let count=count+1
done

echo "Passwords changed!"