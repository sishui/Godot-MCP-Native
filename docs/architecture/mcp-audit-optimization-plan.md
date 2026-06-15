# MCP 审计优化方案

基于「冒险者酒馆」项目 `reference/mcp-audit/` 下四个审计文件（bugs / desired-features / limitations / usage-patterns）提取的与本 MCP 工具直接相关的问题、局限性和功能需求，整理为优化方案。

---

## 一、Bug 修复（按严重程度排序）

### P0 — 断连后无恢复机制

**问题描述：** MCP 连接断开后（如 Godot 进程被杀、Godot 编辑器重启、MCP 服务器异常），所有工具调用返回 `context canceled`。`mcp__godot-mcp__connect` 工具不存在（unknown tool）。唯一恢复方式是重启 Reasonix，丢失全部会话上下文。

**影响：** 一次误操作就导致整个会话报废。

**优化方向：**
- 提供显式的重连工具/方法，让 Reasonix 能在断连后重新建立 MCP 连接
- 或者在 MCP 服务器端增加心跳检测 + 自动恢复机制
- 连接状态指示：在插件 UI 上显示 MCP 连接状态

---

### P1 — save_scene 保存到当前激活场景而非目标场景

**问题描述：** `save_scene` 操作的是当前激活的场景标签页，而不是之前 `open_scene` 打开的目标场景。如果 `open_scene` 因场景损坏无声失败，`save_scene` 静默保存到错误场景，导致修改丢失。

**影响：** 错误地以为修改已保存，实际丢失所有改动。

**优化方向：**
- `save_scene` 增加可选 `scene_path` 参数，明确指定要保存的场景路径
- 如果未传参数，则保存前先确认当前激活场景
- 在返回值中输出实际保存的场景路径

---

### P1 — open_scene 场景损坏时无声失败

**问题描述：** 当 `.tscn` 文件损坏时（如子节点缺少 `parent="."` 属性），`open_scene` 返回 `{"root_node_type":"Panel","status":"success"}`，看起来成功但实际未加载。实际激活的仍然是之前的面板。

**影响：** 无声失败导致后续所有场景操作都作用于错误场景，浪费大量排查时间。

**优化方向：**
- `open_scene` 加载后检测编辑器日志中是否有 Error 级别的加载错误
- 在返回值中增加 `warnings` 或 `errors` 字段，报告加载过程中的问题
- 可选：加载后验证实际激活场景是否与请求一致

---

### P1 — create_node 重名时静默生成 @NodeType@XXXXX

**问题描述：** `create_node("Scroll", "ScrollContainer", parent)` 在父节点下已存在同名节点时，不返回 error，而是静默创建 `@ScrollContainer@29966`。后续代码中的 `GetNode<ScrollContainer>("Scroll")` 拿不到节点，导致 NRE。

**影响：** 创建了冗余节点且不易发现。

**优化方向：**
- 创建一个可选参数 `on_name_conflict`：`"error"`（默认）、`"rename"`、`"auto"`（当前行为）
- 默认（`"error"`）在重名时返回明确的错误提示
- 在返回值中输出实际创建的节点名

---

### P2 — simulate_runtime_input_event release 坐标被覆盖

**问题描述：** 调用 release 事件时传入自定义 position，但被工具返回覆盖为 press 时的值。导致无法模拟不同位置释放鼠标（拖拽操作）。

**影响：** 拖拽操作无法用此工具实现。

**优化方向：**
- 修复 release 事件的 position 参数处理逻辑，使用传入的 position 而非 press 时的缓存值
- 或者明确在文档中标注不支持拖拽操作

---

### P2 — get_runtime_scene_tree 在 Godot 崩溃后返回 stale 缓存

**问题描述：** 游戏进程崩溃后，`get_runtime_scene_tree` 有时返回上一次正常运行时缓存的数据而非空结果，导致误判"游戏正常运行"。

**影响：** 如果只看场景树不看 runtime info 的 stale 标志，可能误判游戏状态。

**优化方向：**
- 在 `get_runtime_scene_tree` 的返回值中增加 `stale` 标记
- 或者检测到会话不活跃时返回明确的空场景树 + warning 字段

---

### P2 — edit_file 修改 .tscn 后 save_scene 覆盖手动编辑

**问题描述：** 用 `edit_file` 直接修改 .tscn 文件后调用 `save_scene`，编辑器把内存中的版本写回磁盘，覆盖手动编辑的修改。

**影响：** 手动编辑的 .tscn 修改被静默丢弃。

**优化方向：**
- `save_scene` 增加文件修改时间检测，如果检测到磁盘文件有未被编辑器感知的修改，则发出警告
- 或者提供一个 `save_scene(force: bool)` 参数控制是否覆盖外部修改

---

### P3 — stop_project → run_project 间隔需要等待

