"""Offline measurements of reviewed native originals; not an audit filter or proof API.
Requires NumPy, SciPy, and Pillow. No source app changes or regenerated screenshots.
"""
from pathlib import Path
from collections import Counter
import argparse, hashlib, io, json, math, zlib
import numpy as np
from PIL import Image, ImageCms, ImageDraw
from scipy.ndimage import label, distance_transform_edt, binary_erosion

GROUPS = {
 'filter': ('DC214045-E411-4EFF-966B-506D6FEF877F.png','D63D1E50-2A75-4F41-A3F5-B320185D8EEC.png','8E92E674-A733-48B8-896C-D05A4CB11B38.json','8BBA14B9-C024-4D8C-9CB5-920EB5FE8F7E.json'),
 'first': ('59ABBC34-9763-4898-99BE-B6D98A391489.png','39BC4105-C824-48E3-9351-CBD80682AB7C.png','6FBCAF98-43CC-4185-8ACC-D8D7C40FC04D.json','97838678-4704-4E7D-B63C-71AE99F1D29F.json'),
 'third': ('2D70CE1E-423C-44FF-AB2D-7FABAA75C2ED.png','CAA03408-26BE-48CF-B2B0-80C80A8D8646.png','C575B4E6-4B80-47AF-B153-1163B8DA9C25.json','64A45338-7C8E-4E35-9FAC-7CFC3EC12F88.json'),
}
# Full-ink support is selected from original visible glyph extents, not solely AX rectangles.
# Joy deliberately includes both title lines so the overlapping AX boxes cannot truncate ink.
# Chord supports contain every visible glyph edge plus 4px backing. They do not
# treat the separate bright capsule outline as the background behind the letters.
SPECS = [
 (10,'filter','songs.filter.violin.standard.4','songs.filter.violin.standard.4.title','Violin',(818,569,940,614),'primary',None),
 (12,'first','songs.known.song-ode-to-joy','songs.tile.known.song-ode-to-joy.cover.title.1','Joy',(88,1120,355,1290),'dark',(88,1205,240,1290)),
 (14,'first','songs.known.song-ode-to-joy','songs.tile.known.song-ode-to-joy.chords.chord.C','C',(79,1365,112,1401),'primary',None),
 (15,'first','songs.known.song-ode-to-joy','songs.tile.known.song-ode-to-joy.chords.chord.G','G',(162,1365,197,1401),'primary',None),
 (16,'first','songs.known.song-ode-to-joy','songs.tile.known.song-ode-to-joy.duration','2:07',(147,1495,242,1554),'secondary',None),
 (17,'first','songs.known.song-ode-to-joy','songs.tile.known.song-ode-to-joy.xp','+35 XP',(251,1495,397,1554),'secondary',None),
 (18,'first','songs.known.gtr-6-5','songs.tile.known.gtr-6-5.chords.chord.G','G',(565,1515,600,1551),'primary',None),
 (19,'first','songs.known.gtr-6-5','songs.tile.known.gtr-6-5.chords.chord.C','C',(753,1515,786,1551),'primary',None),
 (20,'first','songs.known.gtr-6-5','songs.tile.known.gtr-6-5.chords.chord.D','D',(837,1515,869,1550),'primary',None),
 (21,'third','songs.known.song-silent-night','songs.tile.known.song-silent-night.cover.title.0','Silent',(528,1358,737,1425),'primary',None),
 (22,'third','songs.known.song-silent-night','songs.tile.known.song-silent-night.cover.title.1','Night',(532,1428,736,1511),'primary',None),
 (23,'third','songs.known.song-silent-night','songs.tile.known.song-silent-night.cover.catalogue','28',(477,1258,521,1300),'primary',None),
 (24,'third','songs.known.song-silent-night','songs.tile.known.song-silent-night.chords.chord.A7','A7',(428,1871,482,1906),'primary',None),
 (25,'first','songs.versions.song-ode-to-joy','songs.tile.known.song-ode-to-joy.versions.more','+5',(438,1394,489,1432),'primary',None),
 (26,'first','songs.versions.gtr-6-5','songs.tile.known.gtr-6-5.versions.more','+5',(924,1394,975,1432),'primary',None),
]
ROLES={'primary':(245,243,239),'secondary':(163,168,177),'dark':(6,7,8)}
def sha(b): return hashlib.sha256(b).hexdigest()
def source_profile(data):
 assert data[:8]==b'\x89PNG\r\n\x1a\n'
 offset=8; declaration=None; idat=False
 while offset<len(data):
  n=int.from_bytes(data[offset:offset+4],'big');kind=data[offset+4:offset+8];p=data[offset+8:offset+8+n]
  assert len(p)==n and zlib.crc32(kind+p)==int.from_bytes(data[offset+8+n:offset+12+n],'big')
  if kind in (b'iCCP',b'sRGB'):
   assert declaration is None and not idat
   if kind==b'sRGB': assert len(p)==1 and p[0]<4;declaration=('sRGB',int(p[0]),None)
   else:
    nul=p.index(0);assert 1<=nul<=79 and p[nul+1]==0;icc=zlib.decompress(p[nul+2:]);assert 128<=len(icc)<=1048576;declaration=('ICC',sha(icc),icc)
  assert kind not in (b'acTL',b'cICP',b'mDCV',b'cLLI')
  if kind==b'IDAT':idat=True
  offset+=12+n
  if kind==b'IEND': assert offset==len(data);break
 assert declaration and idat
 return declaration
