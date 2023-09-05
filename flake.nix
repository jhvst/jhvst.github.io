{

  inputs = {
    devenv.url = "github:cachix/devenv";
    flake-parts.url = "github:hercules-ci/flake-parts";
    juuso.inputs.nixpkgs.follows = "nixpkgs";
    juuso.url = "github:jhvst/nix-config";
    mk-shell-bin.url = "github:rrbutani/nix-mk-shell-bin";
    nix2container.inputs.nixpkgs.follows = "nixpkgs";
    nix2container.url = "github:nlewo/nix2container";
    nixneovimplugins.url = "github:jooooscha/nixpkgs-vim-extra-plugins";
    nixpkgs.url = "github:nixos/nixpkgs";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";
    nixvim.url = "github:nix-community/nixvim";

    # blogposts
    j1.url = "github:jhvst/jhvst.github.io?dir=blogPosts/j1";
    barbell.url = "github:jhvst/jhvst.github.io?dir=blogPosts/barbell";
    vksum.url = "github:jhvst/jhvst.github.io?dir=blogPosts/vulkan-sum-reduction";
    ipxe-rpi4.url = "github:jhvst/jhvst.github.io?dir=blogPosts/ipxe-rpi4";
    ramsteam.url = "github:jhvst/jhvst.github.io?dir=blogPosts/RAMsteam";
    modular-neovim.url = "github:jhvst/jhvst.github.io?dir=blogPosts/modular-neovim";

    # papers
    bsc-thesis.url = "github:jhvst/jhvst.github.io?dir=papers/bsc-thesis";
    standrews.url = "github:jhvst/jhvst.github.io?dir=papers/msc-thesis-standrews";
  };

  outputs =
    inputs@{ self
    , flake-parts
    , nixneovimplugins
    , nixpkgs
    , nixvim
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
        inputs.devenv.flakeModule
      ];

      perSystem = { pkgs, lib, config, system, ... }: {

        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          overlays = [
            inputs.juuso.overlays.default
          ];
          config = { };
        };

        packages.default = pkgs.stdenv.mkDerivation {

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

        packages.neovim = nixvim.legacyPackages.${system}.makeNixvimWithModule {
          inherit pkgs;
          module = {
            imports = [
              inputs.juuso.outputs.nixosModules.neovim
            ];
            extraConfigVim = ''
              let g:sqlite_clib_path = '${pkgs.sqlite.out}/lib/libsqlite3.dylib'

              let g:limelight_bop = '^'
              let g:limelight_eop = '$'

              augroup autoformat_settings
                autocmd FileType html,css,sass,scss,less,json,js AutoFormatBuffer js-beautify
              augroup END
            '';
            extraConfigLua = ''
              require("papis").setup({
                db_path = "/Users/juuso/.papis/papis-nvim.sqlite3",
                papis_python = {
                  dir = "/Users/juuso/.papis",
                  info_name = "info.yaml",
                  notes_name = [[notes.org]],
                },
                enable_keymaps = true,
              })
            '';
            extraPackages = with pkgs; [
              nodePackages.js-beautify
              papis
              sqlite
              yq-go
              # ncurses # papis has dependency on ncurses, but it is broken on macOS -- install with brew instead. see: https://github.com/jhvst/nix-config/commit/360220836e1f03b5b0668f2f33af1ecc247d8d15
            ];
            extraPlugins = with pkgs.vimPlugins; [
              goyo-vim
              limelight-vim # :LimeLight (also, consider :setlocal spell spelllang=en_us
              markdown-preview-nvim # :MarkdownPreview
              nui-nvim
              null-ls-nvim
              plenary-nvim
            ] ++ [
              nixneovimplugins.packages.${system}.papis-nvim
              nixneovimplugins.packages.${system}.sqlite-lua
            ];
            plugins.lsp.servers.html.enable = true;
            plugins.nvim-cmp = {
              sources =
                [
                  { name = "latex_symbols"; }
                  { name = "papis"; }
                ];
            };
          };
        };

        devenv.shells.default = {

          packages = [
            config.packages.neovim
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
          inherit (self) outputs;
        in
        {

          templates.default = {
            path = ./templates;
            description = "A flake for blogPosts";
          };

        };

    };
}
