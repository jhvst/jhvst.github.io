{

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/23.05";
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

        packages.default = pkgs.stdenv.mkDerivation {

          name = "msc-thesis-standrews";
          src = ./.;
          buildInputs = with pkgs; [
            pandoc
          ];
          phases = [ "unpackPhase" "buildPhase" ];
          buildPhase = ''
            mkdir $out
            cp -r assets $out/assets
            pandoc main.tex -sC --toc --bibliography=main.bib > $out/msc-thesis-standrews.html
          '';
        };
      };
    };
}
