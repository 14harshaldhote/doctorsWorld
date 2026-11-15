"""Writes story/chief.json, the Chief's days (stage 11):

    python3 tools/chief_story.py story/chief.json

Edit the conversations here, not in the JSON."""
import json, sys

def say(who, text, mood=None, gesture=None, head=None, to=None):
	d = {"say": who, "text": text}
	if mood: d["mood"] = mood
	if gesture: d["gesture"] = gesture
	if head: d["head"] = head
	if to: d["to"] = to
	return d

def you(text, **kw):
	return say("you", text, **kw)

def opt(tone, text, then=None, trust=None, flag=None, cond=None, standing=None, xp=None, gesture=None, mood=None):
	d = {"tone": tone, "text": text}
	if cond: d["if"] = cond
	if flag: d["flag"] = flag
	if trust: d["trust"] = trust
	if standing: d["standing"] = standing
	if xp: d["xp"] = xp
	if gesture: d["gesture"] = gesture
	if mood: d["mood"] = mood
	if then: d["then"] = then
	return d

def choose(*options):
	return {"choose": list(options)}

def iff(cond, then, otherwise=None):
	d = {"if": cond, "then": then}
	if otherwise: d["else"] = otherwise
	return d

S = {}

# ------------------------------------------------------------ The morning's news
LOST = {
	"grace": "About yesterday. You did everything that could be done. Today's a new list, and it's long.",
	"priya": "About yesterday, Chief. Grace would say you did everything that could be done. So I'm saying it.",
	"iyer": "About yesterday. I've lost patients on that table too. You carry it, and you come back in. Today's a new list.",
}
STAFF_LOW = {
	"grace": "Two more resignation letters on my desk. CarePlus pays better and shouts less.",
	"priya": "Two more nurses handed in their notice. CarePlus pays better and shouts less.",
	"iyer": "Two more nurses have resigned. Grace hasn't said anything. That's how you know it's bad.",
}
MONEY_LOW = "Pharmacy has put the antibiotic order on hold until Mr. Malhotra finds the money. He's looking under the cushions."
PUBLIC_LOW = "There's a reporter in the lobby again. Waiting times, she says. She's timing the lifts."
HIGH = {
	"grace": "The night nurses sent you a cake. I've had it tested. It's just a cake.",
	"priya": "The night nurses sent you a cake. Grace had it tested. It's just a cake.",
	"iyer": "The night nurses sent you a cake. Grace has had it tested. Apparently it's just a cake.",
}
REPORT = "And the board report is at five. Mrs. Rajan wants the numbers by two. She'll have read them by two-oh-one."

def opener(sp):
	return [
		iff("cb_yesterday_lost", [say(sp, LOST[sp], "calm", "open_hands", to="you")]),
		iff("staff_low", [say(sp, STAFF_LOW[sp], "worried", "hold", to="you")], [
			iff("money_low", [say(sp, MONEY_LOW, "tired", "shrug", to="you")], [
				iff("public_low", [say(sp, PUBLIC_LOW, "worried", "point", to="you")], [
					iff("staff_high&public_high", [say(sp, HIGH[sp], "happy", "shrug", to="you")]),
				]),
			]),
		]),
		iff("report_today", [say(sp, REPORT, "focused", "wag", to="you")]),
	]

# ======================================================== Day 29: Mrs. Banerjee
S["cb_banerjee_morning"] = [
	say("grace", "Good morning, Chief. That's the first time I've said it to your face. It felt strange. I'll be used to it by Thursday.", "happy", "wave", to="you"),
] + opener("grace") + [
	say("grace", "Your intern is in the canteen teaching the canteen staff to wash their hands. She's going to be a terror. I'm so proud.", "happy", "shrug"),
	say("iyer", "And there's a name on the admissions board you'll know. Banerjee. Seventy-nine now. She cut her arm on a glass bowl last night and wouldn't come in until morning.", "calm", "explain", to="you"),
	say("grace", "She told the ambulance she'd only see 'the doctor who held my hand'. The crew asked me who that was. I said the Chief.", "happy", "chest", to="you"),
	choose(
		opt("Warm", "Then the Chief had better go and hold it again.", trust={"grace": 2}, then=[
			say("grace", "Take tissues. She cries at weather forecasts.", "happy", "point"),
		]),
		opt("Practical", "A kitchen cut. Has anyone asked about her tetanus jabs?", trust={"iyer": 2}, then=[
			say("iyer", "That's your job, Chief. Ask her. She'll tell you about her husband first. Let her.", "calm", "wag"),
		]),
	),
]

S["cb_banerjee_arrive"] = [
	say("banerjee", "Beta! Look at you. A white coat with your name stitched on it. In gold!", "happy", "open_hands", to="you"),
	say("banerjee", "I dropped my husband's old glass bowl making payesh. Fifty-one years that bowl lasted. One bad evening.", "tired", "shrug"),
	say("priya", "Deep cut on the right forearm, Chief. The bleeding's stopped. There may be glass in it. She won't let me look until you've said hello.", "calm", "point", to="you"),
	say("banerjee", "Hello first. Then glass. That's manners.", "calm", "wag"),
	choose(
		opt("Warm", "Hello, Mrs. Banerjee. I remember the radio officer who listened to the sea.", trust={"banerjee": 3}, then=[
			say("banerjee", "You remember! Nobody remembers anything about old women except their blood pressure.", "happy", "chest"),
		]),
		opt("Brisk", "Hello. Let's look at that arm before anything else.", then=[
			say("banerjee", "Straight to work. Same as before. Ask your questions, then.", "calm", head="nod"),
		]),
	),
]

S["cb_banerjee_after"] = [
	iff("cb_banerjee_history_tetanus", [
		say("priya", "Twenty years since her last tetanus jab. I'll tell theatre. A kitchen bowl isn't a clean knife.", "focused", "hold", to="you"),
	], [
		say("priya", "Nobody asked her about tetanus, Chief. Theatre will want to know.", "worried", "shrug", to="you"),
	]),
	say("banerjee", "Will it hurt, beta?", "worried", head="tilt", to="you"),
	choose(
		opt("Honest", "The numbing injection stings for a few seconds. After that, you'll feel pushing, not cutting.", trust={"banerjee": 2}, then=[
			say("banerjee", "A few seconds. I had three sons. I can do a few seconds.", "happy", "fold_arms"),
		]),
		opt("Reassure", "Not at all. You won't feel a thing.", trust={"banerjee": -1}, then=[
			say("banerjee", "Everybody says that. Then they come at you with a needle the size of a pencil.", "worried", "shrug"),
		]),
	),
	say("priya", "Minor theatre at two. Tom's laying out the tray.", "calm", "point"),
]

S["cb_banerjee_ready"] = [
	say("banerjee", "I've brought biscuits for the theatre. Marie biscuits. Everyone likes Marie biscuits.", "happy", "offer", to="you"),
	say("iyer", "I'm only watching today, Chief. Your patient, your hands, and her biscuits.", "calm", "open_hands", to="you"),
	say("banerjee", "Hold my hand while they numb it? Like last time?", "worried", head="tilt", to="you"),
	choose(
		opt("Yes", "Until the numbing's done. Then I'll need both hands for the stitches.", trust={"banerjee": 2}, then=[
			say("banerjee", "Fair. I'll hold the nurse's instead.", "happy", head="nod"),
		]),
		opt("Joke", "I'll hold your hand, and Tom will hold the biscuits.", trust={"banerjee": 1}, then=[
			say("banerjee", "Tom will eat the biscuits. I've seen him.", "happy", "wag"),
		]),
	),
]

S["cb_banerjee_after_op"] = [
	iff("op_banerjee_failed", [
		say("iyer", "I finished the end of it. The glass was deep. She's fine, Chief. You'll be quicker next time.", "calm", "open_hands", to="you"),
		say("banerjee", "The other doctor finished. You held my hand. That's the part I'll remember.", "calm", "chest", to="you"),
	], [
		say("banerjee", "Finished? I felt the sting, then nothing. Just tugging, like knitting backwards.", "happy", "open_hands", to="you"),
	]),
	say("banerjee", "Now sit. I'll tell you about my grandson in Pune who wants to be a doctor, and you'll tell him not to.", "happy", "point", to="you"),
	choose(
		opt("Sit", "Five minutes. Grace is timing me.", trust={"banerjee": 2}, then=[
			say("banerjee", "Five minutes is a lot of grandson. I'll talk fast.", "happy", "explain"),
		]),
		opt("Later", "Not now. But I'll come back on my evening round.", then=[
			say("banerjee", "Evening round. I'll hold you to it. I hold everybody to everything.", "calm", "wag"),
		]),
	),
]

S["hc_night_nurses"] = [
	say("malhotra", "Chief. Congratulations again. Now, the budget. The strike settlement promised two nurses on every night shift.", "calm", "explain", to="you"),
	say("malhotra", "That's eleven new salaries. The settlement didn't say where the money comes from. Settlements never do.", "worried", "open_hands", to="you"),
	say("grace", "It comes from where the money for the new marble in the lobby came from, Mr. Malhotra.", "calm", "fold_arms", to="malhotra"),
	say("malhotra", "The marble was a donation.", "calm", "shrug", to="grace"),
	say("grace", "So were my nurses' knees.", "angry", "point", to="malhotra"),
	choose(
		opt("Keep", "We keep the promise. Two on every night shift. Find the money somewhere else.", flag="hc_night_nurses_two",
			trust={"grace": 3, "malhotra": -2}, standing={"staff": 8, "money": -8}, then=[
			say("malhotra", "Somewhere else. My favourite place. It's very crowded.", "tired", "shrug"),
			say("grace", "Thank you, Chief.", "happy", head="nod"),
		]),
		opt("Agency", "One nurse, and an agency nurse on call for the busy nights.", flag="hc_night_nurses_agency",
			trust={"grace": -3, "malhotra": 2}, standing={"money": 4, "staff": -6}, then=[
			say("grace", "Agency nurses don't know where the oxygen is kept. Or the patients' names. But they're cheap.", "angry", "fold_arms"),
		]),
		opt("Trip", "Two nurses. Pay for it from the conference budget. Starting with my trip.", flag="hc_night_nurses_trip",
			trust={"grace": 2, "malhotra": 1}, standing={"staff": 6, "money": -3}, then=[
			say("malhotra", "The Chief cancelling the Chief's own conference. I'll put it in the newsletter.", "happy", "clap"),
			say("grace", "Singapore will survive without you.", "happy", "shrug"),
		]),
	),
]

