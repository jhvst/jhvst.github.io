{ stdenv
, version
, src
, tree-sitter
, pname
,
}: stdenv.mkDerivation {
  inherit version src pname;
  buildInputs = [ tree-sitter ];
  phases = [ "unpackPhase" "buildPhase" "installPhase" ];
  buildPhase = ''
    mkdir -p .emscriptencache
    export EM_CACHE=$(pwd)/.emscriptencache
    ${tree-sitter}/bin/tree-sitter build --wasm
  '';
  installPhase = ''
    mkdir -p $out/queries
    cp -r queries/* $out/queries

    mkdir -p $out/bin
    cp $(basename -s -wasm ${pname}).wasm $out/bin/
  '';
}