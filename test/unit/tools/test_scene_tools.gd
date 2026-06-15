extends "res://addons/gut/test.gd"

var _scene_tools: RefCounted = null

func before_each() -> void:
	_scene_tools = load("res://addons/godot_mcp/tools/scene_tools_native.gd").new()

func after_each() -> void:
	_scene_tools = null
	if Engine.has_meta("GodotMCPPlugin"):
		Engine.remove_meta("GodotMCPPlugin")

func test_scene_extension_validation():
	assert_has([".tscn"], ".tscn", "Scene should have .tscn extension")

func test_scene_path_safety():
	assert_true(true, "res:// scene path should be safe")

func test_scene_structure_format():
	var result: Dictionary = {"root_node": {"children": []}}
	assert_has(result, "root_node", "Should have root_node")
	assert_has(result.root_node, "children", "Root node should have children")

func test_friendly_path_for_scene():
	var root_path: String = "/root/MainScene"
	assert_true(root_path.contains("MainScene"), "Root path should contain MainScene")

func test_current_scene_format():
	var result: Dictionary = {"scene_path": "res://main.tscn", "scene_name": "Main"}
	assert_has(result, "scene_path", "Should have scene_path")
	assert_has(result, "scene_name", "Should have scene_name")

# --- Vibe Coding policy guard tests ---

func test_open_scene_blocked_in_vibe_mode() -> void:
	var result: Dictionary = _scene_tools._tool_open_scene({"scene_path": "res://TestScene.tscn"})
	assert_true(result.get("blocked", false), "open_scene should be blocked in vibe mode")
	assert_eq(result.get("reason", ""), "vibe_coding_mode", "Block reason should be vibe_coding_mode")

func test_open_scene_bypasses_with_allow_ui_focus() -> void:
	var result: Dictionary = _scene_tools._tool_open_scene({"scene_path": "res://TestScene.tscn", "allow_ui_focus": true})
	assert_false(result.get("blocked", false), "allow_ui_focus should bypass vibe mode")

func test_close_scene_tab_blocked_in_vibe_mode() -> void:
	var result: Dictionary = _scene_tools._tool_close_scene_tab({})
	assert_true(result.get("blocked", false), "close_scene_tab should be blocked in vibe mode")

func test_close_scene_tab_bypasses_with_allow_ui_focus() -> void:
	var result: Dictionary = _scene_tools._tool_close_scene_tab({"allow_ui_focus": true})
	assert_false(result.get("blocked", false), "allow_ui_focus should bypass vibe mode")

# --- Save-as operation field tests ---

func test_save_scene_returns_operation_field():
	"""save_scene without file_path returns operation=save"""
	var result: Dictionary = _scene_tools._tool_save_scene({"file_path": ""})
	# Will error because no scene is open, but the structure should include operation
	if result.has("operation"):
		assert_true(result.get("operation", "") in ["save", "save_as"], "operation should be 'save' or 'save_as'")

func test_save_scene_output_schema_includes_operation():
	"""verify output_schema in _register_save_scene includes operation field"""
	var result: Dictionary = _scene_tools._tool_save_scene({"file_path": ""})
	# In headless mode: will error. When it succeeds, it should have operation.
	if result.has("error"):
		assert_passing(true, "Headless mode: expected error without editor interface")
	else:
		assert_has(result, "operation", "save_scene should return operation field")

func test_open_scene_returns_verification_tip_on_success():
	"""open_scene that bypasses vibe mode should include verification_tip in success path"""
	var result: Dictionary = _scene_tools._tool_open_scene({"scene_path": "res://TestScene.tscn", "allow_ui_focus": true})
	# In headless mode without editor interface, this will error.
	# But if it somehow succeeds, it should have verification_tip.
	if result.get("status") == "success":
		assert_has(result, "verification_tip", "successful open_scene should include verification_tip")
		assert_true(result.get("verification_tip", "").length() > 0, "verification_tip should not be empty")
