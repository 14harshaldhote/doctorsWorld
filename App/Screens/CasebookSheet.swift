import GameCore
import SwiftUI

/// Pick a diagnosis from the casebook. Each page lists a condition's
/// visible symptoms, with the ones this patient has highlighted, and the
/// tests that can confirm it. The shift keeps running while you read.
struct CasebookSheet: View {
    let controller: ShiftController
    let patientID: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let shift = controller.shift
        let bedside = Bedside(patientID: patientID, in: shift)
        let known = Set(bedside?.knownVisible ?? [])
        NavigationStack {
            List {
                if let bedside, bedside.canDiagnose {
                    Section {
                        ForEach(shift.catalog.casebook) { entry in
                            let ruledOut = bedside.ruledOut.contains(entry.id)
                            Button {
                                controller.perform(.diagnose(patient: patientID, condition: entry.id))
                                dismiss()
                            } label: {
                                CasebookRow(entry: entry, known: known, ruledOut: ruledOut)
                            }
                            .disabled(ruledOut)
                            .accessibilityIdentifier("diagnose-\(entry.id)")
                        }
                    } footer: {
                        Text("A wrong call costs the patient. Highlighted symptoms are ones this patient has.")
                    }
                } else {
                    Text("This patient no longer needs a diagnosis.").foregroundStyle(.secondary)
                }
            }
            .navigationTitle(bedside.map { "What does \(PlayerText.firstName($0.patient.name)) have?" } ?? "Casebook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct CasebookRow: View {
    let entry: CasebookEntry
    let known: Set<Symptom>
    let ruledOut: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.name).font(.headline).strikethrough(ruledOut)
                Spacer()
                Text(ruledOut ? "Not this" : entry.severity.rawValue.capitalized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ruledOut ? Theme.critical : .secondary)
            }
            FlowLayout(spacing: 4) {
                ForEach(entry.symptoms, id: \.self) { symptom in
                    Chip(text: symptom.displayName, tint: known.contains(symptom) ? Theme.teal : .secondary,
                         filled: known.contains(symptom))
                }
            }
            Text(confirmText).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .opacity(ruledOut ? 0.5 : 1)
        .foregroundStyle(Color.primary)
    }

    private var confirmText: String {
        entry.confirmingTests.isEmpty
            ? "No test needed: the symptoms say it all."
            : "Confirm with: " + entry.confirmingTests.map { $0.displayName }.joined(separator: ", ")
    }
}