# ======================================================== Day 30: Dev Malhotra
S["cb_dev_morning"] = [
	say("grace", "Morning, Chief.", "calm", "wave", to="you"),
] + opener("grace") + [
	say("grace", "Mr. Malhotra rang at five. His son has a pain in his belly. He rang me, then the Dean, then the Dean's wife.", "tired", "shrug", to="you"),
	say("grace", "The Dean is retired. The Dean's wife is not amused.", "calm", "fold_arms"),
	say("iyer", "Fifteen, pain that started round the navel and moved low on the right. If that's not an appendix, I'll eat my own clips.", "calm", "explain", to="you"),
	say("grace", "Mr. Malhotra will ask for things. A private room. The Chief in person.", "calm", "wag", to="you"),
	choose(
		opt("Fair", "Today he's a parent, not the administrator. He gets what every parent gets.", trust={"grace": 2}, then=[
			say("grace", "Every parent gets my tea and my opinions. He'll get both.", "happy", head="nod"),
		]),
		opt("Careful", "He signs my budget. I'll be very careful.", trust={"grace": -1}, then=[
			say("grace", "Careful is good. Careful and fair is better. Remember Kunal Bhatia?", "calm", "fold_arms"),
		]),
	),
]

S["cb_dev_arrive"] = [
	say("malhotra", "Chief. Thank you for coming down yourself. I know everyone is busy. Dev is... Dev is fifteen.", "worried", "open_hands", to="you"),
	say("dev", "Papa, stop. You're doing the voice. The budget meeting voice.", "tired", "shrug", to="malhotra"),
	say("dev", "It hurts here. Low down, on the right. Since last night. I was sick in Mama's car. Don't tell her it was on the seat.", "worried", "point", to="you"),
	say("priya", "Temperature thirty-eight. He winces when the trolley bumps. He says the pain moved after midnight.", "focused", "hold", to="you"),
	choose(
		opt("Patient", "Dev, I'm going to ask you some questions. Your father can stay, but you answer.", trust={"dev": 3, "malhotra": 1}, then=[
			say("dev", "Finally. Someone who talks to me and not about me.", "happy", "open_hands"),
		]),
		opt("Father", "Mr. Malhotra, tell me what happened from the start.", trust={"dev": -2, "malhotra": 2}, then=[
			say("dev", "He wasn't even there. He was on a call. About parking.", "angry", "fold_arms"),
			say("malhotra", "...About parking.", "tired", head="down"),
		]),
	),
]

S["cb_dev_after"] = [
	iff("cb_dev_history_allergy", [
		say("priya", "Penicillin rash. I'll put it on his band and on the board. Theatre will want a different antibiotic.", "focused", "hold", to="you"),
	], [
		say("priya", "Nobody asked him about allergies, Chief. Theatre will ask.", "worried", "shrug", to="you"),
	]),
	say("malhotra", "It's his appendix, isn't it. Will you do it? You? Not a junior?", "worried", head="tilt", to="you"),
	choose(
		opt("Honest", "I'll do it, with Dr. Iyer across the table. That's how we do every case, yours or anyone's.", trust={"malhotra": 2, "dev": 1}, then=[
			say("malhotra", "Every case. Yes. Of course. Every case.", "calm", head="nod"),
		]),
		opt("Reassure", "It's the commonest operation we do. He'll be home in two days.", trust={"malhotra": 1}, then=[
			say("dev", "Two days. We've got a cricket final on Sunday.", "worried", "point"),
			say("malhotra", "You'll be watching it.", "calm", "wag", to="dev"),
		]),
	),
	say("dev", "Can Papa stop phoning people now?", "tired", "shrug"),
	say("malhotra", "One more call. Your mother.", "worried", "hold", to="dev"),
]

S["hc_dev_room"] = [
	say("malhotra", "Chief. One small thing. After his operation, the side room. Dev would rest better there. Quieter. Private.", "calm", "open_hands", to="you"),
	say("malhotra", "I know Mrs. Chawla is in it. Her chest. But she could go in the bay for one night, surely. With a curtain.", "worried", "explain", to="you"),
	say("grace", "Mrs. Chawla has a resistant chest infection, Mr. Malhotra. That's why she's behind a door.", "calm", "fold_arms", to="malhotra"),
	say("malhotra", "I've spent twelve years telling doctors who gets which bed. I know exactly what I'm asking. I'm asking anyway. He's my son.", "tired", "chest", to="you"),
	choose(
		opt("Bay", "Dev stays in the bay, like anyone else. And I'll look in on him myself tonight.", flag="hc_dev_room_bay",
			trust={"malhotra": -3, "grace": 3}, standing={"public": 5, "staff": 2}, then=[
			say("malhotra", "Like anyone else.", "tired", head="down"),
			say("malhotra", "That's what I'd have told you to say, twelve years ago.", "calm", "shrug"),
		]),
		opt("Side", "Move Mrs. Chawla for one night. Dev gets the side room.", flag="hc_dev_room_side",
			trust={"malhotra": 4, "grace": -4}, standing={"public": -6, "staff": -3}, then=[
			say("grace", "I'll move her. And I'll write down why, in my handwriting, which is very clear.", "angry", "point"),
		]),
		opt("Ask", "I'll ask Mrs. Chawla's family. If they say no, it's no.", flag="hc_dev_room_ask",
			trust={"malhotra": 1, "grace": 1}, standing={"public": 1}, then=[
			say("grace", "They'll say yes. People always say yes to a father. That's the trouble with asking.", "calm", "shrug"),
		]),
	),
]

S["cb_dev_ready"] = [
	say("dev", "Will I have a scar? A proper one? For the team photo?", "worried", head="tilt", to="you"),
	choose(
		opt("Honest", "A small one, low on the right. About as long as your little finger.", trust={"dev": 2}, then=[
			say("dev", "Little finger. That's nothing. Arjun has a scar from a dog.", "happy", "shrug"),
		]),
		opt("Joke", "A small one. Tell them it was a shark.", trust={"dev": 3}, then=[
			say("dev", "A shark. In a swimming pool. They'll believe it. They're very stupid.", "happy", "point"),
		]),
	),
	say("malhotra", "Chief. I'll be in the corridor. Phone off. I promise.", "worried", "chest", to="you"),
	say("dev", "He won't. He'll put it on silent. Which is worse.", "tired", "wag"),
]

S["cb_dev_after_op"] = [
	iff("op_dev_failed", [
		say("iyer", "His appendix was tucked further back than most. I took over at the end. He's fine, Mr. Malhotra.", "calm", "open_hands", to="malhotra"),
		say("malhotra", "Fine. Fine is the best word in the language.", "tired", "chest"),
	], [
		say("iyer", "Out, clean, nothing spilled. He'll be eating by tonight.", "happy", "open_hands", to="malhotra"),
	]),
	say("dev", "Did you keep it? The appendix? Can I see?", "happy", "point", to="you"),
	say("malhotra", "Chief. I've thanked a lot of doctors in this building. Mostly for coming in under budget. This is different.", "calm", "chest", to="you"),
	choose(
		opt("Warm", "Sit with him. The budget can wait until tomorrow.", trust={"malhotra": 3}, then=[
			say("malhotra", "The budget can wait. Write that down, Dev. You'll never hear me say it again.", "happy", "point"),
		]),
		opt("Dry", "He did the hard part. He kept still and told me the truth.", trust={"dev": 2, "malhotra": 1}, then=[
			say("dev", "I always tell the truth. Except about the car seat.", "happy", "shrug"),
		]),
	),
]

# ======================================================== Day 31: Tom
S["cb_tom_morning"] = [
	say("grace", "Morning, Chief. Sit down. You'll want to.", "worried", "point", to="you"),
] + opener("grace") + [
	say("grace", "Tom came in at six to set up theatre. At half past, he was sitting on the floor of the scrub room, very pale, and lying to me.", "worried", "explain", to="you"),
	say("iyer", "A lump in his groin that goes back in when he lies down. Since he lifted the new instrument trays last week. Except this morning, it won't go back.", "focused", "hold", to="you"),
	say("grace", "Twenty years he's handed you all scissors. Today somebody hands him a pillow. He'll hate it.", "calm", "shrug"),
	choose(
		opt("Gentle", "Then we'll be gentle. And very, very neat. He'll check.", trust={"grace": 2}, then=[
			say("grace", "He'll count every stitch. Out loud.", "happy", "wag"),
		]),
		opt("Firm", "He's a patient today. He doesn't get to scrub for his own operation.", trust={"iyer": 2}, then=[
			say("iyer", "Tell him that. Twice. Then lock the scrub room.", "calm", head="nod"),
		]),
	),
]

