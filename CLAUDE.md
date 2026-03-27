# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Godling is a 2D single-player game built with Godot 4.6 + GDScript. The core gameplay loop is a "raid-style" extraction shooter:

`Enter Map -> Spawn Random/Fixed Events -> Process 1 Event -> Turn Progression -> Decide Continue or Extract -> End-of-Run Settlement`

- 4-6 random events per turn
- Fixed events persist across turns (narrative events)
- Must successfully extract to keep loot

## Tech Stack

- **Engine**: Godot 4.6
- **Language**: GDScript
- **Config**: JSON (not Excel)
- **Top-level States**: ContentDB, ProgressionState, RunState, BalanceState

## Common Commands

### Run Tests

All tests are headless Godot scripts:

```bash
# Run a single test
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/interactive_battle_smoke_test.gd

# Common test scripts
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/run_flow_smoke_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/bootstrap_scene_smoke_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/battle_director_smoke_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/content_creator_smoke_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/battle_ui_card_smoke_test.gd
```

### Web Export

```bash
# Local export
mkdir -p dist/web
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Web" dist/web/index.html
BUILD_ID="$(date -u +'%Y%m%dT%H%M%SZ')-local"
bash scripts/web/prepare_web_build.sh dist/web "$BUILD_ID"

# Local preview
python3 -m http.server 8080 --directory dist/web
# Open http://localhost:8080
```

### Azure Image Generation

Requires env vars: `AZURE_OPENAI_API_KEY`, `AZURE_OPENAI_ENDPOINT`, `AZURE_OPENAI_API_VERSION`, `AZURE_OPENAI_IMAGE_DEPLOYMENT`

```bash
# Install skill (one-time)
bash scripts/tools/install_azure_imagegen_skill.sh

# Generate single image
python3 codex-configs/skills/azure-imagegen/scripts/azure_image_gen.py generate \
  --prompt "Dark fantasy hero" --use-case stylized-concept \
  --out output/imagegen/hero.png

# Batch generation
python3 codex-configs/skills/azure-imagegen/scripts/azure_image_gen.py generate-batch \
  --input codex-configs/skills/azure-imagegen/examples/godling_batch1.jsonl \
  --out-dir output/imagegen/batch
```

## Architecture

### Top-Level States (AutoLoad)

- **ContentDB**: Loads JSON configs, validates references, provides ID lookups
- **ProgressionState**: Cross-run persistence (permanent storage, currency, completed tasks, story_flags, unlock_flags)
- **RunState**: Current run state (map, turn, danger level, event board, temporary loot)
- **BalanceState**: Runtime balance parameters and content overrides

### Layer Structure

1. **World Layer**: Event board generation, task/fixed event lines, turn progression, event dispatch
2. **Battle Layer**: Executor for `battle` type events (units, AI, combat events, results)
3. **Progression Layer**: Extraction settlement, death cleanup, permanent save
4. **UI Layer**: Display state, receive input, never writes directly to business logic

### Key Data Flow

- Battle Layer returns `BattleResult` to World Layer
- World Layer returns `ExtractionResult` to Progression Layer
- UI reads through intermediate layers, never directly from battle/save data

### Directory Structure

```
autoload/       # Top-level state singletons
systems/        # Business logic (battle/, world/)
ui/             # UI controllers
scenes/         # Godot scenes (.tscn)
data/           # JSON configs (items, battles, maps, etc.)
tests/          # Headless test scripts
docs/           # Long-term documentation (Chinese filenames)
features/       # Feature specs and task breakdowns
tasks/          # Current tasks and handoff notes
```

## Code Conventions

- **Files**: `snake_case` for code/resources, Chinese for documentation
- **Constants**: `UPPER_SNAKE_CASE`
- **No Chinese** in code/resource filenames
- **No large business logic** in single controller scripts
- **Config over code**: New events/tasks/loot go in JSON, not hardcoded

## Critical Rules

1. Never treat fixed events as random slots
2. Never make battle system the sole game focus
3. Never confuse temporary loot with permanent storage
4. Never let UI directly decide rewards or story progression
5. Never add new AutoLoad without proving existing layers can't handle it

## Pre-Implementation Checklist

Before writing code, output these 5 items:

1. What is the goal
2. What is NOT in scope
3. Related files and documentation
4. Key constraints
5. How to verify/accept

## Key Files

- Main entry: `scenes/bootstrap.tscn`
- Battle scene: `scenes/battle/battle_runner.tscn`
- Project config: `project.godot`
- Web export preset: `export_presets.cfg`

## Documentation (Read When Needed)

- Core gameplay: `docs/核心玩法摘要.md`
- Architecture: `docs/技术架构摘要.md`
- Content pipeline: `docs/内容管线说明.md`
- Code standards: `docs/代码规范.md`
- Web publish: `docs/Web发布说明.md`
- Current task: `tasks/当前任务卡.md`
- Handoff notes: `tasks/开发交接.md`
