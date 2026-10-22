import SwiftUI
import ServiceManagement
import MuroKit

struct SettingsView: View {
    @EnvironmentObject var store: AppStore

    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true
    @AppStorage("showDockIcon") private var showDockIcon = true
    @AppStorage("defaultMode") private var defaultMode = "smooth"
    @AppStorage(MenuBarIconStyle.defaultsKey) private var menuBarIcon = MenuBarIconStyle.standard.rawValue

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var confirmClear = false
    @ObservedObject private var downloadFolder = DownloadFolderController.shared
    @State private var customPauseAfter = false
    /// macOS's own screen saver delay, not a Muro setting, so it is read from
    /// Apple's preference rather than stored here and re-read whenever this
    /// window comes forward: System Settings can change it behind our back.
    @State private var screenSaverDelay = ScreenSaverDelay.current()
    /// Set the moment the delay is changed, cleared when the window is next
    /// brought forward. It is the only place the user is told that macOS does
    /// not pick a new delay up straight away.
    @State private var screenSaverDelayJustChanged = false
    /// The window keeps this view alive across close/reopen, which used to
    /// preserve the scroll position — reopening must always show the header.
    @State private var scrollToTopOnNextOpen = false

    var body: some View {
        ZStack {
            // Full-bleed glass layer: fills the ENTIRE window including under
            // the transparent, separator-less titlebar (so the top bar is the
            // same glass, no seam). Content scrolls on top.
            // The light look takes the light kind of glass (6.0).
            VisualEffectBackground(material: Appearance.shared.isLight ? .popover : .hudWindow)
                .overlay(Color.muroShade.opacity(0.22))
                .ignoresSafeArea()

            ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .frame(maxWidth: .infinity)
                    .padding(.top, 30)
                    .id("settings-top")

                section("通用") {
                    row(icon: .launchAtLogin, title: "登录时启动",
                        subtitle: "登录后在后台启动") {
                        Toggle("", isOn: $launchAtLogin)
                            .toggleStyle(.switch)
                            .tint(Color.muroSwitch)
                            .labelsHidden()
                            .onChange(of: launchAtLogin) { _, enabled in
                                setLaunchAtLogin(enabled)
                            }
                    }
                    divider
                    row(icon: .menuBar, title: "显示菜单栏图标",
                        subtitle: menuBarSubtitle) {
                        Toggle("", isOn: $showMenuBarIcon)
                            .toggleStyle(.switch)
                            .tint(Color.muroSwitch)
                            .labelsHidden()
                    }
                    divider
                    row(icon: .dockIcon, title: "显示程序坞图标",
                        subtitle: "关闭后仅在菜单栏中显示 Muro") {
                        Toggle("", isOn: $showDockIcon)
                            .toggleStyle(.switch)
                            .tint(Color.muroSwitch)
                            .labelsHidden()
                            .onChange(of: showDockIcon) { _, on in
                                NSApp.setActivationPolicy(on ? .regular : .accessory)
                                NSApp.activate(ignoringOtherApps: true)
                            }
                    }
                    divider
                    // Default is Muro as it has always looked; Dark is the
                    // same glass in black and white; Light is white with dark
                    // buttons (owner, 2026-10-02). It changes at once, in
                    // every window and the menu bar.
                    row(icon: .appearance, title: "外观",
                        subtitle: "默认、浅色或深色") {
                        CapsuleSegments(
                            options: [AppearanceMode.standard, .light, .dark].map { ($0.title, $0.rawValue) },
                            selection: Binding(
                                get: { Appearance.shared.mode.rawValue },
                                set: { Appearance.shared.set(AppearanceMode(rawValue: $0) ?? .standard) }
                            )
                        )
                    }
                    divider
                    // The icon in the menu bar (6.0): the default and the five
                    // the owner picked from ten drawn in Figma. The menu shows
                    // each glyph beside its name, and the menu bar changes the
                    // moment one is chosen (StatusBarController).
                    row(icon: .menuBarIcon, title: "菜单栏图标",
                        subtitle: "选择 Muro 的菜单栏图标") {
                        GlassDropdown(width: 170, align: .trailing, options: {
                            MenuBarIconStyle.allCases.map { style in
                                MenuOption(
                                    title: style.title,
                                    checked: currentMenuBarIcon == style,
                                    icon: style.menuBarImage()
                                ) { menuBarIcon = style.rawValue }
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(nsImage: currentMenuBarIcon.menuBarImage(size: 16))
                                    .renderingMode(.template)
                                    .foregroundStyle(Color.muroInk)
                                    .frame(width: 16, height: 16)
                                Text(currentMenuBarIcon.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.muroInk)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(Color.muroInk.opacity(0.6))
                            }
                            .padding(.leading, 9)
                            .padding(.trailing, 12)
                            .padding(.vertical, 4.65)
                            .glassCapsule(fill: 0.09, stroke: 0.15)
                        }
                    }
                }

                section("播放") {
                    row(icon: .playbackSpeed, title: "播放速度",
                        subtitle: "调整壁纸播放速度") {
                        GlassDropdown(width: 120, align: .trailing, options: {
                            [0.5, 0.75, 1.0, 1.25, 1.5].map { speed in
                                MenuOption(
                                    title: speedLabel(speed),
                                    checked: abs(store.playbackSpeed - speed) < 0.01
                                ) { store.setPlaybackSpeed(speed) }
                            }
                        }) {
                            HStack(spacing: 6) {
                                Text(speedLabel(store.playbackSpeed))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.muroInk)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(Color.muroInk.opacity(0.6))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5.5)
                            .glassCapsule(fill: 0.09, stroke: 0.15)
                        }
                    }
                    divider
                    row(icon: .defaultQuality, title: "默认画质",
                        subtitle: "节能模式限制为 30 帧，降低 CPU 占用") {
                        CapsuleSegments(
                            options: [("流畅", "smooth"), ("节能", "efficient")],
                            selection: $defaultMode
                        )
                    }
                    divider
                    row(icon: .pauseAfter, title: "定时暂停",
                        subtitle: pauseAfterSubtitle) {
                        GlassDropdown(width: 150, align: .trailing, options: {
                            SettingsView.pauseAfterChoices.map { seconds in
                                MenuOption(
                                    title: seconds == 0 ? "关闭" : durationLabel(seconds),
                                    checked: store.pauseAfterSeconds == seconds
                                ) { store.setPauseAfter(seconds) }
                            } + [.divider, MenuOption(title: "自定义") { customPauseAfter = true }]
                        }) {
                            HStack(spacing: 6) {
                                Text(store.pauseAfterSeconds == 0
                                     ? "关闭" : durationLabel(store.pauseAfterSeconds))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.muroInk)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(Color.muroInk.opacity(0.6))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5.5)
                            .glassCapsule(fill: 0.09, stroke: 0.15)
                        }
                        .anchoredCard(isPresented: $customPauseAfter, width: 300, align: .trailing) {
                            CustomDurationPicker(seconds: Binding(
                                get: { max(10, store.pauseAfterSeconds) },
                                set: { store.setPauseAfter($0) }
                            )) { customPauseAfter = false }
                        }
                    }
                    // Issue #22. Replay on Clear Desktop belongs to Pause After,
                    // so no divider sits between the two, it sits closer to
                    // Pause After than rows sit to each other, and an arrow down
                    // from Pause After stands where its icon would be. A box
                    // around the pair was tried first: it pushed both rows in,
                    // out of line with every other icon and control.
                    subRow(title: "桌面空闲时重新播放", subtitle: replaySubtitle) {
                        Toggle("", isOn: Binding(
                            get: { store.replayOnClearDesktop },
                            set: { store.setReplayOnClearDesktop($0) }
                        ))
                        .toggleStyle(.switch).tint(Color.muroSwitch).labelsHidden()
                    }
                    divider
                    // Apple's setting, offered here so a Mac running Muro as
                    // its screen saver never needs System Settings opened for
                    // the one number that decides when it runs. Muro writes
                    // the same key Apple's own panel writes, and loginwindow
                    // picks it up at its next idle check with nothing to
                    // restart. See MuroKit/ScreenSaverDelay.swift.
                    row(icon: .screenSaver, title: "启动屏幕保护程序",
                        subtitle: screenSaverSubtitle) {
                        GlassDropdown(width: 150, align: .trailing, options: {
                            ScreenSaverDelay.choices.map { seconds in
                                MenuOption(
                                    title: ScreenSaverDelay.label(seconds),
                                    checked: screenSaverDelay == seconds
                                ) {
                                    screenSaverDelay = ScreenSaverDelay.set(seconds)
                                    screenSaverDelayJustChanged = true
                                }
                            }
                        }) {
                            HStack(spacing: 6) {
                                Text(ScreenSaverDelay.label(screenSaverDelay))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.muroInk)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(Color.muroInk.opacity(0.6))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5.5)
                            .glassCapsule(fill: 0.09, stroke: 0.15)
                        }
                    }
                }

