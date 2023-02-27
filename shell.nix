# Run nix-shell to use this: it provides an environment for
# building MicroPython manually in NixOS.
let
  pkgs = import <nixpkgs> {};
in
  pkgs.mkShell rec {
    buildInputs = [ pkgs.cmake pkgs.gcc pkgs.gcc-arm-embedded pkgs.python3 ];
  }
