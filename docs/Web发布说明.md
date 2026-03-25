# Web 发布说明

## 目标

将 `Godling` 导出为浏览器可游玩的 Web 版本，并通过 GitHub Pages 直接访问。

## 当前状态

- 已新增 [export_presets.cfg](../export_presets.cfg) 中的 `Web` 预设
- 已新增 [deploy-web.yml](../.github/workflows/deploy-web.yml) 工作流
- 已确认本地命令可成功导出：

```bash
mkdir -p dist/web
godot --headless --path . --export-release "Web" dist/web/index.html
```

## 本地导出

在项目根目录执行：

```bash
mkdir -p dist/web
godot --headless --path . --export-release "Web" dist/web/index.html
```

导出后主要文件位于：

- `dist/web/index.html`
- `dist/web/index.js`
- `dist/web/index.wasm`
- `dist/web/index.pck`

本地预览：

```bash
python3 -m http.server 8080 --directory dist/web
```

访问：

- `http://localhost:8080`

## GitHub Pages 发布

### 前置条件

1. 仓库已推送到 GitHub
2. 仓库 `Settings -> Pages` 中选择 `GitHub Actions`

### 自动发布触发

- 推送到 `main`
- 推送到 `master`
- 手动触发 `Deploy Web Build`

### 工作流职责

工作流会自动：

1. 下载 `Godot 4.6.1`
2. 安装 `4.6.1.stable` 导出模板
3. 导出 Web 构建
4. 上传 Pages Artifact
5. 部署到 GitHub Pages

## 当前已处理的 Web 兼容点

- [bootstrap.gd](../scripts/ui/bootstrap.gd) 中的桌面窗口控制逻辑已对 `web` 平台跳过

## 已知注意事项

- 浏览器端首帧字体/缩放表现仍需手动实机验证
- 音频可能受到浏览器自动播放策略影响
- 存档走 `user://`，浏览器环境下依赖本地持久化存储
- 若后续新增更多桌面端 `DisplayServer / Window` 行为，需要继续补 `web` 平台保护

## 建议上线前验收

1. 打开页面后首屏布局无裁切
2. 地图 hover 与右侧事件面板联动正常
3. 点击战斗事件可进入交互战斗
4. 战斗结束后能回到地图
5. 刷新页面后存档行为符合预期
