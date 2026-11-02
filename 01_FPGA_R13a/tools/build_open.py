"""Optional reproducible OSS CAD Suite build, with classic ABC Windows fallback."""
import argparse
import shutil
import subprocess
from generate_tables import ROOT

def run(tool,*args):
    exe=shutil.which(tool) or tool
    subprocess.run([exe,*args],cwd=ROOT,check=True)

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--pnr',action='store_true')
    args=parser.parse_args()
    (ROOT/'build').mkdir(exist_ok=True)
    sources=' '.join(p.relative_to(ROOT).as_posix() for p in sorted((ROOT/'rtl').rglob('*.v')))
    script=f'read_verilog {sources}; synth_gowin -family gw2a -top top -run begin:map_ffs; '
    script+='dfflegalize -cell $_DFF_P_ 0 -cell $_DFFE_PP_ 0 -cell $_DFF_PP0_ r -cell $_DFFE_PP0P_ r; '
    script+='techmap -map +/gowin/cells_map.v; abc -lut 4; '
    script+='synth_gowin -family gw2a -top top -run map_cells: -json build/top.json'
    run('yosys','-ql','build/synthesis.log','-p',script)
    if args.pnr:
        run('nextpnr-himbaechel','--device','GW2AR-LV18QN88C8/I7',
            '--vopt','family=GW2A-18C','--vopt','cst=constraints/tang_nano_20k.cst',
            '--json','build/top.json','--write','build/routed.json','--freq','27',
            '--report','build/timing.json','--log','build/pnr.log')
