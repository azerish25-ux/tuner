from pathlib import Path
from PIL import Image
import hashlib,sys,json,math
sys.path.insert(0,'tools/ci')
from test_song_cover_contrast import contrast
P=Path('../native-qa/accessibility-970/screenshots')
files={'songs':'60402883-CEC8-4139-94ED-FFD1F416A642.png','practice':'9316BE55-DBCE-4930-825D-22E7DEDEE3EA.png','progress':'03949922-0D37-442D-AF3E-B0AF73803882.png','paywall':'2BFB9353-1B77-46AD-87F2-23EDA141413A.png'}
specs=[
('songs','Songs',(20,74,87.6667,35.3333),(245,243,239),18),
('songs','Play the melody…',(20,113.3333,254,38),(163,168,177),18),
('songs','When the',(290.0333,283.5040,64.6667,17.3333),(245,243,239),288),
('songs','Song of the day',(68.3333,267.3333,95.3333,15.3333),(245,243,239),67),
('songs','Play',(77.6667,467.8333,36,21.6667),(6,7,8),115),
('songs','D',(292,471,9.6667,15.3333),(255,255,255),291),
('songs','Your songs',(104,554.6667,96.3333,21.6667),(245,243,239),102),
('practice','LV (in LV5)',(50.3333,392.6667,37.3333,28),(76,242,184),49),
('progress','Tune up',(78,389,113,44),(255,181,71),76),
('progress','Last five weeks',(38,749.3333,131,21.6667),(245,243,239),36),
('progress','20 of35days',(286,754.3333,78,14.3333),(163,168,177),285),
('paywall','SAVE58%',(291.6667,417.6667,69.3333,15.3333),(6,7,8),290)
]
images={k:Image.open(P/v).convert('RGB') for k,v in files.items()};results=[]
for screen,label,(x,y,w,h),target,bgx in specs:
 im=images[screen];box=(math.floor(x*3),math.floor(y*3),math.ceil((x+w)*3),math.ceil((y+h)*3));choices=[]
 for py in range(box[1],box[3]):
  for px in range(box[0],box[2]):
   rgb=im.getpixel((px,py));d=sum((a-b)**2 for a,b in zip(rgb,target));choices.append((d,px,py,rgb))
 d,px,py,fg=min(choices);bxy=(round(bgx*3),py);bg=im.getpixel(bxy);ratio=contrast(fg,bg)
 results.append({'screen':screen,'label':label,'reported_frame_pt':[x,y,w,h],'core_selection':'closest actual pixel to the known source role colour inside this text-only frame; no edge-antialias min-ratio assertion','role_colour_target_rgb':target,'core_colour_squared_distance':d,'foreground_xy_px':[px,py],'foreground_rgb':fg,'background_xy_px':bxy,'background_rgb':bg,'local_core_contrast':ratio,'scope':'One exact pre-audit screenshot state/local pair, not every glyph pixel, background position or later SDK audit state.'})
 print(screen,label,'core',px,py,fg,'bg',bxy,bg,'ratio',round(ratio,4),'distance',d)
im=images['songs'];fg=im.getpixel((155,2104));bg=im.getpixel((145,2104));results.append({'screen':'songs','label':'03','reported_frame_pt':[44.02928,699.1,11,10.333333333333258],'core_selection':'Exact same predefined core/background coordinates as the earlier failed c5 receipt','foreground_xy_px':[155,2104],'foreground_rgb':fg,'background_xy_px':[145,2104],'background_rgb':bg,'local_core_contrast':contrast(fg,bg),'previous_c5_core_rgb':[78,88,104],'previous_c5_same_pair_contrast':3.1008981076,'scope':'Confirms improvement for this clear, light-field numbered sleeve only; not a pass for every cover/locked/faded state or a waiver of audit findings.'})
receipt={'source_sha':'970a12db87dd5751d3674b1321e20706a576e03e','run':40396032285,'published_results_sha':'103f9a120ef71d303319c7f8cca391bec2996ab9','images':{k:{'file':v,'sha256':hashlib.sha256((P/v).read_bytes()).hexdigest(),'size_px':list(images[k].size),'srgb_metadata':Image.open(P/v).info.get('srgb'),'scale':3} for k,v in files.items()},'measurements':results}
Path('docs/l10n/reviews/native-followup/accessibility/970-pixel-measurements.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
