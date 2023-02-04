{ config, lib, pkgs, ...}: {
  imports = [
    ../../modules/gitlab-runner.nix
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

  networking.hostName = "bob-the-builder";

  sops.defaultSopsFile = ../../secrets.yaml;

  scott.sops.enable = true;
  scott.sops.ageKeyFile = "/var/keys/age";  

  # users.users.root.openssh.authorizedKeys.keys = [
  #   "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICnt0c1V/ZZFW5J3HGqqxDwr6zoq5ouB5uB7IFXxZqdB cardno:18_978_827"
  # ];

  virtualisation.docker.enable = true;

  system.stateVersion = "23.05";
}