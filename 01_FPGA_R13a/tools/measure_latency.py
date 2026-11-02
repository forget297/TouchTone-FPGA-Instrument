"""Summarize measured paired timestamps. No fabricated measurements.
CSV columns: trial,action_s,audio_s. Timestamps must share one calibrated timebase.
"""
import argparse
import csv
import json
import statistics
from pathlib import Path

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('csv',type=Path)
    p.add_argument('--origin',required=True,choices=['physical','irq','fpga_gate'])
    p.add_argument('--endpoint',required=True,choices=['analog_audio','i2s'])
    args=p.parse_args()
    rows=list(csv.DictReader(args.csv.open(encoding='utf-8-sig')))
    values=[(float(r['audio_s'])-float(r['action_s']))*1000 for r in rows]
    if not values or any(v<0 for v in values): raise SystemExit('Empty data or reversed timestamps')
    end_to_end=args.origin=='physical' and args.endpoint=='analog_audio'
    result=dict(trials=len(values),origin=args.origin,endpoint=args.endpoint,
        min_ms=min(values),mean_ms=statistics.mean(values),max_ms=max(values),
        peak_to_peak_ms=max(values)-min(values),full_path=end_to_end,
        at_least_100_trials=len(values)>=100,
        observed_max_le_10ms=max(values)<=10,observed_max_le_5ms=max(values)<=5,
        note='Observed measurements only; no proof of zero jitter or future worst-case bound.')
    print(json.dumps(result,ensure_ascii=False,indent=2))
