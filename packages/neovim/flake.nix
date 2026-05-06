{

  nixConfig = {
    extra-substituters = [
      "https://pandoc-crossref.cachix.org"
    ];
    extra-trusted-public-keys = [
      "pandoc-crossref.cachix.org-1:LI9ABFTkGpPCTkUTzoopVSSpb1a26RSTJNMsqVbDtPM="
    ];
  };

  inputs = {
    juuso.url = "github:jhvst/nix-config";
    nixneovimplugins.url = "github:NixNeovim/NixNeovimPlugins";
    pandoc-crossref.url = "github:lierdakil/pandoc-crossref/v0.3.23a";
  };

  outputs = inputs@{ ... }:

    inputs.juuso.inputs.flake-parts.lib.mkFlake { inherit inputs; } {

      systems = inputs.juuso.inputs.nixpkgs.lib.systems.flakeExposed;

      perSystem = { pkgs, config, system, ... }: {

        _module.args.pkgs = import inputs.juuso.inputs.nixpkgs {
          inherit system;
          overlays = [
            inputs.juuso.overlays.default
            inputs.nixneovimplugins.overlays.default
          ];
          config = { };
        };

        packages.neovim = inputs.juuso.inputs.nixvim.legacyPackages.${system}.makeNixvimWithModule {
          inherit pkgs;
          module = {
            imports = [
              inputs.juuso.outputs.nixosModules.neovim
            ];
            extraConfigVim = ''
              let g:sqlite_clib_path = '${pkgs.sqlite.out}/lib/libsqlite3.so'

              let g:limelight_bop = '^'
              let g:limelight_eop = '$'
            '';
            extraConfigLua = ''
              local gknapsettings = {
                delay = 420,
                mdoutputext = "pdf",
                mdtopdf = table.concat({
                  "pandoc",
                  "--filter pandoc-include",
                  "--filter pandoc-crossref",
                  "--citeproc",
                  "--bibliography=/var/lib/papis/lib.bib",
                  "--pdf-engine=xelatex",
                  "-M link-citations=true",
                  "-M link-bibliography=true",
                  "-V colorlinks=true",
                  "-V citecolor=red",
                  "-V linkcolor=red",
                  "-V urlcolor=blue",
                  "--number-sections",
                  "--toc",
                  "%docroot%",
                  "-o %outputfile%",
                }, " "),
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

              vim.api.nvim_create_autocmd("BufWritePost", {
                pattern = { "*.md", "*.markdown", "*.tex" },
                callback = function()
                  if vim.b.knap_viewerpid then
                    require("knap").process_once()
                  end
                end,
              })
            '';
            extraPackages = with pkgs; [
              js-beautify
              ncurses # papis has dependency on ncurses, but it is broken on macOS -- install with brew instead. see: https://github.com/jhvst/nix-config/commit/360220836e1f03b5b0668f2f33af1ecc247d8d15
              inputs.pandoc-crossref.packages.${system}.pandoc-with-crossref
              pandoc-include
              papis
              sqlite
              texliveSmall
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
              papis = {
                enable = true;
                settings = rec {
                  search.enable = true;
                  completion.enable = true;
                  at-cursor.enable = true;
                  formatter.enable = true;
                  colors.enable = true;
                  base.enable = true;
                  db_path = "${papis_python.dir}/papis-nvim.sqlite3";
                  debug.enable = true;
                  enable_keymaps = true;
                  yq_bin = "${pkgs.yq-go}/bin/yq";
                  papis_python = {
                    dir = "/run/media/juuso/papis";
                    info_name = "info.yaml";
                    notes_name = {
                      __raw = "[[notes.org]]";
                    };
                  };
                };
              };
            };
          };
        };

        packages.default = config.packages.neovim;

      };

    };
}
