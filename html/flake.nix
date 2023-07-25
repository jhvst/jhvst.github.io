{

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
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

      perSystem = { pkgs, lib, config, system, ... }: {

        packages.default = pkgs.stdenv.mkDerivation {
          name = "html";
          src = ./.;

          phases = [ "unpackPhase" "buildPhase" ];

          buildPhase = ''
            mkdir -p $out
            cp *.html $out
          '';
        };
      };
    };
}
