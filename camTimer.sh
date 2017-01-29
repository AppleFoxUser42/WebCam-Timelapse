#!/bin/bash

for (( i=0 ; i < $# ; i++ )) {
    case ${BASH_ARGV[$i]} in
        "-h")
            echo "Usage camTimer [-idh] [url]"
            echo "-i    capture interval in seconds"
            echo "-d    capture duration in minutes"
            echo "url   URL of webcam"
            echo "-h    this help"
            echo "EXIT Codes: 1 on help; 2 on error; 0 on success"
            exit 1
            ;;
        "-i")
            interval=${BASH_ARGV[$(($i-1))]}
            ;;
        "-d")
            duration=${BASH_ARGV[$(($i-1))]}
            ;;
    esac
}
if [[ $interval ]] && [[ $duration ]] ; then
url=${BASH_ARGV[0]}
else
echo "ERROR: duration or intervals not set. Use -h for help."
exit 2
fi

#Calculate Sleep-Time
maxCounter=$(( ($duration*60) / $interval ))


##Thx to Louis Marascio
##http://fitnr.com/showing-a-bash-spinner.html
spinner()
{
    local pid=$1
    local delay=0.75
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}
##End Louis Code.


for ((i=1 ; i<=$maxCounter ; i++ )) {
    echo -ne "Loading Image $i "
    curl -s "$url" -o "$i".jpg
    sleep $interval &
     
    spinner $! #$! PID of last command or sub-shell
    echo -ne "\r"
}


exit 0