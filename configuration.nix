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

        drink-dispenser = pkgs.writers.writePython3Bin "drink-dispenser" {
          libraries = [ pkgs.python3.pkgs.libgpiod ];
          flakeIgnore = ["E501"];
        } ''
          import json
          import sys
          import threading
          import time
          import gpiod
          import logging
          logging.basicConfig(level=logging.INFO)

          PLAYER_TO_GPIO = {
              0: 5,
              1: 6,
              2: 13,
              3: 16,
              4: 19,
              5: 20,
              6: 21,
              7: 26,
          }

          ALLOWLIST = {
              "hit_banana",
              "explosion_crash",
              "terrain_tumble",
              "hit_paddle_boat",
              "squished",
              "fell_in_lava",
              "fell_in_water",
              "high_tumble",
              "hit_by_star",
              "lightning_strike",
              "low_tumble",
              "negroni_code",
              "spinout",
              "driving_spinout",
              "early_start_spinout",
              # FIXME: if player hits CPU
              # issue # {"event":"star_hit", "ownerIndex":2, "playerIndex":0,
              # "isHumanOwner":false, "isHumanPlayer":true}
          }

          # Global line request for all GPIO pins
          line_request = None


          def init_gpio():
              """Initialize GPIO lines for all player pins."""
              global line_request
              config = {}
              for pin in PLAYER_TO_GPIO.values():
                  config[pin] = gpiod.LineSettings(
                      active_low=True,
                      direction=gpiod.line.Direction.OUTPUT,
                      output_value=gpiod.line.Value.INACTIVE
                  )
              line_request = gpiod.request_lines(
                  "/dev/gpiochip0",
                  config=config,
                  consumer="drink-dispenser"
              )
              logging.info("GPIO initialized - all pins set to INACTIVE")


          def trigger_gpio(gpio_pin):
              """Trigger a GPIO pin for 1500ms in a background thread."""
              logging.info(f"GPIO {gpio_pin} ON")
              line_request.set_value(gpio_pin, gpiod.line.Value.ACTIVE)
              time.sleep(1.5)
              line_request.set_value(gpio_pin, gpiod.line.Value.INACTIVE)
              logging.info(f"GPIO {gpio_pin} OFF")


          def main():
              init_gpio()
              for line in sys.stdin:
                  line = line.strip()
                  if not line:
                      continue

                  try:
                      data = json.loads(line)
                  except json.JSONDecodeError:
                      continue

                  logging.info(f"Got event {line}")

                  event = data.get("event")
                  if event is None:
                      continue

                  if event not in ALLOWLIST:
                      logging.info(f"Event {event} not in allowlist, skipping")
                      continue

                  player_index = data.get("playerIndex")
                  if player_index is None:
                      continue

                  gpio_pin = PLAYER_TO_GPIO.get(player_index)
                  if gpio_pin is not None:
                      logging.info(f"Dispensing drink for Player #{player_index} (event: {event}, gpio: {gpio_pin})")
                      thread = threading.Thread(
                          target=trigger_gpio, args=(gpio_pin,)
                      )
                      thread.daemon = True
                      thread.start()


          if __name__ == "__main__":
              main()
        '';
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
