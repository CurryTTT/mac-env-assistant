"""Write Finder layout. Requires ds_store and mac_alias from PyPI.
Second pass reads the generated HFS+ catalog to bind the background alias.
"""
import sys, struct, datetime
from pathlib import Path
from ds_store import DSStore
from mac_alias import Alias, VolumeInfo, TargetInfo
EPOCH = datetime.datetime(1904,1,1,tzinfo=datetime.timezone.utc)
stage=Path(sys.argv[1]); image=Path(sys.argv[2]) if len(sys.argv)>2 else None
voltime, folderid, fileid, filetime = 0, 0, 0, 0
if image:
    raw=image.read_bytes()
    def u32(b,o): return struct.unpack_from('>I',b,o)[0]
    base=None
    for sector in range(1,64):
        b=raw[sector*512:(sector+1)*512]
        if b[:2]==b'PM' and b[48:80].split(b'\0')[0]==b'Apple_HFS':
            base=u32(b,8)*512; break
    if base is None:
        if raw[1024:1026] in (b'H+',b'HX'): base=0
        else: raise RuntimeError('HFS partition not found')
    vh=raw[base+1024:base+1536]; voltime=u32(vh,16); block=u32(vh,40)
    fork=vh[272:352]; size=struct.unpack_from('>Q',fork)[0]; catalog=b''
    for offset in range(16,80,8):
        start,count=struct.unpack_from('>II',fork,offset)
        catalog+=raw[base+start*block:base+(start+count)*block]
    catalog=catalog[:size]; nodeSize=struct.unpack_from('>H',catalog,32)[0]; leaf=u32(catalog,24)
    records=[]
    while leaf:
        node=catalog[leaf*nodeSize:(leaf+1)*nodeSize]
        for i in range(struct.unpack_from('>H',node,10)[0]):
            at=struct.unpack_from('>H',node,nodeSize-2*(i+1))[0]
            length=struct.unpack_from('>H',node,at)[0]; parent=u32(node,at+2)
            n=struct.unpack_from('>H',node,at+6)[0]; name=node[at+8:at+8+n*2].decode('utf-16be')
            data=at+2+length; typ=struct.unpack_from('>H',node,data)[0]
            if typ in (1,2): records.append((parent,name,u32(node,data+8),u32(node,data+12)))
        leaf=u32(node,0)
    folderid=next(r[2] for r in records if r[0]==2 and r[1]=='.background')
    _,_,fileid,filetime=next(r for r in records if r[0]==folderid and r[1]=='background.png')
    print('HFS background:',voltime,folderid,fileid,filetime)
a=Alias(volume=VolumeInfo('Mac Env Assistant',EPOCH+datetime.timedelta(seconds=voltime),b'H+',5,0,b'\0\0',posix_path='/Volumes/Mac Env Assistant'), target=TargetInfo(0,'background.png',folderid,fileid,EPOCH+datetime.timedelta(seconds=filetime),b'\0\0\0\0',b'PNGf',folder_name='.background',cnid_path=[folderid],carbon_path='Mac Env Assistant:.background:background.png',posix_path='/.background/background.png'))
with DSStore.open(str(stage/'.DS_Store'),'w+') as ds:
    ds['.']['bwsp']={'ShowToolbar':False,'ShowSidebar':False,'ShowStatusBar':False,'ShowPathbar':False,'ShowTabView':False,'WindowBounds':'{{200, 120}, {900, 540}}','ContainerShowSidebar':False}
    ds['.']['icvp']={'viewOptionsVersion':1,'backgroundType':2,'backgroundImageAlias':a.to_bytes(),'iconSize':128.0,'textSize':18.0,'gridSpacing':100.0,'gridOffsetX':0.0,'gridOffsetY':0.0,'arrangeBy':'none','labelOnBottom':True,'showItemInfo':False,'showIconPreview':False}
    ds['.']['vSrn']=('long',1)
    ds['.']['vstl']=('type',b'icnv')
    ds['MacEnvAssistant.app']['Iloc']=(225,270)
    ds['Applications']['Iloc']=(675,270)
