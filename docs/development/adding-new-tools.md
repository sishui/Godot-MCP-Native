# 添加新 MCP 工具 - 完整流程

## 概述

添加一个新 MCP 工具需要修改 7 个文件，涉及注册、实现、分类、翻译、测试、文档 6 个环节。以下以 `await_scene_ready` 为例说明。

---

## 步骤清单

| # | 环节 | 文件 | 操作 |
|---|------|------|------|
| 1 | 注册 + 实现 | `tools/*_tools_native.gd` | 创建 `_register_<name>()` 和 `_tool_<name>()` 函数 |
| 2 | 分类器 | `native_mcp/mcp_tool_classifier.gd` | 在 `_build_classifications()` 中添加条目 |
| 3 | 分类器测试 | `test/unit/test_mcp_tool_classifier.gd` | 更新工具总数 + 新增 `assert_true(is_supplementary_tool(...))` |
| 4 | 单元测试 | `test/unit/tools/test_*.gd` | 添加参数验证、边界条件、返回值格式测试 |
| 5 | 翻译 JSON | `translations/tool_descriptions.json` | 添加工具描述 |
| 6 | 翻译 CSV | `translations/tool_descriptions.csv` | 添加中英文描述 |
| 7 | 文档 | `docs/current/tools-reference.md` | 更新工具列表和新增条目 |

---

## 详细说明

### 1. 注册 + 实现

在工具分类对应的 `*_tools_native.gd` 文件中（如 `debug_tools_native.gd`、`node_tools_native.gd`），完成三件事：

**a) 在 `register_tools()` 中添加调用：**
```gdscript
func register_tools(server_core: RefCounted) -> void:
    # ... 现有注册 ...
    _register_my_new_tool(server_core)
    # ... 后续注册 ...
```

**b) 创建注册函数 `_register_<name>()`：**
```gdscript
func _register_my_new_tool(server_core: RefCounted) -> void:
    server_core.register_tool(
        "my_new_tool",                   # 1. name: 工具名，snake_case
        "Description...",                # 2. description: 工具描述
        input_schema,                    # 3. input_schema: 输入参数定义（Dictionary）
        Callable(self, "_tool_..."),     # 4. callable: 处理函数
        output_schema,                   # 5. output_schema: 返回值定义（Dictionary）
        annotations_dict,                # 6. annotations: 注解
        "core"/"supplementary",          # 7. category: 核心/补充
        "Group-Name"                     # 8. group: 分组名
    )
```

**关键参数说明：**
- **category**: `"core"`（默认启用，tools/list 可见）或 `"supplementary"`（默认禁用，需用户手动开启）
- **group**: 同类工具的分组名，如 `"Node-Write"`、`"Script"`、`"Debug-Advanced"`。补充工具用 `"X-Advanced"` 格式
- **output_schema**: 定义返回值的预期结构；MCP 客户端可能据此过滤字段，建议包含所有返回字段
- **annotations**: 包含 `readOnlyHint`, `destructiveHint`, `idempotentHint`, `openWorldHint` 四个布尔字段

**c) 创建处理函数 `_tool_<name>()`：**
```gdscript
func _tool_my_new_tool(params: Dictionary) -> Dictionary:
    var param1: String = params.get("param1", "")
    if param1.is_empty():
        return {"error": "Missing required parameter: param1"}
    # ... 实现逻辑 ...
    return {"status": "success", "result": value}
```

---

### 2. 分类器注册

在 `native_mcp/mcp_tool_classifier.gd` 的 `_build_classifications()` 中按字母顺序添加：

```gdscript
{"name": "my_new_tool", "category": "supplementary", "group": "Debug-Advanced"},
```

---

### 3. 分类器测试

在 `test/unit/test_mcp_tool_classifier.gd` 中：

**a) 更新工具总数（如有新增工具）：**
```gdscript
# 如果之前是 155，新增一个则改为 156
func test_all_156_tools_registered():
    var all_tools: Array = _classifier.get_all_tools()
    assert_eq(all_tools.size(), 156, "Should have exactly 156 tools registered")
```

**b) 如果是 supplementary 工具，同步更新 supplementary 计数：**
```gdscript
func test_supplementary_tools_count():
    var supp_tools: Array = _classifier.get_supplementary_tools()
    assert_eq(supp_tools.size(), 126, "Should have 126 supplementary tools")
```

**c) 在 `test_is_supplementary_tool()` 中添加断言：**
```gdscript
assert_true(_classifier.is_supplementary_tool("my_new_tool"), "my_new_tool should be supplementary")
```

---

### 4. 单元测试

在 `test/unit/tools/` 下对应测试文件中添加测试，覆盖：

- **参数验证**：缺失必需参数 → 返回 error
- **边界条件**：无效参数、空值、超时等
- **返回值格式**：确保所有字段存在且类型正确

示例（来自 `test_debug_tools.gd`）：
```gdscript
func test_await_scene_ready_missing_scene_name():
    var tool = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
    var result: Dictionary = tool._tool_await_scene_ready({})
    assert_has(result, "error", "Missing scene_name should return error")
```

---

### 5. 翻译 JSON

在 `translations/tool_descriptions.json` 中按字母顺序添加：

```json
"my_new_tool": "Description of the new tool.",
```

---

### 6. 翻译 CSV

在 `translations/tool_descriptions.csv` 中按字母顺序添加一行：

```
my_new_tool,,Description of the new tool.,新工具的描述。
```

CSV 格式：`key,,en,zh`

---

### 7. 文档

在 `docs/current/tools-reference.md` 中：

**a) 更新概览表**：如果新增了工具，更新对应分类的数量统计。

**b) 添加工具条目**：在对应分类下添加：

```markdown
### N. my_new_tool

Description...

**Parameters:**
| Parameter | Type | Required | Description |
...

**Returns:**
| Field | Type | Description |
...

**Annotations:** `readOnlyHint=...`, `destructiveHint=...`, `idempotentHint=...`, `openWorldHint=...`

---
```

---

## 注意事项

1. **工具注册与 MCP 客户端缓存**：`server_core.register_tool()` 在插件 `_enter_tree()` 时执行，工具列表缓存在 MCP 客户端中。如果修改了注册代码后需要测试，必须重启 Godot 编辑器使插件重新加载。
2. **Supplementary 工具默认禁用**：`register_tool` 设置 `enabled = (category == "core")`，所以 supplementary 工具在 UI 面板中默认关闭。用户需手动启用或在代码中调用 `core.set_tool_enabled("tool_name", true)`。
3. **翻译文件作用域**：翻译仅用于 MCP 面板 UI 显示，不影响工具的功能。但缺少翻译会导致工具在面板中无描述文本。
4. **output_schema**：虽然不是强制校验，但建议包含所有返回字段，便于 MCP 客户端理解返回结构。

---

## 验证清单

- [ ] `register_tools()` 中调用了 `_register_<name>()`
- [ ] 分类器 `_build_classifications()` 包含新条目
- [ ] 分类器测试计数已更新
- [ ] supplementary 工具有 `assert_true(is_supplementary_tool(...))`
- [ ] 单元测试覆盖缺失参数和边界
- [ ] 翻译 JSON 和 CSV 已添加
- [ ] 文档 `tools-reference.md` 已更新
- [ ] 全量 GUT 测试通过
