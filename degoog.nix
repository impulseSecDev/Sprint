# ============================================================
# degoog.nix — Modularized Stack for Searxng, Degoog, gluetun.
# ============================================================

{ config, lib, pkgs, ... }:

{
          
  virtualisation.docker.enable = true;

  sops.secrets = {
    protonvpn_private_key = {
      restartUnits = [ "docker-protonvpn.service" ];
    };
    degoog_settings_password = { };
  };

  sops.templates."degoog.env".content = ''
    DEGOOG_SETTINGS_PASSWORDS=${config.sops.placeholder.degoog_settings_password}
    DEGOOG_PUBLIC_INSTANCE=false
  '';

  virtualisation.oci-containers.backend = "docker";
  virtualisation.oci-containers.containers = {
    protonvpn = {
      image = "qmcgaw/gluetun:latest";
      autoStart = true;
      extraOptions = [
        "--cap-add=NET_ADMIN"
        "--device=/dev/net/tun:/dev/net/tun"
      ];
      ports = [
        "63497:8080" # SearXNG web interface
        "27099:4444" # Degoog web interface
      ];
      volumes = [
          "${config.sops.secrets.protonvpn_private_key.path}:/run/secrets/protonvpn_private_key:ro"
        ];
      environment = {
        VPN_SERVICE_PROVIDER = "protonvpn";
        VPN_TYPE = "wireguard";
        SERVER_COUNTRIES = "United States";
      };
      environmentFiles = [
        config.sops.secrets.protonvpn_private_key.path
      ];
    };

    searxng = {
      image = "docker.io/searxng/searxng:latest";
      autoStart = true;
      dependsOn = [ "protonvpn" ];
      extraOptions = [
        "--network=container:protonvpn"
      ];
      volumes = [
        "/var/lib/searxng:/etc/searxng"
      ];
      environment = {
        BASE_URL = "http://localhost:8080/";
        SEARXNG_BIND_ADDRESS = "127.0.0.1:8080";
      };
    };

    degoog = {
      image = "ghcr.io/degoog-org/degoog:latest";
      autoStart = true;
      dependsOn = [ "protonvpn" ];
      environmentFiles = [ config.sops.templates."degoog.env".path ];
      extraOptions = [
        "--network=container:protonvpn"
      ];
      volumes = [
        "/var/lib/degoog:/app/data"
      ];
    };
  };

  # Daily VPN IP Rotation Systemd Timer & Service
  systemd.services.protonvpn-rotate = {
    description = "Rotate ProtonVPN IP by restarting Gluetun";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.docker}/bin/docker restart docker-protonvpn";
    };
  };

  systemd.timers.protonvpn-rotate = {
    description = "Hourly ProtonVPN IP Rotation Timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };

}
