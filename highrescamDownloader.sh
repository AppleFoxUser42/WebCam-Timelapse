#!/bin/bash
#Computes Download URL for high-res-cam and initiates download of tiles. 
#It also stitches them together using montage
#Requires ImageMagick, parallel and curl

#Set Skript-Mode
ramMode=0
export out="out.jpg"
if [ -x $(which parallel) ]; then
    useParallel=1
else
    useParallel=0
fi

#Iterates over parameters
#echo No. of args = $#
for (( i=0 ; i<$# ; i++ )); do
    #echo arg $i is ${BASH_ARGV[$i]}
    case ${BASH_ARGV[$i]} in
        "--ram")
            ramMode=1
            ;;
        "-h")
            echo "frankfurt_highrescam.sh -o [out.jpg]"
            printf " %-6s %b" "-h" "prints this help\n"
            printf "%-7s %b" "--ram" "activates ramdisk mode\n"
            echo "adding a filename sets out variable"
            exit 0
            ;;    
        "-o")
            unset out
            export out=${BASH_ARGV[$(($i-1))]}
            ;;
        "--no-parallel")
            useParallel=0
            echo "Not using GNU parallel!"
            ;;
        "--no-montage")
            useMontage=0
            echo "Not using montage [NOT YET IMPLEMENTED]"
            ;;
    esac
done

#DEBUG exit
#exit 42

if [ ! -x $(which montage) ]; then
    echo "ERROR: montage from ImageMagick not found. Needed to stitch"
    exit 2
fi

if [ $ramMode = "1" ]; then
    if [ ! -d /Volumes/RAMDISK ]; then
        ramdisk=$(hdiutil attach -nomount ramdisk://102400)
        echo DEBUG: RAMDISK on $ramdisk
        sleep 2
        diskutil eraseDisk exfat RAMDISK $ramdisk ;
        sleep 3
        export outloc=/Volumes/RAMDISK/
    else
        export outloc=/Volumes/RAMDISK/
    fi
else
    export outloc=""
fi

function on_signal() {
    echo 'Script stopped by user'
    if [ -d /Volumes/RAMDISK ]; then 
        echo ejecting RAMDISK
        diskutil eject $(diskutil list|grep RAMDISK|awk '{ print $8 }') 
    fi 
    return 1
}
trap 'on_signal'  SIGTERM SIGINT

#debug line to test useParallel
#useParallel=0

#Instantiates all needed variables.
baseurl='http://www.mainhattan-webcam.de/dzi/'
year=$(date +%Y)
day=$(date +%d)
month=$(date +%m)
hour=$(date +%H)
minute=$(date +%M)
urlpart='frankfurt_files/'
suffix='.jpg'
referer='http://www.mainhattan-webcam.de/?ref=helifliegen'

#Checks if minute is divisible by 5. If not floors time.
if [[ $(($minute%5)) -ne 0 ]] && [[ $(($minute%10)) -le 5 ]]
then
    #echo $(($minute-$(($minute%10))))
    minute=$(($minute-$(($minute%10))))
    #echo "Time" $hour":"$minute
elif [[ $(($minute%5)) -ne 0 ]] && [[ $(($minute%10)) -ge 5 ]]
then

    minute=$(($minute-$(($minute%10))))
    #echo "Time" $hour":"$minute
else
    #echo "Time" $hour":"$minute
    minute=$(($minute-5))
fi

#check if image exists, if not subtracts 5min from time.
curl -G -s $baseurl$year"/"$month"/"$day"/"$hour"/"$minute"/"$urlpart"13/1_1.jpg" -e $referer -o timeCheck.jpg
if [ "$(file -b timeCheck.jpg)" = "ASCII text" ]
    then
        sleep 1
        rm timeCheck.jpg >>/dev/null
        echo -n "Changing time from "$hour":"$minute" to "
        minute=$(($minute-5))
        echo $hour":"$minute
        sleep 4
    else
        #echo "Deleting timeCheck.jpg"
        rm timeCheck.jpg >>/dev/null
    fi



#Reference-URL
#http://www.mainhattan-webcam.de/dzi/2017/01/07/20/20/frankfurt_files/10/1_0.jpg 


#dzi=$baseurl$year"/"$month"/"$day"/"$hour"/"$minute"/frankfurt.dzi"
#curl -G $dzi -e $referer -O

url=$baseurl$year"/"$month"/"$day"/"$hour"/"$minute"/"$urlpart

function download_image() {

    outfile="$outloc"$1"_"$3"_"$2".jpg"
    #echo DEBUG: $outfile
    if [ "$useParallel" = "0" ]; then
    echo -ne Downloading... $4$1"/""$2"_"$3"".jpg\r"
    fi
    curl -G -s $4$1"/""$2"_"$3"".jpg" -e $5 -o $outfile &>/dev/null

    #checks if downloaded file is not photo. If so deletes it.
if [ "$(file -b $outfile)" = "ASCII text" ]
    then
        rm $outfile >>/dev/null
    fi
}


#checks if useParallel=1 if so uses GNU parallel if not uses xargs and for-loops. 
if [ $useParallel -eq 1 ]; 
then
    export -f download_image
    echo "Downloading Files"
    parallel -j+8 --bar download_image  ::: 13 ::: {0..23} ::: {0..16} ::: $url ::: $referer
    
    echo "Preprocessing Files"
    parallel -j+8 --bar montage -quiet $outloc"13"_{}_{0..23}.jpg -tile x1 -geometry +0+0 "$outloc"{}.jpg &>/dev/null ::: {0..15}
    
    echo "Creating Full File"
    montage -quiet "$outloc"{0..15}.jpg -tile 1x -geometry +0+0 $out  &>/dev/null
    sleep 4
    
    echo "Deleting Tiles..."
    ls "$outloc"13*.jpg | parallel -j+0 --bar rm {} &>/dev/null
    
    echo "Deleting temporaries..."
    ls "$outloc""*.jpg" | grep -E ^[0-9]+\.jpg | parallel -j+0 --bar rm {} &>/dev/null

else
    echo "Downloading Files"
    for i in 13 
    do
        for j in {0..23} 
        do
            for c in {0..15} 
            do
                download_image $i $j $c $url $referer
    done
        done
            done

echo ""
echo "Preprocessing Files"
for i in {0..15}
do 
    montage -quiet "$outloc"13"_"$i"_"{0..23}.jpg -tile x1 -geometry +0+0 "$outloc"$i.jpg &>/dev/null
done

    echo "Creating Full File"
    montage -quiet "$outloc"{0..15}.jpg -tile 1x -geometry +0+0 $out  &>/dev/null
    sleep 4

    echo "Deleting Tiles..."
    ls "$outloc"13*.jpg | xargs -J % rm % &>/dev/null

    echo "Deleting temporaries..."
    ls "$outloc"*.jpg|grep -E ^[0-9]+\.jpg | xargs -J % rm % &>/dev/null
fi

