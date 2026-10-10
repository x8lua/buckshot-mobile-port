extends SceneTree
var failures = []
var backup: PackedByteArray
var existed = false
func _initialize(): run.call_deferred()
func check(value, label):
 print("CHECK ",label," ","PASS" if value else "FAIL")
 if not value: failures.append(label)
func run():
 await process_frame
 root.size = Vector2i(1920,1080)
 root.content_scale_size = Vector2i(960,540)
 root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
 var mobile = root.get_node("MobileRuntime")
 existed = FileAccess.file_exists(mobile.CHECKPOINT_PATH)
 if existed: backup = FileAccess.get_file_as_bytes(mobile.CHECKPOINT_PATH)
 var sequence: Array[String] = ["live", "blank", "live"]
 var known: Array[bool] = [false, false, false]
 var file = FileAccess.open(mobile.CHECKPOINT_PATH,FileAccess.WRITE)
 file.store_var({"version":1,"endless":false,"current_batch_index":1,"current_round":1,"health_player":3,"health_opponent":2,"sequence":sequence,"known_shells":known,"player_name":"tester","items":[]})
 file.close()
 change_scene_to_file("res://scenes/main.tscn")
 await create_timer(12).timeout
 var rm = current_scene.get_node("standalone managers/round manager")
 print("RESUME_STATE round=",rm.currentRound," socket=",rm.camera.activeSocket," cursor=",rm.cursor.cursor_visible," shells=",rm.shellSpawner.sequenceArray," dealer_animation=",rm.animator_dealer.current_animation)
 check(rm.currentRound == 1,"saved round restored")
 check(rm.camera.activeSocket == "home","camera returned to table")
 check(rm.deskUI_shotgun.visible and rm.cursor.cursor_visible,"interactive table visible")
 check(is_equal_approx(rm.animator_dealer.get_parent().position.x,20.6857),"dealer actually at table")
 check(rm.healthCounter.uiArray[0].visible,"counter booted")
 check(rm.shellSpawner.sequenceArray == sequence,"remaining chamber preserved")
 if mobile.has_method("_can_replay_shells"):
  var dealer = rm.dealerAI.dealermesh_normal
  check(dealer.get_active_material(0).emission_enabled and is_equal_approx(dealer.get_active_material(0).emission_energy_multiplier,0.08),"dealer local brightness only")
  var shell = rm.shellSpawner.spawnedShellObjectArray[0].get_child(0)
  check(shell.mesh.get_active_material(1).emission_enabled and is_equal_approx(shell.mesh.get_active_material(1).emission_energy_multiplier,0.32),"shell color local brightness")
  check(shell.mesh.get_active_material(1) != shell.mat_live,"shared original shell material untouched")
  check(mobile._can_replay_shells(),"one replay available on restored table")
  var cam = rm.camera.cam
  var panel = mobile._shell_panel
  var pos = cam.unproject_position(panel.get_child(0).global_position)
  print("PANEL_TOUCH ",pos," viewport=",root.size)
  var press = InputEventScreenTouch.new(); press.index=0; press.position=pos; press.pressed=true
  root.push_input(press,true)
  var release = InputEventScreenTouch.new(); release.index=0; release.position=pos; release.pressed=false
  root.push_input(release,true)
  check(mobile._shell_replay_busy and not mobile._shell_replay_available,"touch on actual panel consumes once")
  await create_timer(0.8).timeout
  check(rm.shellSpawner.anim_compartment.current_animation == "show shells","original show shells animation replayed")
  paused=true
  await create_timer(0.3,true).timeout
  check(mobile._shell_replay_busy,"pause does not complete replay timers")
  paused=false
  await create_timer(4).timeout
  check(not mobile._shell_replay_busy and not mobile._can_replay_shells(),"second replay blocked")
  check(rm.shellSpawner.sequenceArray == sequence and rm.health_player == 3 and rm.health_opponent == 2,"replay preserves chamber and health")
  check(rm.camera.activeSocket == "home" and rm.cursor.cursor_visible and rm.deskUI_shotgun.visible,"replay returns usable controls")
  mobile._update_shell_batch()
  check(not mobile._shell_replay_available,"same batch cannot rearm")
  rm.shellSpawner.SpawnShells(2,1,1,false)
  mobile._update_shell_batch()
  check(mobile._can_replay_shells(),"new shell/tool batch rearms once")
 else:
  check(false,"local brightness and once-per-batch replay implemented")
 if existed:
  file = FileAccess.open(mobile.CHECKPOINT_PATH,FileAccess.WRITE); file.store_buffer(backup); file.close()
 else: mobile.clear_checkpoint()
 print("RESUME_RESULT ","PASS" if failures.is_empty() else "FAIL")
 quit(0 if failures.is_empty() else 1)
