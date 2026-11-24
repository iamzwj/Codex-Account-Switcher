import AppKit
import SwiftUI

struct Profile: Decodable, Identifiable {
    let id: String
    let label: String
}

struct LauncherError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

func runLauncher(_ arguments: [String]) async throws -> Data {
    try await Task.detached {
        guard let script = Bundle.main.url(forResource: "codex-accounts", withExtension: nil) else {
            throw LauncherError(message: "启动器文件缺失。")
        }
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", script.path] + arguments
        process.standardOutput = output
        process.standardError = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw LauncherError(message: String(decoding: data, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return data
    }.value
}

@main
struct AccountsApp: App {
    var body: some Scene {
        WindowGroup("Codex 账号") {
            AccountsView()
                .frame(minWidth: 480, minHeight: 380)
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 580, height: 440)
    }
}

struct AccountsView: View {
    @State private var profiles: [Profile] = []
    @State private var loaded = false
    @State private var busy = false
    @State private var adding = false
    @State private var name = ""
    @State private var pending: Profile?
    @State private var deleting: Profile?
    @State private var message = ""
    @AppStorage("lastOpenedProfile") private var lastOpened = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
                   let icon = NSImage(contentsOf: url) {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 42, height: 42)
                        .accessibilityHidden(true)
                }
                Text("Codex 账号").font(.system(size: 28, weight: .semibold))
                Spacer()
                Button { name = ""; adding = true } label: {
                    Label("添加账号", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(busy || !loaded)
            }
            if !loaded {
                if message.isEmpty { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
            } else if profiles.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 36)).foregroundStyle(.secondary)
                    Text("还没有添加账号").font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(profiles) { profile in
                            HStack(spacing: 14) {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 30))
                                    .foregroundStyle(Color.cyan)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(profile.label).font(.headline).lineLimit(1)
                                    if profile.id == lastOpened {
                                        Text("上次打开").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Button("切换") { requestSwitch(profile) }
                                    .disabled(busy)
                                    .accessibilityLabel("切换到\(profile.label)")
                                Button(role: .destructive) { deleting = profile } label: {
                                    Image(systemName: "trash")
                                }
                                .disabled(busy)
                                .accessibilityLabel("删除\(profile.label)")
                            }
                            .padding(14)
                            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 13))
                        }
                    }
                }
            }
            if !message.isEmpty {
                Text(message).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
            }
        }
        .padding(24)
        .background(Color(red: 0.07, green: 0.09, blue: 0.14))
        .task {
            do { try await reload() } catch { message = error.localizedDescription }
        }
        .alert("添加账号", isPresented: $adding) {
            TextField("名称或邮箱", text: $name)
            Button("取消", role: .cancel) {}
            Button("添加") { addProfile() }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("名称只保存在本机。打开账号后，在浏览器完成登录。")
        }
        .alert("重新打开 Codex？", isPresented: Binding(
            get: { pending != nil }, set: { if !$0 { pending = nil } }
        ), presenting: pending) { profile in
            Button("取消", role: .cancel) {}
            Button("退出并切换") { open(profile, quitFirst: true) }
        } message: { profile in
            Text("请先保存工作。Codex 会退出并以「\(profile.label)」的配置重新打开。")
        }
        .alert("删除账号？", isPresented: Binding(
            get: { deleting != nil }, set: { if !$0 { deleting = nil } }
        ), presenting: deleting) { profile in
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) { deleteProfile(profile) }
        } message: { profile in
            Text("将删除「\(profile.label)」的本地账号配置和登录状态。项目文件和聊天记录会保留在备份中。")
        }
    }

    private func reload() async throws {
        let data = try await runLauncher(["list", "--json"])
        profiles = try JSONDecoder().decode([Profile].self, from: data)
        loaded = true
    }

    private func addProfile() {
        busy = true
        message = ""
        Task {
            defer { busy = false }
            do {
                _ = try await runLauncher(["add", name])
                try await reload()
                message = "已添加。点击「切换」打开新账号并完成浏览器登录。"
            } catch { message = error.localizedDescription }
        }
    }

    private func deleteProfile(_ profile: Profile) {
        busy = true
        message = ""
        Task {
            defer { busy = false }
            do {
                _ = try await runLauncher(["delete", profile.id])
                if lastOpened == profile.id { lastOpened = "" }
                try await reload()
                message = "已删除「\(profile.label)」。"
            } catch { message = error.localizedDescription }
        }
    }

    private var runningCodex: [NSRunningApplication] {
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.openai.codex")
    }

    private func requestSwitch(_ profile: Profile) {
        if runningCodex.isEmpty { open(profile, quitFirst: false) }
        else { pending = profile }
    }

    private func open(_ profile: Profile, quitFirst: Bool) {
        busy = true
        message = "正在打开「\(profile.label)」…"
        Task {
            defer { busy = false }
            do {
                if quitFirst {
                    for app in runningCodex { _ = app.terminate() }
                    for _ in 0..<40 {
                        if runningCodex.isEmpty { break }
                        try await Task.sleep(nanoseconds: 250_000_000)
                    }
                    guard runningCodex.isEmpty else {
                        throw LauncherError(message: "Codex 还在运行。请处理 Codex 中的提示后重试。")
                    }
                }
                _ = try await runLauncher(["open", profile.id])
                lastOpened = profile.id
                message = ""
            } catch { message = error.localizedDescription }
        }
    }
}
