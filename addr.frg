#lang forge/temporal

// A virtual memory address that a userland process will see & operate on.
sig VirtualAddress {
    vpn1: one L2Index,
    vpn0: one L1Index,
    // NOTE: we have to rename this (vs just "offset") so it uses a different identifier
    // than the PA.
    va_offset: one Offset
}


// The offset within a page of memory. Currently not used.
sig Offset {}
sig L2Index, L1Index {}

// A physical memory address.
sig PhysicalAddress {
    frame: one PhysicalPage,
    pa_offset: one Offset
}

// An actual piece of RAM in hardware.
sig PhysicalPage {}

one sig Mem {
    next: pfunc PhysicalPage -> PhysicalPage
}

pred addr_wellformed {
    wf__all_phys_addresses_exist
    wf__no_extra_phys_addresses
    wf__phys_pages_linear
}

// RULE: a physical address should exist for all combination of physical page & offset.
pred wf__all_phys_addresses_exist {
    all p: PhysicalPage, o: Offset | 
        one pa: PhysicalAddress | pa.frame = p and pa.pa_offset = o
}

pred wf__no_extra_phys_addresses {
    all pa: PhysicalAddress | {
        some p: PhysicalPage, o: Offset | 
            pa.frame = p and pa.pa_offset = o
    }
}

pred wf__phys_pages_linear {
    // No cycles
    all p: PhysicalPage | p not in p.^(Mem.next)
    // Only one starting page
    lone p: PhysicalPage | no prev: PhysicalPage | Mem.next[prev] = p
}