#!/usr/bin/env python3
"""Independent exhaustive-event oracle for finite delayed nested emitters."""
import json,random,sys

def node(values=None,life=5):
 return dict(values=values or {},life=dict(enabled=True,Val=life,ValR=0,Type=0),items=[],axes={},curves={},data={})
def constant(v):return dict(kind='scalar',BvPr=0,BvPo=0,keys=[dict(time=0,type=1,data=[1,1,v])])
def build():
 rng=random.Random(50512);result=[]
 for case in range(300):
  stop=rng.randint(5,35);rl=rng.randint(1,25);cl=rng.randint(1,30);pl=rng.randint(5,45)
  ri,ci=rng.randint(1,12),rng.randint(1,12);rf,cf=rng.randint(1,10),rng.randint(1,10)
  rd,cd=rng.randint(0,9),rng.randint(0,9);rc,cc=rng.randint(1,4),rng.randint(1,4)
  rper,cper=rng.choice([False,True]),rng.choice([False,True]);initial=rng.randint(-3,2)
  r=node({'EVT':0},rl);c=node({'EVT':0},cl);p=node({'PrVT':1},pl)
  r['curves']['CrI']=constant(ri);c['curves']['CrI']=constant(ci)
  r['items']=[dict(role='child_emitter',source_index=0,values=dict(bEnb=True,TgtB=1,CrTm=rf,CrCn=rc,CrPr=100,GenD=rd,bGD=rper))]
  c['items']=[dict(role='child_particle',source_index=0,values=dict(bEnb=True,TgtB=0,CrTm=cf,CrCn=cc,CrPr=100,GenD=cd,bGD=cper,StFr=initial))]
  doc=dict(schema=1,groups=dict(Schd=[dict(index=0,items=[dict(role='scheduled_timeline',source_index=0,values=dict(bEna=True,TlNo=0))])],TmLn=[dict(values={},items=[dict(source_index=0,values=dict(bEna=True,EmNo=0,StTm=0,EdTm=stop))])],Emit=[r,c],Ptcl=[p]))
  # Enumerate real births, rather than propagate maxima as the analyzer does.
  deaths=[]
  for gen in range(rf-1,min(stop,rl)+1,ri):
   for number in range(rc):
    birth=gen+rd*(number if rper else 1)
    for childgen in range(cf-1,min(stop-birth,cl)+1,ci):
     for childnum in range(cc):
      pbirth=birth+childgen+cd*(childnum if cper else 1)
      deaths.append(pbirth+pl-initial)
  result.append(dict(case=case,document=doc,exact_death=max(deaths,default=0),birth_count=len(deaths)))
 return result
if __name__=='__main__':
 from pathlib import Path
 Path(sys.argv[1]).write_text(json.dumps(build()))
