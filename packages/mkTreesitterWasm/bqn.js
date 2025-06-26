await (async (treesitter) => {
  const ctx = new treesitter().setLanguage(await treesitter.Language.load("tree-sitter-bqn.wasm"));
  const highlights = new Uint8Array(await (await fetch("data:application/octet-stream;base64,|highlights|")).arrayBuffer());
  const query = ctx.language.query(new TextDecoder().decode(highlights));
  document.querySelectorAll('.bqn').forEach((el) => {
    var result = bqn(el.textContent);
    if (typeof result === "function") {
      result = `${result.m}-${result.name} function`;
    }
    const reBQN = `${el.textContent}\n# Result: ${result}`
    el.innerHTML = fmt(reBQN, query.matches(ctx.parse(reBQN).rootNode).flatMap(m => m.captures))
  });
})(window.TreeSitter);
