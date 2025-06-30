{ grammars
, lib
, stdenv
, tree-sitter
, writeShellApplication
, writeTextFile
}:
let
  # tree-sitter is a good parser.
  # but, the cli setup is a total garbage fire.
  # i fix this with Nix.
  #
  # Motivation:
  # https://discourse.nixos.org/t/how-can-i-use-standalone-tree-sitter-parse-with-existing-language-grammars/53996
  #
  # The structure of the installPhase recreates the following hard-coded paths:
  # https://github.com/tree-sitter/tree-sitter/blob/a6cd6abcfb4b9b79abea865c99bfd5c82ec5caf6/docs/src/cli/init-config.md
  # The parsers are symlinked for ease of use.
  # Technically one could just copy the tree-sitter.json
  tree-sitter-cli-env = with lib; stdenv.mkDerivation {
    name = "tree-sitter-cli-env";
    phases = [ "installPhase" ];
    installPhase = ''
      mkdir -p $out/parsers
      ${strings.concatLines (lists.forEach grammars (grammar: ''
        install -D ${grammar}/parser $out/tree-sitter/lib/${builtins.elemAt (splitString "-" grammar.pname) 2}.so
        ln -s ${grammar.src} $out/parsers/${grammar.name}
      ''))}
    '';
  };
  # To make your life more miserable, a "configuration" file is passed as a JSON file.
  # This file is a list of strings that hopefully resolves to directories on your filesystem.
  # It does not take the direct links to your parsers, but instead the parent folder which
  # it scans for directories starting with "tree-sitter".
  # We took care of this design decision with the symlink calls above.
  config = writeTextFile {
    name = "tree-sitter.json";
    text = builtins.toJSON { parser-directories = [ "${tree-sitter-cli-env}/parsers" ]; };
  };
in
writeShellApplication {
  name = "tree-sitter-cli";
  runtimeInputs = [ tree-sitter ];
  # The XDG_CACHE_HOME variable is a directory to which tree-sitter hides its binaries.
  # https://github.com/tree-sitter/tree-sitter/blob/a6cd6abcfb4b9b79abea865c99bfd5c82ec5caf6/docs/src/cli/generate.md?plain=1#L42-L47
  # When you build a tree-sitter grammar, it copies to resulting binary into this cache folder.
  # The cache folder then expects the filesystem structure laid out above.
  # We manage this insanity by pointing the cache into our environment derivation.
  text = ''XDG_CACHE_HOME=${tree-sitter-cli-env} tree-sitter "$@" --config-path ${config}'';
}
# Like, I am happy that I did not need any project patches to get this working, but should it really be this complicated?