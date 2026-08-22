# Demo 3 — Complete Systems and Architecture Summary

Last audited: 2026-08-14

This document describes the complete implemented state of the farm game prototype, including current gameplay rules, scene structure, state ownership, input and render layers, placeholder visuals, known limitations, and intended art-replacement boundaries.

## 1. Project Direction

The project is currently a systems-first farming prototype. Gameplay logic is being made playable before final artwork, animation, audio, balancing, content, and polish are added.

Project-wide architecture rule:

- Gameplay state is authoritative.
- Visual nodes render state and forward user intent.
- Placeholder art should live in replaceable scenes or visual helpers.
- Future art changes should not require rewriting time, farming, inventory, crop, or interaction rules.
- New world objects should generally be PackedScenes with stable interaction/collision roots and replaceable visual children.
- New item and crop presentation should move toward data Resources rather than hardcoded visual matches.

The persistent Cursor rule is in `.cursor/rules/logic-visual-separation.mdc`.

## 2. Engine and Project Configuration

`project.godot` configures:

- Godot 4.6.
- Forward Plus rendering.
- Jolt as the configured 3D physics backend, although gameplay is 2D.
- Main scene: `MainFarmSpring.tscn`.
- Base viewport: 1280×720.
- Fullscreen window mode.
- `canvas_items` stretch mode.
- `expand` stretch aspect.
- Black default clear color.
- Nearest-neighbor canvas texture filtering, suitable for pixel art.

There is currently no:

- Save/load system.
- Controller support.
- Input rebinding UI.
- Audio system.
- Animation system.
- Scene transition system.
- Economy, shop, quest, NPC, dialogue, stamina, or combat system.

## 3. Autoload Order and Responsibilities

Autoloads load in this order:

1. `GameState` — `autoload/game_state.gd`
2. `GameTime` — `autoload/game_time.gd`
3. `Inventory` — `autoload/inventory.gd`
4. `Soil` — `autoload/soil.gd`
5. `LocationHud` — `ui/location_hud.tscn`
6. `InventoryHud` — `ui/inventory_hud.tscn`

### GameState

State:

- `current_location_name`, initially empty.

Signal:

- `location_changed(location_name)`.

Behavior:

- `set_location()` updates the location only if the name changed.
- Duplicate location values do not emit again.

### GameTime

Signals:

- `time_changed(hour, minute)`
- `date_changed(day, season, year)`
- `season_changed(season, year)`
- `year_changed(year)`

Calendar:

- Four seasons in order: Spring, Summer, Fall, Winter.
- 28 days per season.
- Year increments after Winter 28.
- Initial date: Spring 1, Year 1.
- Initial time: 06:00.

Time speed:

- One real second equals one in-game minute.
- One uninterrupted in-game day lasts 24 real minutes.
- One uninterrupted season lasts 11.2 real hours.
- One uninterrupted year lasts 44.8 real hours.
- A delta accumulator and `while` loop preserve elapsed minutes after slow frames.

Midnight:

- Minute rolls from 59 to 0.
- Hour increments.
- Hour 24 becomes hour 0.
- Calendar advances one day.
- If appropriate, year and season signals emit.
- `date_changed` emits once.
- `time_changed(0, 0)` emits after the date update.

Sleep:

- `sleep_to_next_morning(wake_hour = 6)` clears fractional accumulated time.
- It advances the calendar exactly one day through the same `_advance_day()` path as midnight.
- It then clamps the wake hour to 0–23.
- Minutes become 0.
- It emits `time_changed`.
- It does not emit a second `date_changed`.
- Crop growth and water reset therefore happen exactly once per sleep.

Pause:

- `GameTime.paused` is a custom boolean.
- It stops only the time autoload.
- It does not pause the SceneTree.
- The inventory menu controls this flag.

Missing time features:

- No time-of-day lighting.
- No forced bedtime.
- No day-end penalty.
- No sleep confirmation or fade.
- No weather.
- No environmental/ambient audio tied to season or time of day (idea to design toward: summer nights playing cricket/insect chirping — see the "Environmental & Time-of-Day Audio (Idea)" note in section 39).
- No holidays or weekday system.
- No stamina restoration.
- No restriction against sleeping repeatedly or during the morning.

### Inventory

Owns all hotslot and inventory stack state, selection state, inventory-menu state, item IDs, stack operations, and current placeholder item presentation.

### Soil

Owns all tilled, watered, planted, and crop-stage gameplay state. It also currently owns procedural soil and water placeholder visuals and spawns crop world scenes.

### HUD autoloads

Location HUD and Inventory HUD are persistent CanvasLayer scenes independent of the farm scene.

## 4. Input Map

Movement:

- `W`: up.
- `A`: left.
- `S`: down.
- `D`: right.

World actions:

- Left mouse: `use_item`.
- Right mouse: `interact`.

Inventory:

- `E`: open inventory.
- `Escape`: close inventory.
- `1` through `5`: select hotslots.

Current input separation:

- Left-click is exclusively for the selected farming tool or seed.
- Right-click is exclusively for the interactable-object system.
- Mature crops are interactable objects, so harvesting is right-click.
- Bed interaction is also right-click.
- `E` does not toggle inventory closed; only Escape closes it.

Input limitations:

- No alternate movement keys or arrows.
- No gamepad or touch mappings.
- No mouse-wheel hotslot selection.
- No configurable controls.

## 5. Main Runtime Scene

`MainFarmSpring.tscn` is the only complete runtime farm scene.

Tree:

- Root `Node2D`
  - `location_info.gd`
  - `display_name = "Spring Farm"`
- `SeasonalFarmTiles`
  - `locations/seasonal_farm_tiles.gd`
- `TileMap`
  - group: `farm_tilemap`
  - three tile layers
- `Player`
  - instance of `player/player.tscn`
  - position `(256, 256)`
- `Bed`
  - instance of `interactables/bed/bed.tscn`
  - position `(304, 256)`

The active location label remains `"Spring Farm"` even when the visual season changes.

## 6. Seasonal Farm Rendering

Seasonal assets:

- `assets/MainFarm/SpringGround.png`
- `assets/MainFarm/SummerGround.png`
- `assets/MainFarm/FallGround.png`
- `assets/MainFarm/WinterGround.png`

Seasonal template scenes:

- `MainFarmSummer.tscn`
- `MainFarmFall.tscn`
- `MainFarmWinter.tscn`

These three scenes are templates, not complete gameplay scenes. They contain a root and TileMap but no player, bed, location setup, seasonal controller, or `farm_tilemap` group.

TileMap layout:

- Layer 0: seasonal ground.
- Layer 1: foliage.
- Layer 2: additional foliage.
- Map is approximately 32×32 cells.
- Default tile size is 16×16.
- Seasonal textures are 128×128 atlases.

TileSet source IDs are consistent across all four farm scenes:

- Source 0: Fall.
- Source 1: Spring.
- Source 2: Summer.
- Source 3: Winter.

`locations/seasonal_farm_tiles.gd`:

- Snapshots Spring layers from the active TileMap.
- Instantiates Summer, Fall, and Winter template scenes temporarily.
- Snapshots every used cell on every TileMap layer.
- Stores cell position, source ID, atlas coordinates, and alternative tile.
- Frees the temporary template roots.
- Subscribes to `GameTime.season_changed`.
- Clears and restores active TileMap cells for the new season.
- Applies the current season during startup.

This preserves:

- Player instance and position.
- Bed.
- Inventory state.
- Tilled cells.
- Water state.
- Planted crops.
- Crop stages.
- Crop interactable scenes.

Winter currently has ground but no foliage cells on layers 1 or 2.

Season system assumptions:

- Every seasonal scene uses compatible layer counts.
- TileSet numeric source IDs remain identical.
- The active TileSet contains the sources referenced by template cells.
- Only tile cells are copied; layer names and metadata are not changed.

## 7. Location HUD

Files:

- `ui/location_hud.tscn`
- `ui/location_hud.gd`

CanvasLayer:

- Layer 10.

Position:

- Top-right.
- Approximately 248 pixels wide.
- Displays three vertically stacked labels.

Content:

