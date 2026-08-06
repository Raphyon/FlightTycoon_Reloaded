#!/usr/bin/env python3
"""Play the economy forward against a model player, and report what happens.

WHY THIS EXISTS
---------------
Every pacing figure this project has produced - "level 10 in fifteen minutes",
"Zone1 full in a quarter of an hour", "+205% at a full build" - came from a
throwaway script that integrated income as if the player never stopped tapping.
That is not a player. It is an upper bound, and we have been treating it as a
prediction.

The fix is the step those scripts skipped: a BEHAVIOUR MODEL. Sessions per day,
minutes per session, and real time passing in between. It matters more here than
in most games because our cycles straddle a session boundary - flights run 2 to
17 hours at range, rent cycles 5 to 20 minutes - so whether a thing is
"collected every cycle" or "collected once per session" changes the answer by an
order of magnitude.

WHAT IT READS
-------------
The game's own source, not a copy. Prices, stats, XP curve, zone costs and the
placed layouts are parsed out of the GDScript and JSON at run time, so this
cannot drift from the game the way a spreadsheet would. If a number moves in
ShopCatalog, the next run of this tool sees it.

WHAT IT ASSUMES - and these are the arguable parts
--------------------------------------------------
  * The player is rational and never idles money: they buy in the priority
    order in BUY_PRIORITY below, cheapest-first within a tier - but they hold
    back a FUEL RESERVE first (see Sim.fuel_reserve). Capital is bought with
    what is left after everything they own can fly, not before.
  * GROUNDED ESCAPE: with no fuel and no cash the game would otherwise be over
    - fuel needs cash, cash needs flights, flights need fuel. There are two ways
    out and the player takes the cheaper one:
      1. SELL an idle aircraft (Fleet.sell, 50% of its price back). Costs
         nothing but the aircraft, and always available if you own one.
      2. Buy a zero-fuel aircraft with coins (the Paper Plane), which flies for
         free. Spends premium currency that has no earn path.
    Selling is tried first, because it is the one that does not consume a
    finite resource.
  * They act only during a session. Flights advance and rent accrues while they
    are away, but nothing is collected, dispatched or bought.
  * Rent does not stack (matches BuildingProgress.collect_rent).
  * ROUTE CHOICE: five destinations now exist, at distances 1 to 5, each gated
    on a homeland zone (Maps.ROBOT_DESTINATIONS). Pay scales with the ROUTE's
    clouds and so does time - but not at the same rate. Distance 1 to 5 is 5x
    the money and 120x the wait, so per minute the nearest is always best and
    the far ones only win when the player is not there to collect anyway.
    The model player therefore flies the LONGEST leg that will still be over by
    the time they next open the game, capped by the aircraft's range and by
    which destinations they have unlocked. Short hops during the day, long haul
    before bed - which is the behaviour the distance ladder is there to reward.

    python3 tools/econ_sim.py
    python3 tools/econ_sim.py --sessions 6 --minutes 3 --days 30
"""
import argparse
import json
import math
import os
import random
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAME = os.path.join(ROOT, "game")

# What a rational player buys first when they can afford several things. This
# is a POLICY, not a fact about the game - change it and the report changes.
BUY_PRIORITY = ["coin_aircraft", "pad", "aircraft", "zone", "building"]


# --------------------------------------------------------------------------
# Reading the game
# --------------------------------------------------------------------------

def gd(path):
    return open(os.path.join(GAME, "scripts", path)).read()


def const(src, name, cast=float):
    m = re.search(r"const %s := ([-\d.]+)" % name, src)
    return cast(m.group(1)) if m else None


def const_list(src, name):
    m = re.search(r"const %s := \[(.*?)\]" % name, src, re.S)
    return [float(x) for x in m.group(1).split(",") if x.strip()]


def entries(src, block):
    """Every {...} row of a const array, as dicts of the literals inside."""
    body = src.split("const %s := [" % block, 1)[1].split("\n]", 1)[0]
    out = []
    for row in re.findall(r"\{\"key\".*?\},", body, re.S):
        d = dict(re.findall(r'"(\w+)":\s*"([^"]*)"', row))
        d.update({k: int(v) for k, v in re.findall(r'"(\w+)":\s*(\d+)', row)})
        if "COINS" in row or '"coins"' in row:
            d["currency"] = "coins"
        out.append(d)
    return out


