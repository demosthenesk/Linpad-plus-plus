import pefile,sys,struct,re
pe=pefile.PE(sys.argv[1])
data=open(sys.argv[1],'rb').read()
ids=set(int(x) for x in re.findall(r'^\s*(\d+):',open('menus.txt').read(),re.M))
# dialogs
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
    return b[o:e].decode('utf-16le','replace'), e+2
def sz_or_ord(b,o):
    if b[o:o+2]==b'\xff\xff': return struct.unpack_from('<H',b,o+2)[0], o+4
    return wstr(b,o)
out=[]
for did,b in res(5):
    if b[2:4]==b'\xff\xff':  # DLGTEMPLATEEX
        o=26; menu,o=sz_or_ord(b,o); cls,o=sz_or_ord(b,o); title,o=wstr(b,o)
        cnt=struct.unpack_from('<H',b,16)[0]
        style=struct.unpack_from('<I',b,12)[0]
        if style & 0x40:
            o+=6; face,o=wstr(b,o)
        items=[]
        for i in range(cnt):
            o=(o+3)&~3
            idd=struct.unpack_from('<i',b,o+20)[0]; o+=24
            c,o=sz_or_ord(b,o); t,o=sz_or_ord(b,o)
            ex=struct.unpack_from('<H',b,o)[0]; o+=2+ex
            if isinstance(t,str) and t.strip(): items.append(t)
        out.append(f'DIALOG {did}: "{title}" ({cnt} controls): '+' | '.join(items[:60]))
    else:
        out.append(f'DIALOG {did}: (std template)')
open('dialogs.txt','w').write('\n'.join(out))
# key table scan, stride 24
VK={0x70+i:f'F{i+1}' for i in range(24)}
VK.update({0x09:'Tab',0x0D:'Enter',0x1B:'Esc',0x20:'Space',0x21:'PgUp',0x22:'PgDown',0x23:'End',0x24:'Home',0x25:'Left',0x26:'Up',0x27:'Right',0x28:'Down',0x2D:'Insert',0x2E:'Del',0x08:'Backspace',0x6B:'Num+',0x6D:'Num-',0x6A:'Num*',0x6F:'Num/',0xBB:'=',0xBD:'-',0xDB:'[',0xDD:']',0xBF:'/',0xDC:'\\',0xC0:'`',0xBA:';',0xDE:"'",0xBC:',',0xBE:'.',0x60:'Num0',0x6E:'Num.'})
for i in range(0x30,0x5B): VK[i]=chr(i)
best=None
for start in range(0,len(data)-24,4):
    vk,fid=struct.unpack_from('<iI',data,start)
    if fid==41001 and vk==0x4E and data[start+8:start+11]==b'\x01\x00\x00':
        best=start;break
print('table at',best)
keys=[]
o=best
while True:
    vk,fid=struct.unpack_from('<iI',data,o); c,a,s=data[o+8:o+11]
    if fid==0 or fid>60000 or c>1 or a>1 or s>1 or vk<0 or vk>255: break
    mods=('Ctrl+' if c else '')+('Alt+' if a else '')+('Shift+' if s else '')
    keys.append((fid, (mods+VK.get(vk,hex(vk))) if vk else ''))
    o+=24
print(len(keys))
open('keys.txt','w').write('\n'.join(f'{f}\t{k}' for f,k in keys))
