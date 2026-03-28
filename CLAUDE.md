# CLAUDE.md

Godling minimal context:

- Stack: Godot 4.6 + GDScript
- Core loop: Enter Map -> Events -> Turn Progression -> Extract/Settlement
- Main scenes: `scenes/bootstrap.tscn`, `scenes/battle/battle_runner.tscn`
- Key AutoLoads: `ContentDB`, `ProgressionState`, `RunState`, `BalanceState`

Hard constraints:

1. Fixed events are not random slots.
2. Battle is not the only gameplay focus.
3. Temporary loot is not permanent storage.
4. UI never decides rewards or progression.
5. No new AutoLoad without explicit approval.

Before implementation, always define: goal, out-of-scope, touched files, and verification method.
