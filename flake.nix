{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixos-hardware.url = "github:nixos/nixos-hardware";
    n64-unfloader.url = "github:buu342/N64-UNFLoader";
    n64-unfloader.flake = false;
  };
  outputs = { self, nixpkgs, nixos-hardware, n64-unfloader }: {
    nixosConfigurations = {
      sempfberry = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          ({ pkgs, ... }: {
            nixpkgs.overlays = [ (import ./overlays/n64-unfloader.nix { inherit n64-unfloader; n64-unfloader-src = n64-unfloader; }) ];
          })
          nixos-hardware.nixosModules.raspberry-pi-4
          ./configuration.nix
          ./base.nix
        ];
      };
    };

    images = {
      sempfberry = (self.nixosConfigurations.sempfberry.extendModules {
        modules = [ "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64-new-kernel-no-zfs-installer.nix" ];
      }).config.system.build.sdImage;
    };
  };
}