S["cb_tom_arrive"] = [
	say("tom", "It's nothing, Chief. A pulled muscle. I'll be scrubbed by ten.", "tired", "open_hands", to="you"),
	say("priya", "It's a lump the size of a lime, Tom. Muscles don't do that.", "calm", "fold_arms", to="tom"),
	say("tom", "...It might be slightly more than a pulled muscle.", "worried", head="down"),
	choose(
		opt("Kind", "Lie back, Tom. For once, I'll do the asking.", trust={"priya": 1}, then=[
			say("tom", "Fine. But if you ask me where the forceps live, I'm answering.", "happy", "point"),
		]),
		opt("Joke", "Tom, you've counted every swab I've ever used. Let me count something of yours.", trust={"priya": 1}, then=[
			say("tom", "That's the strangest thing anyone's said to me in this building. And I've worked here twenty years.", "happy", "shrug"),
		]),
	),
]

S["cb_tom_after"] = [
	iff("cb_tom_history_meal", [
		say("priya", "Two samosas at five, before his shift. Dr. Khan will want that before he goes to sleep.", "focused", "hold", to="you"),
	], [
		say("priya", "Nobody asked when he last ate, Chief. Dr. Khan will ask.", "worried", "shrug", to="you"),
	]),
	say("tom", "Who's scrubbing? Not the new boy. The new boy holds scissors like a pen.", "worried", head="tilt", to="you"),
	choose(
		opt("Neha", "Neha. She learned from you.", then=[
			say("tom", "Neha. Good. She'll put everything back where I keep it. And pretend she never moved anything.", "happy", head="nod"),
		]),
		opt("Rules", "You can't scrub for your own operation, Tom. I checked the rules.", then=[
			say("tom", "There's no such rule. I looked. Grace wrote one this morning.", "tired", "fold_arms"),
		]),
	),
	say("priya", "Theatre 2 at two. Neha's already in there, rearranging his trays to annoy him.", "happy", "point"),
]

S["cb_tom_ready"] = [
	say("tom", "Before I go to sleep. Count the swabs out loud. I want to hear it, even asleep.", "focused", "point", to="you"),
	say("tom", "And when Neha says 'all present', make her say it twice.", "calm", "wag"),
	choose(
		opt("Promise", "Every swab, out loud, twice. That's your rule.", then=[
			say("tom", "Good. Now I can sleep.", "calm", head="nod"),
		]),
		opt("Joke", "We'll count them in your voice. We've all heard it enough.", then=[
			say("tom", "Do the voice properly. Deeper. With disappointment.", "happy", "chest"),
		]),
	),
]

S["cb_tom_after_op"] = [
	iff("op_tom_failed", [
		say("iyer", "The sac was stuck down hard. I finished the mesh. He'll heal, Chief. So will you.", "calm", "open_hands", to="you"),
	], [
		say("iyer", "Mesh flat, no gaps. He'll lift trays again in six weeks. Light ones.", "happy", "open_hands", to="you"),
	]),
	say("tom", "Did you count?", "tired", head="tilt", to="you"),
	choose(
		opt("Yes", "Twice. Out loud. Neha said 'all present' twice.", then=[
			say("tom", "Then I've been operated on properly. Thank you, Chief.", "happy", "chest"),
		]),
		opt("Joke", "We lost a swab. It's fine. It was a small one.", then=[
			say("tom", "...That's not funny.", "shocked", head="up"),
			say("tom", "That's a little bit funny. Never say it again.", "happy", "wag"),
		]),
	),
	say("tom", "Six weeks. Who hands you the instruments for six weeks?", "worried", "open_hands"),
	say("iyer", "Neha. She's already moved your clamps.", "happy", "shrug", to="tom"),
]

S["cb_tom_rota_arrive"] = [
	say("priya", "Four nurses off sick, Chief. The flu's going round the nurses' hostel like gossip.", "tired", "open_hands", to="you"),
	say("priya", "And with Tom in bed four, that's one more bed and one less pair of hands. Grace says you do tonight's rota with me. She says it's good for you.", "calm", "point", to="you"),
	say("grace", "It's very good for you. I'll be watching.", "happy", "fold_arms", to="you"),
]

S["chief_rota_after"] = [
	iff("chief_rota_gap", [
		say("priya", "Somebody's got nobody tonight, Chief. I'll stay until midnight and cover them myself. Again.", "tired", "fold_arms", to="you"),
	], [
		iff("chief_rota_right", [
			say("priya", "That holds. Every bed has a name, and nobody's carrying more than they can. I'll sign it.", "happy", head="nod", to="you"),
		], [
			say("priya", "Signed. It'll do. Someone's carrying more than they should, and they'll feel it at four in the morning.", "calm", "shrug", to="you"),
		]),
	]),
	iff("staff_low", [
		say("priya", "We can't keep doing this, Chief. We need more nurses, not cleverer rotas.", "focused", "open_hands", to="you"),
	]),
]

S["hc_sponsor"] = [
	say("malhotra", "Good news, Chief. Medivance Pharma wants to pay for the new day surgery unit. All of it. The building, the beds, the coffee machine.", "happy", "open_hands", to="you"),
	say("malhotra", "In return, their name over the door. Their antibiotics first on our list. And their reps in the canteen on Tuesdays. With pens.", "calm", "explain", to="you"),
	say("iyer", "Their antibiotic costs three times the old one and works the same. Dr. Khan will have views.", "calm", "fold_arms", to="you"),
	choose(
		opt("All", "Take all of it. A day unit now is worth a few pens.", flag="hc_sponsor_all",
			trust={"malhotra": 3, "iyer": -2}, standing={"money": 12, "public": -4, "staff": -3}, then=[
			say("malhotra", "Wonderful. I'll order a very large sign.", "happy", "clap"),
			say("iyer", "And I'll order a very large box of the old antibiotic. For the patients.", "calm", "shrug"),
		]),
		opt("Money", "Take the money and the name. Not the list. We prescribe what works.", flag="hc_sponsor_money",
			trust={"malhotra": 1, "iyer": 2}, standing={"money": 5, "public": 1}, then=[
			say("malhotra", "They may walk away.", "worried", head="tilt"),
			say("malhotra", "...They won't. They need the sign more than we need their antibiotic. Probably.", "calm", "shrug"),
		]),
		opt("No", "No. A hospital that's for sale ends up selling more than its walls.", flag="hc_sponsor_no",
			trust={"malhotra": -2, "iyer": 2}, standing={"money": -4, "public": 3, "staff": 1}, then=[
			say("malhotra", "That's a lovely sentence. I'll put it on the empty plot where the day unit isn't.", "tired", "shrug"),
		]),
	),
]

# ======================================================== Day 32: Salim
S["cb_salim_morning"] = [
	say("grace", "Morning, Chief. Quiet so far. Which means it won't be.", "calm", "fold_arms", to="you"),
] + opener("grace") + [
	say("iyer", "The ring road's flooded, so every lorry in the state is on the highway through the toll plaza. If anything happens today, it happens there.", "focused", "explain", to="you"),
	choose(
		opt("Ready", "Then let's check the trauma bay before anything happens.", trust={"grace": 2}, then=[
			say("grace", "Stocked at six. Checked at seven. I'll check it again because you asked nicely.", "happy", head="nod"),
		]),
		opt("Hope", "Then let's hope nothing happens.", then=[
			say("grace", "Hope isn't on the stock list, Chief.", "calm", "wag"),
		]),
	),
]

S["cb_salim_triage_arrive"] = [
	say("priya", "A bus lost its brakes at the toll plaza. It went through the queue of motorbikes like skittles.", "worried", "open_hands", to="you"),
	say("priya", "Six off the first ambulances, more coming. Tag them, Chief. Red now, yellow soon, green walks, black beyond help.", "focused", "point", to="you"),
]

S["chief_triage_after"] = [
	iff("chief_triage_under", [
		say("priya", "One you tagged to wait went grey on the trolley, Chief. Dr. Iyer pulled them forward. They'll live. Just.", "worried", "hold", to="you"),
	], [
		iff("chief_triage_right", [
			say("priya", "Every tag right. The trauma bay says it's the calmest crash they've had.", "happy", head="nod", to="you"),
		], [
			say("priya", "Sent in. Dr. Iyer will check the tags again inside. Some of them were generous.", "calm", "shrug", to="you"),
		]),
	]),
]

S["cb_salim_arrive"] = [
	say("salim", "Doctor... it's you. The night doctor. From my bike. Years ago.", "tired", head="tilt", to="you"),
	iff("rider_treated", [
		say("salim", "You stopped the bleeding in my leg. Pooja was seven. She drew you a picture. Purple, with a stethoscope.", "calm", "chest", to="you"),
	], [
		say("salim", "That night, I don't remember much. Intensive care, they told me after. I'm still here. Mostly.", "tired", "shrug", to="you"),
	]),
	say("priya", "He came off his bike when the bus hit the queue. Left side of his chest and belly into the divider. Pressure ninety and falling.", "focused", "hold", to="you"),
	say("salim", "It hurts here, under the ribs on the left. And my left shoulder. Which is strange. I didn't land on my shoulder.", "worried", "point", to="you"),
	choose(
		opt("Calm", "You're in the right place, Salim. A few quick questions.", trust={"salim": 2}, then=[
			say("salim", "Quick. Yes. I'm cold, Doctor. Why am I cold?", "worried", head="tilt"),
		]),
		opt("Fast", "No time for talking. Priya, two big drips and blood.", trust={"salim": -1}, then=[
			say("priya", "Already running, Chief. But ask him things now, while he can still answer.", "focused", "point"),
		]),
	),
]

