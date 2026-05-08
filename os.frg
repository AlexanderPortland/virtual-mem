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

-- Ensure that all physical addresses have a virtual address that maps to them 
pred all_pages_mapped {
    all pa: PhysicalPage | {
        some va: VirtualAddress, proc: Process | {
            walk[va, proc.root] = pa
        }
    }
}

// pred clean__no_orphan_pagetables {
//     -- Every l1 pagetable can be accessed from the root pagetable
//     all l1_pt: L1PageTable {
//         some l2_index: L2Index, l2_pt: L2PageTable | {
//             l2_pt.l2_entries[l2_index] = l1_pt
//         }
//     }

//     -- No orphan pagetable entries either
//     all pt_entry: L1PageTableEntry | {
//         some pt: L1PageTable, index: L1Index | {
//             pt.l1_entries[index] = pt_entry
//         }
//     }

//     -- Each l2 page table must be the root for some process
//     all l2: L2PageTable | some proc: Process | l2 = proc.root
// }

pred wf__no_shared_root_pts {
    all disj proc1, proc2: Process {
        proc1.root != proc2.root
    }
}

pred cpu_wellformed {
    wf__no_shared_root_pts
    traces
}

-- Frame conditions: keep everything frozen
pred do_nothing {
    l2_entries' = l2_entries
    l1_entries' = l1_entries
    page' = page
    write' = write
    user' = user
    OS.current_proc' = OS.current_proc
}

pred context_switch[new_proc: Process] {
    OS.current_proc' = new_proc
    -- MANDATORY: Keep the page tables from changing during a switch!
    l2_entries' = l2_entries
    l1_entries' = l1_entries
    page' = page
    write' = write
    user' = user
}

-- Kernel allocate
-- Corrected allocate in os.frg
-- In os.frg

pred allocate[va: VirtualAddress] {
    -- Pre-condition: No mapping exists yet for this address
    no walk[va, OS.current_proc.root]

    some free_page: PhysicalPage, new_ent: L1PageTableEntry, l1_table: L1PageTable | {
        -- 1. AVAILABILITY CHECKS
        -- Ensure the page isn't already pointed to by any entry
        free_page not in L1PageTableEntry.page
        // -- Ensure the entry isn't already part of any L1 table
        new_ent not in L1PageTable.l1_entries.L1PageTableEntry
        -- Ensure the L1 table isn't already in the L2 (if it's a new allocation)
        -- Note: You might want to allow sharing L1 tables if vpn1 matches!

        -- 2. APPLY MAPPINGS
        l2_entries' = l2_entries + (OS.current_proc.root -> va.vpn1 -> l1_table)
        l1_entries' = l1_entries + (l1_table -> va.vpn0 -> new_ent)

        -- 3. APPLY ATTRIBUTES
        page' = page ++ (new_ent -> free_page)
        write' = write ++ (new_ent -> True)
        user' = user ++ (new_ent -> True)

        -- 4. FRAME CONDITIONS
        OS.current_proc' = OS.current_proc
    }
}

-- Kernel free
pred free[va: VirtualAddress] {
    -- Pre-condition: Must be mapped to be freed
    some walk[va, OS.current_proc.root]

    let l1_table = OS.current_proc.root.l2_entries[va.vpn1] | {
        -- Remove the entry link from the table
        l1_entries' = l1_entries - (l1_table -> va.vpn0 -> L1PageTableEntry)
        
        -- Everything else stays exactly as it was
        l2_entries' = l2_entries
        page' = page
        write' = write
        user' = user
        OS.current_proc' = OS.current_proc
    }
}

pred traces {
    -- STATE 0: Hard-coded emptiness
    no l1_entries
    no l2_entries
    no page
    
    -- STATE 1: DEMAND CHANGE. 
    -- If this is UNSAT, Forge will tell us which rule is blocking it.
    some va: VirtualAddress | allocate[va]

    always {
        step
    }
}

pred step {
    (some va: VirtualAddress | allocate[va]) or 
    // (some va: VirtualAddress | free[va]) xor 
    (some p: Process | p != OS.current_proc and context_switch[p]) or
    (do_nothing)
}