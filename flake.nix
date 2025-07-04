{

  inputs = {
    barbell-pkg.url = "github:jhvst/barbell";
    devshell.url = "github:numtide/devshell";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-2405.url = "github:nixos/nixpkgs/nixos-24.05";
    nuenv.url = "github:DeterminateSystems/nuenv";

    # flake archived blog posts
    j1.url = "github:jhvst/jhvst.github.io?dir=blogPosts/j1";
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
          mkBlogPost = { name, title, description, pubDate, grammars ? [ ], distInclude ? "", distInstall ? "", src }: pkgs.callPackage ./packages/mkBlogPost {
            inherit name title description pubDate grammars distInclude distInstall src;
            barbell = inputs'.barbell-pkg.packages.barbell;
            js-beautify = pkgs.nodePackages.js-beautify;
            pandoc = pkgs.pandoc;
            python-slugify = pkgs.python313Packages.python-slugify;
            validator-nu = pkgs.validator-nu;
            pageTemplate = ./packages/mkBlogPost/template_article.html;
            woff2 = pkgs.woff2;
            servo = pkgs.servo;
            mesa = pkgs.mesa;
          };
        in
        {

          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [
              inputs.nuenv.overlays.nuenv
              self.overlays.default
            ];
            config = { };
          };

          overlayAttrs = {
            inherit (config.packages)
              tree-sitter
              tree-sitter-cli
              hq
              ogq
              ;
          };

          packages."tree-sitter" = (inputs'.nixpkgs-2405.legacyPackages.tree-sitter.override {
            webUISupport = true;
          }).overrideAttrs (old: {
            nativeBuildInputs = [ pkgs.breakpointHook ] ++ old.nativeBuildInputs;
            postInstall = ''
              mkdir -p $out/lib
              cp lib/binding_web/tree-sitter.js $out/lib
              cp lib/binding_web/tree-sitter.wasm $out/lib
            '';
          });

          packages."tree-sitter-cli" = pkgs.callPackage ./packages/tree-sitter-cli {
            tree-sitter = inputs'.nixpkgs.legacyPackages.tree-sitter;
            grammars = [
              inputs'.nixpkgs.legacyPackages.tree-sitter-grammars.tree-sitter-html
            ];
          };

          packages."hq" = pkgs.callPackage ./packages/hq {
            tree-sitter-cli = config.packages.tree-sitter-cli;
            writeShellApplication = pkgs.nuenv.writeShellApplication;
          };

          packages."ogq" = pkgs.callPackage ./packages/ogq {
            hq = config.packages.hq;
            jq = inputs'.nixpkgs.legacyPackages.jq;
          };

          packages.barbell = mkBlogPost rec {
            description = "Barbell is like the template system Handlebars, but with BQN's Under doing the heavy lifting.";
            name = "barbell";
            pubDate = "28 Jun 2023 21:19:00 GMT";
            title = "Barbell: Template System in BQN";
            src = ./blogPosts/${name};
            grammars = [
              inputs'.nixpkgs.legacyPackages.tree-sitter-grammars.tree-sitter-bqn
            ];
            distInstall = ''
              cp ${pkgs.mbqn}/share/bqn/libbqn.js $out/libbqn.js
            '';
            distInclude = ''
              <script src="libbqn.js"></script>
              <link rel='stylesheet' href='https://cdn.jsdelivr.net/npm/katex@0.16.7/dist/katex.min.css' integrity='sha384-3UiQGuEI4TTMaFmGIZumfRPtfKQ3trwQE2JgosJxCnGmQpL/lJdjpcHkaaFwHlcI' crossorigin='anonymous'>

              <script defer src='https://cdn.jsdelivr.net/npm/katex@0.16.7/dist/katex.min.js' integrity='sha384-G0zcxDFp5LWZtDuRMnBkk3EphCK1lhEf4UEyEM693ka574TZGwo4IWwS6QLzM/2t' crossorigin='anonymous'></script>

              <script>
                  document.addEventListener('DOMContentLoaded', function() {
                      var mathElements = document.getElementsByClassName('math');
                      var macros = [];
                      for (var i = 0; i < mathElements.length; i++) {
                          var texText = mathElements[i].firstChild;
                          if (mathElements[i].tagName == 'SPAN') {
                              katex.render(texText.data, mathElements[i], {
                                  displayMode: mathElements[i].classList.contains('display'),
                                  throwOnError: false,
                                  macros: macros,
                                  fleqn: false
                              });
                          }
                      }
                  });
              </script>
            '';
          };

          packages."higher-order-filter-bqn-uiua" = mkBlogPost rec {
            name = "higher-order-filter-bqn-uiua";
            title = "Combinatory Tetris";
            description = "Implementing a higher-order filter in Uiua and BQN";
            pubDate = "31 Jul 2024 10:00:00 GMT";
            grammars = [
              inputs'.nixpkgs.legacyPackages.tree-sitter-grammars.tree-sitter-bqn
              pkgs.tree-sitter-grammars.tree-sitter-haskell
              pkgs.tree-sitter-grammars.tree-sitter-uiua
            ];
            distInstall = ''
              cp ${pkgs.mbqn}/share/bqn/libbqn.js $out/libbqn.js
            '';
            distInclude = ''
              <script src="libbqn.js"></script>
            '';
            src = ./blogPosts/${name};
          };

          packages."bidirectionality-bqn-uiua" = mkBlogPost rec {
            name = "bidirectionality-bqn-uiua";
            title = "APL: A Profunctor Language";
            description = "Implementing a higher-order filter in Uiua and BQN";
            pubDate = "31 Jul 2024 10:00:00 GMT";
            grammars = [
              inputs'.nixpkgs.legacyPackages.tree-sitter-grammars.tree-sitter-bqn
              pkgs.tree-sitter-grammars.tree-sitter-uiua
            ];
            distInstall = ''
              cp ${pkgs.mbqn}/share/bqn/libbqn.js $out/libbqn.js
            '';
            distInclude = ''
              <script src="libbqn.js"></script>
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

          packages."ipxe-rpi4" = mkBlogPost rec {
            name = "ipxe-rpi4";
            title = "iPXE, NixOS, EDK2 UEFI BIOS, and Raspberry Pi 4";
            description = "This is an excerpt from a reddit comment of mine in response to running NixOS with additional kernel modules on NixOS.";
            pubDate = "12 Nov 2022 11:57:50 GMT";
            src = ./blogPosts/${name};
            grammars = [
              pkgs.tree-sitter-grammars.tree-sitter-nix
            ];
          };

          packages."RAMsteam" = mkBlogPost rec {
            name = "RAMsteam";
            title = "RAMsteam";
            description = "Explanation more or less how Linux boots.";
            pubDate = "29 Nov 2022 02:19:00 GMT";
            src = ./blogPosts/${name};
          };

          packages."nix-as-a-static-site-generator" = mkBlogPost rec {
            name = "nix-as-a-static-site-generator";
            title = "Nix as a Static Site Generator";
            description = "A pathway incremental builds and reproducability";
            pubDate = "10 Sep 2023 17:31:00 GMT";
            src = ./blogPosts/${name};
            grammars = [
              pkgs.tree-sitter-grammars.tree-sitter-nix
            ];
          };

          packages."modular-neovim" = mkBlogPost rec {
            name = "modular-neovim";
            title = "Modular Neovim with Nix";
            description = "Expanding your Neovim configuration on per-project basis using Nix and devenv.";
            pubDate = "03 Sep 2023 20:19:00 GMT";
            src = ./blogPosts/${name};
            grammars = [
              pkgs.tree-sitter-grammars.tree-sitter-nix
            ];
          };

          packages."vulkan-sum-reduction" = mkBlogPost rec {
            name = "vulkan-sum-reduction";
            title = "Vulkan sum reduction";
            description = "Sum reduction using SPIR-V subgroups up to vector length of 4096.";
            pubDate = "23 Mar 2022 16:30:00 GMT";
            src = ./blogPosts/${name};
            distInclude = ''
              <link rel='stylesheet' href='https://cdn.jsdelivr.net/npm/katex@0.16.7/dist/katex.min.css' integrity='sha384-3UiQGuEI4TTMaFmGIZumfRPtfKQ3trwQE2JgosJxCnGmQpL/lJdjpcHkaaFwHlcI' crossorigin='anonymous'>

              <script defer src='https://cdn.jsdelivr.net/npm/katex@0.16.7/dist/katex.min.js' integrity='sha384-G0zcxDFp5LWZtDuRMnBkk3EphCK1lhEf4UEyEM693ka574TZGwo4IWwS6QLzM/2t' crossorigin='anonymous'></script>

              <script>
                  document.addEventListener('DOMContentLoaded', function() {
                      var mathElements = document.getElementsByClassName('math');
                      var macros = [];
                      for (var i = 0; i < mathElements.length; i++) {
                          var texText = mathElements[i].firstChild;
                          if (mathElements[i].tagName == 'SPAN') {
                              katex.render(texText.data, mathElements[i], {
                                  displayMode: mathElements[i].classList.contains('display'),
                                  throwOnError: false,
                                  macros: macros,
                                  fleqn: false
                              });
                          }
                      }
                  });
              </script>
            '';
          };

          packages.blogPosts = with config.packages;
            pkgs.stdenv.mkDerivation {
              name = "blogPostsnonFlake";
              src = ./.;
              buildPhase = lib.strings.concatLines (lib.lists.forEach [
                barbell
                fido2-luks
                higher-order-filter-bqn-uiua
                RAMsteam
                ipxe-rpi4
                modular-neovim
                vulkan-sum-reduction
                nix-as-a-static-site-generator
                inputs'.j1.packages.default
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
            title = "MSc thesis: Static Semantics of Rank Polymorphism";
            src = ./papers/msc-thesis-standrews;
            pandoc = pkgs.pandoc;
          };

          packages.bsc-thesis = pkgs.callPackage ./packages/mkPaperLaTeX {
            name = "bsc-thesis";
            title = "BSc thesis: Latency-optimized edge computing in 5G cellular networks";
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

          packages.blog = with config.packages; pkgs.stdenv.mkDerivation {
            name = "Blog of Juuso Haavisto";
            src = ./.;
            buildPhase = ''
              ${blogPosts.buildPhase}
              ${mkPapersLaTeX.buildPhase}

              mkdir -p $out/projects/highlightplay/theinternational5
              cp -r projects/highlightplay/theinternational5/* $out/projects/highlightplay/theinternational5

              cp -r css $out
              cp -r img $out

              cp *.html $out
              rm $out/cv.html
              rm $out/index.html
            '';
          };

          packages.site = with config.packages; pkgs.stdenv.mkDerivation {
            name = "Site of Juuso Haavisto";
            src = ./.;
            buildPhase = ''
              ${blog.buildPhase}
              cp ${rss2}/rss.xml $out
              cp -r SPAs $out
              cp cv.html $out
              cp favicon.svg $out
              cp robots.txt $out
            '';
          };

          packages.default = with config.packages;
            let
              patches = pkgs.writeTextFile {
                name = "redirections.patch";
                text = builtins.readFile ./redirections.patch;
              };
            in
            pkgs.stdenv.mkDerivation {
              name = "Juuso Haavisto";
              src = ./.;
              buildInputs = [ pkgs.git inputs'.barbell-pkg.packages.barbell ];
              buildPhase = ''
                ${site.buildPhase}
                cp ${config.packages.sitemapHTML}/sitemap.html sitemap.bar
                barbell index.html > $out/index.html
              '';
              installPhase = ''
                git apply --unsafe-paths --directory $out ${patches}
                install -D ${config.packages.sitemapXML}/sitemap.xml $out/sitemap.xml
              '';
            };

          packages.sitemap = pkgs.stdenv.mkDerivation {
            name = "sitemap";
            src = config.packages.blog.outPath;
            buildInputs = [ pkgs.fd pkgs.jq ];
            buildPhase = ''
              fd -t f -e html | jq -R -s -c 'split("\n") | map(select(length > 0))' > sitemap.json
            '';
            installPhase = ''
              install -D sitemap.json $out/sitemap.json
            '';
          };

          packages.sitemapXML =
            let
              sitemap = config.packages.sitemap.overrideAttrs (_: prev: {
                src = config.packages.site.outPath;
              });
              entriesJSON = builtins.fromJSON (builtins.readFile "${sitemap}/sitemap.json");
            in
            pkgs.stdenv.mkDerivation rec {
              name = "sitemap-xml";
              src = ./.;
              urls = lib.lists.forEach entriesJSON (entry: ''
                <url>
                  <loc>https://juuso.dev/${entry}</loc>
                </url>
              '');
              urlset = ''
                <?xml version="1.0" encoding="UTF-8"?>
                <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
                  ${ lib.strings.concatLines urls }
                </urlset>
              '';
              buildInputs = [ pkgs.xq-xml ];
              feed = pkgs.writeText "feed.xml" urlset;
              buildPhase = ''
                xq ${feed} > sitemap.xml
              '';
              installPhase = ''
                install -D sitemap.xml $out/sitemap.xml;
              '';
            };

          packages.sitemapHTML =
            let
              entriesJSON = builtins.fromJSON (builtins.readFile "${config.packages.rss}/graphs.json");
            in
            pkgs.stdenv.mkDerivation rec {
              name = "sitemap-html";
              src = ./.;
              urls = lib.lists.forEach entriesJSON (entry: ''
                <li>
                  <a href="./${lib.strings.removePrefix "https://juuso.dev/" entry."og:url"}">${entry."og:title"}</a>
                </li>
              '');
              urlset = ''
                <ol>
                  ${ lib.strings.concatLines urls }
                </ol>
              '';
              feed = pkgs.writeText "links.html" urlset;
              installPhase = ''
                install -D ${feed} $out/sitemap.html;
              '';
            };

          packages.rss = pkgs.callPackage ./packages/mkOpengraph/all.nix {
            src = config.packages.blog.outPath;
            jq = inputs'.nixpkgs.legacyPackages.jq;
            fileset = builtins.fromJSON (builtins.readFile "${config.packages.sitemap}/sitemap.json");
            ogq = config.packages.ogq;
            siteURL = "https://juuso.dev";
          };

          packages.rss2 =
            let
              entriesJSON = builtins.fromJSON (builtins.readFile "${config.packages.rss}/graphs.json");
            in
            pkgs.stdenv.mkDerivation rec {
              name = "rss2";
              src = config.packages.rss.outPath;
              entriesXML = lib.lists.forEach entriesJSON (entry: ''
                <item>
                  <title>${entry."og:title"}</title>
                  <link>${entry."og:url"}</link>
                  <pubDate>${entry."pubDate"}</pubDate>
                </item>
              '');
              channel = ''
                <?xml version="1.0" encoding="UTF-8" ?>
                <?xml-stylesheet href="css/pretty-feed-v3.xsl" type="text/xsl"?>
                <rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
                <channel>
                  <title>Juuso Haavisto</title>
                  <link>https://juuso.dev</link>
                  <atom:link href="https://juuso.dev/rss.xml" rel="self" type="application/rss+xml" />
                  <description>Escape from Finnish farmland</description>
                  ${ lib.strings.concatLines entriesXML }
                </channel>
                </rss>
              '';
              buildInputs = [ pkgs.xq-xml ];
              feed = pkgs.writeText "feed.xml" channel;
              buildPhase = ''
                xq ${feed} > rss.xml
              '';
              installPhase = ''
                install -D rss.xml $out/rss.xml
              '';
            };

          devshells.default = {

            packages = with pkgs; [
              hq
              inputs'.barbell-pkg.packages.barbell
              ogq
              papis
              tomb
              tree-sitter-cli
            ];

            commands = [{
              name = "png-compress";
              help = "compress pngs recursively";
              command = "${lib.getExe pkgs.pngquant} img/*.png img/*/*.png --ext .png --force --strip --verbose";
            }];

          };
        };

      flake =
        let
          inherit (self) outputs;
        in
        { };
    };
}