"""Dependency-free spectral check of HDL-generated samples, not a hardware claim."""
import cmath
import json
import math
import struct
import wave
from generate_tables import ROOT, FS

def fft(values):
    n=len(values)
    assert n and n & (n-1)==0
    a=[complex(v) for v in values]
    j=0
    for i in range(1,n):
        bit=n>>1
        while j & bit:
            j^=bit; bit>>=1
        j^=bit
        if i<j: a[i],a[j]=a[j],a[i]
    length=2
    while length<=n:
        root=cmath.exp(-2j*math.pi/length)
        for base in range(0,n,length):
            w=1
            for k in range(length//2):
                u=a[base+k]; v=w*a[base+k+length//2]
                a[base+k]=u+v; a[base+k+length//2]=u-v; w*=root
        length*=2
    return a

if __name__=='__main__':
    samples=[int(v) for v in (ROOT/'build/audio32_samples.txt').read_text().split()]
    n=len(samples)
    spectrum=fft([v*(.5-.5*math.cos(2*math.pi*i/(n-1))) for i,v in enumerate(samples)])
    magnitude=[abs(v)*4/n for v in spectrum[:n//2]]
    rows=[]
    for f in range(300,3401,100):
        k=round(f*n/FS)
        peak=max(range(k-2,k+3),key=lambda j:magnitude[j])
        noise=max(magnitude[k-10:k-6]+magnitude[k+7:k+11])
        snr=20*math.log10(magnitude[peak]/max(noise,1e-9))
        assert abs(peak*FS/n-f)<=FS/n, (f,'frequency')
        assert snr>25, (f,'missing distinct peak',snr)
        rows.append(dict(expected_hz=f,fft_hz=peak*FS/n,amplitude=magnitude[peak],local_margin_db=snr))
    assert max(abs(v) for v in samples)<32767, 'clipping'
    report=dict(evidence='RTL simulation, not physical recording',fs=FS,samples=n,
                oscillators=32,throughput=32*FS,peak=max(abs(v) for v in samples),tones=rows)
    out=ROOT/'reports'; out.mkdir(exist_ok=True)
    (out/'spectrum32.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    with wave.open(str(out/'test32_simulation.wav'),'wb') as wav:
        wav.setnchannels(1); wav.setsampwidth(2); wav.setframerate(FS)
        wav.writeframes(struct.pack('<'+'h'*n,*samples))
    # Code-generated SVG is a plot, not a raster illustration.
    points=[]
    for k,mag in enumerate(magnitude):
        f=k*FS/n
        if 100<=f<=3700:
            db=max(-80,20*math.log10(max(mag,1e-9)/32768))
            points.append(f'{50+(f-100)/3600*900:.2f},{30-db/80*320:.2f}')
    svg='<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="430" viewBox="0 0 1000 430">'
    svg+='<rect width="1000" height="430" fill="white"/><text x="50" y="20" font-size="16">RTL simulation: 32 independent tones, Fs=46875 Hz (not hardware)</text>'
    svg+='<path d="M50 30V350H950" fill="none" stroke="black"/>'
    svg+='<polyline fill="none" stroke="#1261a0" stroke-width="1" points="'+' '.join(points)+'"/>'
    for f in range(300,3401,100):
        x=50+(f-100)/3600*900
        svg+=f'<text x="{x}" y="370" font-size="9" transform="rotate(60 {x} 370)">{f}</text>'
    svg+='<text x="480" y="423" font-size="12">Frequency (Hz); vertical range 0 to -80 dBFS</text></svg>'
    (out/'spectrum32.svg').write_text(svg,encoding='utf-8')
    print(f'PASS spectrum: {len(rows)} distinct expected peaks; peak={report["peak"]}; no clipping')