S["cb_salim_after"] = [
	iff("cb_salim_history_allergy", [
		say("priya", "No allergies. He's sure. I'll tell Dr. Khan.", "focused", head="nod", to="you"),
	], [
		say("priya", "Nobody asked him about allergies. Dr. Khan will be guessing.", "worried", "shrug", to="you"),
	]),
	say("priya", "Pressure's eighty-five. Dr. Iyer's opening Theatre 1. She says bring your hands, not your questions.", "worried", "point", to="you"),
	say("salim", "Call Pooja. She's at school. Tell her... tell her her papa's being difficult.", "worried", "open_hands", to="you"),
	choose(
		opt("Promise", "I'll call her myself, the minute you're out.", trust={"salim": 3}, then=[
			say("salim", "The minute. She counts minutes. Like her mother did.", "calm", head="nod"),
		]),
		opt("Delegate", "Priya will call her now.", trust={"salim": 1}, then=[
			say("priya", "I'm calling. What do I say?", "calm", "hold"),
			say("salim", "Say her papa is being difficult. She'll understand.", "tired", "shrug"),
		]),
	),
]

S["cb_salim_ready"] = [
	say("salim", "Doctor. If it goes wrong...", "worried", head="down", to="you"),
	choose(
		opt("Honest", "Then Dr. Iyer and I will be doing everything there is. And I'll tell Pooja myself.", trust={"salim": 2}, then=[
			say("salim", "Everything. Good. That's all a man can ask.", "calm", head="nod"),
		]),
		opt("Reassure", "It won't go wrong. I won't let it.", trust={"salim": 1}, then=[
			say("salim", "Doctors always say that in films.", "tired", "shrug"),
		]),
	),
]

S["cb_salim_after_op"] = [
	iff("op_salim_failed", [
		say("iyer", "The spleen fought us. I finished it. His pressure's a hundred and ten. He'll do.", "calm", "open_hands", to="you"),
	], [
		say("iyer", "Dry. His pressure's a hundred and twenty. Good hands, Chief. Fast hands.", "happy", "open_hands", to="you"),
	]),
	say("pooja", "Papa? The nurse said you were being difficult.", "worried"),
	say("salim", "Always, beti. Always difficult.", "happy", "chest"),
	say("pooja", "Is the doctor there? Can I talk to the doctor?", "worried"),
	choose(
		opt("Warm", "I'm here, Pooja. Your papa's going to be fine. Bring him something to read. He talks too much.", trust={"salim": 2}, then=[
			say("pooja", "He does. I'll bring him my maths homework. He hates maths.", "happy"),
		]),
		opt("Plain", "He's out of the operation and he's stable. You can see him at four.", trust={"salim": 1}, then=[
			say("pooja", "Four. I'm counting.", "calm"),
		]),
	),
]

S["hc_reporter"] = [
	say("malhotra", "Chief. There's a television van outside. They want the doctor who ran the crash. In front of the trauma bay, looking tired but heroic.", "worried", "point", to="you"),
	say("malhotra", "They also want to film inside. The patients. Faces.", "calm", "open_hands", to="you"),
	say("grace", "Over my dead body. Which they're welcome to film.", "angry", "fold_arms", to="malhotra"),
	choose(
		opt("Film", "They can film inside, with written consent from every patient, and nobody who says no.", flag="hc_reporter_film",
			trust={"malhotra": 2, "grace": -2}, standing={"public": 6, "staff": -3}, then=[
			say("grace", "Consent from people on morphine. I'll be standing beside every form.", "angry", "point"),
		]),
		opt("Statement", "No cameras on the ward. I'll speak outside, and thank the nurses by name.", flag="hc_reporter_statement",
			trust={"grace": 2, "malhotra": 1}, standing={"public": 3, "staff": 3}, then=[
			say("malhotra", "Outside, by name. Priya will cry. I'll make sure the tissue is in shot.", "happy", "clap"),
		]),
		opt("No", "No cameras and no statement. We had a crash, not a show.", flag="hc_reporter_no",
			trust={"grace": 1, "malhotra": -2}, standing={"public": -4, "staff": 2}, then=[
			say("malhotra", "They'll film the van leaving and say 'the hospital declined to comment'. It always sounds like guilt.", "tired", "shrug"),
		]),
	),
]

# ======================================================== Day 33: Mrs. Mehra
S["cb_mehra_morning"] = [
	say("grace", "Morning, Chief. Board day. I've ironed my second-best apron.", "calm", "chest", to="you"),
] + opener("grace") + [
	say("grace", "Mrs. Kamala Mehra fell on her own staircase at breakfast. The knee that's clicked for forty years. It's her hip now.", "worried", "explain", to="you"),
	say("iyer", "Her son Suresh sits on the board. He's rung Mrs. Rajan, Mr. Malhotra and me. I let it ring.", "calm", "shrug", to="you"),
	say("grace", "You met her years ago, when she waited two hours for her heartburn. She remembers. She remembers everything.", "calm", "wag", to="you"),
	iff("mehra_charmed", [
		say("grace", "She told the ambulance crew the young doctor had manners. She meant you.", "happy", "point"),
	], [
		iff("mehra_complaint", [
			say("grace", "She told the ambulance crew she hoped the young doctor had learned manners. She meant you.", "calm", "fold_arms"),
		]),
	]),
	choose(
		opt("Fair", "She's a patient with a broken hip. That's all she is until it's fixed.", trust={"grace": 2}, then=[
			say("grace", "Tell her son that. Slowly.", "calm", "wag"),
		]),
		opt("Wary", "Board day, and a board member's mother. Of course it is.", trust={"iyer": 1}, then=[
			say("iyer", "The universe has a sense of humour. It just isn't very good.", "calm", "shrug"),
		]),
	),
]

S["cb_mehra_arrive"] = [
	say("mehra", "You. The young doctor who made me wait for a bricklayer.", "calm", "point", to="you"),
	iff("mehra_charmed", [
		say("mehra", "I told my son you were right. He didn't like it. I enjoyed that.", "happy", "shrug"),
	], [
		iff("mehra_complaint", [
			say("mehra", "I wrote to the board about your manners. They wrote back about your skills. Very irritating.", "calm", "fold_arms"),
		], [
			say("mehra", "And now you're the Chief. My son says you're too young. I told him he was too young once.", "calm", "wag"),
		]),
	]),
	say("priya", "Left leg short and turned out, Chief. A broken hip. The pain's controlled. Her son has phoned the desk four times.", "focused", "hold", to="you"),
	say("mehra", "Five. He'll phone again. He thinks if he phones enough, things happen faster. Like his father.", "tired", "shrug"),
	choose(
		opt("Kind", "Then let's give him good news to phone about. A few questions first.", trust={"mehra": 3}, then=[
			say("mehra", "Questions. Good. Nobody asks old women anything except whether they've fallen.", "happy", head="nod"),
		]),
		opt("Plain", "Mrs. Mehra, I need some answers before we can operate.", trust={"mehra": 1}, then=[
			say("mehra", "Straight to business. You've changed. Good.", "calm", head="nod"),
		]),
	),
]

S["cb_mehra_after"] = [
	iff("cb_mehra_history_medicines", [
		say("priya", "Warfarin, for her heart rhythm. Last dose last night. I'll check her clotting and tell Dr. Bhatt.", "focused", "hold", to="you"),
	], [
		say("priya", "Nobody asked about her tablets, Chief. Her handbag rattles.", "worried", "shrug", to="you"),
	]),
	iff("cb_mehra_history_allergy", [
		say("priya", "And penicillin. Spots, she says, on her wedding day. It's on her band.", "calm", "point", to="you"),
	]),
	say("mehra", "When? Today? Suresh will want it today. Suresh will want it yesterday.", "worried", "open_hands", to="you"),
]

S["hc_mehra_first"] = [
	say("malhotra", "Chief. Two broken hips came in this morning. Mrs. Mehra, and a Mr. Gaikwad, a farmer from Sangli, waiting since yesterday afternoon.", "worried", "explain", to="you"),
	say("bhatt", "One theatre, one of me, one afternoon. At their age, every day on their back is a day nearer pneumonia.", "focused", "open_hands", to="you"),
	say("malhotra", "Suresh Mehra has called the board, the Dean and me. In that order. And today is the board report. I'm only saying.", "calm", "shrug", to="you"),
	choose(
		opt("Queue", "Mr. Gaikwad waited longest. He goes first. Mrs. Mehra second, if Dr. Bhatt will stay late.", flag="hc_mehra_first_queue",
			trust={"malhotra": -2, "bhatt": 2, "mehra": -3}, standing={"public": 5, "staff": -2, "money": -2}, then=[
			say("bhatt", "I'll stay. Order the coffee.", "calm", head="nod"),
			say("malhotra", "I'll tell Suresh. From a distance.", "tired", "shrug"),
		]),
		opt("VIP", "Mrs. Mehra first. Mr. Gaikwad tomorrow morning.", flag="hc_mehra_first_vip",
			trust={"malhotra": 3, "bhatt": -2, "mehra": 2}, standing={"money": 5, "public": -6, "staff": -2}, then=[
			say("bhatt", "Tomorrow morning. I'll tell Mr. Gaikwad's son. He drove all night.", "tired", head="down"),
		]),
		opt("Both", "Both today. Open Theatre 1 for Mr. Gaikwad, with Dr. Iyer, and pay the overtime.", flag="hc_mehra_first_both",
			trust={"bhatt": 2, "iyer": 1}, standing={"staff": -5, "money": -3, "public": 3}, then=[
			say("malhotra", "Overtime. On a Saturday rate. On board day.", "worried", "chest"),
			say("bhatt", "Two hips, two theatres. Like the old days. I love the old days.", "happy", "clap"),
		]),
	),
]

