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
    return Object.values(Object.groupBy(
      block.map(capture => {
        const offset = new Array(capture.node.endIndex - capture.node.startIndex).fill(1)
        return new Array(code.length).fill(0).toSpliced(capture.node.startIndex, offset.length, ...offset)
      }).reduce((acc, curr) => acc.map((x, y) => x + curr[y]), new Array(code.length).fill(0))
        .reduce((xs, x, idx) => x === 0 ? xs.concat(idx) : xs, new Array())
        .map(idx => {
          return {
            name: "whitespace",
            node: {
              text: code.at(idx),
              startIndex: idx,
              endIndex: idx,
              type: "whitespace"
            }
          }
        })
        .concat(...block)
        .sort((a, b) => a.node.startIndex - b.node.startIndex)
      , capture => [capture.node.startIndex, capture.node.endIndex]))
      .map(capture => {
        const span = document.createElement("span")
        const tags = capture.map(x => x.name)
        const grammarType = capture.map(x => x.node.type)
        span.classList.add(...tags)
        span.classList.add(...grammarType)
        span.textContent = capture[0].node.text
        return span.outerHTML
      }).join("");
  }

  document.getElementById("font").checked = true;
  await window.TreeSitter.init()
  document.getElementById("Parser").checked = true;
  await BQN(window.TreeSitter);
  await Uiua(window.TreeSitter);

});
