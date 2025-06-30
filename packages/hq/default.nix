{ writeShellApplication
, tree-sitter-cli
,
}: writeShellApplication rec {
  name = "hq";
  runtimeInputs = [ tree-sitter-cli ];
  text = (builtins.readFile ./${name}.nu);
}