# Web 发布说明

## 目标

将 `Godling` 导出为浏览器可游玩的 Web 版本，并通过 GitHub Pages 直接访问。

## 当前状态

- 已新增 [export_presets.cfg](../export_presets.cfg) 中的 `Web` 预设
- 已新增 [deploy-web.yml](../.github/workflows/deploy-web.yml) 工作流
- 已新增 [prepare_web_build.sh](../scripts/web/prepare_web_build.sh) 用于导出后注入构建版本号（降低浏览器缓存旧包命中）
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
BUILD_ID="$(date -u +'%Y%m%dT%H%M%SZ')-local"
bash scripts/web/prepare_web_build.sh dist/web "$BUILD_ID"
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
4. 注入 `BUILD_ID` 到 `index.js / index.pck / index.wasm` 请求参数
5. 上传 Pages Artifact
6. 部署到 GitHub Pages

## 缓存策略

- `scripts/web/prepare_web_build.sh` 会在导出后执行三件事：
  1. 将 `index.html` 中 `index.js` 改为 `index.js?v=<BUILD_ID>`
  2. 将 `index.js` 内部 `index.wasm / index.pck` 请求改为 `?v=<BUILD_ID>`
- 同时会向 `index.html` 注入构建探针脚本（`GODLING_BUILD_GUARD`）：
  - 页面加载后以 `no-store` 方式读取 `.build-id`
  - 若发现远端构建号与当前页面不一致，会自动追加 `build_reload=<最新ID>` 参数并重载一次，降低“普通窗口卡旧 HTML”的概率
- 同时生成：
  - `dist/web/build-meta.json`
  - `dist/web/.build-id`
- 目标是让每次部署都带新版本参数，减少普通窗口命中旧缓存资源。

## 缓存排障

- 若普通窗口看到旧版本或中文异常，优先判断为浏览器缓存问题，而不是字体回退问题。
- 建议先做：
  1. 强制刷新（`Ctrl+F5` / `Cmd+Shift+R`）
  2. 清理站点缓存后重开
  3. 对比无痕窗口是否正常

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