**问题描述：** `dotnet build → stop_project → run_project` 连续执行时，有时 `run_project` 报 "Project is already running"，但查询显示无活跃会话。

**影响：** 验证流程中断，需要手动重试。

**优化方向：**
- `stop_project` 内部增加等待机制，确保进程完全退出后再返回
- 或者在返回状态中包含 `process_still_terminating` 标记
- `run_project` 增加内部重试机制

---

### P3 — connect_signal 参数验证提示不完整

**问题描述：** 调用 `connect_signal("pressed", emitter_path=...)` 只传了 emitter_path 和 signal_name，没传 receiver_path 和 receiver_method。报错只提示了第一个缺失参数。

**影响：** 开发者体验上的小问题。

**优化方向：**
- 一次性验证全部必需参数，返回所有缺失参数名的列表

---

## 二、局限性改进

### L1 — evaluate_runtime_expression 不支持 C# 表达式

**问题描述：** Godot 的 Expression 类只支持 GDScript 表达式，不支持 C# 运行时访问。无法直接验证 C# 单例的数据状态。

**影响：** 验证 C# 状态必须绕道 UI 文本或日志。

**优化方向：**
- 无法改变 Godot Expression 的本质限制
- 可增加 `evaluate_runtime_expression` 的 node_path 上下文支持，允许在指定节点上下文中计算 GDScript 表达式
- 或者提供一个独立的 `call_runtime_csharp_method` 工具，通过 Godot 的 `.NET` 桥接调用 C# 方法

---

### L1 — call_runtime_node_method 参数不稳定

**问题描述：** `call_runtime_node_method` 有时返回 null 但方法实际执行了。数值参数可能被自动转型（int → float），需注意精度问题。

**影响：** 返回值不可靠，无法区分"方法执行了但返回 null"和"方法没执行"。

**优化方向：**
- 修复参数类型的自动转换逻辑，保留原始类型信息
- 增加类型注解参数，允许调用方指定参数类型
- 返回更详细的状态信息

---

### L1 — batch_update_node_properties 不支持 Resource 类型属性

**问题描述：** 设置 `theme_override_styles/normal` 为 StyleBoxFlat 时，传入的值被静默忽略，不报错也不生效。

**影响：** 无法用 MCP 批处理设置按钮/面板的视觉样式。

**优化方向：**
- 支持通过 dict 方式创建和设置 Godot Resource 类型属性
- 如果无法支持，则返回明确的错误提示而非静默忽略
- 改进文档，明确标注支持的属性类型

---

### L2 — execute_editor_script 不返回 print 输出

**问题描述：** `execute_editor_script` 中 GDScript `print("xxx")` 的输出不会出现在工具返回值中（output 始终为 `[]`）。

**影响：** 调试编辑器脚本困难。

**优化方向：**
- 捕获脚本执行期间的 stdout 输出并返回
- 或在执行后自动获取编辑器日志中的 print 输出

---

### L2 — batch_update_node_properties 值格式不一致

**问题描述：** 不同属性类型接受不同格式的值（数字直接传值、Color 传 hex、Vector2 传字符串或 dict），不清楚哪些属性用哪种格式。

**影响：** 每设置一个属性都需要试错。

**优化方向：**
- 统一值格式：优先使用 Godot 的 Variant 序列化格式
- 输出类型映射文档
- 在返回值中提示属性预期类型

---

### L2 — inspect_runtime_node 对动态 C# 节点显示 script=null

**问题描述：** 运行时 `inspect_runtime_node` 返回 `"script": null`，即使该节点已动态附加了 C# 脚本且功能正常。

**影响：** 造成"脚本没加载"的误判。

**优化方向：**
- 修复对动态创建 C# 节点的 script 检测逻辑
- 如果无法区分，在 `script=null` 时增加说明字段说明检测限制

---

### L3 — get_debug_output 跨 session 日志累积

**问题描述：** stdout/stderr 缓冲区未在 `stop_project` / `run_project` 间清空，多个运行实例的日志混合在一起。

**影响：** 日志归属困难，降低 debug 效率。

**优化方向：**
- `run_project` 时自动清空日志缓冲区
- 或者在 `get_debug_output` 中增加 `session_id` 参数来过滤当前 session 的日志

---

### L3 — 场景加载时序导致路径不可用

**问题描述：** `run_project` 后立刻获取场景树，返回的节点只有 `/root/CharacterEntity`，需要等待 3-6 秒后场景才切换为目标场景。

**影响：** 在场景加载完成前的所有 MCP 操作都会报 "Node not found"。

**优化方向：**
- 提供 `await_scene_ready` 工具（见下节功能需求）

---

## 三、功能需求

### F1 — await_scene_ready 工具

**描述：** 每次 `run_project` 后必须手动轮询等待场景加载完成。提供专用工具：

