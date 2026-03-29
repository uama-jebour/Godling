# GodlingBattle Design

**Goal:** Build a brand-new standalone Godot project named `GodlingBattle` for the new auto-battle system, isolated from the old `Godling` project while selectively reusing proven runtime ideas.

## 1. Scope

`GodlingBattle` is a separate Godot 4.6 + GDScript project placed alongside `Godling`, not inside it. The old project remains a reference source only.

The first playable version starts directly on an `出战前准备` screen, lets the player choose:

- 1 hero
- 3 normal units
- equipped strategies
- a test battle

Then it runs an auto-battle spectator scene and finishes on a result screen before returning to `出战前准备`.

## 2. Product Flow

The first-version flow is fixed:

`出战前准备 -> 自动观战 -> 结果结算 -> 返回出战前准备`

There is no title screen in the first version.

There is no ownership, unlock state, preset save, or carry-over progression in the first version. All selectable content is available immediately.

## 3. UX Direction

### 3.1 Preparation Screen

The preparation screen is a formal in-world game screen, not a debug panel. Its tone is `庄重神秘的战术陈列台`.

Layout direction:

- hero and 3 selected normal units displayed side by side as one formation
- long strategy display band with many reserved slots
- no battlefield map preview
- test battle information shown as a concise side or top summary
- strong “deployment ritual” feeling instead of spreadsheet-like setup

### 3.2 Battle Observation

The battle view keeps the existing target direction of `2D 棋子 + 血条`, but must feel like a product screen instead of a debug tool.

The observation scene should focus on:

- readable token positions
- clear HP state
- visible event warning moments
- visible strategy trigger moments
- stable playback over flashy effects

### 3.3 Result Screen

The result screen tone is `冷静的战术报告页`.

First-screen priorities:

- victory / defeat
- surviving units
- key event trigger summary
- key strategy trigger summary

The result page does not need long progression settlement in the first version.

## 4. Core Gameplay Rules

The first version validates pre-battle build decisions, not battle-time manual operation.

That means:

- battle is fully auto-resolved
- active strategies are auto-cast by AI/runtime rules
- the player does not issue battle-time commands
- the old mixed interactive battle style is intentionally excluded from first scope

Reasoning:

- it protects the build-validation core loop
- it avoids a split runtime architecture in V1
- it keeps the new project isolated from old interaction-heavy systems

## 5. Runtime Rules

The initial runtime is based on the confirmed opening document.

### 5.1 Win / Lose

- victory: all enemies defeated
- defeat: hero dies
- defeat: battle exceeds `600s`

If all normal allied units die but the hero remains alive, the battle continues.

### 5.2 Simulation

- tick rate: `10 tick/s`
- deterministic by seed
- PC local target first
- first performance target: about 10 units in one battle, about 3 batch simulations per minute

### 5.3 Combat Model

First version includes:

- melee AI
- ranged AI
- pathing-aware movement
- immediate-hit ranged attacks
- no projectile system
- no critical hit / dodge / armor / resistance / threat

Map influence in first version is limited to pathing.

## 6. Data Model

The new project must define its own data layer. It must not depend on the old `ContentDB`.

### 6.1 `unit_def`

Fields:

- `unit_id`
- `display_name`
- `side` or spawn ownership context
- `type` (`hero`, `normal`, `elite`)
- `move_mode`
- `attack_mode`
- `move_speed`
- `radius`
- `max_hp`
- `attack_power`
- `attack_speed`
- `attack_range`
- `tags`
- `move_logic`
- `combat_ai`

### 6.2 `strategy_def`

Fields:

- `strategy_id`
- `name`
- `kind` (`passive`, `active`, `response`)
- `cost`
- `cooldown`
- `tags`
- `effect_def`
- `trigger_def`

First version rules:

- total strategy budget uses fixed `16` insight points
- cooldown allows decimals and can reach `0`
- durability system is disabled in first version even if future data keeps reserved fields for it

### 6.3 `event_def`

Fields:

- `event_id`
- `name`
- `trigger_def`
- `warning_seconds`
- `unresolved_effect_def`
- `response_tag`
- `response_level`

Current agreed event rule:

- `反制恶魔召唤` only responds to `恶魔召唤:1`

### 6.4 `battlefield_def`

Fields:

- `battlefield_id`
- `size`
- `pathing_blockers`
- optional decorative zones

### 6.5 `battle_setup`

Produced by the preparation screen.

Fields:

