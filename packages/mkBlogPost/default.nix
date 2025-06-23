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
, web-components
, ibm-plex
}: stdenv.mkDerivation rec {
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
    cp -r ${web-components.out}/html/* ./html
    cp ${ibm-plex}/share/fonts/opentype/IBMPlexMono-Regular.otf .
    woff2_compress IBMPlexMono-Regular.otf
    cp IBMPlexMono-Regular.woff2 $out/
    pandoc $src/main.md --no-highlight -o main.html

    echo "${distInclude}" > head.bar
    echo "${title}" > title.bar
    echo "${description}" > description.bar
    echo "${pubDate}" > pubDate.bar
    echo "${name}" > name.bar
    slugify ${title} > slug.bar
    date -d "${pubDate}" -Iminutes > datetime.bar
    cat $src/main.md | wc -w > wordCount.bar

    barbell main.html > article.bar
    barbell html/template_article.html > $out/$(slugify ${title}).html
    js-beautify -f $out/$(slugify ${title}).html -r
    rm $out/main.md

    ${distInstall}
  '';

  doCheck = true;
  checkPhase = ''
    vnu $out/$(slugify ${title}).html
  '';

}