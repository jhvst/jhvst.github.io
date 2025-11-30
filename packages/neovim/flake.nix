{

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    juuso.url = "github:jhvst/nix-config";
    nixneovimplugins.url = "github:NixNeovim/NixNeovimPlugins";
    nixpkgs.url = "github:NixOS/nixpkgs/25.05";
    nixvim.url = "github:nix-community/nixvim";
    papis.url = "github:jghauser/papis.nvim";
  };

  outputs = inputs@{ ... }:

    inputs.flake-parts.lib.mkFlake { inherit inputs; } {

      systems = inputs.nixpkgs.lib.systems.flakeExposed;

      perSystem = { pkgs, config, system, ... }: {

        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          overlays = [
            inputs.juuso.overlays.default
            inputs.nixneovimplugins.overlays.default
            inputs.papis.overlays.default
          ];
          config = { };
        };

        packages.neovim = inputs.nixvim.legacyPackages.${system}.makeNixvimWithModule {
          inherit pkgs;
          module = {
            imports = [
              inputs.juuso.outputs.nixosModules.neovim
            ];
            extraConfigVim = ''
              let g:sqlite_clib_path = '${pkgs.sqlite.out}/lib/libsqlite3.so'

              let g:limelight_bop = '^'
              let g:limelight_eop = '$'

              let g:mkdp_browser = '${pkgs.kdePackages.falkon}/bin/falkon'
              let g:mkdp_echo_preview_url = 1

            '';
            extraConfigLua = ''
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

              require("papis").setup({
                db_path = "/run/media/juuso/papis/papis-nvim.sqlite3",
                papis_python = {
                  dir = "/run/media/juuso/papis",
                  info_name = "info.yaml",
                  notes_name = [[notes.org]],
                },
                enable_keymaps = true,
                yq_bin = "${pkgs.yq-go}/bin/yq",
                enable_modules = {
                  ["search"] = true,          -- Enables/disables the search module
                  ["completion"] = true,      -- Enables/disables the completion module
                  ["at-cursor"] = true,  -- Enables/disables the at-cursor module
                  ["formatter"] = true,       -- Enables/disables the formatter module
                  ["colors"] = true,          -- Enables/disables default highlight groups (you
                                              -- probably want this)
                  ["base"] = true,            -- Enables/disables the base module (you definitely
                                              -- want this)
                  ["debug"] = true,          -- Enables/disables the debug module (useful to
                                              -- troubleshoot and diagnose issues)
                },
              })
            '';
            extraPackages = with pkgs; [
              inputs.nixpkgs.legacyPackages.x86_64-linux.papis
              kdePackages.falkon
              ncurses # papis has dependency on ncurses, but it is broken on macOS -- install with brew instead. see: https://github.com/jhvst/nix-config/commit/360220836e1f03b5b0668f2f33af1ecc247d8d15
              nodePackages.js-beautify
              pandoc
              sqlite
              typst
              typstyle
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
              papis-nvim
            ] ++ [
              pkgs.vimExtraPlugins.sqlite-lua
            ];
            plugins = {
              lsp.servers = {
                html.enable = true;
                tinymist = {
                  enable = true;
                  settings.formatterMode = "typstyle";
                };
                ts_ls.enable = true;
              };
              treesitter.grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
                typst
              ];
              cmp.settings.sources = [
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