- selected hero id
- 3 selected ally unit ids
- selected strategy ids
- selected battle id
- seed

### 6.6 `battle_result`

Produced by runtime.

Fields:

- status
- victory
- defeat_reason
- elapsed_seconds
- survivors
- casualties
- triggered_events
- triggered_strategies
- structured log entries

## 7. System Architecture

The project should be split into five layers.

### 7.1 Data Layer

Responsible for loading and exposing battle content definitions.

Responsibilities:

- units
- strategies
- events
- battles
- test packs

This replaces old-project `ContentDB` dependencies with a minimal new content source.

### 7.2 Preparation Layer

Responsible only for setup selection and validation.

Responsibilities:

- choose hero
- choose 3 units
- choose strategies within cost
- choose test battle
- output normalized `battle_setup`

It does not run battle logic.

### 7.3 Battle Runtime Layer

The runtime is the main reusable-idea zone, but implemented fresh.

Suggested internal modules:

- `battle_state`
- `battle_ai_system`
- `battle_combat_system`
- `battle_event_response_system`
- `battle_runner`

Responsibilities:

- initialize runtime state from `battle_setup`
- step ticks
- target selection
- movement and spacing
- attack resolution
- strategy trigger and cooldown handling
- event warning / response / application flow
- battle end detection
- timeline and result generation

### 7.4 Observe Layer

Consumes runtime output and renders it.

Responsibilities:

- token placement
- hp bars
- event warning presentation
- strategy trigger feedback
- playback pacing

This layer must not own battle rules.

### 7.5 Result Layer

Consumes `battle_result`.

Responsibilities:

- display victory / defeat
- display survivors
- display key summaries
- return to preparation scene

## 8. Reuse Boundary From Old Project

The correct reuse strategy is `new project, refactored reuse`.

### 8.1 What Can Be Reused As Ideas

From the old project, the following concepts are worth carrying over:

- tick-based battle stepping
- staged event flow: `idle -> warning -> response -> resolve`
- deterministic seed testing
- simple melee / ranged auto-battle behavior
- observer-style visual rendering separation

### 8.2 What Should Not Be Directly Reused

These should not be copied as-is:

- old `ContentDB` data access pattern
- old big scene controller UI
- old mixed interactive battle simulator
- old request / battle_def schemas

Reason:

- too coupled to legacy project data and UI assumptions
- would reintroduce the same architectural confusion this new project is meant to avoid

### 8.3 Practical Reuse Rule

Allowed:

- porting small algorithms or module structures after rewriting
- borrowing deterministic test structure
- borrowing visual direction

Not allowed:

- copying old battle scene architecture wholesale
- preserving old dependencies just to save setup time

## 9. Error Handling

First version should fail clearly and early for invalid setup or invalid content.

Preparation validation should block battle start when:

- hero is missing
- ally count is not exactly 3
- strategy cost exceeds budget
- selected battle is missing

Runtime should return explicit failure states for:

- missing content ids
- invalid battle definition
- invalid event or strategy definition

Observe layer should degrade safely:

- if a visual asset is missing, use a fallback token style
- if a timeline entry is incomplete, continue battle display rather than crash the scene

## 10. Testing Strategy

The first version needs both runtime confidence and design-validation coverage.

### 10.1 Deterministic Runtime Tests

Keep headless tests for:

- same seed -> same result
- event trigger ordering
- response success / failure behavior
- timeout defeat
- hero death defeat

### 10.2 Battle Content Tests

Create at least 6 test packs covering:

- melee pressure
- ranged pressure
- summon-event pressure
- freeze / cold strategy interaction
- response success case
- response fail or no-response case

### 10.3 UI Smoke Tests

At minimum verify:

- project boots directly into preparation screen
- battle can start from valid setup
- battle can transition to result page
- result page can return to preparation screen

## 11. First Implementation Slice

The first implementation slice should be:

- standalone `GodlingBattle` project scaffold
- preparation scene
- normalized `battle_setup`
- minimal runtime with hero + allies + enemies
- minimal observation scene
- result scene

This slice proves the complete loop before deeper content expansion.

## 12. Out of Scope For V1

- ownership / unlock progression
- preset save / load
- title screen
- mixed interactive combat
- full skill system
- patrol behavior
- advanced VFX-heavy presentation
- multi-platform delivery

## 13. Future Extension Direction

Confirmed future-priority candidates:

- skill system
- patrol

These should be added by extending runtime modules, not by breaking current layer boundaries.
