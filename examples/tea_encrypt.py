import struct

k0 = 0x00010203
k1 = 0x04050607
k2 = 0x08090a0b
k3 = 0x0c0d0e0f
while True:
    block = input().strip()
    assert len(block) == 8
    v0, v1 = struct.unpack('>II', block.encode('utf8'))
    dsum = 0
    delta = 0x9E3779B9
    for i in range(32):
        print('Q--', end='')
    print('%08x%08x' % (v0, v1))
