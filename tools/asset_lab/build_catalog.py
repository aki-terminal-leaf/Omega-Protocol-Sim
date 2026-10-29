#!/usr/bin/env python3
"""Build the 96-unit Godot asset lab from a supplied GLB/PNG/compiled-AVFX cache."""
import argparse,csv,hashlib,json,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def read(p): return json.loads(p.read_text(encoding="utf-8-sig"))
def build(data,inventory):
 m,f,w=[read(data/(n+".json")) for n in ("manifest","full-data","weapon-data")]
 packs={p:(i,read(data/m["native_assets"][i]["file"])) for p,i in f["packs"].items()}
 for path,pack in w["packs"].items():packs[path]=("weapon_"+hashlib.sha256(path.encode()).hexdigest()[:20],pack)
 tids=dict(f["textures"],**w["textures"])
 record,plan=[read(data/(n+".json")) for n in ("record","motion-plan")]
 owners={}
 for event in record["events"]:
  if event.get("type")!="cast":continue
  actor=plan["actors"].get(event.get("s"))
  if not actor:continue
  motion=next((x for x in reversed(actor["motions"]) if x["start"]<=event["t"]),None)
  form=motion["form"] if motion else actor["form"]
  owners.setdefault((int(event["a"]),int(event["phase"])),set()).add(form)
 cat={"schema":1,"engine":"Godot 4.7.2","scope":"isolated original-resource samples, NOT completed composite encounter choreography","source_equivalence":False,"units":[],"assets":{},"textures":{},"packs":{}}
 rows=list(csv.DictReader(inventory.open(encoding="utf-8-sig")));assert len(rows)==96
 for row in rows:
  ph=row["階段"];num=row["演出單元"].split()[0]
  uid=ph.replace("Δ","Delta").replace("Σ","Sigma").replace("Ω","Omega")+"-"+num
  ids=[int(s) for s in row["相關Action線索"].split(";") if s.isdigit()]
  cinema=ph=="P6" and num in ("01a","01b","01c","21","22","23")
  forms={"P1":["beetle"],"P2":["male","female","optical"],"P3":["final","arm_left","arm_right"],"P4":["final"],"P6":["alpha"]}.get(ph,["male_p5","female_p5","beetle","final","arm_left","arm_right","fist_b5","fist_b6","rear_unit","optical"])
  u={"id":uid,"phase":ph,"title":row["演出單元"],"actions":ids,"requirements":row["物件_材質_動畫_特效需求"],"lifecycle":row["動作_生命週期"],"reference_video_seconds":row["影片附近秒數_非精確時間"],"reference_is_same_fight":False,"samples":[],"complete":False,"limitations":["Original shader / host-stop / audiovisual fidelity not certified.","Isolated source samples, not a completed composite performance."]}
  seen=set()
  def model(form,clip,label,stance="NEUTRAL",duration=6,source=""):
   if form not in m["native_assets"] or (form,clip) in seen:return
   seen.add((form,clip));cat["assets"][form]=m["native_assets"][form]
   u["samples"].append({"kind":"model","asset":form,"clip":clip,"label":label,"scale":m["scales"].get(form,1),"stance":stance,"duration":max(.1,duration),"source":source,"space":"model" if clip.startswith("action_") else "local"})
  def effect(path,label,offset=0):
   if path not in packs or path in seen:return
   seen.add(path);key,pack=packs[path];cat["packs"][key]={"file":"packs/"+key+".json","source":path,"sha256":pack["source_sha256"]}
   for tex in pack.get("textures",[]):
    tp=tex if isinstance(tex,str) else tex.get("path","")
    if tp in tids:
     tid=tids[tp];cat["textures"][tp]=m["native_assets"][tid]["file"];cat["assets"][tid]=m["native_assets"][tid]
   u["samples"].append({"kind":"effect","asset":key,"label":label,"duration":6,"source":path,"source_node_offset_frames":offset,"endpoint_demo":path.startswith("vfx/channeling/"),"seed":1,"lifecycle_basis":"0-180 native frames isolated preview; original scene/host stop unresolved"})
  if cinema:
   u["status"]="source_missing_cinematic";u["limitations"].append("Verified cinematic scene/camera/Alpha-chocobo sources missing. No battle idle/white-flash substitute.")
  else:
   for aid in ids:
    a=m["action_rows"].get(str(aid),{})
    valid_forms=set(owners.get((aid,int(ph[1])),set()))
    # Four independently verified original weapon TMBs also cover the unseen branch.
    if aid in (31525,31526):valid_forms={"male_p5" if ph.startswith("P5") else "male"}
    if aid in (31530,31533):valid_forms={"female_p5" if ph.startswith("P5") else "female"}
    for form in forms:
     if form not in valid_forms:continue
     base={"male_p5":"male","female_p5":"female"}.get(form,form)
     binds=m["action_animation_bindings"].get(form,m["action_animation_bindings"].get(base,{}));b=binds.get(str(a.get("end")))
     if b:
      if aid in (31525,31526,31530,31533):
       expected={31525:"chara/action/mon_sp/m0513/mon_sp021.tmb",31526:"chara/action/mon_sp/m0513/mon_sp015.tmb",31530:"chara/action/mon_sp/m0514/mon_sp006.tmb",31533:"chara/action/mon_sp/m0514/mon_sp005.tmb"}[aid]
       assert b["tmb_path"]==w["actions"][str(aid)]["tmb"]==expected,"Weapon family/TMB mismatch"
      stance="SHIELD" if aid==31525 else "LEGS" if aid in (31530,31531,31532) else "SWORD" if base=="male" else "STAFF" if base=="female" else "NEUTRAL"
      model(form,b["clip"],f"{aid} {a.get('name','')} / {form}",stance,b["duration_s"],b["tmb_path"])
    for c in f["cues"]:
     if c.get("ability")==aid and int(c.get("phase",0))==int(ph[1]):effect(c["path"],f"{aid} / {Path(c['path']).stem}",c.get("node",{}).get("time",0))
    for node in w["actions"].get(str(aid),{}).get("nodes",[]):effect(node["path"],f"{aid} / {Path(node['path']).stem}",node.get("time",0))
   title=row["演出單元"]
   apparatus=[]
   if ph=="P1" and num=="01":apparatus=["beetle"]
   if ph=="P5-Δ" and num=="03":apparatus=["beetle","final","fist_b5","fist_b6"]
   if ph=="P5-Δ" and num=="04":apparatus=["arm_left","arm_right","optical"]
   if ph=="P5-Δ" and num=="08":apparatus=["beetle"]
   if ph=="P2" and num in ("03","07","15"):apparatus=["optical"]
   if ph=="P3" and num in ("03","04"):apparatus=["arm_left","arm_right"]
   if ph=="P5-Σ" and num in ("05","06"):apparatus=["female_p5","arm_left","arm_right","rear_unit"]
   for form in apparatus:model(form,"",form+" / original geometry-material inspection ONLY",source="original GLB geometry/material; requested motion/lifecycle still open")
   if ph=="P1" and ("塔" in u["requirements"] or "塔" in title):
    effect("bg/ex2/05_zon_z3/common/vfx/eff/b2726pil01_f1.avfx","P1 Tower2 / original layered source")
    effect("vfx/channeling/eff/chn_teke02x.avfx","Blaster / two moving demonstration endpoints")
   if ph=="P2" and "配對" in title:effect("vfx/channeling/eff/chn_m0771_1c.avfx","Party Synergy / original tether")
   if ph=="P3" and any(x in title for x in ("輪","配毒")):
    for name in ("chn_m0771_alpha0c","chn_m0771_beta0c","chn_alpha0h","chn_beta0h"):effect("vfx/channeling/eff/"+name+".avfx",name+" / original tether state")
   if ph=="P5-Σ" and ("塔" in title or "塔" in u["requirements"]):effect("bg/ex2/05_zon_z3/common/vfx/eff/b2727pil02_f1.avfx","Sigma Tower3 / capacity state semantics unresolved")
   if not u["samples"]:
    model(forms[0],"cbbm_id0","Model/material inspection ONLY - requested performance missing");u["status"]="inspection_only";u["limitations"].append("No source-linked action/effect; static inspection is not recreation.")
   else:u["status"]="source_samples_partial" if any(x["kind"]=="effect" or x.get("clip") for x in u["samples"]) else "inspection_only"
   if any(x in u["requirements"] for x in ("LB","圖示","頭標","倒數")):u["limitations"].append("Player LB / UI status / headmark components not implemented.")
  cat["units"].append(u)
 return cat,packs
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument("--data",type=Path,required=True);ap.add_argument("--out",type=Path,required=True);ap.add_argument("--catalog",type=Path,default=ROOT/"top/data/asset_lab/catalog.json");args=ap.parse_args()
 if args.out.exists():raise SystemExit("Refusing to overwrite previous data/evidence")
 cat,packs=build(args.data,ROOT/"top/data/asset_lab/inventory.csv");args.out.mkdir(parents=True);(args.out/"packs").mkdir();proof={}
 for spec in cat["assets"].values():
  src,dst=args.data/spec["file"],args.out/spec["file"];dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst);proof[spec["file"]]=hashlib.sha256(dst.read_bytes()).hexdigest()
 for key,spec in cat["packs"].items():
  path=args.out/spec["file"];path.write_text(json.dumps(packs[spec["source"]][1],separators=(",",":")));proof[spec["file"]]=hashlib.sha256(path.read_bytes()).hexdigest()
 (args.out/"leg-motion.json").write_text(json.dumps(read(args.data/"weapon-data.json")["legClip"]))
 args.catalog.parent.mkdir(parents=True,exist_ok=True);args.catalog.write_text(json.dumps(cat,ensure_ascii=False,indent=2)+"\n",encoding="utf-8");shutil.copyfile(args.catalog,args.out/"catalog.json");(args.out/"hashes.json").write_text(json.dumps(proof,indent=2))
 print(json.dumps({"units":len(cat["units"]),"samples":sum(len(u["samples"]) for u in cat["units"]),"status":{s:sum(u["status"]==s for u in cat["units"]) for s in {u["status"] for u in cat["units"]}},"assets":len(proof),"complete":False}))
if __name__=="__main__":main()

