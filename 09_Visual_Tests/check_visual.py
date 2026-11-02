from pathlib import Path
import struct,binascii,math
r=Path(__file__).resolve().parents[1]/'01_FPGA_R13a'
b=bytes(int(x,16) for x in (Path(__file__).resolve().parent/'visual_packets.hex').read_text().split())
frames=[]
for seq in range(2):
 f=bytearray()
 for i in range(23):
  p=b[(seq*23+i)*42:(seq*23+i+1)*42]
  assert p[:4]==bytes([168,1,seq,1]) and int.from_bytes(p[4:6],'little')==i*32 and p[6]==32 and p[-1]==90
  assert binascii.crc_hqx(p[:39],65535)==int.from_bytes(p[39:41],'little')
  f+=p[7:39]
 frames.append(f)
f=frames[0];spec=struct.unpack('<128H',f[288:544]);print('bins6,17',spec[6],spec[17]);assert abs(spec[6]-12000)<20 and abs(spec[17]-4000)<20
assert max(spec[i] for i in range(128) if i not in [5,6,7,16,17,18])<10
for n in range(32):
 fcw,peak=struct.unpack_from('<IH',f,544+n*6);assert fcw==(n//8+1)*100000000 and peak==(n//8+1)*1000
for i in range(64):
 # X uses every second waveform point; Y equals X four waveform samples later when available
 assert f[160+2*i]==f[32+2*i]
 if 2*i+4<128:assert f[161+2*i]==f[32+2*i+4]
assert max(struct.unpack('<128H',frames[1][288:544]))==0
assert set(frames[1][32:288])=={128}
print('PASS CRC46 packets, spectral dual tones/Hann sidelobes, silence, XY alignment, all32 telemetry')
for n in [0,31]:print('note',n,int((r/'rtl/audio/notes32.hex').read_text().split()[n],16)*46875/2**32)
