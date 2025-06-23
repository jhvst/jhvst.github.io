{

  inputs = {
    barbell-pkg.url = "github:jhvst/barbell";
    devshell.url = "github:numtide/devshell";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:nixos/nixpkgs/24.05";

    # blogposts
    j1.url = "github:jhvst/jhvst.github.io?dir=blogPosts/j1";
    vksum.url = "github:jhvst/jhvst.github.io?dir=blogPosts/vulkan-sum-reduction";
    ipxe-rpi4.url = "github:jhvst/jhvst.github.io?dir=blogPosts/ipxe-rpi4";
    ramsteam.url = "github:jhvst/jhvst.github.io?dir=blogPosts/RAMsteam";
    modular-neovim.url = "github:jhvst/jhvst.github.io?dir=blogPosts/modular-neovim";
    nix-static.url = "github:jhvst/jhvst.github.io?dir=blogPosts/nix-as-a-static-site-generator";
  };

  outputs = { self, ... }@inputs:

    inputs.flake-parts.lib.mkFlake { inherit inputs; } {

      systems = inputs.nixpkgs.lib.systems.flakeExposed;
      imports = [
        inputs.devshell.flakeModule
        inputs.flake-parts.flakeModules.easyOverlay
      ];

      perSystem = { pkgs, lib, config, system, inputs', ... }:
        let
          mkBlogPost = { name, title, description, pubDate, distInclude ? "", distInstall ? "", src }: pkgs.callPackage ./packages/mkBlogPost {
            inherit name title description pubDate distInclude distInstall src;
            barbell = inputs'.barbell-pkg.packages.barbell;
            js-beautify = pkgs.nodePackages.js-beautify;
            pandoc = pkgs.pandoc;
            python-slugify = pkgs.python313Packages.python-slugify;
            validator-nu = pkgs.validator-nu;
            web-components = config.packages.web-components;
            woff2 = pkgs.woff2;
          };
        in
        {

          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [
              self.overlays.default
            ];
            config = { };
          };

          overlayAttrs = {
            inherit (config.packages)
              tree-sitter
              ;
          };

          packages.web-components = pkgs.stdenv.mkDerivation {
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

          packages."tree-sitter" = (inputs'.nixpkgs.legacyPackages.tree-sitter.override {
            webUISupport = true;
          }).overrideAttrs (_: {
            preInstall = ''
              mkdir -p $out/lib
              cp lib/binding_web/tree-sitter.js $out/lib
              cp lib/binding_web/tree-sitter.wasm $out/lib
            '';
          });

          packages."tree-sitter-uiua-wasm" = pkgs.stdenv.mkDerivation {
            pname = "tree-sitter-uiua-wasm";
            version = "0.22.6";
            src = pkgs.fetchFromGitHub {
              owner = "shnarazk";
              repo = "tree-sitter-uiua";
              rev = "942e8365d10b9b62be9f2a8b0503459d3d8f3af3";
              hash = "sha256-yWlUnFbM0WsV7VhQQcTfogLarsV1yBhTBuea2LZukN8=";
            };

            phases = [
              "unpackPhase"
              "buildPhase"
            ];
            buildPhase = ''
              mkdir -p .emscriptencache
              export EM_CACHE=$(pwd)/.emscriptencache
              mkdir -p $out/bin
              ${config.packages.tree-sitter}/bin/tree-sitter build --wasm
              cp tree-sitter-uiua.wasm $out/bin/
            '';
          };

          packages."tree-sitter-bqn-wasm" = pkgs.stdenv.mkDerivation rec {
            pname = "tree-sitter-bqn-wasm";
            version = "0.3.2";
            src = pkgs.fetchFromGitHub {
              owner = "shnarazk";
              repo = "tree-sitter-bqn";
              rev = "v${version}";
              hash = "sha256-/FsA5GeFhWYFl1L9pF+sQfDSyihTnweEdz2k8mtLqnY=";
            };

            phases = [
              "unpackPhase"
              "buildPhase"
            ];
            buildPhase = ''
              mkdir -p .emscriptencache
              export EM_CACHE=$(pwd)/.emscriptencache
              mkdir -p $out/bin
              ${config.packages.tree-sitter}/bin/tree-sitter build --wasm
              cp tree-sitter-bqn.wasm $out/bin/

              mkdir -p $out/queries
              cp -r queries/* $out/queries
            '';
          };

          packages."apple-music-linux-pipewire" = mkBlogPost rec {
            name = "apple-music-linux-pipewire";
            title = "Apple Music on Linux using Pipewire";
            description = "Streaming DRM music to Linux from an iPhone";
            pubDate = "28 Jan 2024 16:10:00 GMT";
            src = ./blogPosts/${name};
          };

          packages.barbell = mkBlogPost rec {
            description = "Barbell is like the template system Handlebars, but with BQN's Under doing the heavy lifting.";
            name = "barbell";
            pubDate = "28 Jun 2023 21:19:00 GMT";
            title = "Barbell: Template System in BQN";
            src = ./blogPosts/${name};
            distInstall = ''
              cp ${config.packages.tree-sitter}/lib/tree-sitter.js $out/tree-sitter.js
              cp ${config.packages.tree-sitter}/lib/tree-sitter.wasm $out/tree-sitter.wasm

              cp ${pkgs.mbqn}/share/bqn/libbqn.js $out/libbqn.js
              cp ${config.packages.tree-sitter-bqn-wasm}/bin/tree-sitter-bqn.wasm $out/tree-sitter-bqn.wasm
              cp ${config.packages.tree-sitter-bqn-wasm}/queries/highlights.scm $out/highlights-bqn.scm
            '';
            distInclude = ''
              <script src="libbqn.js"></script>
              <script src="tree-sitter.js"></script>
            '';
          };

          packages."higher-order-filter-bqn-uiua" = mkBlogPost rec {
            name = "higher-order-filter-bqn-uiua";
            title = "Combinatory Tetris";
            description = "Implementing a higher-order filter in Uiua and BQN";
            pubDate = "31 Jul 2024 10:00:00 GMT";
            distInstall = ''
              cp ${config.packages.tree-sitter}/lib/tree-sitter.js $out/tree-sitter.js
              cp ${config.packages.tree-sitter}/lib/tree-sitter.wasm $out/tree-sitter.wasm

              cp ${pkgs.mbqn}/share/bqn/libbqn.js $out/libbqn.js
              cp ${config.packages.tree-sitter-bqn-wasm}/bin/tree-sitter-bqn.wasm $out/tree-sitter-bqn.wasm
              cp ${config.packages.tree-sitter-bqn-wasm}/queries/highlights.scm $out/highlights-bqn.scm

              cp ${config.packages.tree-sitter-uiua-wasm}/bin/tree-sitter-uiua.wasm $out/tree-sitter-uiua.wasm
              cp ${pkgs.tree-sitter-grammars.tree-sitter-uiua}/queries/highlights.scm $out/highlights-uiua.scm
            '';
            distInclude = ''
              <script src="libbqn.js"></script>
              <script src="tree-sitter.js"></script>
            '';
            src = ./blogPosts/${name};
          };

          packages."bidirectionality-bqn-uiua" = mkBlogPost rec {
            name = "bidirectionality-bqn-uiua";
            title = "APL: A Profunctor Language";
            description = "Implementing a higher-order filter in Uiua and BQN";
            pubDate = "31 Jul 2024 10:00:00 GMT";
            distInstall = ''
              cp ${config.packages.tree-sitter}/lib/tree-sitter.js $out/tree-sitter.js
              cp ${config.packages.tree-sitter}/lib/tree-sitter.wasm $out/tree-sitter.wasm

              cp ${pkgs.mbqn}/share/bqn/libbqn.js $out/libbqn.js
              cp ${config.packages.tree-sitter-bqn-wasm}/bin/tree-sitter-bqn.wasm $out/tree-sitter-bqn.wasm
              cp ${config.packages.tree-sitter-bqn-wasm}/queries/highlights.scm $out/highlights-bqn.scm

              cp ${config.packages.tree-sitter-uiua-wasm}/bin/tree-sitter-uiua.wasm $out/tree-sitter-uiua.wasm
              cp ${pkgs.tree-sitter-grammars.tree-sitter-uiua}/queries/highlights.scm $out/highlights-uiua.scm
            '';
            distInclude = ''
              <script src="libbqn.js"></script>
              <script src="tree-sitter.js"></script>
            '';
            src = ./blogPosts/${name};
          };

          packages."fido2-luks" = mkBlogPost rec {
            name = "fido2-luks";
            title = "Multi-token FIDO2 LUKS";
            description = "What happens to your data if your computer gets lost or stolen?";
            pubDate = "8 Jun 2025 23:09:00 GMT";
            src = ./blogPosts/${name};
          };

          packages.blogPostsnonFlake = with config.packages; pkgs.stdenv.mkDerivation {
            name = "blogPostsnonFlake";
            src = ./.;
            buildPhase = lib.strings.concatLines (lib.lists.forEach [
              barbell
              apple-music-linux-pipewire
              higher-order-filter-bqn-uiua
              fido2-luks
            ]
              (post:
                ''
                  mkdir -p $out/blogPosts/${post.name}
                  cp -r ${post.out}/* $out/blogPosts/${post.name}
                ''
              ));
          };

          packages.blogPostsFlake = with inputs'; pkgs.stdenv.mkDerivation {
            name = "blogPostsFlake";
            src = ./.;
            buildPhase = lib.strings.concatLines (lib.lists.forEach [
              j1.packages.default
              vksum.packages.default
              ipxe-rpi4.packages.default
              ramsteam.packages.default
              modular-neovim.packages.default
              nix-static.packages.default
            ]
              (post:
                ''
                  mkdir -p $out/blogPosts/${post.name}
                  cp -r ${post.out}/* $out/blogPosts/${post.name}
                ''
              ));
          };

          packages.msc-thesis-standrews = pkgs.callPackage ./packages/mkPaperLaTeX {
            name = "msc-thesis-standrews";
            src = ./papers/msc-thesis-standrews;
            pandoc = pkgs.pandoc;
          };

          packages.bsc-thesis = pkgs.callPackage ./packages/mkPaperLaTeX {
            name = "bsc-thesis";
            src = ./papers/bsc-thesis;
            pandoc = pkgs.pandoc;
          };

          packages.mkPapersLaTeX = with config; pkgs.stdenv.mkDerivation {
            name = "mkPapersLaTeX";
            src = ./.;
            buildPhase = lib.strings.concatLines (lib.lists.forEach [
              packages.bsc-thesis
              packages.msc-thesis-standrews
            ]
              (post:
                ''
                  mkdir -p $out/papers/${post.name}
                  cp -r ${post.out}/* $out/papers/${post.name}
                ''
              ));
          };

          packages.default = with config.packages; pkgs.stdenv.mkDerivation {
            name = "Juuso Haavisto";
            src = ./.;
            phases = [ "unpackPhase" "buildPhase" ];
            buildPhase = ''
              ${blogPostsFlake.buildPhase}
              ${blogPostsnonFlake.buildPhase}
              ${mkPapersLaTeX.buildPhase}

              mkdir -p $out/projects/highlightplay/theinternational5
              cp -r projects/highlightplay/theinternational5/* $out/projects/highlightplay/theinternational5

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

          devshells.default = {

            packages = with pkgs; [
              butane
              ripgrep
            ];

            commands = [{
              name = "png-compress";
              help = "compress pngs recursively";
              command = "${lib.getExe pkgs.pngquant} img/*.png img/*/*.png --ext .png --force --strip --verbose";
            }];

          };
        };
    };
}