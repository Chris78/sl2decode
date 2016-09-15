# sl2decode

Quickstart:
Usage: ruby sl2decode.rb your_file.sl2

Thanks to GitHub user 'kmpm' for his preparatory work:
https://github.com/kmpm/node-sl2format/blob/master/doc/sl2fileformat.md

The script will extract the data blocks from the binary sl2 file and will write
a human readable textfile as output.
The textfile is actually an inspection of the generated ruby array of hashes.
In addition the exported textfile also contains the YAML export of the data.

Uncomment more block attributes in the script to export them as well.

Since Lowrance has it's own Format for latitude and longitude, the script also
converts the "lowrance_latitude" and "lowrance_longitude" into Google compatible
coordinates. Thanks to http://wiki.openstreetmap.org/wiki/SL2 for the explanation 
on how to convert the coordinates.

I tested the script with my first sl2 chart that I recorded with a Lowrance Hook 4.
