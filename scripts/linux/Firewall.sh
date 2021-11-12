#!/bin/bash

#Script made by Rohan Bhargava. For team Zeus use only.
echo "Hello. This script installs and enable ufw and gufw. Run this as root or using sudo. This script was made by Rohan Bhargava."

#Script runs in a loop
while true; do

#selection menu
echo ""
echo "Enter in the NUMBER of the option you want."
echo "1. ufw"
echo "2. gufw"
echo "3. both"
echo "4. exit"
read selection

#ufw only
if [ $selection -eq 1 ]
then echo "Installing ufw"
apt install ufw
ufw enable
ufw status
fi

#gufw only
if [ $selection -eq 2 ]
then echo "Installing gufw"
apt install gufw
gufw &
fi

#both gufw and ufw
if [ $selection -eq 3 ]
then echo "Installing ufw and gufw"
apt install ufw
apt install gufw
ufw enable
ufw status
gufw &
fi

#quit
if [ $selection -eq 4 ]
then break
fi

done
