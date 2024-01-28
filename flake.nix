{

  inputs = {
    devenv.url = "github:cachix/devenv";
    flake-parts.url = "github:hercules-ci/flake-parts";
    mk-shell-bin.url = "github:rrbutani/nix-mk-shell-bin";
    nix2container.inputs.nixpkgs.follows = "nixpkgs";
    nix2container.url = "github:nlewo/nix2container";
    nixpkgs.url = "github:nixos/nixpkgs/23.05";

    # blogposts
    j1.url = "github:jhvst/jhvst.github.io?dir=blogPosts/j1";
    barbell.url = "github:jhvst/jhvst.github.io?dir=blogPosts/barbell";
    vksum.url = "github:jhvst/jhvst.github.io?dir=blogPosts/vulkan-sum-reduction";
    ipxe-rpi4.url = "github:jhvst/jhvst.github.io?dir=blogPosts/ipxe-rpi4";
    ramsteam.url = "github:jhvst/jhvst.github.io?dir=blogPosts/RAMsteam";
    modular-neovim.url = "github:jhvst/jhvst.github.io?dir=blogPosts/modular-neovim";
    nix-static.url = "github:jhvst/jhvst.github.io?dir=blogPosts/nix-as-a-static-site-generator";

    # papers
    bsc-thesis.url = "github:jhvst/jhvst.github.io?dir=papers/bsc-thesis";
    standrews.url = "github:jhvst/jhvst.github.io?dir=papers/msc-thesis-standrews";

    # components
    barbell-pkg.url = "github:jhvst/barbell";
  };

  outputs =
    inputs@{ self
    , flake-parts
    , nixpkgs
    , ...
    }:

    flake-parts.lib.mkFlake { inherit inputs; } {

      systems = nixpkgs.lib.systems.flakeExposed;
      imports = [
        inputs.devenv.flakeModule
      ];

      perSystem = { pkgs, lib, config, system, inputs', ... }:
        let
          mkBlogPost =
            { name
            , title
            , description
            , pubDate
            , src
            ,
            }:
            let
              "web-components" = pkgs.stdenv.mkDerivation {
                name = "web-components";
                src = ./.;
                phases = [ "unpackPhase" "buildPhase" ];
                buildPhase = ''
                  mkdir -p $out/css
                  mkdir -p $out/html
                  cp css/* $out/css
                  cp html/* $out/html
                '';
              };
            in
            pkgs.stdenv.mkDerivation
              rec {
                inherit name description pubDate src;
                buildInputs = with pkgs; [
                  inputs.barbell-pkg.packages.${system}.barbell
                  nodePackages.js-beautify
                  pandoc
                  python311Packages.python-slugify
                  validator-nu
                  woff2
                ];
                phases = [
                  "unpackPhase"
                  "buildPhase"
                  "checkPhase"
                ];
                buildPhase = ''
                  mkdir -p $out/css
                  mkdir -p $out/img
                  mkdir html
                  cp -r ${web-components.out}/html/* ./html
                  cp ${pkgs.ibm-plex}/share/fonts/opentype/IBMPlexMono-Regular.otf .
                  woff2_compress IBMPlexMono-Regular.otf
                  cp IBMPlexMono-Regular.woff2 $out/
                  pandoc $src/main.md -o main.html

                  echo "${title}" > title.bar
                  echo "${description}" > description.bar
                  echo "${pubDate}" > pubDate.bar
                  echo "${name}" > name.bar
                  slugify ${title} > slug.bar
                  date -d "${pubDate}" -Iminutes > datetime.bar
                  cat $src/main.md | wc -w > wordCount.bar

                  barbell main.html > article.bar
                  barbell html/template_article.html > $out/$(slugify ${title}).html
                  js-beautify -f $out/$(slugify ${title}).html -r
                '';

                doCheck = true;
                checkPhase = ''
                  vnu $out/$(slugify ${title}).html
                '';

              };
        in
        rec {

          packages."apple-music-linux-pipewire" = mkBlogPost rec {
            name = "apple-music-linux-pipewire";
            title = "Apple Music on Linux using Pipewire";
            description = "Streaming DRM music to Linux from an iPhone";
            pubDate = "28 Jan 2024 16:10:00 GMT";
            src = ./blogPosts/${name};
          };

          packages.default = with config.packages; pkgs.stdenv.mkDerivation {

            name = "Juuso Haavisto";
            src = ./.;

            phases = [ "unpackPhase" "buildPhase" ];
            buildPhase = ''
              mkdir -p $out/blogPosts/barbell
              cp -r ${inputs.barbell.outputs.packages.${system}.barbell}/* $out/blogPosts/barbell

              mkdir -p $out/blogPosts/j1
              cp -r ${inputs.j1.outputs.packages.${system}.j1}/* $out/blogPosts/j1

              mkdir -p $out/blogPosts/vulkan-sum-reduction
              cp -r ${inputs.vksum.outputs.packages.${system}.default}/* $out/blogPosts/vulkan-sum-reduction

              mkdir -p $out/blogPosts/ipxe-rpi4
              cp -r ${inputs.ipxe-rpi4.outputs.packages.${system}.default}/* $out/blogPosts/ipxe-rpi4

              mkdir -p $out/blogPosts/RAMsteam
              cp -r ${inputs.ramsteam.outputs.packages.${system}.default}/* $out/blogPosts/RAMsteam

              mkdir -p $out/blogPosts/modular-neovim
              cp -r ${inputs.modular-neovim.outputs.packages.${system}.default}/* $out/blogPosts/modular-neovim

              mkdir -p $out/blogPosts/nix-as-a-static-site-generator
              cp -r ${inputs.nix-static.outputs.packages.${system}.default}/* $out/blogPosts/nix-as-a-static-site-generator

              mkdir -p $out/blogPosts/${apple-music-linux-pipewire.name}
              cp -r ${apple-music-linux-pipewire.out}/* $out/blogPosts/${apple-music-linux-pipewire.name}

              mkdir -p $out/projects/highlightplay/theinternational5
              cp -r projects/highlightplay/theinternational5/* $out/projects/highlightplay/theinternational5

              mkdir -p $out/papers/bsc-thesis
              cp -r ${inputs.bsc-thesis.outputs.packages.${system}.bsc-thesis}/* $out/papers/bsc-thesis

              mkdir -p $out/papers/msc-thesis-standrews
              cp -r ${inputs.standrews.outputs.packages.${system}.default}/* $out/papers/msc-thesis-standrews

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

          devenv.shells.default = {

            packages = with pkgs; [
              butane
            ];

            scripts = {
              img-compress = {
                exec = "${lib.getExe pkgs.pngquant} img/*.png img/*/*.png --ext .png --force --strip --verbose";
              };
            };

          };

        };

      flake =
        let
          inherit (self)
            outputs;
        in
        {

          templates.default = {
            path = ./templates;
            description = "A flake for blogPosts";
          };

        };

    };
}
