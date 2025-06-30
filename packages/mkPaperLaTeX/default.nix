{ stdenv
, name
, title
, src
, pandoc
,
}: stdenv.mkDerivation {
  inherit name src title;
  buildInputs = [ pandoc ];
  phases = [ "unpackPhase" "buildPhase" ];
  buildPhase = ''
    mkdir $out
    cp -r assets $out/assets
    pandoc main.tex \
      -sC --toc --bibliography=main.bib \
      -H meta.html \
      --metadata title="${title}" > $out/${name}.html
  '';
}