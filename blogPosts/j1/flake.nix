{

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-root.url = "github:srid/flake-root";
    blog.url = "github:jhvst/jhvst.github.io";
    barbell.url = "github:jhvst/barbell";
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

        packages.j1 = pkgs.stdenv.mkDerivation {
          name = "j1";
          src = ./.;
          buildInputs = with pkgs; [
            pandoc
            cbqn
            validator-nu
            nodePackages.js-beautify
            inputs.barbell.packages.${system}.barbell
          ];
          phases = [ "unpackPhase" "buildPhase" "checkPhase" ];
          buildPhase = ''
            mkdir -p $out
            mkdir -p $out/css
            mkdir -p $out/img
            mkdir -p $out/attachments
            cp -r ${inputs.blog.packages.${system}.components}/* .
            pandoc j1.md -o article.bar
            barbell template.html > $out/j1.html
            js-beautify -f $out/j1.html -r
            cp css/* $out/css
            cp img/* $out/img
            cp attachments/* $out/attachments
          '';

          doCheck = true;
          checkPhase = ''
            vnu $out/j1.html
          '';
        };

        packages.default = packages.j1;

      };
    };
}
