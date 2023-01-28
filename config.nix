{ config, lib, ... }:
let
  hostname = "gitlab";
  extractSecret = secret: "\${data.sops_file.secrets.data[\"${secret}\"]}";
in {
  options = {
    terraform-nixos = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      description = "Path to terraform-nixos module. Must be set if deploy_nixos is enabled";
    };
  };

  config = {
    # terraform.cloud = {
    #   organization = "faultymuse-homelab";
    #   workspaces.name = "gitlab-test";
    # };
    terraform.required_providers = {
      proxmox = {
        source = "telmate/proxmox";
        version = "2.9.6";
      };
      sops = {
        source = "carlpett/sops";
        version = "0.7.2";
      };
    };

    provider.sops = {};

    data.sops_file.secrets = {
      source_file = "secrets.yaml";
    };

    provider.proxmox = {
      pm_api_url = "https://pve.faultymuse.com:8006/api2/json";
      pm_api_token_id = extractSecret "pm_api_token_id";
      pm_api_token_secret = extractSecret "pm_api_token_secret";

      pm_log_enable = true;
      pm_log_file = "terraform-plugin-proxmox.log";
      pm_log_levels = {
        _default = "debug";
        _capturelog = "";
      };
    };

    resource.tls_private_key.state_ssh_key = {
      algorithm = "RSA";
      rsa_bits = 4096;
    };

    resource.proxmox_vm_qemu.${hostname} = {
      name        = hostname;
      target_node = "pve";
      # iso = "local:iso/nixos-23.05.20221229.677ed08-x86_64-linux.isonixos.iso";
      clone = "nixos-23.05.20230127.8a828fc";
      full_clone = true;
      bios = "ovmf";
      os_type = "cloud-init";
      cores = 8;
      memory = 4096;
      agent = 1; # enable qemu-agent

      network = {
        model = "virtio";
        bridge = "vmbr0";
        tag = 20;
        firewall = false;
      };

      sshkeys = "\${tls_private_key.state_ssh_key.public_key_openssh}";
      # storage = "nvme0";
    };

    module.deploy_nixos = {
      source = config.terraform-nixos;
      flake = ".";
      flake_host = hostname;
      target_host = "\${proxmox_vm_qemu.${hostname}.ssh_host}";
      target_user = "root";
      ssh_private_key = "\${tls_private_key.state_ssh_key.private_key_openssh}";
      ssh_agent = false;
    };
  };
}
