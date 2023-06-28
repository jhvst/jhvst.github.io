{

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
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

        packages.barbell = pkgs.stdenv.mkDerivation {
          name = "barbell";
          src = ./.;
          buildInputs = with pkgs; [
            pandoc
            validator-nu
            nodePackages.js-beautify
            inputs.barbell.packages.${system}.barbell
            woff2
            vale
          ];
          phases = [ "unpackPhase" "buildPhase" "checkPhase" ];
          buildPhase = ''
            mkdir -p $out/css
            mkdir html
            cp -r ${inputs.blog.packages.${system}.components}/html/* ./html
            cp ${pkgs.ibm-plex}/share/fonts/opentype/IBMPlexMono-Regular.otf .
            woff2_compress IBMPlexMono-Regular.otf
            cp IBMPlexMono-Regular.woff2 $out/
            pandoc main.md --katex -o main.html
            barbell main.html > article.bar
            barbell ./html/template_article.html > $out/barbell.html
          '';

          doCheck = false;
          checkPhase = ''
            vnu $out/barbell.html
            vale sync
            vale main.md
          '';
        };

        packages.default = packages.barbell;

      };
    };
}
