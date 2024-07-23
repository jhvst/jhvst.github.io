//@ts-check
import { bqn } from "./libbqn.js";

document.addEventListener("DOMContentLoaded", async () => {

  const BQN = async (treesitter) => {
    const ctx = new treesitter().setLanguage(await treesitter.Language.load("tree-sitter-bqn.wasm"));
    document.getElementById("BQN").checked = true;
    const query = ctx.language.query(await (await fetch("highlights.scm")).text())
    document.getElementById("BQN-highlights").checked = true;
    document.querySelectorAll('.bqn').forEach((el) => {
      const reBQN = `${el.textContent}\n# Result: ${bqn(el.textContent)}`
      document.getElementById("BQN-eval").checked = true;
      el.innerHTML = fmt(reBQN, query.matches(ctx.parse(reBQN).rootNode).flatMap(m => m.captures))
    });
  }

  const Uiua = async (treesitter) => {
    const ctx = new treesitter().setLanguage(await treesitter.Language.load("tree-sitter-uiua.wasm"));
    document.getElementById("Uiua").checked = true;
    const query = ctx.language.query(await (await fetch("highlights-uiua.scm")).text())
    document.getElementById("Uiua-highlights").checked = true;
    document.querySelectorAll('.uiua').forEach((el) => {
      el.innerHTML = fmt(el.textContent, query.matches(ctx.parse(el.textContent).rootNode).flatMap(q => q.captures))
    });
  }

  const fmt = (code, block) => {
    return Object.values(Object.groupBy(block, capture => [capture.node.startIndex, capture.node.endIndex]))
      .reduce(([idx, acc], capture) => {
        const span = document.createElement("span")
        const tags = capture.flatMap(x => [x.name, x.node.type])
        span.classList.add(...tags)
        span.textContent = capture[0].node.text
        const whitespace = (capture[0].node.startIndex > idx ? code.substring(idx, capture[0].node.startIndex) : "").concat(span.outerHTML)
        return [capture[0].node.endIndex, acc.concat(whitespace)]
      }, [0, ""]).pop()
  }

  document.getElementById("font").checked = true;
  await window.TreeSitter.init()
  document.getElementById("Parser").checked = true;
  await BQN(window.TreeSitter);
  await Uiua(window.TreeSitter);

});