class Game:
    """Everything the simulation needs, lifted straight out of the project."""

    def __init__(self):
        fleet, cat = gd("fleet.gd"), gd("shop_catalog.gd")
        bl, prog = gd("building_layout.gd"), gd("progression.gd")

        self.fare = const(fleet, "TICKET_PRICE", int)
        self.base_min = const_list(fleet, "CLOUD_BASE_MINUTES")
        self.step_min = const_list(fleet, "CLASS_STEP_MINUTES")
        self.class_step = {k: float(v) for k, v in re.findall(
            r'"(S\+|[SABCDE])": (-?[\d.]+)',
            re.search(r"const CLASS_STEPS := \{(.*?)\}", fleet, re.S).group(1))}

        self.aircraft = entries(cat, "ENTRIES")
        self.buildings = entries(bl, "BUILDINGS")

        # Affinity: every level shaves 1% off this MODEL's flight time, capped.
        # Worth modelling because it is throughput, and throughput compounds -
        # 10% shorter legs is 11% more legs per session, for free, forever.
        aff = gd("aircraft_affinity.gd")
        self.aff_xp_per_level = const(aff, "XP_PER_LEVEL", int)
        self.aff_xp_per_use = const(aff, "XP_PER_USE", int)
        self.aff_max_level = const(aff, "MAX_LEVEL", int)
        self.aff_per_level = const(aff, "SPEED_BONUS_PER_LEVEL")

        self.xp_coeff = const(prog, "XP_COEFFICIENT")
        self.xp_exp = const(prog, "XP_EXPONENT")

        m = re.search(r'const STARTER_MODEL := "(\w+)"', gd("fleet.gd"))
        self.starter_model = m.group(1) if m else "dc3"
        self.start_money = const(gd("economy.gd"), "STARTING_MONEY", int)
        self.start_coins = const(gd("coins.gd"), "DEFAULT_AMOUNT", int)
        self.start_fuel = const(gd("fuel_store.gd"), "STARTING_AMOUNT", int)
        self.fuel_price = const(gd("fuel_store.gd"), "BASE_PRICE", int)
        # Fuel is sold in FIXED BUNDLES, not by the unit - the shop's smallest
        # cell is 50, so the cheapest possible top-up is 50 * price. That floor
        # is the single most important number in the early game and it lives in
        # a scene script rather than a autoload, so it is read from there.
        panel = open(os.path.join(GAME, "scenes", "main", "FuelPanel.gd")).read()
        self.fuel_bundles = sorted(int(x) for x in re.findall(
            r"\d+", re.search(r"const QUANTITIES := \[(.*?)\]", panel).group(1)))
        self.min_fuel_cost = self.fuel_bundles[0] * self.fuel_price
        bp = gd("building_progress.gd")
        self.people_per_pct = const(bp, "PEOPLE_PER_PERCENT")
        # The coin lottery on rent collection - the only way coins enter the
        # game. Collections are bounded by SESSIONS, not by buildings owned,
        # because rent does not stack.
        self.coin_per_min = const(bp, "COIN_CHANCE_PER_CYCLE_MINUTE")
        self.coin_amount = const(bp, "COIN_DROP_AMOUNT", int)

        ap = gd("apron_progress.gd")
        self.pad_cost = {k: int(v) for k, v in re.findall(
            r'"(\w+)": (\d+)',
            re.search(r"const ZONE_BASE_COST := \{(.*?)\n\}", ap, re.S).group(1))}
        # Each pad in an area costs PAD_COST_GROWTH times the one before it -
        # the only thing that scales against a fleet that pays for itself every
        # few minutes. See ApronProgress.cost_for_area.
        self.pad_growth = const(ap, "PAD_COST_GROWTH")
        # "Zone1 and i < 5" in ApronLayout.build_area_aprons.
        m = re.search(r'area_name == "Zone1" and i < (\d+)', gd("apron_layout.gd"))
        self.free_pads = int(m.group(1)) if m else 0
        self.zone_req = {m.group(1): (int(m.group(2)), int(m.group(3))) for m in re.finditer(
            r'"(\w+)": \{"level": (\d+), "cost": (\d+)\}', gd("zone_progress.gd"))}

        data = os.path.join(GAME, "data")
        self.pads = {a: len(p) for a, p in
                     json.load(open(os.path.join(data, "apron_layout.json")))["homeland"].items()}
        self.plots = len(json.load(open(os.path.join(data, "building_layout.json")))["homeland"])
        # [(distance, unlock_area)] for the five destinations, nearest first.
        # An empty unlock means always available.
        block = re.search(r"const ROBOT_DESTINATIONS := \[(.*?)\n\]",
                          gd("maps.gd"), re.S).group(1)
        self.destinations = [(int(d), u) for d, u in re.findall(
            r'"distance": (\d+),.*?"unlock": "(\w*)"', block, re.S)]

    def xp_for_level(self, n):
        return 0.0 if n <= 1 else self.xp_coeff * n ** self.xp_exp

    def leg_minutes(self, grade, clouds):
        i = max(0, min(len(self.base_min), clouds) - 1)
        return self.base_min[i] + self.class_step[grade] * self.step_min[i]

    # The original's formula - ticket * seats * cloud rating - with the rating
    # read as the ROUTE's, matching Fleet.payout_for. The aircraft's own rating
    # is a ceiling on which routes it may fly, not a multiplier it carries.
    def payout(self, a, clouds):
        return a["seats"] * a.get("ticket", self.fare) * clouds


