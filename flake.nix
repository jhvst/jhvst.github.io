{

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-root.url = "github:srid/flake-root";
    mission-control.url = "github:Platonic-Systems/mission-control";
  };

  outputs =
    inputs@{ self
    , nixpkgs
    , flake-parts
    , ...
    }:

    flake-parts.lib.mkFlake { inherit inputs; } {

      systems = nixpkgs.lib.systems.flakeExposed;
      imports = [
        inputs.flake-root.flakeModule
        inputs.mission-control.flakeModule
      ];

      perSystem = { pkgs, lib, config, ... }: {

        packages.components = pkgs.stdenv.mkDerivation {

          name = "components";
          src = ./.;

          phases = [ "unpackPhase" "buildPhase" ];

          buildPhase = ''
            mkdir -p $out/css
            mkdir -p $out/html
            cp css/* $out/css
            cp html/* $out/html
          '';
        };

        mission-control.scripts = {
          img = {
            description = "compress img assets";
            exec = "${lib.getExe pkgs.pngquant} img/*.png img/*/*.png --ext .png --force --strip --verbose";
            category = "Tools";
          };
        };

        devShells.default = pkgs.mkShell {
          inputsFrom = [ config.mission-control.devShell ];

          packages = with pkgs; [
            validator-nu
            watch
            pngquant
          ];
        };

      };


    };
}
