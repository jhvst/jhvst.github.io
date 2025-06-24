document.addEventListener("DOMContentLoaded", async () => {

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

  await window.TreeSitter.init()

  |grammars|

});