{
  self,
  config,
  pkgs,
  lib,
  system,
  ...
}:
with lib; let
  cfg = config.services.audiobookshelf;
  defaultUser = "audiobookshelf";
  defaultGroup = "audiobookshelf";
in {
  # add meta.maintainers

  options.services.audiobookshelf = {
    enable = mkEnableOption (mdDoc "Enable audiobookshelf service");

    package = mkOption {
      type = types.package;
      default = self.packages.${system}.server;
      defaultText = literalExpression ''"self.packages.''${system}.server"'';
      description = lib.mdDoc "Audiobookshelf package to use.";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/audiobookshelf";
      description = lib.mdDoc "Directory to store audiobookshelf data.";
    };

    configDir = mkOption {
      type = types.path;
      default = "${cfg.dataDir}/config";
      defaultText = literalExpression ''"''${dataDir}/config"'';
      description = lib.mdDoc "Directory where audiobookshelf will store its configuration files.";
    };

    metadataDir = mkOption {
      type = types.path;
      default = "${cfg.dataDir}/metadata";
      defaultText = literalExpression ''"''${dataDir}/metadata"'';
      description = lib.mdDoc "Directory where audiobookshelf will store its metadata files.";
    };

    hostname = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = lib.mdDoc "Hostname to listen on.";
    };

    port = mkOption {
      type = types.port;
      default = 13378;
      description = lib.mdDoc "port to listen on";
    };

    user = mkOption {
      type = types.str;
      default = defaultUser;
      description = lib.mdDoc "User to run audiobookshelf as.";
    };

    group = mkOption {
      type = types.str;
      default = defaultGroup;
      description = lib.mdDoc "group to run audiobookshelf as.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = lib.mdDoc ''
        Open the ports in the firewall for the media server.
      '';
    };
  };

  config = mkIf cfg.enable {
    users.users.${cfg.user} = {
      group = cfg.group;
      isSystemUser = true;
    };
    users.groups.${cfg.group} = {};

    systemd.services.audiobookshelf = {
      description = "Audiobookshelf";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];
      environment = {
        HOST = cfg.hostname;
        PORT = toString cfg.port;
        NODE_ENV = "production";
        CONFIG_PATH = "${cfg.dataDir}/config";
        METADATA_PATH = "${cfg.dataDir}/metadata";
        FFMPEG_PATH = "${pkgs.ffmpeg-full}/bin/ffmpeg";
        FFPROBE_PATH = "${pkgs.ffmpeg-full}/bin/ffprobe";
        TONE_PATH = "${pkgs.tone}/bin/tone";
      };
      path = [
        pkgs.nodejs_18
        pkgs.util-linux
      ];
      serviceConfig = {
        WorkingDirectory = mkDefault "/var/lib/audiobookshelf";
        ExecStart = "node ${cfg.package}/opt/index.js";
        ExecReload = "kill -HUP $MAINPID";
        Restart = "always";
        User = cfg.user;
        Group = cfg.group;
        StateDirectory = mkDefault "audiobookshelf";
        StateDirectoryMode = "0700";
        ProtectHome = true;
        ProtectSystem = "strict";
        PrivateDevices = true;
        ProtectHostname = true;
        ProtectClock = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        RemoveIPC = true;
        PrivateMounts = true;
        Type = "simple";
        UMask = "0077";
        TimeoutSec = 15;
        NoNewPrivileges = true;
        SystemCallArchitectures = "native";
        RestrictNamespaces = !config.boot.isContainer;
        ProtectControlGroups = !config.boot.isContainer;
        ProtectKernelLogs = !config.boot.isContainer;
        ProtectKernelModules = !config.boot.isContainer;
        ProtectKernelTunables = !config.boot.isContainer;
        LockPersonality = true;
        PrivateTmp = !config.boot.isContainer;
        SystemCallFilter = [
          "~@clock"
          "~@aio"
          "~@chown"
          "~@cpu-emulation"
          "~@debug"
          "~@keyring"
          "~@memlock"
          "~@module"
          "~@mount"
          "~@obsolete"
          "~@privileged"
          "~@raw-io"
          "~@reboot"
          "~@setuid"
          "~@swap"
        ];
        SystemCallErrorNumber = "EPERM";
      };
    };

    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [cfg.port];
  };

  meta.maintainers = with lib.maintainers; [ajaxbits];
}
