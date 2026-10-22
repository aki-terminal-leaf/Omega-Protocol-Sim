# SPDX-License-Identifier: MIT
extends RefCounted
static var observations:Dictionary={}
static func validate(app)->Dictionary:
	if observations.is_empty():observations=JSON.parse_string(FileAccess.get_file_as_string("res://data/practice_timing_observations.json")).mechanics
	var id:String=app.encounter.id;var checks:=0;var failures:Array=[]
	if not observations.has(id):return {"checks":0,"failures":["no source observation "+id]}
	var ranges:Dictionary=observations[id].ranges
	for rule in app.encounter.clock.checks:
		var wanted:Array=ranges.get(rule.event,[])
		if wanted.is_empty():failures.append("unavailable source event "+str(rule.event));continue
		var times:Array=[]
		for event in app.state.get("timeline",[]):
			if str(event.kind)!=str(rule.kind):continue
			var detail:Dictionary=event.get("details",event)
			if not str(rule.title).is_empty() and not str(detail.get("title","")).contains(str(rule.title)):continue
			if not str(rule.shape).is_empty():
				if event.kind=="snapshot":
					var index:=-1
					for j in app.journal.size():
						if app.journal[j].title==detail.get("title",""):index=int(app.journal[j].beat)
					if index<0 or not app.encounter.beats[index].shapes.any(func(s):return str(s.get("name","")).contains(str(rule.shape))):continue
				elif not str(detail.get("shape",{}).get("name","")).contains(str(rule.shape)):continue
			var at:=float(event.time)
			if times.is_empty() or absf(at-float(times[-1]))>0.01:times.append(at)
		var limit:=int(rule.limit)
		if limit>0:times=times.slice(0,limit);wanted=wanted.slice(0,limit)
		checks+=1
		if times.size()!=wanted.size():failures.append("%s/%s event count %d != observed%d: %s"%[id,rule.event,times.size(),wanted.size(),str(times)]);continue
		for i in times.size():
			checks+=1
			if float(times[i])<float(wanted[i].min)-float(rule.tolerance) or float(times[i])>float(wanted[i].max)+float(rule.tolerance):failures.append("%s/%s[%d] actual%.4f outside source[%.4f,%.4f]+/-%.3f"%[id,rule.event,i,float(times[i]),float(wanted[i].min),float(wanted[i].max),float(rule.tolerance)])
	return {"checks":checks,"failures":failures}
