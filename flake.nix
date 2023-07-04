{

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-root.url = "github:srid/flake-root";
    mission-control.url = "github:Platonic-Systems/mission-control";

    # blogposts
    j1.url = "github:jhvst/jhvst.github.io?dir=blogPosts/j1";
    barbell.url = "github:jhvst/jhvst.github.io?dir=blogPosts/barbell";

    # papers
    bsc-thesis.url = "github:jhvst/jhvst.github.io?dir=papers/bsc-thesis";
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
        inputs.mission-control.flakeModule
      ];

      perSystem = { pkgs, lib, config, system, ... }: {

        packages.default = pkgs.stdenv.mkDerivation {

          name = "Juuso Haavisto";
          src = ./.;

          phases = [ "unpackPhase" "buildPhase" ];
          buildPhase = ''
            mkdir -p $out/blogPosts/barbell
            cp -r ${inputs.barbell.outputs.packages.${system}.barbell}/* $out/blogPosts/barbell

            mkdir -p $out/blogPosts/j1
            cp -r ${inputs.j1.outputs.packages.${system}.j1}/* $out/blogPosts/j1

            mkdir -p $out/projects/highlightplay/theinternational5
            cp -r projects/highlightplay/theinternational5/* $out/projects/highlightplay/theinternational5

            mkdir -p $out/papers/bsc-thesis
            cp -r ${inputs.bsc-thesis.outputs.packages.${system}.bsc-thesis}/* $out/papers/bsc-thesis

            cp -r ignition $out
            cp -r SPAs $out

            cp -r css $out
            cp -r img $out
            cp -r videos $out

            cp favicon.svg $out
            cp robots.txt $out
            cp rss.xml $out
            cp *.html $out
          '';

        };

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
            pandoc
          ];
        };

      };


    };
}
