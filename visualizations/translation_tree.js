const d3 = require("d3");
const container = d3.select(svg);

// 1. PERSISTENT STATE
if (!container.attr("data-view-mode"))
  container.attr("data-view-mode", "structural");
let currentMode = container.attr("data-view-mode");

if (!container.attr("data-state-idx")) container.attr("data-state-idx", "0");
let current_state = parseInt(container.attr("data-state-idx"));

container.selectAll("*").remove();

// 2. LAYERING
const uiLayer = container
  .append("g")
  .attr("class", "ui-layer")
  .style("z-index", 10);
const contentLayer = container.append("g").attr("class", "content-layer");

const zoom = d3
  .zoom()
  .on("zoom", (e) => contentLayer.attr("transform", e.transform));
container.call(zoom);

// 3. UI CONTROLS (Static Overlay)
function drawUI() {
  uiLayer.selectAll("*").remove();

  const btn = uiLayer
    .append("g")
    .attr("cursor", "pointer")
    .on("click", (event) => {
      event.stopPropagation();
      currentMode = currentMode === "structural" ? "physical" : "structural";
      container.attr("data-view-mode", currentMode);
      drawUI();
      render();
    });

  btn
    .append("rect")
    .attr("x", 15)
    .attr("y", 15)
    .attr("width", 240)
    .attr("height", 35)
    .attr("rx", 8)
    .attr("fill", "#222")
    .attr("stroke", "#555");
  btn
    .append("text")
    .attr("x", 135)
    .attr("y", 37)
    .attr("text-anchor", "middle")
    .attr("fill", "#fff")
    .style("font-size", "12px")
    .style("font-family", "sans-serif")
    .style("font-weight", "bold")
    .text(
      currentMode === "structural"
        ? "PHYSICAL PAGE ARRANGEMENT"
        : "STRUCTURAL ARRANGEMENT"
    );

  const drawStateBtn = (x, label, delta) => {
    const sBtn = uiLayer
      .append("g")
      .attr("cursor", "pointer")
      .on("click", (event) => {
        event.stopPropagation();
        const next = current_state + delta;
        if (next >= 0 && next < instances.length) {
          current_state = next;
          container.attr("data-state-idx", current_state);
          drawUI();
          render();
        }
      });
    sBtn
      .append("rect")
      .attr("x", x)
      .attr("y", 15)
      .attr("width", 80)
      .attr("height", 35)
      .attr("rx", 8)
      .attr("fill", "#444");
    sBtn
      .append("text")
      .attr("x", x + 40)
      .attr("y", 37)
      .attr("text-anchor", "middle")
      .attr("fill", "#fff")
      .style("font-size", "10px")
      .style("font-family", "sans-serif")
      .text(label);
  };

  drawStateBtn(265, "PREV STATE", -1);
  drawStateBtn(355, "NEXT STATE", 1);

  uiLayer
    .append("text")
    .attr("x", 450)
    .attr("y", 37)
    .attr("fill", "#333")
    .style("font-family", "monospace")
    .style("font-weight", "bold")
    .text(`STATE: ${current_state} / ${instances.length - 1}`);
}

