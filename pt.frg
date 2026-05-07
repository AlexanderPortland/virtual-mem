#lang forge/temporal

open "addr.frg"
open "utils.frg"

sig L1PageTableEntry {
    page: one PhysicalPage
    // read: one Bool,
    // write: one Bool,
    // user: one Bool
}

sig L2PageTable {
    l2_entries: pfunc L2Index -> L1PageTable
}

sig L1PageTable {
    l1_entries: pfunc L1Index -> L1PageTableEntry
}

fun walk(va: VirtualAddress, root: L2PageTable): lone PhysicalPage {
    // Traverse the levels of pagetables
    let l1_table = root.l2_entries[va.vpn1] |
    let l1_entry = l1_table.l1_entries[va.vpn0] |
    // Get a physical address that corresponds to this physical page, but with the same offset.
    // NOTE: this relies on the fact that there will always exist a physical address if there's an l1 entry
    // and offset (addr/all_phys_addresses_exist).
    l1_entry.page
}

pred pt_wellformed {
    wf__l1_pt_only_reachable_from_one_l2
    wf__l1_entries_only_from_pt
}

pred wf__l1_pt_only_reachable_from_one_l2 {
    all l1: L1PageTable {
        one l2_parent: L2PageTable, real_index: L2Index | {
            all other: L2PageTable, index: L2Index | other.l2_entries[index] = l1 implies {
                other = l2_parent
                index = real_index
            }
        }
    }
}

pred wf__l1_entries_only_from_pt {
    all entry: L1PageTableEntry {
        one real_l1: L1PageTable, real_index: L1Index | {
            all other: L1PageTable, index: L1Index | {
                other.l1_entries[index] = entry implies {
                    other = real_l1
                    index = real_index
                }
            }
        }
    }
}