{

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-root.url = "github:srid/flake-root";
  };

  outputs =
    inputs@{ self
    , nixpkgs
    , flake-parts
    , ...
    }:

    flake-parts.lib.mkFlake { inherit inputs; } {

      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];
      imports = [
        inputs.flake-root.flakeModule
      ];

      perSystem = { pkgs, lib, config, system, ... }: rec {

        packages.bsc-thesis = pkgs.stdenv.mkDerivation {

          name = "bsc-thesis";
          src = ./.;
          buildInputs = with pkgs; [
            pandoc
          ];
          phases = [ "unpackPhase" "buildPhase" ];
          buildPhase = ''
            mkdir $out
            cp -r assets $out/assets
            pandoc main.tex -sC --toc --bibliography=refs.bib > $out/bsc-thesis.html
          '';
        };

        packages.default = packages.bsc-thesis;

      };
    };
}
