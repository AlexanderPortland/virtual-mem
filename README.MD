# [virtual-mem](https://github.com/AlexanderPortland/virtual-mem)

#### Authors: Alexander Portland and Rahel Selemon

#### Due: May 7, 2026

# Project Objective

Our project models virtual memory in Unix systems as taught in intermediate CS courses and operating systems courses (which we took and loved!). The core functionality is around mappings from virtual to physical addresses, and multi level page table representations. This includes addr translation, which requires traversing the page table data structure, and tracking how system state changes over time.

A key goal that emerged from this functionality is enforcing process isolation (between two procs) and kernel protection (preventing user level access to kernel memory). Permission bits are the primary mechanism used to prevent any of these violations.

## Stakeholders

This model is primarily useful for:

- **CS students** learning about virtual memory, address translation, and OS safety properties for the first time.
- **OS/systems teachers** who want a formal, explorable model of virtual memory concepts.
- **Researchers or engineers** interested in formal verification of memory safety properties.

# Model Design and Visualization

## Design Choices

_What tradeoffs did you make in choosing your representation? What else did you try that didn't work as well?_

An operating system has lots of different pieces and interacts with HW. We abstracted lots of these parts and stripped the model down to some basic Sigs: `Pages`, `Address`es, `Index`es, `Offset`s, `Process`es, `PageTable`s, and `PageTableEntry`s. We didn't model memory at the byte level or many other real OS components.

One key tradeoff we made was choosing not to use real addrs, which makes it so we don't have an accurate physical memory layout. But, by abstracting math and using `Page`s directly, we don't need any address arithmetic while still getting the essential mapping relationships. We also chose to limit our model to a 2 level page table design to minimize complexity.

We think this keeps the core structure needed to model and study the safety properties of an OS. In modeling these Sigs, we found that many correctness properties emerged naturally from simple constraints. This was neat!

_Did your goals change at all from your proposal? Did you realize anything you planned was unrealistic, or that anything you thought was unrealistic was doable?_

Our goals were pretty consistent with our original proposal. We had always meant to focus on the safety properties of process isolation and permission correctness. One thing we realized early on was that modeling shared memory or byte level addressing would have added a lot of complexity without raelly helping our core safety goals, so we got rid of those. But using Temporal Forge to show process switching and page mapping/unmapping over time turned out to be super doable and added a lot to our model/expressiveness.

## Visualization

_How should we understand an instance of your model and what your visualization shows?_

To run the model, run `main.frg` and step through traces. The model will show the root page table for each process at each time step.

We included two custom visualizations that have different views of the system. Both can be used by copying [`visualizations/translation_tree.js`](visualizations/translation_tree.js) into the script tab and selecting 'svg'. The two modes of functionality are as follows:

- **Structural view**: Shows the PT tree layout for each process, with permissions and mappings. This is useful for seeing how virtual addresses are translated and if permission bits are correctly set.
- **Physical memory view**: Shows the layout of physical memory over time, with different colors representing the validity of mappings (shared, free, or mapped). This helps spot isolation violations or improper freed pages at a glance.

*[`visualizations/physical_mem.js`](visualizations/physical_mem.js) is an early prototype we used to look into how memory was actually laid out in HW, but its functionality eventually got merged into the memory view for [`visualizations/translation_tree.js`](visualizations/translation_tree.js) in the end!*

# Testing

We wrote tests for the wellformedness predicates and safety properties of the model, like:

- Wellformedness of address structures (`addr_wellformed`, `pt_wellformed`)
- No orphan page tables or entries (`clean__no_orphan_pagetables`)
- No shared root page tables between procs (`wf__no_shared_root_pts`)
- Correct reachability of L1 page tables from L2 roots
- Valid traces (allocation, context switching, and do nothing)

We were able to confirm both that valid states are reachable and that violation states are correctly ruled out!

# Limitations

_What assumptions did you make about scope? What are the limits of your model?_

- We model a 2 level page table only, but real systems (e.g., x86-64) use 4 level page tables.
- We don't model TLBs, page faults, swapping, or demand paging.
- We don't model memory at the byte level (addrs are abstracted as `Page` entities).
- We don't use real physical addr arithmetic (abstracted guess).
- Our model is limited to 2 procs for showing isolation properties.
- We didn't model shared memory between procs, which is a real feature of Unix VM systems.

# Potential Further Steps

- Moving to a 4 level page table design to more closely model architectures like x86-64.
- Adding support for modeling shared memory regions between procs, and the needed safety checks.
- Modeling page faults to model more dynamic memory behavior.

# Documentation

We made sure to add lots of inline comments to our files to try to explain the logic behind our predicates. We hope that this makes it easy to understand our model. However, running the model with the visualizer is also a good way to understand what our project is trying to do.

# Collaborators

No other students. Thank you to our mentor TA, Joshua, for the guidance!

# AI Usage

We used Gemini for the visualizers, but not for the core model or testing.