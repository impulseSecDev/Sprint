# ============================================================
# Homepage Docker Container for NixOS
# ============================================================

{ config, lib, pkgs, ... }:

{
  sops.secrets = {
    "homepage_auth_secret" = { };
    "homepage_auth_password" = { };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/homepage 0750 986 986 -"
  ];

  sops.templates."homepage.env".content = ''
    HOMEPAGE_AUTH_SECRET=${config.sops.placeholder."homepage_auth_secret"}
    HOMEPAGE_AUTH_PASSWORD=${config.sops.placeholder."homepage_auth_password"}
  '';

  virtualisation.oci-containers = {
    backend = "docker";
    containers.homepage = {
      image = "ghcr.io/gethomepage/homepage:latest";
      volumes = [ "/var/lib/homepage:/app/config" ];
      ports = [ "3000:3000" ];
      environment = {
        HOMEPAGE_ALLOWED_HOSTS = "gethomepage.dev,home.mesh.loranjennings.com";
        HOMEPAGE_AUTH_ENABLED = "true";
        HOMEPAGE_EXTERNAL_URL = "https://home.mesh.loranjennings.com";
        PUID = "986";
        PGID = "986";
      };
      environmentFiles = [ config.sops.templates."homepage.env".path ];
      extraOptions = [ "--network=host" ];
    };
  };
}

