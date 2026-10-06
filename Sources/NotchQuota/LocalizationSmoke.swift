import AppKit
import SwiftUI

extension AppDelegate {
    func runLocalizationSmoke() {
        Task { @MainActor in
            var failures = 0
            @MainActor func check(_ condition: Bool, _ title: String) {
                print("LOCALIZATION \(AppLanguage.effective.rawValue) \(title): \(condition ? "PASS" : "FAIL")")
                if !condition { failures += 1 }
            }
            func wait() async { try? await Task.sleep(nanoseconds: 250_000_000) }
            @MainActor func capture(_ name: String, _ view: NSView) {
                view.layoutSubtreeIfNeeded(); view.displayIfNeeded()
                guard let folder = ProcessInfo.processInfo.environment["NOTCHQUOTA_SMOKE_DIR"] else { return }
                let output = URL(fileURLWithPath: folder).appendingPathComponent(name + ".png")
                if let window = view.window, window.isVisible {
                    let screenshot = Process(); screenshot.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                    screenshot.arguments = ["-x", "-o", "-l", String(window.windowNumber), output.path]
                    screenshot.standardError = FileHandle.nullDevice
                    if (try? screenshot.run()) != nil {
                        screenshot.waitUntilExit()
                        if screenshot.terminationStatus == 0 { return }
                    }
                }
                guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds),
                      let data = bitmapData(view, bitmap) else { return }
                try? data.write(to: URL(fileURLWithPath: folder).appendingPathComponent(name + ".png"))
            }
            @MainActor func bitmapData(_ view: NSView, _ bitmap: NSBitmapImageRep) -> Data? {
                view.cacheDisplay(in: view.bounds, to: bitmap)
                if view is ThoughtView, let context = NSGraphicsContext(bitmapImageRep: bitmap)?.cgContext {
                    context.clear(CGRect(x: 0, y: 0, width: bitmap.pixelsWide, height: bitmap.pixelsHigh))
                    context.resetClip()
                    context.concatenate(context.ctm.inverted())
                    context.scaleBy(x: CGFloat(bitmap.pixelsWide) / view.bounds.width, y: CGFloat(bitmap.pixelsHigh) / view.bounds.height)
                    view.layer?.render(in: context)
                }
                return bitmap.representation(using: .png, properties: [:])
            }
            suppressMotion = true
            let cached = states, attempts = lastAttempt
            let initialLanguage = AppLanguage.effective
            let savedAliases = accountAliases, savedOrder = accountOrder
            for language in AppLanguage.supported {
                let item = NSMenuItem(); item.representedObject = language.rawValue
                selectLanguage(item)
                check(AppLanguage.effective == language, "manual language switch applies immediately")
                check(quotaView.subviews.compactMap { ($0 as? NSButton)?.accessibilityLabel() }.contains { $0.contains(L10n.text("显示详情")) }, "accessibility label updates immediately")
            }
            let restore = NSMenuItem(); restore.representedObject = initialLanguage.rawValue
            selectLanguage(restore)
            check(accountAliases == savedAliases && accountOrder == savedOrder, "language switch preserves aliases and order")
            let menu = makeMenu()
            @MainActor func verify(_ menu: NSMenu) {
                check(menu.size.width < (NSScreen.main?.visibleFrame.width ?? 1000) - 16, "menu fits screen")
                for submenu in menu.items.compactMap(\.submenu) { verify(submenu) }
            }
            verify(menu)
            check(menu.items.contains { $0.title == L10n.text("刷新额度") }, "localized main menu")
            let settings = menu.items.first { $0.title == L10n.text("设置与更新") }?.submenu
            let choices = settings?.items.first { $0.title == L10n.text("语言") }?.submenu
            check(choices?.items.count == 4, "system and three language choices")
            // Render real menu titles in a static proof sheet without opening a blocking menu.
            let proof = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 560))
            proof.wantsLayer = true; proof.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            for (index, title) in (menu.items.filter { !$0.isSeparatorItem }.map(\.title) + (settings?.items.filter { !$0.isSeparatorItem }.map(\.title) ?? [])).enumerated() {
                let label = NSTextField(labelWithString: title)
                label.font = .systemFont(ofSize: 13); label.frame = NSRect(x: 18, y: 535 - CGFloat(index) * 23, width: 480, height: 20)
                proof.addSubview(label)
                check(label.attributedStringValue.size().width <= 480, "menu title fits proof")
            }
            capture("localized-menu", proof)
            setDisplayMode(.island); quotaView.expanded = true; resize(); await wait()
            capture("localized-island", quotaView)
            setDisplayMode(.menuBar); showOverview(); await wait()
            if let content = overviewPopover?.contentViewController?.view { capture("localized-overview", content) }
            closeOverview()
            setDisplayMode(.sidebar); await wait()
            if let first = visibleTargets.first {
                sidebar?.select(first.id, pin: true); await wait()
                if let detail = sidebar?.detailSurface { capture("localized-sidebar-detail", detail) }
                sidebar?.dismiss(animated: false); sidebar?.exitBar(); sidebar?.setCollapsed(true); await wait()
                sidebar?.showQuotaRecovery(accountID: first.id, windows: ["5 小时", "每周"], style: .cloud)
                await wait()
                check(sidebar?.reminder.panel.isVisible == true, "recovery reminder visible")
                if let view = sidebar?.reminder.panel.contentView { capture("localized-recovery", view) }
                sidebar?.reminder.hide()
                sidebar?.select(first.id, pin: true)
                states[first] = DisplayState(error: "网络请求失败，请检查系统代理")
                updateSidebar(); await wait()
                if let detail = sidebar?.detailSurface { capture("localized-error", detail) }
                check(L10n.message("网络请求失败，请检查系统代理") == L10n.text("网络请求失败，请检查系统代理"), "cached error translates")
                states[first] = DisplayState(); updateSidebar(); await wait()
                if let detail = sidebar?.detailSurface { capture("localized-loading", detail) }
            }
            let editor = AccountOrderEditor(accounts: visibleTargets, label: displayTitle)
            let editorWindow = NSWindow(contentRect: editor.view.frame, styleMask: [.titled], backing: .buffered, defer: false)
            editorWindow.isReleasedWhenClosed = false; editorWindow.contentView = editor.view
            editorWindow.orderFrontRegardless(); await wait()
            capture("localized-account-order", editor.view)
            editorWindow.orderOut(nil)
            check(editor.up.intrinsicContentSize.width < 110 && editor.down.intrinsicContentSize.width < 110, "localized reorder buttons fit")
            states = cached
            check(lastAttempt == attempts, "language presentation makes no quota requests")
            sidebar?.hide(); closeOverview()
            print("LOCALIZATION COMPLETE: \(failures == 0 ? "PASS" : "FAIL")"); fflush(stdout)
            AppLanguage.defaults.removePersistentDomain(forName: AppLanguage.smokeSuite)
            exit(failures == 0 ? 0 : 1)
        }
    }
}
