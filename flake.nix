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

    sops-nix.url = github:Mic92/sops-nix;
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    terranix-proxmox.url = "github:scottbot95/terranix-proxmox";
    terranix-proxmox.inputs.nixpkgs.follows = "nixpkgs";
    terranix-proxmox.inputs.terranix.follows = "terranix";
  };

  outputs = { self, nixpkgs, flake-utils, terranix, homelab-ci, terranix-proxmox, sops-nix }:
    (flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        sops = "${pkgs.sops}/bin/sops";
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
            set -e
            if [[ -e config.tf.json ]]; then rm -f config.tf.json; fi
            cp ${config} config.tf.json 

            export PATH=${pkgs.jq}/bin:$PATH
            export TF_TOKEN_app_terraform_io=$(${sops} --extract '["tf_token"]' -d secrets.yaml)

            ${terraform}/bin/terraform init 
            ${terraform}/bin/terraform ${command} "$@"
          '');
        };
      in
      {
        packages.tf-config = terraformConfiguration;
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
        # nix run ".#plan"
        apps.plan = terranixApp { command = "plan"; };
        # nix run
        defaultApp = self.apps.${system}.apply;

        packages.prebuild = 
          let
            machines = pkgs.lib.filterAttrs (_: machine: machine.pkgs.system == system) self.nixosConfigurations;
            linkMachines = pkgs.lib.mapAttrsToList (name: machine: "ln -s ${machine.config.system.build.toplevel} $out/${name}") machines;
          in derivation {
            inherit system;
            name = "prebuild";
            PATH = "${pkgs.coreutils}/bin";
            builder = pkgs.writeShellScript "prebuild" ''
              mkdir -p $out
              ln -s ${terraformConfiguration} $out/config.tf.json
              ${builtins.concatStringsSep "\n" linkMachines}
            '';
          };
      })) // {
        nixosConfigurations.gitlab = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [ 
            ./machines/gitlab/configuration.nix 
            homelab-ci.nixosModules.proxmox-guest-profile
            homelab-ci.nixosModules.sops
            sops-nix.nixosModules.sops
          ];
        };

        # packages.x86_64-linux.pre-build = 
      };
}
