# Claude Code Token 优化指南（Godling）

更新时间：2026-03-28（已修复循环输出问题）
适用项目：`/Users/uama/Documents/Mycode/Godling`

## 1. 目标与结论

本指南用于降低 Claude Code 在 VSCode 中每轮请求的输入 token。

本次优化后的核心结论：

- 不加优化时，简单问候（如“你好”）可达到 `2w+` 输入 token。
- 采用当前低开销配置后，问候基线约 `6.4k~6.6k`。
- 若改用 `--bare` 极简模式，可进一步降到约 `4.7k`，但功能会明显减少。

## 2. 本次定位出的主要开销来源

1. 插件与启动注入上下文（固定系统提示、内置 skills）。
2. 项目与本地设置源（`project/local`）带来的大量权限规则文本。
3. superpowers 的 SessionStart 注入（启用时会显著增加上下文）。
4. 历史会话中出现过大附件（如 base64 图片）会推高会话总量。

## 3. 当前最终方案（已落地）

采用“双模式切换”：

- `low-token`：默认模式，优先低成本。
- `superpowers`：按需启用 superpowers 能力，token 会上升。

### 3.1 低开销模式（low-token）

策略：

- 保留工具能力（不再禁用工具）
- 强制 `--setting-sources user`
- 不加载 superpowers 插件目录

效果：

- 稳定性显著提升（避免“循环计划文本”问题）
- token 相比全功能模式有一定下降（具体数值以当次实测为准）

### 3.2 superpowers 模式（按需）

策略：

- 加载 `superpowers-nohook`（已移除 SessionStart hook）
- 设置工具白名单：`Skill,Read,Bash,Edit,Write,MultiEdit`
- 仍使用 `--setting-sources user`

效果：

- 问候基线约 `11416`（相对 low-token 明显更高）。

## 4. 双模式切换命令

脚本：`~/.claude/switch-claude-mode.sh`

```bash
# 切到低开销
~/.claude/switch-claude-mode.sh low /Users/uama/Documents/Mycode/Godling

# 切到 superpowers 模式
~/.claude/switch-claude-mode.sh super /Users/uama/Documents/Mycode/Godling

# 查看当前模式
~/.claude/switch-claude-mode.sh status /Users/uama/Documents/Mycode/Godling
```

执行切换后，在 VSCode 执行一次 `Developer: Reload Window`，再开新会话。

## 5. 关键文件清单

- 工作区设置：
  - `/Users/uama/Documents/Mycode/Godling/.vscode/settings.json`
- 低开销 wrapper：
  - `/Users/uama/.claude/claude-wrapper-low-token.sh`
- superpowers wrapper：
  - `/Users/uama/.claude/claude-wrapper-superpowers.sh`
- 切换脚本：
  - `/Users/uama/.claude/switch-claude-mode.sh`
- superpowers（去 hook 版本）：
  - `/Users/uama/.claude/plugins/superpowers-nohook`
- 项目最小上下文文档：
  - `/Users/uama/Documents/Mycode/Godling/CLAUDE.md`

## 6. 验证方法（建议每次切换后执行）

在项目目录执行：

```bash
cd /Users/uama/Documents/Mycode/Godling
claude -p "你好" --model kimi-k2.5 --output-format json --permission-mode bypassPermissions
```

检查返回 JSON 中：

- `usage.input_tokens`
- `modelUsage.kimi-k2.5.inputTokens`

## 7. 常见问题与处理

### Q1：切到 superpowers 后 token 明显上涨

这是预期行为。superpowers 模式的目标是能力优先，不是 token 最低。

### Q1.1：为什么会出现“循环输出”

根因是历史低开销 wrapper 曾强制 `--tools ""`，导致编码请求无法真正调用工具，模型会反复输出“先查看代码”的计划文本。现已修复为“保留工具，只限制 setting sources”。

### Q2：切换后腾讯模型不可用

优先检查 `~/.claude/settings.json`：

- `ANTHROPIC_BASE_URL` 是否为腾讯网关地址
- `ANTHROPIC_MODEL` 是否为 `kimi-k2.5`
- 如使用 `--bare`，需确保鉴权变量兼容（曾出现 `invalid x-api-key`）

### Q3：日志出现 `invalid model`（通常在 `generate_session_title`）

该报错通常发生在“会话标题生成”附加请求，不一定影响主对话回复。若主对话可正常返回，可先不阻断使用。

## 8. 回滚方案

如果想恢复单一旧配置：

1. 编辑 `/Users/uama/Documents/Mycode/Godling/.vscode/settings.json`
2. 将 `claudeCode.claudeProcessWrapper` 改回目标 wrapper
3. Reload Window

如果误改全局设置，可从历史备份恢复：

- `~/.claude/settings.json.bak-*`

## 9. 选型建议

- 日常开发、频繁对话：优先 `low-token`
- 需要 superpowers 工作流时：临时切到 `super`，用完切回 `low`
- 需要极致低 token 且可接受能力下降：单独使用 `--bare` 方案（谨慎）
