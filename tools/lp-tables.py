import struct, sys
d = open(sys.argv[1], 'rb').read()
# geometry lives at offset 4096 (and a backup at 8192)
g = d[4096:4096+4096]
magic, struct_size = struct.unpack('<II', g[0:8])
assert magic == 0x616c4467, hex(magic)
meta_max, slot_count, lbs = struct.unpack('<III', g[40:52])
print(f"geometry: metadata_max_size={meta_max} slots={slot_count} logical_block_size={lbs}")
# primary metadata starts right after the two geometry blocks (4096*2 + 4096 reserved)
off = 4096 + 4096 + 4096
h = d[off:off+256]
hm, major, minor, hsize = struct.unpack('<IHHI', h[0:12])
assert hm == 0x414C5030, hex(hm)
print(f"header v{major}.{minor} size={hsize}")
p = 12+32
tables_size, = struct.unpack('<I', h[p:p+4]); p += 4+32
def desc(o): return struct.unpack('<III', h[o:o+12])
parts = desc(p); ext = desc(p+12); grp = desc(p+24); bdev = desc(p+36)
print("partitions", parts, "extents", ext, "groups", grp, "block_devices", bdev)
tbl = d[off+hsize:off+hsize+tables_size]
P=[]
for i in range(parts[1]):
    e = tbl[parts[0]+i*parts[2]:][:parts[2]]
    name = e[:36].rstrip(b'\0').decode()
    attrs, fei, ne, gi = struct.unpack('<IIII', e[36:52])
    P.append((name, fei, ne)); print(f"  part {name}: first_extent={fei} num_extents={ne}")
E=[]
for i in range(ext[1]):
    e = tbl[ext[0]+i*ext[2]:][:ext[2]]
    ns, tt, tdata, tsrc = struct.unpack('<IQII'[0:0] or '<QIQI', e[:24])
    E.append((ns, tt, tdata, tsrc)); print(f"  extent {i}: sectors={ns} type={tt} target_data={tdata} source={tsrc}")
B=[]
for i in range(bdev[1]):
    e = tbl[bdev[0]+i*bdev[2]:][:bdev[2]]
    fls, align, aoff, size = struct.unpack('<QIIQ', e[:24])
    name = e[24:24+36].rstrip(b'\0').decode()
    B.append((name, fls, size)); print(f"  blockdev {i}: {name} first_logical_sector={fls} size={size}")
print("\n--- dmsetup tables ---")
for name, fei, ne in P:
    rows=[]; start=0
    for j in range(fei, fei+ne):
        ns, tt, tdata, tsrc = E[j]
        rows.append(f"{start} {ns} linear DEV{tsrc} {tdata}")
        start += ns
    if rows: print(f"{name}: " + " ; ".join(rows))
