"""Generate mathematical single-period ROM and exact-clock C4..B4 DDS words."""
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FS = 46875

def tables():
    sine = ''.join(f'{round(32767*math.sin(2*math.pi*i/256)) & 0xffff:04x}\n' for i in range(256))
    fcw = ''.join(f'{round(440*2**((60+i-69)/12)*2**32/FS):08x}\n' for i in range(12))
    return {'sine.hex': sine, 'fcw.hex': fcw}

if __name__ == '__main__':
    for name, data in tables().items():
        (ROOT/'rtl'/'audio'/name).write_text(data, encoding='ascii')
    print('Generated sine.hex, fcw.hex; Fs=46875 Hz')
