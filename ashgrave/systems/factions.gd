class_name Factions
extends RefCounted
## Faction reputation (-100..100) and what it changes: prices and willingness to trade.

const NAMES := {
	"church": "Tithe Church",
	"companies": "Free Companies",
	"hollow": "Hollow Folk",
}
const START := {"church": 0, "companies": -25, "hollow": 0}  # Maren deserted a Free Company
const REFUSE_BELOW := -40

static func standing(rep: int) -> String:
	if rep <= -60: return "Hated"
	if rep <= REFUSE_BELOW: return "Hostile"
	if rep < -10: return "Distrusted"
	if rep <= 10: return "Neutral"
	if rep < 50: return "Trusted"
	return "Honoured"

static func buy_price(value: int, rep: int) -> int:
	return maxi(1, ceili(value * (1.25 - rep / 200.0)))

static func sell_price(value: int, rep: int) -> int:
	return maxi(1, floori(value * 0.5 * (1.0 + rep / 200.0)))

static func will_trade(rep: int) -> bool:
	return rep > REFUSE_BELOW
