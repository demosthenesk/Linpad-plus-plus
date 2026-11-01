import pefile,sys,struct,io,os
from PIL import Image
pe=pefile.PE(sys.argv[1]); outd=sys.argv[2]; os.makedirs(outd,exist_ok=True)
icons={}; groups={}; bmps={}
for t in pe.DIRECTORY_ENTRY_RESOURCE.entries:
    for e in t.directory.entries:
        for l in e.directory.entries:
            d=l.data.struct; b=pe.get_data(d.OffsetToData,d.Size)
            if t.id==3: icons[e.id]=b
            elif t.id==14: groups[e.id if e.name is None else str(e.name)]=b
            elif t.id==2: bmps[e.id]=b
for gid,b in groups.items():
    n=struct.unpack_from('<H',b,4)[0]
    ents=[]
    for i in range(n):
        w,h,cc,r,pl,bc,sz,iid=struct.unpack_from('<BBBBHHIH',b,6+i*14)
        ents.append((w or 256,h or 256,bc,iid))
    # best: largest <=32 at 32bpp; also save largest
    for target in (16,24,32,48):
        cands=[x for x in ents if x[0]==target]
        if not cands: continue
        w,h,bc,iid=max(cands,key=lambda x:x[2])
        data=icons[iid]
        if data[:8]==b'\x89PNG\r\n\x1a\n':
            im=Image.open(io.BytesIO(data))
        else:
            hdr=struct.pack('<HHH',0,1,1)+struct.pack('<BBBBHHII',w%256,h%256,0,0,1,bc,len(data),22)
            im=Image.open(io.BytesIO(hdr+data))
        im.convert('RGBA').save(f'{outd}/g{gid}_{target}.png')
for bid,b in bmps.items():
    # BMP: add file header
    hs=struct.unpack_from('<I',b,0)[0]
    bc=struct.unpack_from('<H',b,14)[0]; clr=struct.unpack_from('<I',b,32)[0]
    pal=(clr or (1<<bc if bc<=8 else 0))*4
    off=14+hs+pal
    fh=b'BM'+struct.pack('<IHHI',14+len(b),0,0,off)
    try: Image.open(io.BytesIO(fh+b)).convert('RGBA').save(f'{outd}/b{bid}.png')
    except Exception as ex: print('bmp',bid,ex)
print(len(groups), sorted(groups)[:5], sorted(groups, key=str)[-20:])
