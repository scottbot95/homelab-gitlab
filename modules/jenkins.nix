{ config, options, pkgs, ... }:
{
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