# Auto Battle Smooth Movement Design

**Goal**

Make auto-battle unit movement appear continuously smooth during playback instead of jumping once per tick, without changing battle simulation results, combat timing, or AI decisions.

**Problem Summary**

Auto-battle preview currently renders one discrete scene frame per simulation tick. During playback, the controller switches from one timeline frame to the next after a fixed delay. Each time a new frame is rendered, the unit token is assigned a new `position` immediately. Because no interpolation happens between frames, movement appears stepped and choppy.

Root-cause chain:

- `auto_battle_runner.gd` generates a timeline with one frame per tick.
- `battle_scene_controller.gd` plays those frames at a visible delay.
- `_sync_arena_tokens()` assigns `token.position` directly from the current frame's world position.
- AI movement is already discrete per tick, so render-layer hard assignment exposes the full step distance visually.

**Chosen Approach**

Add render-layer interpolation in the scene controller.

The simulation timeline remains unchanged. Each token gets a logical target position from the latest frame, but the visible token position moves toward that target every render frame inside `_process(delta)`. This decouples visual smoothness from simulation tick frequency while keeping battle logic deterministic.

This is preferred over denser timelines or higher simulation tick rates because it:

- preserves existing combat logic and balance
- avoids expanding timeline payload size
- minimizes regression risk in tests and data contracts
- can be tuned visually without touching simulation rules

**Alternatives Considered**

1. Increase simulation tick rate

This reduces jump distance, but it changes battle timing assumptions, cooldown cadence, and performance characteristics. It is too invasive for a visual polish issue.

2. Generate multiple subframes per tick

This would smooth playback but increases timeline complexity, serialization volume, and test surface. It also duplicates interpolation work that the renderer can do locally.

3. Tween each token on frame updates

This is viable but less robust than per-frame interpolation because playback speed changes, pauses, rapid state refreshes, and repeated re-targeting can create overlapping tweens. A single render-loop interpolator is easier to keep stable.

**Design**

Add a small render-state layer inside `battle_scene_controller.gd`:

- track the latest target arena position for each entity
- track a rendered position for each visible token
- on each playback frame update, refresh only the target position
- on each `_process(delta)`, move rendered positions toward targets

Token placement rules:

- newly spawned tokens start at their target position immediately to avoid slide-in artifacts
- existing tokens interpolate toward the newest target position
- attack/defend motion offsets remain additive and are included in the target position
- dead or removed tokens keep existing fade/removal behavior
- interactive battle mode should preserve current direct behavior unless the same smoothing is explicitly enabled there later

Interpolation behavior:

- use a frame-rate-independent smoothing function in `_process(delta)`
- expose a small constant for movement responsiveness so we can tune feel without touching gameplay
- snap to target when distance becomes very small, preventing endless micro-drift
- optionally snap immediately when arena layout refreshes after resize, to avoid visible sliding caused by container relayout

**Implementation Boundaries**

Modify:

- `scripts/battle/battle_scene_controller.gd`
- `tests/auto_battle_scene_smoke_test.gd`

Add:

- a focused test covering smooth token convergence during auto-battle preview playback

Do not modify:

- `systems/battle/auto_battle_runner.gd`
- `systems/battle/auto_battle_ai_system.gd`
- battle content data

**Testing Strategy**

1. Add a targeted test that:

- instantiates the battle scene
- starts auto preview playback
- captures a token position
- forces a later preview state with a different target position
- verifies the token does not instantly teleport to the final target on the first render frame
- verifies the token converges toward the target over subsequent frames

2. Re-run existing regression coverage:

- `tests/auto_battle_scene_smoke_test.gd`
- `tests/auto_battle_hpbar_alignment_test.gd`
- `tests/auto_battle_runner_smoke_test.gd`

**Risks**

- drag-and-drop interaction uses token rectangles in `_process`; smoothing must not interfere with interactive mode targeting
- attack-line and FX origins that read `token.position` will now use rendered position, which is desirable for preview playback but should be checked for timing consistency
- resizing the arena can produce unwanted glide unless refresh paths explicitly snap render positions

**Success Criteria**

- units move smoothly during auto-battle preview playback
- battle outcome and per-tick logic remain unchanged
- no regressions in existing auto-battle smoke tests
- no visible teleporting during normal movement except on first spawn or explicit snap scenarios
