import pefile,sys,struct
pe=pefile.PE(sys.argv[1])
def res(tid):
    for t in pe.DIRECTORY_ENTRY_RESOURCE.entries:
        if t.id==tid:
            for e in t.directory.entries:
                for l in e.directory.entries:
                    d=l.data.struct
                    yield e.id, pe.get_data(d.OffsetToData,d.Size)
def wstr(b,o):
    e=o
    while b[e:e+2]!=b'\0\0': e+=2
    return b[o:e].decode('utf-16le'), e+2
def std(b):
    o=4; stack=[0]; out=[]
    depth=0
    while o<len(b):
        flags,=struct.unpack_from('<H',b,o); o+=2
        if flags & 0x10:
            s,o=wstr(b,o); out.append('  '*depth+'['+s+']'); depth+=1
            if flags&0x80: pass
            stack.append(flags)
        else:
            idd,=struct.unpack_from('<H',b,o); o+=2
            s,o=wstr(b,o)
            out.append('  '*depth+(f'{idd}: {s}' if s else '----'))
            if flags&0x80:
                depth-=1
                # pop popups that ended
        if flags & 0x80 and flags & 0x10 and False: pass
    return out
def menuex(b):
    o=4+struct.unpack_from('<H',b,2)[0]
    out=[]
    def items(o,depth):
        while True:
            typ,state,idd,res_=struct.unpack_from('<IIIH',b,o); o+=14
            s,o=wstr(b,o)
            o=(o+3)&~3
            if res_&1:
                o+=4
                out.append('  '*depth+f'[{s}] ({idd})')
                o=items(o,depth+1)
            else:
                out.append('  '*depth+(f'{idd}: {s}' if (s or idd) else '----'))
            if res_&0x80: return o
    items(o,0); return out
for mid,b in res(4):
    ver,=struct.unpack_from('<H',b,0)
    print('=== MENU',mid,'ver',ver)
    if ver==1: print('\n'.join(menuex(b)))
    else:
        # standard: proper recursive
        out=[]
        def items(o,depth):
            while True:
                flags,=struct.unpack_from('<H',b,o); o+=2
                if flags&0x10:
                    s,o=wstr(b,o); out.append('  '*depth+'['+s+']'); o=items(o,depth+1)
                else:
                    idd,=struct.unpack_from('<H',b,o); o+=2; s,o=wstr(b,o)
                    out.append('  '*depth+(f'{idd}: {s}' if s else '----'))
                if flags&0x80: return o
        items(4,0); print('\n'.join(out))
