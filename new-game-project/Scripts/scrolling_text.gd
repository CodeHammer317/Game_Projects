extends Label

var main_text := """
NDS // Secure Channel 7
Clearance: Field Operative

Agent,

Your investigation at the Christian Library triggered multiple alerts across our network.
The symbols you uncovered match pre‑Flood inscriptions found at three recent incident sites.

At 0430 hours, a civilian reported tremors beneath the Old District.
Local authorities dismissed it as construction noise.
Our sensors say otherwise.

A Nephilim signature — faint, but rising — is pulsing beneath the abandoned subway line
near the Standard Coffee Shop.

Your objectives are as follows:

1. Enter the Old District undetected.
2. Locate the source of the seismic activity.
3. Recover any relics, documents, or biological traces.
4. Neutralize hostile entities if encountered.
5. Extract before the area is quarantined by government forces.

Expect resistance.
Expect misinformation.
Expect the truth to fight back.

This is your first field deployment, Agent…
but you’ve seen more than most recruits ever will.

Trust your instincts.
Trust the signs.
And remember:

If the Nephilim are waking,
we are already behind.
"""

func _ready() -> void:
	scrolling_text(main_text)


func scrolling_text(input_text: String) -> void:
	visible_characters = 0
	text = input_text

	# Loop through each character index
	for i in range(text.length()):
		visible_characters = i + 1
		await get_tree().create_timer(0.03).timeout
