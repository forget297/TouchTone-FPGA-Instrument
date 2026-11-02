"""Analyze HDL sample capture or 16-bit mono/stereo WAV, with actual sample rate."""
import argparse
import json
import wave
from pathlib import Path
import numpy as np

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('input',nargs='?',default='build/audio_samples.txt')
    parser.add_argument('--fs',type=int,default=46875)
    parser.add_argument('--output',default='build/spectrum.json')
    parser.add_argument('--wav',default=None)
    parser.add_argument('--plot',default=None)
    args=parser.parse_args()
    path=Path(args.input)
    if path.suffix.lower()=='.wav':
        with wave.open(str(path),'rb') as f:
            if f.getsampwidth()!=2: raise ValueError('Only signed PCM16 WAV supported')
            fs=f.getframerate(); channels=f.getnchannels()
            data=np.frombuffer(f.readframes(f.getnframes()),dtype='<i2').reshape(-1,channels).mean(axis=1)
    else:
        fs=args.fs; data=np.loadtxt(path)
    if args.wav:
        with wave.open(args.wav,'wb') as f:
            f.setnchannels(1); f.setsampwidth(2); f.setframerate(fs)
            f.writeframes(np.clip(data,-32768,32767).astype('<i2').tobytes())
    steady=data[min(int(fs*.08),len(data)//4):]
    n=2**int(np.ceil(np.log2(len(steady))))
    spectrum=abs(np.fft.rfft((steady-steady.mean())*np.hanning(len(steady)),n))
    freq=np.fft.rfftfreq(n,1/fs)
    peaks=[]
    for target in range(300,1401,100):
        mask=np.where(abs(freq-target)<12)[0]
        k=int(mask[np.argmax(spectrum[mask])])
        db=20*np.log10(max(float(spectrum[k]),1e-12)/max(float(spectrum.max()),1e-12))
        peaks.append({'expected_hz':target,'observed_hz':round(float(freq[k]),3),'relative_db':round(db,2)})
    passed=all(abs(p['expected_hz']-p['observed_hz'])<3 and p['relative_db']>-6 for p in peaks)
    report={'fs_hz':fs,'samples':len(data),'peak_pcm':int(abs(data).max()),
            'clipped_samples':int(np.count_nonzero(abs(data)>=32767)),
            'test_mode_12_peaks_pass':passed,'peaks':peaks,
            'note':'HDL sample capture is simulation evidence, not analog hardware measurement.'}
    Path(args.output).write_text(json.dumps(report,indent=2),encoding='utf-8')
    if args.plot:
        import matplotlib
        matplotlib.use('Agg')
        import matplotlib.pyplot as plt
        fig,ax=plt.subplots(figsize=(10,4),layout='constrained')
        ax.plot(freq,20*np.log10(np.maximum(spectrum,1e-12)/spectrum.max()),lw=1)
        for p in peaks:
            ax.plot(p['observed_hz'],p['relative_db'],'o',ms=3)
            ax.annotate(str(p['expected_hz']),(p['observed_hz'],p['relative_db']),
                        xytext=(0,6),textcoords='offset points',ha='center',fontsize=8)
        ax.set(xlim=(200,1500),ylim=(-90,10),xlabel='Frequency (Hz)',ylabel='Relative level (dB)',
               title='12 independent voices - HDL simulation, Fs = 46,875 Hz')
        ax.grid(alpha=.2)
        fig.savefig(args.plot,dpi=150)
    print(json.dumps(report,indent=2))
    if not passed: raise SystemExit('Expected twelve test-mode spectral peaks missing')

if __name__=='__main__': main()