                section("节能") {
                    row(icon: .lowPower, title: "低电量模式下自动暂停",
                        subtitle: "节能时保持静止画面") {
                        Toggle("", isOn: Binding(
                            get: { store.autoPauseLowPower },
                            set: { store.setAutoPauseLowPower($0) }
                        ))
                        .toggleStyle(.switch).tint(Color.muroSwitch).labelsHidden()
                    }
                    divider
                    row(icon: .lowBattery, title: "电量低于 20% 时自动暂停",
                        subtitle: "接通电源后自动恢复") {
                        Toggle("", isOn: Binding(
                            get: { store.autoPauseBattery },
                            set: { store.setAutoPauseBattery($0) }
                        ))
                        .toggleStyle(.switch).tint(Color.muroSwitch).labelsHidden()
                    }
                    divider
                    row(icon: .covered, title: "壁纸被遮挡时自动暂停",
                        subtitle: "被窗口或全屏应用遮挡时保持静止") {
                        Toggle("", isOn: Binding(
                            get: { store.autoPauseFullScreen },
                            set: { store.setAutoPauseFullScreen($0) }
                        ))
                        .toggleStyle(.switch).tint(Color.muroSwitch).labelsHidden()
                    }
                    divider
                    // Issue #22. Any app window open on a screen freezes that
                    // screen's wallpaper, and a clear desktop plays it.
                    row(icon: .desktopOnly, title: "仅在桌面可见时播放",
                        subtitle: "显示器上有窗口时保持静止") {
                        Toggle("", isOn: Binding(
                            get: { store.playOnlyOnDesktop },
                            set: { store.setPlayOnlyOnDesktop($0) }
                        ))
                        .toggleStyle(.switch).tint(Color.muroSwitch).labelsHidden()
                    }
                }