S["cb_mehra_ready"] = [
	iff("hc_mehra_first_queue", [
		say("mehra", "Second, after a farmer from Sangli. My son is going to explode. Good. He's never waited for anything in his life.", "calm", "shrug", to="you"),
	], [
		iff("hc_mehra_first_vip", [
			say("mehra", "First. Suresh fixed it. I can see from your face you didn't like it. Neither do I, much.", "tired", "fold_arms", to="you"),
		]),
	]),
	say("mehra", "Will I walk at my grandson's wedding? March. He's marrying a dentist. I have opinions.", "worried", head="tilt", to="you"),
	choose(
		opt("Honest", "If the screw goes in well, you'll stand tomorrow. Walking to March is up to you and the physiotherapist.", trust={"mehra": 2}, then=[
			say("mehra", "A young man shouting 'one more step'. I'll manage him.", "happy", "wag"),
		]),
		opt("Promise", "You'll dance at it.", then=[
			say("mehra", "Don't promise dancing. My husband promised dancing. Forty years, not one dance.", "calm", "shrug"),
		]),
	),
]

S["cb_mehra_after_op"] = [
	iff("op_mehra_failed", [
		say("bhatt", "The bone was softer than the X-ray said. I finished the plate. It's solid now, Chief.", "calm", "open_hands", to="you"),
	], [
		say("bhatt", "Screw dead centre, plate flat. She'll stand tomorrow. Shouting, probably.", "happy", "open_hands", to="you"),
	]),
	say("mehra", "Has Suresh phoned?", "tired", head="tilt", to="you"),
	say("bhatt", "Eleven times.", "happy", "shrug", to="mehra"),
	say("mehra", "Tell him I'm asleep. Tell him the Chief is very rude and very good. Both. He needs to hear both.", "calm", "point", to="you"),
	choose(
		opt("Warm", "I'll tell him the good part. You can tell him the rude part.", trust={"mehra": 2}, then=[
			say("mehra", "I'll enjoy that.", "happy", head="nod"),
		]),
		opt("Dry", "I'll tell him you're comfortable. That's all I'm allowed to say.", trust={"mehra": 1}, then=[
			say("mehra", "Comfortable. On a ward. With a screw in my hip. Doctors.", "tired", "shrug"),
		]),
	),
]

# ======================================================== Day 34: Mrs. Verghese
S["cb_verghese_morning"] = [
	say("grace", "Before you ask: no, I'm fine. It's indigestion. Everybody my age has indigestion.", "tired", "fold_arms", to="you"),
] + opener("grace") + [
	say("iyer", "You're holding your side, Grace.", "focused", "point", to="grace"),
	say("grace", "I'm holding my clipboard. Against my side. It's a different thing.", "calm", "shrug", to="iyer"),
	say("iyer", "Admissions has a CarePlus day case. Keyhole gallbladder three days ago, home the same evening. Fever, yellow, belly like a board.", "calm", "explain", to="you"),
	say("iyer", "We've seen this one before, Chief. Mrs. Sinha. Different hospital, same leaflet.", "focused", "wag", to="you"),
	choose(
		opt("Grace", "Grace, if that indigestion's still there at noon, I'm examining you myself.", flag="cb_verghese_grace_warned",
			trust={"grace": 1, "iyer": 2}, then=[
			say("grace", "At noon I'll be busy. At one, I'll be busy. I'm always busy, Chief. That's the job.", "tired", "shrug"),
		]),
		opt("Case", "Let's see her. And get her notes from CarePlus before anyone at CarePlus edits them.", trust={"iyer": 2}, then=[
			say("iyer", "Already asked. They said they'd 'look into it'. That's never a good sentence.", "calm", "fold_arms"),
		]),
	),
]

S["cb_verghese_arrive"] = [
	say("verghese", "Are you the Chief? Good. Somebody in charge. CarePlus gave me a leaflet and a number that rings for ever.", "tired", "open_hands", to="you"),
	say("priya", "Thirty-nine point two, yellow eyes, belly tight as a drum. Operation at CarePlus three days ago.", "focused", "hold", to="you"),
	say("verghese", "They said it was textbook. Everybody keeps saying textbook. I count money for a bank, Doctor. When the numbers don't add up, I don't call it textbook.", "angry", "wag", to="you"),
	choose(
		opt("Listen", "Then let's add up your numbers properly. Tell me everything, from the start.", trust={"verghese": 3}, then=[
			say("verghese", "From the start. Finally.", "calm", head="nod"),
		]),
		opt("Defer", "I'm sure CarePlus did their best. Let's find out what's going on.", trust={"verghese": -1}, then=[
			say("verghese", "Their best is why I'm on your trolley.", "angry", "fold_arms"),
		]),
	),
]

S["cb_verghese_after"] = [
	iff("cb_verghese_history_allergy", [
		say("priya", "Penicillin. She swells up. And CarePlus gave it to her anyway, in recovery. She came up in welts. It's on her band now.", "angry", "hold", to="you"),
	], [
		say("priya", "Nobody asked about allergies, Chief. And she's going to theatre.", "worried", "shrug", to="you"),
	]),
	say("verghese", "Will you have to go back in through the same holes?", "worried", head="tilt", to="you"),
	choose(
		opt("Honest", "The same three holes. We'll wash out the bile and find where it's leaking.", trust={"verghese": 2}, then=[
			say("verghese", "Find it. And write down what you find. In ink.", "calm", "point"),
		]),
		opt("Vague", "We'll take a look and see.", trust={"verghese": -1}, then=[
			say("verghese", "'Take a look and see.' That's what CarePlus said.", "angry", "shrug"),
		]),
	),
]

S["hc_kapoor_back"] = [
	say("kapoor", "Chief. Congratulations, belatedly. Board votes are so very public.", "happy", "open_hands", to="you"),
	say("kapoor", "Mrs. Verghese is ours. We'd like her back. Our ambulance is outside, our surgeon is waiting, our cost entirely. No paperwork.", "calm", "explain", to="you"),
	say("iyer", "She's septic, Sameer. She isn't going anywhere in an ambulance today.", "focused", "fold_arms", to="kapoor"),
	say("kapoor", "Then let's keep it collegial. Whatever you find in there stays between our two hospitals. Surgeons have bad days. Even yours.", "calm", "shrug", to="you"),
	iff("sinha_covered", [
		say("kapoor", "After all, you kept Mrs. Sinha's leak in the family. I'm only asking for the same courtesy.", "happy", "point", to="you"),
	]),
	choose(
		opt("Report", "She stays. What I find goes to her, in writing, and to the medical council.", flag="hc_kapoor_back_report",
			trust={"kapoor": -5, "iyer": 3}, standing={"public": 5, "staff": 2, "money": -3}, then=[
			say("kapoor", "The council. How formal. My lawyers love formal.", "angry", "wag"),
		]),
		opt("Call", "She stays. I'll tell her what I find. And I'll ring you first, surgeon to surgeon, before anything's written.", flag="hc_kapoor_back_call",
			trust={"kapoor": 1, "iyer": 1}, standing={"public": 1}, then=[
			say("kapoor", "Surgeon to surgeon. That's all I ask. I'll wait for your call.", "calm", head="nod"),
		]),
		opt("Quiet", "She stays. What's in the notes stays in the notes.", flag="hc_kapoor_back_quiet",
			trust={"kapoor": 3, "iyer": -4}, standing={"public": -5, "money": 2}, then=[
			say("iyer", "That's how notes end up saying 'known complication', Chief.", "angry", "fold_arms"),
		]),
	),
]

S["cb_verghese_ready"] = [
	say("verghese", "If you find their mistake, will you tell me? The truth. Not textbook.", "worried", head="tilt", to="you"),
	choose(
		opt("Truth", "I'll tell you exactly what I find, in plain words, as soon as you're awake.", flag="cb_verghese_promised", trust={"verghese": 3}, then=[
			say("verghese", "Plain words. Good. I'll be awake.", "calm", head="nod"),
		]),
		opt("Careful", "I'll tell you what I find. Whose fault it is isn't for me to say.", then=[
			say("verghese", "Fine. I'll decide whose fault it is. I'm good at sums.", "calm", "fold_arms"),
		]),
	),
]

S["cb_verghese_after_op"] = [
	iff("op_verghese_failed", [
		say("iyer", "The leak was hard to find. I finished it. She's dry now.", "calm", "open_hands", to="you"),
	], [
		say("iyer", "Washed out, and the leak's stopped. Dry.", "happy", "open_hands", to="you"),
	]),
	say("verghese", "Well? Plain words.", "tired", head="tilt", to="you"),
	choose(
		opt("Plain", "Bile was leaking from where your gallbladder was taken out. It shouldn't have been. We've stopped it.", trust={"verghese": 3}, then=[
			say("verghese", "Shouldn't have been. Thank you. That's the first sentence about this anyone has finished.", "calm", head="nod"),
		]),
		opt("Soft", "These things happen sometimes. It's fixed now.", trust={"verghese": -2}, then=[
			say("verghese", "'These things happen.' I'll write that down. Next to 'textbook'.", "angry", "fold_arms"),
		]),
	),
	iff("hc_kapoor_back_report", [
		say("iyer", "The letter to the council goes tonight. Dr. Kapoor's lawyers will ring in the morning. Let them.", "calm", "shrug", to="you"),
	]),
]

