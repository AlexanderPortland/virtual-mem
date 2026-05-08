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
    l2_entries: pfunc L2Index -> L1PageTable
}

sig L1PageTable {
    var l1_entries: pfunc L1Index -> L1PageTableEntry
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

fun walk_inner[l2: L2Index, l1: L1Index, root: L2PageTable]: lone PhysicalPage {
    root.l2_entries[l2].l1_entries[l1].page
}

pred pt_wellformed {
    wf__l1_pt_only_reachable_from_one_l2
    wf__l1_entries_only_from_pt
    wf__all_l1_already_exist
}

pred wf__all_l1_already_exist {
    all l2: L2Index, pt: L2PageTable | {
        some l1: L1PageTable | {
            pt.l2_entries[l2] = l1
        }
    }
}

pred wf__l1_pt_only_reachable_from_one_l2 {
    all l1: L1PageTable {
        all disj l2_a: L2PageTable, l2_b: L2PageTable | {
            not {{
                some index: L2Index | l2_a.l2_entries[index] = l1
            } and {
                some index: L2Index | l2_b.l2_entries[index] = l1
            }}
        }
    }
}

pred wf__l1_entries_only_from_pt {
    all entry: L1PageTableEntry {
        some entry.page implies {
            lone l1: L1PageTable | some idx: L1Index | l1.l1_entries[idx] = entry
        }
    }
}

test expect {
  walk_finds_page: {
    some l1: L1Index, l2: L2Index, root: L2PageTable, pt: L1PageTable, 
         ent: L1PageTableEntry, pg: PhysicalPage, va: VirtualAddress | {
      va.vpn1 = l2
      va.vpn0 = l1
      root.l2_entries[l2] = pt
      pt.l1_entries[l1] = ent
      ent.page = pg
      
      walk[va, root] = pg
      walk_inner[l2, l1, root] = pg
    }
  } is sat

  walk_fails_gracefully: {
    all va: VirtualAddress, root: L2PageTable | {
      no root.l2_entries[va.vpn1] implies no walk[va, root]
    }
  } is sat
}

test expect {
  must_have_all_l1: {
    pt_wellformed
    some pt: L2PageTable, idx: L2Index | no pt.l2_entries[idx]
  } is unsat

  no_shared_l1_v2: {
      pt_wellformed
      some l1: L1PageTable | {
          some disj l2a, l2b: L2PageTable | {
          (some i: L2Index | l2a.l2_entries[i] = l1)
          (some j: L2Index | l2b.l2_entries[j] = l1)
          }
      }
  } is unsat
}

test expect {
  valid_full_system: {
    pt_wellformed
    some va: VirtualAddress, root: L2PageTable | some walk[va, root]
  } for exactly 1 L2PageTable, 
    exactly 2 L1PageTable, 
    exactly 2 L2Index, 
    exactly 2 L1Index, 
    exactly 4 VirtualAddress,
    exactly 5 L1PageTableEntry is sat
}