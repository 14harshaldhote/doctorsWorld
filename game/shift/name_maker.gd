class_name NameMaker
extends RefCounted
## Names for the people who walk in while you play, made on the spot.
##
## A person comes from a community, and their first name, surname and home
## town all come from it, so a Malayali family shares a Malayali surname and
## nobody is called "Gurpreet Iyer". Some first names only suit the young
## (a "*" after the name) or the old (a "^"), so an eighty-year-old is never
## "Atharva". Nobody is ever given a name already in the story's cast, the
## sample doctor's, or the rival's, so a stranger can't be mistaken for a
## character you know.
##
## Everything goes through SeededRandom: the same seed gives the same person.

## Roughly the town's mix: how often each community walks in.
const WEIGHTS := {
	"marathi": 18, "hindi": 18, "muslim": 10, "punjabi": 6, "gujarati": 6, "bengali": 6,
	"tamil": 6, "malayali": 6, "telugu": 4, "kannada": 3, "goan": 3, "northeast": 2, "parsi": 1,
}
## Names that can never be used for a stranger, on top of the cast's.
const BLOCKED := ["Asha", "Verma", "Varun", "Khanna", "Suresh", "Babu"]
## Below this age a "^" name is skipped; above OLD_FROM a "*" name is.
const YOUNG_UNTIL := 35
const OLD_FROM := 45