S["cb_verghese_rota_arrive"] = [
	say("priya", "Chief. Grace went home at noon. Grace never goes home. She said it was indigestion, and she said it sitting down.", "worried", "open_hands", to="you"),
	say("priya", "So it's you and me on tonight's cover. And the flu's still in the hostel.", "tired", "point", to="you"),
	iff("cb_verghese_grace_warned", [
		say("priya", "She said you'd threatened to examine her. She said to tell you she's fine. She said it twice, which means she isn't.", "worried", "shrug", to="you"),
	]),
]

# ======================================================== Day 35: Sister Grace
S["cb_grace_morning"] = [
	say("priya", "Chief. Grace rang in sick. Grace has never rung in sick. Not in twenty-six years. She did a morning shift on her wedding day.", "worried", "open_hands", to="you"),
] + opener("priya") + [
	say("iyer", "Then she rang again at six, from her kitchen floor, to say she was coming in anyway. I sent an ambulance. She'll be furious.", "focused", "explain", to="you"),
	say("priya", "A month of pain under her ribs on the right, after food. She's been eating antacids like sweets and calling it stress.", "worried", "hold", to="you"),
	say("iyer", "Gallstones, almost certainly. And a gallbladder angry enough to put Grace Mathew on a floor.", "calm", "wag", to="you"),
	choose(
		opt("Steady", "Then she gets the best this building has. Starting with us not panicking.", trust={"priya": 2}, then=[
			say("priya", "Not panicking. Right. I'll stop alphabetising the drug cupboard, then.", "calm", "shrug"),
		]),
		opt("Worried", "She hid it for a month. From us. Who else is hiding something?", trust={"iyer": 2}, then=[
			say("iyer", "Everyone, Chief. Nurses most of all. They think pain is a staffing problem.", "calm", "open_hands"),
		]),
	),
]

S["cb_grace_arrive"] = [
	say("grace", "Don't look at me like that. I'm lying on a trolley in my own admissions bay, and I'm fine.", "tired", "fold_arms", to="you"),
	say("grace", "Who's on the desk? Has anyone checked the controlled drugs? Priya, you're here. Who's on the desk?", "worried", "point", to="priya"),
	say("priya", "Tom's on the desk. With his hernia. On a chair. He's loving it.", "calm", "shrug", to="grace"),
	choose(
		opt("Gentle", "Grace. For once the ward can look after itself. Let me look after you.", trust={"grace": 3}, then=[
			say("grace", "...Fine. Ask your questions. I'll know if you skip one.", "calm", head="down"),
		]),
		opt("Firm", "Grace, you're my patient. Patients don't run the ward. Answer my questions.", trust={"grace": 1}, then=[
			say("grace", "Bossy. I taught you that. Ask, then.", "calm", "wag"),
		]),
	),
]

S["cb_grace_after"] = [
	iff("cb_grace_history_medicines", [
		say("priya", "Aspirin every morning, for her knees, because she won't take anything stronger. Theatre needs to know.", "focused", "hold", to="you"),
	], [
		say("priya", "Nobody asked about her tablets, Chief. She takes things. She just doesn't tell anyone.", "worried", "shrug", to="you"),
	]),
	say("priya", "Dr. Iyer's booked Theatre 2 for two. Tom wanted to scrub. Dr. Iyer took his shoes.", "calm", "point", to="you"),
	say("grace", "Who's doing it?", "worried", head="tilt", to="you"),
	choose(
		opt("Me", "I am. With Dr. Iyer across the table.", trust={"grace": 2}, then=[
			say("grace", "You. The one who couldn't find the sink on Day 2.", "happy", "shrug"),
			say("grace", "Good. I'd trust nobody else. Don't tell Dr. Iyer I said so.", "calm", head="nod"),
		]),
		opt("Ask", "Would you rather Dr. Iyer did it?", then=[
			say("grace", "I'd rather you did. I've watched your hands for years. Don't make me say it twice.", "calm", "fold_arms"),
		]),
	),
]

S["cb_grace_ready"] = [
	say("grace", "Listen to me, before I go to sleep.", "focused", "point", to="you"),
	say("grace", "Count everything. Twice. The way I taught Tom, and Tom taught Neha.", "calm", "wag", to="you"),
	choose(
		opt("Promise", "Everything, twice. And I'll be the one who tells you it went well.", trust={"grace": 2}, then=[
			say("grace", "Then make sure it goes well. I'll be very cross otherwise.", "calm", head="nod"),
		]),
		opt("Joke", "Grace, I've never seen you lie down. It's unsettling.", trust={"grace": 1}, then=[
			say("grace", "Enjoy it. It won't happen again.", "happy", "shrug"),
		]),
	),
]

S["cb_grace_after_op"] = [
	iff("op_grace_failed", [
		say("iyer", "Her gallbladder was stuck to everything. I took over at the end. She's fine, Chief. She's going to be fine.", "calm", "open_hands", to="you"),
	], [
		say("iyer", "Out, through four little holes. Lovely work, Chief. Don't tell her I cried. I didn't cry.", "happy", "chest", to="you"),
	]),
	say("grace", "Did you count?", "tired", head="tilt", to="you"),
	choose(
		opt("Yes", "Twice. Neha read it out. Tom listened from the corridor.", trust={"grace": 2}, then=[
			say("grace", "Good. Then I can sleep.", "calm", head="nod"),
		]),
		opt("Joke", "Three times. Tom made us.", trust={"grace": 2}, then=[
			say("grace", "Good boy.", "happy", "shrug"),
		]),
	),
	say("grace", "Keep the stones. I want to see what's been bullying me.", "calm", "point"),
]

S["hc_grace_cover"] = [
	say("grace", "Right. Who's running my floor for two weeks? And don't say 'we'll manage'. Nobody manages. Somebody runs it.", "focused", "point", to="you"),
	say("priya", "Grace, you've just had an operation...", "worried", "open_hands", to="grace"),
	say("grace", "And my floor has just lost its head nurse. Chief?", "calm", "fold_arms", to="you"),
	choose(
		opt("Priya", "Priya runs it. Acting head nurse, with the pay that goes with it.", flag="hc_grace_cover_priya",
			trust={"grace": 3, "priya": 4}, standing={"staff": 5, "money": -2}, then=[
			say("priya", "Me? With the pay?", "shocked", head="up"),
			say("grace", "With the pay. Write it down, Chief. Today.", "happy", "point"),
		]),
		opt("Agency", "An agency matron, for two weeks. Priya has enough on.", flag="hc_grace_cover_agency",
			trust={"grace": -3, "priya": -3}, standing={"staff": -5, "money": -4}, then=[
			say("grace", "An agency matron won't know that bed three hates the window, or that Mrs. Lobo only takes her tablets for Priya.", "angry", "fold_arms"),
		]),
		opt("Grace", "You run it from your bed by phone, Grace, for one week. Then Priya.", flag="hc_grace_cover_grace",
			trust={"grace": 2, "priya": -1}, standing={"staff": 1, "public": -1}, then=[
			say("priya", "From her bed. She'll ring every hour.", "tired", "shrug"),
			say("grace", "Every half hour.", "happy", "wag"),
		]),
	),
]

# ======================================================== Day 36 on: the Chief's rounds
S["rounds_morning"] = [
	iff("chief_rounds_first", [
		say("iyer", "The casebook's closed, Chief. Seven patients in seven days, and every one of them went home or will. Now it's just the job.", "calm", "open_hands", to="you"),
		iff("hc_grace_cover_priya", [
			say("iyer", "Priya's acting head nurse. She's ordered a new badge. It says 'Acting', very small.", "happy", "shrug", to="you"),
		], [
			iff("hc_grace_cover_agency", [
				say("iyer", "The agency matron has asked me twice where the oxygen is kept. I've told her twice.", "tired", "fold_arms", to="you"),
			], [
				say("iyer", "Grace is running the floor from her bed, by phone. She's rung four times since six.", "happy", "shrug", to="you"),
			]),
		]),
	], [
		iff("grace_back_today", [
			say("iyer", "Grace is back. She's walked the whole floor twice and found eleven things wrong. She looks very happy.", "happy", "clap", to="you"),
		], [
			iff("grace_away", [
				iff("rounds_a", [say("iyer", "Grace rang at six to ask who left the drug cupboard open. Nobody did. She just wanted to ring.", "happy", "shrug", to="you")]),
				iff("rounds_b", [say("iyer", "Grace has sent a list. Forty-one things. Number one says 'Don't let the Chief skip lunch'.", "happy", "point", to="you")]),
				iff("rounds_c", [say("iyer", "Grace walked to the end of her road this morning. She rang to tell me. Then she rang to tell Priya.", "happy", "open_hands", to="you")]),
			], [
				iff("rounds_a", [say("iyer", "Mr. Malhotra's chart has four bars now. He added one for 'morale'. It's purple.", "calm", "shrug", to="you")]),
				iff("rounds_b", [say("iyer", "Tom's back at the ring. He's told Neha she can keep three of her changes. Only three.", "happy", "wag", to="you")]),
				iff("rounds_c", [say("iyer", "Dr. Saxena did her first night alone. Nobody died, and she labelled every drawer in the doctors' room.", "happy", "shrug", to="you")]),
			]),
		]),
	]),
	iff("milestone_today", [
		say("iyer", "Today's a milestone, Chief. Grace has counted every day since you read the fire notices on your first morning. The number is on a cake.", "happy", "clap", to="you"),
		say("iyer", "Don't make a speech. The interns will film it.", "happy", "wag", to="you"),
	]),
	iff("tier_up_today", [
		iff("rounds_a", [say("iyer", "The new housing past the bypass opened last week. Six thousand more people, the same number of beds. From today, every day is busier.", "focused", "explain", to="you")]),
		iff("rounds_b", [say("iyer", "CarePlus has shut its emergency department at night. Too expensive, they say. Their ambulances come to us now. Every day is busier from today.", "focused", "explain", to="you")]),
		iff("rounds_c", [say("iyer", "They've widened the highway. Two more lanes, and twice the crashes. The council calls it progress. Dr. Khan calls it job security.", "tired", "shrug", to="you")]),
		say("iyer", "And the board has raised its bar. They'll want a better report than last time. They always will.", "calm", "wag", to="you"),
	]),
	iff("busy_today", [
		say("iyer", "It's one of those days. A rota to fill before eight, and ambulance control says the highway is already blocked.", "worried", "hold", to="you"),
	]),
] + opener("iyer") + [
	iff("rounds_a", [say("iyer", "The interns have the simulator booked for half past one. They've asked for you. Apparently you're 'intense'.", "happy", "shrug", to="you")]),
	iff("rounds_b", [say("iyer", "Dr. Saxena has loaded another real case into the simulator. She's made it harder. She says you'd want that.", "calm", "explain", to="you")]),
	iff("rounds_c", [say("iyer", "The simulator's booked all afternoon. The interns are placing bets on your score. I've put money on you.", "happy", "point", to="you")]),
]

