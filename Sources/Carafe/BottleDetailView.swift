import AppKit
import CarafeCore
import SwiftUI
import UniformTypeIdentifiers

struct BottleDetailView: View {
    @Environment(AppModel.self) private var model
    let bottle: Bottle

    @State private var programs: [Program] = []
    @State private var confirmingDelete = false
    @State private var newVariableName = ""
    @State private var newVariableValue = ""

    private var isRunning: Bool { model.running.contains(bottle.id) }
    private var variables: [(name: String, value: String)] {
        bottle.settings.extraEnvironment.sorted { $0.key < $1.key }.map { (name: $0.key, value: $0.value) }
    }
    private var newVariableIsValid: Bool {
        !newVariableName.isEmpty && !newVariableName.contains { $0 == "=" || $0.isWhitespace }
    }

    var body: some View {
        Form {
            Section("Programs") {
                if programs.isEmpty {
                    Text("Nothing installed yet. Click Run to open an installer or .exe, or drop one onto this window.")
                        .foregroundStyle(.secondary)
                }
                ForEach(programs) { program in
                    HStack {
                        Label(program.name, systemImage: program.isPinned ? "pin" : "app")
                        Spacer()
                        if program.isPinned {
                            Button {
                                model.unpin(program, in: bottle)
                            } label: {
                                Image(systemName: "pin.slash")
                            }
                            .buttonStyle(.borderless)
                            .help("Remove \(program.name) from this list. The program itself stays installed.")
                            .accessibilityLabel("Unpin \(program.name)")
                        }
                        Button("Launch") { model.open(program.url, in: bottle) }
                    }
                }
                Button("Pin a Program…") { choosePin() }
                    .help("Add a program from this bottle's C: drive that the list doesn't show on its own")
            }

            Section("Tools") {
                HStack {
                    ForEach(WineTool.allCases) { tool in
                        Button(tool.title) { model.runTool(tool, in: bottle) }
                    }
                }
                HStack {
                    Button("Open C: Drive") { model.showDriveC(of: bottle) }
                    Button("Show Log") { model.showLog(of: bottle) }
                    Button("Quit All Programs") { model.killAll(in: bottle) }
                        .disabled(!isRunning)
                }
            }

            Section("Settings") {
                Picker(selection: binding(\.windowsVersion)) {
                    ForEach(WindowsVersion.allCases) { Text($0.displayName).tag($0) }
                } label: {
                    SettingLabel(
                        title: "Windows Version",
                        info: "The version of Windows this bottle reports to programs. Windows 10 suits most software; pick an older version for programs that refuse to install or misbehave on newer ones.")
                }
                Picker(selection: binding(\.settings.syncMode)) {
                    ForEach(SyncMode.allCases) { Text($0.displayName).tag($0) }
                } label: {
                    SettingLabel(
                        title: "Sync Mode",
                        info: "How Wine emulates the Windows locks and events that multi-threaded programs rely on. MSync is fastest and ESync is the next best, but each only works if the installed Wine build supports it; otherwise it is ignored. Choose Off if a program hangs or crashes. Applies the next time a program starts.")
                }
                Picker(selection: binding(\.settings.graphics)) {
                    ForEach(model.engine(for: bottle)?.graphicsBackends ?? GraphicsBackend.allCases) {
                        Text($0.displayName).tag($0)
                    }
                } label: {
                    SettingLabel(
                        title: "Graphics",
                        info: "What turns a program's DirectX drawing into something your Mac can display. D3DMetal is Apple's and the one to use for modern DirectX 11 and 12 games. If a game shows a black screen, glitches or won't start, try DXMT (DirectX 10–11) or DXVK (DirectX 9–11, best for older games). Wine Built-in is the slowest but most basic fallback. Applies after Quit All Programs.")
                }
                Toggle(isOn: binding(\.settings.retinaMode)) {
                    SettingLabel(
                        title: "Retina Mode",
                        info: "Renders at your display's full pixel resolution instead of scaled-up. Text and graphics look sharper, but windows and fonts appear smaller and games have more pixels to draw, which can lower frame rates.")
                }
                Toggle(isOn: binding(\.settings.metalHUD)) {
                    SettingLabel(
                        title: "Metal Performance HUD",
                        info: "Shows Apple's overlay with frame rate, frame time and GPU memory on top of programs that draw with Metal. Useful for checking game performance. Applies the next time a program starts.")
                }
                Toggle(isOn: binding(\.settings.advertiseAVX)) {
                    SettingLabel(
                        title: "Advertise AVX Through Rosetta",
                        info: "Tells Windows programs the processor supports AVX instructions, which Rosetta can translate on macOS 15 and later. Turn on for games that refuse to start without AVX; leave off otherwise, since translated AVX can be slow. Applies the next time a program starts.")
                }
            }

            Section {
                ForEach(variables, id: \.name) { variable in
                    HStack {
                        Text("\(variable.name)=\(variable.value)")
                            .font(.body.monospaced())
                            .textSelection(.enabled)
                        Spacer()
                        Button {
                            var copy = bottle
                            copy.settings.extraEnvironment[variable.name] = nil
                            model.update(copy)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Remove \(variable.name)")
                        .accessibilityLabel("Remove \(variable.name)")
                    }
                }
                HStack {
                    TextField("Name", text: $newVariableName, prompt: Text("NAME"))
                    TextField("Value", text: $newVariableValue, prompt: Text("value"))
                    Button("Add") { addVariable() }
                        .disabled(!newVariableIsValid)
                }
                .labelsHidden()
                .font(.body.monospaced())
                .onSubmit { if newVariableIsValid { addVariable() } }
            } header: {
                SettingLabel(
                    title: "Environment Variables",
                    info: "Extra variables passed to every program in this bottle, for tweaks a guide or a game's support page tells you to set, such as WINEDLLOVERRIDES or DXVK_HUD. They override Carafe's own settings of the same name. Applies the next time a program starts.")
            }

            Section {
                Button("Delete Bottle…", role: .destructive) { confirmingDelete = true }
            }
        }
        .formStyle(.grouped)
        .disabled(model.busy.contains(bottle.id))
        .navigationTitle(bottle.name)
        .navigationSubtitle("\(bottle.windowsVersion.displayName) · \(model.engine(for: bottle)?.name ?? "engine missing")\(isRunning ? " · Running" : "")")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Rescan this bottle for installed programs")
                Button {
                    chooseFile()
                } label: {
                    Label("Run", systemImage: "play.fill")
                }
                .help("Run a Windows installer or program in this bottle")
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            urls.forEach { model.open($0, in: bottle) }
            return !urls.isEmpty
        }
        .onAppear(perform: refresh)
        .onChange(of: model.busy) { refresh() }
        .onChange(of: bottle.pinnedPrograms) { refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refresh()
        }
        .confirmationDialog("Delete “\(bottle.name)”?", isPresented: $confirmingDelete) {
            Button("Move to Trash", role: .destructive) {
                Task { await model.delete(bottle) }
            }
        } message: {
            Text("This quits its running programs and moves the bottle, including everything installed in it, to the Trash.")
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<Bottle, Value>) -> Binding<Value> {
        Binding(
            get: { bottle[keyPath: keyPath] },
            set: { newValue in
                var copy = bottle
                copy[keyPath: keyPath] = newValue
                model.update(copy)
            }
        )
    }

    private func refresh() {
        programs = model.programs(in: bottle)
    }

    private func addVariable() {
        var copy = bottle
        copy.settings.extraEnvironment[newVariableName] = newVariableValue
        model.update(copy)
        newVariableName = ""
        newVariableValue = ""
    }

    private func choosePin() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = ["exe", "bat", "lnk"].compactMap { UTType(filenameExtension: $0) }
        panel.directoryURL = model.repository.driveC(for: bottle)
        panel.message = "Choose a program in “\(bottle.name)” to add to its Programs list"
        panel.prompt = "Pin"
        if panel.runModal() == .OK, let url = panel.url {
            model.pin(url, in: bottle)
        }
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = ["exe", "msi", "bat", "lnk"].compactMap { UTType(filenameExtension: $0) }
        panel.message = "Choose a Windows installer or program to run in “\(bottle.name)”"
        panel.prompt = "Run"
        if panel.runModal() == .OK, let url = panel.url {
            model.open(url, in: bottle)
        }
    }
}

/// A setting's name with an info button that explains it in a popover.
struct SettingLabel: View {
    let title: String
    let info: String

    @State private var showingInfo = false

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
            Button {
                showingInfo.toggle()
            } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("What does \(title) do?")
            .accessibilityLabel("About \(title)")
            .popover(isPresented: $showingInfo, arrowEdge: .trailing) {
                Text(info)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 280, alignment: .leading)
                    .padding()
            }
        }
    }
}
