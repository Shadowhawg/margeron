-- The story told through cutscenes: the prologue, and the "Echoes" (memories) unlocked by the main quests.
--
-- A cutscene is a list of shots. Each shot:
--   From / To   camera keyframes: { Pos = <point>, Look = <point> }. The camera glides From -> To.
--               A point is either a Vector3 whose Y is the height ABOVE THE GROUND at that X/Z,
--               or { Anchor = "Player" | "<NPC id>", Offset = Vector3 } (offset in the anchor's space).
--   Duration    seconds the shot lasts (it also waits for the lines to finish)
--   Black       true = no picture, just text on black
--   Lines       { { Speaker = "...", Text = "..." }, ... } shown one after another
--
-- "{name}" in any line is replaced with the player's name, "{race}" with their race.
local VOICE = "The Voice"

local Story = {}

Story.Cutscenes = {
	Prologue = {
		Title = "Margeron",
		Subtitle = "The Unremembered",
		Music = "Prologue",
		Shots = {
			{
				Black = true,
				Duration = 4,
				Lines = {
					{ Speaker = VOICE, Text = "Breathe." },
					{ Speaker = VOICE, Text = "...Good. You still remember how to do that, at least." },
				},
			},
			{
				From = { Pos = Vector3.new(-200, 40, 260), Look = Vector3.new(-40, 4, 190) },
				To = { Pos = Vector3.new(-90, 18, 230), Look = Vector3.new(-40, 2, 200) },
				Duration = 9,
				Lines = {
					{
						Speaker = VOICE,
						Text = "You won't remember me. You won't remember anything. Not your name. Not your face.",
					},
					{ Speaker = VOICE, Text = "Not the oath you swore on the mountain." },
					{ Speaker = VOICE, Text = "That was the price. I'm sorry. I was there when we paid it." },
				},
			},
			{
				From = { Pos = Vector3.new(300, 90, -300), Look = Vector3.new(1180, 20, -1180) },
				To = { Pos = Vector3.new(420, 110, -420), Look = Vector3.new(1180, 40, -1180) },
				Duration = 9,
				Lines = {
					{ Speaker = VOICE, Text = "Look east. Do you see the glow on the peak? That's not the sunrise." },
					{
						Speaker = VOICE,
						Text = "Something under that mountain is waking up. And when it opens its eyes...",
					},
					{ Speaker = VOICE, Text = "...it will be looking for you." },
				},
			},
			{
				From = { Pos = Vector3.new(120, 60, 150), Look = Vector3.new(0, 10, 0) },
				To = { Pos = Vector3.new(60, 35, 110), Look = Vector3.new(0, 8, -10) },
				Duration = 8,
				Lines = {
					{
						Speaker = VOICE,
						Text = "That's Riverwatch. There are people there who will need you, though they won't know why.",
					},
					{ Speaker = VOICE, Text = "Neither will you. Not yet." },
				},
			},
			{
				From = {
					Pos = { Anchor = "Player", Offset = Vector3.new(0, 12, -14) },
					Look = { Anchor = "Player", Offset = Vector3.new(0, 0, 0) },
				},
				To = {
					Pos = { Anchor = "Player", Offset = Vector3.new(0, 3, -7) },
					Look = { Anchor = "Player", Offset = Vector3.new(0, 1, 0) },
				},
				Duration = 6,
				Lines = {
					{ Speaker = VOICE, Text = "First things first. Lean over the water. Look at your reflection." },
					{ Speaker = VOICE, Text = "Tell me who you see." },
				},
			},
		},
	},

	-- Plays right after character creation.
	Awakening = {
		Music = "Prologue",
		Shots = {
			{
				From = {
					Pos = { Anchor = "Player", Offset = Vector3.new(4, 3, -6) },
					Look = { Anchor = "Player", Offset = Vector3.new(0, 1.5, 0) },
				},
				To = {
					Pos = { Anchor = "Player", Offset = Vector3.new(2, 2.5, -5) },
					Look = { Anchor = "Player", Offset = Vector3.new(0, 1.5, 0) },
				},
				Duration = 6,
				Lines = {
					{ Speaker = VOICE, Text = "There you are. A {race}." },
					{ Speaker = VOICE, Text = "...Strange. You look exactly the way I remember." },
				},
			},
			{
				From = {
					Pos = { Anchor = "Player", Offset = Vector3.new(0, 6, 10) },
					Look = { Anchor = "Player", Offset = Vector3.new(0, 2, -20) },
				},
				To = {
					Pos = { Anchor = "Player", Offset = Vector3.new(0, 8, 14) },
					Look = { Anchor = "Player", Offset = Vector3.new(0, 4, -40) },
				},
				Duration = 7,
				Lines = {
					{ Speaker = VOICE, Text = "Now get up. Cross the bridge. Find the elder of Riverwatch." },
					{ Speaker = VOICE, Text = "And whatever happens, {name}... don't tell anyone you can hear me." },
				},
			},
		},
	},

	Echo1 = {
		Title = "Echo I",
		Subtitle = "The Burning Wood",
		Music = "Echo",
		Shots = {
			{
				From = { Pos = Vector3.new(470, 30, 60), Look = Vector3.new(560, 10, -40) },
				To = { Pos = Vector3.new(500, 22, 20), Look = Vector3.new(580, 8, -60) },
				Duration = 10,
				Lines = {
					{ Speaker = VOICE, Text = "Did you notice? The wolves weren't hunting. They were fleeing." },
					{ Speaker = VOICE, Text = "Animals always know first." },
					{
						Speaker = VOICE,
						Text = "You knew too, once. You stood on a hill like this and watched a whole forest burn.",
					},
					{ Speaker = VOICE, Text = "You didn't run. I remember that. You never ran." },
				},
			},
		},
	},

	Echo2 = {
		Title = "Echo II",
		Subtitle = "A Blade With a Name",
		Music = "Echo",
		Shots = {
			{
				From = {
					Pos = { Anchor = "Player", Offset = Vector3.new(3, 2, -4) },
					Look = { Anchor = "Player", Offset = Vector3.new(0, 1, 0) },
				},
				To = {
					Pos = { Anchor = "Player", Offset = Vector3.new(1.5, 1.5, -3) },
					Look = { Anchor = "Player", Offset = Vector3.new(0, 0.5, 0) },
				},
				Duration = 10,
				Lines = {
					{
						Speaker = VOICE,
						Text = "You held that sword like you'd held one for a hundred years. Brann noticed. He said nothing. Good man.",
					},
					{ Speaker = VOICE, Text = "There was another blade, once. Silver. It had a name. You named it." },
					{ Speaker = VOICE, Text = "...I can't remember what. That's how I know I'm fading too." },
				},
			},
		},
	},

	Echo3 = {
		Title = "Echo III",
		Subtitle = "What Was Buried",
		Music = "Echo",
		Shots = {
			{
				From = { Pos = Vector3.new(120, 50, -650), Look = Vector3.new(220, 5, -800) },
				To = { Pos = Vector3.new(170, 30, -700), Look = Vector3.new(220, 5, -820) },
				Duration = 11,
				Lines = {
					{
						Speaker = VOICE,
						Text = "Grisk's map was marked with the old crypt. Someone paid the Redfangs to dig there.",
					},
					{ Speaker = VOICE, Text = "Someone who knows what's buried in that crypt." },
					{ Speaker = VOICE, Text = "...Someone who knows what YOU buried in that crypt." },
				},
			},
		},
	},

	Echo4 = {
		Title = "Echo IV",
		Subtitle = "The Ashen Guard",
		Music = "Echo",
		Shots = {
			{
				Black = true,
				Duration = 4,
				Lines = { { Speaker = VOICE, Text = "I remember now. Some of it. Enough." } },
			},
			{
				From = { Pos = Vector3.new(800, 120, -800), Look = Vector3.new(1180, 20, -1180) },
				To = { Pos = Vector3.new(950, 120, -950), Look = Vector3.new(1180, 40, -1180) },
				Duration = 16,
				Lines = {
					{ Speaker = VOICE, Text = "The dead in that crypt were soldiers. Your soldiers. The Ashen Guard." },
					{
						Speaker = VOICE,
						Text = "Seven of you climbed Cinder Peak to bind the Mother of Ash in her sleep.",
					},
					{ Speaker = VOICE, Text = "One came back down. You." },
					{
						Speaker = VOICE,
						Text = "The binding needed a price, so you paid it. Your memory. Your name. Your whole self, poured into the seal.",
					},
					{
						Speaker = VOICE,
						Text = "I'm what was left over. The part of you that remembers. I'm you, {name}. I always was.",
					},
				},
			},
		},
	},

	Echo5 = {
		Title = "Echo V",
		Subtitle = "Oathbreaker",
		Music = "Echo",
		Shots = {
			{
				From = { Pos = Vector3.new(1120, 25, -1100), Look = Vector3.new(1180, 5, -1180) },
				To = { Pos = Vector3.new(1150, 15, -1140), Look = Vector3.new(1180, 4, -1180) },
				Duration = 7,
				Lines = { { Speaker = "The Ashen Wyrmling", Text = "Mother... remembers you... Oathbreaker." } },
			},
			{
				From = {
					Pos = { Anchor = "Player", Offset = Vector3.new(0, 4, -9) },
					Look = { Anchor = "Player", Offset = Vector3.new(0, 1.5, 0) },
				},
				To = {
					Pos = { Anchor = "Player", Offset = Vector3.new(0, 2.5, -5) },
					Look = { Anchor = "Player", Offset = Vector3.new(0, 1.5, 0) },
				},
				Duration = 14,
				Lines = {
					{ Speaker = VOICE, Text = "Oathbreaker. That's what they called you. Not 'hero'. Not 'Warden'." },
					{
						Speaker = VOICE,
						Text = "She thinks you broke the oath. You didn't. Corvin did. But the seal is cracking all the same, and the Mother is dreaming of you.",
					},
					{
						Speaker = VOICE,
						Text = "Whatever we were, we get to choose what we are now. Build a home. Earn a name. Rule this valley if you want to.",
					},
					{ Speaker = VOICE, Text = "When she wakes, I want her to find someone worth fearing." },
					{ Speaker = VOICE, Text = "We'll find out the rest together. I'm not going anywhere." },
				},
			},
		},
	},

	EchoOath = {
		Title = "Echo",
		Subtitle = "The Night Before",
		Music = "Echo",
		Shots = {
			{
				From = { Pos = Vector3.new(-470, 30, -580), Look = Vector3.new(-520, 4, -640) },
				To = { Pos = Vector3.new(-495, 14, -605), Look = Vector3.new(-520, 3, -640) },
				Duration = 12,
				Lines = {
					{
						Speaker = VOICE,
						Text = "I remember this place. Seven of us, knee-deep in the lake, carving our names by torchlight.",
					},
					{
						Speaker = VOICE,
						Text = "Corvin went last. His hand shook so badly the knife slipped. We laughed at him.",
					},
					{
						Speaker = VOICE,
						Text = "We shouldn't have laughed. He was the only one of us who understood what we were agreeing to.",
					},
				},
			},
			{
				Black = true,
				Duration = 6,
				Lines = {
					{ Speaker = VOICE, Text = "On the mountain, when the moment came, he wasn't beside us. He'd run." },
					{
						Speaker = VOICE,
						Text = "So you gave more than your share. You gave his share too. That's why there's so little of you left, {name}.",
					},
				},
			},
		},
	},

	Echo6 = {
		Title = "Echo VI",
		Subtitle = "What You Choose to Keep",
		Music = "Echo",
		Shots = {
			{
				From = { Pos = Vector3.new(1110, 30, -1090), Look = Vector3.new(1180, 6, -1180) },
				To = { Pos = Vector3.new(1140, 20, -1130), Look = Vector3.new(1180, 4, -1180) },
				Duration = 10,
				Lines = {
					{
						Speaker = "Corvin",
						Text = "Six of them are still in there. Still screaming. Every night for nine years I've heard them.",
					},
					{ Speaker = "Corvin", Text = "I only wanted to let them out. Is that so terrible?" },
					{ Speaker = "Corvin", Text = "...Tell Aurelia I'm sorry. Tell her I never stopped being afraid." },
				},
			},
			{
				From = {
					Pos = { Anchor = "Player", Offset = Vector3.new(0, 5, -10) },
					Look = { Anchor = "Player", Offset = Vector3.new(0, 1.5, 0) },
				},
				To = {
					Pos = { Anchor = "Player", Offset = Vector3.new(0, 2.5, -5) },
					Look = { Anchor = "Player", Offset = Vector3.new(0, 1.5, 0) },
				},
				Duration = 18,
				Lines = {
					{ Speaker = VOICE, Text = "The seal is still cracked. It needs a seventh. It always did." },
					{ Speaker = VOICE, Text = "Not you. You've given enough. It needs me." },
					{
						Speaker = VOICE,
						Text = "I'm the part of you that remembers the mountain. The six. The fear. Let me be the one who stays.",
					},
					{
						Speaker = VOICE,
						Text = "You'll forget me. That's alright. You've made new memories since the riverbank. Better ones.",
					},
					{
						Speaker = VOICE,
						Text = "A home. A name people say kindly. Friends who'd climb a mountain for you.",
					},
					{ Speaker = VOICE, Text = "Keep those, {name}. Those were always the ones worth keeping." },
				},
			},
			{
				Black = true,
				Duration = 6,
				Lines = {
					{ Speaker = "", Text = "The voice is gone. The mountain is quiet." },
					{ Speaker = "", Text = "For the first time since you woke by the river, the silence is yours." },
				},
			},
		},
	},
}

-- Which quest unlocks which Echo when it's turned in.
Story.QuestEchoes = {
	MQ2 = "Echo1",
	MQ3 = "Echo2",
	MQ4 = "Echo3",
	MQ5 = "Echo4",
	MQ5B = "EchoOath",
	MQ6 = "Echo5",
	MQ8 = "Echo6",
}

Story.EchoOrder = { "Echo1", "Echo2", "Echo3", "Echo4", "EchoOath", "Echo5", "Echo6" }

return Story
