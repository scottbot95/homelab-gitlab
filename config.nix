{ config, lib, terraform-nixos, ... }:
let
  hostname = "gitlab";
  extractSecret = secret: "\${data.sops_file.secrets.data[\"${secret}\"]}";
in {
  # terraform.cloud = {
  #   organization = "faultymuse-homelab";
  #   workspaces.name = "gitlab-test";
  # };
  terraform.required_providers = {
    sops = {
      source = "carlpett/sops";
      version = "0.7.2";
    };
  };

  provider.sops = {};

  data.sops_file.secrets = {
    source_file = "secrets.yaml";
  };

  proxmox = {
    provider = {
      endpoint = "https://pve.faultymuse.com:8006/api2/json";
      token_id = extractSecret "pm_api_token_id";
      token_secret = extractSecret "pm_api_token_secret";
      log_level = "debug";
    };

    qemu.gitlab = {
      enable = true;
      agent = true;
      target_node = "pve";
      flake = toString ./.;
      clone = "nixos-23.05.20230127.8a828fc";
      full_clone = true;
      bios = "ovmf";
      os_type = "cloud-init";
      cores = 8;
      memory = 4096;

      network = [{
        model = "virtio";
        bridge = "vmbr0";
        tag = 20;
        firewall = false;
      }];
    };
  };
}