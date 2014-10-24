#!/bin/bash

remove_temps=1

# -k option to keep temporary files if something goes wrong
while getopts ":k" opt; do
  case $opt in
    k)
      remove_temps=
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
  esac
done

shift $(( OPTIND - 1 ));

# check for input and output arguments
if (($# < 2)); then
	echo "Usage: $0 orig.epub converted.txt";
	exit 1;
fi

# copy input to temp dir
origdir="`pwd`"
tmpdir=`mktemp -d`
cp "$1" $tmpdir
cd $tmpdir

# epub is just a zip archive with htmls in it
unzip "$1" &> /dev/null

# save field separator
OLDIFS=$IFS
IFS=$'\n'

# find and parse table of contents
toc=$(find . -name "_toc_ncx_.ncx" | head -1)
if [[ -z $toc ]]; then
	toc=$(find . -name "toc.ncx" | head -1)
fi

if [[ -n $toc ]]; then
	files=$(grep "content src" $toc | perl -lpe 's/^.*?"//;s/".*$//;s/\#.*$//;$_=(split m|/|)[-1]' | xargs -I {} find . -name "{}")
else
	# fall back to raw list of htmls, may result in order mixed up
	files=$(find . -name "*.*html"| sort -n)
fi

# convert all htmls to text
stage1=`mktemp`
for f in $files; do
	html2text -utf8 -width 10000 "$f" >> $stage1
done

IFS=$OLDIFS

# convert to ASCII with windows line endings
stage2=`mktemp`
stage3=`mktemp`
stage4=`mktemp`
perl -lpe 's/^<\?xml version=.*? encoding=.*?\?>$//' $stage1 > $stage2
perl -CSAD -MText::Unidecode -ne 'print unidecode($_)' $stage2 > $stage3
perl -pe 's/\n$/\r\n/' $stage3 > $stage4;

# copy final output back
cp $stage4 "$origdir/$2"

# remove intermediate files
if [[ $remove_temps ]]; then
	rm -rf $stage1 $stage2 $stage3 $stage4 $tmpdir
fi

