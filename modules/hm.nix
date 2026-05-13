{
  config,
  lib,
  ...
}:
let
  cfg = config.programs.lazy-apps;
  common = import ./common.nix;

  # If this HM configuration is being used as a NixOS module, check if the NixOS
  # counterpart is already enabled. If so, we should skip creating the menu
  # files to avoid duplicates in XDG menu merging.
  isNixOSEnabled = config ? osConfig && config.osConfig.programs.lazy-apps.enable or false;
in
{
  options.programs.lazy-apps = {
    enable = lib.mkEnableOption "Enable Lazy Apps desktop integration";
    gcRoot = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Create GC roots for realized lazy apps to prevent them from being garbage collected.";
    };
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile."menus/applications-merged/lazy-apps.menu" = lib.mkIf (!isNixOSEnabled) {
      text = common.menu;
    };
    xdg.dataFile."desktop-directories/lazy-apps.directory" = lib.mkIf (!isNixOSEnabled) {
      text = common.directory;
    };
  };
}
