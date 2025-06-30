{ stdenv
, ogq
, jq
, src
, filepath
, siteURL
}: stdenv.mkDerivation {
  inherit src;
  name = builtins.baseNameOf filepath;
  buildInputs = [ ogq jq ];
  buildPhase = ''
    ogq ${src}/${filepath} > graph.json
    date -u -d "$(jq '."article:published_time"' -r graph.json)" '+%d %b %Y %H:%M:%S GMT' > pubDate.txt
    jq --arg pubDate "$(cat pubDate.txt)" '. + { "og:url": "${siteURL}/${filepath}", pubDate: $pubDate}' graph.json > graphrss.json
  '';
  installPhase = ''
    install -D graphrss.json $out/graph.json
  '';
}