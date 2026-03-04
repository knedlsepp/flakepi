{ pkgs, config, lib, ... }:
{
  environment.systemPackages = with pkgs; [ vim git htop strace n64-unfloader sc64deployer ];

  systemd.services.sc64deployer = {
    enable = true;
    description = "sc64deployer ROM Upload Service";
    wantedBy = [ "multi-user.target" ];
    unitConfig = {
      StartLimitIntervalSec = "0";
    };
    serviceConfig = {
      Type = "simple";
      ExecStart =  let
          upload-rom = pkgs.writeShellApplication {
            name = "upload-rom";
            runtimeInputs = [
              pkgs.sc64deployer
            ];
            text = ''
              until sc64deployer list; do sleep 2; done
              sc64deployer upload /var/lib/unfloader/build.rom
              # Prevent "[IS-Viewer 64]: Stopped listening" via 'tail -f /dev/null'
              tail -f /dev/null | sc64deployer debug --isv 0x03FF0000
            '';
          };
        in
        "${upload-rom}/bin/upload-rom";

      User = "sc64deployer";
      Group = "sc64deployer";
      Restart = "always";
      RestartSec = "1";
    };
  };


  # UNFLoader service configuration
  systemd.services.unfloader-upload = {
    enable = false;
    description = "UNFLoader ROM Upload Service";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.n64-unfloader}/bin/UNFLoader -f 4 -b -l -d -r /var/lib/unfloader/rom.n64";
      User = "unfloader";
      Group = "unfloader";
      Restart = "always";
    };
  };

  # Create unfloader user and group
  users.users.unfloader = {
    isSystemUser = true;
    createHome = true;
    description = "UNFLoader service user";
    group = "unfloader";
  };

  users.groups.unfloader = { };


  # Create sc64deployer user and group
  users.users.sc64deployer = {
    isSystemUser = true;
    createHome = true;
    description = "sc64deployer service user";
    group = "sc64deployer";
    extraGroups =  [
      "dialout" # Access to serial device
    ];
  };

  users.groups.sc64deployer = { };


  services.openssh.enable = true;
  networking.hostName = "sempfberry";
  users = {
    users.root = {
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDTL9AJG8V8Hl3yiPJeghn3GcIy3sl+jsED+RgC5Md4E sepp@localhohohost"
      ];
    };
  };
  networking = {
    networkmanager.enable = lib.mkForce false;
    interfaces."wlan0".useDHCP = true;
    wireless = {
      interfaces = [ "wlan0" ];
      enable = true;
      networks = {
        knoedlnetz = {
          # Generated using `wpa_passphrase knoedlnetz`. A slight security issue...
          pskRaw = "2c3655a7b8f9ed76f7e63824442a42eac54127737d138cac2f5b259ad667cca5";
        };
      };
    };
  };
  system.stateVersion = "25.11";
}
