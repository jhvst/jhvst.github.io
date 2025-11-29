{ barbell
, callPackage
, description
, distInclude
, distInstall
, grammars
, ibm-plex
, js-beautify
, lib
, mesa
, name
, pageTemplate
, pandoc
, pubDate
, python-slugify
, servo
, src
, stdenv
, title
, tree-sitter
, validator-nu
, woff2
, writableTmpDirAsHomeHook
, writeTextFile
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
      <script type="module" src="tree-sitter.js"></script>
    '' else '''';
  wasmGrammars = lib.lists.forEach grammars (grammar:
    callPackage ../mkTreesitterWasm {
      inherit (grammar) version src;
      inherit barbell;
      pname = grammar.pname + "-wasm";
    }
  );
  mkImage = stdenv.mkDerivation {
    name = title + "-opengraph_image";
    src = ./.;
    buildInputs = [ barbell servo ];
    nativeBuildInputs = [ writableTmpDirAsHomeHook ];

    # see: https://discourse.nixos.org/t/test-packages-with-opengl-dependency/40099/8
    # fixes: `Failed to create WR surfman: ConnectionFailed (thread main, at ports/servoshell/desktop/headless_window.rs:42)`
    LIBGL_DRIVERS_PATH = "${mesa}/lib:${mesa}/lib/dri";
    __EGL_VENDOR_LIBRARY_FILENAMES = "${mesa}/share/glvnd/egl_vendor.d/50_mesa.json";

    buildPhase = ''
      echo "${title}" > title.bar
      echo "${description}" > description.bar
      barbell template_og_image.html > opengraph_image.html
      servo -zx opengraph_image.html --window-size 1200x630 -o opengraph_image.png
    '';
    installPhase = ''
      install -D opengraph_image.png $out/opengraph_image.png
    '';
  };
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
    echo "https://juuso.dev/blogPosts/${name}/opengraph_image.png" > image.bar
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

    cp ${mkImage}/opengraph_image.png $out
    ${treesitterInstall}
    ${distInstall}
  '';

  doCheck = true;
  checkPhase = ''
    vnu $out/$(slugify ${title}).html
  '';

}
