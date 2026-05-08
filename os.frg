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

pred os_wellformed {
    wf__no_shared_root_pts
    traces
}

pred do_nothing {
    -- All var fields remain unchanged
    l1_entries' = l1_entries
    page' = page
    write' = write
    user' = user
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

-- ============================================================
-- Tests for wf__no_shared_root_pts
-- ============================================================
test expect {
    -- Base case: a single process trivially has no shared roots
    wf_no_shared_one_proc: {
        one Process
        wf__no_shared_root_pts
    } is sat

    -- Two processes with distinct roots should satisfy the predicate
    wf_no_shared_distinct_roots: {
        some disj p1, p2: Process | {
            p1.root != p2.root
        }
        wf__no_shared_root_pts
    } is sat

    -- Two processes sharing the same root must violate the predicate
    wf_shared_root_violates: {
        some disj p1, p2: Process | {
            p1.root = p2.root
        }
        wf__no_shared_root_pts
    } is unsat
}

-- ============================================================
-- Tests for all_pages_mapped
-- ============================================================
test expect {
    -- Predicate should be satisfiable in some world
    all_pages_mapped_sat: {
        all_pages_mapped
    } is sat

    -- If there are physical pages but nothing maps to them, pred must fail
    all_pages_mapped_fails_empty_entries: {
        some PhysicalPage
        no page              -- no entry->physpage mappings exist
        all_pages_mapped
    } is unsat

    -- If no physical pages exist, predicate holds vacuously
    all_pages_mapped_vacuous: {
        no PhysicalPage
        all_pages_mapped
    } is sat
}

-- ============================================================
-- Tests for clean__no_orphan_pagetables
-- ============================================================
test expect {
    -- An entirely empty page table structure is trivially clean
    no_orphan_empty: {
        no L1PageTable
        no L1PageTableEntry
        clean__no_orphan_pagetables
    } is sat

    -- Predicate is satisfiable in a non-trivial world
    no_orphan_sat: {
        clean__no_orphan_pagetables
    } is sat

    -- An L1PageTable not reachable from any L2 entry is an orphan
    orphan_l1_violates: {
        some l1: L1PageTable | {
            all l2: L2PageTable, idx: L2Index | l2.l2_entries[idx] != l1
        }
        clean__no_orphan_pagetables
    } is unsat

    -- An L1PageTableEntry not in any L1PageTable's entries is an orphan
    orphan_entry_violates: {
        some e: L1PageTableEntry | {
            all pt: L1PageTable, idx: L1Index | pt.l1_entries[idx] != e
        }
        clean__no_orphan_pagetables
    } is unsat

    -- An L2PageTable with no owning process is an orphan
    orphan_l2_violates: {
        some l2: L2PageTable | all proc: Process | proc.root != l2
        clean__no_orphan_pagetables
    } is unsat
}

test expect {
    do_nothing_sat: {
        do_nothing
    } is sat

    do_nothing_preserves_l1_entries: {
        do_nothing
        l1_entries' != l1_entries
    } is unsat

    do_nothing_preserves_page: {
        do_nothing
        page' != page
    } is unsat

    do_nothing_preserves_write: {
        do_nothing
        write' != write
    } is unsat

    do_nothing_preserves_user: {
        do_nothing
        user' != user
    } is unsat

    do_nothing_preserves_current_proc: {
        do_nothing
        OS.current_proc' != OS.current_proc
    } is unsat
}

test expect {
    ctx_switch_sat: {
        some new_proc: Process | {
            new_proc != OS.current_proc
            context_switch[new_proc]
        }
    } is sat

    ctx_switch_updates_proc: {
        some new_proc: Process | {
            new_proc != OS.current_proc
            context_switch[new_proc]
            OS.current_proc' != new_proc
        }
    } is unsat

    ctx_switch_preserves_l1_entries: {
        some new_proc: Process | {
            context_switch[new_proc]
            l1_entries' != l1_entries
        }
    } is unsat

    ctx_switch_preserves_page: {
        some new_proc: Process | {
            context_switch[new_proc]
            page' != page
        }
    } is unsat

    ctx_switch_preserves_write: {
        some new_proc: Process | {
            context_switch[new_proc]
            write' != write
        }
    } is unsat

    ctx_switch_preserves_user: {
        some new_proc: Process | {
            context_switch[new_proc]
            user' != user
        }
    } is unsat
}

test expect {
    allocate_sat: {
        no l1_entries
        no page
        some l1: L1Index, l2: L2Index | allocate[l1, l2]
    } is sat

    allocate_requires_empty_slot: {
        some l1: L1Index, l2: L2Index | {
            some walk_inner[l2, l1, OS.current_proc.root]
            allocate[l1, l2]
        }
    } is unsat

    allocate_preserves_current_proc: {
        some l1: L1Index, l2: L2Index | {
            allocate[l1, l2]
            OS.current_proc' != OS.current_proc
        }
    } is unsat

    allocate_creates_entry: {
        some l1: L1Index, l2: L2Index | {
            no walk_inner[l2, l1, OS.current_proc.root]
            allocate[l1, l2]
            l1_entries in l1_entries'
            l1_entries' != l1_entries
        }
    } is sat

    allocate_uses_fresh_page: {
        some l1: L1Index, l2: L2Index, pa: PhysicalPage, proc: Process,
             other_l1: L1Index, other_l2: L2Index | {
            walk_inner[other_l2, other_l1, proc.root] = pa
            allocate[l1, l2]
            some e: L1PageTableEntry | {
                e not in OS.current_proc.root.l2_entries[L2Index].l1_entries[L1Index]
                e in (OS.current_proc.root.l2_entries[L2Index].l1_entries[L1Index])'
                page'[e] = pa
            }
        }
    } is unsat
}

test expect {
    step_sat: {
        step
    } is sat

    step_exhausts_actions: {
        step
        not do_nothing
        not { some new_proc: Process | new_proc != OS.current_proc and context_switch[new_proc] }
        not { some l1: L1Index, l2: L2Index | allocate[l1, l2] }
    } is unsat

    step_via_do_nothing: {
        do_nothing
        step
    } is sat

    step_via_context_switch: {
        some new_proc: Process | {
            new_proc != OS.current_proc
            context_switch[new_proc]
        }
        step
    } is sat

    step_via_allocate: {
        some l1: L1Index, l2: L2Index | allocate[l1, l2]
        step
    } is sat
}

test expect {
    traces_sat: {
        some p: Process | OS.current_proc = p
        traces
    } for 5 Process, 5 PhysicalPage, 5 VirtualAddress is sat

    traces_init_no_l1: {
        traces
        some l1_entries
    } is unsat

    traces_init_no_page: {
        traces
        some page
    } is unsat
}

test expect {
    os_wf_no_shared_roots: {
        os_wellformed
        not wf__no_shared_root_pts
    } is unsat

    no_self_context_switch_in_step: {
        step
        context_switch[OS.current_proc]
        OS.current_proc' != OS.current_proc
    } is unsat
}