{

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    web-components.url = "github:jhvst/jhvst.github.io?dir=packages/web-components";
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

      perSystem = { pkgs, lib, config, system, ... }: rec {

        packages.barbell = pkgs.stdenv.mkDerivation rec {

          title = "Barbell: Templates in BQN";
          description = "Barbell is like the templating system Handlebars, but with BQN's Under doing the heavy lifting";
          pubDate = "28 Jun 2023 21:19:00 GMT";
          author = "Juuso Haavisto";

          name = "barbell";
          src = ./.;
          buildInputs = with pkgs; [
            inputs.barbell.packages.${system}.barbell
            nodePackages.js-beautify
            pandoc
            python311Packages.python-slugify
            validator-nu
            woff2
          ];
          phases = [ "unpackPhase" "buildPhase" "checkPhase" ];
          buildPhase = ''
            mkdir -p $out/css
            mkdir html
            cp -r ${inputs.web-components.packages.${system}.default}/html/* ./html
            cp ${pkgs.ibm-plex}/share/fonts/opentype/IBMPlexMono-Regular.otf .
            woff2_compress IBMPlexMono-Regular.otf
            cp IBMPlexMono-Regular.woff2 $out/
            pandoc main.md --katex -o main.html

            echo "${title}" > title.bar
            echo "${description}" > description.bar
            echo "${pubDate}" > pubDate.bar
            echo "${name}" > name.bar
            slugify ${title} > slug.bar
            date -d "${pubDate}" -Iminutes > datetime.bar
            cat main.md | wc -w > wordCount.bar
            cp -r ./img $out/img/

            barbell main.html > article.bar
            barbell ./html/template_article.html > $out/barbell.html
          '';

          doCheck = true;
          checkPhase = ''
            vnu $out/barbell.html
          '';
        };

        packages.default = packages.barbell;

      };
    };
}
