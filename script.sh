#!/bin/bash

if [[ $EUID -ne 0 ]]; then
    echo "You must be signed in as root. Run \`sudo bash cypat.sh\` to retry."
    exit 1
fi

# ===== util functions =====

function cont() {
    echo Press ENTER to continue.
    read
}

function heading() {
    clear
    echo "=============== $* ==============="
    echo
}

function promptYN() {
    prompt="$1 [Y/n] "
    if [[ "$1" == "-n" ]]; then
        prompt="$2 [y/N] "
    fi

    read -p "$prompt" yn

    if [[ "$1" == "-n" ]]; then
        if [[ -z "$yn" ]]; then
            return 1
        else
            return `[[ $yn =~ ^[yY]$ ]]`
        fi
    else
        return `[[ $yn =~ ^[yY]?$ ]]`
    fi
}

# ===== end util functions =====

clear
echo "Hi! Welcome to Alex's CyberPatriot script. This will guide you through several common vulnerabilities."
echo "This is inspired by https://github.com/Forty-Bot/linux-checklist"
echo "Remember to \`curl cht.sh/\` and read the README and solve the forensics questions."
echo "Backups will be made under /home/script"
cont
mkdir /home/script

heading "GUI things"
echo "Read the README"
echo "Note which ports/users are allowed."
echo "Do the Forensics Questions before running the rest of this script."
echo "Update the Firefox settings to be the default browser."
echo "Go to the preferences > Software & Updates"
echo "Check for updates daily and display other updates immediately"
echo "Install updates from important security updates and recommended updates"
echo "(this information is also available in /etc/apt/sources.list"
echo "Don't forget to apt update && apt upgrade"
cont


function secureRoot() {
    heading "Secure root ssh config"
    echo "Set \`PermitRootLogin no\` in /etc/ssh/sshd_config"
    cont
    gedit /etc/ssh/sshd_config
}

function disableGuestUser() {
    heading "Secure users"
    echo "disable the guest user"
    echo "go to /etc/lightdm/lightdm.conf and add the line \`allow-guest=false\`"
    cont
    gedit /etc/lightdm/lightdm.conf
    echo "restart session (sudo restart lightdm). This will log you out, so make sure you are not executing anything important."
    cont
    echo "restarting lightdm..."
    sudo restart lightdm
}

function inputUsers() {
    echo -n > /home/script/passwds.txt
    echo -n > /home/script/admins.txt

    echo "type out all users, separated by lines"
    
    # for each provided user, we check if they exist on the system
    # if yes, good, if no, create user
    while read -p "username: " username; do
        echo "checking for $username"

        # if user not found
        if cat /etc/passwd | grep $username &>/dev/null; then
            echo "$username exists in /etc/passwd"
        elif promptYN "$username not found in /etc/passwd. create user $username?"; then
            adduser "$username"
        fi

        if promptYN -n "is $username an admin?"; then
            adduser "$username" sudo # add to sudo group
            adduser "$username" adm
            echo "$username added to sudo and adm groups"
            echo "$username" >>/home/script/admins.txt
        fi

        echo "${username}:Old\$cona1" >>/home/script/passwds.txt
    done

    echo "content of \"/home/script/passwds.txt\":"
    cat /home/script/passwds.txt

    if promptYN "change all user passwords?"; then
        cat /home/script/passwds.txt | chpasswd
    fi
}

function users() {
    if promptYN -n "enter all users?"; then
        inputUsers
    else
        echo "skipping adding new users";
    fi

    # checks if the provided user from /etc/passwd was given by the user.
    # i.e. is there a user on the system that should not be there
    if promptYN -n "check users in /etc/passwd?"; then
        for username in `cat /etc/passwd | cut -d: -f1`; do
            if grep $username /home/script/passwds.txt > /dev/null; then
                echo "$username found in /home/script/passwds.txt, skipping"
            elif promptYN -n "$username not found in /home/script/passwds.txt, remove?"; then
                deluser --remove-home $username
                echo "$username deleted."
            fi
        done
    fi

    # get list of sudoers
    if promptYN -n "check admin?"; then
        for username in `cat /etc/group | grep sudo | cut -d: -f4 | tr ',' '\n'`; do
            if grep $username /home/script/admins.txt; then
                echo "$username is a valid admin, skipping"
            elif promptYN "$username is in the sudo group but not a valid sudoer, remove from sudo?"; then
                deluser $username sudo
                echo "$username removed from sudo group."
                if cat /etc/group | grep adm | grep $username && promptYN "user also in \"adm\" group, remove?"; then
                    deluser $username adm
                    echo "$username removed from adm group."
                fi
            fi
        done
    fi
}

function usersCont() {
    heading "Secure users cont."
    echo "Check for anybody except root with uid 0; these users are BAD"
    echo "username:uid"
    cat /etc/passwd | cut -f1,3 -d:
    cont
}

function removeGames() {
    echo "here is the list of installed packages with \"game\" in their description:"
    gameNames=`dpkg --list | grep game | tr -s ' ' | cut -d ' ' -f 2`
    echo "$gameNames"
    if promptYN "remove these?"; then
        apt purge $(echo "$gameNames" | tr '\n' ' ')
    fi
    promptYN "remove pure-ftpd?" && apt purge pure-ftpd
    promptYN "remove zenmap?" && apt purge zenmap
}

