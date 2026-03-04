{ summercart64-src, ... }@inputs:
self: super:
let
  sc64deployer-pkg = super.rustPlatform.buildRustPackage {
    pname = "sc64deployer";
    version = "master";

    src = inputs.summercart64-src;
    sourceRoot = "source/sw/deployer";

    cargoLock = {
      lockFile = inputs.summercart64-src + "/sw/deployer/Cargo.lock";
    };
    nativeBuildInputs = with super; [
      rustPlatform.bindgenHook
      pkg-config
    ];
    buildInputs = with super; [
      udev
    ];
  };

in
{
  inherit (super) lib;
  sc64deployer = sc64deployer-pkg;
}
