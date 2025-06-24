await (async (treesitter) => {
  const ctx = new treesitter().setLanguage(await treesitter.Language.load("tree-sitter-uiua.wasm"));
  document.getElementById("Uiua").checked = true;
  const query = ctx.language.query(await (await fetch("highlights-uiua.scm")).text())
  document.getElementById("Uiua-highlights").checked = true;
  document.querySelectorAll('.uiua').forEach((el) => {
    el.innerHTML = fmt(el.textContent, query.matches(ctx.parse(el.textContent).rootNode).flatMap(q => q.captures))
  });
})(window.TreeSitter)
