{ tree-sitter
, stdenv
, fetchurl
, ...
}:

stdenv.mkDerivation rec {
  inherit (tree-sitter) version;
  pname = "tree-sitter-lib-wasm";

  src = fetchurl {
    url = "https://github.com/tree-sitter/tree-sitter/releases/download/v${version}/tree-sitter.wasm";
    hash = "sha256-BpFDqlKyFBSf5uZli+BvNqZMt8mcvqIbTXsJ7okFoI4=";
  };

  phases = [ "unpackPhase" ];

  unpackPhase = ''
    cp $src $out
  '';

}
