{ pkgs, lib, config, ... }:

{
  sops.secrets."vikunja_db_password" = {};
  sops.secrets."vikunja_service_secret" = {};

  sops.templates."vikunja.env" = {
    content = ''
      POSTGRES_PASSWORD=${config.sops.placeholder."vikunja_db_password"}
      VIKUNJA_DATABASE_PASSWORD=${config.sops.placeholder."vikunja_db_password"}
      VIKUNJA_SERVICE_SECRET=${config.sops.placeholder."vikunja_service_secret"}
    '';
    path = "/run/secrets/vikunja.env";
    mode = "0440";
    owner = "root";
    group = "root";
  };

  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  virtualisation.oci-containers.backend = "docker";

  users.users.vikunja = {
    isSystemUser = true;
    group = "vikunja";
    uid = 992;
  };

  users.groups.vikunja = {
    gid = 992;
  };

  virtualisation.oci-containers.containers."vikunja-db" = {
    image = "postgres:18";
    environment = {
      "POSTGRES_USER" = "vikunja";
    };
    environmentFiles = [
      config.sops.templates."vikunja.env".path
    ];
    volumes = [
      "/var/lib/vikunja/db:/var/lib/postgresql:rw"
    ];
    log-driver = "journald";
    extraOptions = [
      "--health-cmd=pg_isready -h localhost -U $POSTGRES_USER"
      "--health-interval=30s"
      "--health-start-period=15s"
      "--network-alias=db"
      "--network=vikunja_default"
    ];
  };

  systemd.services."docker-vikunja-db" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "docker-network-vikunja_default.service"
      "docker.service"
    ];
    requires = [
      "docker-network-vikunja_default.service"
      "docker.service"
    ];
    partOf = [
      "docker-vikunja-root.target"
    ];
    wantedBy = [
      "docker-vikunja-root.target"
    ];
  };

  virtualisation.oci-containers.containers."vikunja" = {
    image = "vikunja/vikunja";
    environment = {
      "VIKUNJA_DATABASE_DATABASE" = "vikunja";
      "VIKUNJA_DATABASE_HOST" = "db";
      "VIKUNJA_DATABASE_TYPE" = "postgres";
      "VIKUNJA_DATABASE_USER" = "vikunja";
      "VIKUNJA_SERVICE_PUBLICURL" = "https://vikunja.mesh.loranjennings.com";
      "VIKUNJA_SERVICE_ENABLEREGISTRATION" = "false";
    };
    environmentFiles = [
      config.sops.templates."vikunja.env".path
    ];
    volumes = [
        "/var/lib/vikunja/files:/app/vikunja/files:rw"
    ];
    ports = [
      "127.2.0.1:3456:3456/tcp"
    ];
    dependsOn = [
      "vikunja-db"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=vikunja"
      "--network=vikunja_default"
      "--user=992:992"
    ];
  };

  systemd.services."docker-vikunja" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "docker-network-vikunja_default.service"
      "docker.service"
    ];
    requires = [
      "docker-network-vikunja_default.service"
      "docker.service"
    ];
    partOf = [
      "docker-vikunja-root.target"
    ];
    wantedBy = [
      "docker-vikunja-root.target"
    ];
  };

  # Networks
  systemd.services."docker-network-vikunja_default" = {
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "docker network rm -f vikunja_default";
    };
    script = ''
      docker network inspect vikunja_default >/dev/null 2>&1 || docker network create vikunja_default
    '';
    partOf = [ "docker-vikunja-root.target" ];
    wantedBy = [ "docker-vikunja-root.target" ];
    after = [ "docker.service" ];
    requires = [ "docker.service" ];
  };
  systemd.tmpfiles.rules = [
    "d /var/lib/vikunja 0755 root root - -"
    "d /var/lib/vikunja/files 0750 vikunja vikunja - -"
    "d /var/lib/vikunja/db 0755 root root - -"
  ];

}
