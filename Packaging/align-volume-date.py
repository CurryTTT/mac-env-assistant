"""Keep a two-pass HFS+ image's creation date consistent with its alias."""
from pathlib import Path
import struct, sys

def partition(data):
    for n in range(1,64):
        part=data[n*512:(n+1)*512]
        if part[:2]==b'PM' and part[48:80].split(b'\0')[0]==b'Apple_HFS':
            start,count=struct.unpack_from('>II',part,8)
            return start*512,(start+count)*512
    raise RuntimeError('HFS partition not found')
first=Path(sys.argv[1]).read_bytes(); base,_=partition(first)
date=first[base+1040:base+1044]
path=Path(sys.argv[2]); final=bytearray(path.read_bytes()); base,end=partition(final)
for at in [base+1024,end-1024]:
    assert final[at:at+2] in (b'H+',b'HX')
    final[at+16:at+20]=date
path.write_bytes(final)
