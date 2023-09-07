{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/23.05";
  };

  outputs = { self, nixpkgs, ... } @ inputs:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forEachSupportedSystem = f: nixpkgs.lib.genAttrs supportedSystems (system: f {
        inherit system;
        pkgs = import nixpkgs { inherit system; };
      });
    in
    {
      packages = forEachSupportedSystem ({ pkgs, system }: {

        default = pkgs.stdenv.mkDerivation {

          name = "components";
          src = ./../..;

          phases = [ "unpackPhase" "buildPhase" ];

          buildPhase = ''
            mkdir -p $out/css
            mkdir -p $out/html
            cp css/* $out/css
            cp html/* $out/html
          '';
        };
      });
    };
}