def pixels(path):
 data=path.read_bytes();kind,description,icc=source_profile(data);im=Image.open(io.BytesIO(data))
 assert im.size==(1206,2622) and im.getexif().get(274,1)==1
 assert np.all(np.asarray(im.convert('RGBA'))[:,:,3]==255)
 if kind=='ICC':im=ImageCms.profileToProfile(im.convert('RGB'),ImageCms.ImageCmsProfile(io.BytesIO(icc)),ImageCms.createProfile('sRGB'),outputMode='RGB',renderingIntent=1)
 return np.asarray(im.convert('RGB')),{'sha256':sha(data),'profile':kind,'profileDescription':description,'normalization':'declared sRGB: no transform' if kind=='sRGB' else 'embedded ICC to sRGB relative-colorimetric','size':[1206,2622],'orientation':1}
def luminance(a):
 v=a.astype(float)/255.;return np.where(v<=.04045,v/12.92,((v+.055)/1.055)**2.4)@np.array([.2126,.7152,.0722])
def nodes(n):
 yield n
 for child in n.get('children',[]):yield from nodes(child)
def find(h,identifier,kind):
 a=[n for n in nodes(h) if n.get('identifier')==identifier and n.get('type')==kind];assert len(a)==1,(identifier,len(a));return a[0]
def point(a,L,mask,box,maximum):
 q=np.where(mask,L,-np.inf if maximum else np.inf);y,x=np.unravel_index(q.argmax() if maximum else q.argmin(),q.shape)
 return {'pixel':[int(x+box[0]),int(y+box[1])],'rgb':a[y,x].tolist(),'luminance':float(L[y,x])}
