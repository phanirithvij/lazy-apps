# Lazy Apps

## Introduction

This repository provides a simple customizable [Nix][] package,
`lazy-apps` that you can use to create a set of applications that
_appear_ to be installed on your system but are actually not until you
try to run them.

This is something of an intermediate step between packages installed
in your system/user profile and packages run through something like
[comma][] or [nix run][].

[Nix]: https://nixos.org/nix/
[comma]: https://github.com/nix-community/comma
[nix run]: https://nixos.org/manual/nix/stable/command-ref/new-cli/nix3-run

## Usage

Lazy Apps is currently made available as a Nix Flake.

Add

``` nix
lazy-apps = {
  url = "sourcehut:~rycee/lazy-apps";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

to your Flake inputs. You can then make use of the `lazy-apps`
package. For example, installing

``` nix
self.packages.${system}.lazy-apps.override {
  apps = [
    { pkg = pkgs.hello; }
    {
      pkg = pkgs.gpsprune;
      exe = "gpsprune";
      desktopItem = pkgs.makeDesktopItem {
        name = "gpsprune";
        exec = "gpsprune %F";
        icon = "gpsprune";
        desktopName = "GpsPrune";
        genericName = "GPS Data Editor";
        comment = "Application for viewing, editing and converting GPS coordinate data";
        categories = [ "Education" "Geoscience" ];
        mimeTypes = [
          "application/gpx+xml"
          "application/vnd.google-earth.kml+xml"
          "application/vnd.google-earth.kmz"
        ];
      };
    }
  ];
}
```

will make the `hello` and `gpsprune` commands available in the shell.
The GpsPrune desktop item means that you can also start it through
your desktop manager.
