# Nephilim Death Squad — Vertical Slice Storyboard

## Canonical slice premise

A rogue Vatican archivist intercepts evidence of an AI-assisted Nephilim resurrection project. Before the archivist can finish the transmission, the same occult signal appears beneath the Old District. NDS deploys through the quarantined streets and abandoned subway, destroys the Glitch Demon anchoring the signal, and recovers proof that the incident is one node in Azazel's global plan.

The slice adapts the opening of **The Awakening of Shadows** into one compact episode using the project's connected scenes. It should answer the local mystery, establish the Archivist as an endangered ally, and end with a clear campaign-scale threat.

## Canonical player route

`Title → Archivist Transmission → Study Briefing → Upgrade Chamber → Coffee Shop → Old District → Subway → Pulse Chamber → Debrief/Epilogue`

The Cat Milk Factory and Cat Overlord are not part of the vertical-slice canon. Their existing scenes may remain in the project as archived prototype material, but no required story beat, collectible, or transition may depend on them.

## Player-facing level flow

### 0. Cold Open — “The Leak”

**Scene:** `Scenes/World/opening_screen.tscn`  
**Format:** Three-panel intercepted transmission  
**Target length:** 30–45 seconds

#### Panel 1 — The unauthorized upload

**Visual:** A lone archivist works at a hidden terminal beneath the Vatican. Security agents enter the archive behind him.

**Source label:** `ROGUE ARCHIVIST // ENCRYPTED CHANNEL`

**Archivist:**

> NDS, if this reaches you, the Vatican archive has been compromised. I found the source of the tremors.

**Story job:** Establish that the Archivist chose to contact NDS and is already in danger.

#### Panel 2 — Demon Protocol

**Visual:** A colossal pre-Flood skeleton, an artificial vessel, occult machinery, and an AI analysis system share the same sigil.

**Source label:** `ARCHIVIST FILE UPLOAD // FRAGMENT 01`

**Archivist:**

> Excavation records. Pre-Flood remains. Artificial vessels. An intelligence they call DEMON PROTOCOL is choosing compatible hosts.

**Story job:** State the central conspiracy in plain language without identifying its architect.

#### Panel 3 — The local match

**Visual:** The transmission collapses as agents reach the Archivist. NDS detects the matching sigil beneath the Old District subway.

**Source label:** `ROGUE ARCHIVIST // SIGNAL BREAKING`

**Archivist:**

> They know I'm transmitting. The same sigil is active beneath your city, near the abandoned subway. Do not trust the official quarantine—

**System:**

> TRANSMISSION TERMINATED  
> NDS TRACE: LOCAL MATCH CONFIRMED

**Story job:** Convert exposition into an immediate field objective and leave the Archivist's fate unresolved.

**Reveal limit:** The cold open may name **Demon Protocol**, but it must not name Azazel or fully explain the resurrection network.

---

### 1. NDS Safehouse — “First Field Deployment”

**Scene:** `Scenes/World/study.tscn`  
**Briefing UI:** `Scenes/World/level_01_briefing_screen.tscn`  
**Target length:** 2–3 minutes

- NDS authenticates the transmission by matching its sigil to the seismic pulse beneath the city.
- The official quarantine claims a gas leak; the Archivist explicitly warned NDS not to trust it.
- Mission objective: cross the Old District, enter the abandoned subway, trace the signal, recover the Archivist's evidence, and neutralize its guardian.
- Optional teammate banter introduces the squad's personality.
- The cold coffee and continuing tremors keep the threat physically present.

**Briefing anchor:**

> TOP LOBSTA: At 02:13 we caught an unauthorized transmission from beneath the Vatican Archive. Thirty seconds later, the same sigil lit up under our Old District. We are treating that as a distress call and a target lock.

**Gameplay job:** Let the player move, interact, and understand the mission before combat.

**Story reveal:** The Archivist's leak and the local tremors are parts of the same event.

---

### 2. Upgrade Chamber — “Field Baptism”

**Scene:** `Scenes/World/upgrade_chamber.tscn`  
**Reward:** Double Jump  
**Target length:** 2–3 minutes

- A recovered relic responds to the incoming signal and grants Double Jump.
- NDS describes the response as **faith resonance**, not ordinary technology.
- The relic briefly displays the Archivist's sigil, suggesting both systems draw from the same ancient source.
- A short traversal challenge requires Double Jump to exit.

**Gameplay job:** Teach traversal and establish the upgrade/relic loop.

**Story reveal:** NDS can resist and repurpose the same ancient forces that Demon Protocol is exploiting.

