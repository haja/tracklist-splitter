#!/bin/bash

input="$1"
tracklistFile="$2"
outputFolder="$3"

mode="$4" # only start timestamps are provided (uses other regex + sets $to to $from of next track)

# metadata fields
metaAlbum="$5"
metaGenre="$6"

myTranscode() {
    from="$1"
    to="$2"
    artist="$3"
    title="$4"
    trackNr="$5"

    # sanatize title
    title="${title//\//_}";
    artist="${artist//\//_}";

    # add leading zeros trackNr
    trackNr=$(printf "%02d" "$trackNr");

    outputString="${outputFolder}/${trackNr} - ${artist} - ${title}.${ext}"

    # chech if $to is set (not set in startOnly mode for last track)
    if [[ ! $to ]]; then
        echo "to not set! using track end as end timestamp"
        ffmpeg -i "${input}" -ss ${from} -metadata title="${title}" -metadata artist="${artist}" -metadata track=${trackNr} -metadata album="${metaAlbum}" -metadata genre="${metaGenre}" -c copy "${outputString}"
    else
        ffmpeg -i "${input}" -ss ${from} -metadata title="${title}" -metadata artist="${artist}" -metadata track=${trackNr} -metadata album="${metaAlbum}" -metadata genre="${metaGenre}" -to ${to} -c copy "${outputString}"
    fi
}

if [ $# -ne 6 ] || [[ $mode != "startOnly" && $mode != "startEnd" ]]; then
    echo "Usage: $0 <audiofile> <tracklist> <output folder> <mode> <album> <genre>"
    echo "output folder will be created if it doesn't exist"
    echo "mode: startOnly or startEnd"
    echo "tracklist must be of form: (start) [- (end) ]- (artist)-(title)"
    exit 1
fi

if [ -e "$outputFolder" ]; then
    echo "outputFolder exists. continue? (y/n)";
	read ANSWER
	if [ "$ANSWER" != "y" ]; then
		echo "aborting"
		exit 1
	fi
else
    mkdir -p "$outputFolder";
fi

ext=${input##*.} # match file ext

counter=1

if [[ $mode == "startOnly" ]]
then
    regex="^([\:0-9]+) - ([^-]*)-([^-]*)"
    while read -r trackRaw; do
        echo "---- matching ${trackRaw}"
        if [[ $trackRaw =~ $regex ]]
        then
            from[$counter]=${BASH_REMATCH[1]}
            artist[$counter]=${BASH_REMATCH[2]}
            title[$counter]=${BASH_REMATCH[3]}
        else
            echo "**** no match ${trackRaw} trackNr: $counter";
        fi
        let "counter += 1";
    done < "$tracklistFile"
    
    # get to timestamp as from of next track (or set to empty on last track)
    for (( i = 2; i < $counter; i++ )); do
        prev="$i"
        let "prev -= 1";
        to[$prev]="${from[$i]}"
    done
else
    regex="^([\:0-9]+) - ([\:0-9]+) - ([^-]*)-([^-]*)"
    while read -r trackRaw; do
        echo "---- matching ${trackRaw}"
        if [[ $trackRaw =~ $regex ]]
        then
            # somehow these arrays are needed
            # call to ffmpeg doesn't work if using vars directly (messes up $trackRaw var)
            echo from ${BASH_REMATCH[1]}
            echo to ${BASH_REMATCH[2]}
            echo artist ${BASH_REMATCH[3]}
            echo title ${BASH_REMATCH[4]}
            echo number ${counter}

            from[$counter]=${BASH_REMATCH[1]}
            to[$counter]=${BASH_REMATCH[2]}
            artist[$counter]=${BASH_REMATCH[3]}
            title[$counter]=${BASH_REMATCH[4]}
        else
            echo "**** no match ${trackRaw} trackNr: $counter";
            exit 1
        fi
        let "counter += 1";
    done < "$tracklistFile"
fi

for (( i = 1; i < $counter; i++ )); do
    myTranscode "${from[i]}" "${to[i]}" "${artist[i]}" "${title[i]}" "${i}"
done
