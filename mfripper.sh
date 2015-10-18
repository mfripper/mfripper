#!/bin/bash

#mfripper 0.1 (2013-12-22) by Lugia010719d1

threshold="14"

basename=$1
jpgdir="$basename"
logfile="$basename-mfripper-log.txt"
pngdir="$basename-mfrip"
templatedir="templates-728"
tempdir="temp"
temptemplate="$tempdir/temptemplate.png"
tempimage="$tempdir/temp.png"
width=0
height=0

#rip the watermark away
function ripwm {
	ifile="$1"
	
	diffcounter=0
	maxmatch="0.0"
	matchtemplate=""
	matchtemplatename=""
	
	#cycle through all templates
	for template in $templatedir/*.png; do
		currenttemplate=$template
		#size is not 728 (the default template size)
		if [ ! $width = "728" ]; then
			#is the width less than 728?
			less=`echo "$width < 728" | bc`
			#is the width not divisible by two?
			notdivisible=`echo "$width % 2" | bc`
			
			#larger than 728 -> add border
			if [ $less = "0" ]; then
				border=`echo "($width - 728)/2" | bc`
				convert "$currenttemplate" -bordercolor white -border "$border"x0 -quality 95 "$temptemplate"
				
				#add 1 if the original width was not divisible by 2
				if [ $notdivisible = "1" ]; then
					extentsize=`expr 728 + $border + $border + 1`
					convert "$temptemplate" -gravity East -background white -extent "$extentsize"x0 -quality 95 "$temptemplate"
				fi
			fi
			
			#smaller than 728 -> remove border
			if [ $less = "1" ]; then
				border=`echo "(728 - $width)/2" | bc`
				convert "$currenttemplate" -bordercolor white -shave "$border"x0 -quality 95 "$temptemplate"
				
				#reduce by 1 if the original width was not divisible by 2
				if [ $notdivisible = "1" ]; then
					convert "$temptemplate" -gravity East -chop "1x0" -quality 95 "$temptemplate"
				fi
			fi
			currenttemplate="$temptemplate"
		fi
	
		#get the template height and export bottom chop of the same height from the inspected picture into temporary folder
		templateheight=`identify -format '%h' "$currenttemplate"`
		chopamount=`expr $height - $templateheight`
		diffcounter=`expr $diffcounter + 1`
		convert "$ifile" -gravity North -chop "0x$chopamount" -quality 95 "$tempimage"
		
		#get matemathical comparison of the chop with the template
		currentmatch=`compare -metric PSNR "$tempimage" "$currenttemplate" "$tempdir/difference-$diffcounter.png" 2>&1`
		
		#if the match is better than previous matches, remember it as the best match
		bestsofar=`echo "$currentmatch > $maxmatch" | bc`
		if [ $bestsofar = "1" ]; then
			maxmatch=$currentmatch
			matchtemplate=$currenttemplate
			matchtemplatename=$template
			echo "Match upgraded to: $currenttemplate ($maxmatch)"
		fi
	done
	
	echo "Best match for $ifile: $matchtemplate ($maxmatch)"
	#check if the best match is good enough (if the input image didnt have any watermark, even the best match would be poor)
	goodenough=`echo "$maxmatch > $threshold" | bc`
	if [ $goodenough = "0" ]; then
		matchtemplate=""
		echo "No chopping will be done."
		echo "NO: $maxmatch [$ifile]" >> $logfile
	fi
	
	#do the chop, resulting file will be saved in a new file
	if [ ! $matchtemplate = "" ]; then
		outfile=${ifile%.*}
		outfile="$outfile-chop.png"
		templateheight=`identify -format '%h' "$matchtemplate"`
		echo "Chopping $ifile by $templateheight ($matchtemplate)"
		echo "YES: $maxmatch ($matchtemplatename) [$ifile]" >> $logfile
		convert "$ifile" -gravity South -chop "0x$templateheight" -quality 95 "$outfile"
		rm "$ifile"
	fi
	
}

#detect page type, then rip the watermark
function inspectwm {
	ifile="$1"
	
	#get width and height
	width=`identify -format '%w' "$ifile"`
	height=`identify -format '%h' "$ifile"`
	
	#detect what size of page ti might be.
	#Detection result is not used in any way currently, but might be useful later
	if [ $width -eq 728 ]; then
	echo "Single-page has been detected"
	else
	if [ $width -eq 1456 ]; then
	echo "Spread has been detected"
	else
	echo "Non-standard size has been detected"
	fi
	fi
	
	#go to the ripping function
	ripwm "$ifile"
	
}

#remove the temporary garbage
function cleanup {
	rm -r "$tempdir"
}


#-------------
#MAIN FUNCTION
#-------------

#if temp dir already exists, exit
if [ -e $tempdir ]; then
	echo "A file or directory with the name temp already exists! Clean up before running this script!"
	exit
fi

mkdir "$tempdir"


#if jpgdir doesn't exist, just exit
if [ ! -d $jpgdir ]; then
	echo "Directory $jpgdir does not exist!"
	exit
fi

#clean previous pngdirs
if [ -e $pngdir ]; then
	rm -r $pngdir
fi

#create a new pngdir
mkdir "$pngdir"

#copy directory structure
prevcwd=$PWD
cd "$jpgdir"
find . -type d | sort | cpio -pvdm "../$pngdir" > /dev/null 2>&1
cd "$prevcwd"

echo "Ripping $1 with threshold $threshold" >> "$logfile"

imgcounter=0
imglist=`find $jpgdir -iname '*.jpg' | sort`
totalimgcount=`echo "$imglist" | wc -l`
echo "Found $totalimgcount jpg images"
#convert all jpgs in jpgdir into pngs in pngdir
for img in $imglist; do
	imgcounter=`expr $imgcounter + 1`
	filename=`basename "$img"`
	filename=${filename%.*}
	filepath=`echo "$img" | cut -d \/ -f 2-`
	filepath=${filepath%.*}
	echo "$imgcounter/$totalimgcount: Converting $filename"
	convert "$jpgdir/$filepath.jpg" -quality 95 "$pngdir/$filepath.png"
	inspectwm "$pngdir/$filepath.png"
done


echo "" >> "$logfile"
#remove temporary files
cleanup

exit
