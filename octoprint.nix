# ============================================================
# octoprint.nix — Ocotoprint Basic Module.
# ============================================================

{ config, lib, pkgs, ... }:

{
  services.octoprint = {
    enable = true;
    host = "127.0.0.1";
    port = 6899;
  };
}
