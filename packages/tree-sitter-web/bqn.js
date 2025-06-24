await (async (treesitter) => {
  const ctx = new treesitter().setLanguage(await treesitter.Language.load("tree-sitter-bqn.wasm"));
  const query = ctx.language.query(await (await fetch("highlights.scm")).text())
  document.querySelectorAll('.bqn').forEach((el) => {
    var result = bqn(el.textContent);
    if (typeof result === "function") {
      result = `${result.m}-${result.name} function`;
    }
    const reBQN = `${el.textContent}\n# Result: ${result}`
    el.innerHTML = fmt(reBQN, query.matches(ctx.parse(reBQN).rootNode).flatMap(m => m.captures))
  });
})(window.TreeSitter)
