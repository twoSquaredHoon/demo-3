# Dialogue JSON format

One file per NPC in `dialogue/content/`. Filename must match `"id"` (`maya.json` → `"maya"`). Drop a generic `npcs/npc.tscn` in the world and set `npc_id` to that same id.

```json
{
  "id": "maya",
  "display_name": "Maya",
  "color": "#c47a6a",
  "start": "greeting",
  "nodes": {
    "greeting": {
      "entry": true,
      "priority": 1,
      "when": { "flag": "maya_met" },
      "lines": ["Crops still alive?"],
      "choices": [],
      "set_flags": []
    }
  }
}
```

## File fields

- `id` — must equal the filename stem.
- `display_name` — default speaker for bare-string lines; also the name label on the NPC.
- `color` — hex placeholder body color (`#rrggbb`).
- `start` — fallback node if no `entry` node matches.
- `nodes` — map of node id → node.

## Nodes

- `entry: true` — candidate when the player talks to this NPC (left-click interact). Reply-only nodes omit this.
- `priority` — higher wins among matching entries (default `0`).
- `when` — all listed keys must match (AND). Omit or `{}` for always.
  - `flag` / `flag_not` — boolean flags stored in the Dialogue autoload (memory-only).
  - `season` — `"spring"` / `"summer"` / `"fall"` / `"winter"`.
  - `hour_from` + `hour_to` — inclusive, 0–23; can wrap midnight (`20` + `5`).
- `lines` — strings (speaker = `display_name`) or `{ "speaker": "You", "text": "..." }`.
- `choices` — `{ "text": "Reply", "goto": "other_node" }`. Empty/omitted: advancing the last line **ends** the talk.
- `set_flags` — string array. Applied when this node finishes (last line with no choices, or a choice is picked).

`goto` must stay inside the same file. Adding a character: new JSON + instance of `npcs/npc.tscn`.
