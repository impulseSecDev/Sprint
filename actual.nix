# ============================================================
# Actual - Server Docker Container for NixOS
# ============================================================

{ config, lib, pkgs, ... }:

{
  users.users.actual = {
    isSystemUser = true;
    group = "actual";
    uid = 986;
  };
  users.groups.actual.gid = 986;

  systemd.tmpfiles.rules = [
    "d /var/lib/actual 0750 actual actual -"
  ];


  virtualisation.oci-containers = {
    backend = "docker";
    containers.actual = {
      image = "docker.io/actualbudget/actual-server:latest";
      user = "986:986";
      volumes = [
        "/var/lib/actual:/data" 
      ];
      ports = [ "127.6.0.1:5006:5006" ];
    };
  };
}

