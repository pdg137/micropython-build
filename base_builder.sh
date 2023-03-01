source $stdenv/setup
set -u

cp --no-preserve=mode -r $src src
cd src

rmdir lib/mbedtls
ln -s $lib_mbedtls lib/mbedtls

rmdir lib/micropython-lib
ln -s $lib_micropython_lib lib/micropython-lib

rmdir lib/pico-sdk
ln -s $lib_pico_sdk lib/pico-sdk

rmdir lib/tinyusb
ln -s $lib_tinyusb lib/tinyusb

cat >> ports/rp2/boards/$MICROPY_BOARD/mpconfigboard.h <<EOF
#define MICROPY_BANNER_NAME_AND_VERSION "$MICROPY_BANNER_NAME_AND_VERSION"
EOF

rm ports/rp2/modules/_boot.py

cd ..

# This date shows up in sys.version.
SOURCE_DATE_EPOCH=$(date -u --date=$date +%s)

mkdir build
cd build
cmake ../src/ports/rp2 $cmake_flags
cmake --build .

mkdir $out
cp --no-preserve=mode firmware.uf2 $out/$name.uf2
cp --no-preserve=mode firmware.bin $out/$name.bin

echo "Built $MICROPY_BANNER_NAME_AND_VERSION"
