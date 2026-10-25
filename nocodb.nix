{ config, pkgs, lib, ... }:

{
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };
  virtualisation.oci-containers.backend = "docker";

  sops.secrets."nocodb_db_password" = {};

  sops.templates."nocodb-db.env" = {
    content = ''
      POSTGRES_PASSWORD=${config.sops.placeholder."nocodb_db_password"}
    '';
    path = "/run/secrets/nocodb-db.env";
    mode = "0440";
    owner = "root";
    group = "root";
  };

  sops.templates."nocodb.env" = {
    content = ''
      NC_DB=pg://db:5432?u=nocodb&p=${config.sops.placeholder."nocodb_db_password"}&d=nocodb
    '';
    path = "/run/secrets/nocodb.env";
    mode = "0440";
    owner = "root";
    group = "root";
  };

  users.groups.nocodb       = { gid = 984; };
  users.groups.nocodb-redis = { gid = 985; };
  users.groups.nocodb-db    = { gid = 986; };

  users.users.nocodb       = { uid = 984; group = "nocodb";       isSystemUser = true; };
  users.users.nocodb-redis = { uid = 985; group = "nocodb-redis"; isSystemUser = true; };
  users.users.nocodb-db    = { uid = 986; group = "nocodb-db";    isSystemUser = true; };

  systemd.tmpfiles.rules = [
    "d /var/lib/nocodb          0755 root         root         -"
    "d /var/lib/nocodb/data     0750 nocodb       nocodb       -"
    "d /var/lib/nocodb/postgres 0700 nocodb-db    nocodb-db    -"
    "d /var/lib/nocodb/redis    0750 nocodb-redis nocodb-redis -"
  ];

  virtualisation.oci-containers.containers."nocodb-db" = {
    image = "postgres:18.6";
    user = "986:986";
    environment = {
      "POSTGRES_DB" = "nocodb";
      "POSTGRES_USER" = "nocodb";
    };
    environmentFiles = [
      config.sops.templates."nocodb-db.env".path
    ];
    volumes = [
      "/var/lib/nocodb/postgres:/var/lib/postgresql:rw"
      "/etc/passwd:/etc/passwd:ro"
    ];
    log-driver = "journald";
    extraOptions = [
      "--health-cmd=pg_isready -U nocodb -d nocodb"
      "--health-interval=10s"
      "--health-retries=5"
      "--health-timeout=5s"
      "--network-alias=db"
      "--network=nocodb-network"
    ];
  };
  systemd.services."docker-nocodb-db" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    unitConfig.Description = "Container nocodb-db";
    after = [ "docker-network-nocodb-network.service" ];
    requires = [ "docker-network-nocodb-network.service" ];
    partOf = [ "docker-compose-nocodb-root.target" ];
    wantedBy = [ "docker-compose-nocodb-root.target" ];
  };

  virtualisation.oci-containers.containers."nocodb" = {
    image = "nocodb/nocodb:latest";
    user = "984:984";
    environment = {
      "NC_DISABLE_MUX" = "true";
      "NC_REDIS_URL" = "redis://redis:6379";
      "NC_SITE_URL" = "https://noco.mesh.loranjennings.com";
    };
    environmentFiles = [
      config.sops.templates."nocodb.env".path
    ];
    volumes = [
      "/var/lib/nocodb/data:/usr/app/data:rw"
    ];
    ports = [
      "52823:8080/tcp"
    ];
    dependsOn = [
      "nocodb-db"
      "nocodb-redis"
    ];
    log-driver = "journald";
    extraOptions = [
      "--health-cmd=wget -q --tries=1 --spider http://localhost:8080/api/v1/health || exit 1"
      "--health-interval=30s"
      "--health-retries=5"
      "--health-start-period=30s"
      "--health-timeout=5s"
      "--network-alias=nocodb"
      "--network=nocodb-network"
    ];
  };
  systemd.services."docker-nocodb" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    unitConfig.Description = "Container nocodb";
    after = [ "docker-network-nocodb-network.service" ];
    requires = [ "docker-network-nocodb-network.service" ];
    partOf = [ "docker-compose-nocodb-root.target" ];
    wantedBy = [ "docker-compose-nocodb-root.target" ];
  };

  virtualisation.oci-containers.containers."nocodb-redis" = {
    image = "redis:7";
    user = "985:985";
    volumes = [
      "/var/lib/nocodb/redis:/data:rw"
    ];
    log-driver = "journald";
    extraOptions = [
      "--health-cmd=[\"redis-cli\", \"ping\"]"
      "--health-interval=10s"
      "--health-retries=5"
      "--health-timeout=5s"
      "--network-alias=redis"
      "--network=nocodb-network"
    ];
  };
  systemd.services."docker-nocodb-redis" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    unitConfig.Description = "Container nocodb-redis";
    after = [ "docker-network-nocodb-network.service" ];
    requires = [ "docker-network-nocodb-network.service" ];
    partOf = [ "docker-compose-nocodb-root.target" ];
    wantedBy = [ "docker-compose-nocodb-root.target" ];
  };

  virtualisation.oci-containers.containers."nocodb-worker" = {
    image = "nocodb/nocodb:latest";
    user = "984:984";
    environment = {
      "NC_REDIS_URL" = "redis://redis:6379";
      "NC_SITE_URL" = "http://localhost:8080";
      "NC_WORKER_CONTAINER" = "true";
    };
    environmentFiles = [
      config.sops.templates."nocodb.env".path
    ];
    volumes = [
      "/var/lib/nocodb/data:/usr/app/data:rw"
    ];
    dependsOn = [ "nocodb" ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=worker"
      "--network=nocodb-network"
    ];
  };
  systemd.services."docker-nocodb-worker" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    unitConfig.Description = "Container nocodb-worker";
    after = [ "docker-network-nocodb-network.service" ];
    requires = [ "docker-network-nocodb-network.service" ];
    partOf = [ "docker-compose-nocodb-root.target" ];
    wantedBy = [ "docker-compose-nocodb-root.target" ];
  };

  # Network
  systemd.services."docker-network-nocodb-network" = {
