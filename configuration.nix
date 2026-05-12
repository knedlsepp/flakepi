{ pkgs, config, lib, ... }:
{
  environment.systemPackages = with pkgs; [ vim git htop strace sc64deployer ];

  systemd.services.sc64deployer = {
    enable = true;
    description = "sc64deployer ROM Upload Service with drink dispenser";
    wantedBy = [ "multi-user.target" ];
    unitConfig = {
      StartLimitIntervalSec = "0";
    };
    serviceConfig = {
      Type = "simple";
      ExecStart =  let
        upload-rom = pkgs.writeShellApplication {
          name = "upload-rom";
          runtimeInputs = [ pkgs.sc64deployer ];
          text = ''
            until sc64deployer list; do sleep 2; done
            sc64deployer upload /var/lib/sc64deployer/build.rom
            # Prevent "[IS-Viewer 64]: Stopped listening" via 'tail -f /dev/null'
            exec tail -f /dev/null | sc64deployer debug --isv 0x03FF0000
          '';
        };

        drink-dispenser = pkgs.writeShellApplication {
          name = "drink-dispenser";
          runtimeInputs = [ pkgs.jq pkgs.libgpiod ];
          text = ''
            playerToGPIO=(5 6 13 16 19 20 21 26)

            allowlist=(
              "hit_banana"
              "explosion_crash"
              "terrain_tumble"
              "hit_paddle_boat"
              "squished"
              "fell_in_lava"
              "fell_in_water"
              "high_tumble"
              "hit_by_star"
              "lightning_strike"
              "low_tumble"
              "negroni_code"
              "spinout"
              "driving_spinout"
              "early_start_spinout"
              # "star_hit" # FIXME: if player hits CPU => issue # {"event":"star_hit", "ownerIndex":2, "playerIndex":0, "isHumanOwner":false, "isHumanPlayer":true}
            )

            isAllowlisted() {
              local e="$1"
              for w in "''${allowlist[@]}"; do
                [[ "$e" == "$w" ]] && return 0
              done
              return 1
            }

            while IFS= read -r line
            do
              echo "$line" | jq -e . >/dev/null 2>&1 || continue
              echo "Got event $line"

              event=$(echo "$line" | jq -r '.event // empty') || continue
              playerIndex=$(echo "$line" | jq -r '.playerIndex // empty') || continue

              isAllowlisted "$event" || continue

              if [ -n "$playerIndex" ]; then
                echo "Dispensing drink for Player #$playerIndex (event: $event)"
                gpioset -c 0 -l -t 1500ms,0s "''${playerToGPIO[$playerIndex]}=1" &
              fi
            done
          '';
        };
      in
        "${pkgs.bash}/bin/bash -c '${upload-rom}/bin/upload-rom |& ${drink-dispenser}/bin/drink-dispenser'";

      User = "sc64deployer";
      Group = "sc64deployer";
      Restart = "always";
      RestartSec = "1";
    };
  };




  # Create sc64deployer user and group
  users.users.sc64deployer = {
    isSystemUser = true;
    createHome = true;
    description = "sc64deployer service user";
    group = "sc64deployer";
    extraGroups =  [
      "dialout" # Access to serial device
      "gpio"    # Access to GPIO devices
    ];
  };

  users.groups.sc64deployer = { };
  users.groups.gpio = { };
  services.udev.extraRules = ''
      KERNEL=="gpiochip[0-9]*", GROUP="gpio", MODE="0660"
  '';


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
