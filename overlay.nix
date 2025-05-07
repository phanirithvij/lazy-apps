final: prev:
let
  lazy-app = ((import ./.).mkLazyApps { pkgs = final; }).lazy-app;
in
{
  lazy-app = lazy-app;

  lazyApps =
    let
      lib = prev.lib;

      # Recursively replace each derivation having `mainProgram` set with a lazy
      # application. Any other attribute will be given a null value, which can
      # be filtered out.
      mkLazyPkg =
        name: value:
        if lib.isAttrs value then
          if lib.isDerivation value then
            # If the derivation has a main program, then create a corresponding
            # lazy application.
            if (value.meta or { }) ? mainProgram then
              lazy-app.override { pkg = value; }
            else
              throw "This is not a valid lazy derivation: ${name}"
          else
            mkLazyPkgs value
        else
          value;

      mkLazyPkgs = attrs: lib.mapAttrs mkLazyPkg attrs;

    in
    mkLazyPkgs final;
}
