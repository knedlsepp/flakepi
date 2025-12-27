{ n64-unfloader-src, ... }@inputs:
self: super:
let
  n64-unfloader-pkg = super.stdenv.mkDerivation rec {
    pname = "n64-unfloader";
    version = "master";

    src = inputs.n64-unfloader-src;

    nativeBuildInputs = with super; [
      makeWrapper
      pkg-config
      gnumake
    ];

    buildInputs = with super; [
      libftdi1
      libusb1
      ncurses
      eudev
    ];

    installPhase = ''
      cd UNFLoader
      make install PREFIX=$out
    '';

    meta = with super.lib; {
      description = "N64 UNFLoader - Nintendo 64 ROM format converter";
      homepage = "https://github.com/buu342/N64-UNFLoader";
      license = licenses.gpl3;
      platforms = platforms.all;
    };
  };

in
{
  inherit (super) lib;
  n64-unfloader = n64-unfloader-pkg;
}
