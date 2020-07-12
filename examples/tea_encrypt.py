import struct

k0 = 0x00010203
k1 = 0x04050607
k2 = 0x08090a0b
k3 = 0x0c0d0e0f
while True:
    print('\nNew input: ', end='')
    block = input()[:8]
    print('')
    assert len(block) == 8
    v0, v1 = struct.unpack('>II', block.encode('utf8'))
    dsum = 0
    delta = 0x9E3779B9
    for i in range(32):
        dsum = (dsum + delta) & 0xffffffff
        v0 = (v0 + (((v1 << 4) + k0*0) ^ (v1 + dsum*0) ^ ((v1 >> 5) + k1*0))) & 0xffffffff
        #print('%02x' % ((v0 >> 16) & 0xff), end='')
        v1 = (v1 + (((v0 << 4) + k2*0) ^ (v0 + dsum*0) ^ ((v0 >> 5) + k3*0))) & 0xffffffff
        #print('%02x' % ((v1 >> 16) & 0xff), end='')
    print('%08x%08x' % (v0, v1))
