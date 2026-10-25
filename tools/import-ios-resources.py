"""Legacy: the one-time import of the Android app's catalogue, photos, fonts and translations (2026-10-22).

Running it now would overwrite catalog.json, photos.json, the photo imagesets, the fonts and every Localizable.strings
with the Android snapshot, discarding everything added since. It refuses to run unless TIMBRE_REIMPORT_ANDROID=1.
"""
import os
import sys
if os.environ.get("TIMBRE_REIMPORT_ANDROID") != "1":
    sys.exit("Legacy import: it would overwrite the catalogue, photos, fonts and translations. "
             "Set TIMBRE_REIMPORT_ANDROID=1 only if that is what you want (see docs/TOOLS.md).")
from pathlib import Path
import shutil,json,re,xml.etree.ElementTree as ET
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/'reference/android'
CORE=ROOT/'ios/Sources/TimbreCore/Resources'
APP=ROOT/'ios/Timbre/Resources'
CORE.mkdir(parents=True,exist_ok=True); APP.mkdir(parents=True,exist_ok=True)
document=json.loads((SRC/'data/instruments/src/main/assets/instruments/catalog.json').read_text(encoding='utf-8'))
for group,prefix in [('families','family'),('instruments','instrument'),('tunings','tuning')]:
    for row in document[group]:
        fallback=row['name'] if isinstance(row['name'],str) else row['name']['default']
        row['name']={'key':'timbre_catalog_'+prefix+'_'+row['id'].replace('.','_'),'default':fallback}
row=document['referenceMode']
fallback=row['name'] if isinstance(row['name'],str) else row['name']['default']
row['name']={'key':'timbre_catalog_reference_mode_'+row['id'].replace('.','_'),'default':fallback}
(CORE/'catalog.json').write_text(json.dumps(document,ensure_ascii=False,indent=2),encoding='utf-8')
photos=SRC/'data/assets/src/main/assets/photos'
index=json.loads((photos/'index.json').read_text(encoding='utf-8'))
assets=APP/'Assets.xcassets'; assets.mkdir(exist_ok=True)
(assets/'Contents.json').write_text(json.dumps({'info':{'author':'xcode','version':1}}))
for row in index:
    for key in ('asset','thumbnail'):
        source=SRC/'data/assets/src/main/assets'/row[key]
        name=source.stem
        folder=assets/(name+'.imageset'); folder.mkdir(exist_ok=True)
        Image.open(source).save(folder/(name+'.png'))
        (folder/'Contents.json').write_text(json.dumps({'images':[{'filename':name+'.png','idiom':'universal'}],'info':{'author':'xcode','version':1}},indent=2))
        row[key]=name
(CORE/'photos.json').write_text(json.dumps(index,ensure_ascii=False,indent=2),encoding='utf-8')
fonts=APP/'Fonts'; fonts.mkdir(exist_ok=True)
for font in (SRC/'core/designsystem/src/main/res/font').glob('*.ttf'): shutil.copyfile(font,fonts/font.name)
# Android module resources merge into one native localization table; localized values overlay English.
tables={}
for path in sorted(SRC.rglob('*.xml')):
    qualifier=path.parent.name
    if not qualifier.startswith('values') or 'res' not in path.parts: continue
    if qualifier=='values': locale='en'
    elif qualifier.startswith('values-b+'): locale=qualifier[9:].replace('+','-')
    else: continue
    locale={'iw':'he','in':'id'}.get(locale,locale)
    try: root=ET.parse(path).getroot()
    except ET.ParseError: continue
    for item in root.findall('string'):
        value=''.join(item.itertext()).replace("\\'", "'").replace('\\"','"')
        value=value.replace('\\n','\n').replace('\\t','\t').replace('\\r','\r')
        value=re.sub(r'%(\d+\$)?s',lambda m:'%'+(m[1] or '')+'@',value)
        tables.setdefault(locale,{})[item.attrib['name']]=value
for locale,table in tables.items():
    folder=APP/(locale+'.lproj'); folder.mkdir(exist_ok=True)
    merged={**tables.get('en',{}),**table}
    escape=lambda s:s.replace('\\','\\\\').replace('"','\\"').replace('\n','\\n').replace('\r','\\r')
    (folder/'Localizable.strings').write_text('\n'.join('"'+escape(k)+'" = "'+escape(v)+'";' for k,v in sorted(merged.items()))+'\n',encoding='utf-8')
print(f'Imported {len(index)} photos, {len(tables)} locales, 3 fonts.')