// 4. RENDER CORE
function render() {
  contentLayer.selectAll("*").remove();
  const viz = contentLayer.append("g");

  const inst = instances[current_state];

  // --- FIND ACTIVE PROCESS ---
  const osAtoms = inst.signature("OS").atoms();
  const currentProcField = inst.field("current_proc");
  let activeProcAtom = null;
  if (osAtoms.length > 0) {
    const activeTuples = osAtoms[0].join(currentProcField).tuples();
    if (activeTuples.length > 0) activeProcAtom = activeTuples[0].atoms()[0];
  }

  const processes = inst.signature("Process").atoms();
  const l2Field = inst.field("l2_entries").tuples();
  const l1Field = inst.field("l1_entries").tuples();
  const pageField = inst.field("page").tuples();
  const writeField = inst.field("write").tuples();
  const userField = inst.field("user").tuples();
  const rootField = inst.field("root");
  const physPages = inst.signature("PhysicalPage").atoms();

  const ramY = 550;
  const hardwareXMap = {};
  physPages.forEach((p, i) => (hardwareXMap[p.id()] = i * 220 + 150));

  if (currentMode === "physical") {
    const busG = viz.append("g");
    physPages.forEach((p) => {
      const x = hardwareXMap[p.id()];
      busG
        .append("rect")
        .attr("x", x - 70)
        .attr("y", ramY - 25)
        .attr("width", 140)
        .attr("height", 80)
        .attr("rx", 6)
        .attr("fill", "#f0f0f0")
        .attr("stroke", "#bbb")
        .attr("stroke-width", 2);
      busG
        .append("text")
        .attr("x", x)
        .attr("y", ramY + 80)
        .attr("text-anchor", "middle")
        .style("font-size", "12px")
        .style("font-family", "monospace")
        .text(p.id().split("$")[0]);
    });
  }

  processes.forEach((proc, pIdx) => {
    const isActive = activeProcAtom && proc.id() === activeProcAtom.id();

    const treeData = {
      name: proc.id().split("$")[0] + (isActive ? " (RUNNING)" : ""),
      type: "Process",
      active: isActive,
      children: [],
    };

    const l2TableRel = proc.join(rootField).tuples();
    if (l2TableRel.length > 0) {
      const l2Atom = l2TableRel[0].atoms()[0];
      const l2Node = { name: "L2", children: [] };
      l2Field
        .filter((t) => t.atoms()[0].id() === l2Atom.id())
        .forEach((t2) => {
          const l1Atom = t2.atoms()[2];
          const l1Node = { name: "L1", children: [] };
          l1Field
            .filter((t1) => t1.atoms()[0].id() === l1Atom.id())
            .forEach((t1) => {
              const entry = t1.atoms()[2];
              const pgT = pageField.find(
                (t) => t.atoms()[0].id() === entry.id()
              );
              const wrT = writeField.find(
                (t) => t.atoms()[0].id() === entry.id()
              );
              const usT = userField.find(
                (t) => t.atoms()[0].id() === entry.id()
              );
              if (pgT) {
                l1Node.children.push({
                  name: pgT.atoms()[1].id().split("$")[0],
                  type: "Page",
                  physId: pgT.atoms()[1].id(),
                  writable: wrT && wrT.atoms()[1].id().includes("True"),
                  user: usT && usT.atoms()[1].id().includes("True"),
                });
              }
            });
          if (l1Node.children.length > 0) l2Node.children.push(l1Node);
        });
      if (l2Node.children.length > 0) treeData.children.push(l2Node);
    }

    const treeLayout = d3.tree().nodeSize([140, 160]);
    const hierarchy = d3.hierarchy(treeData);
    treeLayout(hierarchy);

    const xOffset = pIdx * 600 + 250;
    const yOffset = 100;
    const g = viz
      .append("g")
      .attr("transform", `translate(${xOffset}, ${yOffset})`);

    if (currentMode === "physical") {
      hierarchy.descendants().forEach((d) => {
        if (d.data.type === "Page") {
          d.x = hardwareXMap[d.data.physId] - xOffset;
          d.y = ramY - yOffset;
        }
      });
    }

    // Edges
    g.selectAll(".link")
      .data(hierarchy.links())
      .enter()
      .append("path")
      .attr("fill", "none")
      .attr("stroke", (d) =>
        d.target.data.type === "Page"
          ? d.target.data.writable
            ? "#e15759"
            : "#4e79a7"
          : "#bbb"
      )
      .attr("stroke-width", (d) => (d.target.data.type === "Page" ? 4 : 2.5))
      .attr("stroke-dasharray", (d) =>
        d.target.data.type === "Page" && !d.target.data.user ? "2,4" : "0"
      )
      .attr(
        "d",
        d3
          .linkVertical()
          .x((d) => d.x)
          .y((d) => d.y)
      );

    // Permission Bubbles
    const bW = 52;
    const bH = 16;
    const labelGroups = g
      .selectAll(".edge-label-group")
      .data(hierarchy.links().filter((d) => d.target.data.type === "Page"))
      .enter()
      .append("g")
      .attr(
        "transform",
        (d) =>
          `translate(${(d.source.x + d.target.x) / 2 + 14}, ${
            (d.source.y + d.target.y) / 2
          })`
      );

    labelGroups
      .append("rect")
      .attr("x", -bW / 2)
      .attr("y", -bH / 2)
      .attr("width", bW)
      .attr("height", bH)
      .attr("rx", 4)
      .attr("fill", "#fff")
      .attr("opacity", 0.85)
      .attr("stroke", (d) => (d.target.data.writable ? "#e15759" : "#4e79a7"))
      .attr("stroke-width", 1);

    labelGroups
      .append("text")
      .attr("text-anchor", "middle")
      .attr("dominant-baseline", "central")
      .style("font-size", "9px")
      .style("font-weight", "bold")
      .style("font-family", "monospace")
      .style("fill", (d) => (d.target.data.writable ? "#c0392b" : "#2980b9"))
      .text(
        (d) =>
          `${d.target.data.writable ? "RW" : "RO"}|${
            d.target.data.user ? "USR" : "KRN"
          }`
      );

    // Nodes
    const nodes = g
      .selectAll(".node")
      .data(hierarchy.descendants())
      .enter()
      .append("g")
      .attr("transform", (d) => `translate(${d.x},${d.y})`);

    nodes
      .append("circle")
      .attr("r", 14)
      .attr("fill", (d) =>
        d.data.type === "Process"
          ? d.data.active
            ? "#f39c12"
            : "#4e79a7"
          : d.data.type === "Page"
          ? "#fff"
          : "#76b7b2"
      )
      .attr("stroke", (d) => (d.data.active ? "#e67e22" : "#333"))
      .attr("stroke-width", (d) => (d.data.active ? 5 : 2));

    nodes
      .append("text")
      .attr("dy", "-2.2em")
      .attr("text-anchor", "middle")
      .style("font-size", "12px")
      .style("font-family", "monospace")
      .style("font-weight", "bold")
      .attr("fill", (d) => (d.data.active ? "#d35400" : "#333"))
      .text((d) =>
        currentMode === "physical" && d.data.type === "Page" ? "" : d.data.name
      );
  });
}

drawUI();
render();