const COMMUNITIES := {
	"marathi": {
		"m": ["Sachin", "Ganesh", "Prashant", "Nitin", "Sandeep", "Amol", "Vijay", "Santosh", "Mahesh", "Shrikant^",
			"Dattatray^", "Pandurang^", "Vitthal^", "Sunil", "Ajit", "Dilip^", "Tushar", "Omkar*", "Atharva*",
			"Yash*", "Siddharth", "Aniket*"],
		"f": ["Snehal", "Pallavi", "Manisha", "Ashwini", "Vaishali", "Sayali*", "Rupali", "Shubhangi", "Kalpana^",
			"Mangal^", "Sunanda^", "Aarti", "Prajakta", "Gauri", "Rutuja*", "Shalini", "Vandana", "Sharda^",
			"Sakshi*", "Ketaki*"],
		"last": ["Patil", "Deshmukh", "Jadhav", "Pawar", "Shinde", "Chavan", "Deshpande", "Gokhale", "Bhosale",
			"More", "Salunkhe", "Mane", "Sawant", "Karande", "Wagh", "Gade", "Nikam", "Phadke", "Joglekar", "Apte",
			"Ranade", "Mhatre"],
		"home": ["Pune", "Satara", "Kolhapur", "Nashik", "Sangli", "Latur", "Ratnagiri", "Solapur"],
	},
	"hindi": {
		"m": ["Rajesh", "Sanjay", "Amit", "Manoj", "Pankaj", "Rakesh", "Ashok^", "Dinesh", "Naveen", "Alok",
			"Vinod^", "Saurabh", "Gaurav", "Nikhil", "Aditya*", "Ankit*", "Shyam^", "Brijesh", "Ramprasad^",
			"Kishan^", "Ayush*", "Harsh*"],
		"f": ["Geeta^", "Seema", "Poonam", "Neelam", "Kiran", "Anita", "Ritu", "Shweta", "Sapna", "Komal*",
			"Priyanka*", "Nisha", "Kusum^", "Savita^", "Radha", "Meenu", "Shalu", "Kamlesh^", "Tanvi*", "Khushi*"],
		"last": ["Sharma", "Gupta", "Mishra", "Pandey", "Srivastava", "Chauhan", "Singh", "Agarwal", "Dubey",
			"Tripathi", "Shukla", "Rastogi", "Chaturvedi", "Prasad", "Kushwaha", "Maurya", "Jain", "Goyal", "Thakur",
			"Rathore"],
		"home": ["Kanpur", "Lucknow", "Varanasi", "Gorakhpur", "Prayagraj", "Bareilly", "Jhansi", "Agra"],
	},
	"muslim": {
		"m": ["Asif", "Faisal", "Irfan", "Javed", "Nadeem", "Rizwan", "Sohail", "Tariq", "Wasim", "Shahid",
			"Aamir", "Zaheer", "Mujeeb^", "Yusuf^", "Rafiq^", "Ayaan*", "Rehan*", "Zaid*"],
		"f": ["Ayesha", "Nazia", "Shabana^", "Sana*", "Heena", "Rukhsar", "Shazia", "Tabassum", "Nasreen^",
			"Afreen*", "Mehjabeen^", "Sameena", "Firdaus^", "Naseem^", "Yasmin", "Alina*", "Inaya*"],
		"last": ["Pathan", "Syed", "Momin", "Inamdar", "Mulla", "Bagwan", "Tamboli", "Attar", "Kazi", "Rizvi",
			"Farooqui", "Baig", "Malik", "Shaikhji"],
		"home": ["Aurangabad", "Bhiwandi", "Malegaon", "Hyderabad", "Bhopal", "Lucknow", "Mumbra"],
	},
	"punjabi": {
		"m": ["Harpreet", "Jaspreet", "Baldev^", "Kuldeep", "Sukhwinder", "Amarjeet^", "Paramjit^", "Rajinder^",
			"Gurpreet", "Arjan*", "Fateh*"],
		"f": ["Simran*", "Navneet", "Harleen*", "Jasleen*", "Rupinder", "Kulwant^", "Baljeet^", "Amrit",
			"Gurleen*", "Mandeep", "Surinder^"],
		"last": ["Gill", "Dhillon", "Grewal", "Sidhu", "Bajwa", "Brar", "Randhawa", "Cheema", "Ahluwalia", "Arora",
			"Chawla", "Kohli"],
		"home": ["Ludhiana", "Amritsar", "Jalandhar", "Patiala", "Bathinda"],
	},
	"gujarati": {
		"m": ["Hitesh", "Jignesh", "Ketan", "Bhavesh", "Mitesh", "Paresh", "Chirag", "Nilesh", "Dhaval*",
			"Kalpesh", "Jayantilal^", "Harshad^", "Vihaan*"],
		"f": ["Hetal", "Nidhi", "Bhavna", "Jigna", "Falguni", "Dharmishtha^", "Krupa", "Mansi*", "Payal",
			"Urvashi", "Hansa^", "Jasuben^", "Diya*"],
		"last": ["Patel", "Shah", "Mehta", "Desai", "Trivedi", "Parikh", "Modi", "Dave", "Vyas", "Panchal",
			"Solanki", "Thakkar"],
		"home": ["Surat", "Vadodara", "Rajkot", "Anand", "Bhavnagar", "Valsad"],
	},
	"bengali": {
		"m": ["Subhash^", "Partha", "Sourav", "Debashish", "Arnab", "Abhijit", "Tapan^", "Indranil", "Pradip^",
			"Sanjoy", "Rohan*", "Ritwik*"],
		"f": ["Moumita", "Sanchita", "Rituparna", "Payel", "Shampa", "Debjani", "Swati", "Tanushree", "Mitali",
			"Rupa", "Aditi*", "Anwesha*", "Shefali^"],
		"last": ["Chatterjee", "Mukherjee", "Ghosh", "Das", "Sen", "Dutta", "Chakraborty", "Bhattacharya", "Roy",
			"Sarkar", "Mitra", "Ganguly"],
		"home": ["Kolkata", "Howrah", "Durgapur", "Siliguri", "Asansol"],
	},
	"tamil": {
		"m": ["Karthik", "Senthil", "Murugan", "Balaji", "Saravanan", "Venkatesh", "Ganesan^", "Arun", "Vignesh*",
			"Prabhu", "Ramasamy^", "Gokul*"],
		"f": ["Kavya*", "Divya", "Meenakshi", "Revathi", "Saranya", "Gayathri", "Kalaivani", "Selvi", "Anitha",
			"Deepika", "Valliammai^", "Janani*", "Pushpa^"],
		"last": ["Subramanian", "Raman", "Natarajan", "Sundaram", "Murthy", "Rajendran", "Balasubramaniam",
			"Chandrasekar", "Venkataraman", "Srinivasan", "Annamalai", "Pandian"],
		"home": ["Madurai", "Coimbatore", "Salem", "Tiruchy", "Tirunelveli", "Vellore"],
	},
	"malayali": {
		"m": ["Sreejith", "Anoop", "Rajeev", "Vineeth", "Biju", "Shibu", "Jijo", "Tomy", "Shaji", "Ajith",
			"Ratheesh", "Joby", "Sabu^", "Gopalan^", "Abhinav*", "Alan*"],
		"f": ["Reshma", "Lekha", "Soumya", "Sreeja", "Bindu", "Jincy", "Tintu", "Smitha", "Anju", "Neethu",
			"Jisha", "Saramma^", "Kunjamma^", "Nivya*"],
		"last": ["Panicker", "Warrier", "Kurian", "Chacko", "Abraham", "Cherian", "Mathai", "Koshy", "Namboodiri",
			"Kutty"],
		"home": ["Kottayam", "Thrissur", "Kollam", "Kozhikode", "Alappuzha", "Kannur"],
	},
	"telugu": {
		"m": ["Srinivas", "Ravi", "Venkat", "Naresh", "Kiran", "Prasad", "Chaitanya", "Ramakrishna^", "Sai*",
			"Charan*"],
		"f": ["Sravani", "Sirisha", "Lavanya", "Swathi", "Padma^", "Haritha", "Madhavi", "Sailaja", "Bhavani",
			"Keerthi*", "Varalakshmi^"],
		"last": ["Reddy", "Naidu", "Chowdary", "Goud", "Setty", "Pothula", "Kondapalli", "Vemula", "Gaddam",
			"Bandi"],
		"home": ["Guntur", "Warangal", "Vijayawada", "Nellore", "Karimnagar"],
	},
	"kannada": {
		"m": ["Manjunath", "Nagaraj", "Basavaraj", "Shivakumar", "Raghavendra", "Girish", "Yogesh",
			"Mallikarjun^", "Puneeth*"],
		"f": ["Shilpa", "Roopa", "Sumitra^", "Nandini", "Bhagya", "Pavithra", "Chaitra", "Sowmya", "Gowramma^"],
		"last": ["Gowda", "Hegde", "Shetty", "Kamath", "Naik", "Acharya", "Shenoy", "Kini"],
		"home": ["Hubballi", "Mysuru", "Belagavi", "Davangere", "Udupi"],
	},
	"goan": {
		"m": ["Anthony^", "Agnelo", "Cajetan^", "Domnic", "Elvis", "Ivan", "Marcus", "Rodney", "Savio",
			"Valentine^", "Ryan*"],
		"f": ["Agnes^", "Bernadette", "Clara", "Lorna", "Natasha", "Sheryl", "Sonia", "Teresa", "Velina",
			"Wilma^", "Tanya*"],
		"last": ["Rodrigues", "Pinto", "Dias", "Coutinho", "Mascarenhas", "Noronha", "Furtado", "Lobo",
			"Correia", "Almeida", "Rebello", "Colaco"],
		"home": ["Margao", "Mapusa", "Vasco", "Panaji", "Ponda"],
	},
	"northeast": {
		"m": ["Bikash", "Pranjal", "Diganta", "Hemanta^", "Rituraj", "Sanjib", "Nayan*"],
		"f": ["Pallabi", "Moushumi", "Jonali", "Bornali", "Ankita*", "Rimjhim*", "Minati^"],
		"last": ["Bora", "Gogoi", "Baruah", "Saikia", "Kalita", "Hazarika", "Deka"],
		"home": ["Guwahati", "Jorhat", "Dibrugarh", "Tezpur", "Silchar"],
	},
	"parsi": {
		"m": ["Cyrus", "Darius", "Jehangir^", "Rustom^", "Farokh", "Behram^", "Zubin*"],
		"f": ["Perizad", "Roshan", "Shirin^", "Zarine", "Dilnaz", "Freny^", "Anahita*"],
		"last": ["Irani", "Mistry", "Engineer", "Contractor", "Wadia", "Batliwala", "Daruwala", "Lalkaka"],
		"home": ["Mumbai", "Navsari", "Udvada", "Pune"],
	},
}

