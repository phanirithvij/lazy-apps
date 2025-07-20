{
  config,
  lib,
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
  dir = ''
    [Desktop Entry]
    Version=1.0
    Type=Directory
    Name=Lazy Apps
    Comment=Lazy Apps
  '';
in
{
  options.programs.lazy-apps.enable = lib.mkEnableOption "Enable Lazy Apps desktop integration";
  config = lib.mkIf cfg.enable {
    xdg.configFile."menus/applications-merged/lazy-apps.menu".text = menu;
    xdg.dataFile."desktop-directories/lazy-apps.directory".text = dir;
  };
}
