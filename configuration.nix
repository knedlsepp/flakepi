# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.grub.enable = false;
  boot.loader.raspberryPi.enable = true;
  boot.loader.raspberryPi.version = 4;
  boot.kernelPackages = pkgs.linuxPackages_rpi4;
  boot.consoleLogLevel = lib.mkDefault 7;

  networking.hostName = "sempfberry"; # Define your hostname.
  networking.wireless = {
    enable = true;
    networks = {
      knoedlnetz = {
        # Generated using `wpa_passphrase knoedlnetz`. A slight security issue, but I don't have wired networking yet...
        pskRaw = "2c3655a7b8f9ed76f7e63824442a42eac54127737d138cac2f5b259ad667cca5";
      };
    };
  };
  systemd.services.wpa_supplicant.serviceConfig = {
    # First login attempt doesn't work for whatever reason
    Restart = "always";
    RestartSec = 8;
    StartLimitIntervalSec = 0; # Don't stop trying after a couple of restarts
  };

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = false;
  networking.interfaces.eth0.useDHCP = true;
  networking.interfaces.wlan0.useDHCP = true;
  networking.enableIPv6 = false;
  # networking.defaultGateway = { address = "192.168.43.1"; interface = "wlan0"; }; # Only enable if you're having issues with the WiFi gateway

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  # i18n = {
  #   consoleFont = "Lat2-Terminus16";
  #   consoleKeyMap = "us";
  #   defaultLocale = "en_US.UTF-8";
  # };

  # Set your time zone.
  time.timeZone = "Europe/Vienna";

  systemd.tmpfiles.rules = [ "f /etc/netgroup" ]; # stat failed for file `/etc/netgroup'; will try again later: No such file or directory

  programs.vim.defaultEditor = true;
  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    manpages
    posix_man_pages

    wget
    vim
    git
    raspberrypi-tools
    fzf
    direnv
    htop
    any-nix-shell
    gitAndTools.gitFull
    strace
  ];
  programs.zsh = {
    enable = true;
    autosuggestions.enable = true;
    ohMyZsh = {
      enable = true;
      customPkgs = [];
      theme = "fishy";
      plugins = [ "git" "github" "z" "docker" "colored-man-pages" ];
    };
    interactiveShellInit = ''
      source "$(fzf-share)/key-bindings.zsh"
      source "$(fzf-share)/completion.zsh"
      eval "$(direnv hook zsh)"
      export DIRENV_LOG_FORMAT= # Silence direnv
    '';
    promptInit = ''
      any-nix-shell zsh --info-right | source /dev/stdin
    '';
    syntaxHighlighting.enable = true;
  };

  nix = {
    trustedUsers = [ "root" "@wheel" ];
    buildCores = 3;
    daemonNiceLevel = 5;
    daemonIONiceLevel = 5;
  };
  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  services.openssh.permitRootLogin = "yes";


  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = false;

  # Enable sound.
  sound.enable = true;
  hardware.pulseaudio.enable = true;

  # Enable the X11 windowing system.
  services.xserver = {
    enable = true;
    displayManager.sddm = {
      enable = true;
      autoLogin.enable = true;
      autoLogin.user = "sepp";
    };
    desktopManager.plasma5.enable = true;
    desktopManager.kodi.enable = false;
    videoDrivers = [ "modesetting" ];
    layout = "de,us";
    xkbOptions = "eurosign:e, ctrl:nocaps";
  };
  hardware.opengl = {
    enable = true;
    setLdLibraryPath = true;
    package = pkgs.mesa_drivers;
  };
  hardware.deviceTree = {
    base = pkgs.device-tree_rpi;
    overlays = [ "${pkgs.device-tree_rpi.overlays}/vc4-fkms-v3d.dtbo" ];
  };
  boot.loader.raspberryPi.firmwareConfig = ''
    gpu_mem=192
  '';
  networking.networkmanager.enable = lib.mkForce false;


  # Define a user account. Don't forget to set a password with 'passwd'
  users.users.root = {
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC/Z8395cyaul/PIgLDCSgHWrg3h1xiALouLu8gAOYb9CtN05VTSOINuI95rcdPFIQC+2vconZ/sW2j+mUmsrIP6b2eFm1XRg6Nicu9tPK+fqksSqL2TjPijwmeptljDwUN/F5YfCRCFCixAtRq5wTARbEzC8hDvnfaoimiRD4JyMCnRJvEAZxh5AsY5vD42sQVmS1xh7lx80gd7ARdeKh5xBV/ccnFzON0U9HTM4DNSa2URV+QCJec1ORYHAfo+DdmR+q7J96lVp5UbLki1Ym4KEW6eCUeOZ6bAq8aaFlWmlwFIMNOzfEc/kZRDurRj8IJx5BWzI1RPRg9Z+ChqbZh josef.kemetmueller@PC-18801"
    ];
  };
  users.users.sepp = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC/Z8395cyaul/PIgLDCSgHWrg3h1xiALouLu8gAOYb9CtN05VTSOINuI95rcdPFIQC+2vconZ/sW2j+mUmsrIP6b2eFm1XRg6Nicu9tPK+fqksSqL2TjPijwmeptljDwUN/F5YfCRCFCixAtRq5wTARbEzC8hDvnfaoimiRD4JyMCnRJvEAZxh5AsY5vD42sQVmS1xh7lx80gd7ARdeKh5xBV/ccnFzON0U9HTM4DNSa2URV+QCJec1ORYHAfo+DdmR+q7J96lVp5UbLki1Ym4KEW6eCUeOZ6bAq8aaFlWmlwFIMNOzfEc/kZRDurRj8IJx5BWzI1RPRg9Z+ChqbZh josef.kemetmueller@PC-18801"
    ];
  };
  users.users.pi = {
    isNormalUser = true;
    initialHashedPassword = "raspberry";
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC/Z8395cyaul/PIgLDCSgHWrg3h1xiALouLu8gAOYb9CtN05VTSOINuI95rcdPFIQC+2vconZ/sW2j+mUmsrIP6b2eFm1XRg6Nicu9tPK+fqksSqL2TjPijwmeptljDwUN/F5YfCRCFCixAtRq5wTARbEzC8hDvnfaoimiRD4JyMCnRJvEAZxh5AsY5vD42sQVmS1xh7lx80gd7ARdeKh5xBV/ccnFzON0U9HTM4DNSa2URV+QCJec1ORYHAfo+DdmR+q7J96lVp5UbLki1Ym4KEW6eCUeOZ6bAq8aaFlWmlwFIMNOzfEc/kZRDurRj8IJx5BWzI1RPRg9Z+ChqbZh josef.kemetmueller@PC-18801"
    ];
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "20.03"; # Did you read the comment?

}

