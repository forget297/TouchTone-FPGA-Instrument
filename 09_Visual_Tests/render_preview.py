from pathlib import Path
from PIL import Image,ImageDraw
r=Path('.')
for v in range(4):
 im=Image.new('RGB',(800,480));d=ImageDraw.Draw(im)
 for line in (r/f'view{v}.commands').read_text().splitlines():
  cmd,args=line.split(' ',1);a=list(map(int,args.split(',')))
  col=a[-1];rgb=((col>>11)*255//31,((col>>5)&63)*255//63,(col&31)*255//31)
  x,y,u,w=a[:4]
  if cmd=='fill':d.rectangle((x,y,x+u-1,y+w-1),fill=rgb)
  elif cmd=='line':d.line((x,y,u,w),fill=rgb)
 im.save(r/f'preview_view{v}.png')
print('Rendered four command-stream previews (simulation data, not hardware photos)')
