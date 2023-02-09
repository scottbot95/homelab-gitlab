{ config, options, pkgs, ... }:
{
  sops.secrets."age_key" = {};
  sops.secrets."tf_token" = {};

  scott.sops.envFiles.jenkins = {
    vars = {
      SOPS_AGE_KEY = "age_key";
      TF_TOKEN_app_terraform_io = "tf_token";
    };
    requiredBy = [ "jenkins.service" ];
  };

  services.jenkins = {
    enable = true;
    packages = options.services.jenkins.packages.default ++ (with pkgs; [
      bash
    ]);
    environment = {
      NIX_CONFIG = ''
        experimental-features = nix-command flakes
      '';
    };
    extraJavaOptions = [
      "-Dorg.jenkinsci.plugins.durabletask.BourneShellScript.LAUNCH_DIAGNOSTICS=true"
    ];
  };

  systemd.services.jenkins = { 
    serviceConfig.EnvironmentFile = "/run/secrets/jenkins.env";
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    virtualHosts = {
      "${config.networking.hostName}.prod.faultymuse.com" = {
        locations."/".proxyPass = "http://localhost:8080";
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 ];
}