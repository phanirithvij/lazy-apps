{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.lazy-apps;
  menu = ''
    <!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
        "http://www.freedesktop.org/standards/menu-spec/menu-1.0.dtd">
    <Menu>
        <Name>Applications</Name>
        <Menu>
            <Name>Lazy Apps</Name>
            <Directory>lazy-apps.directory</Directory>
            <Include>
                <Category>LazyApps</Category>
            </Include>
        </Menu>
    </Menu>
  '';
  dirpkg =
    pkgs.runCommand "lazy-apps-directory" { }
      #bash
      ''
        mkdir -p $out/share/desktop-directories
        cat <<EOF >$out/share/desktop-directories/lazy-apps.directory
        [Desktop Entry]
        Version=1.0
        Type=Directory
        Name=Lazy Apps
        Comment=Lazy Apps
        EOF
      '';
in
{
  # Goals
  # - separate category in Applications Menu named "Lazy Apps"
  #   - same for home-manager module
  # - GC Desktop Action entry for all lazy apps
  options.programs.lazy-apps.enable = lib.mkEnableOption "Enable Lazy Apps system level desktop integration";
  config = lib.mkIf cfg.enable {
    environment.etc."xdg/menus/applications-merged/lazy-apps.menu".text = menu;
    environment.systemPackages = [ dirpkg ];
  };
}
