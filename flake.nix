{
  description = "Lazy Apps";

  outputs = { self, nixpkgs }:
    let forAllSystems = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;
    in {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          lib = pkgs.lib;
        in {
          lazy-apps = pkgs.makeOverridable ({ apps ? [ ] }:
            pkgs.runCommand "lazy-apps" (let
              mkExePath = { pkg, exe ? null, ... }:
                if exe != null then
                  "${lib.getBin pkg}/bin/${exe}"
                else
                  lib.getExe pkg;

              mkExeName = { pkg, exe ? null, ... }:
                if exe != null then
                  exe
                else
                  pkg.meta.mainProgram or (lib.getName pkg);

              mkEntry = app: ''
                ${mkExeName app})
                  path='${builtins.unsafeDiscardStringContext (mkExePath app)}'
                  ;;
              '';
            in {
              nativeBuildInputs = [ pkgs.copyDesktopItems ];

              desktopItems = lib.filter (d: d != null)
                (map (app: app.desktopItem or null) apps);

              script = ''
                #!${pkgs.runtimeShell}

                set -euo pipefail

                app=$(basename "$0")
                path=""

                case $app in
                ${lib.concatMapStringsSep "\n" mkEntry apps}
                    *)
                        echo "Unknown app $app"
                        exit 1
                        ;;
                esac

                if [[ ! -e $path ]]; then
                    noteId=$(notify-send -t 0 -p "Realizing $app …")
                    trap "notify-send -r '$noteId' 'Canceled realization of $app'" EXIT
                    SECONDS=0
                    nix-store --realise "$path" > /dev/null 2>&1
                    trap - EXIT
                    notify-send -r "$noteId" "Realized $app in $SECONDS s"
                fi

                if [[ -e $path ]]; then
                    exec $path "$@"
                fi
              '';
              exes = toString (map mkExeName apps);
              passAsFile = [ "script" ];
            }) ''
              runHook preInstall

              mkdir -p "$out/bin" "$out/libexec"
              install -m755 "$scriptPath" "$out/libexec/lazy-apps"
              for exe in $exes; do
                ln -sv "$out/libexec/lazy-apps" "$out/bin/$exe"
              done

              runHook postInstall
            '') { };

          example = self.packages.${system}.lazy-apps.override {
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
                  comment =
                    "Application for viewing, editing and converting GPS coordinate data";
                  categories = [ "Education" "Geoscience" ];
                  mimeTypes = [
                    "application/gpx+xml"
                    "application/vnd.google-earth.kml+xml"
                    "application/vnd.google-earth.kmz"
                  ];
                };
              }
            ];
          };
        });
    };
}
