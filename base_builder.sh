source $stdenv/setup
set -u

mkdir -p $out/licenses

cp --no-preserve=mode -r $src src
cp src/LICENSE $out/licenses/LICENSE_micropython.txt
cd src

rmdir lib/mbedtls
ln -s $lib_mbedtls lib/mbedtls
cp lib/mbedtls/LICENSE $out/licenses/LICENSE_mbedtls.txt
cp lib/mbedtls/apache-2.0.txt $out/licenses/apache-2.0_mbedtls.txt

rmdir lib/micropython-lib
ln -s $lib_micropython_lib lib/micropython-lib
cp lib/micropython-lib/LICENSE $out/licenses/LICENSE_micropython_lib.txt

rmdir lib/pico-sdk
ln -s $lib_pico_sdk lib/pico-sdk
cp lib/pico-sdk/LICENSE.TXT $out/licenses/LICENSE_pico_sdk.txt

rmdir lib/tinyusb
ln -s $lib_tinyusb lib/tinyusb
cp lib/tinyusb/LICENSE $out/licenses/LICENSE_tinyusb.txt

cat >> ports/rp2/boards/$MICROPY_BOARD/mpconfigboard.h <<END
#define MICROPY_BANNER_NAME_AND_VERSION "$MICROPY_BANNER_NAME_AND_VERSION"
END

rm ports/rp2/modules/_boot.py

cd ..

# This date shows up in sys.version.
SOURCE_DATE_EPOCH=$(date -u --date=$date +%s)

mkdir build
cd build
cmake ../src/ports/rp2 $cmake_flags
cmake --build .

cp --no-preserve=mode firmware.uf2 $out/$name.uf2
cp --no-preserve=mode firmware.bin $out/$name.bin

echo "Built $MICROPY_BANNER_NAME_AND_VERSION"
