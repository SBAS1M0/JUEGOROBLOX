import os, sys
from lupa import lua54
SIM=os.path.dirname(os.path.abspath(__file__))
ROOT=os.path.join(SIM, '..', '..', 'src')
def files(sub):
    out=[]
    base=os.path.join(ROOT,sub)
    for dp,_,fs in os.walk(base):
        for f in sorted(fs):
            if f.endswith('.lua'):
                p=os.path.join(dp,f); out.append((os.path.relpath(p,base),p))
    return out
lua=lua54.LuaRuntime(unpack_returned_tuples=True)
g=lua.globals()
g.SIM_DIR=SIM
tbl=lua.eval('{}')
for k in ('shared','server','client'):
    t=lua.eval('{}')
    for i,(rel,ab) in enumerate(files(k)):
        t[i+1]=lua.table(rel,ab)
    tbl[k]=t
g.FILES=tbl
script=sys.argv[1] if len(sys.argv)>1 else 'scenario.lua'
lua.execute(open(os.path.join(SIM,script)).read())
