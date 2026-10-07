#!/usr/bin/python3
"""Record per-workload resource usage without command lines or secrets."""
import json
import os
from pathlib import Path
import subprocess
import time

STATE = Path('/run/mainframe-health/previous.json')

def main():
    now=time.time()
    try: previous=json.loads(STATE.read_text())
    except (OSError, ValueError): previous={}
    elapsed=max(1, now-previous.get('time',now))
    tasks={}; ranked=[]
    for p in Path('/proc').glob('[0-9]*'):
        try:
            raw=(p/'stat').read_text(); fields=raw[raw.rfind(')')+2:].split()
            start=fields[19]; cpu=int(fields[11])+int(fields[12])
            rss=int(fields[21])*os.sysconf('SC_PAGE_SIZE')
            io=dict(line.split(': ') for line in (p/'io').read_text().splitlines())
            disk=int(io['read_bytes'])+int(io['write_bytes'])
            key=f'{p.name}:{start}'; old=previous.get('tasks',{}).get(key,[cpu,disk])
            tasks[key]=[cpu,disk]
            ranked.append(dict(pid=int(p.name),name=(p/'comm').read_text().strip(),rss_mib=round(rss/1048576,1),cpu_pct=round(max(0,cpu-old[0])/os.sysconf('SC_CLK_TCK')/elapsed*100,1),io_mib=round(max(0,disk-old[1])/1048576,1),group=(p/'cgroup').read_text().strip().split(':')[-1]))
        except (OSError,ValueError,IndexError): continue
    mem=dict((line.split(':')[0],int(line.split()[1])) for line in Path('/proc/meminfo').read_text().splitlines())
    report=dict(time=now,load=os.getloadavg(),available_mib=round(mem['MemAvailable']/1024),swap_used_mib=round((mem['SwapTotal']-mem['SwapFree'])/1024))
    for key in ['rss_mib','cpu_pct','io_mib']:
        report['top_'+key]=sorted(ranked,key=lambda row:row[key],reverse=True)[:3]
    for command in ['get_throttled','measure_temp']:
        try: report[command]=subprocess.check_output(['vcgencmd',command],text=True,timeout=2).strip()
        except (OSError,subprocess.SubprocessError): report[command]='unavailable'
    print(json.dumps(report,separators=(',',':')),flush=True)
    STATE.parent.mkdir(parents=True,exist_ok=True)
    temporary=STATE.with_suffix('.tmp')
    temporary.write_text(json.dumps(dict(time=now,tasks=tasks)))
    temporary.replace(STATE)

if __name__=='__main__': main()
