let
  # This date is used to identify releases.  It gets baked into the filenames,
  # file system timestamps, and `sys.version` in Python.  Update it when
  # making a new release.
  date = "2023-02-27";

  short_date = (builtins.substring 2 2 date) +
    (builtins.substring 5 2 date) + (builtins.substring 8 2 date);

  build_git_tag = short_date + "-" + builtins.getEnv "COMMIT";

  # 2022-12-14, nixos-22.11 branch
  nixpkgs = import (fetchTarball
    "https://github.com/NixOS/nixpkgs/archive/170e39462b516bd1475ce9184f7bb93106d27c59.tar.gz");
  pkgs = nixpkgs {};

  example_code = fetchGit {
    url = "${builtins.getEnv "POLOLU_VCS"}pololu-3pi-plus-2040-robot-example-code";
    ref = "master";
    rev = "69336542612368dcd6d09cef9896bd38bd7a9734";  # 2023-02-27
  };

  base = pkgs.stdenv.mkDerivation rec {
    name = "micropython-base" + name_suffix;
    name_suffix = "-pololu-3pi+-2040-robot-${version}-${short_date}";

    inherit date;

    src = pkgs.fetchFromGitHub {
      owner = "pdg137";  # TODO: move to pololu
      repo = "micropython";
      rev = "228269a7b933a813349e0be45a8d7b7eab048cfc";  # 2023-02-24
      hash = "sha256-rgmJUILVnRh94CT2fAJPVQ3APgxNP0ONaYaa0h/n1uQ=";
    };

    # After changing the micropython version, run
    # 'git describe --tags' to get the new values for these:
    version = "v1.19.1";
    version_suffix = "-847";
    MICROPY_GIT_TAG = version + version_suffix + "-g" + MICROPY_GIT_HASH;
    MICROPY_GIT_HASH = builtins.substring 0 9 src.rev;

    # Submodules of micropython needed by the RP2 port.
    # We could try 'fetchSubmodules = true;' above but that would fetch lots of repositories
    # we don't need, and it won't work with submodules that come from private URLs.
    #
    # After changing the Micropython version, get the info you need to update this by
    # running in the Micropython repository:
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
      rev = "038b4ac6572d0d5b4c18148dc7d7fdc026369fa4";
      hash = "sha256-LLSxEKF4wENO7C9kL3F3oDHl/2dzUNJf6SnbVdx0lTc=";
    };
    lib_pico_sdk = pkgs.fetchFromGitHub {
      owner = "pdg137";  # TODO: move to pololu
      repo = "pico-sdk";
      rev = "48c7f53957e6a249425d4778d926ccd6c981bf42";
      hash = "sha256-NgAsatPA+KEMOawgimphjHnw5EyrpcIrY8MKUDl0a9k=";
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

    MICROPY_BOARD = "POLOLU_3PI+_2040_ROBOT";

    buildInputs = [ pkgs.cmake pkgs.gcc pkgs.gcc-arm-embedded pkgs.python3 ];

    cmake_flags = "-DMICROPY_BOARD=${MICROPY_BOARD} " +
      "-DPICO_BUILD_DOCS=0 " +
      "-DUSER_C_MODULES=${ulab_src}/code/micropython.cmake";

    builder = ./base_builder.sh;
  };

  image = pkgs.stdenv.mkDerivation {
    name = "micropython" + base.name_suffix;
    inherit date;
    base_bin = "${base}/${base.name}.bin";
    demo = "${example_code}/micropython_demo";
    bin2uf2 = ./bin2uf2.rb;
    buildInputs = [ pkgs.dosfstools pkgs.libfaketime pkgs.mtools pkgs.ruby ];
    builder = ./image_builder.sh;
  };

in rec {
  pololu-3pi-plus-2040-robot = image // { inherit base; };

  # Aliases:
  p3pi = pololu-3pi-plus-2040-robot;
}
