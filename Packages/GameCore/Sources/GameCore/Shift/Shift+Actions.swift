extension Shift {
    /// Applies a player action. Throws, and changes nothing, if the action
    /// is not allowed right now.
    public mutating func apply(_ action: ShiftAction) throws {
        guard !isOver else { throw ShiftActionError.shiftOver }
        switch action {
        case .assignBed(let id, let bed): try assignBed(patientID: id, bed: bed)
        case .examine(let id): try examine(patientID: id)
        case .runTest(let id, let test): try runTest(patientID: id, test: test)
        case .diagnose(let id, let conditionID): try diagnose(patientID: id, conditionID: conditionID)
        case .treat(let id, let grade): try treat(patientID: id, grade: grade)
        }
    }

    private func index(of id: Int) throws -> Int {
        guard let index = patients.firstIndex(where: { $0.id == id }) else {
            throw ShiftActionError.unknownPatient
        }
        return index
    }

    private func bedIndex(of id: Int) throws -> Int {
        let index = try index(of: id)
        guard patients[index].bed != nil else { throw ShiftActionError.patientNotInBed }
        return index
    }

    private mutating func assignBed(patientID id: Int, bed: Int) throws {
        let index = try index(of: id)
        guard beds.indices.contains(bed) else { throw ShiftActionError.unknownBed }
        guard beds[bed] == nil else { throw ShiftActionError.bedOccupied }
        guard patients[index].location == .waiting else { throw ShiftActionError.patientNotWaiting }

        let mostUrgent = waitingPatients.map(\.stability).min() ?? patients[index].stability
        let correct = patients[index].stability <= mostUrgent + 0.0001
        beds[bed] = id
        patients[index].location = .bed(bed)
        events.append(.triaged(patient: id, bed: bed, correct: correct))
        if correct { award(config.tuning.triageXP, for: .triage) }
    }

    private mutating func examine(patientID id: Int) throws {
        let index = try bedIndex(of: id)
        guard !patients[index].examined else { throw ShiftActionError.alreadyExamined }
        patients[index].examined = true
        patients[index].knownSymptoms.formUnion(condition(of: patients[index])?.visible ?? [])
        events.append(.examined(patient: id))
    }

    private mutating func runTest(patientID id: Int, test: DiagnosticTest) throws {
        let index = try bedIndex(of: id)
        guard patients[index].diagnosis == nil else { throw ShiftActionError.alreadyDiagnosed }
        guard patients[index].pendingTest == nil else { throw ShiftActionError.testAlreadyRunning }
        guard !patients[index].testsRun.contains(test) else { throw ShiftActionError.testAlreadyDone }
        let duration = test.duration * config.testDurationMultiplier
        patients[index].pendingTest = PendingTest(test: test, readyAtTick: tick + Self.ticks(for: duration))
        events.append(.testStarted(patient: id, test: test))
    }

    private mutating func diagnose(patientID id: Int, conditionID: String) throws {
        let index = try bedIndex(of: id)
        guard patients[index].diagnosis == nil else { throw ShiftActionError.alreadyDiagnosed }
        guard catalog.condition(conditionID) != nil else { throw ShiftActionError.unknownCondition }

        let correct = conditionID == patients[index].conditionID
        events.append(.diagnosed(patient: id, condition: conditionID, correct: correct))
        if correct {
            patients[index].diagnosis = conditionID
            patients[index].pendingTest = nil
            var xp = Double(config.tuning.diagnosisXP)
            if patients[index].testsRun.count >= 2 { xp *= config.tuning.manyTestsFactor }
            award(Int(xp.rounded()), for: .diagnosis)
        } else {
            patients[index].wrongGuesses += 1
            streak = 0
            patients[index].stability = max(0, patients[index].stability - config.tuning.wrongDiagnosisPenalty)
            if patients[index].stability <= 0 { losePatient(at: index) }
        }
    }

    private mutating func treat(patientID id: Int, grade: ProcedureGrade) throws {
        let index = try bedIndex(of: id)
        guard patients[index].diagnosis != nil else { throw ShiftActionError.notDiagnosed }

        let tuning = config.tuning
        let multiplier = 1 + Double(min(streak, tuning.streakCap)) * tuning.streakStep
        let base = tuning.xp(for: grade) + tuning.dischargeXP
        if let bed = patients[index].bed { beds[bed] = nil }
        patients[index].location = .discharged
        patients[index].grade = grade
        events.append(.treated(patient: id, grade: grade))
        award(Int((Double(base) * multiplier).rounded()), for: .treatment)

        let clean = patients[index].wrongGuesses == 0 && grade != .poor
        if clean {
            streak += 1
            bestStreak = max(bestStreak, streak)
        } else {
            streak = 0
        }
    }
}
