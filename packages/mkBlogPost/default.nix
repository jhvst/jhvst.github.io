{ stdenv
, name
, description
, pubDate
, src
, distInstall
, distInclude
, barbell
, js-beautify
, pandoc
, python-slugify
, validator-nu
, woff2
, title
, pageTemplate
, ibm-plex
, writeTextFile
, tree-sitter
, grammars
, lib
, callPackage
}:
let
  template = writeTextFile {
    name = "template_article.html";
    text = (builtins.readFile pageTemplate);
  };
  treesitterInstall =
    if builtins.length grammars > 0 then ''
      cp ${tree-sitter}/lib/tree-sitter.js $out/tree-sitter.js
      cp ${tree-sitter}/lib/tree-sitter.wasm $out/tree-sitter.wasm
    '' else '''';
  treesitterInclude =
    if builtins.length grammars > 0 then ''
      <script src="tree-sitter.js"></script>
    '' else '''';
  wasmGrammars = lib.lists.forEach grammars (grammar:
    callPackage ../mkTreesitterWasm {
      inherit (grammar) version src;
      inherit barbell;
      pname = grammar.pname + "-wasm";
    }
  );
in
stdenv.mkDerivation rec {
  inherit name description pubDate src distInstall distInclude;
  buildInputs = [
    barbell
    js-beautify
    pandoc
    python-slugify
    validator-nu
    woff2
  ];
  phases = [
    "unpackPhase"
    "buildPhase"
    "checkPhase"
  ];
  buildPhase = ''
    mkdir $out
    mkdir html
    cp -r $src/* $out/
    cp ${ibm-plex}/share/fonts/opentype/IBMPlexMono-Regular.otf .
    woff2_compress IBMPlexMono-Regular.otf
    cp IBMPlexMono-Regular.woff2 $out/
    pandoc $src/main.md --no-highlight --katex -o main.html

    echo "${distInclude + treesitterInclude}" > head.bar
    echo "${title}" > title.bar
    echo "${description}" > description.bar
    echo "${pubDate}" > pubDate.bar
    echo "${name}" > name.bar
    slugify ${title} > slug.bar
    date -d "${pubDate}" -Iminutes > datetime.bar
    cat $src/main.md | wc -w > wordCount.bar

    ${lib.strings.concatLines (lib.lists.forEach wasmGrammars
        (grammar: ''
          cp -r ${grammar}/bin/* $out/
          cat ${grammar}/language.js >> grammars.bar
        '')
    )}

    cp ${template} template_article.html
    barbell main.html > article.bar
    barbell template_article.html > $out/$(slugify ${title}).html
    js-beautify -f $out/$(slugify ${title}).html -r
    rm $out/main.md

    ${treesitterInstall}
    ${distInstall}
  '';

  doCheck = true;
  checkPhase = ''
    vnu $out/$(slugify ${title}).html
  '';

}