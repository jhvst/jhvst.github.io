await (async (treesitter) => {
  const ctx = new treesitter().setLanguage(await treesitter.Language.load("tree-sitter-|language|.wasm"));
  const highlights = new Uint8Array(await (await fetch("data:application/octet-stream;base64,|highlights|")).arrayBuffer());
  const query = ctx.language.query(new TextDecoder().decode(highlights));
  document.querySelectorAll('.|language|').forEach((el) => {
    el.innerHTML = fmt(el.textContent, query.matches(ctx.parse(el.textContent).rootNode).flatMap(q => q.captures))
  });
})(window.TreeSitter);
