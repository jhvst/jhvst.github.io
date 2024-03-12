{

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    juuso.url = "github:jhvst/nix-config";
    nixneovimplugins.url = "github:NixNeovim/NixNeovimPlugins";
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
            inputs.nixneovimplugins.overlays.default
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

              let g:mkdp_browser = '${pkgs.kdePackages.falkon}/bin/falkon'
              let g:mkdp_echo_preview_url = 1

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

              local gknapsettings = {
                delay = 420,
                mdoutputext = "pdf",
                mdtopdf = "pandoc %docroot% -t typst -o %outputfile%",
              }
              vim.g.knap_settings = gknapsettings

              -- set shorter name for keymap function
              local kmap = vim.keymap.set

              -- F5 processes the document once, and refreshes the view
              kmap({ 'n', 'v', 'i' },'<F5>', function() require("knap").process_once() end)

              -- F6 closes the viewer application, and allows settings to be reset
              kmap({ 'n', 'v', 'i' },'<F6>', function() require("knap").close_viewer() end)

              -- F7 toggles the auto-processing on and off
              kmap({ 'n', 'v', 'i' },'<F7>', function() require("knap").toggle_autopreviewing() end)

              -- F8 invokes a SyncTeX forward search, or similar, where appropriate
              kmap({ 'n', 'v', 'i' },'<F8>', function() require("knap").forward_jump() end)
            '';
            extraPackages = with pkgs; [
              kdePackages.falkon
              ncurses # papis has dependency on ncurses, but it is broken on macOS -- install with brew instead. see: https://github.com/jhvst/nix-config/commit/360220836e1f03b5b0668f2f33af1ecc247d8d15
              nodePackages.js-beautify
              pandoc
              papis
              sioyek
              sqlite
              typst
              xdg-utils
              yq-go
            ];
            extraPlugins = with pkgs.vimPlugins; [
              goyo-vim
              knap
              limelight-vim # :LimeLight (also, consider :setlocal spell spelllang=en_us
              markdown-preview-nvim # :MarkdownPreview
              nui-nvim
              null-ls-nvim
              plenary-nvim
            ] ++ [
              pkgs.vimExtraPlugins.papis-nvim
              pkgs.vimExtraPlugins.sqlite-lua
            ];
            plugins.lsp.servers.html.enable = true;
            plugins.cmp.settings = {
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
