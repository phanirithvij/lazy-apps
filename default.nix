{
  mkLazyApps =
    { pkgs }:
    let
      inherit (pkgs) lib symlinkJoin;

      mkExeName = pkg: if pkg == null then null else pkg.meta.mainProgram or (lib.getName pkg);

      lazy-app = lib.makeOverridable (
        {
          pkg ? pkgs.hello,
          exe ? mkExeName pkg,
          debugLogs ? false,
          useNom ? true,
          nomPackage ? pkgs.nix-output-monitor,
          notify ? true,
          notifyPackage ? pkgs.libnotify,
          desktopItems ? [ ],
          addGcDesktopAction ? true,
          addLazyAppCategory ? true,
          addLazyIndicatorIcon ? true,
          copyIcons ? true,
          copyCompletions ? true,
          copyManpages ? true,
          copyFonts ? false,
          customIcons ? [ ],
          installCompletions ? false,
          registerMimeTypes ? true,
          gcRoot ? false,
          ...
        }@args:
        let
          nom = lib.getExe nomPackage;
          notify-send = lib.getExe notifyPackage;

          # Discard context to avoid making the whole package a runtime dependency
          # of the lazy-wrapper derivation itself.
          pkgPath = builtins.unsafeDiscardStringContext "${pkg}";

          exePath = builtins.unsafeDiscardStringContext (
            if exe != null then lib.getExe' pkg exe else lib.getExe pkg
          );
          drvPath = builtins.unsafeDiscardStringContext pkg.drvPath;

          noDebug = lib.optionalString (!debugLogs) "> /dev/null 2>&1";
          debugNom = lib.optionalString (debugLogs) " --log-format internal-json 2>&1 | ${nom} --json)";
          debugNompre = lib.optionalString (debugLogs) "(";

          gcScript = pkgs.writeShellScriptBin "del-${exe}" ''
            app='${exe}'
            ${lib.optionalString notify ''
              noteId=$(${notify-send} -t 0 -p "Deleting $app …")
              trap "${notify-send} -r '$noteId' 'Failed to delete $app'" EXIT
              SECONDS=0
            ''}

            space=$(nix-store --delete '${exePath}' | cut -d',' -f2 | cut -d' ' -f2,3)

            ${lib.optionalString notify ''
              trap - EXIT
              ${notify-send} -r "$noteId" "Deleted $app in ''${SECONDS}s. Freed up $space"
            ''}
          '';

        in
        pkgs.runCommand "lazy-${exe}"
          {
            pname = lib.getName pkg;
            version = lib.getVersion pkg;
            nativeBuildInputs = [
              pkgs.copyDesktopItems
              pkgs.gnused
              pkgs.crudini
            ];

            passDesktopItems = desktopItems;

            meta.mainProgram = exe;
            passthru = (pkg.passthru or { }) // {
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
                ${lib.optionalString notify ''${notify-send} -t 3 -p "Running $app"''}
                exec $path "$@"
              else
                ${lib.optionalString notify ''
                  noteId=$(${notify-send} -t 0 -p "Realizing $app …")
                  trap "${notify-send} -r '$noteId' 'Canceled realization of $app'" EXIT
                  SECONDS=0
                ''}

                ${debugNompre}nix-store --realise "$path"${noDebug}${debugNom} ||\
                ${debugNompre}nix-store --realise "$drv"${noDebug}${debugNom}

                ${lib.optionalString gcRoot ''
                  # Create GC root to prevent garbage collection
                  GC_ROOT_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/lazy-apps/gcroots"
                  mkdir -p "$GC_ROOT_DIR"
                  nix-store --add-root "$GC_ROOT_DIR/${exe}" --indirect -r "$path" > /dev/null 2>&1 || true
                ''}

                ${lib.optionalString notify ''
                  trap - EXIT
                  ${notify-send} -r "$noteId" "Realized $app in $SECONDS s"
                ''}
                exec $path "$@"
              fi
            '';
            exeName = exe;
            passAsFile = [ "script" ];
          }
          ''
            runHook preInstall
            install -Dm755 "$scriptPath" "$out/bin/$exeName"

            mkdir -p $out/share/applications
            for item in $passDesktopItems; do
              filename=$(basename "$item")
              clean_name=$(echo "$filename" | sed -E 's/^[a-z0-9]{32}-//')
              outfile="$out/share/applications/$clean_name"
              cp --no-preserve=all "$item" "$outfile"

              ${lib.optionalString addGcDesktopAction ''
                if ! crudini --get "$outfile" "Desktop Entry" "Actions" &>/dev/null; then
                  crudini --set "$outfile" "Desktop Entry" "Actions" "GC;"
                else
                  sed -i 's#^Actions=#Actions=GC;#g' "$outfile"
                fi
                echo >> "$outfile"
                cat << 'EOF2' >> "$outfile"
                [Desktop Action GC]
                Name=Garbage Collect
                Exec=${lib.getExe gcScript}
                EOF2
              ''}

              ${lib.optionalString addLazyAppCategory ''
                if ! crudini --get "$outfile" "Desktop Entry" "Categories" &>/dev/null; then
                  crudini --set "$outfile" "Desktop Entry" "Categories" "LazyApps;"
                else
                  sed -i 's#^Categories=#Categories=LazyApps;#g' "$outfile"
                fi
              ''}
            done

            # Assets copying (Icons, Completions, Manpages, Fonts)
            # We use the discarded pkgPath to avoid eval-time dependency tracking
            # and then use remove-references-to to strip runtime dependencies.
            ${lib.optionalString copyIcons ''
              if [[ -d "${pkgPath}/share/icons" ]]; then
                mkdir -p "$out/share/icons"
                cp -rL --no-preserve=all "${pkgPath}/share/icons"/* "$out/share/icons/"
              fi
              if [[ -d "${pkgPath}/share/pixmaps" ]]; then
                mkdir -p "$out/share/pixmaps"
                cp -rL --no-preserve=all "${pkgPath}/share/pixmaps"/* "$out/share/pixmaps/"
              fi
            ''}

            ${lib.optionalString copyCompletions ''
              for shell in bash fish zsh; do
                if [[ -d "${pkgPath}/share/$shell" ]]; then
                  mkdir -p "$out/share/$shell"
                  cp -rL --no-preserve=all "${pkgPath}/share/$shell"/* "$out/share/$shell/"
                fi
              done
            ''}

            ${lib.optionalString copyManpages ''
              if [[ -d "${pkgPath}/share/man" ]]; then
                mkdir -p "$out/share/man"
                cp -rL --no-preserve=all "${pkgPath}/share/man"/* "$out/share/man/"
              fi
            ''}

            ${lib.optionalString copyFonts ''
              if [[ -d "${pkgPath}/share/fonts" ]]; then
                mkdir -p "$out/share/fonts"
                cp -rL --no-preserve=all "${pkgPath}/share/fonts"/* "$out/share/fonts/"
              fi
            ''}

            runHook postInstall
          ''
      ) { };
    in
    {
      inherit lazy-app;

      # Helper to check for binary collisions in a set of lazy apps
      checkCollisions =
        apps:
        let
          appsList = if lib.isAttrs apps then lib.attrValues apps else apps;
          # Map each app to its main program name
          getExe = app: app.meta.mainProgram or (lib.getName app);
          exes = map getExe appsList;
          # Find duplicates
          duplicates = lib.filter (exe: (lib.count (x: x == exe) exes) > 1) (lib.unique exes);
        in
        if duplicates == [ ] then
          apps
        else
          throw "Lazy Apps Collision detected! Multiple apps provide the following binaries: ${lib.concatStringsSep ", " duplicates}";

      mkLazyAppsBundle =
        {
          name ? "lazy-apps-bundle",
          paths,
          ...
        }:
        let
          common = import ./modules/common.nix;
          pathsList = if lib.isAttrs paths then lib.attrValues paths else paths;
        in
        symlinkJoin {
          inherit name;
          paths = pathsList;
          postBuild = ''
            # Install menu and directory files directly into the bundle
            mkdir -p $out/etc/xdg/menus/applications-merged
            mkdir -p $out/share/desktop-directories
            
            cat <<'EOF' > $out/etc/xdg/menus/applications-merged/lazy-apps.menu
${common.menu}
EOF
            cat <<'EOF' > $out/share/desktop-directories/lazy-apps.directory
${common.directory}
EOF
          '';
        };

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
