extends SceneTree
## Prevent lab capacity changes from disabling bounds or changing ordinary previews.
const Ordinary=preload("res://scripts/avfx_player.gd")
const Source=preload("res://scripts/source_avfx_player.gd")
const Lab=preload("res://scripts/asset_lab_effect.gd")
func _initialize():
 var rows:Array=[]
 for player in [Ordinary.new(),Source.new(),Lab.new()]:
  var lab:bool=player is Lab
  assert(player._work_limit()==(128000 if lab else 16000))
  assert(player._particle_limit()==(4096 if lab else 2048))
  player.work=player._work_limit()-1
  assert(player._tick() and not player.diagnostics.has("budget_exceeded"))
  assert(not player._tick() and player.diagnostics.has("budget_exceeded"))
  rows.append({"work_limit":player._work_limit(),"particle_limit":player._particle_limit(),"overflow_rejected":true})
  player.free()
 print("TOP_CAPACITY_LIMITS_PASS ",JSON.stringify(rows));quit()