def run(root,out):
 out.mkdir(parents=True,exist_ok=True);(out/'masks').mkdir(exist_ok=True);groups={};result=[];tiles=[]
 for key,files in GROUPS.items():
  first,p1=pixels(root/files[0]);second,p2=pixels(root/files[1]);h1=json.loads((root/files[2]).read_text());h2=json.loads((root/files[3]).read_text())
  assert h1['frame']==h2['frame']==[0,0,402,874];assert np.array_equal(first[118:],second[118:])
  groups[key]=(first,second,h1,h2);p1['file']=files[0];p2['file']=files[1]
  groups[key]+=({'before':p1,'after':p2,'hierarchyBefore':{'file':files[2],'sha256':sha((root/files[2]).read_bytes())},'hierarchyAfter':{'file':files[3],'sha256':sha((root/files[3]).read_bytes())},'appBodyExactEquality':True,'appBodyPixelY':118},)
 for number,group,parent,identifier,text,box,role,core_roi in SPECS:
  first,second,h1,h2,provenance=groups[group];leaf=find(h2,identifier,48);old=find(h1,identifier,48);parentnode=find(h2,parent,9);oldparent=find(h1,parent,9)
  assert leaf['label']==old['label']==text and leaf['frame']==old['frame'];assert any(n is leaf for n in nodes(parentnode));assert any(n is old for n in nodes(oldparent));assert parentnode['frame']==oldparent['frame'] and parentnode['label']==oldparent['label']
  assert 0<=box[0]<box[2]<=1206 and 354<=box[1]<box[3]<2373
  a=second[box[1]:box[3],box[0]:box[2]];assert np.array_equal(a,first[box[1]:box[3],box[0]:box[2]])
  L=luminance(a);light=role!='dark';fg=np.array(ROLES[role]);core=np.max(abs(a.astype(float)-fg),axis=2)<=1
  if core_roi:
   roi=np.zeros(core.shape,bool);roi[core_roi[1]-box[1]:core_roi[3]-box[1],core_roi[0]-box[0]:core_roi[2]-box[0]]=True;core&=roi
  strong=(L>.15 if role=='secondary' else L>.3) if light else L<.25
  components,n=label(strong);sizes=np.bincount(components.ravel());strong &= sizes[components]>=3
  interior=binary_erosion(strong,structure=np.ones((3,3)),iterations=2)
  if core_roi:interior &= roi
  core |= interior
  assert core.sum()>20 and np.all(~core | strong)
  distance=distance_transform_edt(~strong);ambiguous=(distance<=2)&~core
  backing=distance>2;adjacent=backing&(distance<=8)
  assert backing.sum()>10 and adjacent.sum()>10
  extremes={}
  for title,m in [('fullSupportBacking',backing),('adjacentBacking2to8px',adjacent)]:
   f=point(a,L,core,box,not light);b=point(a,L,m,box,light)
   r=(max(f['luminance'],b['luminance'])+.05)/(min(f['luminance'],b['luminance'])+.05)
   extremes[title]={'ratio':r,'foreground':f,'background':b,'backgroundCount':int(m.sum())}
  sensitivity={}
  for radius in (2,3,4,5):
   b=distance>radius;f=point(a,L,core,box,not light);v=point(a,L,b,box,light)
   sensitivity[str(radius)]=(max(f['luminance'],v['luminance'])+.05)/(min(f['luminance'],v['luminance'])+.05)
  file=f'finding-{number:02d}.npz';np.savez_compressed(out/'masks'/file,core=core,strongInk=strong,ambiguousAAAndBoundary=ambiguous,backing=backing,adjacentBacking=adjacent)
  original=Image.fromarray(a);original.save(out/'masks'/f'finding-{number:02d}-original.png')
  overlay=a.copy();overlay[backing]=[0,190,220];overlay[ambiguous]=[255,190,0];overlay[core]=[255,0,255]
  Image.fromarray(overlay).save(out/'masks'/f'finding-{number:02d}-roles.png')
  ratio=extremes['fullSupportBacking']['ratio'];row={'finding':number,'group':group,'label':text,'id':identifier,'parent':parent,'parentLabel':parentnode['label'],'type':'StaticText','parentType':'Button','framePoints':leaf['frame'],'supportPixels':box,'coreROI':core_roi,'roleRGB':ROLES[role],'source':provenance,'coreCount':int(core.sum()),'strongInkCount':int(strong.sum()),'ambiguousBoundaryCount':int(ambiguous.sum()),'extremes':extremes,'backgroundExclusionRadiusSensitivity':sensitivity,'maskFile':f'masks/{file}','maskSHA256':sha((out/'masks'/file).read_bytes()),'authorization':False,'result':'measured lower bound below 4.5; manual backing/AA adjudication needed' if ratio<4.5 else 'measured observed core/backing bound at least 4.5; no audit waiver'};result.append(row)
  scale=3 if a.shape[1]<200 else 2;tile=Image.new('RGB',(1200,max(130,a.shape[0]*scale+35)),(240,240,240));d=ImageDraw.Draw(tile);d.text((5,5),f'{number}: {text} | observed bound {ratio:.5f}:1 | magenta core / amber boundary / cyan backing',fill='black');tile.paste(original.resize((a.shape[1]*scale,a.shape[0]*scale),Image.Resampling.NEAREST),(5,30));tile.paste(Image.fromarray(overlay).resize((a.shape[1]*scale,a.shape[0]*scale),Image.Resampling.NEAREST),(600,30));tiles.append(tile)
 sheet=Image.new('RGB',(1200,sum(t.height for t in tiles)),(240,240,240));y=0
 for t in tiles:sheet.paste(t,(0,y));y+=t.height
 sheet.save(out/'support-and-masks.png')
 report={'diagnosticOnly':True,'auditAuthorization':False,'threshold':4.5,'method':'Full reviewed support; source-color-near candidates (per-channel <=1), plus 2px-eroded ink interiors to retain top-wash variation, avoid deliberately using edge AA as foreground; these are core candidates, not native alpha/coverage proof; high-contrast strong-ink segmentation and a 2px exclusion band separate candidate backing. All support backing, not selected favorable pixels, supplies conservative observed extrema. Radius2-5 sensitivity retained. Segmentation is a measurement aid, not an independent glyph oracle or a proof of hidden backing.','limitations':['Only these three stable revealed layouts and available originals are assessed.','Finite sequential screenshots/hierarchies are not atomic callback proof.','A below-threshold support bound does not by itself prove background beneath glyphs is below threshold; inspect the candidate point.','No trait inference, original issue resolution, accessibility readiness or original offscreen contrast claim.','Full-glyph coverage needs human support/mask review; near-background AA is deliberately not counted as core. Candidate cores are not native alpha proof, and the 2px exclusion leaves immediate fringe/hidden backing unmeasured.'],'references':['https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html','https://www.w3.org/WAI/WCAG22/Techniques/general/G18'],'targets':result}
 (out/'measurements.json').write_text(json.dumps(report,indent=2)+'\n')
 print('\n'.join(f"{r['finding']:02d} {r['label']:7s} {r['extremes']['fullSupportBacking']['ratio']:.7f} {r['extremes']['fullSupportBacking']['background']}" for r in result))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--originals',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();run(a.originals,a.output)
