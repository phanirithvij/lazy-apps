{
  description = "Lazy Apps";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      pre-commit-hooks,
    }:
    let
      forAllSystems = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;
    in
    {
      packages = forAllSystems (
        system: (import ./.).mkLazyApps { pkgs = nixpkgs.legacyPackages.${system}; }
      );

      overlays.default = import ./overlay.nix;

      nixosModules.default = import ./modules/nixos.nix;

      homeModules.default = import ./modules/hm.nix;

      checks = forAllSystems (
        system:
        if system != "x86_64-linux" then
          { }
        else
          let
            pkgs = nixpkgs.legacyPackages.${system};
            src = pkgs.nix-gitignore.gitignoreSource [ ] ./.;
            pre-commit-check = pre-commit-hooks.lib.${system}.run {
              inherit src;
              hooks = {
                nixfmt-rfc-style.enable = true;
              };
            };
          in
          {
            inherit pre-commit-check;
          }
      );

      devShell = forAllSystems (
        system:
        nixpkgs.legacyPackages.${system}.mkShell {
          inherit (self.checks.${system}.pre-commit-check) shellHook;
        }
      );
    };
}