---

### 3. Coffee Shop — “Last Stop Above Ground”

**Scene:** `Scenes/World/coffee_shop.tscn`  
**Target length:** 30–60 seconds

- The route passes the Standard Coffee Shop at the edge of the quarantine.
- Broadcast audio repeats the official gas-leak story.
- A cup rattles with each underground pulse.
- Squad banter gets one short joke before the tone darkens.

**Suggested banter:**

> MATTT: If this really is a gas leak, I want it noted that I heroically volunteered from outside the blast radius.

**Gameplay job:** Provide a short tonal bridge from safehouse preparation to hostile streets.

**Story reveal:** The cover story is active before NDS reaches the barricades.

---

### 4. Old District — “Tremors and Static”

**Scene:** `Scenes/World/Level_01_Old_District.tscn`  
**Target length:** 6–8 minutes

- Government barricades blame a gas leak while digital signs repeat the leaked sigil.
- Early enemies appear mundane, then reveal visible digital corruption.
- Missing-person posters and dragged footprints point toward the subway.
- Mattt's assist is introduced during a controlled encounter.
- A corrupted municipal terminal contains **Archivist File 01**.
- A mini-arena ends when a damaged machine broadcasts a distorted Gregorian phrase and unlocks the subway route.

**Gameplay job:** Teach basic combat, ranged threats, assist use, pickups, and enemy tells.

**Story reveal:** The signal travels through both the ground and the city's electronic network.

#### Archivist File 01 — “Vessel Selection”

> ARCHIVIST LOG 7C. The excavation team is not searching for relics. They are searching for candidates. Demon Protocol compares living subjects against something recovered from the pre-Flood remains. The rejected names are transferred to local holding sites. I cannot find records of their release.

**Collectible job:** Reframe the missing persons as test subjects without explaining the final resurrection process.

---

### 5. Abandoned Subway — “The Signal Below”

**Scene:** `Scenes/World/subway_level_01.tscn`  
**Target length:** 6–8 minutes

- The tone shifts from street investigation to underground horror.
- Pulsing lights, chanting speakers, biological residue, and corrupted infrastructure guide the player downward.
- Double Jump traversal crosses collapsed platforms, electrified rails, and ruptured pipes.
- Encounters combine physical ambushes, ranged enemies, and clearly glitched foes.
- An abandoned Vatican transport case contains **Archivist File 02**.
- Freight tracks do not lead to a factory; they terminate at a sealed excavation door feeding the Pulse Chamber.

**Gameplay job:** Test traversal under pressure and combine the enemy types taught above ground.

**Story reveal:** The subway was used to move excavation equipment and human candidates into a chamber beneath the city.

#### Archivist File 02 — “The Gilgamesh Reference”

> ARCHIVIST LOG 9A. The local chamber is only a signal anchor. The primary remains are held elsewhere under the designation GILGAMESH. Every anchor is teaching the same intelligence how to cross from corrupted data into living tissue. If the anchors synchronize, containment becomes resurrection.

**Collectible job:** Explain the function of the local site and foreshadow the full campaign's scale.

---

### 6. Pulse Chamber — “Cut the Signal”

**Scene:** `Scenes/World/pulse_chamber.tscn`  
**Boss:** Glitch Demon  
**Target length:** 4–6 minutes

- The chamber is an occult signal anchor built from excavation machinery and corrupted city infrastructure.
- The Glitch Demon is the signal given a temporary body, not the mastermind behind it.
- Its attacks combine physical danger with visual corruption and electronic interference.
- Mattt's assist and the player's movement/combat kit create the finishing opening.
- On defeat, Raven plants charges while NDS extracts the chamber's final data fragment.
- The fragment is **Archivist File 03** and contains the first explicit identification of Azazel.

**Gameplay job:** Test mastery of movement, shooting, melee, dodging, assist timing, and hazard awareness.

**Story reveal:** Destroying the demon closes the local anchor, but other anchors remain active.

#### Archivist File 03 — “The Architect”

> ARCHIVIST DEAD-DROP. I found the authorization chain. There is no department, council, or human director at its end. Only one name, repeated in every era of the archive: AZAZEL. Demon Protocol is not creating his army. It is rebuilding one that remembers him.

**Collectible job:** Name the campaign antagonist only after the player earns the local victory.

---

### 7. Debrief/Epilogue — “We Are Already Behind”

**Scene:** `Scenes/World/study.tscn`  
**Format:** Locked in-engine debrief, final character beat, end card, and credits

