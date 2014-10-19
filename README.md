epub2casiotxt
=============

Convert EPUB to text file that can be uploaded to a Casio EX-Word dictionary

Usage:

  epub2casiotxt [-k] orig.epub converted.txt

  -k     keep temporary files

Requirements:

- html2txt
- Perl
- Text::Unidecode

The script does the following:

- extracts the chapters from the EPUB (which is just an archive of (X)HTMLs with metadata)
- converts them to text and concatenates the chunks into one flat text file (hopefully in the right order)
- removes non-ASCII characters
- converts line endings to \r\n


