let

  # This date is used to identify releases.  It gets baked into the filenames,
  # file system timestamps, and `sys.version` in Python.
  date = "2024-01-17";

  short_date = (builtins.substring 2 2 date) +
    (builtins.substring 5 2 date) + (builtins.substring 8 2 date);

  build_git_tag = if builtins.getEnv "COMMIT" == "" then
    builtins.throw "Be sure to use build.sh.  See README." else
    short_date + "-" + builtins.getEnv "COMMIT";

  # nixos-23.11 branch, 2024-01-14
  nixpkgs = import (fetchTarball
    "https://github.com/NixOS/nixpkgs/archive/428544ae95eec077c7f823b422afae5f174dee4b.tar.gz");
  pkgs = nixpkgs {};

  micropython = {
    src = pkgs.fetchFromGitHub {
      owner = "micropython";
      repo = "micropython";
      rev = "9b8c64c9cee8203be167e6bffc74e186ae2fc958";  # 1.22.1 release
      hash = "sha256-tGFXJW1RkUs/64Yatgg/1zZFPDQdu76uiMjNU8ebdvg=";
    };
    patches = [ ./mpy-traceback.patch ];

    # After changing the MicroPython version above, run
    # 'git describe --tags --match=v*' to get the new values for these:
    version = "v1.22.1";
    version_suffix = ""; # e.g. "-47"
  };

  # Submodules of MicroPython needed by the RP2 port.
  # We could try 'fetchSubmodules = true;' above but that would fetch lots of repositories
  # we don't need, and it won't work with submodules that come from private URLs.
  #
  # After changing the MicroPython version, get the info you need to update this by
  # running in the MicroPython repository:
  #   cd ports/rp2 && make submodules && git submodule status --recursive | grep '^ '
  lib_berkeley_db = pkgs.fetchFromGitHub {
    owner = "pfalcon";
    repo = "berkeley-db-1.xx";
    rev = "35aaec4418ad78628a3b935885dd189d41ce779b";
    hash = "sha256-XItxmpXXPgv11LcnL7dty6uq1JctGokHCU8UGG9ic04=";
  };
  lib_mbedtls = pkgs.fetchFromGitHub {
    owner = "ARMmbed";
    repo = "mbedtls";
    rev = "981743de6fcdbe672e482b6fd724d31d0a0d2476";
    hash = "sha256-w5bJErCNRZLE8rHcuZlK3bOqel97gPPMKH2cPGUR6Zw=";
  };
  lib_micropython_lib = pkgs.fetchFromGitHub {
    owner = "micropython";
    repo = "micropython-lib";
    rev = "7cdf70881519c73667efbc4a61a04d9c1a49babb";
    hash = "sha256-XkBX+xMcaJsNs+VjNiZ8XNliMlsum8Gi+ndrxmVnM+M=";
  };
  lib_pico_sdk = pkgs.fetchFromGitHub {
    owner = "raspberrypi";
    repo = "pico-sdk";
    rev = "6a7db34ff63345a7badec79ebea3aaef1712f374";
    hash = "sha256-JNcxd86XNNiPkvipVFR3X255boMmq+YcuJXUP4JwInU=";
  };
  lib_tinyusb = pkgs.fetchFromGitHub {
    owner = "hathach";
    repo = "tinyusb";
    rev = "1fdf29075d4e613eacfa881166015263797db0f6";
    hash = "sha256-2u+ESlbKrr9dLq09Ictr6Ke/b8EHWxXKRxkLlbap+ss=";
  };

  pico_sdk_patches = [ ];

  ulab_src = pkgs.fetchFromGitHub {
    owner = "v923z";
    repo = "micropython-ulab";
    rev = "9a1d03d90d9ae1c7f676941f618d0451030354f7";  # 2024-01-16
    hash = "sha256-82Qd41jG2EBCjyGWXVO1tFpwY71mvOhQLazfl33M0pw=";
  };

  # After changing the ulab version, look in its docs/ulab-change-log.md
  # file to get the new version of this.
  ulab_git_tag = "6.5.0" + "-" + builtins.substring 0 7 ulab_src.rev;

  board = { board_name, file_name, MICROPY_BOARD, example_code, start_url }:
    let
      base = pkgs.stdenv.mkDerivation rec {
        name = "micropython-base" + name_suffix;
        name_suffix = "-${file_name}-${version}-${short_date}";

        inherit MICROPY_BOARD date;
        inherit (micropython) src patches version version_suffix;

        MICROPY_GIT_HASH = builtins.substring 0 9 src.rev;
        MICROPY_GIT_TAG = version + version_suffix + "-g" + MICROPY_GIT_HASH;

        inherit lib_berkeley_db lib_mbedtls lib_micropython_lib lib_pico_sdk pico_sdk_patches lib_tinyusb ulab_src ulab_git_tag;

        MICROPY_BANNER_NAME_AND_VERSION =
          "MicroPython ${MICROPY_GIT_TAG} build ${build_git_tag}; with ulab ${ulab_git_tag}";

        buildInputs = [ pkgs.cmake pkgs.gcc pkgs.gcc-arm-embedded pkgs.python3 ];

        cmake_flags = "-DMICROPY_BOARD=${MICROPY_BOARD} " +
          #"-DCMAKE_BUILD_TYPE=Debug " +
          "-DPICO_BUILD_DOCS=0 " +
          "-DUSER_C_MODULES=${ulab_src}/code/micropython.cmake";

        builder = ./base_builder.sh;
      };

      image = pkgs.stdenv.mkDerivation {
        name = "micropython" + base.name_suffix;
        inherit board_name start_url date base example_code;
        bin2uf2 = ./bin2uf2.rb;
        buildInputs = [ pkgs.dosfstools pkgs.libfaketime pkgs.mtools pkgs.ruby ];
        builder = ./image_builder.sh;
      };
    in image // { inherit base; };

