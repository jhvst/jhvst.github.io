import { useState } from 'react';
import {
  ReactFlow,
  useNodesState,
  useEdgesState,
  getNodesBounds,
  getViewportForBounds,
  Panel,
  MarkerType,
} from '@xyflow/react';
import '@xyflow/react/dist/style.css';
import reactFlowStyle from '@xyflow/react/dist/style.css?inline';
import mainStyle from "./index.css?inline";

import { elementToSVG } from 'dom-to-svg';
import type { Edge, Node } from '@xyflow/react';

export const downloadSVG = async (svgString: string, filename: string) => {
  const svgBlob = new Blob([svgString], { type: "image/svg+xml" });
  const svgUrl = URL.createObjectURL(svgBlob);

  const a = document.createElement("a");
  a.href = svgUrl;
  a.download = filename;
  a.click();
};

const exportSVG = (container: any, width: any, height: any, transform: any, setPane: any) => {
  const iframe = document.createElement("iframe");
  iframe.style.width = `1000px`;
  iframe.style.height = `1000px`;
  iframe.style.position = "absolute";
  iframe.style.top = "0";
  iframe.style.left = "50px";

  iframe.addEventListener("load", (e) => {
    const iframeDocument = e.target.contentDocument;
    const iframeStyle = iframeDocument.createElement("style");
    iframeStyle.innerHTML = `
        ${mainStyle}
        ${reactFlowStyle}
    `;
    iframeDocument.body.append(iframeStyle);
    const clone = container.cloneNode(true) as HTMLElement;
    Object.assign(clone.style, {
      transform,
      width: `${width}px`,
      height: `${height}px`,
    });
    iframeDocument.body.append(clone);
    iframeDocument.body.classList.add("react-flow", "light")
    const svgDocument = elementToSVG(iframeDocument.documentElement);
    const result = new XMLSerializer().serializeToString(svgDocument);
    const svgBlob = new Blob([result], { type: "image/svg+xml" });
    const svgUrl = URL.createObjectURL(svgBlob);
    const link = <a href={svgUrl} download={"diagram.svg"}>Download</a>
    setPane(link)
    iframe.remove()
  });

  return iframe
}

export const initialNodes: Node[] = [
  {
    id: 'G',
    type: 'input',
    position: { x: 11, y: 0 },
    data: { label: '/' },
  },
  {
    id: 'F',
    position: { x: 10, y: 3 },
    data: { label: '>' },
  },
  {
    id: 'F2',
    position: { x: 10, y: 9 },
    data: { label: '2' },
    type: "output",
  },
  {
    id: 'G2',
    position: { x: 11, y: 6 },
    data: { label: 'x' },
  },
].map((node) => {
  const x = (x) => x * 25;
  return Object.assign(node, {
    position: {
      x: x(node.position.x),
      y: x(node.position.y),
    },
    style: {
      width: "fit-content",
      height: "fit-content",
    },
  });
});

export const initialEdges: Edge[] = [
  ['G', 'F'],
  ['G', 'G2'],
  ['F', 'G2'],
  ['F', 'F2'],
  ["G2", "F2"],
].map(([source, target]) => {
  return {
    id: `${source}->${target}`,
    source,
    target,
    style: {
      strokeWidth: 2,
    },
  }
});

export default function App() {
  const [nodes] = useNodesState(initialNodes);
  const [edges] = useEdgesState(initialEdges);
  const [pane, setPane] = useState();

  const panelWait = (instance: any) => {
    const viewport = instance.getViewport()
    const bounds = getNodesBounds(instance.getNodes())
    const transform = getViewportForBounds(bounds, bounds.width, bounds.height, viewport.zoom, viewport.zoom, 0);
    const container = document.querySelector(".react-flow__viewport");
    const iframe = exportSVG(container, bounds.width, bounds.height, transform, setPane)
    document.body.append(iframe);
  }

  return (
    <ReactFlow
      nodes={nodes}
      edges={edges}
      draggable={false}
      zoomOnScroll={false}
      onInit={(instance: any) => panelWait(instance)}
    >
      <Panel position="top-right">
        {pane}
      </Panel>
    </ReactFlow>
  );
}
