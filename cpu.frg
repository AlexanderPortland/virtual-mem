#lang forge/froglet

open "addr.frg"
open "pt.frg"
open "utils.frg"

one sig Root {
    pt: one L2PageTable
}

// Ensure that all physical addresses have a virtual address that maps to them 
pred all_pages_mapped {
    all pa: PhysicalPage | {
        some va: VirtualAddress | {
            walk[va, Root.pt] = pa
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

    // Only one l2 pagetable, and it's the root
    // TODO: change this when having multiple processes
    all l2: L2PageTable | l2 = Root.pt
}

pred all_clean {
    clean__no_orphan_pagetables
}

pred all_wellformed {
    addr_wellformed
    pt_wellformed
}

run {
    all_wellformed
    all_clean
    all_pages_mapped
} for exactly 4 PhysicalPage, exactly 1 L1PageTable