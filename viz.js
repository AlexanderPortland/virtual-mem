// 1. Setup and Clear
d3.select(svg).selectAll("*").remove();

const roots = instance.signature("Root").atoms();
const l2Tables = instance.signature("L2PageTable").atoms();
const l1Tables = instance.signature("L1PageTable").atoms();
const pages = instance.signature("PhysicalPage").atoms();

// Store coordinates to draw lines later
const coords = new Map();

// 2. Enhanced Draw Function
function drawNode(atom, x, y, color, label) {
  coords.set(atom.id(), { x, y });
  const group = d3
    .select(svg)
    .append("g")
    .attr("transform", `translate(${x}, ${y})`);

  group
    .append("rect")
    .attr("width", 130)
    .attr("height", 30)
    .attr("x", -65)
    .attr("y", -15)
    .attr("rx", 5)
    .style("fill", color)
    .style("stroke", "#333");

  group
    .append("text")
    .attr("text-anchor", "middle")
    .attr("dy", ".35em")
    .style("fill", "black")
    .style("font-size", "10px")
    .text(label);
}

// 3. Helper for Drawing Arrows
function drawEdge(sourceAtom, targetAtom, label = "") {
  const s = coords.get(sourceAtom.id());
  const t = coords.get(targetAtom.id());
  if (!s || !t) return;

  const lineGroup = d3.select(svg).append("g");

  lineGroup
    .append("line")
    .attr("x1", s.x)
    .attr("y1", s.y + 15)
    .attr("x2", t.x)
    .attr("y2", t.y - 15)
    .style("stroke", "#666")
    .style("stroke-width", 1.5)
    .attr("marker-end", "url(#arrowhead)"); // Requires marker def (standard in Sterling)

  if (label) {
    lineGroup
      .append("text")
      .attr("x", (s.x + t.x) / 2 + 5)
      .attr("y", (s.y + t.y) / 2)
      .style("font-size", "9px")
      .style("fill", "#444")
      .text(label);
  }
}

// 4. Position Nodes
drawNode(roots[0], 400, 50, "#ff6b6b", "CPU ROOT");
drawNode(roots[0].pt, 400, 110, "#4dabf7", "L2 Table (Root)");

l1Tables.forEach((table, i) => {
  drawNode(table, 250 + i * 300, 220, "#51cf66", "L1 Table");
});

pages.forEach((page, i) => {
  drawNode(page, 150 + i * 150, 380, "#ff922b", "Phys Page " + i);
});

// 5. Draw Connections based on Model Relations
// Root -> L2
drawEdge(roots[0], roots[0].pt);

// L2 -> L1 (l2_entries pfunc)
l2Tables.forEach((l2) => {
  l2.l2_entries.tuples().forEach((tuple) => {
    // tuple is [L2Index, L1PageTable]
    drawEdge(l2, tuple.atoms()[1], "idx: " + tuple.atoms()[0].id());
  });
});

// L1 -> PhysPage (l1_entries -> L1PageTableEntry -> page)
l1Tables.forEach((l1) => {
  l1.l1_entries.tuples().forEach((tuple) => {
    // tuple is [L1Index, L1PageTableEntry]
    const entry = tuple.atoms()[1];
    const page = entry.page; // Follow the field to PhysicalPage
    drawEdge(l1, page, "idx: " + tuple.atoms()[0].id());
  });
});
