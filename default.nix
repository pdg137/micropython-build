let
  # This date is used to identify releases.  It gets baked into the filenames,
  # file system timestamps, and `sys.version` in Python.
  date = "2023-04-05";

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
    rev = "c81c49a8f588ef88c0a36164b085bd95bff44850";  # 2023-03-08
    hash = "sha256-aSyOwxQdSawV7yFH7oDjvyWYzc1HpkD0a560YouaUyo=";
  };

  base = pkgs.stdenv.mkDerivation rec {
    name = "micropython-base" + name_suffix;
    name_suffix = "-pololu-3pi-2040-robot-${version}-${short_date}";

    inherit date;

    src = pkgs.fetchFromGitHub {
      owner = "micropython";
      repo = "micropython";
      rev = "c046b23ea29e0183c899a8dbe1da3bed3440a255";  # master branch, 2023-04-04
      hash = "sha256-goEiILB0EiqodvC9MlvjoD7cb9QCBqJRUfkDuXCA1ss=";
    };
    patches = [ ./3pi_2040.patch ];

    # After changing the MicroPython version above, run
    # 'git describe --tags --match=v*' to get the new values for these:
    version = "v1.19.1";
    version_suffix = "-1008";
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
      rev = "1bc2c9cb8b8fe4659bd94b8ebba5a4c02029b7fa";
      hash = "sha256-DiX++cDFRHfx67BDRMDd03G62aGvwAzqkgFWenroRAw=";
    };
    lib_micropython_lib = pkgs.fetchFromGitHub {
      owner = "micropython";
      repo = "micropython-lib";
      rev = "c8603192d1d142fdeb7f9578e000c9834669a082";
      hash = "sha256-BYtZoElqYLqgtN+ymP1ta/FYqUQPBD9Bb79+HPqGKNk=";
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
      rev = "8585407df9b7a25aba19b6a6ac7136f577f3d1e6";  # 2023-03-03
      hash = "sha256-F26l06uHxtkVKtt/juOlNolD57znSNRBBCImkIlCAYM=";
    };

    # After changing the ulab version, run
    # 'git describe --tags' to get the new value of this:
    ulab_git_tag = "5.1.1-21-g" + builtins.substring 0 7 ulab_src.rev;

    MICROPY_BANNER_NAME_AND_VERSION =
      "MicroPython ${MICROPY_GIT_TAG} build ${build_git_tag}; with ulab ${ulab_git_tag}";

    MICROPY_BOARD = "POLOLU_3PI_2040_ROBOT";

    buildInputs = [ pkgs.cmake pkgs.gcc pkgs.gcc-arm-embedded pkgs.python3 ];

    cmake_flags = "-DMICROPY_BOARD=${MICROPY_BOARD} " +
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

in rec {
  pololu-3pi-2040-robot = image // { inherit base; };

  # Aliases:
  p3pi = pololu-3pi-2040-robot;
}
