#lang forge/temporal

open "addr.frg"
open "pt.frg"
open "utils.frg"
open "os.frg"

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
    // all_clean
    // all_pages_mapped
} for exactly 5 PhysicalPage, exactly 2 Process, exactly 10 L1PageTableEntry