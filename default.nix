let

  # This date is used to identify releases.  It gets baked into the filenames,
  # file system timestamps, and `sys.version` in Python.
  date = "2025-01-19";

  short_date = (builtins.substring 2 2 date) +
    (builtins.substring 5 2 date) + (builtins.substring 8 2 date);

  build_git_tag = if builtins.getEnv "COMMIT" == "" then
    builtins.throw "Be sure to use build.sh.  See README." else
    short_date + "-" + builtins.getEnv "COMMIT";

  # nixos-25.11 from 2026-01-08:
  nixpkgs-version = "d351d0653aeb7877273920cd3e823994e7579b0b";
  nixpkgs = fetchTarball {
    name = "nixpkgs-${nixpkgs-version}";
    url = "https://github.com/NixOS/nixpkgs/archive/${nixpkgs-version}.tar.gz";
    sha256 = "049hhh8vny7nyd26dfv7i962jpg18xb5bg6cv126b8akw5grb0dg";
  };
  pkgs = import nixpkgs {};

  micropython = {
    src = pkgs.fetchFromGitHub rec {
      owner = "micropython";
      repo = "micropython";
      rev = "v1.27.0";
      name = "${repo}-${rev}";
      hash = "sha256-mOYiLTqb/BjDl0l7IXgFKh0Bgng/asofIhHXRly8JPU=";
    };

    patches = [
      ./mpy-traceback.patch

       # Change the Pico firmware to use a 1MB USB Mass Storage filesystem.
      ./pico-1mb-mass-storage.patch
    ];

    # After changing the MicroPython version above, run
    # 'git describe --tags --match=v*' to get the new values for these:
    version = "v1.27.0";
    version_suffix = ""; # e.g. "-47"
  };

  # Submodules of MicroPython needed by the RP2 port.
  # We could try 'fetchSubmodules = true;' above but that would fetch lots of repositories
  # we don't need, and it won't work with submodules that come from private URLs.
  #
  # After changing the MicroPython version, get the info you need to update this by
  # running in the MicroPython repository:
  #   cd ports/rp2 && make submodules && git submodule status --recursive | grep '^ '
  lib_axtls = pkgs.fetchFromGitHub rec {
    owner = "micropython";
    repo = "axtls";
    rev = "531cab9c278c947d268bd4c94ecab9153a961b43";
    name = "${repo}-${rev}";
    hash = "sha256-+Uh598l4ri6y5nwoV+bPozmpHlhpzOO2LLaRVOIj6hU=";
  };
  lib_berkeley_db = pkgs.fetchFromGitHub rec {
    owner = "pfalcon";
    repo = "berkeley-db-1.xx";
    rev = "0f3bb6947c2f57233916dccd7bb425d7bf86e5a6";
    name = "${repo}-${rev}";
    hash = "sha256-TuyxdMu34jR9p5WYHf12a+mI1ECRPjX457qwLSK2zfg=";
  };
  lib_mbedtls = pkgs.fetchFromGitHub rec {
    owner = "ARMmbed";
    repo = "mbedtls";
    rev = "107ea89daaefb9867ea9121002fbbdf926780e98";
    name = "${repo}-${rev}";
    hash = "sha256-CigOAezxk79SSTX6Z7rDnt64qI6nkCD0piY9ZVNy+e0=";
  };
  lib_micropython_lib = pkgs.fetchFromGitHub rec {
    owner = "micropython";
    repo = "micropython-lib";
    rev = "6ae440a8a144233e6e703f6759b7e7a0afaa37a4";
    name = "${repo}-${rev}";
    hash = "sha256-GyHa9Bti9LSuls6NCcpoi1TXDvVMe0zqhggHSSAEFCE=";
  };
  lib_pico_sdk = pkgs.fetchFromGitHub rec {
    owner = "raspberrypi";
    repo = "pico-sdk";
    rev = "9a4113fbbae65ee82d8cd6537963bc3d3b14bcca";
    name = "${repo}-${rev}";
    hash = "sha256-GDtUXUZMfbMcfUnIcmTdh/g5zdBXaElRkt4ceAu0hFA=";
  };
  lib_tinyusb = pkgs.fetchFromGitHub rec {
    owner = "hathach";
    repo = "tinyusb";
    rev = "aa0fc2e08f1c2dd6f026a431e8989357fbb4c5bf";
    name = "${repo}-${rev}";
    hash = "sha256-quiL2Gi6AqJUpiLXuBXSmDw9rlaHmaZqMBralSEW35g=";
  };

  pico_sdk_patches = [ ];

  ulab_src = pkgs.fetchFromGitHub rec {
    owner = "v923z";
    repo = "micropython-ulab";
    rev = "6.11.0";
    name = "${repo}-${rev}";
    hash = "sha256-KA26/ZAfjP1LvJ6OAdngc4NGD9aUHTgHU0y/Y7VX+Qs=";
  };

  # After changing the ulab version, update this string appropriately.
  # If you are not on a specific release, you can look in its
  # docs/ulab-change-log.md file to try to figure out the new version
  # and uncomment the second line below.

  ulab_git_tag = ulab_src.rev;
  # ulab_git_tag = "6.11.0" + "-" + builtins.substring 0 7 ulab_src.rev;

  board = { board_name, file_name, MICROPY_BOARD, example_code, start_url, image_size_mb }:
    let
      base = pkgs.stdenv.mkDerivation rec {
        name = "micropython-base" + name_suffix;
        name_suffix = "-${file_name}-${version}-${short_date}";

        inherit MICROPY_BOARD date;
        inherit (micropython) src patches version version_suffix;

        MICROPY_GIT_HASH = builtins.substring 0 9 src.rev;
        MICROPY_GIT_TAG = version + version_suffix + "-g" + MICROPY_GIT_HASH;

        inherit lib_axtls lib_berkeley_db lib_mbedtls lib_micropython_lib lib_pico_sdk pico_sdk_patches lib_tinyusb ulab_src ulab_git_tag;

        MICROPY_BANNER_NAME_AND_VERSION =
          "MicroPython ${MICROPY_GIT_TAG} build ${build_git_tag}; with ulab ${ulab_git_tag}";

        buildInputs = with pkgs;
          [ cmake gcc gcc-arm-embedded python3 picotool ];

        cmake_flags = "-DMICROPY_BOARD=${MICROPY_BOARD} " +
          #"-DCMAKE_BUILD_TYPE=Debug " +
          "-DPICO_BUILD_DOCS=0 " +
          "-DUSER_C_MODULES=${ulab_src}/code/micropython.cmake";

        builder = ./base_builder.sh;
      };

      image = pkgs.stdenv.mkDerivation {
        name = "micropython" + base.name_suffix;
        inherit board_name start_url date base example_code image_size_mb;
        bin2uf2 = ./bin2uf2.rb;
        buildInputs = [ pkgs.dosfstools pkgs.libfaketime pkgs.mtools pkgs.ruby ];
        builder = ./image_builder.sh;
      };
    in image // { inherit base; };

in rec {
  pico = board {
    board_name = "Raspberry Pi Pico";
    file_name = "pico";
    MICROPY_BOARD = "RPI_PICO";
    image_size_mb = "2";
    start_url = "https://www.raspberrypi.com/documentation/microcontrollers/pico-series.html";
    example_code = pkgs.fetchFromGitHub {
      owner = "pdg137";
      repo = "pico-blink-demo";
      rev = "92e56eb0498e78391e808220da9c21424685ba24";  # 2025-01-19
      hash = "sha256-pS9YovP8Ar+GdclhSqLHXY71eEODQYdE0Mg111LrQ/o=";
    };
  };

  pololu-3pi-2040-robot = board {
    board_name = "Pololu 3pi+ 2040 Robot";
    file_name = "pololu-3pi-2040-robot";
    MICROPY_BOARD = "POLOLU_3PI_2040_ROBOT";
    image_size_mb = "16";
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
    image_size_mb = "16";
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
