{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    blog.url = "path:../../";
    barbell.url = "github:jhvst/barbell";
  };

  outputs = inputs@{ self, nixpkgs, ... }: {

    packages.aarch64-darwin.j1 = (
      let
        system = "aarch64-darwin";
        pkgs = nixpkgs.legacyPackages.${system};
        blog = inputs.blog.packages.${system};
      in
      pkgs.stdenv.mkDerivation {
        name = "j1";
        src = ./.;
        buildInputs = with pkgs; [
          pandoc
          cbqn
          validator-nu
          nodePackages.js-beautify
          inputs.barbell.packages.${system}.barbell
        ];
        phases = [ "unpackPhase" "buildPhase" "checkPhase" ];
        buildPhase = ''
          mkdir -p $out
          mkdir -p $out/css
          mkdir -p $out/img
          mkdir -p $out/attachments
          cp -r ${blog.components}/* .
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
      }
    );

    packages.aarch64-darwin.default = self.packages.aarch64-darwin.j1;

  };
}
