import AppKit
import SwiftUI
import UserNotifications

extension AppDelegate {
    @objc func openPreferences() {
        activeMenu?.cancelTracking()
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 540), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = L10n.text("偏好设置…")
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: PreferencesView(app: self))
            window.center(); settingsWindow = window
        }
        objectWillChange.send()
        settingsWindow?.makeKeyAndOrderFront(nil)
        if !testMode { NSApp.activate(ignoringOtherApps: true) }
    }
    func setNoticeEnabled(_ enabled: Bool) {
        guard !demo, !testMode else { return }
        if !enabled {
            var settings = quotaNotifications.preferences; settings.enabled = false
            quotaNotifications.save(settings); objectWillChange.send(); return
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert])
                var settings = self.quotaNotifications.preferences; settings.enabled = granted
                self.quotaNotifications.save(settings)
                self.notificationStatus = granted ? "通知已开启" : "请在系统设置中允许通知"
            } catch { self.notificationStatus = "无法开启通知，请稍后重试" }
            self.objectWillChange.send()
        }
    }
    /// Allowlist-only report: never serialize errors, identities, paths or payloads.
    func diagnosticSummary() -> String {
        var lines = ["AetherNotchQuota " + (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development"),
                     "macOS " + ProcessInfo.processInfo.operatingSystemVersionString,
                     "mode=\(displayMode.rawValue); accounts=\(visibleTargets.count)"]
        for (index, candidate) in visibleTargets.enumerated() {
            let state = states[candidate] ?? DisplayState()
            lines.append("account[\(index + 1)] provider=\(candidate.provider.rawValue); loading=\(state.loading); error=\(state.error != nil); stale=\(state.stale); windows=\(state.snapshot?.windows.count ?? 0)")
        }
        return lines.joined(separator: "\n")
    }
}

