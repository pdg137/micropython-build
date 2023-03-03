# Micropython build scripts

This repository contains code and instructions for building [MicroPython]
firmware images for the Pololu 3pi+ 2040 Robot.

## Building with Nix

To build a combined UF2 file that contains both Micropython (compiled from source)
and a filesystem with Pololu example code, install [Nix] and [Git] on a Linux machine,
then navigate to this directory and run `./build.sh -A pololu-3pi-2040-robot`.

You can also build Micropython itself without a filesystem by running
`./build.sh -A pololu-3pi-2040-robot.base`.

These builds are reproducible: if you build the firmware the same way on two
different machines or at two different times, you should get the exact same result.

## Manual build

To build your own updated version of MicroPython for the 3pi+, you
can follow these steps on a Linux machine:

```text
sudo apt install git cmake make gcc gcc-arm-none-eabi python3 # for Debian/Ubuntu

git clone https://github.com/v923z/micropython-ulab ulab
git clone https://github.com/micropython/micropython.git
cd micropython

# This part can go away once our changes are merged.
git remote add pololu https://github.com/pololu/micropython.git
git fetch pololu
git checkout pololu/3pi

make -C mpy-cross # build Python cross-compiler

cd ports/rp2
make BOARD=POLOLU_3PI_2040_ROBOT submodules
make BOARD=POLOLU_3PI_2040_ROBOT clean
make USER_C_MODULES=../../../ulab/code/micropython.cmake BOARD=POLOLU_3PI_2040_ROBOT
```

There will now be a `firmware.uf2` file in the `build-POLOLU_3PI_2040_ROBOT` directory
that you can use.  It will not contain a file system or example code for the robot.

## Acknowledgments

This project relies on the following third-party projects:

- [MicroPython](https://github.com/micropython/micropython)
- [Mbed TLS](https://github.com/ARMmbed/mbedtls)
- [micropython-lib](https://github.com/micropython/micropython-lib)
- [Raspberry Pi Pico SDK](https://github.com/raspberrypi/pico-sdk)
- [TinyUSB](https://github.com/hathach/tinyusb)
- [ulab](https://github.com/v923z/micropython-ulab)
- [Nixpkgs](https://github.com/nixos/nixpkgs) and [Nix]

It also incorporates example code written by Pololu:

- [Pololu 3pi+ 2040 Robot example code and libraries](https://github.com/pololu/pololu-3pi-2040-robot)

[Git]: https://git-scm.com/
[Nix]: https://github.com/nixos/nix
[MicroPython]: https://micropython.org/
