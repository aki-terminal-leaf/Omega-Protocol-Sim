extends SceneTree
const E=preload("res://scripts/encounters.gd")
const Runtime=preload("res://scripts/p5_omega_runtime.gd")
var cases:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var profiles:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/strategies.json"))
	for p in profiles:
		var priority:Array=[]
		for role in p.priority:priority.append(E.ROLES.find(role))
		for mask in 256:
			var stacks:Array=[]
			for actor in 8:stacks.append(2 if mask&(1<<actor) else 1)
			if stacks.count(2)!=4:continue
			for a in 7:
				for b in range(a+1,8):
					for c in 7:
						if c in [a,b]:continue
						for d in range(c+1,8):
							if d in [a,b]:continue
							cases+=1
							var config:Dictionary={"first":[a,b],"second":[c,d],"priority":priority}
							var first:=Runtime.choose(config,stacks,false)
							if first.size()!=8 or first.count(first[6])!=1 or first.count(first[7])!=1 or stacks[first[6]]!=2 or stacks[first[7]]!=2:failures+=1;continue
							var actual:Array=stacks.duplicate()
							for actor in first.slice(0,6):actual[int(actor)]+=1
							if actual.count(3)!=2 or actual[c]!=2 or actual[d]!=2:failures+=1;continue
							var second:=Runtime.choose(config,actual,true)
							if second.size()!=8:failures+=1;continue
							for actor in second.slice(0,6):actual[int(actor)]+=1
							if actual!=[3,3,3,3,3,3,3,3]:failures+=1
	print("OMEGA ALLOCATIONS cases=",cases," failures=",failures)
	quit(1 if failures else 0)
