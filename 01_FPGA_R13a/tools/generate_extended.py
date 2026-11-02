"""Deterministic mathematical oscillators and event-only scores; no recordings."""
import math
from generate_tables import ROOT, FS, tables

def extended_tables():
    result = tables()
    result['notes32.hex'] = ''.join(f'{round(440*2**((60+i-69)/12)*2**32/FS):08x}\n' for i in range(32))
    result['test32.hex'] = ''.join(f'{round((300+100*i)*2**32/FS):08x}\n' for i in range(32))
    waves = []
    for weights in ([1], [1, .45, .22, .12], [1/n for n in range(1,9)], None):
        values = []
        for i in range(256):
            if weights is None:
                values.append(1-4*abs(i/256-.5))
            else:
                values.append(sum(w*math.sin(2*math.pi*i*(h+1)/256) for h,w in enumerate(weights)))
        scale=max(abs(v) for v in values)
        waves.extend(round(32767*v/scale) for v in values)
    result['instruments.hex']=''.join(f'{v & 65535:04x}\n' for v in waves)
    scores = [
        [0,0,7,7,9,9,(7,2),15,5,5,4,4,2,2,(0,2),15,
         7,7,5,5,4,4,(2,2),15,7,7,5,5,4,4,(2,2),15],
        [4,4,5,7,7,5,4,2,0,0,2,4,(4,2),2,(2,2),15,
         4,4,5,7,7,5,4,2,0,0,2,4,(2,2),0,(0,2),15],
        [0,2,4,5,7,9,11,9,7,5,4,2,(0,2),15,0,4,
         7,4,0,5,9,5,2,7,11,7,4,7,0,(0,2),15,15]]
    words=[]
    for score in scores:
        for entry in score:
            note,duration=entry if isinstance(entry,tuple) else (entry,1)
            words.append(duration*16+note)
        words.extend([0x1f]*32)
    result['songs.hex']=''.join(f'{v:02x}\n' for v in words)
    return result

if __name__=='__main__':
    for name,data in extended_tables().items():
        (ROOT/'rtl/audio'/name).write_text(data,encoding='ascii')
    print('Generated 32 note/test frequencies, four waveforms and three event-only scores.')