# Add or change password expiration requirements to /etc/login.defs.
# Add a minimum password length, password history, and add complexity requirements.
function passwordReqs() {
    echo "change the following in /etc/login.defs:"
    echo "PASS_MIN_DAYS 7"
    echo "PASS_MAX_DAYS 90"
    echo "PASS_WARN_AGE 14"
    cont
    gedit /etc/login.defs

    if promptYN "install libpam-cracklib?"; then
        apt install libpam-cracklib
    fi

    # update password requirements
    clear
    echo "Open /etc/pam.d/common-password with sudo."
    echo "Add minlen=8 to the end of the line that has pam_unix.so in it."
    echo "Add remember=5 to the end of the line that has pam_unix.so in it."
    echo "Locate the line that has pam.cracklib.so in it."
    echo "Add \"ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1\" to the end of that line."
    cont
    gedit /etc/pam.d/common-password

    # Implement an account lockout policy.
    clear
    echo "open /etc/pam.d/common-auth."
    echo "add deny=5 unlock_time=1800 to the end of the line with pam_tally2.so in it."
    echo "Change all passwords to satisfy these requirements."
    cont
    gedit /etc/pam.d/common-auth
}

function suspiciousFiles() {
    echo "check for suspicious files."
    cont
    ls -aR /home | less
}

# Check /etc/sudoers.d and make sure only members of group sudo can sudo.
function checkSudoers() {
    echo "Check /etc/sudoers.d and make sure only members of group sudo can sudo."
    echo "This will use visudo to open the file."
    cont
    visudo
}

function checkServices() {
    if promptYN "check services?"; then
        service --status-all | less
    fi
    echo "Check service configuration files for required services in /etc."
    echo "Usually a wrong setting in a config file for sql, apache, etc. will be a point."
}

function securePorts() {
    echo "WIP"
    if promptYN "secure ports?"; then
        echo "If a port has 127.0.0.1:SOME_PORT in its line, that means it's connected to loopback and isn't exposed. Otherwise, there should only be ports which are specified in the readme open (but there probably will be tons more)."
        echo "For each open port which should be closed:"
        echo "Copy the program which is listening on the port."
        echo "lsof -i :SOME_PORT"
        echo "whereis SOME_PROGRAM"
        echo "Copy where the program is (if there is more than one location, just copy the first one)."
        echo "This shows which package provides the file."
        echo "If there is no package, that means you can probably delete it with"
        echo "rm SOME_LOCATION; killall -9 SOME_PROGRAM"
        echo "apt purge SOME_PACKAGE"
        echo "dpkg -S SOME_LOCATION"
        ss -ln | less

        echo "Check to make sure you aren't accidentally removing critical packages before hitting \"y\""
        echo "ss -l to make sure the port actually closed."
    fi
}

function configureFirewall() {
    promptYN "enable firewall?" && ufw enable
}

function configureSysctl() {
    echo "turn on the following settings ( = 1 ):"
    echo "net.ipv4.tcp_syncookies"
    echo "net.ipv4.conf.default.rp_filter"
    echo "net.ipv4.conf.all.rp_filter"
    echo "net.ipv6.conf.all.disable_ipv6"
    echo "net.ipv6.conf.default.disable_ipv6"

    echo "disable the following settings ( = 0 ):"
    echo "net.ipv4.ip_forward"
    echo "net.ipv4.conf.all.accept_redirects"
    echo "net.ipv6.conf.all.accept_redirects"
    echo "net.ipv4.conf.all.send_redirects"
    echo "net.ipv4.conf.all.accept_source_route"
    echo "net.ipv6.conf.all.accept_source_route"

    cont
    gedit /etc/sysctl.conf

    promptYN "update changes?" && sysctl -p
}

function checkRootkits() {
    apt install clamtk
    promptYN "run freshclam?" && freshclam
}

function checkCron() {
    echo "check these files:"
    ls /etc/cron.*
    echo "crontab:"
    cat /etc/crontab
    ls /var/spool/cron/crontabs

    echo "check the init files"
    ls /etc/init
    ls /etc/init.d

    echo "check for each user"
    crontab -u {USER} -l
}

# Acknowledgements
# Michael "MB" Bailey and Christopher "CJ" Gardner without whose checklists this would never have been possible.
# Alexander Dittman and Alistair Norton for being fellow linux buddies.
# My 2015-16 CP team: Quiana Dang, Sieun Lee, Jasper Woolley, and David Randazzo.
# In no particular order: Marcus Phoon, Joshua Hufnagel, Patrick Hufnagel, Michael-Andrew Keays, Christopher May, Garrett Brothers, Joseph Kelley, and Julian Vallyeason.

# main loop
while true; do
    clear
    echo "Which section to run?"
    echo "1. secure root ssh config"
    echo "2. disable guest user"
    echo "3. check users"
    echo "4. check /etc/passwd"
    echo "5. remove games and apps"
    echo "6. configure firewall"
    echo "7. password requirements"
    echo "8. check sudoers"
    echo "9. find suspicious files"
    echo "10. services"
    echo "11. sysctl"
    echo "12. rootkits"
    echo "13. cron"
    read -p "enter section number: " secnum

    if [[ -z "$secnum" ]]; then
        echo "thanks for using this script! hope it won you lots o' points :)"
        break
    fi

    clear
    case $secnum in
    1) secureRoot;;
    2) disableGuestUser;;
    3) users;;
    4) usersCont;;
    5) removeGames;;
    6) configureFirewall;;
    7) passwordReqs;;
    8) checkSudoers;;
    9) suspiciousFiles;;
    10) checkServices;;
    11) configureSysctl;;
    12) checkRootkits;;
    13) checkCron;;
    esac
    cont
done
