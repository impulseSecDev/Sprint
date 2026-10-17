# ============================================================
# wazuh-agent.nix — Debian Docker Container for NixOS
# ============================================================

{ config, lib, pkgs, ... }:

let
  version = "4.14.3";

  dockerfile = pkgs.writeText "Dockerfile" ''
    FROM debian:bookworm-slim
    RUN apt-get update && apt-get install -y curl gnupg ca-certificates procps && \
        mkdir -p /etc/apt/keyrings && \
        curl -sSL https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --dearmor -o /etc/apt/keyrings/wazuh.gpg && \
        chmod 644 /etc/apt/keyrings/wazuh.gpg && \
        echo "deb [signed-by=/etc/apt/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" \
          > /etc/apt/sources.list.d/wazuh.list && \
        apt-get update && apt-get install -y wazuh-agent=${version}-1 && \
        rm -rf /var/lib/apt/lists/* && \
        cp -a /var/ossec/etc /var/ossec/etc.default
    COPY entrypoint.sh /entrypoint.sh
    RUN chmod +x /entrypoint.sh
    ENTRYPOINT ["/entrypoint.sh"]
  '';

  entrypoint = pkgs.writeText "entrypoint.sh" ''
    #!/bin/sh
    set -e
    OSSEC=/var/ossec

    # Restore default configs into mount if empty
    if [ ! -f "$OSSEC/etc/ossec.conf" ]; then
      cp -a $OSSEC/etc.default/* $OSSEC/etc/
    fi

    # Ensure wazuh group ownership on persistent directory
    chown -R root:wazuh $OSSEC/etc
    chmod -R 770 $OSSEC/etc

    # Substitute Manager IP if set
    if [ -n "$WAZUH_MANAGER_SERVER" ]; then
      sed -i "s|<address>.*</address>|<address>$WAZUH_MANAGER_SERVER</address>|" $OSSEC/etc/ossec.conf
    fi

    # Only run auth if client.keys is missing or empty
    if [ ! -s "$OSSEC/etc/client.keys" ]; then
      echo "Registering agent with manager at $WAZUH_MANAGER_SERVER..."
      
      OPT_ARGS=""
      if [ -n "$WAZUH_REGISTRATION_PASSWORD" ]; then
        OPT_ARGS="-P $WAZUH_REGISTRATION_PASSWORD"
      fi

      $OSSEC/bin/agent-auth -m "$WAZUH_MANAGER_SERVER" -A "$WAZUH_AGENT_NAME" $OPT_ARGS
    fi

    echo "Starting Wazuh agent..."
    $OSSEC/bin/wazuh-control start
    exec tail -F $OSSEC/logs/ossec.log
  '';

  buildContext = pkgs.runCommand "wazuh-agent-context" { } ''
    mkdir $out
    cp ${dockerfile} $out/Dockerfile
    cp ${entrypoint} $out/entrypoint.sh
  '';
in
{
  sops.secrets."wazuh_manager_server" = {};
  sops.secrets."wazuh_agent_name" = {};
  sops.secrets."wazuh_registration_password" = {};

  sops.templates."wazuh-agent.env" = {
    content = ''
      WAZUH_MANAGER_SERVER=${config.sops.placeholder."wazuh_manager_server"}
      WAZUH_AGENT_NAME=${config.sops.placeholder."wazuh_agent_name"}
      WAZUH_REGISTRATION_PASSWORD=${config.sops.placeholder."wazuh_registration_password"}
    '';
    path = "/run/secrets/wazuh-agent.env";
    mode = "0444";
  };

  systemd.tmpfiles.rules = [
    "d /var/ossec/etc 0750 root root -"
  ];

  # OCI Container Definition
  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      wazuh-agent = {
        image = "wazuh-agent-debian:${version}";

        environmentFiles = [ config.sops.templates."wazuh-agent.env".path ];

        volumes = [
          "wazuh-agent-etc:/var/ossec/etc"
          "wazuh-agent-queue:/var/ossec/queue"
          "wazuh-agent-logs:/var/ossec/logs"
        ];

        extraOptions = [
          "--network=host"
          "--pid=host"
          "--cap-add=SYS_PTRACE"
          "--cap-add=SYS_ADMIN"
          "--cap-add=NET_ADMIN"
        ];
      };
    };
  };

  systemd.services."docker-wazuh-agent" = {
    serviceConfig.ExecStartPre = lib.mkForce [
      "-${pkgs.docker}/bin/docker rm -f wazuh-agent"
      "${pkgs.docker}/bin/docker build --network=host -t wazuh-agent-debian:${version} ${buildContext}"
    ];
  };
}