```
await_scene_ready(scene_name: "Main", timeout_sec: 10)
→ { "scene": "Main", "elapsed": 3.2, "timeout": false }
```

**内部实现：** 每 0.5s 检查一次 `get_runtime_info().current_scene`，直到匹配或超时。

---

### F2 — assert_runtime_condition 断言工具

**描述：** 提供自动化的运行时断言工具，替代手动比对返回值：

```
assert_runtime_condition(expression: "...", expected: "200 G", node_path: "...")
→ { "passed": true/false, "actual": "返回值", "expected": "200 G" }
```

**支持：** 数值/字符串/布尔断言，可配置比较方式。

---

### F3 — C# 对象属性运行时读取

**描述：** 在 `node_path` 指定节点后，能用 `property_path` 读取嵌套 C# 属性：

```
evaluate_runtime_expression("Data.Resources.Gold", node_path="/root/Main/GameManager")
→ { "value": 1500 }
```

**难点：** 受限于 Godot Expression 的 GDScript-only 限制，可能需要通过 Runtime Probe 的 C# 桥接实现。

---

### F4 — MCP 自动重连 / 显式重连工具

**描述：**
- 检测到连接断开后，每 5s 尝试重连一次，最多持续 30s
- 或提供 `mcp_reconnect` 显式重连工具

**备注：** 本 MCP 插件是原生 Godot 插件而非远程代理，所以重连逻辑在客户端侧。

---

### F5 — 截图 + Vision 自动分析

**描述：** 提供复合工具 `screenshot_and_analyze`，一张截图后自动做 Vision 分析，避免两次手动调用。

---

### F6 — save_scene 增加目标路径参数

**描述：** `save_scene` 增加可选 `scene_path` 参数，允许明确指定保存到哪个场景文件：

```
save_scene(scene_path: "res://Scenes/Main/Main.tscn")
```

---

### F7 — create_node 增加 name_conflict 策略参数

**描述：** 增加可选参数 `on_name_conflict: "error" | "rename" | "auto"`：
- `"error"`（默认）：重名时返回错误
- `"rename"`：自动生成唯一名称
- `"auto"`：保持当前行为

---

## 四、优先级建议

| 类别 | 项目 | 优先级 | 预估工作量 |
|------|------|--------|-----------|
| Bug | P0 — 断连恢复 | **最高** | 中 |
| Bug | P1 — save_scene 目标场景 | **高** | 小 |
| Bug | P1 — open_scene 无声失败 | **高** | 中 |
| Bug | P1 — create_node 重名 | **高** | 小 |
| 功能 | F1 — await_scene_ready | **高** | 小 |
| Bug | P2 — simulate_input release 坐标 | 中 | 小 |
| Bug | P2 — stale 缓存数据 | 中 | 小 |
| 局限 | L1 — C# 表达式支持 | 中 | 大 |
| 局限 | L1 — batch_update Resource 类型 | 中 | 大 |
| 功能 | F2 — assert_runtime_condition | 中 | 中 |
| 功能 | F6 — save_scene 目标路径 | 中 | 小 |
| Bug | P3 — stop/run 间隔 | 低 | 小 |
| 局限 | L2 — execute_editor_script print | 低 | 中 |
| 局限 | L2 — batch_update 值格式 | 低 | 中 |
| 功能 | F7 — create_node 命名策略 | 低 | 小 |

---

## 五、现有对策（短期规避方案）

部分问题已经有成熟的规避方案，记录在 `usage-patterns.md` 和 `godot-mcp-limitations.md` 中。优化前可以参考这些实践中总结的工作流。

| 问题 | 现有规避方案 |
|------|-------------|
| save_scene 目标问题 | 保存前先用 `get_current_scene()` 确认激活场景 |
| open_scene 无声失败 | 打开后检查 `get_editor_logs(source="editor_panel")` 中的 Error |
| create_node 重名 | 创建后立即 `get_scene_structure` 检查节点名 |
| C# 表达式不支持 | 用 `emit_signal("pressed")` 触发按钮 + UI Label text 间接验证 |
| batch_update Resource | 退回到编辑 .tscn 文件或使用 `execute_editor_script` |
| edit_file + save_scene 覆盖 | 先 `close_scene_tab` 确保文件持久化，再 `open_scene` 重新加载 |
| 场景加载时序 | `run_project` 后用 `bash("sleep 5")` 等待，再检查 `current_scene` |
| 日志跨 session | `run_project` 后记下当前 max sequence 号，只看新增日志 |
| execute_editor_script print | 通过 `get_editor_logs(source="editor_panel")` 查看 print 输出 |
| inspect_runtime_node script=null | 通过信号是否正常触发、方法是否可调用来间接验证 |

---

*本文档基于 `F:\gitProjects\冒险者酒馆\reference\mcp-audit/` 下的审计报告整理，原始审计数据来自实际项目开发中的 MCP 工具使用记录。*