S["rounds_rota_arrive"] = [
	iff("rounds_a", [say("priya", "Four off sick, Chief. The flu again. Every bed needs a name before eight.", "tired", "open_hands", to="you")]),
	iff("rounds_b", [say("priya", "Two on leave, two off sick, and one stuck behind a landslide on the ghat road. Rota, Chief.", "tired", "shrug", to="you")]),
	iff("rounds_c", [say("priya", "The agency's cancelled three of tonight's nurses. They found a hospital that pays more. Rota, Chief.", "angry", "fold_arms", to="you")]),
	iff("grace_away", [
		say("priya", "Grace has rung twice to ask if we've done it yet. We haven't. So let's.", "calm", "point", to="you"),
	]),
]

S["rounds_triage_arrive"] = [
	iff("rounds_a", [say("priya", "The highway again, Chief. A bus and a lorry, head on. They're coming in now.", "worried", "open_hands", to="you")]),
	iff("rounds_b", [say("priya", "A bus went off the ghat road and landed on its wheels, thank God. Everyone off it is coming here.", "worried", "point", to="you")]),
	iff("rounds_c", [say("priya", "The toll plaza again. Another bus with no brakes. Somebody should close that road.", "angry", "open_hands", to="you")]),
	say("priya", "Red now, yellow soon, green walks, black beyond help. Tag them, Chief.", "focused", "point", to="you"),
]

S["sim_arrive"] = [
	iff("rounds_a", [say("saxena", "Chief! The simulator's loaded. A real case from last month: same scans, same surprises. I've turned the difficulty up. You said you liked it hard.", "happy", "open_hands", to="you")]),
	iff("rounds_b", [say("saxena", "Chief. The new interns are behind the glass. Someone told them you never lose a patient. Please don't lose a patient.", "worried", "point", to="you")]),
	iff("rounds_c", [say("saxena", "I've loaded one of your own cases. I'm not saying which. Dr. Iyer says that's 'cheeky'. I looked it up. It's a compliment.", "happy", "shrug", to="you")]),
]

S["sim_brief"] = [
	say("iyer", "Simulation lab. Real scans, real problems, and nobody bleeds for real. Treat it as if they do.", "calm", "explain", to="you"),
	say("khan", "I'll make the monitor as unkind as the real thing. Kinder would be useless.", "focused", "wag", to="you"),
]

S["sim_after"] = [
	iff("op_sim_failed", [
		say("saxena", "The simulator won that one. The interns went very quiet. Then they asked to watch it again. That's good, isn't it?", "worried", head="tilt", to="you"),
	], [
		iff("op_sim_won", [
			say("saxena", "Clean run! The interns clapped. Dr. Iyer told them to stop clapping. Then she clapped.", "happy", "clap", to="you"),
		], [
			say("saxena", "You got there. The interns saw every wobble. One wrote 'even the Chief wobbles' in her notebook, and underlined it.", "calm", "shrug", to="you"),
		]),
	]),
	say("saxena", "Same time tomorrow? I'll make it harder.", "happy", "point", to="you"),
]

S["hc_intern_slip"] = [
	say("saxena", "Chief. Last night I gave Mr. Arora his blood thinner twice. At ten, and again at midnight. I didn't check the chart. Priya caught it at two.", "worried", "open_hands", to="you"),
	say("saxena", "His clotting's fine. He's fine. Nobody else knows except Priya. She said I had to tell you. So I'm telling you.", "worried", head="down", to="you"),
	say("saxena", "Please don't put it in the incident system. It'll follow me for ever.", "worried", "chest", to="you"),
	choose(
		opt("Report", "We report it, together. You write it, I'll sit beside you. That's how this place gets safer.", flag="hc_intern_slip_report",
			trust={"saxena": 1}, standing={"staff": 3, "public": 2}, then=[
			say("saxena", "Together. ...Dr. Iyer said you'd say that.", "calm", head="nod"),
		]),
		opt("Quiet", "Nobody was hurt. Learn from it, and we'll leave it there.", flag="hc_intern_slip_quiet",
			trust={"saxena": 3}, standing={"staff": -2}, then=[
			say("saxena", "Thank you, Chief. I'll never do it again. Priya won't like it, though.", "calm", "chest"),
		]),
		opt("Nights", "We report it, and you're off nights until you've done the drug safety course again.", flag="hc_intern_slip_nights",
			trust={"saxena": -3}, standing={"staff": -3, "public": 1}, then=[
			say("saxena", "Off nights. Yes, Chief. I understand.", "tired", head="down"),
		]),
	),
]

S["hc_monsoon_beds"] = [
	say("malhotra", "Chief, every bed in the building is full of dengue. Forty fevers, more every hour, and forty planned operations on this fortnight's list.", "worried", "open_hands", to="you"),
	say("malhotra", "I suggest we cancel all the planned operations for two weeks and free the beds. It's what CarePlus did.", "calm", "explain", to="you"),
	say("iyer", "Some of those forty can't wait two weeks. Two of them are cancers.", "focused", "fold_arms", to="malhotra"),
	choose(
		opt("Cancel", "Cancel everything that can wait. The two cancers stay on the list.", flag="hc_monsoon_beds_cancel",
			trust={"malhotra": 2}, standing={"public": -2, "money": -3, "staff": 2}, then=[
			say("malhotra", "Everything that can wait. Thirty-eight phone calls. I'll start with the angriest.", "tired", "shrug"),
		]),
		opt("Seminar", "Keep the list. Turn the seminar room into a fever ward.", flag="hc_monsoon_beds_seminar",
			trust={"iyer": 2}, standing={"public": 5, "staff": -6}, then=[
			say("iyer", "The seminar room. Again. The nurses will want the projector out of the way.", "calm", "shrug"),
		]),
		opt("CarePlus", "Send the stable fevers to CarePlus. We pay, they nurse.", flag="hc_monsoon_beds_careplus",
			trust={"kapoor": 2, "malhotra": -1}, standing={"money": -5, "public": 2}, then=[
			say("malhotra", "Pay Dr. Kapoor to take our patients. He'll frame the invoice.", "tired", "chest"),
		]),
	),
]

S["hc_rao_returns"] = [
	say("rao", "Chief. Don't get up. I've been retired for seven months. I've read every book I own. Twice.", "calm", "open_hands", to="you"),
	say("rao", "My wife says if I reorganise the spice rack once more she'll leave me. So I'm offering you two days a week. Teaching. Unpaid.", "happy", "shrug", to="you"),
	iff("count_rule", [
		say("rao", "I see the count rule is still on every wall. Good. Some things should outlive the people who were wrong about them.", "calm", head="nod"),
	]),
	choose(
		opt("Teach", "Two days a week with the interns. They need someone who's made mistakes and said so.", flag="hc_rao_returns_teach",
			trust={"rao": 3}, standing={"staff": 5, "money": -1}, then=[
			say("rao", "Someone who's made mistakes. I'm very well qualified.", "happy", "chest"),
		]),
		opt("Clinic", "Teach in the outpatient clinic. The town remembers you. That's worth something.", flag="hc_rao_returns_clinic",
			trust={"rao": 2}, standing={"public": 4, "money": -1}, then=[
			say("rao", "The clinic. Old patients, older stories. Yes.", "calm", head="nod"),
		]),
		opt("No", "Thank you, Dr. Rao. But the department has to stand without you now.", flag="hc_rao_returns_no",
			trust={"rao": -1}, standing={"staff": -1}, then=[
			say("rao", "Quite right. I said the same to my old chief. He sulked for a year. I won't. Much.", "calm", "shrug"),
		]),
	),
]

S["hc_budget_month"] = [
	iff("rounds_a", [say("malhotra", "The monthly budget, Chief. Three columns and money for one. Column one, nurses. Two, the scanner that reboots in the middle of scans. Three, the Saturday clinic.", "calm", "explain", to="you")]),
	iff("rounds_b", [say("malhotra", "The budget again, Chief. Column one, nurses. Two, new monitors for the recovery room; the old ones beep at nothing. Three, the Saturday clinic.", "calm", "explain", to="you")]),
	iff("rounds_c", [say("malhotra", "Budget, Chief. Column one, nurses. Two, a second ultrasound, so nobody waits a day for a scan. Three, the Saturday clinic.", "calm", "explain", to="you")]),
	say("malhotra", "One pen. Choose.", "tired", "offer", to="you"),
	choose(
		opt("Nurses", "Nurses. Two more on the wards.", flag="hc_budget_month_nurses", standing={"staff": 6, "money": -4}, then=[
			say("malhotra", "Nurses. Again. The machines will sulk.", "tired", "shrug"),
		]),
		opt("Kit", "The machine. Patients can't wait on broken kit.", flag="hc_budget_month_kit", standing={"public": 3, "money": -3, "staff": -2}, then=[
			say("malhotra", "The machine. It'll still go wrong. Just less often.", "calm", head="nod"),
		]),
		opt("Clinic", "The Saturday clinic. That's where the town meets us.", flag="hc_budget_month_clinic", standing={"public": 5, "money": -4}, then=[
			say("malhotra", "The clinic. I'll tell the machines it's not personal.", "calm", "shrug"),
		]),
	),
]

