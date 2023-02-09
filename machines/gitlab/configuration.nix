{ config, lib, pkgs, ...}: {
  imports = [
    # ../../modules/gitlab-runner.nix
    # ../../modules/gitlab-web.nix
    ../../modules/jenkins.nix
  ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    autoResize = true;
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/ESP";
    fsType = "vfat";
  };

  networking.hostName = "gitlab";

  sops.defaultSopsFile = ../../secrets.yaml;

  scott.sops.enable = true;
  scott.sops.ageKeyFile = "/var/keys/age";  

  virtualisation.docker.enable = true;

  system.stateVersion = "23.05";
}