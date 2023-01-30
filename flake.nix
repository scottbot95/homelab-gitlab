{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    terranix = {
      url = "github:terranix/terranix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    homelab-ci.url = "github:scottbot95/homelab-ci";
    homelab-ci.inputs.nixpkgs.follows = "nixpkgs";

    terranix-proxmox.url = "github:scottbot95/terranix-proxmox";
    terranix-proxmox.inputs.nixpkgs.follows = "nixpkgs";
    terranix-proxmox.inputs.terranix.follows = "terranix";
  };

  outputs = { self, nixpkgs, flake-utils, terranix, homelab-ci, terranix-proxmox }:
    (flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        terraform = pkgs.terraform;
        terranixConfigArgs = {
          inherit system;
          modules = [ 
            ./config.nix
            terranix-proxmox.terranixModule
          ];
        };
        terraformConfiguration = terranix.lib.terranixConfiguration terranixConfigArgs;
        terranixApp = {
          command,
          name ? command,
          config ? terraformConfiguration,
        }: {
          type = "app";
          program = toString (pkgs.writers.writeBash name ''
            if [[ -e config.tf.json ]]; then rm -f config.tf.json; fi
            cp ${config} config.tf.json \
              && ${terraform}/bin/terraform init \
              && ${terraform}/bin/terraform ${command} "$@"
          '');
        };
      in
      {
        defaultPackage = terraformConfiguration;
        # nix develop
        devShell = pkgs.mkShell {
          buildInputs = [
            pkgs.jq
            terraform
            terranix.defaultPackage.${system}
          ];
        };
        # nix run ".#build"
        apps.build = {
          type = "app";
          program = toString (pkgs.writers.writeBash "build" ''
            if [[ -e config.tf.json ]]; then rm -f config.tf.json; fi
            cp ${terraformConfiguration} config.tf.json
          '');
        };
        # nix run ".#apply"
        apps.apply = terranixApp { command ="apply"; };
        # nix run ".#destroy"
        apps.destroy = terranixApp { command = "destroy"; };
        # nix run
        defaultApp = self.apps.${system}.apply;
      })) // {
        nixosConfigurations.gitlab = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [ 
            ./configuration.nix
            homelab-ci.nixosModules.proxmox-guest-profile
          ];
        };
      };
}
