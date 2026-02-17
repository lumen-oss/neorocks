{
  description = "Luarocks with Neovim as the Lua interpreter";

  nixConfig = {
    extra-substituters = "https://neorocks.cachix.org";
    extra-trusted-public-keys = "neorocks.cachix.org-1:WqMESxmVTOJX7qoBC54TwrMMoVI1xAM+7yFin8NRfwk=";
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };

    flake-parts.url = "github:hercules-ci/flake-parts";

    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      # inputs.nixpkgs.follows = "nixpkgs";
    };

    neovim-nightly.url = "github:nix-community/neovim-nightly-overlay";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    git-hooks,
    flake-parts,
    neovim-nightly,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
        "x86_64-linux"
      ];
      perSystem = {
        config,
        self',
        inputs',
        system,
        ...
      }: let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            self.overlays.default
          ];
        };

        pre-commit-check = git-hooks.lib.${system}.run {
          src = self;
          hooks = {
            cabal2nix.enable = true;
            alejandra = {
              enable = true;
              excludes = [
                "neolua/default.nix"
              ];
            };
            editorconfig-checker.enable = true;
            fourmolu.enable = true;
            hpack.enable = true;
            hlint.enable = true;
          };
        };

        neorocksShell = pkgs.mkShell {
          name = "neorocks-shell";
          buildInputs =
            self.checks.${system}.pre-commit-check.enabledPackages
            ++ (with pkgs; [
              luarocks
              busted-nlua
            ]);
        };
      in {
        devShells = {
          default = neorocksShell;
          inherit neorocksShell;
        };

        packages = rec {
          default = busted-nlua;
          inherit
            (pkgs)
            busted-nlua
            neovim-nightly
            ;
        };

        checks = {
          inherit pre-commit-check;
          neorocks-test = pkgs.neorocksTest {
            src = ./testproject;
            name = "neorocks-test";
            pname = "testproject";
            neovim = pkgs.neovim-nightly;
            luaPackages = ps:
              with ps; [
                plenary-nvim
              ];
          };
        };
      };
      flake = {
        overlays = {
          default = import ./nix/overlay.nix {neovim-input = neovim-nightly;};
        };
      };
    };
}
