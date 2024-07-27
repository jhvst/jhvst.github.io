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

  iframe.addEventListener("load", async () => {
    const iframeDocument = iframe.contentDocument;
    if (!iframeDocument) throw new Error("Could not get iframe document");
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

  document.body.append(iframe);
}


export const initialNodes: Node[] = [
  {
    id: 'F',
    type: 'input',
    position: { x: 25, y: 0 },
    data: { label: 'F' },
    style: {
      width: "fit-content",
    },
  },
  {
    id: 'G',
    position: { x: 75, y: 75 },
    data: { label: 'G' },
    style: {
      width: "fit-content",
    },
  },
  {
    id: 'a',
    type: 'output',
    position: { x: 25, y: 150 },
    data: { label: 'a' },
    style: {
      width: "fit-content",
      height: "fit-content",
    },
  },
];

export const initialEdges: Edge[] = [
  {
    id: 'F->G',
    source: 'F',
    target: 'G',
    style: {
      strokeWidth: 2,
    },
  },
  {
    id: 'G->a',
    source: 'G',
    target: 'a',
    style: {
      strokeWidth: 2,
    },
  },
  {
    id: 'F->a',
    source: 'F',
    target: 'a',
    style: {
      strokeWidth: 2,
    },
  },
];

export default function App() {
  const [nodes] = useNodesState(initialNodes);
  const [edges] = useEdgesState(initialEdges);
  const [pane, setPane] = useState();

  const panelWait = (instance: any) => {
    const nodes = instance.getNodes();
    const viewport = instance.getViewport()
    const bounds = getNodesBounds(nodes)
    const transform = getViewportForBounds(bounds, bounds.width, bounds.height, viewport.zoom, viewport.zoom, 0);
    const CONTAINER_QUERY = ".react-flow__viewport";
    const container = document.querySelector(CONTAINER_QUERY);
    exportSVG(container, bounds.width, bounds.height, transform, setPane)
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
