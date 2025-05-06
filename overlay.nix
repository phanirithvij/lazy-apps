final: prev: {
  lazyApps =
    let
      lib = prev.lib;

      lazy-app = ((import ./.).mkLazyApps { pkgs = final; }).lazy-app;

      # Recursively replace each derivation having `mainProgram` set with a lazy application.
      mkLazyPkg =
        name: value:
        if lib.isAttrs value then
          if lib.isDerivation value && (value.meta or { }) ? mainProgram then
            lazy-app.override { pkg = value; }
          else
            mkLazyPkgs value
        else
          value;

      mkLazyPkgs = attrs: lib.mapAttrs mkLazyPkg attrs;

    in
    mkLazyPkgs final;
}
