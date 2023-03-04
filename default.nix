let
  # This date is used to identify releases.  It gets baked into the filenames,
  # file system timestamps, and `sys.version` in Python.  Update it when
  # making a new release.
  date = "2023-03-02";

  short_date = (builtins.substring 2 2 date) +
    (builtins.substring 5 2 date) + (builtins.substring 8 2 date);

  build_git_tag = if builtins.getEnv "COMMIT" == "" then
    builtins.throw "Be sure to use build.sh.  See README." else
    short_date + "-" + builtins.getEnv "COMMIT";

  # 2022-12-14, nixos-22.11 branch
  nixpkgs = import (fetchTarball
    "https://github.com/NixOS/nixpkgs/archive/170e39462b516bd1475ce9184f7bb93106d27c59.tar.gz");
  pkgs = nixpkgs {};

  example_code = fetchGit {
    url = "git@github.com:pololu/pololu-3pi-2040-robot";
    ref = "master";
    rev = "a65580998e9ffee5881b6d3c787ce3086d42b038";  # 2023-03-02
  };

  base = pkgs.stdenv.mkDerivation rec {
    name = "micropython-base" + name_suffix;
    name_suffix = "-pololu-3pi-2040-robot-${version}-${short_date}";

    inherit date;

    src = pkgs.fetchFromGitHub {
      owner = "pololu";
      repo = "micropython";
      rev = "c9526d9d6e3e8c78f9267c4a52f41959e476b5cb";  # 3pi branch, 2023-03-02
      hash = "sha256-0vs7TjcQ1XPffDz2G0TqKLUwiy3wqCbq5Lul/1R4jB8=";
    };

    # After changing the MicroPython version above, run
    # 'git describe --tags --match=v*' to get the new values for these:
    version = "v1.19.1";
    version_suffix = "-902";
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
      rev = "c1526d2d1eb68c4c3b0ff8940b012c98a80301f1";
      hash = "sha256-NRMbQJH4Fx9Bl8KEHQ1yzdvb6bRyLw9SC1xjURXy41I=";
    };
    lib_pico_sdk = pkgs.fetchFromGitHub {
      owner = "pololu";
      repo = "pico-sdk";
      rev = "61d5b1a2105b966c59b7da92e826aac972ea3add";
      hash = "sha256-nRtVjnotbmApCb1U/s8N0kQixLArPs90zHRWQ7BlckU=";
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
      rev = "f2dd2230c4fdf1aa5c7a160782efdde18e8204bb";  # 2023-01-23
      hash = "sha256-JxH1mpFJDxCKp/CXSsQVEqCmtRZiiEvnsm6eDbi3jwo=";
    };

    # After changing the ulab version, run
    # 'git describe --tags' to get the new value of this:
    ulab_git_tag = "5.1.1-20-g" + builtins.substring 0 7 ulab_src.rev;

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
