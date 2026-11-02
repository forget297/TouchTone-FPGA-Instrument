"""Run self-checking HDL testbenches. Requires Icarus Verilog on PATH."""
import os
import subprocess
import shutil
import argparse
from pathlib import Path
from generate_tables import ROOT
from generate_extended import extended_tables as tables

def run(*args):
    if args[0]=='vvp' and os.name=='nt':
        args=(args[0],'-M','-',*args[1:]) # bypass broken Windows short-path discovery
    if args[0]=='iverilog' and os.environ.get('IVERILOG_BASE'):
        args=(args[0],'-B',os.environ['IVERILOG_BASE'],*args[1:])
    print('+', ' '.join(map(str,args)), flush=True)
    result=subprocess.run([shutil.which(args[0]) or args[0],*map(str,args[1:])],cwd=ROOT,
                          text=True,encoding='utf-8',errors='replace',capture_output=True,timeout=240)
    output=result.stdout+result.stderr
    print(output,end='',flush=True)
    if args[0]=='vvp':
        (ROOT/'build'/(Path(args[-1]).stem+'.log')).write_text(output,encoding='utf-8')
    result.check_returncode()

if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('tests',nargs='*',help='Optional testbench stems, e.g. tb_system')
    args=parser.parse_args()
    benches=sorted((ROOT/'sim').glob('tb_*.v'))
    unknown=set(args.tests)-{p.stem for p in benches}
    if unknown: parser.error('Unknown testbenches: '+', '.join(sorted(unknown)))
    (ROOT/'build').mkdir(exist_ok=True)
    for name,data in tables().items():
        assert (ROOT/'rtl/audio'/name).read_text()==data, f'Stale ROM: {name}'
    sources=sorted(p.relative_to(ROOT).as_posix() for p in (ROOT/'rtl').rglob('*.v'))
    sources+=['diagnostic/encoder_diagnostic.v']
    run('iverilog','-g2012','-Wall','-s','top','-o','build/top.vvp',*sources)
    passed=0
    for tb in benches:
        if args.tests and tb.stem not in args.tests: continue
        target='build/'+tb.stem+'.vvp'
        run('iverilog','-g2012','-s',tb.stem,'-o',target,*sources,'sim/sensor_model.v',tb.relative_to(ROOT).as_posix())
        run('vvp','-i',target)
        passed+=1
    print(f'{passed} HDL TESTS PASSED')
