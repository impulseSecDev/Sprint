{
  description = "Sprint (Search Engines & Printing Services) NixOS configuration";

  # Build image
  # nix build .#nixosConfigurations.sprint.config.system.build.sdImage

  # Flash Image 
  # sudo dd if=result/sd-image/nixos-image-sd-card-26.05.20260807.ee48b14-aarch64-linux.img of=/dev/sdb bs=4M status=progress conv=fsync

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";

    # refer to https://github.com/nvmd/nixos-raspberrypi for documentation on nixos-raspberrypi
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  nixConfig = {
    extra-substituters = [
      "https://nixos-raspberrypi.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };

  outputs = inputs@{ nixpkgs, nixos-raspberrypi, sops-nix, ... }: {
    nixosConfigurations.sprint = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = { inherit (inputs) nixos-raspberrypi; };
      modules = [
        ./configuration.nix
        sops-nix.nixosModules.sops
        "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
        ({ pkgs, lib, ... }: {
          sdImage.compressImage = false;
          sdImage.firmwareSize = 1024;
          imports = with nixos-raspberrypi.nixosModules; [
            nixos-raspberrypi.lib.inject-overlays 
            trusted-nix-caches
            raspberry-pi-4.base
          ];
        })
      ];
    };
  };
}
