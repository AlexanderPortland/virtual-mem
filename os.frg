#lang forge/temporal

open "addr.frg"
open "pt.frg"
open "utils.frg"

sig Process {
    root: one L2PageTable
}

one sig OS {
    var current_proc: one Process
}

// Ensure that all physical addresses have a virtual address that maps to them 
pred all_pages_mapped {
    all pa: PhysicalPage | {
        some va: VirtualAddress, proc: Process | {
            walk[va, proc.root] = pa
        }
    }
}

pred clean__no_orphan_pagetables {
    // Every l1 pagetable can be accessed from the root pagetable
    all l1_pt: L1PageTable {
        some l2_index: L2Index, l2_pt: L2PageTable | {
            l2_pt.l2_entries[l2_index] = l1_pt
        }
    }

    // No orphan pagetable entries either
    all pt_entry: L1PageTableEntry | {
        some pt: L1PageTable, index: L1Index | {
            pt.l1_entries[index] = pt_entry
        }
    }

    // Each l2 page table must be the root for some process
    all l2: L2PageTable | some proc: Process | l2 = proc.root
}

pred wf__no_shared_root_pts {
    all disj proc1, proc2: Process {
        proc1.root != proc2.root
    }
}

// Each physical page should only be reachable once per process.
// I don't think this is a hard rule for VM systems, but it rules out some funky edge cases that wouldn't
// show up in practice.
// TODO: this is actually kinda hard, so fix if we have time...
// pred wf__only_reachable_once_per_proc {
//     all pa: PhysicalPage, proc: Process | {
//         all disj va1: VirtualAddress, va2: VirtualAddress | {
//             {not {
//                 va1.vpn1 = va2.vpn1
//                 va1.vpn0 = va2.vpn0
//             }} implies {
//                 {walk[va1, proc.root] = pa} implies {not { walk[va2, proc.root] = pa}}
//                 {walk[va2, proc.root] = pa} implies {not { walk[va1, proc.root] = pa}}
//             }
//         }
//     }
// }

pred cpu_wellformed {
    wf__no_shared_root_pts
    traces
}

pred do_nothing {
    -- All var fields remain unchanged
    L1PageTable.l1_entries' = L1PageTable.l1_entries
    L1PageTableEntry.page' = L1PageTableEntry.page
    L1PageTableEntry.write' = L1PageTableEntry.write
    L1PageTableEntry.user' = L1PageTableEntry.user
    OS.current_proc' = OS.current_proc
}

pred context_switch[new_proc: Process] {
    OS.current_proc' = new_proc
    l1_entries' = l1_entries
    page' = page
    write' = write
    user' = user
}

// Kernel allocate
pred allocate[l1: L1Index, l2: L2Index] {
    no walk_inner[l2, l1, OS.current_proc.root]

    some free_page: PhysicalPage, free_entry: L1PageTableEntry | {
        all proc: Process, other_l1: L1Index, other_l2: L2Index | {
            some walk_inner[other_l2, other_l1, proc.root] implies walk_inner[other_l2, other_l1, proc.root] != free_page
        }

        // not {
            all l1_fuck: L1Index, l2_fuck: L2Index, proc_fuck: Process | {
                proc_fuck.root.l2_entries[l2_fuck].l1_entries[l1_fuck] != free_entry
            }
        // }

        l1_entries' = l1_entries + (OS.current_proc.root.l2_entries[l2] -> l1 -> free_entry)
        page' = page + (free_entry -> free_page)
        // l2_entries' = l2_entries
        
        OS.current_proc' = OS.current_proc
    }
}

pred traces {
    -- Initial State: Everything is empty
    no l1_entries
    // no l2_entries
    no page
    
    some l1: L1Index, l2: L2Index | allocate[l1, l2]
    next_state { some l1: L1Index, l2: L2Index | allocate[l1, l2] }
    next_state { next_state { some new_proc: Process | new_proc != OS.current_proc and context_switch[new_proc] } }
    next_state { next_state { next_state { some l1: L1Index, l2: L2Index | allocate[l1, l2] } } }
    
    always {
        step
    }
}

pred step {
    { some new_proc: Process | new_proc != OS.current_proc and context_switch[new_proc] } 
    or 
    { some l1: L1Index, l2: L2Index | allocate[l1, l2] }
    or 
    { do_nothing }
}