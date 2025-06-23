{ stdenv
, name
, src
, pandoc
,
}: stdenv.mkDerivation {
  inherit name;
  inherit src;
  buildInputs = [ pandoc ];
  phases = [ "unpackPhase" "buildPhase" ];
  buildPhase = ''
    mkdir $out
    cp -r assets $out/assets
    pandoc main.tex -sC --toc --bibliography=main.bib > $out/${name}.html
  '';
}