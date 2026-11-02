"""Collect reproducible evidence and package deliverables, excluding build scratch."""
import hashlib
import json
import shutil
import zipfile
from generate_tables import ROOT

if __name__=='__main__':
    reports=ROOT/'reports'; reports.mkdir(exist_ok=True)
    for name in ['synthesis.log','pnr.log','timing.json','digital_latency.csv','poll_latency.csv']:
        source=ROOT/'build'/name
        if source.exists(): shutil.copy2(source,reports/name)
    for source in (ROOT/'build').glob('tb_*.log'): shutil.copy2(source,reports/source.name)
    source_hashes={str(p.relative_to(ROOT)).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest()
                   for folder in ['rtl','constraints','diagnostic'] for p in sorted((ROOT/folder).rglob('*'))
                   if p.is_file() and 'impl' not in p.relative_to(ROOT).parts}
    firmware=ROOT/'firmware/fpga_instrument_r4.fs'
    if firmware.exists():
        newest=max((ROOT/name).stat().st_mtime for name in source_hashes if not name.startswith('diagnostic/'))
        if newest>firmware.stat().st_mtime:
            raise SystemExit('RTL/ROM/constraints newer than firmware. Rebuild in Gowin and refresh the firmware copy before packaging.')
    manifest={'sha256_sources':source_hashes,
              'firmware':firmware.relative_to(ROOT).as_posix() if firmware.exists() else None,
              'firmware_sha256':hashlib.sha256(firmware.read_bytes()).hexdigest() if firmware.exists() else None,
              'firmware_compiler':'Gowin V1.9.11.03 Education; GW2AR-LV18QN88C8/I7; SSPI GPIO',
              'board':'Tang Nano 20K / GW2AR-LV18QN88C8/I7','adc':'ADS1015',
              'hardware_tested':False}
    diagnostic=ROOT/'firmware/encoder_diagnostic_a77_b41.fs'
    if diagnostic.exists():
        manifest['diagnostic_firmware_sha256']=hashlib.sha256(diagnostic.read_bytes()).hexdigest()
    manifest['revision']='R4 echo fix: nonoverlapping RAM read/capture/write/publish; pluck2x triangle4x; sine/organ unchanged; hardware pending'
    (reports/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    archive=ROOT.parent/(ROOT.name+'.zip')
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
        for p in sorted(ROOT.rglob('*')):
            if p.is_file() and not any(x in p.relative_to(ROOT).parts for x in ['build','impl','__pycache__']):
                z.write(p,ROOT.name+'/'+p.relative_to(ROOT).as_posix())
    print(archive)
