def main [query, file] {
  tree-sitter-cli query -c $query $file | sed '1d' | lines | split column -r ',*\s*(pattern|capture|start|end|text):\s+' idx pattern capture start end text | reject idx | to json
}