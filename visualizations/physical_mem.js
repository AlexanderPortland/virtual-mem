const d3 = require("d3");
const container = d3.select(svg);
container.selectAll("*").remove();

// 1. Setup Canvas
d3.select(svg).attr("width", width).attr("height", height);

// 2. Access atoms and current state fields
const processes = instance.signature("Process").atoms();
const physicalPages = instance.signature("PhysicalPage").atoms();

// In Temporal Forge, fields return the value for the CURRENTLY SELECTED state
const nextField = instance.field("next");
const rootField = instance.field("root");
const l2Field = instance.field("l2_entries");
const l1Field = instance.field("l1_entries");
const pageField = instance.field("page");

// 3. Hardware Sequencing (Order pages)
const ramOrder = [];
const visited = new Set();
let current = physicalPages.find(
  (p) => !nextField.tuples().some((t) => t.atoms()[1].id() === p.id())
);

if (!current && physicalPages.length > 0) current = physicalPages[0];

while (
  current &&
  !visited.has(current.id()) &&
  ramOrder.length < physicalPages.length
) {
  ramOrder.push(current);
  visited.add(current.id());
  const nextTuple = nextField
    .tuples()
    .find((t) => t.atoms()[0].id() === current.id());
  current = nextTuple ? nextTuple.atoms()[1] : null;
}
physicalPages.forEach((p) => {
  if (!visited.has(p.id())) ramOrder.push(p);
});

// 4. Temporal Mapping Logic
const pageToProcess = {};
physicalPages.forEach((p) => (pageToProcess[p.id()] = []));

processes.forEach((proc) => {
  const rootRel = proc.join(rootField);
  if (rootRel.tuples().length === 0) return;
  const rootAtom = rootRel.tuples()[0].atoms()[0];

  // Traverse the page table for the current state
  l2Field
    .tuples()
    .filter((t) => t.atoms()[0].id() === rootAtom.id())
    .forEach((t2) => {
      const l1Table = t2.atoms()[2];
      l1Field
        .tuples()
        .filter((t1) => t1.atoms()[0].id() === l1Table.id())
        .forEach((t1) => {
          const l1Entry = t1.atoms()[2];
          const pageRel = l1Entry.join(pageField);
          if (pageRel.tuples().length > 0) {
            const pId = pageRel.tuples()[0].atoms()[0].id();
            if (pageToProcess[pId] && !pageToProcess[pId].includes(proc.id())) {
              pageToProcess[pId].push(proc.id());
            }
          }
        });
    });
});

// 5. Render Hardware Strip
const boxSize = 100;
const margin = 20;
const ramGroup = container.append("g").attr("transform", "translate(50, 180)");

ramOrder.forEach((page, i) => {
  const owners = pageToProcess[page.id()] || [];
  const x = i * (boxSize + margin);

  let color = "#ffffff";
  let statusText = "FREE";
  if (owners.length === 1) {
    color = "#4ecdc4";
    statusText = "MAPPED";
  }
  if (owners.length > 1) {
    color = "#ff6b6b";
    statusText = "BREACH";
  }

  // Physical Page Rect
  ramGroup
    .append("rect")
    .attr("x", x)
    .attr("y", 0)
    .attr("width", boxSize)
    .attr("height", boxSize)
    .attr("fill", color)
    .attr("stroke", "#333")
    .attr("stroke-width", 3)
    .attr("rx", 8);

  // Page Name
  ramGroup
    .append("text")
    .attr("x", x + boxSize / 2)
    .attr("y", -15)
    .attr("text-anchor", "middle")
    .style("font-weight", "bold")
    .text(page.id().split("$")[0]);

  // Status Label
  ramGroup
    .append("text")
    .attr("x", x + boxSize / 2)
    .attr("y", boxSize + 20)
    .attr("text-anchor", "middle")
    .style("font-size", "10px")
    .style("fill", "#666")
    .text(statusText);

  // List owning processes
  owners.forEach((owner, j) => {
    ramGroup
      .append("text")
      .attr("x", x + 10)
      .attr("y", 30 + j * 20)
      .style("font-size", "12px")
      .style("font-family", "monospace")
      .text(owner.split("$")[0]);
  });
});

// 6. State Indicator
container
  .append("text")
  .attr("x", 50)
  .attr("y", 50)
  .text("Temporal Hardware Trace")
  .style("font-size", "24px")
  .style("font-weight", "bold");

container
  .append("text")
  .attr("x", 50)
  .attr("y", 80)
  .text("Use the Time drawer arrows to advance through the allocation trace")
  .style("fill", "#666");