                section("显示器") {
                    ForEach(Array(store.displays.enumerated()), id: \.element.id) { index, display in
                        if index > 0 { divider }
                        row(icon: display.isBuiltIn ? .builtInDisplay : .externalDisplay,
                            title: display.displayName,
                            subtitle: "\(display.kindLabel)显示器") {
                            Text("\(display.pixelsW) × \(display.pixelsH)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.muroSecondary)
                        }
                    }
                }

                section("存储") {
                    row(icon: .storage, title: "资源库与缓存",
                        subtitle: store.clearStatus ?? "保留正在使用的壁纸") {
                        HStack(spacing: 10) {
                            Text(formatSize(store.libraryBytes))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.muroSecondary)
                            Button("清理") { confirmClear = true }
                                .buttonStyle(.plain)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.muroInk)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 5.5)
                                .glassCapsule(fill: 0.09, stroke: 0.15)
                        }
                    }
                    // The share of it that came from the Apple section, which
                    // can be most of it: one aerial alone can be 1.5 GB.
                    subRow(title: "Apple 下载内容",
                           subtitle: "Apple 专区的航拍壁纸和图片") {
                        Text(formatSize(store.appleDownloadBytes))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.muroSecondary)
                    }
                    divider
                    row(icon: .downloadFolder, title: "下载文件夹",
                        subtitle: downloadFolder.subtitle) {
                        HStack(spacing: 8) {
                            // A move can take minutes on a slow drive, and it
                            // could not be stopped (full check, 2026-10-01).
                            if downloadFolder.moving != nil {
                                settingsPill("取消") { downloadFolder.cancel() }
                                    .disabled(downloadFolder.cancelling)
                                    .opacity(downloadFolder.cancelling ? 0.45 : 1)
                            } else {
                                if downloadFolder.isCustom {
                                    settingsPill("默认") { downloadFolder.reset() }
                                }
                                settingsPill("更改") { downloadFolder.choose() }
                            }
                        }
                    }
                    // An "Auto-clear memory: Manual / Daily / Weekly" row used
                    // to sit here. Nothing ever read it, and the RAM it claimed
                    // to free is not RAM Muro holds, so it was removed rather
                    // than given a fake implementation.
                }

                // The wallpaper catalog URL is baked in (AppStore
                // .defaultCatalogURL) and not shown here — a normal user never
                // needs to change it, and a bad value only breaks their own
                // Explore. Still overridable via `defaults write … catalogURL`
                // for the owner's own testing.

                section("关于") {
                    row(icon: .softwareUpdate,
                        title: "软件更新",
                        subtitle: updateSubtitle) {
                        updateControl
                    }
                    divider
                    row(icon: .support,
                        title: "支持 Muro",
                        subtitle: "Muro 免费使用，赞助可支持持续开发。") {
                        sponsorControl
                    }
                }

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 28)
            }
            .onReceive(NotificationCenter.default.publisher(
                for: NSWindow.willCloseNotification
            )) { note in
                if (note.object as? NSWindow)?.title == MuroWindow.settings {
                    scrollToTopOnNextOpen = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(
                for: NSWindow.didBecomeKeyNotification
            )) { note in
                guard scrollToTopOnNextOpen,
                      (note.object as? NSWindow)?.title == MuroWindow.settings else { return }
                scrollToTopOnNextOpen = false
                proxy.scrollTo("settings-top", anchor: .top)
            }
            // Separate from the scroll handler above on purpose: that one only
            // runs on a reopen, and this has to run every time the window is
            // brought forward, including straight after a trip to System
            // Settings, or the row would keep showing a value macOS no longer
            // holds.
            .onReceive(NotificationCenter.default.publisher(
                for: NSWindow.didBecomeKeyNotification
            )) { note in
                guard (note.object as? NSWindow)?.title == MuroWindow.settings else { return }
                screenSaverDelay = ScreenSaverDelay.current()
                screenSaverDelayJustChanged = false
            }
            }
        }
        .frame(width: 560, height: 600)
        .menuHost()
        .background(SettingsWindowConfigurator())
        .alert("下载文件夹", isPresented: Binding(
            get: { downloadFolder.message != nil },
            set: { if !$0 { downloadFolder.message = nil } }
        )) {
            Button("确定", role: .cancel) { downloadFolder.message = nil }
        } message: {
            Text(downloadFolder.message ?? "")
        }
        .alert("清理资源库？", isPresented: $confirmClear) {
            Button("取消", role: .cancel) {}
            Button("清理", role: .destructive) { store.clearDownloadedCache() }
        } message: {
            Text(clearMessage)
        }
    }

    /// Issue #3: a fast wallpaper is distracting, so let it move for a while
    /// and then hold on a frame.
    static let pauseAfterChoices = [0, 10, 30, 60, 120, 300, 900, 3600]

    static func pauseAfterLabel(_ seconds: Int) -> String {
        seconds <= 0 ? "关闭" : durationLabel(seconds)
    }

    private var pauseAfterSubtitle: String {
        store.pauseAfterSeconds == 0
            ? "壁纸将持续播放"
            : "播放 \(durationLabel(store.pauseAfterSeconds)) 后保持静止"
    }

    /// Says what macOS will do, not what the menu is called. "System default"
    /// is the honest answer on a Mac where the preference has never been set:
    /// there is no system-wide plist to read it from and loginwindow does not
    /// publish the number it falls back to.
    private var screenSaverSubtitle: String {
        // Said once, right after a change, because it is the moment it matters
        // and it is the difference between "this is broken" and "this is how
        // macOS works". Measured on the owner's Mac on 2026-09-10: the delay
        // was set to 10 minutes at 18:36:51, macOS read it and armed a timer
        // for the full 600 seconds, and did not look at the setting again
        // until 18:46:51. Two further changes in between were ignored. This is
        // not Muro: `loginwindow` reads the preference only when its own timer
        // fires or when the screen is locked, and there is no notification,
        // XPC message or public API that makes it look sooner. Apple's own
        // Settings panel writes the same key the same way and behaves
        // identically.
        // Never needs no explanation of when it takes effect: it already
        // has. "Saved. macOS uses it after the current wait ends..." read
        // oddly under Never (full check, 2026-10-01).
        if screenSaverDelayJustChanged, let seconds = screenSaverDelay, seconds > 0 {
            return "已保存。当前等待结束后生效，锁定屏幕可立即生效。"
        }
        guard let seconds = screenSaverDelay else {
            return "当前由 macOS 决定，可选择具体等待时间。"
        }
        return seconds <= 0
            ? "从不启动屏幕保护程序"
            : "闲置 \(durationLabel(seconds)) 后启动"
    }

    /// Says what is about to happen in counts, and names the part that cannot
    /// be taken back. "Except applied or playlist items" told the user the
    /// rules and left them to work out the consequence.
    private var clearMessage: String {
        let plan = store.clearPlan
        guard !plan.isEmpty else {
            return plan.keptForSchedules > 0
                ? "无需清理。所有壁纸均正在使用，或已加入播放列表及自动化。"
                : "无需清理。所有壁纸均正在使用。"
        }
        let count = plan.removed.count + plan.apple.count
        var text = "将移除 \(count) 张"
            + (count == 1 ? "壁纸" : "壁纸")
            + "，释放约 \(formatSize(plan.bytes + plan.appleBytes))。"
        if !plan.apple.isEmpty {
            text += plan.apple.count == 1
                ? "其中 1 项来自 Apple 专区，可重新下载。"
                : "其中 \(plan.apple.count) 项来自 Apple 专区，可重新下载。"
        }
        let keptPlaying = plan.kept - plan.keptForSchedules
        if keptPlaying > 0 {
            text += keptPlaying == 1
                ? "正在播放的壁纸将保留。"
                : "正在使用的 \(keptPlaying) 张壁纸将保留。"
        }
        if plan.keptForSchedules > 0 {
            text += plan.keptForSchedules == 1
                ? "播放列表和自动化中的壁纸将保留。"
                : "播放列表和自动化中的 \(plan.keptForSchedules) 张壁纸将保留。"
        }
        if plan.personal > 0 {
            text += plan.personal == 1
                ? "其中 1 项是导入的壁纸，删除后需重新导入。原始文件不受影响。"
                : "其中 \(plan.personal) 项是导入的壁纸，删除后需重新导入。原始文件不受影响。"
        }
        return text
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(spacing: 8) {
            MuroAppIcon()
                .frame(width: 64, height: 64)
            Text("Muro")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.muroInk)
            Text("版本 \(AppStore.appVersion)")
                .font(.system(size: 11))
                .foregroundStyle(Color.muroSecondary)
            if let version = store.latestRelease?.version {
                Button {
                    openWhatsNew(store)
                } label: {
                    Text("Muro \(version) 已发布，查看更新内容。")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.muroAccent)
                }
                .buttonStyle(.plain)
            }
            CreditLink(text: "设计与开发：\(Credits.name)", size: 10)
                .padding(.top, 2)
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Color.muroSecondary)
                .padding(.leading, 2)
            VStack(spacing: 0) { content() }
                .liquidGlass(cornerRadius: 14, tint: 0.14, stroke: 0.1)
        }
        .padding(.top, 20)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.muroInk.opacity(0.06))
            .frame(height: 1)
            .padding(.leading, 58)
    }

    /// A setting that only changes the row above it. Placed straight after
    /// that row with no divider, it keeps every measurement of `row`, so its
    /// arrow, title and control line up with every other row. Only its top
    /// padding is shorter, which pulls it towards the row it belongs to.
    private func subRow(
        title: String, subtitle: String, @ViewBuilder control: () -> some View
    ) -> some View {
        HStack(spacing: 12) {
            SettingsIconView(icon: .replay)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.muroInk)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.muroSecondary)
            }
            Spacer()
            control()
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 12)
    }

    /// Replay has nothing to replay without a time, so it says so while
    /// Settings has none. A wallpaper with its own Pause After time still
    /// replays that one.
    private var replaySubtitle: String {
        store.pauseAfterSeconds == 0
            ? "需先设置定时暂停时长"
            : "每次桌面空闲时重新播放 \(durationLabel(store.pauseAfterSeconds))"
    }

    // MARK: - Software update

    private var updateSubtitle: String {
        switch store.updateCheck {
        case .idle:      return "Muro \(AppStore.appVersion)"
        case .checking:  return "正在检查 GitHub…"
        case .upToDate:  return "Muro \(AppStore.appVersion) 已是最新版本"
        case .available(let version, _):
            return "GitHub 上已发布 \(version) 版本"
        case .failed:    return "检查失败，请检查网络连接。"
        }
    }

    @ViewBuilder private var updateControl: some View {
        switch store.updateCheck {
        case .checking:
            ProgressView()
                .controlSize(.small)
                .frame(width: 96)
        case .available:
            // Muro is not self-updating, so this hands over the DMG itself
            // when the release has one and the release page when it does not.
            Button("下载 ↗") { store.downloadUpdate() }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.muroOnAccent)
                .padding(.horizontal, 14)
                .padding(.vertical, 5.5)
                .background(Capsule().fill(Color.muroAccent))
        default:
            Button("立即检查") {
                Task { await store.checkForUpdates(userInitiated: true) }
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.muroInk)
            .padding(.horizontal, 14)
            .padding(.vertical, 5.5)
            .glassCapsule(fill: 0.09, stroke: 0.15)
        }
    }

    /// The only place in Settings that asks for anything.
    ///
    /// One ordinary row, built with the same helper as every other, so it sits
    /// in the list rather than shouting over it. It is already the only warm
    /// colour among the blues and teals and the only heart among the gears,
    /// which is contrast enough; a glowing or pulsing treatment would be a nag
    /// wearing a nicer outfit, and the reason people trust Muro is that it
    /// never does that. Nothing here is gated, nothing is withheld, and
    /// ignoring it costs the user nothing.
    private var sponsorControl: some View {
        // Ko-fi came out (owner, 2026-10-01): the page cannot take money until
        // a bank is linked, and a button that leads nowhere is worse than one
        // way to give that works.
        HStack(spacing: 8) {
            supportPill("GitHub ↗", AppStore.sponsorURL)
        }
    }

    /// Both ways to give wear the same capsule, so neither one is pushed.
    private func supportPill(_ title: String, _ url: URL) -> some View {
        Button(title) { NSWorkspace.shared.open(url) }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.muroInk)
            .padding(.horizontal, 14)
            .padding(.vertical, 5.5)
            .glassCapsule(fill: 0.09, stroke: 0.15)
    }

    /// What the menu bar row says underneath itself.
    ///
    /// Turning Launch at Login on used to switch the menu bar icon back on,
    /// because at the time the icon really was the only way back into a
    /// running Muro. `applicationShouldHandleReopen` fixed that: Launchpad,
    /// Spotlight and Finder all reopen the gallery now. The force outlived its
    /// reason and took the choice away from exactly the people who want Muro
    /// out of the way, which is issue #31.
    ///
    /// So it is gone, and the row says where Muro is instead, on the one
    /// combination where nothing on screen leads back to it.
    private var menuBarSubtitle: String {
        showMenuBarIcon || showDockIcon
            ? "在菜单栏快速控制壁纸"
            : "从启动台或聚焦搜索打开 Muro"
    }

    private var currentMenuBarIcon: MenuBarIconStyle {
        MenuBarIconStyle(rawValue: menuBarIcon) ?? .standard
    }

    /// The glass capsule the Clear button uses, for the rows beside it.
    private func settingsPill(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.muroInk)
            .padding(.horizontal, 14)
            .padding(.vertical, 5.5)
            .glassCapsule(fill: 0.09, stroke: 0.15)
    }

    private func row(
        icon: SettingsIcon, title: String, subtitle: String,
        @ViewBuilder control: () -> some View
    ) -> some View {
        HStack(spacing: 12) {
            SettingsIconView(icon: icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.muroInk)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.muroSecondary)
            }
            Spacer()
            control()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

// MARK: - Frosted-glass window chrome

/// NSVisualEffectView bridge — the translucent blurred "liquid glass" base
/// behind the Settings content.
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}

/// Only touches the window chrome: transparent, full-size-content,
/// separator-less titlebar so the SwiftUI glass background shows through it
/// seamlessly. It does NOT insert any view (that previously covered the
/// content and blanked the window).
struct SettingsWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { configure(view.window) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { configure(view.window) }
    }

    private func configure(_ window: NSWindow?) {
        guard let window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarSeparatorStyle = .none
        window.isMovableByWindowBackground = true
    }
}
