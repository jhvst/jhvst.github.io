{

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-root.url = "github:srid/flake-root";
    blog-html.url = "github:jhvst/jhvst.github.io?dir=html";
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

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            nodejs
            papis
          ];
        };

        packages.default = pkgs.stdenv.mkDerivation rec {

          title = "Type Guided Scheduling for Heterogenious GPUs";
          description = "";
          pubDate = "23 Mar 2022 16:30:00 GMT";

          name = "type-scheduling";
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
            mkdir -p $out/img
            mkdir html
            cp -r ${inputs.blog-html.packages.${system}.default}/* ./html
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
            barbell main.html > article.bar
            barbell html/template_article.html > $out/$(slugify ${title}).html
            js-beautify -f $out/$(slugify ${title}).html -r
          '';

          doCheck = true;
          checkPhase = ''
            vnu $out/$(slugify ${title}).html
          '';
        };
      };
    };
}
