extends Node

## AUTOLOAD (singleton) — see project.godot [autoload]. Loaded after
## Inventory, before Soil.
##
## Two numbers: `balance` (spendable money, already "in the bank") and
## `pending` (today's Selling Box proceeds, not banked yet). Selling a crop
## (see interactables/furniture/selling_box/selling_box.gd) only ever adds
## to `pending` via add_pending() — it is folded into `balance` exactly
## once, at the same day-advance instant Soil grows crops and clears
## watering: GameTime's `date_changed` signal, fired by BOTH natural
## midnight (GameTime._advance_minute()) and manual sleep
## (GameTime.sleep_to_next_morning(), called from interactables/bed/bed.gd).
## See autoload/soil.gd's _on_date_changed() for the exact same
## single-day-advance-path pattern this mirrors — "sell during the day,
## the money lands in your wallet the next morning" falls out of that for
## free, with no separate day-end timer of its own.
##
## Who talks to this script:
##   - `interactables/furniture/selling_box/selling_box.gd` calls
##     add_pending() when the player sells the selected hotbar stack.
##   - `ui/location_hud.gd` listens to balance_changed/pending_changed to
##     draw the gold total and the "+Ng today" indicator.
##
## Nothing SPENDS money yet — there is no shop anywhere in this project.
## can_afford()/spend() exist now so a future shop only ever needs to call
## those, never touch `balance` directly.

signal balance_changed(new_balance: int)
signal pending_changed(new_pending: int)
## Emitted the instant `pending` is folded into `balance` (i.e. exactly
## when date_changed fires with something to settle) — lets the HUD show a
## brief "earned Ng" confirmation instead of the pending indicator just
## silently resetting to zero overnight.
signal day_settled(amount_earned: int)

## Starting capital — narratively "what's left after the debt/inheritance
## mess" (see the Obsidian vault's Story notes). Placeholder like
## crop_data.gd's sell prices; easy to retune once the economy is balanced.
const STARTING_BALANCE := 500

var balance: int = STARTING_BALANCE
var pending: int = 0


func _ready() -> void:
	GameTime.date_changed.connect(_on_date_changed)


## Called by interactables/furniture/selling_box/selling_box.gd whenever a
## stack sells. Deliberately does NOT touch `balance` — see the class doc
## comment above for why the one-day delay is intentional, not a bug.
func add_pending(amount: int) -> void:
	if amount <= 0:
		return
	pending += amount
	pending_changed.emit(pending)


func can_afford(amount: int) -> bool:
	return amount >= 0 and balance >= amount


## Reserved for a future shop/purchase system (see class doc comment).
## Returns false — and changes nothing — if `amount` can't be afforded.
func spend(amount: int) -> bool:
	if not can_afford(amount):
		return false
	balance -= amount
	balance_changed.emit(balance)
	return true


func _on_date_changed(_day: int, _season: int, _year: int) -> void:
	if pending <= 0:
		return
	var earned := pending
	balance += pending
	pending = 0
	balance_changed.emit(balance)
	pending_changed.emit(pending)
	day_settled.emit(earned)
