# Nephilim Death Squad — Vertical Slice Storyboard

## Slice premise

A routine tremor beneath the Old District exposes a hidden supply line feeding an AI-assisted Nephilim resurrection project. The player follows the signal from an NDS safehouse, through the streets and abandoned subway, into the front operation of a corrupted laboratory. Defeating its guardian reveals that the incident is part of Azazel's larger plan.

The slice adapts the opening of **The Awakening of Shadows** to the scenes and mechanics already present in the project. It should feel like one complete episode while ending with a clear hook for the wider campaign.

## Player-facing level flow

### 0. Cold Open — “The Leak”

**Format:** Short comic-panel intro  
**Existing assets:** `Assets/Comic/`

- A rogue Vatican archivist transmits fragments of a classified file.
- Images flash by: pre-Flood symbols, an excavation, genetic tanks, and an AI diagram labeled **DEMON PROTOCOL**.
- The transmission is interrupted before the archivist can identify the project leader.
- Final panel: NDS detects the same symbol beneath the player's city.

**Story job:** Establish the ancient/modern conspiracy quickly and give the mission urgency.

**Target length:** 30–45 seconds.

---

### 1. NDS Safehouse — “First Field Deployment”

**Scene:** `Scenes/World/study.tscn`  
**Briefing UI:** `Scenes/World/level_01_briefing_screen.tscn`

- The player begins in the Study, which serves as the NDS safehouse.
- Optional interactions establish tone:
  - Teammate banter introduces the squad's podcast-like personality.
  - The cold coffee and tremors suggest the disturbance is already close.
  - A shelf or terminal contains the first conspiracy-lore collectible.
- The mission briefing identifies a Nephilim signature beneath the abandoned subway near the Standard Coffee Shop.
- Objective: enter the Old District, trace the signal, recover evidence, and neutralize anything guarding it.

**Gameplay job:** Let the player move, interact, and absorb the premise before combat.

**Story reveal:** The symbols from the Vatican leak match the local seismic signal.

**Target length:** 2–3 minutes.

---

### 2. Upgrade Chamber — “Field Baptism”

**Scene:** `Scenes/World/upgrade_chamber.tscn`  
**Reward:** Double Jump

- The player enters the NDS relic chamber before deployment.
- A recovered artifact activates and grants Double Jump.
- The upgrade is framed as a **faith resonance** rather than ordinary technology: the relic responds to conviction and reveals movement paths that should be impossible.
- A short tutorial requires the new ability to exit.

**Gameplay job:** Teach traversal and establish the upgrade/relic loop.

**Story reveal:** NDS combines ancient relic knowledge with modern field equipment, but does not fully understand either.

**Target length:** 2–3 minutes.

---

### 3. Level 1A: Old District — “Tremors and Static”

**Scene:** `Scenes/World/Level_01_Old_District.tscn`

- The player crosses streets under a quiet quarantine.
- Early enemies appear human or mundane, then show signs of digital corruption.
- Environmental storytelling:
  - Government barricades blame a gas leak.
  - Screens flicker with a repeated sigil.
  - Missing-person posters lead toward the subway.
- Mattt's assist ability is introduced during a controlled encounter.
- A mini-arena ends when a corrupted machine broadcasts a distorted Gregorian phrase.
- The subway entrance opens after the signal is traced.

**Gameplay job:** Teach basic combat, ranged threats, assist use, pickups, and enemy tells.

**Story reveal:** The “Nephilim signature” is traveling through both the ground and the city's electronic network.

**Collectible:** Archivist File 01 — a redacted reference to “AI-guided vessel selection.”

**Target length:** 6–8 minutes.

---

### 4. Level 1B: Abandoned Subway — “The Signal Below”

**Scene:** `Scenes/World/subway_level_01.tscn`

- The subway shifts the tone from street investigation to underground horror.
- The player follows pulsing lights, chanting speakers, and biological residue.
- Traversal uses Double Jump over collapsed platforms, electrified rails, and ruptured pipes.
- Enemy encounters mix physical ambushes with the first clearly supernatural or glitched foe.
- Mid-level discovery: supply crates bear both a corporate dairy logo and the Vatican archive symbol.
- At the exit, the player sees freight tracks leading directly to the Cat Milk Factory.

**Gameplay job:** Test traversal under pressure and combine enemy types.

**Story reveal:** A ridiculous local company is functioning as a front for a serious occult logistics network.

