let

  # This date is used to identify releases.  It gets baked into the filenames,
  # file system timestamps, and `sys.version` in Python.
  date = "2023-11-13";

  short_date = (builtins.substring 2 2 date) +
    (builtins.substring 5 2 date) + (builtins.substring 8 2 date);

  build_git_tag = if builtins.getEnv "COMMIT" == "" then
    builtins.throw "Be sure to use build.sh.  See README." else
    short_date + "-" + builtins.getEnv "COMMIT";

  # nixos-22.11 branch, 2022-12-14
  nixpkgs = import (fetchTarball
    "https://github.com/NixOS/nixpkgs/archive/170e39462b516bd1475ce9184f7bb93106d27c59.tar.gz");
  pkgs = nixpkgs {};

  micropython = {
    src = pkgs.fetchFromGitHub {
      owner = "micropython";
      repo = "micropython";
      rev = "05cb1406ad1b421a238faf763e19f4119f5f6bb2";  # master branch, 2023-10-11
      hash = "sha256-zgaa1sRGTyBGDrBFrhiUvuDYe1YGkJcbmFmuhieRBZc=";
    };
    patches = [ ./mpy-boards.patch ./mpy-traceback.patch ];

    # After changing the MicroPython version above, run
    # 'git describe --tags --match=v*' to get the new values for these:
    version = "v1.22.0-preview";
    version_suffix = "-8";
  };

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
    rev = "e025c843b60e93689f0f991d753010bb5bd6a722";
    hash = "sha256-ilKBoIQy3xW+s5djp0jShjO/G29vASfUn6gBoHedMxk=";
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
    rev = "a05ec05351260cf48fefc347265b8d8bf29c03f1";  # 2023-08-10
    hash = "sha256-jo9eowplUgKOmdUFJsoDkEI7s7HvaH5Ya3tHxVoXN8k=";
  };

  # After changing the ulab version, look in its docs/ulab-change-log.md
  # file to get the new version of this.
  ulab_git_tag = "6.4.0" + builtins.substring 0 7 ulab_src.rev;

  board = { board_name, file_name, MICROPY_BOARD, example_code, start_url }:
    let
      base = pkgs.stdenv.mkDerivation rec {
        name = "micropython-base" + name_suffix;
        name_suffix = "-${file_name}-${version}-${short_date}";

        inherit MICROPY_BOARD date;
        inherit (micropython) src patches version version_suffix;

        MICROPY_GIT_HASH = builtins.substring 0 9 src.rev;
        MICROPY_GIT_TAG = version + version_suffix + "-g" + MICROPY_GIT_HASH;

        inherit lib_mbedtls lib_micropython_lib lib_pico_sdk pico_sdk_patches lib_tinyusb ulab_src ulab_git_tag;

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
      rev = "bf2688c366d4986be37e88ee364e237050a11e6b";  # 2023-11-13
      hash = "sha256-/e8KfNVponv1Crf67B5z/3PCRMo60oHCOpiIeU3+fPM=";
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
      rev = "629845142ddc44e34f1340484afa8a22eab89d57";  # 2023-11-13
      hash = "sha256-C044Eo3TCdePG3qZVKLUju8tNbDlhaSGfuJnGT0ztog=";
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
