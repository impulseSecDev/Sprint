{ config, lib, pkgs, ... }:

{
  imports =
    [ 
      ./fluent-bit.nix
      ./wazuh-agent.nix
      ./wireguard.nix
      ./nginx.nix
      ./fail2ban.nix
      ./suricata.nix
      ./it-tools.nix
      ./degoog.nix
      ./octoprint.nix
      ./homepage.nix
    ];

  fileSystems."/boot/firmware".options = lib.mkForce [ "noatime" "nofail" ];

  zramSwap.enable = true; # Highly recommended for 4GB/8GB Pis

  services.openssh = {
    enable = false;
    openFirewall = false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      #AllowUsers = [ "tim" ];
    };
  };

  # Disable USB Sleep
  boot.kernelParams = [ "usbcore.autosuspend=-1" ];

  sops.secrets."user_password" = {
    neededForUsers = true;
  };

  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    age.keyFile = "/var/lib/sops-nix/keys.txt";
  };

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  networking.hostName = "sprint"; # Define your hostname.
# Configure network connections interactively with nmcli or nmtui.
  networking.networkmanager.enable = true;

# Set your time zone.
# time.timeZone = "Europe/Amsterdam";

# Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.tim = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ]; # Enable ‘sudo’ for the user.
    packages = with pkgs; [
      btop
      sops
    ];
  };

environment = {
  shellAliases = {
    sops-edit = "sudo SOPS_AGE_KEY_FILE=\"/var/lib/sops-nix/keys.txt\" sops";
    vi = "nvim";
    vim = "nvim";
  };
  variables = {
    EDITOR = "nvim";
    SUDO_EDITOR = "nvim";
    VISUAL = "nvim";
    SOPS_EDITOR = "vim";
  };
};

  nix.settings.trusted-users = [ "root" "tim" ];
  users.users.root.hashedPassword = "!";
  programs.neovim.enable = true;

# List packages installed in system profile.
# You can use https://search.nixos.org/ to find more packages (and options).
  environment.systemPackages = with pkgs; [
    wget
    suricata
    
    # USed by SearXNG engines
    dateutils

    (python3.withPackages (ps: with ps; [ 
      lxml 
      babel
    ]))
  ];


# List services that you want to enable:

  services.tailscale = {
    enable = true;
  };

  boot.zfs.forceImportRoot = false;
  boot.supportedFilesystems.zfs = lib.mkForce false;

  nix.optimise.automatic = true;

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  system.stateVersion = "26.05";


}
