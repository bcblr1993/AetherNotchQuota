import AppKit

extension AppDelegate {
    func appendLanguageMenu(to menu: NSMenu) {
        let choices = NSMenu(); choices.autoenablesItems = false
        for language in AppLanguage.allCases {
            let item = NSMenuItem(title: language.title, action: #selector(selectLanguage(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = language.rawValue
            item.state = AppLanguage.selection == language ? .on : .off
            item.toolTip = L10n.text("系统弹窗在下次启动时使用所选语言")
            choices.addItem(item)
        }
        let parent = NSMenuItem(title: L10n.text("语言"), action: nil, keyEquivalent: "")
        parent.submenu = choices; menu.addItem(parent)
    }
    @objc func selectLanguage(_ item: NSMenuItem) {
        guard let raw = item.representedObject as? String, let language = AppLanguage(rawValue: raw) else { return }
        AppLanguage.save(language)
        refreshLanguagePresentation()
    }
    func refreshLanguagePresentation() {
        activeMenu?.cancelTracking()
        sidebar?.reminder.hide()
        sidebar?.panel.title = L10n.text("AetherNotchQuota 侧边栏")
        sidebar?.detail.title = L10n.text("AetherNotchQuota 账号详情")
        overviewModel.now = Date()
        updateRecoveryItem(); updateView()
        if overviewPopover?.isShown == true || sidebar?.detail.isVisible == true { updateOverview() }
    }
}