@MainActor struct PreferencesView: View {
    @ObservedObject var app: AppDelegate
    @State private var report = ""
    @State var selectedTab = 0
    private var simulated: Bool { app.demo || app.testMode }
    private func change(_ action: () -> Void) { action(); app.objectWillChange.send() }
    private func noticeBinding<T>(_ key: WritableKeyPath<QuotaNoticePreferences, T>) -> Binding<T> {
        Binding(get: { app.quotaNotifications.preferences[keyPath: key] }, set: { value in
            guard !simulated else { return }
            var settings = app.quotaNotifications.preferences; settings[keyPath: key] = value
            app.quotaNotifications.save(settings); app.objectWillChange.send()
        })
    }
    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 6) {
                navigationButton(0, title: "外观与伙伴", icon: "sparkles")
                navigationButton(1, title: "账号设置", icon: "person.crop.circle")
                navigationButton(2, title: "额度提醒", icon: "bell")
                navigationButton(3, title: "更新与诊断", icon: "info.circle")
            }
            Divider()
            Group {
                switch selectedTab {
                case 1: accounts
                case 2: notices
                case 3: support
                default: display
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.padding(18).frame(width: 620, height: 540)
            .background(Color(nsColor: .windowBackgroundColor))
    }
    private func navigationButton(_ index: Int, title: String, icon: String) -> some View {
        Button { selectedTab = index } label: {
            Label(L10n.text(title), systemImage: icon)
                .font(.system(size: 12, weight: selectedTab == index ? .semibold : .regular))
                .frame(maxWidth: .infinity).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 9).fill(selectedTab == index ? Color.accentColor.opacity(0.18) : Color.clear))
        }.buttonStyle(.plain).accessibilityAddTraits(selectedTab == index ? .isSelected : [])
    }
    private var display: some View {
        Form {
            Picker(L10n.text("显示方式"), selection: Binding(get: { app.displayMode }, set: { mode in change { app.setDisplayMode(mode) } })) {
                ForEach(DisplayMode.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Toggle(L10n.text("自动轮换（每分钟）"), isOn: Binding(get: { app.automaticRotation }, set: { _ in change { app.toggleAutomaticRotation() } })).disabled(app.displayMode == .sidebar)
            if app.displayMode == .sidebar {
                Picker(L10n.text("收起外观"), selection: Binding(get: { app.sidebar?.appearance ?? .ghost }, set: { style in change { app.sidebar?.setAppearance(style) } })) {
                    ForEach(SidebarAppearance.selectable, id: \.self) { Text($0.title).tag($0) }
                }
                Toggle(L10n.text("小伙伴日常动作"), isOn: Binding(get: { app.sidebar?.companionActivitiesEnabled ?? true }, set: { _ in change { app.toggleCompanionActivities() } }))
                Toggle(L10n.text("活泼互动模式"), isOn: Binding(get: { app.sidebar?.interactiveCompanionEnabled ?? true }, set: { _ in change { app.toggleInteractiveCompanion() } }))
                Toggle(L10n.text("闲置时自动收起"), isOn: Binding(get: { app.sidebar?.autoCollapse ?? true }, set: { _ in change { app.toggleSidebarCollapse() } }))
                Text(L10n.text("拖离屏幕边缘后，单击摸摸，双击查看额度。小龟慢慢探头、小狐轻轻蹭蹭、小幽灵害羞团团。"))
                    .font(.callout).foregroundStyle(.secondary)
            }
            Picker(L10n.text("语言"), selection: Binding(get: { AppLanguage.selection }, set: { language in
                guard !simulated else { return }; AppLanguage.save(language); app.refreshLanguagePresentation()
            })) { ForEach(AppLanguage.allCases, id: \.self) { Text($0.title).tag($0) } }.disabled(simulated)
            Toggle(L10n.text("开机自动启动"), isOn: Binding(get: { !simulated && LaunchAtLogin.state.checkmark == .on }, set: { _ in change { app.toggleLaunchAtLogin() } })).disabled(simulated)
        }.formStyle(.grouped)
    }
    private var accounts: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.text("选择需要显示和查询的账号；额外实例默认关闭。")) .foregroundStyle(.secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(app.detectedApps.map(QuotaTarget.standard) + app.instances.map { QuotaTarget(provider: .antigravity, instance: $0) }, id: \.id) { candidate in
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle(app.displayTitle(candidate), isOn: Binding(get: { app.visibleTargets.contains(candidate) }, set: { _ in
                                change {
                                    let item = NSMenuItem(); item.representedObject = candidate.id
                                    if candidate.instance == nil { app.toggleProviderVisibility(item) } else { app.toggleInstance(item) }
                                }
                            })).disabled(candidate.instance?.supported == false || simulated)
                            if app.blockedAccounts.contains(candidate.id) {
                                Text(L10n.text("账号已变化，请在菜单重新勾选确认")).font(.caption).foregroundStyle(.orange)
                            } else if let error = app.states[candidate]?.error {
                                Text(L10n.message(error)).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                Button(L10n.text("重新扫描实例")) { app.scanInstances() }.disabled(simulated)
                Button(L10n.text("手动添加实例…")) { app.addManualInstance() }.disabled(simulated)
                Button(L10n.text("调整账号顺序…")) { app.editAccountOrder() }.disabled(app.visibleTargets.count < 2)
            }
            HStack {
                Picker(L10n.text("当前账号"), selection: Binding(get: { app.target.id }, set: { id in
                    if let target = app.visibleTargets.first(where: { $0.id == id }) { app.target = target; app.updateView() }
                })) { ForEach(app.visibleTargets, id: \.id) { Text(app.accountLabel($0)).tag($0.id) } }
                Button(L10n.text("修改当前账号别名…")) { app.renameAccount(); app.objectWillChange.send() }.disabled(simulated || app.visibleTargets.isEmpty)
            }
        }.padding(20)
    }
    private var notices: some View {
        Form {
            Toggle(L10n.text("启用系统额度通知"), isOn: Binding(get: { app.quotaNotifications.preferences.enabled }, set: { app.setNoticeEnabled($0) })).disabled(simulated)
            Text(L10n.text("首次读取不提醒；只使用成功刷新的额度，同一周期去重，不额外查询。")) .font(.callout).foregroundStyle(.secondary)
            if !app.notificationStatus.isEmpty { Text(L10n.text(app.notificationStatus)).font(.caption) }
            Group {
                Picker(L10n.text("低额度阈值"), selection: noticeBinding(\.threshold)) { Text("20%").tag(20); Text("10%").tag(10) }
                Toggle(L10n.text("额度恢复至 100% 时通知"), isOn: noticeBinding(\.recovery))
                Toggle(L10n.text("安静时段"), isOn: noticeBinding(\.quietEnabled))
                HStack {
                    Picker(L10n.text("开始"), selection: noticeBinding(\.quietStart)) { ForEach(0..<24) { Text(String(format: "%02d:00", $0)).tag($0) } }
                    Picker(L10n.text("结束"), selection: noticeBinding(\.quietEnd)) { ForEach(0..<24) { Text(String(format: "%02d:00", $0)).tag($0) } }
                }.disabled(!app.quotaNotifications.preferences.quietEnabled)
                ForEach(app.visibleTargets, id: \.id) { target in
                    Toggle(app.accountLabel(target), isOn: Binding(get: { !app.quotaNotifications.preferences.mutedAccounts.contains(target.id) }, set: { enabled in
                        var value = app.quotaNotifications.preferences
                        if enabled { value.mutedAccounts.remove(target.id) } else { value.mutedAccounts.insert(target.id) }
                        app.quotaNotifications.save(value); app.objectWillChange.send()
                    }))
                }
            }.disabled(simulated || !app.quotaNotifications.preferences.enabled)
        }.formStyle(.grouped)
    }
    private var support: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("AetherNotchQuota " + (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development")).font(.title2.bold())
            HStack {
                Button(app.appUpdates.menuTitle) { app.openUpdates() }.disabled(simulated || !app.appUpdates.canCheck)
                Button(L10n.text("使用说明 / 反馈问题…")) { app.openHelp() }
            }
            Toggle(L10n.text("自动检查新版本（每天）"), isOn: Binding(get: { app.appUpdates.automaticallyChecks }, set: { _ in change { app.toggleUpdateChecks() } })).disabled(simulated)
            Divider()
            Text(L10n.text("诊断摘要仅包含版本、显示模式和请求状态，不包含账号名称、凭据、路径或接口响应。")) .foregroundStyle(.secondary)
            Button(L10n.text("预览诊断摘要")) { report = app.diagnosticSummary() }
            ScrollView { Text(report).font(.system(.caption, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
            Button(L10n.text("复制摘要")) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(report, forType: .string) }.disabled(report.isEmpty)
        }.padding(20)
    }
}
