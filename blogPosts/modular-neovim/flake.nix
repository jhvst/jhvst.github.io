{

  inputs = {
    barbell.inputs.nixpkgs.follows = "nixpkgs";
    barbell.url = "github:jhvst/barbell?dir=packages/barbell";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:nixos/nixpkgs/23.05";
    web-components.url = "github:jhvst/jhvst.github.io?dir=packages/web-components";
  };

  outputs =
    inputs@{ self
    , nixpkgs
    , flake-parts
    , ...
    }:

    flake-parts.lib.mkFlake { inherit inputs; } {

      systems = nixpkgs.lib.systems.flakeExposed;
      imports = [ ];

      perSystem = { pkgs, lib, config, inputs', ... }: {

        packages.default = pkgs.stdenv.mkDerivation rec {

          title = "Modular Neovim with Nix";
          description = "Expanding your Neovim configuration on per-project basis using Nix and devenv.";
          pubDate = "03 Sep 2023 20:19:00 GMT";

          name = "modular-neovim";
          src = ./.;
          buildInputs = with pkgs; [
            inputs'.barbell.packages.barbell
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
            cp -r ${inputs'.web-components.packages.default}/html/* ./html
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
