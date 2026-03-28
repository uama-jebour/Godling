# Codex VSCode Token 优化指南（Godling）

更新时间：2026-03-28  
适用项目：`/Users/uama/Documents/Mycode/Godling`

## 1. 结论

在 Codex VSCode 插件里，即使只发“你好”，也会有较高输入 token。根因不是你的这句话，而是每轮都会附带较大的固定上下文（系统/开发指令、工具能力描述等）。

本次实测（同一项目、`exec --ephemeral "你好"`）：

- `full`（默认能力全开）：`input_tokens ≈ 24231`
- `dev-low-token`（保留开发能力，降开销）：`input_tokens ≈ 19041`
- `chat-low-token`（极限省 token，禁 shell tool）：`input_tokens ≈ 8490`

## 2. 主要开销来源（已验证）

1. 固定注入上下文（`base_instructions` 等）占比很大。
2. `shell_tool` 是最大头（关闭后 token 显著下降）。
3. `multi_agent` 也有明显增量（关闭后有中等幅度下降）。
4. `instructions_file` 在本次场景影响较小，不是主要矛盾。

## 3. 已落地优化（双模式 + 全功能）

### 3.1 新增 wrapper

- `/Users/uama/.codex/codex-wrapper-full.sh`
- `/Users/uama/.codex/codex-wrapper-dev-low-token.sh`
- `/Users/uama/.codex/codex-wrapper-chat-low-token.sh`

### 3.2 新增切换脚本

- `/Users/uama/.codex/switch-codex-mode.sh`

命令：

```bash
# 查看当前模式
~/.codex/switch-codex-mode.sh status /Users/uama/Documents/Mycode/Godling

# 全功能模式（token 最高）
~/.codex/switch-codex-mode.sh full /Users/uama/Documents/Mycode/Godling

# 开发低开销模式（推荐默认）
~/.codex/switch-codex-mode.sh dev /Users/uama/Documents/Mycode/Godling

# 聊天极限省 token（会禁用 shell tool）
~/.codex/switch-codex-mode.sh chat /Users/uama/Documents/Mycode/Godling
```

执行切换后，请在 VSCode 执行一次 `Developer: Reload Window`，并新开会话再测试。

## 4. 项目设置变更

已在工作区设置写入：

- `/Users/uama/Documents/Mycode/Godling/.vscode/settings.json`
  - `chatgpt.cliExecutable = /Users/uama/.codex/codex-wrapper-dev-low-token.sh`

即：当前默认已切到 `dev-low-token`。

## 5. 模式选择建议

- 日常编码：用 `dev`（在能力与 token 之间更平衡）。
- 纯问答或轻咨询：临时切 `chat`（token 最低）。
- 复杂改造、多工具重度任务：切 `full`。

## 6. 验证方式

可以直接跑：

```bash
cd /Users/uama/Documents/Mycode/Godling
~/.codex/codex-wrapper-dev-low-token.sh exec --json --skip-git-repo-check --ephemeral "你好" | rg '"type":"turn.completed"'
```

查看返回中的：

- `usage.input_tokens`
- `usage.cached_input_tokens`

