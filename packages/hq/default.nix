{ tree-sitter-cli, writeNuApplication }: writeNuApplication rec {
  name = "hq";
  runtimeInputs = [ tree-sitter-cli ];
  text = (builtins.readFile ./${name}.nu);
}
