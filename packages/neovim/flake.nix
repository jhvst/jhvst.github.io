{

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    juuso.url = "github:jhvst/nix-config";
    nixneovimplugins.url = "github:jooooscha/nixpkgs-vim-extra-plugins";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";
    nixpkgs.inputs.nixpkgs.follows = "juuso";
    nixvim.url = "github:nix-community/nixvim";
  };

  outputs =
    inputs@{ self
    , flake-parts
    , juuso
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
      imports = [ ];

      perSystem = { pkgs, lib, config, system, ... }: {

        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          overlays = [
            inputs.juuso.overlays.default
          ];
          config = { };
        };

        packages.neovim = nixvim.legacyPackages.${system}.makeNixvimWithModule {
          inherit pkgs;
          module = {
            imports = [
              inputs.juuso.outputs.nixosModules.neovim
            ];
            extraConfigVim = ''
              ${if pkgs.system == "aarch64-darwin" then
                "let g:sqlite_clib_path = '${pkgs.sqlite.out}/lib/libsqlite3.dylib'"
              else
                "let g:sqlite_clib_path = '${pkgs.sqlite.out}/lib/libsqlite3.so'"
              }

              let g:limelight_bop = '^'
              let g:limelight_eop = '$'

              augroup autoformat_settings
                autocmd FileType html,css,sass,scss,less,json,js AutoFormatBuffer js-beautify
              augroup END
            '';
            extraConfigLua = ''
              require("papis").setup({
                db_path = "${juuso.nixosConfigurations.starlabs.config.users.users.juuso.home}/.papis/papis-nvim.sqlite3",
                papis_python = {
                  dir = "${juuso.nixosConfigurations.starlabs.config.users.users.juuso.home}/.papis",
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

        packages.default = config.packages.neovim;

      };

    };
}
