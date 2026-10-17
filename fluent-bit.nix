###############################################################################
# Fluent-bit — VW VM
###############################################################################
{ config, lib, pkgs, ... }:
{
  sops.secrets = {
    "es_host" = {};
    "es_api_key" = {};
  };

  sops.templates."fluentbit-env".content = ''
    ES_API_KEY=${config.sops.placeholder.es_api_key}
  '';

  environment.etc."fluent-bit/tailscale-parse.lua".text = ''
    function parse_tailscale(tag, timestamp, record)
      local cmdline = record["_CMDLINE"]
      if cmdline then
        local ip = string.match(cmdline, "-h%s+(100%.[%d%.]+)")
        if ip then
          record["tailscale_src_ip"] = ip
          record["tailscale_ssh"]    = true
          record["event_type"]       = "tailscale_login"
        end
      end
      return 1, timestamp, record
    end
  '';

  environment.etc."fluent-bit/fail2ban-parse.lua".text = ''
    function parse_fail2ban(tag, timestamp, record)
      local msg = record["log"] or record["message"] or ""
      local jail, action, ip = string.match(msg, "%[([^%]]+)%]%s+(%w+)%s+([%d%.]+)")
      if jail then
        record["jail"] = jail
        record["action"] = action
        record["src_ip"] = ip
      end
      return 1, timestamp, record
    end
  '';

  environment.etc."fluent-bit/parsers.conf".text = ''
    [PARSER]
        Name        suricata-eve
        Format      json
        Time_Key    timestamp
        Time_Format %Y-%m-%dT%H:%M:%S.%L%z
        Time_Keep   On

    [PARSER]
        Name   nginx
        Format regex
        Regex ^(?<remote>[^ ]*) (?<host>[^ ]*) (?<user>[^ ]*) \[(?<time>[^\]]*)\] "(?<method>\S+)(?: +(?<path>[^\"]*?)(?: +\S*)?)?" (?<code>[^ ]*) (?<size>[^ ]*)(?: "(?<referer>[^\"]*)" "(?<agent>[^\"]*)")
        Time_Key time
        Time_Format %d/%b/%Y:%H:%M:%S %z

    [PARSER]
        Name        nginx-error
        Format      regex
        Regex       ^(?<time>\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2}) \[(?<level>\w+)\] (?<pid>\d+)#(?<tid>\d+): (?<message>.+)$
        Time_Key    time
        Time_Format %Y/%m/%d %H:%M:%S
  '';

  sops.templates."fluent-bit.conf" = {
    content = ''
      [SERVICE]
          flush        1
          log_level    info
          daemon       off
          Parsers_File /etc/fluent-bit/parsers.conf

      [INPUT]
          name systemd
          tag  sprint.journal
          db   /var/lib/fluent-bit/journal.db

      [INPUT]
          name tail
          path /var/log/syslog /var/log/messages
          tag  sprint.tail

      [INPUT]
          name              tail
          tag               sprint.fail2ban
          path              /var/log/fail2ban.log
          db                /var/lib/fluent-bit/fail2ban.db

      [INPUT]
          name              tail
          tag               sprint.suricata.eve
          path              /var/log/suricata/eve.json
          db                /var/lib/fluent-bit/suricata-eve.db
          mem_buf_limit     10MB
          skip_long_lines   on
          refresh_interval  5
          parser            suricata-eve

      [INPUT]
          name              tail
          tag               sprint.suricata.fast
          path              /var/log/suricata/fast.log
          db                /var/lib/fluent-bit/suricata-fast.db
          mem_buf_limit     5MB
          skip_long_lines   on
          refresh_interval  5

      [INPUT]
          name              tail
          tag               sprint.nginx.access
          path              /var/log/nginx/access.log
          mem_buf_limit     5MB
          skip_long_lines   on
          refresh_interval  5
          Parser            nginx
          db                /var/lib/fluent-bit/nginx.db

      [INPUT]
          name              tail
          tag               sprint.nginx.error
          path              /var/log/nginx/error.log
          mem_buf_limit     5MB
          skip_long_lines   on
          refresh_interval  5
          Parser            nginx-error
          db                /var/lib/fluent-bit/nginx-error.db

      [FILTER]
          name   modify
          match  *
          remove SYSLOG_TIMESTAMP

      [FILTER]
          name   lua
          match  *.journal
          script /etc/fluent-bit/tailscale-parse.lua
          call   parse_tailscale

      [FILTER]
          name   lua
          match  sprint.fail2ban
          script /etc/fluent-bit/fail2ban-parse.lua
          call   parse_fail2ban

      [OUTPUT]
          name               es
          match              *
          host               ${config.sops.placeholder."es_host"}
          port               9200
          logstash_format    Off
          Index              sprint
          suppress_type_name On
          buffer_size        10MB
          http_api_key       ''${ES_API_KEY}
    '';
    path = "/run/secrets/fluent-bit.conf";
    mode = "0444";
    owner = "root";
    group = "root";
  };

  services.fluent-bit = {
    enable = true;
    configurationFile = config.sops.templates."fluent-bit.conf".path;
  };

  systemd.services.fluent-bit = {
    serviceConfig = {
      EnvironmentFile = config.sops.templates."fluentbit-env".path;
      # Critical for reading /var/lib/ and suricata logs
      SupplementaryGroups = [ "adm" "suricata" "nginx" ];
      StateDirectory = lib.mkForce "fluent-bit";
      StateDirectoryMode = "0750";
    };
  };
}
