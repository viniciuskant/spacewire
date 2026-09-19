{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  packages = with pkgs; [
    verilator
    zlib
    gcc
    gnumake
    iverilog
    gtkwave
  ];

  C_INCLUDE_PATH = "${pkgs.zlib}/include";
  LIBRARY_PATH = "${pkgs.zlib}/lib";
}
