import CarafeCore
import SwiftUI

@main
struct CarafeApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup("Carafe") {
            ContentView()
                .environment(model)
                .frame(minWidth: 820, minHeight: 520)
        }
    }
}

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @State private var showingNewBottle = false

    var body: some View {
        @Bindable var model = model

        NavigationSplitView {
            List(model.bottles, selection: $model.selection) { bottle in
                HStack {
                    Label(bottle.name, systemImage: "wineglass")
                    Spacer()
                    if model.busy.contains(bottle.id) {
                        ProgressView().controlSize(.small)
                    } else if model.running.contains(bottle.id) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.green)
                            .help("Programs are running in this bottle")
                            .accessibilityLabel("Running")
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
            .toolbar {
                ToolbarItem {
                    Button {
                        showingNewBottle = true
                    } label: {
                        Label("New Bottle", systemImage: "plus")
                    }
                    .disabled(model.engine == nil)
                    .help("Create a new bottle, an isolated Windows environment to install programs into")
                }
            }
        } detail: {
            if model.engine == nil {
                SetupView()
            } else if let bottle = model.selectedBottle {
                BottleDetailView(bottle: bottle)
                    .id(bottle.id)
            } else {
                ContentUnavailableView {
                    Label("No Bottle Selected", systemImage: "wineglass")
                } description: {
                    Text("A bottle is an isolated Windows environment. Create one to install apps into.")
                } actions: {
                    Button("New Bottle") { showingNewBottle = true }
                }
            }
        }
        .sheet(isPresented: $showingNewBottle) {
            NewBottleSheet()
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}

struct NewBottleSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var version = WindowsVersion.win10

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        Form {
            TextField("Name", text: $name, prompt: Text("Games"))
            Picker("Windows Version", selection: $version) {
                ForEach(WindowsVersion.allCases) { Text($0.displayName).tag($0) }
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    let name = trimmedName
                    Task { await model.createBottle(name: name, version: version) }
                    dismiss()
                }
                .disabled(trimmedName.isEmpty)
            }
        }
    }
}

struct SetupView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wineglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Wine Is Not Installed")
                .font(.title2.bold())
            Text("Carafe runs Windows programs through Wine. Install downloads a CrossOver-based Wine build plus Apple's D3DMetal and other graphics layers (about 255 MB) from the Sikarugir-App GitHub releases into Carafe's Application Support folder.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 460)

            HStack {
                Button("Install Wine") {
                    Task { await model.installWine() }
                }
                .buttonStyle(.borderedProminent)
                Button("Check Again") { model.reload() }
            }
            .disabled(model.installing)

            if model.installing {
                ProgressView()
            }
            if !model.installLog.isEmpty {
                ScrollView {
                    Text(model.installLog)
                        .font(.caption.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: 460, maxHeight: 120)
            }
        }
        .padding(32)
    }
}
