{ config, pkgs, lib, ... }:
{

  # needed so docker can access internet
  boot.kernel.sysctl."net.ipv4.ip_forward" = true;

  sops.secrets."age_key" = {};
  sops.secrets."gitlab/url" = {};
  sops.secrets."gitlab/registration_token" = {};
  sops.secrets."tf_token" = {};

  scott.sops.envFiles.gitlab-runner = {
    vars = {
      CI_SERVER_URL = "gitlab/url";
      REGISTRATION_TOKEN = "gitlab/registration_token";
    };
    requiredBy = [ "gitlab-runner.service" ];
  };

  services.gitlab-runner.enable = true;
  # runner for building in docker via host's nix-daemon
  # nix store will be readable in runner, might be insecure
  services.gitlab-runner.services.nix = {
    registrationConfigFile = "/run/secrets/gitlab-runner.env";
    dockerImage = "alpine";
    dockerVolumes = [
      "/nix/store:/nix/store:ro"
      "/nix/var/nix/db:/nix/var/nix/db:ro"
      "/nix/var/nix/daemon-socket:/nix/var/nix/daemon-socket:ro"
    ];
    dockerDisableCache = true;
    preBuildScript = pkgs.writeScript "setup-container" ''
      mkdir -p -m 0755 /nix/var/log/nix/drvs
      mkdir -p -m 0755 /nix/var/nix/gcroots
      mkdir -p -m 0755 /nix/var/nix/profiles
      mkdir -p -m 0755 /nix/var/nix/temproots
      mkdir -p -m 0755 /nix/var/nix/userpool
      mkdir -p -m 1777 /nix/var/nix/gcroots/per-user
      mkdir -p -m 1777 /nix/var/nix/profiles/per-user
      mkdir -p -m 0755 /nix/var/nix/profiles/per-user/root
      mkdir -p -m 0700 "$HOME/.nix-defexpr"
      mkdir -p -m 0755 /etc/nix
      echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf
      . ${pkgs.nix}/etc/profile.d/nix-daemon.sh
      ${pkgs.nix}/bin/nix-env -i ${builtins.concatStringsSep " " (with pkgs; [ nix cacert git openssh bash ])}
    '';
    environmentVariables = {
      ENV = "/etc/profile";
      USER = "root";
      NIX_REMOTE = "daemon";
      PATH = "/nix/var/nix/profiles/default/bin:/nix/var/nix/profiles/default/sbin:/bin:/sbin:/usr/bin:/usr/sbin";
      NIX_SSL_CERT_FILE = "/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt";
    };
    registrationFlags = [
      "--env SOPS_AGE_KEY=$(cat ${config.sops.secrets."age_key".path})"
      "--env TF_TOKEN_app_terraform_io=$(cat ${config.sops.secrets."tf_token".path})"
    ];
    tagList = [ "nix" ];
  };
}