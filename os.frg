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
}

// Kernel allocate
pred allocate[va: VirtualAddress] {
    no walk[va, OS.current_proc.root]

    some free_page: PhysicalPage | {
        all proc: Process, any_va: VirtualAddress | walk[any_va, OS.current_proc.root] != free_page
        let entry = OS.current_proc.root.l2_entries[va.vpn1].l1_entries[va.vpn0] | {
            -- Set the mapping and permissions in the NEXT state
            entry.page' = free_page
            entry.write' = True
            entry.user' = True
        }
        all other_entry: L1PageTableEntry | {
            (other_entry != OS.current_proc.root.l2_entries[va.vpn1].l1_entries[va.vpn0]) implies {
                other_entry.page' = other_entry.page
                other_entry.write' = other_entry.write
                other_entry.user' = other_entry.user
            }
        }
        
        OS.current_proc' = OS.current_proc
    }
}

pred traces {
    -- Initial State: Everything is empty
    all l1: L1PageTable, idx: L1Index | no l1.l1_entries[idx]
    
    -- Transitions
    always {
        step
    }
}

pred step {
    { some new_proc: Process | new_proc != OS.current_proc and context_switch[new_proc] } 
    or 
    { some va: VirtualAddress | allocate[va] }
    or 
    { do_nothing }
}