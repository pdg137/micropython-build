let
  # This date is used to identify releases.  It gets baked into the filenames,
  # file system timestamps, and `sys.version` in Python.
  date = "2023-05-10";

  short_date = (builtins.substring 2 2 date) +
    (builtins.substring 5 2 date) + (builtins.substring 8 2 date);

  build_git_tag = if builtins.getEnv "COMMIT" == "" then
    builtins.throw "Be sure to use build.sh.  See README." else
    short_date + "-" + builtins.getEnv "COMMIT";

  # nixos-22.11 branch, 2022-12-14
  nixpkgs = import (fetchTarball
    "https://github.com/NixOS/nixpkgs/archive/170e39462b516bd1475ce9184f7bb93106d27c59.tar.gz");
  pkgs = nixpkgs {};

  example_code = pkgs.fetchFromGitHub {
    owner = "pololu";
    repo = "pololu-3pi-2040-robot";
    rev = "edc85070ec9820e3740a7d118d253f67ea6fbc86";  # 2023-05-10
    hash = "sha256-uhod1T8c6q6GN1p3aUMjZjueissL1FrhVBSrvihJey8=";
  };

  base = pkgs.stdenv.mkDerivation rec {
    name = "micropython-base" + name_suffix;
    name_suffix = "-pololu-3pi-2040-robot-${version}-${short_date}";

    inherit date;

    src = pkgs.fetchFromGitHub {
      owner = "micropython";
      repo = "micropython";
      rev = "4e4bdbd191eb00ef42d9bd6fe9a8303a16f6878d";  # master branch, 2023-05-09
      hash = "sha256-7uZw5JV6wDyhPlzKc0oM0zSDv6Xzm/xOVhP8inm7u0U=";
    };
    patches = [ ./3pi.patch ./traceback.patch ];

    # After changing the MicroPython version above, run
    # 'git describe --tags --match=v*' to get the new values for these:
    version = "v1.20.0";
    version_suffix = "-62";
    MICROPY_GIT_TAG = version + version_suffix + "-g" + MICROPY_GIT_HASH;
    MICROPY_GIT_HASH = builtins.substring 0 9 src.rev;

    # Submodules of MicroPython needed by the RP2 port.
    # We could try 'fetchSubmodules = true;' above but that would fetch lots of repositories
    # we don't need, and it won't work with submodules that come from private URLs.
    #
    # After changing the MicroPython version, get the info you need to update this by
    # running in the MicroPython repository:
    #   cd ports/rp2 && make submodules && git submodule status --recursive | grep '^ '
    lib_mbedtls = pkgs.fetchFromGitHub {
      owner = "ARMmbed";
      repo = "mbedtls";
      rev = "981743de6fcdbe672e482b6fd724d31d0a0d2476";
      hash = "sha256-w5bJErCNRZLE8rHcuZlK3bOqel97gPPMKH2cPGUR6Zw=";
    };
    lib_micropython_lib = pkgs.fetchFromGitHub {
      owner = "micropython";
      repo = "micropython-lib";
      rev = "c113611765278b2fc8dcf8b2f2c3513b35a69b39";
      hash = "sha256-Bh21HxOUVdFbbtAPTr3I5krhS5kIqBbMleUCodg3hBo=";
    };
    lib_pico_sdk = pkgs.fetchFromGitHub {
      owner = "raspberrypi";
      repo = "pico-sdk";
      rev = "f396d05f8252d4670d4ea05c8b7ac938ef0cd381";
      hash = "sha256-p69go8KXQR21szPb+R1xuonyFj+ZJDunNeoU7M3zIsE=";
    };
    lib_tinyusb = pkgs.fetchFromGitHub {
      owner = "hathach";
      repo = "tinyusb";
      rev = "868f2bcda092b0b8d5f7ac55ffaef2c81316d35e";
      hash = "sha256-R3BUj8q3/q2Z+bh73jJTrepoLuziU8HdUAaVXTXtRBk=";
    };

    ulab_src = pkgs.fetchFromGitHub {
      owner = "v923z";
      repo = "micropython-ulab";
      rev = "ac2e9954edc185ec212e437e73e4b5e4290de35b";  # 2023-05-07
      hash = "sha256-BVhPoZGyKP4x/CDFR5F3+edD7oT6J31t+EASVO0qYSI=";
    };

    # After changing the ulab version, run
    # 'git describe --tags' to get the new value of this:
    ulab_git_tag = "6.0.12"; #+ builtins.substring 0 7 ulab_src.rev;

    MICROPY_BANNER_NAME_AND_VERSION =
      "MicroPython ${MICROPY_GIT_TAG} build ${build_git_tag}; with ulab ${ulab_git_tag}";

    MICROPY_BOARD = "POLOLU_3PI_2040_ROBOT";

    buildInputs = [ pkgs.cmake pkgs.gcc pkgs.gcc-arm-embedded pkgs.python3 ];

    cmake_flags = "-DMICROPY_BOARD=${MICROPY_BOARD} " +
      #"-DCMAKE_BUILD_TYPE=Debug " +
      "-DPICO_BUILD_DOCS=0 " +
      "-DUSER_C_MODULES=${ulab_src}/code/micropython.cmake";

    builder = ./base_builder.sh;
  };

  image = pkgs.stdenv.mkDerivation {
    name = "micropython" + base.name_suffix;
    board_name = "Pololu 3pi+ 2040 Robot";
    start_url = "https://www.pololu.com/3pi/start";
    inherit date base example_code;
    bin2uf2 = ./bin2uf2.rb;
    buildInputs = [ pkgs.dosfstools pkgs.libfaketime pkgs.mtools pkgs.ruby ];
    builder = ./image_builder.sh;
  };

  # Run this to avoid having useful things garbage collected:
  #   nix-build -A gcroots --out-link gcroots
  gcroots = pkgs.mkShell {
    buildInputs = base.buildInputs ++ image.buildInputs;
    inherit example_code;
    inherit (base) src lib_mbedtls lib_micropython_lib lib_pico_sdk lib_tinyusb ulab_src;
  };

in rec {
  pololu-3pi-2040-robot = image // { inherit base; };

  inherit gcroots;

  # Aliases:
  p3pi = pololu-3pi-2040-robot;
}
