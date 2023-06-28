{

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    blog.url = "github:jhvst/jhvst.github.io";
    barbell.url = "github:jhvst/barbell";
  };

  outputs = inputs@{ self, nixpkgs, ... }: {

    packages.aarch64-darwin.barbell = (
      let
        system = "aarch64-darwin";
        pkgs = nixpkgs.legacyPackages.${system};
        blog = inputs.blog.packages.${system};
      in
      pkgs.stdenv.mkDerivation {
        name = "barbell";
        src = ./.;
        buildInputs = with pkgs; [
          pandoc
          validator-nu
          nodePackages.js-beautify
          inputs.barbell.packages.${system}.barbell
          woff2
          vale
        ];
        phases = [ "unpackPhase" "buildPhase" "checkPhase" ];
        buildPhase = ''
          mkdir -p $out/css
          mkdir html
          cp -r ${blog.components}/html/* ./html
          cp ${pkgs.ibm-plex}/share/fonts/opentype/IBMPlexMono-Regular.otf .
          woff2_compress IBMPlexMono-Regular.otf
          cp IBMPlexMono-Regular.woff2 $out/
          pandoc main.md --katex -o main.html
          barbell main.html > article.bar
          barbell ./html/template_article.html > $out/barbell.html
        '';

        doCheck = false;
        checkPhase = ''
          vnu $out/barbell.html
          vale sync
          vale main.md
        '';
      }
    );

    packages.aarch64-darwin.default = self.packages.aarch64-darwin.barbell;

  };
}
