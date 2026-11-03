{ config, pkgs, lib, ... }:
{
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  virtualisation.oci-containers.backend = "docker";
  systemd.tmpfiles.rules = [
    "d /var/lib/drawio 0750 1001 999 -"
  ];

  virtualisation.oci-containers.containers."drawio" = {
    image = "jgraph/drawio:latest";
    user = "1001:999";
    environment = {
      "DRAWIO_SERVER_URL" = "https://draw.mesh.loranjennings.com/";
    };
    volumes = [
      "/var/lib/drawio:/user/local/tomcat:rw"
    ];
    ports = [
      "127.7.0.1:8080:8080/tcp"
    ];
    log-driver = "journald";
    extraOptions = [
    ];
  };

  systemd.services."docker-drawio" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    unitConfig.Description = "Container drawio";
  };
}
