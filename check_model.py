"""Exhaustively check the abstract pointer/flag model for small FIFOs.

This checks finite interleavings of digital register transitions, not RTL syntax,
payload storage or analog CDC behavior. Every reachable state is checked under all
four actions: idle/write on the write clock, and idle/read on the read clock.
"""
from collections import deque
from typing import NamedTuple


class State(NamedTuple):
    wr: int = 0
    rd: int = 0
    read_sync1: int = 0
    read_sync2: int = 0
    write_sync1: int = 0
    write_sync2: int = 0
    full: bool = False
    empty: bool = True


def gray(pointer: int) -> int:
    return pointer ^ (pointer >> 1)


def explore(address_bits: int) -> int:
    capacity = 1 << address_bits
    modulus = 2 * capacity
    full_mask = capacity | (capacity >> 1)
    initial = State()
    todo = deque([initial])
    seen = {initial}
    while todo:
        st = todo.popleft()
        occupancy = (st.wr - st.rd) % modulus
        if occupancy > capacity or (occupancy == capacity and not st.full) or (occupancy == 0 and not st.empty):
            raise AssertionError(f"unsafe state for capacity {capacity}: {st}")
        for wants_transfer in (0, 1):
            w = (st.wr + (wants_transfer and not st.full)) % modulus
            r = (st.rd + (wants_transfer and not st.empty)) % modulus
            write_edge = st._replace(wr=w, read_sync1=gray(st.rd), read_sync2=st.read_sync1,
                                     full=(gray(w) == (st.read_sync2 ^ full_mask)))
            read_edge = st._replace(rd=r, write_sync1=gray(st.wr), write_sync2=st.write_sync1,
                                    empty=(gray(r) == st.write_sync2))
            for nxt in (write_edge, read_edge):
                if nxt not in seen:
                    seen.add(nxt)
                    todo.append(nxt)
    return len(seen)


if __name__ == "__main__":
    for bits in (2, 3):
        print(f"Abstract safety passed for depth {1 << bits}: {explore(bits):,} reachable states")
