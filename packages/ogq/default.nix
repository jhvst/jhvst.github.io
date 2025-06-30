{ writeShellApplication
, hq
, jq
, writeTextFile
,
}:
let
  opengraph = writeTextFile {
    name = "opengraph.scm";
    text = (builtins.readFile ./opengraph.scm);
  };
in
writeShellApplication {
  name = "ogq";
  runtimeInputs = [ hq jq ];
  text = ''
    hq ${opengraph} "$1" | jq '[.[] | select(.capture == "2 - value") | .text | trimstr("`") | fromjson ] | reduce while(. != []; .[2:]) as [$key, $val] ({}; .[$key] = $val)'
  '';
}