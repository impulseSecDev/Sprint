# ============================================================
# Actual - Server Docker Container for NixOS
# ============================================================

{ config, lib, pkgs, ... }:

{
  sops.secrets = {
    "homepage_auth_secret" = { };
    "homepage_auth_password" = { };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/actual 0750 986 986 -"
  ];

  virtualisation.oci-containers = {
    backend = "docker";
    containers.actual = {
      image = "docker.io/actualbudget/actual-server:latest";
      user = "1000:1000";
      volumes = [
        "/var/lib/actual:/data" 
      ];
      ports = [ "5006:5006" ];
      restart: unless-stopped
    };
  };
}

