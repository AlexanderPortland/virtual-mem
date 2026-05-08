#lang forge/temporal

open "addr.frg"
open "pt.frg"
open "utils.frg"
open "os.frg"

option max_tracelength 10
option min_tracelength 5

// pred all_clean {
//     clean__no_orphan_pagetables
// }

pred all_wellformed {
    addr_wellformed
    pt_wellformed
    os_wellformed
}

run {
    all_wellformed
    // all_clean
    // all_pages_mapped
} for exactly 5 PhysicalPage, exactly 2 Process--, exactly 10 L1PageTableEntry