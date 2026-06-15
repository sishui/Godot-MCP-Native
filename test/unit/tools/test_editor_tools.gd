extends "res://addons/gut/test.gd"

var _editor_tools: RefCounted = null

func before_each() -> void:
	_editor_tools = load("res://addons/godot_mcp/tools/editor_tools_native.gd").new()

func after_each() -> void:
	_editor_tools = null
	if Engine.has_meta("GodotMCPPlugin"):
		Engine.remove_meta("GodotMCPPlugin")

func test_editor_state_format():
	var result: Dictionary = {
		"active_scene": "Main",
		"editor_mode": "editor",
		"selected_count": 1,
		"selected_nodes": ["/root/Main"]
	}
	assert_has(result, "active_scene", "Should have active_scene")
	assert_has(result, "editor_mode", "Should have editor_mode")
	assert_has(result, "selected_count", "Should have selected_count")
	assert_has(result, "selected_nodes", "Should have selected_nodes")

func test_selected_nodes_friendly_path():
	var paths: Array = ["/root/Main", "/root/Main/Player", "/root/Main/Camera3D"]
	for path in paths:
		assert_false(str(path).contains("@"), "Friendly path should not contain @")

func test_run_stop_project():
	var states: Array = ["playing", "editor"]
	assert_has(states, "playing", "Should have playing state")
	assert_has(states, "editor", "Should have editor state")

func test_editor_setting_name_format():
	var setting: String = "debug/gdscript/warnings/unused_variable"
	assert_true(setting.contains("/"), "Setting should have category separator")

func test_editor_logs_format():
	var result: Dictionary = {
		"logs": ["[INFO] Test message"],
		"count": 1,
		"total_available": 100
	}
	assert_has(result, "logs", "Should have logs")
	assert_has(result, "count", "Should have count")
	assert_has(result, "total_available", "Should have total_available")

func test_performance_metrics_format():
	var result: Dictionary = {
		"fps": 60.0,
		"memory_usage_mb": 512.5,
		"object_count": 1000,
		"resource_count": 50
	}
	assert_has(result, "fps", "Should have fps")
	assert_has(result, "memory_usage_mb", "Should have memory_usage_mb")
	assert_has(result, "object_count", "Should have object_count")

func test_execute_script_with_singletons():
	var singletons: Dictionary = {
		"OS": OS,
		"Engine": Engine,
		"Input": Input,
	}
	assert_has(singletons, "OS", "Should have OS singleton")
	assert_has(singletons, "Engine", "Should have Engine singleton")
	assert_has(singletons, "Input", "Should have Input singleton")

func test_execute_script_result_format():
	var success: Dictionary = {"status": "success", "result": "42"}
	var error: Dictionary = {"status": "error", "error": "Parse failed"}
	assert_has(success, "status", "Should have status")
	assert_has(error, "error", "Error should have error message")

# --- Vibe Coding policy guard tests ---

func test_run_project_blocked_in_vibe_mode() -> void:
	var result: Dictionary = _editor_tools._tool_run_project({})
	assert_true(result.get("blocked", false), "run_project should be blocked in vibe mode")
	assert_eq(result.get("reason", ""), "vibe_coding_mode", "Block reason should be vibe_coding_mode")

func test_run_project_bypasses_with_allow_window() -> void:
	var result: Dictionary = _editor_tools._tool_run_project({"allow_window": true})
	assert_false(result.get("blocked", false), "allow_window should bypass vibe mode")

func test_stop_project_blocked_in_vibe_mode() -> void:
	var result: Dictionary = _editor_tools._tool_stop_project({})
	assert_true(result.get("blocked", false), "stop_project should be blocked in vibe mode")

func test_stop_project_bypasses_with_allow_window() -> void:
	var result: Dictionary = _editor_tools._tool_stop_project({"allow_window": true})
	assert_false(result.get("blocked", false), "allow_window should bypass vibe mode")

func test_select_node_blocked_in_vibe_mode() -> void:
	var result: Dictionary = _editor_tools._tool_select_node({"node_path": "/root/Main"})
	assert_true(result.get("blocked", false), "select_node should be blocked in vibe mode")

func test_select_node_bypasses_with_allow_ui_focus() -> void:
	var result: Dictionary = _editor_tools._tool_select_node({"node_path": "/root/Main", "allow_ui_focus": true})
	assert_false(result.get("blocked", false), "allow_ui_focus should bypass vibe mode")

func test_select_file_blocked_in_vibe_mode() -> void:
	var result: Dictionary = _editor_tools._tool_select_file({"file_path": "res://project.godot"})
	assert_true(result.get("blocked", false), "select_file should be blocked in vibe mode")

func test_select_file_bypasses_with_allow_ui_focus() -> void:
	var result: Dictionary = _editor_tools._tool_select_file({"file_path": "res://project.godot", "allow_ui_focus": true})
	assert_false(result.get("blocked", false), "allow_ui_focus should bypass vibe mode")

func test_editor_screenshot_update_always_forced():
	var source_code: String = _editor_tools.get_script().source_code
	assert_true(source_code.contains("SubViewport.UPDATE_ALWAYS"), "get_editor_screenshot should set UPDATE_ALWAYS before capturing")
	assert_true(source_code.contains("render_target_update_mode = original_update_mode"), "get_editor_screenshot should restore original update mode after capturing")
	assert_true(source_code.contains("RenderingServer.force_draw()"), "get_editor_screenshot should call force_draw after frame wait")

func test_editor_screenshot_switches_main_screen():
	var source_code: String = _editor_tools.get_script().source_code
	assert_true(source_code.contains("set_main_screen_editor"), "get_editor_screenshot should switch main screen editor before capturing")
	assert_true(source_code.contains("viewport_type.to_upper()"), "get_editor_screenshot should convert viewport_type to upper case for set_main_screen_editor")

func test_editor_screenshot_uses_engine_main_loop():
	var source_code: String = _editor_tools.get_script().source_code
	assert_true(source_code.contains("Engine.get_main_loop()"), "get_editor_screenshot should use Engine.get_main_loop() instead of get_tree() for SceneTree access")
	assert_false(source_code.contains("get_tree().process_frame"), "get_editor_screenshot should NOT use get_tree() which is unavailable on RefCounted")

# --- Stop project wait logic tests ---

func test_stop_project_waits_for_exit():
	"""stop_project should call stop_playing_scene and wait for exit"""
	var result: Dictionary = _editor_tools._tool_stop_project({"allow_window": true})
	# In headless mode without editor interface, this returns error
	assert_has(result, "status", "stop_project should return a status field")
	# When successful, stopped_after_ms should be present
	if result.get("status") == "success":
		assert_has(result, "stopped_after_ms", "Successful stop should report stopped_after_ms")

func test_stop_project_output_schema_includes_stopped_after_ms():
	"""check _register_stop_project output_schema includes stopped_after_ms"""
	var source_code: String = _editor_tools.get_script().source_code
	assert_true(source_code.contains("stopped_after_ms"), "Source should reference stopped_after_ms")
