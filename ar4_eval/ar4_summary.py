"""Resume ar4_eval/logs/*.txt en tablas antes/despues. Uso: python ar4_summary.py"""
import re, glob, os, statistics as st, collections
here = os.path.dirname(os.path.abspath(__file__))
kv = re.compile(r'(\w+)=(\S+)')
def pct(xs, p):
    xs = sorted(xs); return xs[min(len(xs)-1, int(round(p*(len(xs)-1))))] if xs else float('nan')
def load():
    d = collections.defaultdict(lambda: collections.defaultdict(list))
    for f in sorted(glob.glob(os.path.join(here, 'logs', '*.txt'))):
        v, sc, r = os.path.basename(f)[:-4].split('_')
        for line in open(f, encoding='utf8', errors='ignore'):
            m = re.search(r'\[AR4\]\[(\w+)\] (before|after) (.*)', line)
            if not m: continue
            tag, _, rest = m.groups()
            d[(v, sc)][(r, tag)].append(dict(kv.findall(rest)))
    return d
def row(name, xs):
    if not xs: return f'| {name} | - | - | - | - |'
    return f'| {name} | {len(xs)} | {st.mean(xs):.1f} | {st.median(xs):.1f} | {pct(xs,.9):.1f} |'
d = load()
print('| Metric | n | mean | median | p90 |\n|---|---|---|---|---|')
for (v, sc) in sorted(d):
    runs = d[(v, sc)]
    lat = [float(e['latencyMs']) for (r, t), es in runs.items() if t == 'worker' for e in es]
    infl = [float(e['inflightAtSend']) for (r, t), es in runs.items() if t == 'worker' for e in es]
    srch = [float(e['totalMs']) for (r, t), es in runs.items() if t == 'search' for e in es]
    wait = [float(e['waitMs']) for (r, t), es in runs.items() if t == 'dl' for e in es if e.get('event') == 'slotWait']
    tot = [float(e['totalUs'])/1000 for (r, t), es in runs.items() if t == 'frame' for e in es]
    bld = [float(e['buildUs'])/1000 for (r, t), es in runs.items() if t == 'frame' for e in es]
    ras = [float(e['rasterUs'])/1000 for (r, t), es in runs.items() if t == 'frame' for e in es]
    print(f'| **{v} {sc}** | | | | |')
    print(row('worker latency (ms)', lat)); print(row('in-flight at send', infl))
    print(row('globalSearch total (ms)', srch)); print(row('download slot wait (ms)', wait))
    print(row('frame total (ms)', tot)); print(row('frame build (ms)', bld)); print(row('frame raster (ms)', ras))
    if tot: print(f'| slow frames >16.7 ms | {len(tot)} | {100*sum(x>16.7 for x in tot)/len(tot):.1f}% | | |')