static var _blocked := {}


## Every name token a stranger can't have: the cast's first names and
## surnames, and BLOCKED. Lower case.
static func blocked() -> Dictionary:
	if _blocked.is_empty():
		for word: String in BLOCKED:
			_blocked[word.to_lower()] = true
		var cast := StoryBook.cast()
		for id: String in cast:
			var entry: Variant = cast[id]
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			for word in str(entry.get("name", "")).replace(".", " ").split(" ", false):
				if word.length() > 2 and word not in ["Dr", "Mr", "Mrs", "Ms", "Sister", "The", "Your"]:
					_blocked[word.to_lower().replace("'", "")] = true
	return _blocked


static func allowed(word: String) -> bool:
	return not blocked().has(word.to_lower().replace("'", ""))


## A name that fits the age: "*" names are for the young, "^" for the old.
static func fits_age(entry: String, age: int) -> bool:
	if entry.ends_with("*"):
		return age < OLD_FROM
	if entry.ends_with("^"):
		return age >= YOUNG_UNTIL
	return true


static func plain(entry: String) -> String:
	return entry.trim_suffix("*").trim_suffix("^")


## A community, picked by WEIGHTS.
static func community(rng: SeededRandom) -> String:
	var total := 0
	for key: String in WEIGHTS:
		total += int(WEIGHTS[key])
	var roll := rng.next_int(total)
	for key: String in WEIGHTS:
		roll -= int(WEIGHTS[key])
		if roll < 0:
			return key
	return "hindi"


## A stranger's name: {first, last, full, community, sex, home}. sex is "m"
## or "f" ("" picks one); age decides which first names fit. A surname can
## be passed to make a relative of someone already met.
static func make(rng: SeededRandom, sex: String = "", age: int = 40, from: String = "", surname: String = "") -> Dictionary:
	var group := from if COMMUNITIES.has(from) else community(rng)
	var data: Dictionary = COMMUNITIES[group]
	var who := sex if sex in ["m", "f"] else ("m" if rng.chance(0.5) else "f")
	var firsts: Array = []
	for entry: String in data[who]:
		if fits_age(entry, age) and allowed(plain(entry)):
			firsts.append(plain(entry))
	var lasts: Array = []
	for entry: String in data["last"]:
		if allowed(entry):
			lasts.append(entry)
	var first := str(rng.pick(firsts))
	var last := surname if not surname.is_empty() else str(rng.pick(lasts))
	return {
		"first": first,
		"last": last,
		"full": "%s %s" % [first, last],
		"community": group,
		"sex": who,
		"home": str(rng.pick(data["home"])),
	}


## How staff address them: "Mr. Patil", "Ms. Shah" (a young woman),
## "Mrs. Shah", or the first name for a child ("Ayaan").
static func called(person: Dictionary, age: int) -> String:
	if age < 18:
		return str(person.get("first", "Patient"))
	if str(person.get("sex", "m")) == "m":
		return "Mr. %s" % person.get("last", "")
	return ("Ms. %s" if age < 30 else "Mrs. %s") % person.get("last", "")