def family(sp, first):
	return [
		say(sp, first, "angry", "point", to="you"),
		say(sp, "I've spoken to a lawyer. I'd rather speak to you.", "calm", "fold_arms", to="you"),
		choose(
			opt("Sorry", "That was wrong, and I'm sorry. I'll find out why, and I'll tell you what we change.", flag="hc_family_complaint_sorry", standing={"public": 4}, then=[
				say(sp, "Find out why, and tell me. Then maybe I lose the lawyer's card.", "calm", head="nod"),
			]),
			opt("Defend", "We were stretched that day. The ones who waited were the ones who could.", flag="hc_family_complaint_defend", standing={"public": -3, "staff": 2}, then=[
				say(sp, "Then tell people that at the desk, at the start. Not at the end.", "angry", "fold_arms"),
			]),
			opt("Review", "I'll have it reviewed formally, with a written report to you within a week.", flag="hc_family_complaint_review", standing={"public": 2, "staff": -1, "money": -1}, then=[
				say(sp, "In writing. Good. I like things in writing.", "calm", head="nod"),
			]),
		),
	]

# Three different families on three kinds of day, so the complaint desk
# never shows the same face twice running.
S["hc_family_complaint"] = [
	iff("rounds_a", family("relative_a", "My father waited nine hours in your admissions bay with a broken wrist. Nine hours, on a plastic chair. He's seventy-four.")),
	iff("rounds_b", family("relative_b", "My mother was sent home at midnight in a taxi, alone, in the rain, with a drip mark still bleeding. She's eighty.")),
	iff("rounds_c", family("relative_c", "Nobody told us my brother's operation was cancelled. We sat outside theatre for six hours. We found out from the cleaner.")),
]

S["hc_staff_poach"] = [
	iff("rounds_a", [say("priya", "CarePlus sent me a letter. Head of nursing at their new hospital. Double what I earn here.", "worried", "hold", to="you")]),
	iff("rounds_b", [say("priya", "CarePlus has offered Neha a job. Theatre lead, double the money. She hasn't said no. She hasn't said yes.", "worried", "open_hands", to="you")]),
	iff("rounds_c", [say("priya", "Three of the night nurses have letters from CarePlus. Same letter. Same smile on the envelope.", "angry", "fold_arms", to="you")]),
	choose(
		opt("Match", "Match the offer. Whatever it costs, it costs less than losing them.", flag="hc_staff_poach_match", standing={"staff": 5, "money": -6}, then=[
			say("priya", "Mr. Malhotra will faint. I'll catch him. I'm a nurse.", "happy", "shrug"),
		]),
		opt("Promote", "I can't match it. I can offer a promotion, training, and a real say in the rota.", flag="hc_staff_poach_promote", standing={"staff": 3, "money": -2}, then=[
			say("priya", "A say in the rota. Nobody's ever offered that. That might be worth more than double.", "calm", head="nod"),
		]),
		opt("Let go", "If they want to go, they go with my blessing. We'll train the next ones.", flag="hc_staff_poach_go", standing={"staff": -6, "money": 3}, then=[
			say("priya", "With your blessing. That's kind. It's also how wards empty, one blessing at a time.", "tired", "shrug"),
		]),
	),
]

S["hc_inspection"] = [
	iff("rounds_a", [say("priya", "The health inspectors want the sluice, the drug cupboard and the night records. In that order.", "worried", "point", to="you")]),
	iff("rounds_b", [say("priya", "The fire inspector's already found a fire door wedged open with a chair. It was Tom's chair.", "worried", "shrug", to="you")]),
	iff("rounds_c", [say("priya", "A records inspection. Fifty sets of notes, picked at random. Mr. Malhotra's gone pale.", "worried", "open_hands", to="you")]),
	say("malhotra", "Chief, we could show them the new wing first. It's very shiny. The old wing could have a quiet morning.", "calm", "explain", to="you"),
	choose(
		opt("Everything", "Show them everything, old wing first. If something's wrong, we need to know.", flag="hc_inspection_real", standing={"public": 4, "money": -2}, then=[
			say("priya", "Old wing first. The sluice will be thrilled to meet someone at last.", "happy", "shrug"),
		]),
		opt("Tidy", "Give us an hour to tidy up, then show them round.", flag="hc_inspection_tidy", standing={"public": -2, "staff": -2, "money": 1}, then=[
			say("priya", "An hour of hiding things is an hour of not nursing.", "angry", "fold_arms"),
		]),
		opt("Later", "Ask them to come back next week. We're too busy for inspectors today.", flag="hc_inspection_delay", standing={"public": -5}, then=[
			say("priya", "You can't send inspectors away, Chief. You can only make them write it down.", "worried", "shrug"),
		]),
	),
]

# ======================================================== Every fifth day: the board
S["board_report"] = [
	say("rajan", "Chief. Sit, please. The board has your numbers: staff, money, and what the town thinks of us. Mr. Malhotra has made a chart.", "calm", "open_hands", to="you"),
	say("malhotra", "Three bars. I chose the colours myself.", "happy", "point"),
	iff("board_first", [
		say("rajan", "Your first report. I was a judge for nineteen years. First reports tell you less than people think, and more than they'd like.", "calm", "wag", to="you"),
	]),
	iff("board_strong", [
		say("rajan", "Strong. The nurses are staying, the money adds up, and the town trusts us with its relatives. I'll keep this one.", "happy", head="nod", to="you"),
		say("malhotra", "Even the money bar is green. I've never had a green money bar. I may frame it.", "happy", "clap"),
		{"xp": 200, "trust": {"rajan": 3}},
	], [
		iff("board_poor", [
			say("rajan", "Poor. I won't decorate it.", "focused", "fold_arms", to="you"),
			iff("staff_low", [say("rajan", "Nurses are leaving. A hospital without nurses is an expensive car park.", "focused", "point", to="you")]),
			iff("money_low", [say("rajan", "The money doesn't add up. Mr. Malhotra has stopped sleeping.", "focused", "shrug", to="you")]),
			iff("public_low", [say("rajan", "And the town is losing faith. The newspaper has a weekly column about our waiting times. It's very well written.", "focused", "open_hands", to="you")]),
			iff("board_warned_before", [
				say("rajan", "This is the second poor report running. Dr. Kapoor has offered CarePlus 'management support'. Some of the board would like to accept.", "angry", "wag", to="you"),
			], [
				say("rajan", "One poor report is a warning. Two is a pattern. Boards act on patterns.", "calm", "wag", to="you"),
			]),
			{"trust": {"rajan": -2}},
		], [
			say("rajan", "Mixed. Some of it is good. Some of it will be a problem by the next report.", "calm", "shrug", to="you"),
			iff("staff_low", [say("rajan", "Nurses are leaving. A hospital without nurses is an expensive car park.", "focused", "point", to="you")]),
			iff("money_low", [say("rajan", "The money doesn't add up. Mr. Malhotra has stopped sleeping.", "focused", "shrug", to="you")]),
			iff("public_low", [say("rajan", "And the town is losing faith. The newspaper has a weekly column about our waiting times. It's very well written.", "focused", "open_hands", to="you")]),
			{"xp": 80},
		]),
	]),
	iff("board_bar_up", [
		iff("rounds_a", [say("rajan", "And remember, the bar is higher than it was. The town keeps growing. So do our expectations.", "calm", "wag", to="you")]),
		iff("rounds_b", [say("rajan", "The bar is higher this year, Chief. Last year's good is this year's ordinary.", "calm", "wag", to="you")]),
		iff("rounds_c", [say("rajan", "We expect more every year. That isn't unkindness. That's a growing town.", "calm", "open_hands", to="you")]),
	]),
	say("rajan", "What will you do before the next report?", "calm", head="tilt", to="you"),
	choose(
		opt("Staff", "Look after the staff first. Everything in this building stands on them.", standing={"staff": 3, "money": -2}, trust={"rajan": 1}, then=[
			say("rajan", "Noted. Mr. Malhotra, stop wincing.", "calm", "wag"),
		]),
		opt("Money", "Get the money right. Nothing lasts if we can't pay for it.", standing={"money": 3, "staff": -2}, trust={"malhotra": 2}, then=[
			say("malhotra", "Music. To my ears.", "happy", "chest"),
		]),
		opt("Town", "Earn the town's trust. Shorter waits, open doors, and the truth when we get it wrong.", standing={"public": 3, "money": -1}, trust={"rajan": 2}, then=[
			say("rajan", "The truth when you get it wrong. That's the part people forget to budget for.", "calm", head="nod"),
		]),
	),
	say("rajan", "We'll meet again on the next board day. Good evening, Chief.", "calm", "wave", to="you"),
]

path = sys.argv[1]
with open(path, "w") as out:
	json.dump(S, out, indent="\t", ensure_ascii=False)
	out.write("\n")
print("wrote", len(S), "conversations")