1. Location name.
2. Date, formatted as `Spring 1, Year 1`.
3. 24-hour clock, formatted as `06:00`.
4. Camera zoom row: a `-` button, a percentage label, and a `+` button (added after this document's 2026-08-14 audit; see "Camera Zoom Control" below and the section 39 addendum).

Subscriptions:

- `GameState.location_changed`.
- `GameTime.date_changed`.
- `GameTime.time_changed`.

Placeholder styling:

- White/light text.
- Dark outlines.
- Right alignment.
- No final panel art.

Known issue:

- Display-only controls use default mouse filtering and may consume clicks in the top-right rectangle.

### Camera Zoom Control

- `-`/`+` buttons step `zoom_percent` between 60 and 120 in increments of 10, starting at 100.
- `zoom_percent` is applied as a multiplier of the Player `Camera2D`'s zoom at the moment it was first found (`_base_camera_zoom`), found via `get_viewport().get_camera_2d()`.
- This is the only place a HUD script reaches directly into a world node instead of only listening to autoload signals.
- Zoom state lives on the HUD node only; it is not stored in any autoload and does not persist across a scene reload.
- Buttons disable at the 60% and 120% ends of the range.

## 8. Player

Files:

- `player/player.tscn`
- `player/player.gd`

Scene structure:

- `CharacterBody2D`.
- 16×32 rectangular `CollisionShape2D`.
- Yellow/tan `Polygon2D` placeholder body.
- `Camera2D`.
- `TileTargeter`.
- `ToolUse`.
- `Interactor` Area2D.

Movement:

- Speed is 120 pixels per second.
- Direction comes from `Input.get_vector()`.
- Diagonal movement is normalized.
- Uses `move_and_slide()`.
- Opening inventory sets velocity to zero and blocks movement.

Camera:

- 3× zoom.
- Position smoothing enabled.
- Smoothing speed 8.
- No camera limits.
- No drag margins.

Missing player features:

- No facing direction.
- No idle/walk animation state.
- No acceleration.
- No sprint.
- No stamina.
- No footsteps.
- No action animation.
- No map-boundary collision.

Unused file:

- Root-level `player.tscn` is an empty legacy `CharacterBody2D` and is not referenced by the runtime scene.

## 9. Farm Tile Targeting

File:

- `farming/tile_targeter.gd`

Signal:

- `target_changed(has_target, cell)`.

Current signal has no subscribers.

Behavior each rendered frame:

- Finds the first node in group `farm_tilemap`.
- Reads global mouse position.
- Converts mouse position to a TileMap cell.
- Requires a nonempty source tile on ground layer 0.
- Calculates whether the tile center is within reach.
- Shows a full-tile translucent highlight when valid.

Reach:

- Exported reach radius: 16 pixels.
- Hardcodes a centered 16×32 player body.
- Reach begins from the upper 16×16 half of that body.
- It measures tile-center distance from the closest point on that rectangle.

Placeholder visual:

- Runtime-created white translucent `Polygon2D`.
- z-index 10.

Limitations:

- Player dimensions are duplicated in targeting logic.
- No facing requirement.
- Uses tile center rather than exact clicked point.
- Every nonempty ground-layer cell is targetable.
- No semantic farmable-cell metadata.

## 10. Tool Use

File:

- `player/tool_use.gd`

Input:

- Left mouse through `_unhandled_input`.

Guards:

- Does nothing while the inventory menu is open.
- Requires a valid target from `TileTargeter`.

Dispatch:

- Hoe calls `Soil.till(cell)`.
- Watering can calls `Soil.water(cell)`.
- Rice Seed or Beans Seed calls `Soil.plant(cell, item_id)`.
- One seed is removed only after planting succeeds.
- Produce and unknown items have no left-click behavior.

Harvest is not in this script. It is handled through crop interactables on right-click.

Missing tool mechanics:

- No stamina cost.
- No animation.
- No cooldown.
- No durability.
- No tool upgrades.
- No watering-can capacity or refill.
- No area-of-effect tool actions.

## 11. Soil State and Rules

File:

- `autoload/soil.gd`

Authoritative dictionaries use `Vector2i` TileMap coordinates:

- `_tilled`: cell to true.
- `_planted`: cell to crop ID.
- `_watered`: cell to true.
- `_stages`: cell to integer stage.

Runtime visual caches:

- `_overlays`: cell to tilled-soil `Polygon2D`.
- `_crop_plants`: cell to crop `Area2D`.
- `_water_marks`: cell to water marker `Polygon2D`.

Runtime roots under the active TileMap:

- `TilledSoilOverlays`, z-index 5.
- `CropPlants`, z-index 6.
- `WaterMarks`, z-index 7.

TileMap resolution:

- Uses the first node in group `farm_tilemap`.
- Rebuilds runtime visual roots if the active map changes or roots become invalid.

### Tilling

Requirements:

- Farm TileMap exists.
- Ground layer 0 contains a tile at the cell.
- Cell is not already tilled.

Effect:

- Cell becomes tilled.
- Full-tile brown placeholder overlay is created.

Not checked:

- Crop presence.
- Furniture presence.
- Player overlap.
- Tile metadata.
- Season.
- Ground material.
- Stamina or durability.

### Watering

Requirements:

- Cell is tilled.
- Cell is not already watered.

Plant presence is not required.

Effect:

- Cell becomes watered.
- Tilled overlay becomes blue-gray.
- Small blue water-drop polygon appears.

### Daily growth and water reset

Soil subscribes to `GameTime.date_changed`.

For each planted cell:

- If unwatered, stage does not change.
- If watered and below that crop’s mature stage, stage increases by one.
- Mature crops remain at mature stage.
- Crop visual refreshes after growth.

After growth:

- Every watered cell becomes dry.
- Water markers are freed.
- Tilled overlays return to brown.
- Empty watered soil also becomes dry.

This occurs after:

- Natural midnight.
- Bed sleep.
- Any future system that advances the date through `GameTime._advance_day()`.

### Soil persistence limitations

- State is memory-only.
- Keys contain no location/map identity.
- Loading another unrelated map with matching coordinates would project the same farm state onto it.
- Tilled soil never expires.
- No untill action exists.
- No rain or automatic watering.
- No crop death, rot, weeds, fertilizer, or quality.

## 12. Crop Definitions

File:

- `farming/crop_data.gd`

Crop Resource fields:

- Crop ID.
- Seed item ID.
- Harvest item ID.
- Display name.
- Harvest type.
- Mature stage.
- Regrow stage.
- Placeholder color.

Harvest types:

- `SINGLE_HARVEST`.
- `REGROWABLE`.

Rice:

- Crop ID: `rice`.
- Seed ID: `rice_seed`.
- Harvest item: `rice`.
- Mature stage: 3.
- Single-harvest.
- Yellow-green placeholder color.

Beans:

- Crop ID: `beans`.
- Seed ID: `beans_seed`.
- Harvest item: `beans`.
- Mature stage: 3.
- Regrow stage: 2.
- Regrowable indefinitely.
- Green placeholder color.

Crop lookup:

- `from_seed()` maps seed IDs to crop data.
- `from_id()` maps crop IDs to crop data.
- Lookups are hardcoded `match` statements.
- Every lookup creates a new Resource.
- No `.tres` crop assets exist yet.

## 13. Crop Lifecycle

Planting:

- Requires tilled soil.
- Requires no existing crop.
- Requires a known seed ID.
- Creates crop state at stage 0.
- Spawns a crop interactable scene.
- Successful tool use consumes one seed.

Growth:

- Stage 0: newly planted.
- First watered new day: stage 1.
- Second watered new day: stage 2.
- Third watered new day: stage 3, mature.
- Missing a watering day pauses growth rather than killing the plant.

Harvest capacity check:

- Crop asks Inventory to add one produce item before modifying plant state.
- If the 20-slot inventory cannot fit it, harvest fails.
- The mature crop remains unchanged and harvestable.

Rice harvest:

- Adds Rice ×1.
- Removes planted state.
- Removes stage state.
- Frees the crop scene.
- Leaves the tile tilled.
- Requires a new rice seed to grow again.

Beans harvest:

- Adds Beans ×1.
- Keeps the crop scene and planted state.
- Resets stage to 2.
- One more watered new day returns it to stage 3.
- This cycle repeats indefinitely.

Harvesting currently has:

- No variable yield.
- No quality.
- No experience.
- No seed return.
- No sound.
- No animation.
- No harvest cooldown.

## 14. Crop World Object

Files:

- `interactables/crop/crop_plant.tscn`
- `interactables/crop/crop_plant.gd`

Scene:

- Root `Area2D`.
- Interaction collision layer 2.
- Collision mask 0.
- Monitorable, not monitoring.
- 16×16 interaction shape.
- No `StaticBody2D`.
- No solid collision; the player can walk through crops.
- Placeholder diamond `Polygon2D`.
- Visible stage-number `Label`.

Behavior:

- Extends the common interactable base.
- Stores its soil cell.
- `can_interact()` returns true only when the crop is mature.
- Right-click interaction calls `Soil.harvest(cell)`.
- Immature crops are ignored by nearest-interactable selection.

Visual refresh:

- Reads crop and stage state from Soil.
- Color comes from crop data.
- Scale is `1.0 + stage × 0.25`.
- Label explicitly displays stage 0 through 3.
- Prompt is crop name while immature and `"Harvest"` when mature.

The crop object owns no crop gameplay state. Soil remains authoritative.

## 15. Interactable Framework

Base:

- `interactables/interactable.gd`

Player scanner:

- `player/interactor.gd`

Shared contract:

- Group: `interactable`.
- Physics interaction layer: 2.
- Exported `enabled`.
- Exported `prompt`.
- `can_interact(actor)`.
- `get_interact_prompt()`.
- `interact(actor)`.

Base `_ready()`:

- Adds object to the interactable group.
- Sets collision layer 2.
- Sets collision mask 0.
- Disables monitoring.
- Enables monitorability.

Player Interactor:

- Child Area2D on the player.
- Collision layer 0.
- Collision mask 2.
- Circular range radius 28.
- Tracks overlapping interactable areas.

Right-click:

- Stops if inventory is open.
- Chooses the nearest valid overlapping interactable.
- Uses squared origin distance.
- Calls its `interact(player)`.

Selection is proximity-based, not cursor-based. Right-clicking anywhere while in range interacts with the nearest eligible object.

No implemented:

- Line-of-sight check.
- Cursor-object targeting.
- Interaction prompt HUD.
- Focus outline.
- Tie-break rule beyond overlap-array order.

## 16. Bed

Files:

- `interactables/bed/bed.tscn`
- `interactables/bed/bed.gd`

Interaction:

- Root Area2D.
- 40×40 interaction shape.
- Interaction layer 2.
- Prompt: `"Sleep"`.
- Right-click calls `GameTime.sleep_to_next_morning()`.

Physical body:

- Child `StaticBody2D`.
- Collision layer 1.
- 28×20 collision shape.
- Blocks the player.

Placeholder visuals:

- Mattress Polygon2D.
- Pillow Polygon2D.

Missing:

- Confirmation.
- Fade.
- Sleep animation.
- Player reposition.
- Time restriction.
- Stamina restoration.

## 17. Inventory Data Model

File:

- `autoload/inventory.gd`

Containers:

- Five hotslots.
- Twenty normal inventory slots.
- Inventory UI uses five columns and four rows.

Stack shape:

- Dictionary with `id` and `quantity`.

Maximum stack:

- 99 for every item.

Initial hotslots:

1. Hoe ×1.
2. Rice Seed ×10.
3. Beans Seed ×10.
4. Watering Can ×1.
5. Empty.

Normal inventory starts empty.

Item IDs:

- Empty string.
- `hoe`.
- `watering_can`.
- `rice_seed`.
- `beans_seed`.
- `rice`.
- `beans`.

Selection:

- Selected hotslot starts at index 0.
- Keys 1–5 select.
- Clicking a hotslot selects.
- Selecting the already-selected index emits nothing.

Adding:

- `try_add_item()` rejects empty IDs and nonpositive amounts.
- Capacity is preflighted by building a placement plan (`_plan_add_item()`) before anything is mutated.
- Existing matching stacks fill first (hotslots, then inventory).
- **Changed since this document's 2026-08-14 audit** (see section 39 addendum): empty slots now fill hotslots before the inventory grid, trying the *currently selected* hotslot first. Harvested produce and other newly-added items CAN now land directly in an empty selected hotslot — this line previously read "Harvested produce never automatically enters hotslots," which is no longer accurate.
- Addition is all-or-nothing.

Removing:

- Rejects invalid, empty, nonpositive, or insufficient requests.
- Quantity 0 clears the stack.
- Seed use removes from selected hotslot only after planting succeeds.

Drag/drop:

- Empty sources cannot drag.
- Same source/destination is a no-op.
- Different item IDs swap whole stacks.
- Matching IDs merge to 99.
- Overflow remains in the source.
- Full matching destination is a no-op.

Inventory signals:

- `inventory_changed`.
- `selection_changed(hotslot_index)`.
- `menu_visibility_changed(is_open)`.

The menu-visibility signal currently has no subscriber.

Limitations:

- Public arrays and dictionaries can bypass validation.
- Unknown container kinds default to normal inventory.
- UI validates drag payload weakly.
- No split stack.
- No sorting.
- No dropping or trashing.
- No equipment.
- No per-item stack limits.
- Tools could theoretically stack to 99.
- No persistence.

## 18. Item Presentation

Current display names and colors are hardcoded in `Inventory` using item-ID matches.

Placeholder presentation:

- Hoe: brown.
- Watering can: blue.
- Rice Seed: yellow-green.
- Beans Seed: dark green.
- Rice: pale yellow.
- Beans: green.

`inventory/item_data.gd` defines an `ItemData` Resource with:

- ID.
- Display name.
- Icon color.
- Static factory.

It is currently unused. The Inventory autoload duplicates those responsibilities.

Future art cleanup:

- Make ItemData authoritative.
- Add Texture2D icon references.
- Give tools, seeds, and produce per-item stack limits.
- Remove presentation matches from gameplay Inventory logic.

## 19. Inventory HUD

Files:

- `ui/inventory_hud.tscn`
- `ui/inventory_hud.gd`
- `ui/inventory_slot.gd`

CanvasLayer:

- Layer 11, above Location HUD layer 10.

Persistent hotslots:

- Bottom centered.
- Bottom region height: 84 pixels.
- Five 52×56 slots.
- Eight-pixel spacing.
- Visible during normal gameplay and while inventory is open.

Inventory popup:

- Opened with E.
- Closed with Escape.
- Full-screen translucent dim.
- Center panel minimum 420×300.
- Center area excludes the bottom hotslot region.
- Twenty 60×64 inventory slots.
- Five columns.
- Hint explains drag/drop and Escape.

While open:

- Time pauses.
- Movement stops.
- Tool use stops.
- Interactions stop.
- Hotslots remain above the dim and stay interactive.
- Number keys still change selected hotslot.

Slot behavior:

- Root Panel catches mouse input.
- Child labels/icons ignore mouse input.
- Left-click hotslot selects.
- Dragging starts only from nonempty slots.
- Drag preview is a colored 40×30 Panel.
- Drops call Inventory stack movement.

Slot visuals:

- ColorRect placeholder icon.
- Item-name label.
- Quantity label shown only above one.
- Hotslot index label.
- Gold selected border.
- Blue-gray hover border.
- Gray normal border.

Mouse layering:

- Hotslot containers ignore mouse so only slot panels catch clicks.
- Hotslot subtree comes after InventoryMenu and is therefore above it.
- Fullscreen menu/dim blocks world clicks elsewhere.

## 20. Physics and Collision Layers

Project collision layer names are not configured.

Numeric layer 1:

- Player solid body.
- Bed StaticBody2D.

Player:

- Collision layer 1.
- Collision mask 1.

Bed body:

- Collision layer 1.
- Collision mask 0.

Numeric layer 2:

- Bed interaction Area2D.
- Crop interaction Area2D.
- All base interactables.

Player Interactor:

- Layer 0.
- Mask 2.

TileSet maps currently contain no physics layers or collision polygons. Therefore:

- Ground does not block movement.
- Foliage does not block movement.
- Map edges do not block movement.
- Only explicit solid objects, currently the bed, block movement.

## 21. Render and UI Layers

Canvas layers:

- World: canvas layer 0.
- Location/date/time HUD: canvas layer 10.
- Inventory/hotslots: canvas layer 11.

World z-index:

- Base TileMap/player/bed: 0.
- Tilled-soil overlays: 5.
- Crop root: 6.
- Crop scene root: 6 relative to parent.
- Water marks: 7.
- Tile target highlight: 10.

Because crop root and crop scene both have relative z-index 6, crop content can effectively render at z-index 12. This is an accidental double offset and can place crops above the target highlight.

There is no y-sorting. Player and bed depth at equal z depends on tree order rather than world Y.

## 22. Placeholder Visual Inventory

Production-ish current art:

- Four seasonal farm PNG atlases.
- Matching Aseprite source files exist for farm ground.

Placeholder visuals:

- Player Polygon2D.
- Bed mattress and pillow Polygon2D.
- Crop diamond Polygon2D.
- Crop numeric stage label.
- Tilled soil runtime Polygon2D.
- Watered-soil tint.
- Water-drop runtime Polygon2D.
- Tile target Polygon2D.
- Inventory ColorRect icons.
- Colored drag preview.
- Default UI panels and fonts.

Player Aseprite run sources exist under `aseprite/Player`, but exported spritesheets and animation nodes are not wired into the game.

## 23. Visual-Replacement Boundaries

Already scene-based and easy to replace:

- Player body inside `player/player.tscn`.
- Bed visuals inside `interactables/bed/bed.tscn`.
- Crop visuals inside `interactables/crop/crop_plant.tscn`.
- Seasonal ground PNGs if atlas layout remains compatible.

Needs a cleanup adapter before final art:

- Soil overlays are constructed directly in Soil logic.
- Water marks are constructed directly in Soil logic.
- Tile target highlight is constructed in targeting logic.
- Inventory icons, names, and colors are hardcoded in Inventory.
- Crop script knows exact Sprout and StageLabel nodes.
- Target reach knows exact player placeholder dimensions.
- Numeric physics layers are duplicated.

Intended direction:

- Add dedicated visual children/controllers with methods such as `set_stage()` and `play_state()`.
- Keep Soil authoritative but move rendering to a SoilVisual helper or scene.
- Move item presentation into ItemData Resources.
- Move crop presentation/animation references into crop resources.
- Replace numeric collision constants with named project layers.
- Keep interaction and collision roots stable while swapping Sprite2D, AnimatedSprite2D, AnimationPlayer, particles, and sounds beneath them.

## 24. Complete Gameplay Loops

### Basic farming loop

1. Move with WASD.
2. Select Hoe with 1.
3. Aim a nearby ground tile with mouse.
4. Left-click to till.
5. Select Rice Seed with 2 or Beans Seed with 3.
6. Left-click tilled soil to plant stage 0.
7. Select Watering Can with 4.
8. Left-click tilled soil to water.
9. Right-click bed while nearby to sleep.
10. Date advances.
11. Watered crops gain one stage.
12. All watered soil dries.
13. Repeat until stage 3.
14. Right-click near the mature crop to harvest.

### Rice loop

- Three watered day changes to mature.
- Right-click harvest produces Rice ×1.
- Plant disappears.
- Soil remains tilled.
- New rice seed is required.

### Beans loop

- Three watered day changes to mature.
- Right-click harvest produces Beans ×1.
- Plant remains at stage 2.
- One watered day change makes it mature again.
- Repeats indefinitely.

### Inventory loop

- Press E.
- Time, movement, tool use, and interaction stop.
- Drag stacks between normal inventory and hotslots.
- Matching stacks merge to 99.
- Different stacks swap.
- Click a hotslot or press 1–5 to select.
- Press Escape to resume.

### Seasonal loop

- Calendar advances through 28-day seasons.
- Season transition emits `season_changed`.
- Active TileMap layers switch to the corresponding seasonal template.
- Farm object and gameplay state remain live.

## 25. Signals and Current Consumers

Consumed:

- `GameState.location_changed` → Location HUD.
- `GameTime.time_changed` → Location HUD.
- `GameTime.date_changed` → Location HUD and Soil.
- `GameTime.season_changed` → SeasonalFarmTiles.
- `Inventory.inventory_changed` → Inventory HUD.
- `Inventory.selection_changed` → Inventory HUD.

Emitted but unused:

- `GameTime.year_changed`.
- `Inventory.menu_visibility_changed`.
- `TileTargeter.target_changed`.

API currently unused:

- `Interactable.get_interact_prompt()`.
- `Inventory.get_selected_quantity()`.
- `ItemData.make()`.

## 26. Known Architecture Risks

Highest-priority risks:

1. Soil cell state has no location identity.
2. Every nonempty ground tile is considered farmable.
3. Seasonal swapping depends on numeric TileSet source-ID parity.
4. Main farm layer names and location display remain Spring-specific.
5. World terrain has no collision.
6. No y-sorting.
7. Crop z-index is effectively doubled.
8. Display-only Location HUD may block world mouse input.
9. Interaction is nearest-by-proximity, not cursor-targeted.
10. Inventory pause can overwrite future pause reasons because it directly sets one boolean.
11. Inventory presentation remains in gameplay logic.
12. Soil still constructs permanent placeholder visuals.
13. Crop factories are hardcoded and allocate new Resources per lookup.
14. Public singleton fields allow unvalidated mutation.
15. Malformed external drag data can trigger invalid inventory operations.
16. No persistence exists.

## 27. Files by Responsibility

Project:

- `project.godot` — engine, autoload, display, input, physics, rendering settings.

World scenes:

- `MainFarmSpring.tscn` — complete runtime farm.
- `MainFarmSummer.tscn` — Summer tile template.
- `MainFarmFall.tscn` — Fall tile template.
- `MainFarmWinter.tscn` — Winter tile template.

Autoload gameplay:

- `autoload/game_state.gd`
- `autoload/game_time.gd`
- `autoload/inventory.gd`
- `autoload/soil.gd`

Player:

- `player/player.tscn`
- `player/player.gd`
- `player/tool_use.gd`
- `player/interactor.gd`
- `player.tscn` — unused legacy stub.

Farming:

- `farming/tile_targeter.gd`
- `farming/crop_data.gd`

Interactables:

- `interactables/interactable.gd`
- `interactables/bed/bed.gd`
- `interactables/bed/bed.tscn`
- `interactables/crop/crop_plant.gd`
- `interactables/crop/crop_plant.tscn`

Inventory:

- `inventory/item_data.gd` — unused future Resource.

Locations:

- `locations/location_info.gd`
- `locations/seasonal_farm_tiles.gd`

UI:

- `ui/location_hud.gd`
- `ui/location_hud.tscn`
- `ui/inventory_hud.gd`
- `ui/inventory_hud.tscn`
- `ui/inventory_slot.gd`

Authoring and assets:

- `assets/MainFarm/*.png` — imported seasonal maps.
- `aseprite/MainFarm/Ground/*` — farm source artwork.
- `aseprite/Player/*` — player run-animation source files, not yet exported or wired.
- `icon.svg` — project icon.

Every active script has a `.gd.uid` sidecar. Some manually-authored scenes and ext-resource entries do not carry stable scene/script UIDs, but path-based loading currently works.

## 28. Explicitly Not Implemented Yet

- Save/load and serialization.
- Multiple playable locations.
- Location-specific soil stores.
- Indoor/outdoor transitions.
- Farmable metadata or restricted plots.
- Terrain collision and map boundaries.
- Weather and rain watering.
- Crop season restrictions or seasonal death.
- Harvest quality, variable yield, crop XP.
- Selling, buying, money, shops.
- Stamina, health, hunger.
- Tool durability, upgrades, capacity, refill.
- Stack splitting, sorting, dropping, trashing.
- Equipment and character stats.
- NPCs, schedules, dialogue, quests.
- Interaction prompt UI.
- Cursor-specific object interaction.
- Animation, VFX, SFX, music.
- Environmental/ambient audio driven by season and time of day (e.g. summer-night cricket/insect chirping) — see section 39 for the idea note.
- Sleep fade/confirmation.
- Time-of-day lighting.
- Day-end failure conditions.
- Controller/touch support.
- Accessibility and key rebinding.
- Automated gameplay tests.

This file should be updated whenever a system’s rules, ownership, input, layer, or visual boundary changes.

## 29. Complete Authored-File Manifest

This section extends every earlier system description with a file-by-file inventory. It covers every file returned by Git as tracked or currently untracked and not ignored. Binary art is described by format, dimensions, frames, layers, runtime usage, and import relationship rather than reproducing raw binary bytes.

Ignored/generated directories are documented separately in section 37.

### Repository and editor metadata

#### `.editorconfig`

- Marks this folder as the configuration root.
- Sets UTF-8 as the character set for all files.
- Contains no language-specific indentation override.

#### `.gitattributes`

- Enables automatic text-file detection.
- Normalizes repository text line endings to LF.

#### `.gitignore`

- Ignores `.godot/`.
- Ignores a root `android/` export/build directory.
- Ignores `.DS_Store`.

#### `.cursor/rules/logic-visual-separation.mdc`

- Always-applied Cursor project rule.
- Declares gameplay state authoritative.
- Requires visuals to render state and forward intent.
- Requires replaceable scene-based visual children.
- Encourages narrow APIs such as `refresh_visual()` and `set_stage()`.
- Prevents gameplay rules from relying on sprites, frames, colors, or visibility.
- Directs item/crop presentation toward Resources.
- Requires named references and collision layers where possible.
- Requires temporary visual coupling to be recorded in this document.

#### `GAME_SYSTEMS_SUMMARY.md`

- This overall project document.
- Contains the architecture, logic, scene, input, layer, content, artwork, risk, and complete-file audits.
- Intended to remain current as systems are added or changed.

## 30. Complete Configuration and Scene-File Contents

### `project.godot`

- Godot configuration version 5.
- Project name: `demo3`.
- Engine features: Godot 4.6 and Forward Plus.
- Main scene: `MainFarmSpring.tscn`.
- Project icon: `icon.svg`.
- Autoload sequence:
  - `GameState` from `autoload/game_state.gd`.
  - `GameTime` from `autoload/game_time.gd`.
  - `Inventory` from `autoload/inventory.gd`.
  - `Soil` from `autoload/soil.gd`.
  - `LocationHud` from `ui/location_hud.tscn`.
  - `InventoryHud` from `ui/inventory_hud.tscn`.
- Display:
  - 1280×720 base viewport.
  - Fullscreen mode.
  - `canvas_items` stretch.
  - `expand` aspect.
- Rendering:
  - Black default clear color.
  - Nearest-neighbor canvas texture filtering.
- Physics:
  - Jolt selected as the 3D physics engine.
- Input actions:
  - `move_left`: physical A.
  - `move_right`: physical D.
  - `move_up`: physical W.
  - `move_down`: physical S.
  - `use_item`: left mouse.
  - `interact`: right mouse.
  - `open_inventory`: physical E.
  - `close_inventory`: Escape.
  - `hotbar_1` through `hotbar_5`: physical 1 through 5.

### `MainFarmSpring.tscn`

- UID: `uid://dxho2ur3rl2co`.
- Complete configured main scene.
- Root `Node2D` uses `locations/location_info.gd`.
- Root display name is `"Spring Farm"`.
- Child `SeasonalFarmTiles` uses `locations/seasonal_farm_tiles.gd`.
- Child `TileMap` belongs to group `farm_tilemap`.
- TileMap has:
  - Layer 0: `Spring Ground`.
  - Layer 1: `Foliage1`.
  - Layer 2: `Foliage2`.
- Embeds TileSet atlas definitions for all four seasonal PNGs.
- Uses Spring source ID 1 for its painted cells.
- Instances `player/player.tscn` at `(256, 256)`.
- Instances `interactables/bed/bed.tscn` at `(304, 256)`.
- This is the only seasonal farm file containing complete gameplay objects.

### `MainFarmSummer.tscn`

- UID: `uid://c0vwkl8i40fox`.
- TileMap data template.
- Root `Node2D` plus one three-layer TileMap.
- Layers:
  - `Summer Ground`.
  - `Foliage1`.
  - `Foliage2`.
- Embeds all four seasonal atlas sources.
- Painted cells use Summer source ID 2.
- Contains no scripts, player, bed, seasonal controller, or farm group.
- Instantiated temporarily by `seasonal_farm_tiles.gd` only to read tile cells.

### `MainFarmFall.tscn`

- UID: `uid://bsnjvssh4xkre`.
- TileMap data template.
- Root plus `Fall Ground`, `Foliage1`, and `Foliage2`.
- Embeds all four seasonal atlas sources.
- Painted cells use Fall source ID 0.
- Contains no runtime actors or scripts.
- Used as seasonal snapshot data.

### `MainFarmWinter.tscn`

- UID: `uid://bvpnjaug3s65n`.
- TileMap data template.
- Root plus `Winter Ground`, `Foliage1`, and `Foliage2`.
- Painted ground uses Winter source ID 3.
- Both foliage layers exist but contain no painted cells.
- Contains no runtime actors or scripts.
- Used as seasonal snapshot data.

### `player/player.tscn`

- UID: `uid://cq8player00001`.
- Functional player PackedScene.
- Root `CharacterBody2D` uses `player/player.gd`.
- Collision layer 1 and mask 1.
- Child collision rectangle: 16×32.
- Child `Body`: tan/yellow placeholder `Polygon2D`.
- Child `Camera2D`:
  - Zoom 3×.
  - Position smoothing enabled.
  - Smoothing speed 8.
- Child `TileTargeter` uses `farming/tile_targeter.gd`.
- Child `ToolUse` uses `player/tool_use.gd`.
- Child `Interactor`:
  - Area2D.
  - Uses `player/interactor.gd`.
  - Collision layer 0.
  - Collision mask 2.
  - Circular range radius 28.

### `player.tscn`

- UID: `uid://bw40sholh6y8m`.
- Contains only an empty `CharacterBody2D` named `player`.
- Has no script, collision, visuals, or children.
- No other project file references it.
- Legacy/dead scene, distinct from `player/player.tscn`.

### `interactables/bed/bed.tscn`

- Root Area2D uses `bed.gd`.
- Interaction layer 2.
- 40×40 interaction collision rectangle.
- Child `Body` contains:
  - `StaticBody2D` on collision layer 1.
  - 28×20 solid collision rectangle.
  - Mattress placeholder Polygon2D.
  - Pillow placeholder Polygon2D.
- Root interaction area is non-monitoring and monitorable through the base script.
- Instanced by `MainFarmSpring.tscn`.

### `interactables/crop/crop_plant.tscn`

- Root Area2D uses `crop_plant.gd`.
- Interaction layer 2, mask 0.
- Relative z-index 6.
- 16×16 interaction collision rectangle.
- Child `Sprout`: diamond-shaped placeholder Polygon2D.
- Child `StageLabel`: centered outlined number.
- No StaticBody2D, so crops do not block movement.
- Spawned dynamically by Soil.

### `ui/location_hud.tscn`

- CanvasLayer 10.
- Root script: `ui/location_hud.gd`.
- Top-right MarginContainer, approximately 248 pixels wide.
- VBox contains:
  - Location label.
  - Date label.
  - Time label.
- Labels are right-aligned, outlined, and use different font sizes.
- Initial placeholder date is Spring 1, Year 1.
- Initial time is 06:00.
- Controls retain default mouse filtering.

### `ui/inventory_hud.tscn`

- CanvasLayer 11.
- Root script: `ui/inventory_hud.gd`.
- Hidden fullscreen `InventoryMenu`:
  - Input-blocking root.
  - Semitransparent black `Dim`.
  - Center area that excludes the bottom 84 pixels.
  - Panel with minimum size 420×300.
  - Inventory title.
  - Five-column `InventoryGrid`.
  - Drag/Escape hint.
- Separate `HotbarMargin` after the menu in scene order:
  - Anchored to the bottom 84 pixels.
  - Centered `HotslotsRow`.
  - Remains visible and interactive over the open menu.

## 31. Complete Script and UID Contents

Every `.gd.uid` file contains one stable Godot script UID and no gameplay code.

### `autoload/game_state.gd`

- Extends Node.
- Signal: `location_changed(location_name: String)`.
- State: `current_location_name = ""`.
- `set_location(location_name)`:
  - Returns if unchanged.
  - Stores the new name.
  - Emits the signal.

### `autoload/game_state.gd.uid`

- `uid://bl5squ5strgyy`.

### `autoload/game_time.gd`

- Extends Node.
- Defines `Season` enum: Spring, Summer, Fall, Winter.
- Defines season-name array.
- Constants:
  - One real second per game minute.
  - 28 days per season.
- Signals:
  - `time_changed`.
  - `date_changed`.
  - `season_changed`.
  - `year_changed`.
- Public state:
  - Hour 6.
  - Minute 0.
  - Day 1.
  - Spring.
  - Year 1.
  - `paused = false`.
- `_process(delta)` accumulates real seconds and advances all complete game minutes.
- `_advance_minute()` handles minute/hour/day rollover and emits time.
- `_advance_day()` handles day/season/year rollover and ordered signals.
- `sleep_to_next_morning()` advances one date, clamps wake hour, resets minute/accumulator, and emits time once.
- Formatting helpers return zero-padded clock and season/day/year strings.

### `autoload/game_time.gd.uid`

- `uid://dm8nqixx4618n`.

### `autoload/inventory.gd`

- Extends Node.
- Defines:
  - Hotslot and inventory container-kind strings.
  - Five hotslots.
  - Twenty inventory slots.
  - Five inventory columns.
  - Max stack 99.
  - All tool, seed, crop, and empty item IDs.
- Signals:
  - `inventory_changed`.
  - `selection_changed`.
  - `menu_visibility_changed`.
- Public arrays:
  - `hotslots`.
  - `items`.
- Initial state:
  - Hoe ×1.
  - Rice Seed ×10.
  - Beans Seed ×10.
  - Watering Can ×1.
  - One empty hotslot.
  - Twenty empty inventory slots.
- Implements:
  - Menu-open state and GameTime pause.
  - Hotslot selection.
  - Safe item and quantity reads.
  - Selected item and quantity reads.
  - Atomic item addition to normal inventory.
  - Item removal.
  - Selected-hotslot removal.
  - Cross-container stack swap/merge.
  - Placeholder display-name and color lookup.
  - Seed-ID recognition.
  - Internal capacity, stack, container, and stack-construction helpers.

### `autoload/inventory.gd.uid`

- `uid://btsrr1gpuiy2g`.

### `autoload/soil.gd`

- Extends Node.
- Preloads `crop_data.gd` and `crop_plant.tscn`.
- Constants:
  - Dry tilled color.
  - Watered tilled color.
  - Water marker color.
  - Planted stage 0.
- Authoritative state:
  - `_tilled`.
  - `_planted`.
  - `_watered`.
  - `_stages`.
- Visual caches:
  - `_overlays`.
  - `_crop_plants`.
  - `_water_marks`.
- Resolves the first grouped `farm_tilemap`.
- Rebuilds visual roots when needed.
- `till()` validates ground and creates tilled state/visual.
- `plant()` validates tilled/unplanted/known seed state, stores crop ID and stage 0, and creates CropPlant.
- `water()` accepts any dry tilled cell, including empty soil.
- `get_stage()`, `get_crop()`, and `is_harvestable()` expose crop state.
- `harvest()`:
  - Requires maturity.
  - Atomically inserts one produce item.
  - Removes single-harvest crops.
  - Resets regrowable crops.
- `on_new_day()`:
  - Grows watered crops up to maturity.
  - Refreshes crop visuals.
  - Clears all watering.
- Procedurally constructs tilled rectangles and water-drop polygons.

### `autoload/soil.gd.uid`

- `uid://b0h4wrvri03na`.

### `farming/crop_data.gd`

- Extends Resource.
- Harvest enum:
  - `SINGLE_HARVEST`.
  - `REGROWABLE`.
- Exported fields:
  - `id`.
  - `seed_item_id`.
  - `harvest_item_id`.
  - `display_name`.
  - `harvest_type`.
  - `mature_stage`.
  - `regrow_stage`.
  - `color`.
- Static generic `make()` factory.
- Static Rice definition:
  - Rice IDs.
  - Single harvest.
  - Mature stage 3.
  - Yellow-green placeholder.
- Static Beans definition:
  - Beans IDs.
  - Regrowable.
  - Mature stage 3.
  - Regrow stage 2.
  - Green placeholder.
- Static lookups from seed ID and crop ID.

### `farming/crop_data.gd.uid`

- `uid://xlxh8glydqor`.

### `farming/tile_targeter.gd`

- Extends Node2D.
- Signal: `target_changed`.
- Exports:
  - Reach radius 16.
  - Ground layer 0.
  - Highlight color.
- Tracks `targeted_cell` and `has_target`.
- Resolves grouped farm TileMap.
- Each frame:
  - Converts global mouse position to a map cell.
  - Requires layer-0 tile data.
  - Calculates reach from a hardcoded upper-player rectangle.
  - Shows/hides procedural highlight.
  - Emits only when target state changes.

### `farming/tile_targeter.gd.uid`

- `uid://di0h2t4f1djgr`.

### `interactables/interactable.gd`

- Extends Area2D.
- Constants:
  - Group name `interactable`.
  - Interaction layer 2.
- Exports `enabled` and `prompt`.
- `_ready()` enforces group and collision/monitoring settings.
- Default `can_interact()` returns enabled.
- `get_interact_prompt()` returns prompt.
- `interact()` is an empty override point.

### `interactables/interactable.gd.uid`

- `uid://bgyx5xmd8boek`.

### `interactables/bed/bed.gd`

- Extends the interaction base by path.
- `_ready()` calls base and sets prompt to `"Sleep"`.
- `interact()` checks enabled and calls `GameTime.sleep_to_next_morning()`.

### `interactables/bed/bed.gd.uid`

- `uid://co77n2pfxff0h`.

### `interactables/crop/crop_plant.gd`

- Extends the interaction base by path.
- Stores a TileMap cell.
- Caches `Sprout` and `StageLabel`.
- `setup(cell)` sets authoritative cell reference and refreshes.
- `can_interact()` requires enabled and `Soil.is_harvestable(cell)`.
- `interact()` delegates to `Soil.harvest(cell)`.
- `refresh_visual()`:
  - Reads Soil crop and stage.
  - Uses crop color.
  - Scales placeholder by stage.
  - Displays numeric stage.
  - Sets prompt to crop name or Harvest.

### `interactables/crop/crop_plant.gd.uid`

- `uid://cwkgo5ty8p0vw`.

### `inventory/item_data.gd`

- `class_name ItemData`.
- Extends Resource.
- Exports:
  - ID.
  - Display name.
  - Icon color.
- Static `make()` factory.
- Currently unused.

### `inventory/item_data.gd.uid`

- `uid://b36wigt22i27m`.

### `locations/location_info.gd`

- Extends Node.
- Exported display name defaults to `"Unknown"`.
- `_ready()` sends the configured name to GameState.

### `locations/location_info.gd.uid`

- `uid://f3plem6ftesb`.

### `locations/seasonal_farm_tiles.gd`

- Extends Node.
- Maps Summer, Fall, and Winter enum values to corresponding template scenes.
- Keeps a season-to-layer-snapshot dictionary.
- On ready:
  - Resolves sibling TileMap.
  - Snapshots active Spring data.
  - Loads and snapshots each other season.
  - Connects season change.
  - Applies current season.
- Snapshot fields:
  - Cell position.
  - Source ID.
  - Atlas coordinates.
  - Alternative/transform value.
- Applying:
  - Clears each active layer.
  - Rewrites all cached cells.
- Emits errors for missing templates, maps, or season snapshots.

### `locations/seasonal_farm_tiles.gd.uid`

- `uid://43rdjl6au77d`.

### `player/player.gd`

- Extends CharacterBody2D.
- Exported speed 120.
- Reads normalized four-direction input in `_physics_process`.
- Stops and resolves movement while inventory is open.
- Otherwise applies velocity and calls `move_and_slide()`.

### `player/player.gd.uid`

- `uid://dmk3mu21n4phd`.

### `player/interactor.gd`

- Extends Area2D.
- Maintains overlapping interactable Area2Ds.
- Connects area-entered and area-exited.
- Right-click:
  - Stops while inventory is open.
  - Chooses nearest valid enabled overlap.
  - Calls interaction.
  - Marks handled only when an object is used.
- Filters by group and method availability.

### `player/interactor.gd.uid`

- `uid://vusdtixjgwhj`.

### `player/tool_use.gd`

- Extends Node.
- Exports a TileTargeter NodePath.
- Resolves TileTargeter on ready.
- Handles left-click in `_unhandled_input`.
- Stops while inventory is open.
- Uses targeted cell and selected hotslot.
- Dispatch:
  - Hoe → till.
  - Watering Can → water.
  - Any recognized seed → plant and consume one on success.
- Does not harvest.

### `player/tool_use.gd.uid`

- `uid://bwbvlgm2mrtgo`.

### `ui/inventory_hud.gd`

- Extends CanvasLayer.
- Preloads `inventory_slot.gd`.
- Constants for hotslot and inventory slot sizes.
- Caches menu, rows, grid, and panel nodes.
- Dynamically creates:
  - Five hotslot widgets.
  - Twenty normal inventory widgets.
- Connects Inventory change and selection signals.
- Handles:
  - E opening.
  - Escape closing.
  - Number-key selection.
- Opening sets Inventory menu state and pauses GameTime.
- Closing clears menu state and resumes GameTime.
- Refreshes both slot collections.
- Applies runtime panel styling.

### `ui/inventory_hud.gd.uid`

- `uid://7rvo0wncsg3f`.

### `ui/inventory_slot.gd`

- Extends Panel.
- Stores container kind, slot index, and whether a number is shown.
- Builds child controls in code:
  - ColorRect icon.
  - Name label.
  - Quantity label.
  - Index label.
- Refresh reads stack data and item presentation from Inventory.
- Shows quantity only when greater than one.
- Highlights selected hotslot.
- Mouse enter/exit updates hover style.
- Left-click selects hotslots.
- Drag:
  - Requires nonempty source.
  - Returns kind/index payload.
  - Creates colored panel preview.
- Drop:
  - Accepts dictionaries with kind/index keys.
  - Calls Inventory swap/merge.

### `ui/inventory_slot.gd.uid`

- `uid://culio577bo2gp`.

### `ui/location_hud.gd`

- Extends CanvasLayer.
- Caches location/date/time labels.
- Connects GameState location changes.
- Connects GameTime time/date changes.
- Initializes all text from current singleton values.
- Signal handlers reread singleton state and update labels.

### `ui/location_hud.gd.uid`

- `uid://dmwn0n2cuu5jb`.

## 32. Complete Exported Seasonal Artwork Inventory

Every seasonal PNG:

- Is tracked.
- Is 128×128.
- Is an 8-bit sRGBA PNG with transparency.
- Represents an 8×8 grid of possible 16×16 tiles.
- Is declared by every farm scene.
- Uses nearest-neighbor filtering through scene/project settings.

### `assets/MainFarm/FallGround.png`

- 2,501 bytes at audit time.
- 51 colors.
- Fall terrain and foliage atlas.
- Exact flattened export of `aseprite/MainFarm/Ground/FallGround.aseprite`.
- Godot texture UID: `uid://cjt2gqdwccgm4`.
- TileSet source ID 0.
- Used actively by `MainFarmFall.tscn`.

### `assets/MainFarm/FallGround.png.import`

- Godot `CompressedTexture2D` import descriptor.
- Source: `res://assets/MainFarm/FallGround.png`.
- Generated cache target: `.godot/imported/FallGround.png-2b51d59decafe09f7fd664eeca256869.ctex`.
- Lossless/default compression mode.
- No mipmaps.
- No size limit.
- Standard RGBA channel mapping.
- Alpha-border correction enabled.
- Not imported as a normal map or VRAM-compressed texture.

### `assets/MainFarm/SpringGround.png`

- 3,368 bytes at audit time.
- 437 colors.
- Spring terrain and foliage atlas.
- Intended export of `SpringGround.aseprite`.
- Differs from the current Aseprite flattening at 13 pixels:
  - `(20,2)`.
  - `(19,3)`, `(21,3)`.
  - `(19,4)`, `(20,4)`, `(21,4)`.
  - `(20,5)`.
  - `(25,8)`, `(26,8)`, `(27,8)`.
  - `(25,9)`, `(27,9)`.
  - `(26,10)`.
- Godot UID: `uid://dm5dnwrousqvu`.
- TileSet source ID 1.
- Used actively by `MainFarmSpring.tscn`.

### `assets/MainFarm/SpringGround.png.import`

- Godot import descriptor for Spring PNG.
- Cache target: `.godot/imported/SpringGround.png-0ef537d54498eb6dbe3bbfc64d9bf06c.ctex`.
- Same lossless, no-mipmap, RGBA, alpha-border settings as the Fall import.

### `assets/MainFarm/SummerGround.png`

- 2,502 bytes.
- 63 colors.
- Summer terrain and foliage atlas.
- Exact flattened export of `SummerGround.aseprite`.
- Godot UID: `uid://c3pe1narh5sec`.
- TileSet source ID 2.
- Used actively by `MainFarmSummer.tscn`.

### `assets/MainFarm/SummerGround.png.import`

- Godot import descriptor for Summer PNG.
- Cache target: `.godot/imported/SummerGround.png-63c59536150d0653758f33b0b7f7f8b9.ctex`.
- Same common texture import settings.

### `assets/MainFarm/WinterGround.png`

- 1,085 bytes.
- Six colors.
- Winter snow/ground atlas.
- Exact flattened export of `WinterGround.aseprite`.
- Godot UID: `uid://dba3ekysjva11`.
- TileSet source ID 3.
- Used actively by `MainFarmWinter.tscn`.
- Winter scene paints no foliage.

### `assets/MainFarm/WinterGround.png.import`

- Godot import descriptor for Winter PNG.
- Cache target: `.godot/imported/WinterGround.png-01cc8ca52006ba39faa04abcc3212f3d.ctex`.
- Same common texture import settings.

## 33. Complete Aseprite Source-Art Inventory

All seven Aseprite files:

- Are tracked binary authoring documents.
- Use 32-bit RGBA.
- Use 1:1 pixel ratio.
- Use an sRGB color profile.
- Use a 16×16 grid.
- Have one visible/editable normal-blend layer named `Layer 1`.
- Have full layer opacity.
- Have no tags or slices.
- Are not imported or read by Godot at runtime.

### `aseprite/MainFarm/Ground/FallGround.aseprite`

- 128×128 canvas.
- One frame lasting 100 ms.
- One compressed cel at `(0,0)`.
- Cel content size: 53×64.
- Source for FallGround PNG.
- PNG export currently matches exactly.

### `aseprite/MainFarm/Ground/SpringGround.aseprite`

- 128×128 canvas.
- One frame lasting 100 ms.
- One compressed cel at `(0,0)`.
- Cel content size: 53×64.
- Intended source for SpringGround PNG.
- PNG currently contains the documented 13-pixel difference.

### `aseprite/MainFarm/Ground/SummerGround.aseprite`

- 128×128 canvas.
- One 100 ms frame.
- One compressed cel at `(0,0)`.
- Cel content size: 53×64.
- Contains an explicit 32-entry palette chunk.
- PNG export currently matches exactly.

### `aseprite/MainFarm/Ground/WinterGround.aseprite`

- 128×128 canvas.
- One 100 ms frame.
- One compressed cel at `(0,0)`.
- Cel content size: 48×64.
- PNG export currently matches exactly.

### `aseprite/Player/RunBack.aseprite`

- 32×32 canvas.
- Seven frames.
- Every frame lasts 100 ms.
- Frame cel bounds:
  - Frame 0: `(0,1)`, 16×31.
  - Frame 1: `(1,1)`, 16×31.
  - Frame 2: `(1,1)`, 17×31.
  - Frame 3: `(2,1)`, 16×31.
  - Frame 4: `(3,1)`, 15×31.
  - Frame 5: `(3,1)`, 16×31.
  - Frame 6: `(1,1)`, 16×31.
- No PNG/spritesheet export.
- No SpriteFrames resource.
- No scene or code references.
- Current player still uses Polygon2D.

### `aseprite/Player/RunFront.aseprite`

- 32×32 canvas.
- Seven 100 ms frames.
- Frame cel bounds:
  - Frame 0: `(2,1)`, 14×30.
  - Frame 1: `(2,2)`, 15×29.
  - Frame 2: `(0,2)`, 17×29.
  - Frame 3: `(1,1)`, 15×30.
  - Frame 4: `(1,1)`, 15×30.
  - Frame 5: `(1,2)`, 15×29.
  - Frame 6: `(0,2)`, 19×29.
- Not exported or referenced by Godot.

### `aseprite/Player/RunSide.aseprite`

- 32×32 canvas.
- Seven 100 ms frames.
- Frame cel bounds:
  - Frame 0: `(1,0)`, 22×32.
  - Frame 1: `(2,1)`, 20×30.
  - Frame 2: `(2,0)`, 18×31.
  - Frame 3: `(2,0)`, 21×32.
  - Frame 4: `(2,1)`, 19×31.
  - Frame 5: `(2,0)`, 20×32.
  - Frame 6: `(2,0)`, 18×32.
- Intended for one side direction and horizontal flipping.
- Not exported or referenced by Godot.

## 34. Exact Seasonal Atlas Usage

Every farm TileSet declares:

- Fall source 0.
- Spring source 1.
- Summer source 2.
- Winter source 3.
- 16×16 atlas regions.

Declared Fall, Spring, and Summer atlas coordinates:

- `(0,0)`.
- `(1,0)`.
- `(2,0)`.
- `(3,0)`.
- `(0,1)`.
- `(1,1)`.
- `(0,2)`.
- `(1,2)`.
- `(0,3)`.
- `(1,3)`.

Declared Winter coordinates:

- `(0,0)`.
- `(1,0)`.
- `(2,0)`.
- `(0,1)`.
- `(0,2)`.
- `(1,2)`.
- `(0,3)`.
- `(1,3)`.

Coordinate-to-pixel mapping multiplies each atlas coordinate by 16. For example, `(3,0)` uses pixel rectangle `(48,0)` through `(63,15)`.

### Fall placements

- Ground has 1,024 cells.
- `(0,0)`: 304 cells.
- `(0,2)`: 180 cells.
- `(0,3)`: 180 cells.
- `(1,2)`: 180 cells.
- `(1,3)`: 180 cells.
- Foliage1 uses `(3,0)` for 104 cells:
  - 24 untransformed.
  - 24 horizontal-and-vertical flipped.
  - 28 horizontal-flipped and transposed.
  - 28 vertical-flipped and transposed.
- Foliage2 uses `(3,0)` for four cells:
  - Two horizontal-flipped and transposed.
  - Two vertical-flipped and transposed.
- Declared but unplaced: `(1,0)`, `(2,0)`, `(0,1)`, `(1,1)`.

### Spring placements

- Ground has 1,024 cells.
- `(0,0)`: 304 untransformed.
- `(0,2)`, `(0,3)`, `(1,2)`, and `(1,3)` each appear:
  - 20 times untransformed.
  - 160 times vertical-flipped and transposed.
- Foliage1 and Foliage2 use the same `(3,0)` counts/transforms as Fall.
- Declared but unplaced: `(1,0)`, `(2,0)`, `(0,1)`, `(1,1)`.

### Summer placements

- Same cell-coordinate counts as Fall.
- All ground placements are untransformed.
- Foliage uses the same `(3,0)` counts/transforms as Fall.
- Declared but unplaced: `(1,0)`, `(2,0)`, `(0,1)`, `(1,1)`.

### Winter placements

- Ground has 1,024 cells.
- `(0,0)`: 304 cells.
- `(0,2)`, `(0,3)`, `(1,2)`, and `(1,3)`: 180 each.
- All are untransformed.
- No foliage cells.
- Declared but unplaced: `(1,0)`, `(2,0)`, `(0,1)`.

## 35. Project Icon Contents

### `icon.svg`

- 995-byte vector file at audit time.
- 128×128 SVG canvas.
- Standard Godot logo.
- Contains a rounded dark background rectangle.
- Contains grouped vector paths and circles for the blue/white logo.
- Referenced by `project.godot` as the project icon.
- Godot UID: `uid://573hb80rg5ka`.

### `icon.svg.import`

- Godot texture-import descriptor.
- Source: `res://icon.svg`.
- Cache target: `.godot/imported/icon.svg-218a8f2b3041327d8a5756f3a245f83b.ctex`.
- SVG scale 1.0.
- Editor-theme color conversion disabled.
- Lossless texture settings.
- No mipmaps.

## 36. Runtime Usage Status of Every Authored Content Group

Actively used at runtime:

- `project.godot`.
- `MainFarmSpring.tscn`.
- All four autoload scripts.
- Both HUD scenes and all three HUD scripts.
- Functional player scene and its four scripts.
- Base interactable.
- Bed scene/script.
- Crop scene/script.
- Crop data script.
- Seasonal controller.
- Location info.
- All four seasonal PNGs through TileSet declarations.
- Summer/Fall/Winter scenes as seasonal data templates.
- Icon through project configuration.
- UID/import sidecars through Godot’s editor/import identity systems.

Authored but not runtime-used:

- Root `player.tscn`.
- `inventory/item_data.gd`.
- All four farm Aseprite source documents.
- All three player Aseprite source documents.
- Documentation and Cursor rule, which support development rather than game execution.

Artwork currently visible in-game:

- Seasonal ground and foliage PNGs.
- Procedural player Polygon2D.
- Procedural bed polygons.
- Procedural crop polygon and stage number.
- Procedural tilled/watered soil.
- Procedural target highlight.
- Procedural inventory ColorRects and default Control styling.

Artwork present but not visible in-game:

- Player RunBack, RunFront, and RunSide Aseprite animations.

## 37. Generated, Ignored, and Internal Files

These are present in the working directory but are intentionally outside the authored-file manifest.

### `.godot/`

- Ignored Godot-generated workspace and import cache.
- Includes:
  - `.gdignore`.
  - Imported `.ctex` textures.
  - Import MD5 metadata.
  - Filesystem caches.
  - Global script class caches.
  - Scene group caches.
  - Editor layout, folding, selection, and history state.
  - Project metadata.
- Rebuilt by Godot.
- Should not be treated as authoritative source or committed.

### `.git/`

- Git implementation directory.
- Includes:
  - Repository config.
  - HEAD and index.
  - Branch and remote references.
  - Object database.
  - Reflogs.
  - Hooks and sample hooks.
  - Merge/commit state when applicable.
- Not part of the game.
- Should never be edited as gameplay content.

### `.DS_Store`

Ignored Finder metadata files currently exist at:

- `.DS_Store`.
- `aseprite/.DS_Store`.
- `aseprite/MainFarm/.DS_Store`.

Each was 6,148 bytes at audit time. They contain macOS folder-view metadata, are not artwork, and are not read by Godot.

## 38. Overall Historical Implementation Included

This document preserves the previously documented implementation and now adds the complete file/art inventory. The accumulated implemented sequence represented by the current files is:

1. Main farm scene, TileMap, player body, movement, and camera.
2. Location state and top-right location HUD.
3. Five-slot hotslot inventory and left-click farming tools.
4. Tilling and watering, including watering empty tilled soil.
5. Real-time clock where one second equals one game minute.
6. Four-season, 28-day calendar and date/clock HUD.
7. Reusable Area2D interactable framework.
8. Solid bed object and next-morning sleep.
9. Date-driven crop growth with explicit numeric stages.
10. Daily water consumption/reset.
11. E-open/Escape-close normal inventory.
12. Right-click object interaction.
13. Five hotslots plus twenty-slot normal inventory.
14. Stack quantities, maximum 99, and cross-container drag/drop.
15. Rice and Beans crop definitions.
16. Single-harvest Rice lifecycle.
17. Indefinitely regrowable Beans lifecycle.
18. Transactional harvest capacity behavior.
19. Crop PackedScene objects on the world-object interaction layer without solid collision.
20. Right-click-only harvesting.
21. Seasonal TileMap replacement without resetting gameplay state.
22. Project-wide logic/visual separation policy.
23. Complete architecture, content, risk, and artwork documentation.

The source of truth is still the current code and scenes. This document records their audited behavior as of 2026-08-14.

## 39. Addendum (2026-08-21) — Changes Since the 2026-08-14 Audit

This section records two changes found in the code after the audit above; neither has been folded into a full re-audit of every section.

### Camera zoom control

`ui/location_hud.gd` and `ui/location_hud.tscn` gained a camera-zoom control: a `-` button, a percentage label, and a `+` button in a new `ZoomRow` under the existing location/date/time labels. See section 7 for the full description, now merged in above.

Architecturally, this is the one spot in the project where a HUD script reads a world node (the Player's `Camera2D`, via `get_viewport().get_camera_2d()`) directly rather than only listening to `GameState`/`GameTime`/`Inventory` signals. It does not write back into any autoload and does not affect gameplay state, tiles, or input handling elsewhere — it only scales the existing `Camera2D.zoom`. Code comments describing this in detail were added directly to `ui/location_hud.gd`.

### Inventory placement priority

`autoload/inventory.gd`'s item-adding logic (`try_add_item()`) was reworked into a `_plan_add_item()` / `_apply_add_plan()` pair, changing the actual placement rule, not just its implementation. Empty slots are now filled hotslots-first, trying the currently *selected* hotslot before any other slot, and only falling back to the inventory grid once every hotslot is full. See the updated bullet list in section 17 above — the line "Harvested produce never automatically enters hotslots" is no longer accurate as written; a harvest (or any `try_add_item()` call) can now fill an empty selected hotslot directly. This was an in-progress edit made to the file while this review was underway, so it was left as-is and only documented, not reverted.

### Environmental & Time-of-Day Audio (Idea)

Not implemented — there is no audio system in the project at all yet (see section 2). Recorded here as a design idea, raised alongside this addendum, so it isn't lost: ambient/ATMOSPHERIC sound should eventually react to the same season + time-of-day state the visuals already react to, the same way `locations/seasonal_farm_tiles.gd` reacts to `GameTime.season_changed` and the HUD reacts to `GameTime.time_changed`.

Concrete example driving the idea: **summer nights should have cricket/insect (풀벌레) chirping ambience** — i.e. an ambient sound loop keyed on `GameTime.season == Season.SUMMER` AND a night-time hour range (roughly `hour >= ~20` or `< ~6`, to be tuned), rather than a single always-on ambient track. More generally, this suggests a small season × time-of-day ambience table (e.g. spring day / spring night / summer day / summer night / … ), most naturally implemented as:

- A new `AmbientAudio` autoload (or a non-autoload controller under the farm scene) that subscribes to `GameTime.season_changed` and `GameTime.time_changed` (or a coarser "is it night" signal derived from `GameTime.hour`), and crossfades between per-season/per-time-of-day `AudioStreamPlayer` loops.
- Keeping this purely reactive to `GameTime`, the same way every other seasonal/time-driven system in the project already is — no new authoritative state needed, since season/hour are already tracked by `GameTime`.
- Extending later to other weather/ambience ideas noted elsewhere in this document (rain, holidays) if a broader environmental-audio system is built, rather than one-off wiring just for crickets.

This has not been implemented; no audio files, `AudioStreamPlayer` nodes, or scripts exist for it yet. It is grouped with "No environmental/ambient audio tied to season or time of day" in section 3 and section 28's not-yet-implemented lists.
