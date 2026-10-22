#!/usr/bin/env python3
"""Re-extract anonymous joint enemy placements from hash-verified public clears.

No player identity/position is emitted. Resource positions can be stale; reject
wrong-radius helpers instead of using them to certify a placement family.
"""
import argparse, gzip, hashlib, json, math
from pathlib import Path

def point(r):
    return [round((r["x"]-10000)/100, 2), round((r["y"]-10000)/100, 2)]
def angle(p):
    return math.degrees(math.atan2(p[0], -p[1])) % 360

def audit(root):
    out = {"schema":1,"scope":"finite four-clear observations; not exhaustive server RNG or probabilities", "sources":[], "limitless":[], "sigma":[], "meteors":[], "delta":[], "hello_world":[]}
    for mf in sorted(root.glob("*/*/manifest.json")):
        m=json.loads(mf.read_text()); assert m.get("complete"), mf
        files={}
        for f in m["files"]:
            raw=gzip.decompress((mf.parent/f["file"]).read_bytes())
            assert hashlib.sha256(raw).hexdigest()==f["sha256"], f["file"]
            files[f["file"]]=json.loads(raw)
        out["sources"].append({"report":m["report"],"fight":m["fight"],"manifest_sha256":hashlib.sha256(mf.read_bytes()).hexdigest(),"verified_files":len(files)})
        events=sorted([e for seg in m["replay_segments"] for e in files[seg["file"]]["events"]],key=lambda e:e["timestamp"])
        phases=m["fight_metadata"]["phases"]
        def casts(phase, ids):
            start=phases[phase-1]["startTime"]; end=phases[phase]["startTime"] if phase<6 else m["fight_metadata"]["end_time"]
            return [(e["ability"]["guid"],(e["timestamp"]-start)/1000,point(e["sourceResources"])) for e in events if e["type"]=="cast" and start<=e["timestamp"]<end and e.get("ability",{}).get("guid") in ids and "x" in e.get("sourceResources",{})]
        ref={"report":m["report"],"fight":m["fight"]}
        lb=casts(2,[31540,31541,31539,32369,31537])
        def radial(aid, radius):
            hits=[p for a,t,p in lb if a==aid and abs(math.hypot(*p)-radius)<0.08]
            assert len(hits)==1,(ref,aid,hits)
            return hits[0]
        male=radial(31540,22); female=radial(31541,22)
        assert math.dist(male,[-female[0],-female[1]])<0.05
        arrow=radial(31539,22); shield=radial(32369,22); flare=radial(31537,22)
        npc_ids={e["id"] for e in files["metadata.json.gz"]["enemies"] if e["guid"]==15712}
        start2=phases[1]["startTime"]; boss_positions=[]
        for e in events:
            if not start2+87000<e["timestamp"]<start2+110000: continue
            for side in ["source","target"]:
                res=e.get(side+"Resources",{})
                if e.get(side+"ID") in npc_ids and "x" in res:
                    pos=point(res)
                    if pos not in boss_positions: boss_positions.append(pos)
        assert boss_positions and all(math.dist(p,[0,-10])<0.05 for p in boss_positions)
        out["limitless"].append(dict(ref,main_female=boss_positions[0],male=male,female=female,arrow=arrow,shield=shield,flare=flare,male_angle=round(angle(male)/45)*45%360,arrow_angle=round(angle(arrow)/30)*30%360,shield_angle=round(angle(shield)/30)*30%360,flare_angle=round(angle(flare)/30)*30%360))
        sigma=casts(5,[32559,31492,31493])
        male=[p for a,t,p in sigma if a==32559 and abs(math.hypot(*p)-20)<0.08]; assert len(male)==1
        towers=[{"pos":p,"count":1 if a==31492 else 2} for a,t,p in sigma if a in [31492,31493] and abs(math.hypot(*p)-17)<0.08]
        assert len(towers) in [5,6] and sum(t["count"] for t in towers)==8
        sx=-sum(t["pos"][0] for t in towers);sy=-sum(t["pos"][1] for t in towers)
        gap=angle([sx,sy]); ma=angle(male[0]);relative=(gap-ma)%360
        assert min(abs(relative),abs(relative-180),abs(relative-360))<0.2,(ref,relative)
        out["sigma"].append(dict(ref,male=male[0],towers=towers,gap_angle=round(gap,2),gap_relative_to_male=round(relative,2)))
        npc={e["id"]:e["guid"] for e in files["metadata.json.gz"]["enemies"]}; adds={}
        for e in events:
            for side in ["source","target"]:
                guid=npc.get(e.get(side+"ID")); res=e.get(side+"Resources",{})
                if guid in [15726,15727] and "x" in res:
                    adds.setdefault((guid,e.get(side+"Instance",1)),point(res))
        comets=[p for (guid,instance),p in adds.items() if guid==15727]; meteors=[p for (guid,instance),p in adds.items() if guid==15726]
        assert len(comets)==6 and len(meteors)==2
        out["meteors"].append(dict(ref,comets=sorted(comets),meteors=sorted(meteors)))
        delta=casts(5,[31521,31600,31636,31637]);eye=[p for a,t,p in delta if a==31521 and t<80];arms=[p for a,t,p in delta if a==31600 and t<80];beetle=[p for a,t,p in delta if a in [31636,31637] and t<80]
        assert len(eye)==1 and len(arms)==6 and len(beetle)==1
        out["delta"].append(dict(ref,eye=eye[0],arms=arms,beetle=beetle[0]))
        hw=casts(3,[31583,31584]); waves=[]
        for a,t,p in hw:
            if abs(math.hypot(*p)-14)>0.08: continue
            if not waves or t-waves[-1]["at"]>0.2:waves.append({"at":t,"towers":[]})
            waves[-1]["towers"].append({"pos":p,"ability":a})
        assert len(waves)==4 and all(len(w["towers"])==4 for w in waves)
        out["hello_world"].append(dict(ref,waves=waves))
    assert len(out["sources"])==4
    return out

def main():
    p=argparse.ArgumentParser(description=__doc__); p.add_argument("input",type=Path);p.add_argument("--output",type=Path,required=True);a=p.parse_args()
    result=audit(a.input);a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(result,indent=2)+"\n")
    print(json.dumps({"sources":len(result["sources"]),"verified_files":sum(s["verified_files"] for s in result["sources"]),"joint_lb_layouts":len(result["limitless"]),"sigma_correlated_patterns":len(result["sigma"]),"meteor_instances":sum(len(s["comets"])+len(s["meteors"]) for s in result["meteors"]),"hw_towers":sum(len(w["towers"]) for s in result["hello_world"] for w in s["waves"])}))
if __name__=="__main__":main()
