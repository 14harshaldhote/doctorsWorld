import GameCore
import SwiftUI

/// The panel under (or beside) the floor. It shows the selected patient:
/// what they have said, what tests found, and the buttons to examine,
/// test, diagnose and treat. With nobody selected it explains what to do.
struct BedsidePanel: View {
    let controller: ShiftController
    @State private var diagnosing: DiagnoseTarget?

    struct DiagnoseTarget: Identifiable {
        let id: Int
    }

    var body: some View {
        let shift = controller.shift
        ScrollView {
            Group {
                if let id = controller.selectedPatientID, let bedside = Bedside(patientID: id, in: shift) {
                    PatientDetails(bedside: bedside, shift: shift, controller: controller) {
                        diagnosing = DiagnoseTarget(id: id)
                    }
                } else {
                    IdleHelp(shift: shift, controller: controller)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemGroupedBackground))
        .sheet(item: $diagnosing) { target in
            CasebookSheet(controller: controller, patientID: target.id)
        }
    }
}

/// Everything about one patient.
private struct PatientDetails: View {
    let bedside: Bedside
    let shift: Shift
    let controller: ShiftController
    let onDiagnose: () -> Void

    private var patient: Patient { bedside.patient }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Text(bedside.nextStep.hint(for: patient.name))
                .font(.callout)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("bedsideHint")
            symptoms
            if patient.location == .waiting {
                freeBeds
            } else if patient.bed != nil {
                tests
                actions
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: Theme.statusSymbol(patient.status))
                .font(.title2)
                .foregroundStyle(Theme.status(patient.status))
            VStack(alignment: .leading, spacing: 2) {
                Text(patient.name).font(.title3.weight(.bold))
                Text(patient.bed.map { "Bed \($0 + 1) · \(patient.status.label)" } ?? "Waiting · \(patient.status.label)")
                    .font(.subheadline)
                    .foregroundStyle(Theme.status(patient.status))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("♥ \(Int(bedside.vitals.heartRate.rounded()))")
                Text("O₂ \(Int(bedside.vitals.oxygen.rounded()))%  BP \(Int(bedside.vitals.systolic.rounded()))")
            }
            .font(.caption.monospacedDigit().weight(.semibold))
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("patientHeader")
    }

    private var symptoms: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(patient.examined ? "Symptoms" : "Says").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            FlowLayout {
                ForEach(bedside.knownVisible, id: \.self) { symptom in
                    Chip(text: symptom.displayName, tint: Theme.teal)
                }
                ForEach(bedside.knownFindings, id: \.self) { finding in
                    Chip(text: finding.displayName, tint: Theme.deepTeal, filled: true)
                }
            }
        }
    }

    private var freeBeds: some View {
        HStack {
            ForEach(shift.freeBeds, id: \.self) { bed in
                Button("Bed \(bed + 1)") {
                    controller.perform(.assignBed(patient: patient.id, bed: bed))
                    controller.select(patient.id)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("assignBed\(bed + 1)")
            }
            if shift.freeBeds.isEmpty {
                Text("Every bed is taken. Finish someone first.").font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    private var tests: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tests").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                ForEach(bedside.tests) { option in
                    TestButton(option: option) {
                        controller.perform(.runTest(patient: patient.id, test: option.test))
                    }
                }
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            if bedside.canExamine {
                Button("Examine") { controller.perform(.examine(patient: patient.id)) }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("examineButton")
            }
            if bedside.canDiagnose {
                Button("Diagnose…", action: onDiagnose)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("diagnoseButton")
            }
            if let condition = bedside.diagnosedCondition, bedside.canTreat {
                Button {
                    controller.perform(.treat(patient: patient.id, grade: .good))
                } label: {
                    Label("Treat: \(condition.procedure.displayName)", systemImage: "cross.case.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.stable)
                .accessibilityIdentifier("treatButton")
            }
        }
        .controlSize(.large)
    }
}

/// One diagnostic test: order it, watch it run, read the result.
private struct TestButton: View {
    let option: Bedside.TestOption
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(option.test.displayName).font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(Int(option.seconds.rounded()))s").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                status
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(option.state != .available)
        .accessibilityIdentifier("test-\(option.test.rawValue)")
    }

    @ViewBuilder private var status: some View {
        switch option.state {
        case .available:
            Text("Order").font(.caption.weight(.semibold)).foregroundStyle(Theme.teal)
        case .running(let left, let progress):
            ProgressView(value: progress) {
                Text("Back in \(Int(left.rounded(.up)))s").font(.caption)
            }
            .tint(Theme.teal)
        case .done(let found):
            Label(PlayerText.result(found), systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(found.isEmpty ? Color.secondary : Theme.deepTeal)
        case .blocked:
            Text("Not now").font(.caption).foregroundStyle(.tertiary)
        }
    }
}

/// Shown when no patient is selected.
private struct IdleHelp: View {
    let shift: Shift
    let controller: ShiftController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(shift.isOver ? "Shift over" : "Your ward").font(.title3.weight(.bold))
            Text("Drag waiting patients onto a free bed. Tap a patient in a bed to examine them, order tests, "
                 + "diagnose and treat. Everyone gets worse while you think, the waiting room fastest.")
                .font(.callout)
                .foregroundStyle(.secondary)
            if !shift.waitingPatients.isEmpty {
                Text("Waiting").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                FlowLayout(spacing: 8) {
                    ForEach(shift.waitingPatients) { patient in
                        Button {
                            controller.select(patient.id)
                        } label: {
                            Label(patient.name, systemImage: Theme.statusSymbol(patient.status))
                                .foregroundStyle(Theme.status(patient.status))
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("waiting-\(patient.id)")
                    }
                }
            }
        }
    }
}