in rec {
  pololu-3pi-2040-robot = board {
    board_name = "Pololu 3pi+ 2040 Robot";
    file_name = "pololu-3pi-2040-robot";
    MICROPY_BOARD = "POLOLU_3PI_2040_ROBOT";
    start_url = "https://www.pololu.com/3pi/start";
    example_code = pkgs.fetchFromGitHub {
      owner = "pololu";
      repo = "pololu-3pi-2040-robot";
      rev = "6ddb719da080c21d9d1fb03e9f92007a12848f24";  # 2024-01-16
      hash = "sha256-KcT2ChRHVFUHAa1h+B75kmP1wDPcyP1cxVF3IsEllxU=";
    };
  };

  pololu-zumo-2040-robot = board {
    board_name = "Pololu Zumo 2040 Robot";
    file_name = "pololu-zumo-2040-robot";
    MICROPY_BOARD = "POLOLU_ZUMO_2040_ROBOT";
    start_url = "https://www.pololu.com/zumo/start";
    example_code = pkgs.fetchFromGitHub {
      owner = "pololu";
      repo = "zumo-2040-robot";
      rev = "7bf996d4aa4180349538ab3c64980621930f6623";  # 2024-01-16
      hash = "sha256-V+vFeZ82soP77lXwHTVZks7a2DvdbjIJckPnrViBgCE=";
    };
  };

  # Run this to avoid having most of the useful things garbage collected:
  #   nix-build -A gcroots --out-link gcroots
  gcroots = pkgs.mkShell {
    buildInputs = p3pi.buildInputs ++ p3pi.base.buildInputs;
    inherit (p3pi.base) src lib_mbedtls lib_micropython_lib lib_pico_sdk lib_tinyusb ulab_src;
    p3pi_example_code = p3pi.example_code;
  };

  # Aliases:
  p3pi = pololu-3pi-2040-robot;
  zumo = pololu-zumo-2040-robot;
}
