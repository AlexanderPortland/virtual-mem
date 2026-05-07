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

const btnRect = btn
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
  const rootField = instance.field("root");
  const physPages = instance.signature("PhysicalPage").atoms();

  // Map each PhysicalPage (Mapped or Unmapped) to a fixed X coordinate
  const hardwareXMap = {};
  const ramY = 450;
  physPages.forEach((p, i) => {
    hardwareXMap[p.id()] = i * 180 + 100;
  });

  // Draw the "Physical Memory Bus" background (only in Physical Mode)
  if (mode === "physical") {
    const busG = viz.append("g").attr("class", "bus-bg");
    physPages.forEach((p) => {
      const x = hardwareXMap[p.id()];
      // Draw a "slot" for every physical page
      busG
        .append("rect")
        .attr("x", x - 50)
        .attr("y", ramY - 10)
        .attr("width", 100)
        .attr("height", 60)
        .attr("rx", 4)
        .attr("fill", "#f0f0f0")
        .attr("stroke", "#ddd");

      busG
        .append("text")
        .attr("x", x)
        .attr("y", ramY + 65)
        .attr("text-anchor", "middle")
        .attr("fill", "#999")
        .style("font-size", "10px")
        .style("font-family", "monospace")
        .text(p.id().split("$")[0]);
    });
  }

  processes.forEach((proc, pIdx) => {
    const treeData = {
      name: proc.id().split("$")[0],
      type: "Process",
      children: [],
    };
    const l2Rel = proc.join(rootField);

    if (!l2Rel.empty()) {
      const l2Atom = l2Rel.tuples()[0].atoms()[0];
      const l2Node = { name: "L2 Table", children: [] };

      l2Field
        .tuples()
        .filter((t) => t.atoms()[0].id() === l2Atom.id())
        .forEach((t2) => {
          const l1Atom = t2.atoms()[2];
          const l1Node = { name: "L1 Table", children: [] };

          l1Field
            .tuples()
            .filter((t1) => t1.atoms()[0].id() === l1Atom.id())
            .forEach((t1) => {
              const entry = t1.atoms()[2];
              const pgRel = entry.join(pageField);
              if (!pgRel.empty()) {
                const pId = pgRel.tuples()[0].atoms()[0].id();
                l1Node.children.push({
                  name: pId.split("$")[0],
                  type: "Page",
                  physId: pId,
                });
              }
            });
          if (l1Node.children.length > 0) l2Node.children.push(l1Node);
        });
      treeData.children.push(l2Node);
    }

    const treeLayout = d3.tree().nodeSize([100, 120]);
    const hierarchy = d3.hierarchy(treeData);
    treeLayout(hierarchy);

    const xOffset = pIdx * 450 + 150;
    const yOffset = 100;
    const g = viz
      .append("g")
      .attr("transform", `translate(${xOffset}, ${yOffset})`);

    if (mode === "physical") {
      hierarchy.descendants().forEach((d) => {
        if (d.data.type === "Page") {
          d.x = hardwareXMap[d.data.physId] - xOffset;
          d.y = ramY - yOffset; // Align exactly with the bus slots
        }
      });
    }

    g.selectAll(".link")
      .data(hierarchy.links())
      .enter()
      .append("path")
      .attr("fill", "none")
      .attr("stroke", mode === "physical" ? "#ff6b6b" : "#bbb")
      .attr("stroke-width", 1.5)
      .attr("stroke-dasharray", mode === "physical" ? "4,2" : "0")
      .attr(
        "d",
        d3
          .linkVertical()
          .x((d) => d.x)
          .y((d) => d.y)
      );

    const nodes = g
      .selectAll(".node")
      .data(hierarchy.descendants())
      .enter()
      .append("g")
      .attr("transform", (d) => `translate(${d.x},${d.y})`);

    nodes
      .append("circle")
      .attr("r", 6)
      .attr("fill", (d) =>
        d.data.type === "Process"
          ? "#4e79a7"
          : d.data.type === "Page"
          ? "#e15759"
          : "#76b7b2"
      )
      .attr("stroke", "#333");

    nodes
      .append("text")
      .attr("dy", "1.6em")
      .attr("text-anchor", "middle")
      .style("font-size", "11px")
      .style("font-family", "monospace")
      .text((d) => d.data.name);
  });

  if (mode === "physical") {
    viz
      .append("text")
      .attr("x", 20)
      .attr("y", ramY + 100)
      .text("PHYSICAL ADDRESS SPACE (INCLUDING UNMAPPED SLOTS)")
      .style("font-weight", "bold")
      .style("font-family", "sans-serif")
      .style("fill", "#555");
  }
}

render(currentMode);
