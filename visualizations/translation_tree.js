const d3 = require("d3");
const container = d3.select(svg);

// 1. PERSISTENT STATE
if (!container.attr("data-view-mode"))
  container.attr("data-view-mode", "structural");
let currentMode = container.attr("data-view-mode");
container.selectAll("*").remove();

// 2. TOGGLE BUTTON
const btn = container
  .append("g")
  .attr("cursor", "pointer")
  .on("click", (event) => {
    event.stopPropagation();
    currentMode = currentMode === "structural" ? "physical" : "structural";
    container.attr("data-view-mode", currentMode);
    updateButtonText();
    render(currentMode);
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

const btnText = btn
  .append("text")
  .attr("x", 135)
  .attr("y", 37)
  .attr("text-anchor", "middle")
  .attr("fill", "#fff")
  .style("font-size", "12px")
  .style("font-family", "sans-serif")
  .style("font-weight", "bold")
  .style("pointer-events", "none");

function updateButtonText() {
  btnText.text(
    currentMode === "structural"
      ? "PHYSICAL PAGE ARRANGEMENT"
      : "STRUCTURAL ARRANGEMENT"
  );
}
updateButtonText();

// 3. RENDER CORE
function render(mode) {
  container.selectAll(".content").remove();
  const viz = container.append("g").attr("class", "content");

  container.call(
    d3.zoom().on("zoom", (e) => viz.attr("transform", e.transform))
  );

  const processes = instance.signature("Process").atoms();
  const l2Field = instance.field("l2_entries");
  const l1Field = instance.field("l1_entries");
  const pageField = instance.field("page");
  const writeField = instance.field("write");
  const userField = instance.field("user");
  const rootField = instance.field("root");
  const physPages = instance.signature("PhysicalPage").atoms();

  const ramY = 550;
  const hardwareXMap = {};
  physPages.forEach((p, i) => (hardwareXMap[p.id()] = i * 220 + 150));

  // Physical Memory Slots
  if (mode === "physical") {
    const busG = viz.append("g").attr("class", "bus-bg");
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
        .attr("fill", "#333")
        .text(p.id().split("$")[0]);
    });
  }

  processes.forEach((proc, pIdx) => {
    const treeData = {
      name: proc.id().split("$")[0],
      type: "Process",
      children: [],
    };
    const l2TableRel = proc.join(rootField);

    if (!l2TableRel.empty()) {
      const l2Atom = l2TableRel.tuples()[0].atoms()[0];
      const l2Node = { name: "L2", children: [] };

      l2Field
        .tuples()
        .filter((t) => t.atoms()[0].id() === l2Atom.id())
        .forEach((t2) => {
          const l1Atom = t2.atoms()[2];
          const l1Node = { name: "L1", children: [] };

          l1Field
            .tuples()
            .filter((t1) => t1.atoms()[0].id() === l1Atom.id())
            .forEach((t1) => {
              const entry = t1.atoms()[2];
              const pgT = pageField
                .tuples()
                .find((t) => t.atoms()[0].id() === entry.id());
              const wrT = writeField
                .tuples()
                .find((t) => t.atoms()[0].id() === entry.id());
              const usT = userField
                .tuples()
                .find((t) => t.atoms()[0].id() === entry.id());

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
      treeData.children.push(l2Node);
    }

    const treeLayout = d3.tree().nodeSize([140, 160]);
    const hierarchy = d3.hierarchy(treeData);
    treeLayout(hierarchy);

    const xOffset = pIdx * 600 + 250;
    const yOffset = 100;
    const g = viz
      .append("g")
      .attr("transform", `translate(${xOffset}, ${yOffset})`);

    if (mode === "physical") {
      hierarchy.descendants().forEach((d) => {
        if (d.data.type === "Page") {
          d.x = hardwareXMap[d.data.physId] - xOffset;
          d.y = ramY - yOffset;
        }
      });
    }

    // 4. EDGES
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

    // 5. CENTERED PERMISSION BUBBLES
    const bW = 52; // Bubble Width
    const bH = 16; // Bubble Height

    const labelGroups = g
      .selectAll(".edge-label-group")
      .data(hierarchy.links().filter((d) => d.target.data.type === "Page"))
      .enter()
      .append("g")
      .attr("transform", (d) => {
        const midX = (d.source.x + d.target.x) / 2 + 14;
        const midY = (d.source.y + d.target.y) / 2;
        return `translate(${midX}, ${midY})`;
      });

    // Bubble Background (Centered at 0,0 relative to group)
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

    // Bubble Text (Center-aligned)
    labelGroups
      .append("text")
      .attr("text-anchor", "middle")
      .attr("dominant-baseline", "central") // Perfectly vertical center
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

    // 6. NODES
    const nodes = g
      .selectAll(".node")
      .data(hierarchy.descendants())
      .enter()
      .append("g")
      .attr("transform", (d) => `translate(${d.x},${d.y})`);

    nodes
      .append("circle")
      .attr("r", 12)
      .attr("fill", (d) =>
        d.data.type === "Process"
          ? "#4e79a7"
          : d.data.type === "Page"
          ? "#fff"
          : "#76b7b2"
      )
      .attr("stroke", "#333")
      .attr("stroke-width", 2);

    nodes
      .append("text")
      .attr("dy", "-1.8em")
      .attr("text-anchor", "middle")
      .style("font-size", "12px")
      .style("font-family", "monospace")
      .style("font-weight", "bold")
      .text((d) =>
        mode === "physical" && d.data.type === "Page" ? "" : d.data.name
      );
  });
}

render(currentMode);
