# Godling Session Instructions

## Start-of-Task Context Order
1. `agent.md`
2. `项目记忆.md`
3. `tasks/当前任务卡.md`
4. `tasks/开发交接.md`
5. `docs/Web发布说明.md`
6. Only related `features/*/规格说明.md`

## Always Do Before Coding
Output 5-point summary:
1. Goal understanding
2. What is out-of-scope
3. Files to change
4. Constraints to follow
5. Validation plan

## Current Priority
- Stabilize first-screen map layout (desktop + web)
- Improve real web experience
- Close cache-related confusion
- Do **not** expand big new systems

## Scope Guardrails
- Keep Godot `4.6` + `GDScript`
- Keep top-level state boundary: `ContentDB / ProgressionState / RunState`
- Do not break loop: map event -> interactive battle -> write-back -> turn advance -> forced raid -> extraction
- Fixed events must not be overwritten by random refresh

## Practical Notes
- First screen is map event board (not old left-side button list)
- If normal window shows old build or Chinese glitches, first suspect browser cache; do not misdiagnose as font regression

## Fast Validation Commands (macOS)
- `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/bootstrap_scene_smoke_test.gd`
- `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/run_flow_smoke_test.gd`
- `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Web" /tmp/godling_web_export/index.html`
- `bash scripts/web/prepare_web_build.sh /tmp/godling_web_export "$(date -u +'%Y%m%dT%H%M%SZ')-local"`

## Collaboration Style
- Provide concise progress updates every 30-60 seconds during substantial work
- Keep changes minimal, focused, and reversible
- Sync docs when behavior or workflow changes
