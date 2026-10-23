# SPDX-License-Identifier: MIT
extends RefCounted
## STANDALONE CN training-family sampler; not a server-frequency/full RNG claim.
static func generate(ctx, stacks:Array, override:Dictionary={}) -> Dictionary:
	var family:int
	if override.has("family"):family=int(override.family)
	elif ctx.profile.has("omega_training_family"):family=int(ctx.profile.omega_training_family)
	else:family=ctx.rng.randi_range(0,2)
	assert(family in [0,1,2])
	var first:Array=override.get("first",[ctx.at(4),ctx.at(5)]).duplicate()
	# Limitation: World I remains the actual one-stack pair; arbitrary I1 joint RNG is not modeled.
	var twos:Array=[];var ones:Array=[]
	for actor in 8:
		if int(stacks[actor])==2:twos.append(actor)
		elif actor not in first:ones.append(actor)
	shuffle(twos,ctx.rng);shuffle(ones,ctx.rng)
	var second:Array=override.get("second",[]).duplicate()
	if second.is_empty():
		if family==0:second=[ones[0],ones[1]]
		elif family==1:second=[twos[0],ones[0]]
		else:second=[twos[0],twos[1]]
	validate(stacks,first,second,family)
	var initial:Array=stacks.map(func(x):return int(x))
	var signature:="%d-%s-%s-%s"%[family,"_".join(initial.map(func(x):return str(x))),"_".join(first.map(func(x):return str(x))),"_".join(second.map(func(x):return str(x)))]
	return {"id":"cn-omega-training-"+signature,"family":family,"initial_stacks":initial,"first":first.map(func(x):return int(x)),"second":second.map(func(x):return int(x)),"mandatory_holders":second.filter(func(a):return int(stacks[int(a)])==2),"sampler":"standalone_cn_training_family_v1","server_frequency_claim":false,"limitation":"World I remains the actual one-stack pair; arbitrary I1 joint RNG is not modeled."}
static func shuffle(values:Array,rng:RandomNumberGenerator)->void:
	for i in range(values.size()-1,0,-1):
		var j:=rng.randi_range(0,i);var tmp=values[i];values[i]=values[j];values[j]=tmp
static func validate(stacks:Array,first:Array,second:Array,family:int)->void:
	assert(stacks.size()==8 and stacks.count(2)==4 and stacks.count(1)==4)
	assert(first.size()==2 and second.size()==2 and first[0]!=first[1] and second[0]!=second[1])
	assert(first.all(func(a):return int(a)>=0 and int(a)<8 and int(stacks[int(a)])==1))
	assert(second.all(func(a):return int(a)>=0 and int(a)<8 and a not in first))
	assert(second.filter(func(a):return int(stacks[int(a)])==2).size()==family)
