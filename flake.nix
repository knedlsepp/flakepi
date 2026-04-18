{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixos-hardware.url = "github:nixos/nixos-hardware";
    summercart64.url = "github:Polprzewodnikowy/SummerCart64";
    summercart64.flake = false;

    llm-agents.url = "github:numtide/llm-agents.nix";
  };
  outputs = { self, nixpkgs, nixos-hardware, llm-agents, summercart64 }: {
    nixosConfigurations = {
      sempfberry = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          ({ pkgs, ... }: {
            nixpkgs.overlays = [
              (import ./overlays/sc64deployer.nix { inherit summercart64; summercart64-src = summercart64; })
            ];
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

    devShells = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system: {
      default =
        let
          pkgs = import nixpkgs { inherit system; };
        in
        pkgs.mkShell {
          packages = with pkgs; [
            (llm-agents.packages.${system}.mistral-vibe)
          ];
        };
    });
  };
}

