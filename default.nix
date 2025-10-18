{
  mkLazyApps =
    { pkgs }:
    let
      inherit (pkgs) lib;

      mkExeName = pkg: if pkg == null then null else pkg.meta.mainProgram or (lib.getName pkg);

      notify-send = lib.getExe pkgs.libnotify;
      nom = lib.getExe pkgs.nix-output-monitor;

      makeGcDesktopItem =
        {
          exe,
          exePath,
          desktopItem,
          addGcDesktopAction,
          addLazyAppCategory,
        }:
        let
          gcScript = pkgs.writeShellScriptBin "del-${exe}" ''
            app=${exe}
            noteId=$(${notify-send} -t 0 -p "Deleting $app …")
            trap "${notify-send} -r '$noteId' 'Failed to delete $app'" EXIT
            SECONDS=0
            space=$(nix-store --delete ${exePath} | cut -d',' -f2 | cut -d' ' -f2,3)
            trap - EXIT
            ${notify-send} -r "$noteId" "Deleted $app in ''${SECONDS}s. Freed up $space"
          '';
          item =
            if addGcDesktopAction || addLazyAppCategory then
              (pkgs.runCommand "lazy-app-desktop-file-${exe}"
                {
                  nativeBuildInputs = with pkgs; [
                    gnused
                    crudini
                  ];
                }
                ''
                  mkdir $out
                  outfile=$out/${exe}.desktop
                  cp --no-preserve=all ${desktopItem} $outfile
                  ${lib.optionalString addGcDesktopAction
                    #bash
                    ''
                      if ! crudini --get $outfile "Desktop Entry" "Actions" &>/dev/null; then
                        crudini --set $outfile "Desktop Entry" "Actions" "GC;"
                      else
                        sed -i 's#^Actions=#Actions=GC;#g' $outfile
                      fi
                      echo >>$outfile
                      cat << EOF >>$outfile
                      [Desktop Action GC]
                      Name=Garbage Collect
                      Exec=${lib.getExe gcScript}
                      EOF
                    ''
                  }
                  ${lib.optionalString addLazyAppCategory
                    #bash
                    ''
                      if ! crudini --get $outfile "Desktop Entry" "Categories" &>/dev/null; then
                        crudini --set $outfile "Desktop Entry" "Categories" "LazyApps;"
                      else
                        sed -i 's#^Categories=#Categories=LazyApps;#g' $outfile
                      fi
                    ''
                  }
                ''
              )
              + "/${exe}.desktop"
            else
              desktopItem;
        in
        item;

      lazy-app = lib.makeOverridable (
        {
          debugLogs ? false,
          desktopItems ? [ ],
          addGcDesktopAction ? true,
          addLazyAppCategory ? true,
          ...
        }@overrideArgs:
        let
          _pkg = overrideArgs.pkg or pkgs.hello;
          pkg =
            if _pkg ? override then
              _pkg.override (
                removeAttrs overrideArgs [
                  "pkg" # Hope we don't conflict with some nixpkgs override value `rg ' pkg (,|\?)'` in nixpkgs
                  "exe"
                  "debugLogs"
                  "desktopItems"
                  "addGcDesktopAction"
                  "addLazyAppCategory"
                ]
              )
            else
              _pkg;
          exe = overrideArgs.exe or (mkExeName pkg);
        in
        pkgs.runCommand "lazy-${exe}"
          (
            let
              exePath = builtins.unsafeDiscardStringContext (
                if exe != null then lib.getExe' pkg exe else lib.getExe pkg
              );
              drvPath = builtins.unsafeDiscardStringContext pkg.drvPath;

              nodebug = lib.optionalString (!debugLogs) "> /dev/null 2>&1";
              debugNom = lib.optionalString (debugLogs) " --log-format internal-json 2>&1 | ${nom} --json)";
              debugNompre = lib.optionalString (debugLogs) "(";
              desktopItems' = map (
                desktopItem:
                makeGcDesktopItem {
                  inherit
                    exe
                    exePath
                    desktopItem
                    addGcDesktopAction
                    addLazyAppCategory
                    ;
                }
              ) desktopItems;
            in
            {
              pname = lib.getName pkg;
              version = lib.getVersion pkg;
              nativeBuildInputs = [ pkgs.copyDesktopItems ];

              desktopItems = desktopItems';

              meta.mainProgram = exe;
              passthru = pkg.passthru // {
                inherit pkg;
              };

              script = ''
                #!${pkgs.runtimeShell}

                ${lib.optionalString debugLogs "set -x"}
                set -euo pipefail

                app='${exe}'
                path='${exePath}'
                drv='${drvPath}'

                if [[ -e $path ]]; then
                    exec $path "$@"
                else
                    noteId=$(${notify-send} -t 0 -p "Realizing $app …")
                    trap "${notify-send} -r '$noteId' 'Canceled realization of $app'" EXIT
                    SECONDS=0
                    ${debugNompre}nix-store --realise "$path"${nodebug}${debugNom} ||\
                    ${debugNompre}nix-store --realise "$drv"${nodebug}${debugNom}
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
