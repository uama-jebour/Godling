# Godling

一个使用 **Godot 4.6** 开发的 2D 类搜打撤卡牌游戏原型。  
项目当前聚焦于最小可玩验证：事件选择、回合推进、主线叙事、强制袭击、撤离结算与本地 JSON 存档。

## 项目定位

- 灵感来源：苏丹的游戏、鸭科夫
- 核心体验：在单张 2D 地图内按回合选择事件，权衡风险与收益，在合适时机撤离
- 核心卖点：通过任务系统将叙事嵌入搜打撤循环，并逐步解锁系统

## 当前 Demo 已实现

- 家园配置加载（英雄、携带物、装备快照）
- 地图事件板（随机事件 + 固定叙事事件）
- 事件出击面板（详情、奖励预览、提交需求）
- 事件处理与回合推进
- 第 4 回合后概率触发“强制袭击”（不占回合）
- 主线提交物（静默祷词）-> 主线战斗 -> 撤离事件
- 撤离成功写入本地存档（JSON）

## 运行环境

- Godot Engine `4.6.x`
- macOS / Windows（开发与导出）

## 本地运行

在 Godot 编辑器中打开项目后按 `F5`，或在终端运行：

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --path '/Users/zhangwei/Documents/Mycode/Godling'
```

## 可视化手动测试（简版）

1. 启动后确认：回合1、危险度0、随机4/固定1。  
2. 选择任意随机事件并处理：应进入下一回合，危险度+1。  
3. 推进至第4回合后，验证强制袭击可被处理且不占回合。  
4. 点击“调试：获得静默祷词”，处理主线叙事并推进至第6回合。  
5. 完成主线战斗后触发撤离，处理撤离事件，确认日志显示入库成功。  

更完整步骤见 Release 页面说明。

## 导出 Windows 可执行文件

先确保已安装对应版本导出模板（`4.6.1.stable`），再执行：

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path '/Users/zhangwei/Documents/Mycode/Godling' --export-release "Windows Desktop" 'build/windows/Godling.exe'
```

导出产物：

- `build/windows/Godling.exe`
- `build/windows/Godling.pck`

## 一键打包与发布

项目提供脚本：

```bash
./scripts/release_windows.sh v0.1.0 "Godling v0.1.0"
```

脚本会自动执行：

- 打包 `zip`
- 生成 `sha256`
- 创建并推送 tag
- 使用 `gh` 创建/更新 GitHub Release 并上传资产

## 仓库结构（关键目录）

```text
autoload/     # 顶层状态：ContentDB / ProgressionState / RunState
data/         # JSON 数据源（地图、事件、任务、战斗等）
scenes/       # 场景
scripts/      # 运行逻辑与工具脚本
docs/         # 项目文档
features/     # 功能规格文档
tasks/        # 路线图与任务卡
tests/        # 冒烟测试脚本
```

## 发布版本

- Latest: `v0.1.0`  
  https://github.com/uama-jebour/Godling/releases/tag/v0.1.0
