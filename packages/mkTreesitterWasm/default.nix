{ stdenv
, version
, src
, tree-sitter
, pname
, lib
, barbell
, writeTextFile
,
}:
let
  language = builtins.elemAt (lib.splitString "-" pname) 2;
  jsFile =
    if builtins.pathExists ./${language}.js
    then builtins.readFile ./${language}.js
    else builtins.readFile ./default.js;
  jsTemplate = writeTextFile {
    name = language;
    text = jsFile;
  };
in
stdenv.mkDerivation {
  inherit version src pname;
  buildInputs = [ tree-sitter barbell ];
  phases = [ "unpackPhase" "buildPhase" "installPhase" ];
  buildPhase = ''
    mkdir -p .emscriptencache
    export EM_CACHE=$(pwd)/.emscriptencache
    ${tree-sitter}/bin/tree-sitter build --wasm

    cp ${jsTemplate} template.js
    echo $(cat queries/highlights.scm | base64 -w0) > highlights.bar
    echo "${language}" > language.bar
    barbell template.js > language.js
  '';
  installPhase = ''
    mkdir -p $out/bin
    cp tree-sitter-${language}.wasm $out/bin/
    cp language.js $out/
  '';
}