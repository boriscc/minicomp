import struct
import sys

assert len(sys.argv[1]) == 8
v0, v1 = struct.unpack('>II', sys.argv[1].encode('utf8'))
print('%08x%08x' % (v0, v1))
