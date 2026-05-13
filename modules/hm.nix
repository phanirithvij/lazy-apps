{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.lazy-apps;
  lib' = (import ./..).mkLazyApps { inherit pkgs; };

  bundle = lib'.mkLazyAppsBundle {
    name = "lazy-apps-user-bundle";
    paths = cfg.applications;
  };
in
{
  options.programs.lazy-apps = {
    enable = lib.mkEnableOption "Enable Lazy Apps desktop integration";
    gcRoot = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Create GC roots for realized lazy apps to prevent them from being garbage collected.";
    };
    applications = lib.mkOption {
      type = with lib.types; oneOf [ (attrsOf package) (listOf package) ];
      default = [ ];
      description = "List or attribute set of lazy applications to include in the user bundle.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ bundle ];
  };
}
