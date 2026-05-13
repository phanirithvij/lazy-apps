{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.lazy-apps;
  common = import ./common.nix;
  dirpkg =
    pkgs.runCommand "lazy-apps-directory" { }
      #bash
      ''
        mkdir -p $out/share/desktop-directories
        cat <<EOF >$out/share/desktop-directories/lazy-apps.directory
        ${common.directory}
        EOF
      '';
in
{
  options.programs.lazy-apps = {
    enable = lib.mkEnableOption "Enable Lazy Apps system level desktop integration";
    gcRoot = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Create GC roots for realized lazy apps to prevent them from being garbage collected.";
    };
  };
  config = lib.mkIf cfg.enable {
    environment.etc."xdg/menus/applications-merged/lazy-apps.menu".text = common.menu;
    environment.systemPackages = [ dirpkg ];
  };
}
