{
  mkLazyApps =
    { pkgs }:
    let
      lib = pkgs.lib;

      mkExeName = pkg: if pkg == null then null else pkg.meta.mainProgram or (lib.getName pkg);

      lazy-app = lib.makeOverridable (
        {
          pkg ? pkgs.hello,
          exe ? mkExeName pkg,
          desktopItems ? [ ],
          debugLogs ? false,
        }:
        pkgs.runCommand "lazy-${exe}"
          (
            let
              exePath = if exe != null then lib.getExe' pkg exe else lib.getExe pkg;
              drvPath = builtins.unsafeDiscardStringContext pkg.drvPath;

              notify-send = lib.getExe pkgs.libnotify;
              debug = lib.optionalString (!debugLogs) "> /dev/null 2>&1";
            in
            {
              pname = lib.getName pkg;
              version = lib.getVersion pkg;
              nativeBuildInputs = [ pkgs.copyDesktopItems ];

              inherit desktopItems;

              meta.mainProgram = exe;
              passthru.pkg = pkg;

              script = ''
                #!${pkgs.runtimeShell}

                ${lib.optionalString debugLogs "set -x"}
                set -euo pipefail

                app='${exe}'
                path='${builtins.unsafeDiscardStringContext exePath}'
                drv='${drvPath}'

                if [[ -e $path ]]; then
                    exec $path "$@"
                else
                    noteId=$(${notify-send} -t 0 -p "Realizing $app …")
                    trap "${notify-send} -r '$noteId' 'Canceled realization of $app'" EXIT
                    SECONDS=0
                    nix-store --realise "$path"${debug} ||\
                    nix-store --realise "$drv"${debug}
                    trap - EXIT
                    ${notify-send} -r "$noteId" "Realized $app in $SECONDS s"
                    exec $path "$@"
                fi
              '';
              exeName = exe;
              passAsFile = [ "script" ];
            }
          )
          ''
            runHook preInstall
            install -Dm755 "$scriptPath" "$out/bin/$exeName"
            runHook postInstall
          ''
      ) { };
    in
    {
      inherit lazy-app;

      examples = pkgs.symlinkJoin {
        name = "lazy-apps-examples";
        paths = [
          (lazy-app.override { pkg = pkgs.hello; })

          (lazy-app.override {
            pkg = pkgs.stellarium;
            desktopItems = [
              (pkgs.makeDesktopItem {
                name = "stellarium";
                type = "Application";
                desktopName = "Stellarium";
                genericName = "Desktop planetarium";
                exec = "stellarium --startup-script=%f";
                icon = "stellarium";
                startupNotify = false;
                terminal = false;
                categories = [
                  "Astronomy"
                  "Education"
                  "Science"
                ];
                comment = "Planetarium";
                mimeTypes = [ "application/x-stellarium-script" ];
              })
            ];
          })
        ];
      };
    };
}