**Collectible:** Archivist File 02 — the phrase **Gilgamesh Chamber** and a partial image of a giant skeleton.

**Target length:** 5–7 minutes.

---

### 5. Level 2A: Cat Milk Factory — “Demon Protocol”

**Scene:** `Scenes/World/level_02_cat_milk_factory_entrance.tscn`

- The factory begins as corporate satire and becomes an AI demon lab.
- Production machinery processes an unidentified luminous substance rather than milk.
- Roomba drones and automated defenses behave as if possessed.
- Loudspeakers alternate between cheerful advertising and corrupted liturgy.
- The player disables three production relays to unlock the executive core.
- Each relay reveals part of the operation:
  1. Biological material arrives from excavation sites.
  2. AI identifies compatible hosts.
  3. The finished product stabilizes Nephilim tissue.

**Gameplay job:** Deliver the slice's most complete combat/traversal level and escalate enemy combinations.

**Story reveal:** The conspiracy uses ordinary consumer infrastructure to hide an AI-driven resurrection supply chain.

**Collectible:** Archivist File 03 — authorization signed only with the sigil of **Azazel**.

**Target length:** 8–10 minutes.

---

### 6. Level 2B: Factory Core — “The Cat Overlord”

**Scene:** `Scenes/World/level_02_cat_milk_factory_boss.tscn`  
**Boss:** Cat Overlord

- The Cat Overlord is the factory's mascot, executive guardian, and corrupted AI vessel.
- Phase 1 emphasizes comic corporate attacks: product projectiles, drones, and arena hazards.
- Phase 2 reveals the infernal machine beneath the mascot shell.
- A prophecy vision briefly highlights the boss's weak point, introducing the faith-power concept without requiring a full new system.
- Mattt's assist and the player's core combat abilities create the finishing opening.
- On defeat, the boss transmits its final data packet to an unknown receiver.

**Gameplay job:** Test mastery of movement, shooting/melee, dodging, assist timing, and hazard awareness.

**Story reveal:** The Cat Overlord was not the mastermind. It was one node in Azazel's Demon Protocol.

**Target length:** 4–6 minutes.

---

### 7. Epilogue — “We Are Already Behind”

**Format:** Short in-engine scene or comic-panel outro

- NDS recovers the factory database.
- A map shows linked sites in Vatican City, Mesopotamia, and Babel.
- The rogue archivist's final recovered message identifies Azazel as “the architect.”
- Deep beneath the Gilgamesh Chamber, an enormous eye opens.
- End card: **THE AWAKENING OF SHADOWS**

**Story job:** Resolve the local mission, name the larger antagonist, and promise the giant-scale campaign.

**Target length:** 45–60 seconds.

## Slice arc at a glance

1. **Question:** Why is a Nephilim signal appearing beneath an ordinary city?
2. **Investigation:** The signal connects street corruption, the subway, and a corporate factory.
3. **Answer:** The factory is part of an AI-assisted resurrection network.
4. **Victory:** The player destroys the local guardian and recovers proof.
5. **Hook:** Azazel controls a global network, and something beneath Mesopotamia has awakened.

## Recommended slice scope

### Must ship

- Study briefing and optional interactions
- Upgrade Chamber and Double Jump tutorial
- Old District combat tutorial
- Subway traversal level
- Cat Milk Factory main level
- Cat Overlord boss
- Three lore collectibles
- Cold open and epilogue using existing comic-panel presentation
- Short squad banter in every gameplay level

### Nice to have

- Prophecy-vision visual effect during the boss
- Relay shutdown objectives in the factory
- Environmental screens that become increasingly corrupted
- One optional hidden room requiring Double Jump
- End-of-slice mission-results screen

### Save for the full campaign

- Playable Mesopotamia/Gilgamesh Chamber
- Vatican Archives level
- Multiple selectable faith powers
- Giant boss battles
- Physical/spiritual plane switching
- Full Azazel confrontation

## Narrative guardrails

- Keep the conspiracy fun, heightened, and fictional; the humor should come from the squad and absurd cover operations, not from undermining the threat.
- Every level should contain one joke, one unsettling image, and one meaningful clue.
- Faith powers should represent resilience, discernment, and resistance to corruption—not generic spellcasting.
- Azazel should remain mostly unseen in the slice. A name, sigil, voice fragment, and final consequence will make the reveal stronger.
- Collectibles should deepen the mystery without carrying information required to understand the main objective.
