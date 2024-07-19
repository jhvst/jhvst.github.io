document.addEventListener("DOMContentLoaded", function() {

  const Parser = async () => {
    const ctx = window.TreeSitter;
    await ctx.init();
    document.getElementById("Parser").checked = true;
    return ctx;
  };

  const BQN = async (treesitter) => {
    const ctx = new treesitter();
    const language = await treesitter.Language.load("tree-sitter-bqn.wasm");
    ctx.setLanguage(language);
    document.getElementById("BQN").checked = true;
    return ctx;
  };

  const highlighter = async (ctx) => {
    let res = await fetch("highlights.scm")
    let highlights = await res.text();
    const query = ctx.language.query(highlights)
    document.getElementById("BQN-highlights").checked = true;
    return query
  };

  const fmt = (ctx, query) => {
    document.querySelectorAll('.bqn').forEach((el) => {
      const code = el.textContent;
      const tree = ctx.parse(code);

      const adjusted = query.matches(tree.rootNode).flatMap((match) => match.captures);
      const arr = adjusted.map((el) => {
        return {
          name: el.name,
          text: el.node.text,
          start: el.node.startIndex,
          end: el.node.endIndex
        }
      })
      const elems = Object.groupBy(arr, ({ start }) => {
        return start
      })

      const spans = Object.values(elems).map((el) => {
        const span = document.createElement("span")
        const tags = el.map((tag) => tag.name)
        span.classList.add(...tags)
        span.textContent = el[0].text
        span.setAttribute("data-start", el[0].start)
        span.setAttribute("data-end", el[0].end)
        return span
      })
      const fmt = spans.map((s, i) => {
        var sub = "";
        if (i > 0) {
          const start = s.getAttribute("data-start")
          const end = spans[i - 1].getAttribute("data-end")
          const diff = start - end
          if (diff > 0) {
            sub += code.substring(start, end)
          }
        }
        return `${sub}${s.outerHTML}`
      }).join("")
      el.innerHTML = fmt
    });
  }

  const main = async () => {
    const treesitter = await Parser();
    const treesitter_bqn = await BQN(treesitter);
    const highlights = await highlighter(treesitter_bqn)
    fmt(treesitter_bqn, highlights)

    document.querySelectorAll(".bqn").forEach((el) => {
      const code = el.textContent;
      const result = bqn(code)
      console.log(result)
      const output = document.createElement("output")
      output.value = `Result: ${result}`;
      el.append(output)
    })

  }

  main();

});
