{
  mkLazyApps =
    { pkgs }:
    let
      lib = pkgs.lib;

      mkExeName = pkg: if pkg == null then null else pkg.meta.mainProgram or (lib.getName pkg);

      lazy-app = pkgs.makeOverridable (
        {
          pkg ? pkgs.hello,
          exe ? mkExeName pkg,
          desktopItem ? null,
        }:
        pkgs.runCommand "lazy-${exe}"
          (
            let
              exePath = if exe != null then lib.getExe' pkg exe else lib.getExe pkg;

              notify-send = lib.getExe pkgs.libnotify;
            in
            {
              pname = lib.getName pkg;
              version = lib.getVersion pkg;
              nativeBuildInputs = [ pkgs.copyDesktopItems ];

              desktopItems = lib.optional (desktopItem != null) desktopItem;

              meta.mainProgram = exe;

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
            desktopItem = pkgs.makeDesktopItem {
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
            };
          })
        ];
      };
    };
}
