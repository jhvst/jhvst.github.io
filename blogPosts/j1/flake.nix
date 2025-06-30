{

  inputs = {
    barbell.url = "github:jhvst/barbell?dir=packages/barbell";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:nixos/nixpkgs/24.05";
  };

  outputs = { ... }@inputs:

    inputs.flake-parts.lib.mkFlake { inherit inputs; } {

      systems = inputs.nixpkgs.lib.systems.flakeExposed;

      perSystem = { pkgs, inputs', ... }: rec {

        packages.j1 = pkgs.stdenv.mkDerivation {
          name = "j1";
          src = ./.;
          buildInputs = with pkgs; [
            pandoc
            validator-nu
            nodePackages.js-beautify
            inputs'.barbell.packages.barbell
          ];
          phases = [ "unpackPhase" "buildPhase" "checkPhase" ];
          buildPhase = ''
            mkdir -p $out
            mkdir -p $out/css
            mkdir -p $out/img
            mkdir -p $out/attachments
            pandoc j1.md -o article.bar
            barbell template.html > $out/j1.html
            js-beautify -f $out/j1.html -r
            cp css/* $out/css
            cp img/* $out/img
            cp attachments/* $out/attachments
          '';

          doCheck = true;
          checkPhase = ''
            vnu $out/j1.html
          '';
        };

        packages.default = packages.j1;

      };
    };
}
