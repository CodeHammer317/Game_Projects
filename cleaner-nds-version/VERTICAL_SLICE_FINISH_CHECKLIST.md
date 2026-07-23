# Vertical Slice Finish Checklist

Use this list for the final push toward a shareable demo. Check an item only after testing it in a fresh run, not just after confirming that the scene or script exists.

## P0 — Complete playable route

- [ ] Finish one uninterrupted run through Title Screen → Cold Open → Study → Upgrade Chamber → Coffee Shop → Old District → Subway → Pulse Chamber → Study Debrief → Credits → Title Screen.
- [ ] Confirm every exit/transition works once, cannot trigger twice, and places the player at the correct spawn point.
- [ ] Confirm a new game clears old run state: upgrades, Archivist files, checkpoints, finale state, health, lives, and meters.
- [ ] Confirm returning to the title screen after the credits allows a second clean playthrough without restarting the game.
- [ ] Test death and respawn before and after every checkpoint in the Old District and Subway.
- [ ] Test death, retry, and room reset during the Glitch Demon encounter.
- [ ] Confirm cutscenes and dialogue always return player control when expected.
- [ ] Confirm Archivist File 03 can be opened and closed after the boss without soft-locking the ending sequence.

## P0 — Core gameplay

- [ ] Verify movement, jump, dodge, melee, shooting, assist, and special-meter controls with both keyboard and a controller.
- [ ] Confirm every on-screen control prompt matches the actual input action.
- [ ] Confirm Double Jump is awarded exactly once, remains available for the rest of the run, and is clearly taught in the Upgrade Chamber.
- [ ] Confirm enemy attacks, stage hazards, and projectiles damage the player consistently and provide readable warning/impact feedback.
- [ ] Confirm health, lives, special meter, relics, and helper status update correctly in the HUD.
- [ ] Confirm pickups cannot be collected twice or remain visible after collection.
- [ ] Tune the Glitch Demon so all attacks have readable tells, fair recovery windows, and no unavoidable damage combinations.
- [ ] Confirm defeating the boss disables its remaining attacks, projectiles, hazards, and combat audio before the ending begins.

## P1 — Story and level content

- [ ] Match the Cold Open copy, panel order, timing, and reveal limits to `STORYBOARD_VERTICAL_SLICE.md`.
- [ ] Review the Study briefing and optional interactions for clarity before the player enters combat.
- [ ] Give the Coffee Shop a clear transition beat and enough direction that the exit is never confusing.
- [ ] Confirm the Old District teaches basic combat, ranged threats, assist use, pickups, and enemy tells in a safe difficulty curve.
- [ ] Confirm the Subway tests Double Jump and mixed enemy pressure without requiring blind jumps.
- [ ] Ensure the Old District, Subway, and Pulse Chamber each include one joke, one unsettling image, and one meaningful clue.
- [ ] Confirm Archivist Files 01–03 have the correct IDs, titles, order, placement, reader controls, and collected-state behavior.
- [ ] Make the main plot understandable even if Files 01 and 02 are missed.
- [ ] Add or finalize short squad banter in each gameplay level without interrupting active combat.
- [ ] Proofread all dialogue, prompts, document text, end-card text, and credits for spelling, punctuation, and character-name consistency.
- [ ] Confirm Azazel is not named before File 03/the earned finale reveal.
- [ ] Confirm Cat Milk Factory content cannot be reached during the vertical slice.

## P1 — Visual and audio polish

- [ ] Replace or intentionally approve every remaining placeholder sprite, icon, background, animation, and sound.
- [ ] Check sprite scale, filtering, camera framing, and pixel consistency in every scene at the target window size.
- [ ] Check HUD, dialogue panels, document readers, prompts, end card, and credits for clipping or overlap.
- [ ] Add clear visual feedback for interactions, pickups, locked controls, checkpoints, damage, enemy death, and boss defeat.
- [ ] Remove visible seams, unreachable empty areas, collision snags, and places where the player can leave the camera or level bounds.
- [ ] Balance music, ambience, dialogue sounds, attacks, impacts, alerts, and boss audio so important cues remain audible.
- [ ] Confirm every AudioStreamPlayer stops or transitions cleanly when its scene changes.
- [ ] Review the final explosion, debrief, end card, and credits as one continuous sequence for pacing and tone.

## P1 — Balance and player guidance

- [ ] Playtest with someone who has not seen the project and record every point where they stop knowing what to do.
- [ ] Keep the complete slice near the storyboard target length and remove stretches with no decision, threat, clue, or character beat.
- [ ] Make checkpoints frequent enough that a death never forces the player to repeat a long dialogue or tutorial.
- [ ] Check health, lives, and meter pickup placement against a first-time player's likely resource use.
- [ ] Confirm the difficulty rises from Old District → Subway → Pulse Chamber without a sudden unexplained spike.
- [ ] Verify that important exits, interactables, threats, and collectibles are readable against their backgrounds.

## P2 — Nice-to-have scope

- [ ] Add progressively corrupted environmental screens if the must-ship route is already stable.
- [ ] Add one optional Double Jump hidden room with a worthwhile but nonessential reward.
- [ ] Add a brief prophecy/weak-point effect during the Glitch Demon fight.
- [ ] Add a mission-results screen only if it does not delay export testing.
- [ ] Give live, recovered, and damaged Archivist recordings distinct voice processing.

## Release QA

- [ ] Run Godot's project validation with no parse or resource-load errors.
- [ ] Clear the debugger output, then complete a full playthrough with no new errors or unexpected warnings.
- [ ] Test windowed and fullscreen presentation, focus loss, pause/resume, and quitting back to the desktop.
- [ ] Test keyboard-only and controller-only runs from title screen through credits.
- [ ] Test the release export—not only the editor build—from a clean folder.
- [ ] Confirm the export includes every required scene, asset, font, shader, audio file, and project setting.
- [ ] Check loading time, frame pacing, and memory use in the largest scenes and during the boss finale.
- [ ] Verify save/config files fail safely when missing or from an older build.
- [ ] Confirm the build has the correct game title, icon, version number, credits, license notices, and README/instructions.
- [ ] Zip a release candidate, perform one final clean playthrough from that exact archive, and keep it unchanged for distribution.

## Definition of done

- [ ] All P0 items are complete.
- [ ] All P1 items are complete or have an explicit accepted exception.
- [ ] No known crash, soft lock, broken transition, lost-input state, or progression blocker remains.
- [ ] A first-time player can start, understand, finish, and replay the demo without developer help.
- [ ] The distributed release candidate passes the same title-to-credits test as the editor build.
