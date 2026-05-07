#lang forge/temporal

open "addr.frg"
open "pt.frg"
open "utils.frg"

sig Process {
    root: one L2PageTable
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

pred cpu_wellformed {
    wf__no_shared_root_pts
}

pred all_clean {
    clean__no_orphan_pagetables
}

pred all_wellformed {
    addr_wellformed
    pt_wellformed
    cpu_wellformed
}

run {
    all_wellformed
    all_clean
    // all_pages_mapped
} for exactly 4 PhysicalPage, exactly 2 Process, exactly 3 L1PageTableEntry