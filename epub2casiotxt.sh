#!/bin/bash

remove_temps=1

# -k option to keep temporary files if something goes wrong
while getopts ":klt" opt; do
  case $opt in
    k)
      remove_temps=
      ;;
    l)
      force_raw_list=1
      ;;
    t)
      use_toc_ncx=1
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

if [[ $1 == $2 ]]; then
	echo "Error: The two arguments are the same, not clobbering original file"
	exit 1
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

# find root file from container.xml
root_file=$(sed '/<container/ s/xmlns="[^"]*"//g' < META-INF/container.xml | xmllint --xpath 'string(/container/rootfiles/rootfile[1]/@full-path)' -)

if [[ -z $root_file ]]; then
	echo "Can't parse root file from container.xml" >&2
	exit 1
fi

# force falling back to raw list of htmls?
if [[ -n $force_raw_list ]]; then
	# may result in order mixed up
	files=$(find . -name "*.*htm*"| sort -n)
elif [[ -n $use_toc_ncx ]]; then
	toc_file=$(find . -name toc.ncx)
	files=$(perl -lne 'if (/content src/) {s/.*?"(.+?)".*/\1/g; print}' $toc_file)

	path=$(dirname $root_file)
	cd "$path"
else
	files=$(sed '/^<package/ s/xmlns="[^"]*"//g' < $root_file | xmllint --xpath '/package/manifest/item[@media-type="application/xhtml+xml"]/@href' - | sed 's/ href="\([^"]*\)"/\1\n/g')

	# html paths are relative to rootfile?
	path=$(dirname $root_file)
	cd "$path"
fi

# convert all htmls to text
stage1=`mktemp`
for f in $files; do
	#html2text -utf8 -width 10000 "$f" >> $stage1
	html2text -b 10000 "$f" utf8 >> $stage1
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

