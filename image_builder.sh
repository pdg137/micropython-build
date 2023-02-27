source $stdenv/setup
set -u

# This date shows up in file creation/modification timestamps.
SOURCE_DATE_EPOCH=$(date -u --date=$date +%s)

# Expand MicroPython image to 1 MiB.
ruby -e 'print ARGF.read.b.ljust(1024*1024, "\xFF")' $base_bin > base.bin

# Create a 15 MiB FAT file system.
ruby -e 'print "\xFF"*15*1024*1024' > demo.bin
faketime $date mkfs.fat -S 4096 -s 1 -f 1 -g 255/63 \
  -i 0 -n 'MicroPython' demo.bin

# Copy our Python code into the file system.
faketime $date mcopy -i demo.bin -s $demo/* ::

cat base.bin demo.bin > image.bin

ruby $bin2uf2 image.bin image.uf2

mkdir $out
mv image.uf2 $out/$name.uf2
