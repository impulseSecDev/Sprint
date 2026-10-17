# ============================================================
# IT-Tools.nix
# ============================================================

{ config, lib, pkgs, ... }:

{
  # OCI Container Definition
  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      it-tools = {
        image = "ghcr.io/corentinth/it-tools:latest";
        ports = [ "11379:80" ];
        autoStart = true;
      };
    };
  };
}
