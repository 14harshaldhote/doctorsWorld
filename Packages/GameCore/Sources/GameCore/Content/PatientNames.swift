/// Made-up patient names, picked with the shift's seeded generator.
enum PatientNames {
    static let first = [
        "Asha", "Ravi", "Meera", "Kabir", "Leela", "Arjun", "Nisha", "Vikram",
        "Pooja", "Sameer", "Tara", "Imran", "Divya", "Rohan", "Anjali", "Farah",
        "Dev", "Kavya", "Nikhil", "Sana", "Omar", "Isha", "Aditya", "Riya",
        "Mohan", "Zara", "Neel", "Priya", "Yusuf", "Gita", "Elena", "Tom",
        "Grace", "Leo", "Maya", "Sam", "Noor", "Ben", "Lina", "Jai"
    ]

    static let initials = "ABCDEFGHIJKLMNOPRSTVWY".map(String.init)

    static func name(using generator: inout SeededRandom) -> String {
        let given = first[generator.nextInt(upperBound: first.count)]
        let initial = initials[generator.nextInt(upperBound: initials.count)]
        return "\(given) \(initial)."
    }
}