- The Pulse Chamber collapses and the Old District signal goes dark.
- The player returns to the Study and remains control-locked throughout the finale.
- NDS confirms that the local anchor and Glitch Demon were destroyed.
- The recovered Archivist files establish that other anchors remain active and that Azazel is their architect.

**Debrief screen:**

> LOCAL ANCHOR: DESTROYED  
> GLITCH DEMON: NEUTRALIZED  
> ARCHIVIST FILES: RECOVERED

**Nancy:**

> Did you remember to pickup my catfood?

- Cut to black and display **THE END**.
- Roll credits while the title-screen theme plays without looping.
- Return to the title screen after the credits.

**Story job:** Confirm the local victory, preserve the wider threat, and release the tension with one final squad-character joke before ending the demo.

## The Archivist — scripting guide

### Identity in the slice

- Refer to the character only as **the Archivist**.
- Do not reveal a civilian name, rank, face, or exact allegiance in the vertical slice.
- The Archivist has access to forbidden records but is not omniscient.
- The Archivist contacted NDS deliberately after discovering that official channels were compromised.
- Whether the Archivist escaped, was captured, or died remains unanswered.

### Voice

- Precise, educated, restrained, and urgently practical.
- Speaks in evidence and consequences rather than mystical riddles.
- Fear appears through shortened sentences and missing context, not panic or melodrama.
- Treats faith as an act of resistance and moral choice, not as decorative occult vocabulary.
- Never dumps lore that the current scene does not need.

### Information ladder

1. **Cold open:** Demon Protocol selects hosts; a matching signal exists locally.
2. **File 01:** Missing people are being screened as vessels.
3. **File 02:** Local chambers are synchronized resurrection anchors; Gilgamesh exists.
4. **File 03:** Azazel is the architect behind the network.
5. **Epilogue:** Multiple anchors are already active and beginning to communicate.

### Formatting rules

- Live transmissions use `ROGUE ARCHIVIST // ENCRYPTED CHANNEL`.
- Recovered logs use `ARCHIVIST LOG` followed by a short fragment code.
- The final recovery uses `ARCHIVIST DEAD-DROP`.
- System messages are uppercase and contain no character voice.
- Keep every spoken or displayed block readable in five to twelve seconds.

## Slice arc at a glance

1. **Question:** Why did a Vatican Archivist warn NDS about a signal beneath an ordinary city?
2. **Investigation:** Street corruption, missing persons, and subway shipments lead to a buried anchor.
3. **Answer:** Demon Protocol is using AI to select vessels and teach ancient corruption to inhabit living tissue.
4. **Victory:** NDS destroys the Glitch Demon and shuts down the local anchor.
5. **Hook:** Azazel controls a global network, and the remaining anchors are beginning to synchronize.

## Production scope

### Must ship

- Archivist transmission cold open
- Study briefing and optional interactions
- Upgrade Chamber and Double Jump tutorial
- Coffee Shop transition beat
- Old District combat tutorial
- Subway traversal level
- Pulse Chamber and Glitch Demon finale
- Archivist Files 01–03
- Short squad banter in each gameplay level
- Debrief/epilogue and campaign end card

### Nice to have

- Environmental screens that become increasingly corrupted
- One optional hidden room requiring Double Jump
- A brief prophecy/weak-point effect during the Glitch Demon fight
- End-of-slice mission-results screen
- Unique voice processing for live, recovered, and damaged Archivist recordings

### Explicitly cut from the vertical slice

- Cat Milk Factory level
- Relay shutdown objectives
- Cat Overlord boss
- Corporate dairy conspiracy beats
- Factory-specific collectibles and dialogue

### Save for the full campaign

- Playable Vatican Archives
- Playable Mesopotamia/Gilgamesh Chamber
- Multiple selectable faith powers
- Giant boss battles
- Physical/spiritual plane switching
- The Archivist's true identity and fate
- Full Azazel confrontation

## Narrative guardrails

- Keep the conspiracy heightened and fictional; humor should come from squad chemistry, not from undermining the threat.
- Every gameplay level should contain one joke, one unsettling image, and one meaningful clue.
- Faith powers represent resilience, discernment, and resistance to corruption—not generic spellcasting.
- Azazel remains unseen in the slice. A name, sigil, recovered authorization, and final consequence are enough.
- The three Archivist files deepen the mystery, but the main mission must remain understandable if a player misses them.
- Never imply that the Glitch Demon is the ultimate villain; it is a dangerous local manifestation of a larger system.
