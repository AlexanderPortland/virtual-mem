#lang forge/temporal


open "addr.frg"
open "pt.frg"
open "utils.frg"
open "os.frg"

option max_tracelength 15
option min_tracelength 10

pred all_clean {
    // clean__no_orphan_pagetables
}

pred all_wellformed {
    addr_wellformed
    pt_wellformed
    cpu_wellformed
}

// run {
//     all_wellformed
//     // all_clean
//     // all_pages_mapped
//     #VirtualAddress > 1
//     eventually { some va: VirtualAddress | some walk[va, OS.current_proc.root] }
// } for exactly 5 PhysicalPage, exactly 2 Process, exactly 10 L1PageTableEntry

run {
    all_wellformed
    traces
    -- Demand an allocation in State 1 and a free later on
    // next_state { some va: VirtualAddress | allocate[va] }
    // eventually { some va: VirtualAddress | free[va] }
    // #L1PageTable > 1
} for exactly 2 Process, exactly 10 L1PageTableEntry, exactly 5 PhysicalPage, exactly 2 L1Index --, exactly 2 L2Index, exactly 3 L1Index, exactly 6 VirtualAddress