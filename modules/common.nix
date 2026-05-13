{
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
  directory = ''
    [Desktop Entry]
    Version=1.0
    Type=Directory
    Name=Lazy Apps
    Comment=Lazy Apps
  '';
}
