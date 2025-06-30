{ stdenv
, jq
, lib
, callPackage
, ogq
, src
, fileset
, siteURL
}: stdenv.mkDerivation rec {
  inherit src;
  name = "mkOpengraph-all";
  buildInputs = [ jq ];
  graphset = lib.lists.forEach fileset (filepath: callPackage ./default.nix {
    inherit
      filepath
      jq
      ogq
      siteURL
      src
      ;
  });
  buildPhase = lib.strings.concatLines
    (lib.lists.forEach graphset (drv: ''
      cat ${drv}/graph.json >> combined.json
    '')) + ''
    jq -s '. | sort_by(."article:published_time") | reverse' combined.json > sorted.json
  '';
  installPhase = ''
    install -D sorted.json $out/graphs.json
  '';
}