# --------------------------------------------------------------------------
# The model player
# --------------------------------------------------------------------------

class Sim:
    def __init__(self, g, sessions, minutes, waking=16.0,
                 lapse=0.0, max_break=0, rng=None):
        self.g = g
        # REAL PLAYERS PUT THE GAME DOWN. `lapse` is the chance any given day
        # starts a break; `max_break` is how long a break can run. A break is a
        # day with no session at all - time still passes, so flights land and
        # rent finishes, but nothing is collected or dispatched.
        #
        # This is where a no-stacking rent design shows its teeth: a fortnight
        # away banks ONE payout per building, not fourteen, and every aircraft
        # sits on its pad having landed on day one.
        self.lapse = lapse
        self.max_break = max_break
        self.rng = rng or random.Random(0)
        self.break_left = 0
        self.days_played = 0
        # MINUTES OF ACTUAL PLAY at the moment each milestone was reached - the
        # only honest unit for "how long is this game". Elapsed days are a
        # property of the player's calendar; hours at the controls are a
        # property of the design.
        self.milestones = {}
        self.sessions = sessions
        self.session_len = minutes
        # Sessions spread over waking hours; the rest of the day is one long gap.
        self.gap = (waking * 60.0 - sessions * minutes) / max(1, sessions - 1) if sessions > 1 else 0.0
        self.night = 24 * 60.0 - waking * 60.0

        self.money = float(g.start_money)
        self.coins = g.start_coins
        self.fuel = float(g.start_fuel)
        self.xp = 0.0
        self.level = 1
        self.fleet = []            # [{"a": entry, "state": str, "left": min}]
        # Zone1's first five pads come FREE - see ApronLayout.build_area_aprons.
        # The model was buying all five, at 500 rising by 1.35 each, so it
        # opened $1,175 down against a $3,000 second aircraft and made the
        # first ten minutes look far poorer than the game actually is.
        # A fresh game is HANDED a DC-3 on apron 1 - see Fleet.grant_starter.
        # Modelled here or the tool measures an opening the game no longer has.
        starter = [a for a in g.aircraft if a["key"] == g.starter_model]
        if starter:
            self.fleet.append({"a": starter[0], "state": "idle",
                               "left": 0.0, "clouds": 1})
        self.pads = self.g.free_pads
        self.pads_in = {"Zone1": self.g.free_pads}
        self.zones = set()
        self.built = []            # building entries
        self.rent_ready = []       # minutes remaining per built building
        self.log = []
        self.rescues = 0
        self.sold = 0
        self.collections = 0
        self.coins_found = 0
        self.affinity = {}         # model key -> legs flown, for the speed bonus
        self.coin_per_min = g.coin_per_min
        self.no_coins = False
        self.coin_amount = g.coin_amount

    # -- helpers ---------------------------------------------------------
    def free_pads(self):
        return self.pads - len(self.fleet)

    def popularity(self):
        return 1.0 + sum(b["people"] for b in self.built) / (self.g.people_per_pct * 100.0)

    def unlocked_pads(self):
        n = self.g.pads.get("Zone1", 0)
        for z in self.zones:
            n += self.g.pads.get(z, 0)
        return n

    def next_zone(self):
        for name, (lvl, cost) in sorted(self.g.zone_req.items(), key=lambda kv: kv[1][0]):
            if name not in self.zones:
                return name, lvl, cost
        return None, 0, 0

    def buildings_unlocked(self):
        return "Zone2" in self.zones

    def add_xp(self, amount):
        self.xp += amount
        while self.xp >= self.g.xp_for_level(self.level + 1):
            self.level += 1

    # -- time passing ----------------------------------------------------
    def advance(self, minutes):
        for f in self.fleet:
            if f["state"] in ("out", "back"):
                f["left"] -= minutes
                if f["left"] <= 0:
                    f["state"] = "arrived" if f["state"] == "out" else "home"
        for i, left in enumerate(self.rent_ready):
            self.rent_ready[i] = max(0.0, left - minutes)

    # -- routes ----------------------------------------------------------
    def reachable(self, a):
        """Distances this aircraft may fly: within its range, and unlocked."""
        return [d for d, gate in self.g.destinations
                if d <= a["range"] and (gate == "" or gate in self.zones)]

    def route_for(self, a, until_next):
        """The longest leg that is over before the player comes back.

        Per minute the nearest destination always wins (5x the pay for 120x the
        wait), so the only reason to fly further is time the player was going
        to spend away regardless. Falls back to the nearest when nothing fits,
        rather than not flying - an aircraft sitting idle earns nothing at all.
        """
        options = self.reachable(a)
        fits = [d for d in options
                if self.g.leg_minutes(a["force"], d) <= until_next]
        return max(fits) if fits else min(options)

    # -- a session -------------------------------------------------------
    def _service(self):
        """Collect everything that is waiting: arrivals, then rent."""
        for f in self.fleet:
            a = f["a"]
            if f["state"] == "arrived":
                self.money += self.g.payout(a, f["clouds"]) * self.popularity()
                self.affinity[a["key"]] = self.affinity.get(a["key"], 0) + 1
                self.add_xp(a["xp"])
                f["state"] = "return_ready"
            elif f["state"] == "home":
                self.money += self.g.payout(a, f["clouds"]) * self.popularity()
                self.affinity[a["key"]] = self.affinity.get(a["key"], 0) + 1
                self.add_xp(a["xp"])
                f["state"] = "idle"
        for i, left in enumerate(self.rent_ready):
            if left <= 0:
                b = self.built[i]
                self.money += b["rent"]
                self.rent_ready[i] = b["minutes"]
                self.collections += 1
                # Scaled by the building's own cycle, so coins-per-hour is
                # flat across the catalogue - see BuildingProgress.
                if self.rng.random() < self.coin_per_min * b["minutes"]:
                    self.coins += self.coin_amount
                    self.coins_found += self.coin_amount

    def _dispatch(self, horizon):
        """Send everything idle, buying the fuel it needs.

        `horizon` is how long until the player can next act - the rest of this
        sitting plus the gap after it - which is what decides how far a route
        is worth sending.
        """
        for f in self.fleet:
            a = f["a"]
            if f["state"] not in ("idle", "return_ready"):
                continue
            need = a["fuel"]
            if self.fuel < need:
                # Smallest bundle that covers the shortfall - you cannot buy 12
                # units of fuel, only 50, 500, 5000 or 50000.
                short = need - self.fuel
                want = next((q for q in self.g.fuel_bundles if q >= short),
                            self.g.fuel_bundles[-1])
                cost = want * self.g.fuel_price
                if self.money >= cost:
                    self.money -= cost
                    self.fuel += want
            if self.fuel >= need:
                self.fuel -= need
                # The return leg flies the route it went out on - it is the
                # same route, and the aircraft is at the far end of it.
                if f["state"] == "idle":
                    f["clouds"] = self.route_for(a, horizon)
                f["left"] = self.leg_minutes_for(a, f["clouds"])
                f["state"] = "out" if f["state"] == "idle" else "back"

    def session(self, until_next):
        """One sitting at the controls, played out minute by minute.

        THIS USED TO BE A SINGLE PASS. Collect, buy, dispatch, and then the
        caller jumped the clock by the whole session - so every aircraft made
        at most ONE state transition per sitting, and the round trip
        idle -> out -> arrived -> return_ready -> back -> home takes four of
        them. At four sessions a day that was one round trip per aircraft per
        DAY, while a cloud-1 leg is two minutes long.

        The early game is all short-haul, so this understated it enormously -
        which is why the model limped to level 11 in a week when a real player
        reaches level 19 in an afternoon. A sitting now runs a real clock:
        service what has landed, spend, dispatch, skip to the next landing, and
        go round again until the minutes are used up.
        """
        remaining = self.session_len
        after = max(0.0, until_next - self.session_len)
        # Bounded purely as a guard against a zero-length leg spinning forever;
        # a five-minute sitting with one-minute legs uses about six.
        for _ in range(500):
            self._service()
            self.buy()
            self._dispatch(remaining + after)
            if remaining <= 0:
                return
            flying = [f["left"] for f in self.fleet if f["state"] in ("out", "back")]
            # Nothing in the air and nothing dispatchable - the rest of the
            # sitting cannot change anything, so skip to the end of it.
            step = remaining if not flying else min(min(flying), remaining)
            if step <= 0:
                step = remaining
            self.advance(step)
            remaining -= step

    # -- spending --------------------------------------------------------
    def fuel_reserve(self):
        """Cash a rational player will NOT spend on capital.

        Enough to put one leg of fuel in everything they already own. An
        aircraft that cannot fly is worth nothing, so spending the money that
        would have fuelled nine of them on a tenth is not a trade any player
        makes - but with fuel bought only after BUY_PRIORITY had taken its
        pick, it is exactly what this model did, and it is what parked it at
        nine aircraft and $300 for twenty-three days.
        """
        need = sum(f["a"]["fuel"] for f in self.fleet)
        return max(0.0, need - self.fuel) * self.g.fuel_price

    def spendable(self):
        return self.money - self.fuel_reserve()

    def buy(self):
        self._escape_if_grounded()
        changed = True
        while changed:
            changed = False
            for what in BUY_PRIORITY:
                if what == "pad" and self.free_pads() <= 0 and self.pads < self.unlocked_pads():
                    zone, cost = self._cheapest_pad()
                    if self.spendable() >= cost:
                        self.money -= cost
                        self.pads += 1
                        self.pads_in[zone] = self.pads_in.get(zone, 0) + 1
                        changed = True
                elif what == "coin_aircraft" and not self.no_coins:
                    # ShopCatalog.unlocked() lets a coin aircraft ignore the
                    # level gate entirely - "the pay-to-win lane, available
                    # from the first minute". With 100 free coins that is an
                    # Ark on day one, earning 150x the starter on the same
                    # two-minute hop. Leaving it out modelled a player who
                    # ignores the strongest move in the game.
                    best = self._best_coin_aircraft()
                    if best and self.free_pads() > 0:
                        self.coins -= best["price"]
                        self.fleet.append({"a": best, "state": "idle",
                                           "left": 0.0, "clouds": 1})
                        changed = True
                elif what == "aircraft":
                    best = self._best_affordable_aircraft()
                    if best and self.free_pads() > 0:
                        self.money -= best["price"]
                        self.fleet.append({"a": best, "state": "idle", "left": 0.0, "clouds": 1})
                        changed = True
                elif what == "zone":
                    name, lvl, cost = self.next_zone()
                    if (name and self.level >= lvl and self.free_pads() <= 0
                            and self.spendable() >= cost):
                        self.money -= cost
                        self.zones.add(name)
                        changed = True
                elif what == "building" and self.buildings_unlocked():
                    b = self._best_affordable_building()
                    if b and len(self.built) < self.g.plots:
                        self.money -= b["price"]
                        self.built.append(b)
                        self.rent_ready.append(float(b["minutes"]))
                        changed = True

    # No fuel, no money, and nothing in the air: the only move left is a
    # zero-fuel aircraft bought with the paid currency.
    def _grounded(self):
        # Against the smallest BUNDLE, not one unit's price. Testing one unit
        # said "not grounded" at $300 with a $500 floor, so the rescue never
        # fired in precisely the state it exists for - the model sat stalled
        # for 23 days with an escape hatch it never noticed it needed.
        if self.money >= self.g.min_fuel_cost:
            return False
        if any(f["state"] in ("out", "back", "arrived", "home") for f in self.fleet):
            return False
        return all(self.fuel < f["a"]["fuel"] for f in self.fleet) if self.fleet else True

    def _escape_if_grounded(self):
        if not self._grounded():
            return
        # 1. Sell something. RESALE_FRACTION is 0.5 and coin aircraft are not
        #    sellable, matching Fleet.can_sell.
        sellable = [f for f in self.fleet if f["a"].get("currency") != "coins"]
        if sellable:
            worst = min(sellable, key=lambda f: f["a"]["price"])
            self.money += worst["a"]["price"] * 0.5
            self.fleet.remove(worst)
            self.sold += 1
            return
        # 2. Nothing left to sell - spend coins on something that flies free.
        for a in sorted(self.g.aircraft, key=lambda a: a["price"]):
            if a.get("currency") != "coins" or a["fuel"] != 0:
                continue
            if self.coins < a["price"]:
                continue
            if self.free_pads() <= 0 and self.pads >= self.unlocked_pads():
                return
            if self.free_pads() <= 0:
                cost = self.g.pad_cost.get("Zone1", 1000)
                if self.money < cost:
                    return
                self.money -= cost
                self.pads += 1
            self.coins -= a["price"]
            self.fleet.append({"a": a, "state": "idle", "left": 0.0, "clouds": 1})
            self.rescues += 1
            return

    def pad_cost(self, area):
        base = self.g.pad_cost.get(area, 1000)
        return round(base * self.g.pad_growth ** self.pads_in.get(area, 0))

    def _cheapest_pad(self):
        """The cheapest pad available anywhere, not the next one in Zone1.

        With per-area geometric pricing, filling one area before starting the
        next is the WORST order: Zone1's twentieth pad is over a million while
        Zone2's first is 800. Forcing Zone1 to fill first made the growth factor
        look far harsher than it is, because the model was paying an avoidable
        price. A real player buys where it is cheap, which turns zones into the
        growth path rather than a thing you get to eventually.
        """
        best, best_cost = None, None
        for area in ["Zone1"] + sorted(self.zones):
            room = self.g.pads.get(area, 0) - self.pads_in.get(area, 0)
            if room <= 0:
                continue
            c = self.pad_cost(area)
            if best_cost is None or c < best_cost:
                best, best_cost = area, c
        return best, (best_cost if best_cost is not None else 10 ** 12)

    def _best_affordable_aircraft(self):
        """Most income per hour that money and level allow."""
        best, best_rate = None, 0.0
        for a in self.g.aircraft:
            if a.get("currency") == "coins" or a["level"] > self.level:
                continue
            if a["price"] > self.money:
                continue
            # Ranked on the DAYTIME rate, the nearest destination, because
            # that is where most of the play happens. It understates a
            # long-range aircraft, which also earns 5x on the overnight leg a
            # short-range one cannot fly at all.
            rate = self.g.payout(a, 1) / self.g.leg_minutes(a["force"], 1)
            if rate > best_rate:
                best, best_rate = a, rate
        return best

    def _best_coin_aircraft(self):
        """Best coin aircraft the float can afford, ranked on the NEAREST
        destination - a new account has only the distance-1 robot unlocked, so
        ranking on max range would pick something it cannot fly yet."""
        best, best_rate = None, 0.0
        for a in self.g.aircraft:
            if a.get("currency") != "coins" or a["price"] > self.coins:
                continue
            rate = self.g.payout(a, 1) / self.g.leg_minutes(a["force"], 1)
            if rate > best_rate:
                best, best_rate = a, rate
        return best

    def _best_affordable_building(self):
        best, best_rate = None, 0.0
        for b in self.g.buildings:
            if b.get("currency") == "coins" or b["level"] > self.level:
                continue
            if b["price"] > self.spendable():
                continue
            rate = b["rent"] / b["minutes"]
            if rate > best_rate:
                best, best_rate = b, rate
        return best

    # -- run -------------------------------------------------------------
    def _day_off(self):
        if self.break_left > 0:
            self.break_left -= 1
            return True
        if self.max_break > 0 and self.rng.random() < self.lapse:
            self.break_left = self.rng.randint(1, self.max_break) - 1
            return True
        return False

    # Affinity is per MODEL and counts CLAIMED LEGS, matching
    # Fleet.claim_destination_reward / claim_home_reward - the two places
    # AircraftAffinity.grant_use is called.
    def _affinity_multiplier(self, key):
        xp = self.affinity.get(key, 0) * self.g.aff_xp_per_use
        level = min(xp // self.g.aff_xp_per_level + 1, self.g.aff_max_level)
        return 1.0 - self.g.aff_per_level * level

    def leg_minutes_for(self, a, clouds):
        return self.g.leg_minutes(a["force"], clouds) * self._affinity_multiplier(a["key"])

    def played_minutes(self):
        return self.days_played * self.sessions * self.session_len

    # Everything the game has to give. Aircraft are not in here because the
    # model buys the best it can afford rather than collecting the set - level
    # 36 is the last unlock in ShopCatalog, so reaching it means the whole
    # ladder is open.
    def _check_milestones(self):
        done = {
            "all zones": len(self.zones) >= len(self.g.zone_req),
            "all pads": self.pads >= sum(self.g.pads.values()),
            "all plots": len(self.built) >= self.g.plots,
            "fleet ladder": self.level >= 36,
        }
        for name, hit in done.items():
            if hit and name not in self.milestones:
                self.milestones[name] = self.played_minutes()

    def run(self, days):
        marks = {}
        t = 0.0
        for day in range(1, days + 1):
            if self._day_off():
                self.advance(24 * 60.0)
                t += 24 * 60.0
                if day in (1, 7, 30, days):
                    marks["day %d" % day] = self.snapshot(t)
                continue
            self.days_played += 1
            for s in range(self.sessions):
                # How long until they next open the game - the gap between
                # sessions, or the whole night after the last one. It is what
                # decides how far this session's flights are sent.
                last = s == self.sessions - 1
                # session() advances its own clock now, so no advance here.
                self.session(self.session_len + (self.night if last else self.gap))
                t += self.session_len
                if day == 1 and s == 0:
                    marks["first session"] = self.snapshot(t)
                if s < self.sessions - 1:
                    self.advance(self.gap)
                    t += self.gap
            self.advance(self.night)
            t += self.night
            self._check_milestones()
            if day in (1, 7, 30, days):
                marks["day %d" % day] = self.snapshot(t)
        return marks

    def snapshot(self, t):
        return {
            "t": t, "money": self.money, "level": self.level, "coins": self.coins,
            "fleet": len(self.fleet), "pads": self.pads, "zones": len(self.zones),
            "built": len(self.built), "pop": (self.popularity() - 1.0) * 100.0,
            "best": max((a["a"]["name"] for a in self.fleet),
                        key=lambda n: 0, default="-") if self.fleet else "-",
            "fleet_names": sorted({f["a"]["name"] for f in self.fleet}),
            "played": self.days_played,
            "collections": self.collections,
            "coins_found": self.coins_found,
            "cycle_minutes": (sum(b["minutes"] for b in self.built) / len(self.built)
                              if self.built else 0.0),
        }


# --------------------------------------------------------------------------
# A cohort, rather than one imagined player
# --------------------------------------------------------------------------
#
# One player is an anecdote. The numbers that matter to a designer are the
# SPREAD: what the lightest player has after a month, what the heaviest has,
# and where the middle sits. A curve that is fine for the average and broken at
# both ends is a broken curve.
#
# Archetypes are sampled, not enumerated, because the axes are continuous and
# correlated in ways we cannot claim to know - how often you open the game, how
# long you stay, and how likely you are to disappear for a fortnight.
ARCHETYPES = [
    # name, sessions/day, minutes/session, lapse chance, longest break (days)
    ("lapsed",   (1, 2), (2.0, 5.0),  0.30, 14),
    ("casual",   (2, 4), (3.0, 8.0),  0.12, 7),
    ("regular",  (4, 6), (5.0, 12.0), 0.05, 4),
    ("heavy",    (6, 10), (8.0, 20.0), 0.02, 2),
]


def cohort(g, days, per_arch, seed=0):
    rng = random.Random(seed)
    out = []
    for name, (s_lo, s_hi), (m_lo, m_hi), lapse, brk in ARCHETYPES:
        rows = []
        for i in range(per_arch):
            sim = Sim(g, rng.randint(s_lo, s_hi), rng.uniform(m_lo, m_hi),
                      lapse=lapse, max_break=brk,
                      rng=random.Random(rng.randrange(1 << 30)))
            marks = sim.run(days)
            snap = marks["day %d" % days]
            snap["minutes"] = sim.played_minutes()
            snap["milestones"] = sim.milestones
            rows.append(snap)
        out.append((name, rows))
    return out


def report_cohort(g, days, per_arch, seed):
    print("  COHORT: %d players per archetype, %d days, min / mean / max\n"
          % (per_arch, days))
    fields = [("level", "level", "%d"), ("pads", "pads", "%d"),
              ("fleet", "fleet", "%d"), ("zones", "zones", "%d"),
              ("built", "bldgs", "%d"), ("money", "cash", "%,.0f")]
    print("  %-9s %8s %26s %26s" % ("", "played", "", ""))
    for name, rows in cohort(g, days, per_arch, seed):
        played = [r["played"] for r in rows]
        mins = [r["minutes"] for r in rows]
        print("  %-9s %3d-%-3d days   %.0f-%.0f min of play total"
              % (name, min(played), max(played), min(mins), max(mins)))
        for key, label, fmt in fields:
            v = sorted(r[key] for r in rows)
            avg = sum(v) / len(v)
            if fmt.startswith("%,"):
                cell = "%13s %13s %13s" % ("{:,.0f}".format(v[0]),
                                           "{:,.0f}".format(avg),
                                           "{:,.0f}".format(v[-1]))
            else:
                cell = "%13d %13.1f %13d" % (v[0], avg, v[-1])
            print("      %-7s %s" % (label, cell))
        print()


# How many HOURS AT THE CONTROLS it takes to exhaust the content, per archetype.
# The target this is measured against is 40 hours for an average player; days
# elapsed is not the unit, because a lapsed player and a heavy one can hit the
# same milestone on the same calendar day having played twenty times as much.
MILESTONES = ["all pads", "all zones", "all plots", "fleet ladder"]


def report_completion(g, days, per_arch, seed):
    print("  TIME TO EXHAUST THE CONTENT - hours of ACTUAL PLAY, not elapsed")
    print("  (%d players per archetype, given %d days of calendar)\n" % (per_arch, days))
    print("  %-9s %-14s %8s %8s %8s %7s" % ("", "milestone", "min", "mean", "max", "reached"))
    for name, rows in cohort(g, days, per_arch, seed):
        for i, m in enumerate(MILESTONES):
            hrs = sorted(r["milestones"][m] / 60.0 for r in rows if m in r["milestones"])
            label = name if i == 0 else ""
            if not hrs:
                print("  %-9s %-14s %8s %8s %8s %4d/%d"
                      % (label, m, "-", "-", "-", 0, len(rows)))
                continue
            print("  %-9s %-14s %8.1f %8.1f %8.1f %4d/%d"
                  % (label, m, hrs[0], sum(hrs) / len(hrs), hrs[-1], len(hrs), len(rows)))
        print()


# What the coin lottery actually pays, per archetype, at a range of rates. The
# number that matters is not the percentage - it is coins per month of real
# play, against prices of 5 (Paper Plane) to 70 (Ark).
def report_coins(g, days, per_arch, seed):
    rates = [0.0001, 0.0005, 0.00083, 0.0017, 0.0025]
    print("  COIN LOTTERY - collections and coins over %d days\n" % days)
    print("  rates below are PER MINUTE of cycle; a 12-min building at 0.00083"
          " rolls ~1%% a collection\n")
    print("  %-9s %12s %s" % ("", "collections",
                              "".join("%9s" % ("%.5f" % r) for r in rates)))
    for name, rows in cohort(g, days, per_arch, seed):
        cols = sum(r["collections"] for r in rows) / len(rows)
        mins = sum(r.get("cycle_minutes", 0.0) for r in rows) / len(rows)
        cells = "".join("%9.1f" % (cols * r * mins * g.coin_amount) for r in rates)
        print("  %-9s %12.0f %s" % (name, cols, cells))
    print("\n  cells are COINS EARNED in %d days, averaged over the cohort" % days)
    print("  prices: Paper Plane 5, USS-51 28, Ark 70, Eiffel Tower 30, "
          "apron skins and liveries also coin-priced")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--sessions", type=int, default=4, help="play sessions per day")
    ap.add_argument("--minutes", type=float, default=5.0, help="minutes per session")
    ap.add_argument("--pad-growth", type=float, default=0.0,
                    help="override ApronProgress.PAD_COST_GROWTH for tuning")
    ap.add_argument("--days", type=int, default=30)
    ap.add_argument("--cohort", type=int, default=0, metavar="N",
                    help="run N players per archetype and report min/mean/max")
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--no-coins", action="store_true",
                    help="never spend the coin float - models an earned-only run")
    ap.add_argument("--coins", type=int, default=0, metavar="N",
                    help="N players per archetype; report coin-lottery yield")
    ap.add_argument("--completion", type=int, default=0, metavar="N",
                    help="N players per archetype; report hours-of-play to finish")
    args = ap.parse_args()

    g = Game()
    # Tuning override, so a sweep does not mean editing the game between runs.
    if args.pad_growth:
        g.pad_growth = args.pad_growth
    print("  MODEL PLAYER: %d sessions/day x %g min  (%g min/day of actual play)"
          % (args.sessions, args.minutes, args.sessions * args.minutes))
    print("  reading: fare %d, %d aircraft, %d buildings, %d plots, %d Zone1 pads"
          % (g.fare, len(g.aircraft), len(g.buildings), g.plots, g.pads["Zone1"]))
    print("  %d destinations at %s clouds; longest leg that fits the gap wins\n"
          % (len(g.destinations), "/".join(str(d) for d, _ in g.destinations)))

    if args.coins:
        report_coins(g, args.days, args.coins, args.seed)
        return

    if args.completion:
        report_completion(g, args.days, args.completion, args.seed)
        return

    if args.cohort:
        report_cohort(g, args.days, args.cohort, args.seed)
        return

    sim = Sim(g, args.sessions, args.minutes)
    sim.no_coins = args.no_coins
    marks = sim.run(args.days)

    print("  %-14s %5s %10s %6s %5s %5s %6s %8s" %
          ("", "level", "cash", "fleet", "pads", "zones", "bldgs", "popular"))
    for name, m in marks.items():
        print("  %-14s %5d %10s %6d %5d %5d %6d %7.0f%%" % (
            name, m["level"], "{:,}".format(int(m["money"])), m["fleet"],
            m["pads"], m["zones"], m["built"], m["pop"]))

    last = list(marks.values())[-1]
    print("\n  fleet at the end: %s" % (", ".join(last["fleet_names"]) or "nothing"))
    print("  grounded %d time(s): %d fixed by selling an aircraft, %d by spending coins"
          % (sim.sold + sim.rescues, sim.sold, sim.rescues))
    print("  coins: %d of %d left" % (sim.coins, g.start_coins))
    if sim.rescues:
        zero = [a["name"] for a in g.aircraft
                if a.get("currency") == "coins" and a["fuel"] == 0]
        print("  the escape hatch is %s - the only aircraft that burns no fuel."
              % (", ".join(zero) or "nothing"))
        print("  %d rescues available in total, then the deadlock is permanent."
              % (g.start_coins // min(a["price"] for a in g.aircraft
                                      if a.get("currency") == "coins" and a["fuel"] == 0)))


if __name__ == "__main__":
    main()
