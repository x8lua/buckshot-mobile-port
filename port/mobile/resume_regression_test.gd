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
  check(dealer.get_active_material(0).emission_enabled and is_equal_approx(dealer.get_active_material(0).emission_energy_multiplier,0.12),"dealer face readable locally")
  check(rm.musicManager.speaker_music.playing and rm.musicManager.speaker_music.stream != null,"continue starts background music")
  check(rm.musicManager.speaker_music.volume_db > -60,"continue music fade reaches audible volume")
  var shell = rm.shellSpawner.spawnedShellObjectArray[0].get_child(0)
  check(shell.mesh.get_active_material(1).shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED,"display shell color independent of environment")
  check(shell.mesh.get_active_material(1) != shell.mat_live,"shared original shell material untouched")
  check(dealer.get_active_material(1).emission_enabled and is_equal_approx(dealer.get_active_material(1).emission_energy_multiplier,0.50),"teeth balanced against face")
  var examine = current_scene.get_node("standalone managers/shell examine")
  for kind in ["live","blank"]:
   rm.shellSpawner.sequenceArray[0] = kind
   examine.SetupShell()
   await process_frame
   await process_frame
   var color_mat = examine.mesh.get_active_material(1)
   check(color_mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED,"magnifier "+kind+" color independent of environment")
   var base_color = examine.mat_live.albedo_color if kind == "live" else examine.mat_blank.albedo_color
   check(color_mat.albedo_color.is_equal_approx(Color(base_color.r*0.55,base_color.g*0.55,base_color.b*0.55,base_color.a)),"magnifier "+kind+" preserves hue without white clipping")
   examine.RevertShell()
  rm.shellSpawner.sequenceArray[0] = "live"
  var visual = rm.animator_dealer.get_parent()
  check(visual.visible,"dealer visible at table before shot")
  rm.animator_dealer.play("dealer fly away")
  await process_frame
  await process_frame
  check(visual.visible,"original recoil animation remains visible")
  await create_timer(0.5).timeout
  check(not visual.visible,"teleported dealer remains invisible at back")
  rm.animator_dealer.play("dealer return to table")
  await process_frame
  check(visual.visible and dealer.get_active_material(0).emission_energy_multiplier < 0.005,"dealer starts return in darkness")
  await create_timer(1.0).timeout
  var halfway_energy = dealer.get_active_material(0).emission_energy_multiplier
  check(halfway_energy > 0.005 and halfway_energy < 0.10,"dealer gradually emerges during original movement")
  check(visual.position.x > 20.6857 and visual.position.x < 25.9599,"dealer is moving toward table mid-return")
  await create_timer(1.2).timeout
  check(visual.visible and is_equal_approx(dealer.get_active_material(0).emission_energy_multiplier,0.12),"dealer fully visible at table")
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
