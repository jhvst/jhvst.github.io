{

  inputs = {
    devenv.url = "github:cachix/devenv";
    flake-parts.url = "github:hercules-ci/flake-parts";
    mk-shell-bin.url = "github:rrbutani/nix-mk-shell-bin";
    nix2container.inputs.nixpkgs.follows = "nixpkgs";
    nix2container.url = "github:nlewo/nix2container";
    nixpkgs.url = "github:nixos/nixpkgs";

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
    , nixpkgs
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

        devenv.shells.default = {

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
