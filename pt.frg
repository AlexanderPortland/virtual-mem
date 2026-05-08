#lang forge/temporal

open "addr.frg"
open "utils.frg"

sig L1PageTableEntry {
    var page: lone PhysicalPage,
    // Whether the page is writable
    var write: one Bool,
    // Whether the page is user-accessible
    var user: one Bool
}

sig L2PageTable {
    var l2_entries: pfunc L2Index -> L1PageTable
}

sig L1PageTable {
    var l1_entries: pfunc L1Index -> L1PageTableEntry
}

fun walk[va: VirtualAddress, root: L2PageTable]: lone PhysicalPage {
    // Traverse the levels of pagetables
    // let l1_table = root.l2_entries[va.vpn1] |
    // let l1_entry = l1_table.l1_entries[va.vpn0] |
    // Get a physical address that corresponds to this physical page, but with the same offset.
    // l1_entry.page
    root.l2_entries[va.vpn1].l1_entries[va.vpn0].page
}

pred pt_wellformed {
    // wf__l1_pt_only_reachable_from_one_l2
    wf__l1_entries_only_from_pt
}

pred wf__l1_pt_only_reachable_from_one_l2 {
    all l1: L1PageTable {
        lone l2_parent: L2PageTable, real_index: L2Index | {
            all other: L2PageTable, index: L2Index | other.l2_entries[index] = l1 implies {
                other = l2_parent
                index = real_index
            }
        }
    }
}

pred wf__l1_entries_only_from_pt {
    all entry: L1PageTableEntry | {
        -- ONLY enforce the "must have a parent" rule IF the entry is actually 
        -- pointed to by some table.
        some pt: L1PageTable, idx: L1Index | pt.l1_entries[idx] = entry 
        implies {
            lone real_l1: L1PageTable, real_index: L1Index | {
                all other: L1PageTable, index: L1Index | {
                    other.l1_entries[index] = entry implies {
                        other = real_l1
                        index = real_index
                    }
                }
            }
        }
    }
}