{
  description = "Lazy Apps";

  inputs = { nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable"; };

  outputs = { self, nixpkgs }:
    let forAllSystems = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;
    in {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          lib = pkgs.lib;

          mkExeName = pkg:
            if pkg == null then
              null
            else
              pkg.meta.mainProgram or (lib.getName pkg);

        in {
          lazy-app = pkgs.makeOverridable
            ({ pkg ? pkgs.hello, exe ? mkExeName pkg, desktopItem ? null }:
              pkgs.runCommand "lazy-${exe}" (let
                exePath = if exe != null then
                  "${lib.getBin pkg}/bin/${exe}"
                else
                  lib.getExe pkg;

                notify-send = lib.getExe pkgs.libnotify;
              in {
                pname = lib.getName pkg;
                version = lib.getVersion pkg;
                nativeBuildInputs = [ pkgs.copyDesktopItems ];

                desktopItems = lib.optional (desktopItem != null) desktopItem;

                script = ''
                  #!${pkgs.runtimeShell}

                  set -euo pipefail

                  app='${exe}'
                  path='${builtins.unsafeDiscardStringContext exePath}'

                  if [[ ! -e $path ]]; then
                      noteId=$(${notify-send} -t 0 -p "Realizing $app …")
                      trap "${notify-send} -r '$noteId' 'Canceled realization of $app'" EXIT
                      SECONDS=0
                      nix-store --realise "$path" > /dev/null 2>&1
                      trap - EXIT
                      ${notify-send} -r "$noteId" "Realized $app in $SECONDS s"
                  fi

                  if [[ -e $path ]]; then
                      exec $path "$@"
                  fi
                '';
                exeName = exe;
                passAsFile = [ "script" ];
              }) ''
                runHook preInstall
                install -Dm755 "$scriptPath" "$out/bin/$exeName"
                runHook postInstall
              '') { };

          examples = let lazy-app = self.packages.${system}.lazy-app;
          in pkgs.symlinkJoin {
            name = "lazy-apps-examples";
            paths = [
              (lazy-app.override { pkg = pkgs.hello; })

              (lazy-app.override {
                pkg = pkgs.gpsprune;
                desktopItem = pkgs.makeDesktopItem {
                  name = "gpsprune";
                  exec = "gpsprune %F";
                  icon = "gpsprune";
                  desktopName = "GpsPrune";
                  genericName = "GPS Data Editor";
                  comment =
                    "Application for viewing, editing and converting GPS coordinate data";
                  categories = [ "Education" "Geoscience" ];
                  mimeTypes = [
                    "application/gpx+xml"
                    "application/vnd.google-earth.kml+xml"
                    "application/vnd.google-earth.kmz"
                  ];
                };
              })
            ];
          };
        });
    };
}
