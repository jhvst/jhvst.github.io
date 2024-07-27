{ tree-sitter
, stdenv
, fetchurl
, ...
}:

stdenv.mkDerivation rec {
  inherit (tree-sitter) version;
  pname = "tree-sitter-lib-js";

  src = fetchurl {
    url = "https://github.com/tree-sitter/tree-sitter/releases/download/v${version}/tree-sitter.js";
    hash = "sha256-3crLac0mwHMixRt5imOAX9mcJyF3yWM6l484hjWMoHA=";
  };

  phases = [ "unpackPhase" ];

  unpackPhase = ''
    cp $src $out
  '';

}
