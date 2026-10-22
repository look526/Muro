import SwiftUI
import AppKit
import MuroKit

// MARK: - The notes themselves

/// One change: what it is, and one line saying what that means.
struct WhatsNewEntry: Identifiable {
    let id = UUID()
    var title: String
    var detail: String
}

/// Entries are grouped so a release reads as two short lists rather than one
/// long one. The tint is the group's own colour, worn by its bubble, so New
/// and Fixed are told apart at a glance instead of by reading two identical
/// grey captions.
struct WhatsNewSection: Identifiable {
    let id = UUID()
    var name: String
    var tint: Color
    var entries: [WhatsNewEntry]
}

struct WhatsNewRelease: Identifiable {
    var id: String { version }
    var version: String
    /// Free text, so a release can say "September 2026" or nothing at all.
    var date: String?
    var headline: String
    var sections: [WhatsNewSection]

    var isEmpty: Bool { sections.allSatisfy { $0.entries.isEmpty } }
}

/// The release notes shown in the sheet.
///
/// Data, never layout: the sheet draws whatever is here, so writing the next
/// release is editing this one list.
enum WhatsNew {
    static let current = WhatsNewRelease(
        version: "6.0.2",
        date: "2026 年 10 月",
        headline: "Muro 现已支持 Apple 航拍壁纸和屏幕保护程序，播放列表可用于锁屏及屏幕保护，并带来浅色、深色外观与全新图标。",
        sections: [
            WhatsNewSection(name: "新增", tint: .muroAccent, entries: [
                WhatsNewEntry(title: "Apple 专区",
                              detail: "在独立标签页中浏览 Apple 的航拍与动态壁纸。"),
                WhatsNewEntry(title: "4K Apple 屏幕保护程序",
                              detail: "将「飘移」「你好」「漂流」等 8 款屏保制作成无缝循环的 4K 视频，可用于桌面、锁屏及屏幕保护。"),
                WhatsNewEntry(title: "锁屏与屏保播放列表",
                              detail: "桌面、锁屏和屏幕保护可各自播放不同列表，关闭后恢复原有壁纸。"),
                WhatsNewEntry(title: "默认、浅色与深色",
                              detail: "在设置中选择经典午夜蓝、简洁白色或纯黑外观。"),
                WhatsNewEntry(title: "全新图标",
                              detail: "全新「玻璃月亮」图标，在程序坞中跟随 Mac 的浅色或深色图标样式。"),
                WhatsNewEntry(title: "导入自有屏幕保护程序",
                              detail: "从资源库添加 XScreenSaver 等 .saver 文件，并在 Muro 中设置。"),
                WhatsNewEntry(title: "将壁纸保存到其他磁盘",
                              detail: "在设置中选择文件夹，移动时显示进度并支持取消。"),
                WhatsNewEntry(title: "设置焕新",
                              detail: "每项设置均有独立的玻璃图标。"),
                WhatsNewEntry(title: "选择菜单栏图标",
                              detail: "六款菜单栏图标可选，包括经典月亮和带环行星。"),
            ]),
            WhatsNewSection(name: "修复", tint: .muroGreen, entries: [
                WhatsNewEntry(title: "macOS 14 崩溃问题",
                              detail: "修复 Muro 6.0 和 6.0.1 在 macOS 14 上启动即退出的问题。"),
                WhatsNewEntry(title: "启动崩溃问题",
                              detail: "修复部分 Mac 上旧版 Apple 航拍列表导致启动崩溃的问题。"),
                WhatsNewEntry(title: "循环播放闪烁",
                              detail: "修复部分壁纸在桌面、锁屏及屏保循环播放时短暂停顿的问题。"),
                WhatsNewEntry(title: "新款 Mac 的锁屏与屏保",
                              detail: "修复设置锁屏或屏保时另一个也被更改的问题。"),
                WhatsNewEntry(title: "部分 Mac 的锁屏问题",
                              detail: "修复 macOS 未启用 Muro 而一直显示 Apple 壁纸的问题，现在 Muro 会自动启用。"),
                WhatsNewEntry(title: "播放列表保留手动选择",
                              detail: "修复手动设置壁纸或暂停后，在下一步被覆盖的问题。"),
                WhatsNewEntry(title: "清理时保留计划中的壁纸",
                              detail: "修复清理资源库时误删播放列表和自动化所用壁纸的问题。"),
                WhatsNewEntry(title: "自定义输入崩溃",
                              detail: "修复输入过长数字导致应用退出的问题。"),
                WhatsNewEntry(title: "更轻量",
                              detail: "关闭壁纸库窗口后释放图片，降低内存占用。"),
                WhatsNewEntry(title: "其他重要修复与改进",
                              detail: "涵盖壁纸库、资源库、菜单栏和设置。"),
            ]),
        ]
    )

    // Past releases are deliberately not listed here. Keeping them inline meant
    // the sheet grew by one more release every time, and 4.0 opened onto a
    // scroll through 3.0, 2.0 and 1.1 before you reached anything current. The
    // footer's "Earlier releases" goes to the releases page, which is the one
    // place that list is complete and does not need shipping in the app.

    static let releasesURL = URL(string: "https://github.com/MrRockySL/Muro/releases")!
}

// MARK: - The sheet

/// What's New: the top bar's sparkle button opens this.
///
/// It is built like the two editor sheets (the same glass, header, scroller
/// and footer) so it reads as part of the app rather than an About box, and it
/// is written against `WhatsNew` so the notes are data, never layout.
struct WhatsNewView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    private let release = WhatsNew.current

    var body: some View {
        VStack(spacing: 0) {
            header
            GlassScrollView(fadeTop: 14, fadeBottom: 22) {
                VStack(alignment: .leading, spacing: 14) {
                    // A newer Muro comes first, above this build's own notes.
                    // Someone who opened this because of the badge is here for
                    // that, and should not have to scroll past old news.
                    if let update = store.latestRelease {
                        updateBlock(update)
                        SectionLabel("当前版本")
                    }
                    releaseCard
                    if release.isEmpty {
                        placeholder
                    } else {
                        ForEach(release.sections) { section in
                            sectionBlock(section)
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 14)
                .padding(.bottom, 10)
            }
            footer
        }
        .frame(width: 580, height: 620)
        .sheetSurface()
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            MuroAppIcon()
                .frame(width: 32, height: 32)
            Text("更新内容")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.muroInk)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.muroInk.opacity(0.85))
                    .glassCircleChrome()
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            Rectangle()
                .fill(.glassSheen(0.05, 0.02))
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.muroInk.opacity(0.08))
                        .frame(height: 1)
                }
        )
    }

    // MARK: The release

    /// The version, the date and the one sentence, inside a card of their own.
    /// It gives the top of the sheet something to be, instead of three loose
    /// pieces of text sitting on the background.
    private var releaseCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Muro \(release.version)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.muroInk)
                if let date = release.date {
                    Text(date)
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.muroSecondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.glassSheen(0.09, 0.03)))
                        .overlay(Capsule().strokeBorder(Color.muroInk.opacity(0.1), lineWidth: 1))
                }
            }
            Text(release.headline)
                .font(.system(size: 12))
                .foregroundStyle(Color.muroSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.glassSheen(0.06, 0.02))
                .overlay(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.muroGlow.opacity(0.30 * Appearance.shared.palette.wash), Color.muroGlow.opacity(0)
                        ]),
                        center: UnitPoint(x: 0.5, y: 1.05), startRadius: 0, endRadius: 260
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.muroInk.opacity(0.12), lineWidth: 1)
        )
    }

    /// The group's name as a bubble in its own colour. A pair of identical grey
    /// captions made New and Fixed look like the same thing twice.
    private func groupBubble(_ section: WhatsNewSection) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(section.tint)
                .frame(width: 5, height: 5)
            Text(section.name.uppercased())
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .tracking(0.5)
                .foregroundStyle(section.tint)
        }
        .padding(.leading, 10)
        .padding(.trailing, 12)
        .padding(.vertical, 5)
        .background(Capsule().fill(section.tint.opacity(0.14)))
        .overlay(Capsule().strokeBorder(section.tint.opacity(0.30), lineWidth: 1))
    }

    // MARK: The update

    /// The new release: what it is, what changed in it, and the button that
    /// gets it. Accent-framed so it cannot be mistaken for the notes of the
    /// build already running.
    private func updateBlock(_ update: ReleaseInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 9.5, weight: .semibold))
                    Text("有可用更新")
                        .font(.system(size: 9.5, weight: .semibold))
                        .tracking(1.3)
                }
                .foregroundStyle(Color.muroInk)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.muroAccent))
                if let date = update.publishedAt.map(Self.dateText) {
                    Text(date)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Color.muroSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Muro \(update.version)")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color.muroInk)
                if let title = update.title {
                    Text(title)
                        .font(.system(size: 13.5))
                        .foregroundStyle(Color.muroSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if update.isEmpty {
                Text("此版本的更新说明可在发布页面查看。")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.muroSecondary)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(update.notes) { note in
                        VStack(alignment: .leading, spacing: 8) {
                            if let name = note.name, !name.isEmpty {
                                SectionLabel(ChineseUI.name(name))
                            }
                            ForEach(Array(note.lines.enumerated()), id: \.offset) { _, line in
                                noteLine(line)
                            }
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                PrimaryPill(title: "下载 Muro \(update.version)") {
                    store.downloadUpdate()
                }
                GhostPill(title: "更新说明") {
                    NSWorkspace.shared.open(update.page)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.glassSheen(0.1, 0.035))
                .overlay(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.muroGlow.opacity(0.28 * Appearance.shared.palette.wash), Color.muroGlow.opacity(0)
                        ]),
                        center: UnitPoint(x: 0.1, y: -0.2), startRadius: 0, endRadius: 360
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.muroAccent.opacity(0.55), lineWidth: 1)
        )
    }

    /// One line of the remote notes. A dot rather than a symbol bubble: the
    /// text comes from GitHub, so there is no icon to pick for it.
    private func noteLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Color.muroAccent)
                .frame(width: 5, height: 5)
                .padding(.top, 6)
            Text(text)
                .font(.system(size: 12.5))
                .foregroundStyle(Color.muroInk.opacity(0.86))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private static func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy 年 M 月 d 日"
        return formatter.string(from: date)
    }

    // MARK: Notes

    private func sectionBlock(_ section: WhatsNewSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            groupBubble(section)
                .padding(.bottom, 1)
            ForEach(section.entries) { entry in
                entryRow(entry)
            }
        }
    }

    /// The name in a rounded face, the explanation in the normal one. The
    /// contrast is what makes a name read as a name; when both were the same
    /// face at the same weight the list read as undifferentiated prose.
    private func entryRow(_ entry: WhatsNewEntry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.title)
                .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.muroInk)
                .fixedSize(horizontal: false, vertical: true)
            Text(entry.detail)
                .font(.system(size: 12))
                .foregroundStyle(Color.muroSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 4)
    }

    /// What the sheet shows until the notes are written. It is a designed
    /// state rather than a blank panel, because an update button that opens
    /// onto nothing reads as a broken one.
    private var placeholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Color.muroAccent)
                .frame(width: 54, height: 54)
                .background(Circle().fill(.glassSheen(0.14, 0.05)))
                .overlay(Circle().strokeBorder(Color.muroInk.opacity(0.16), lineWidth: 1))
            Text("更新说明即将发布")
                .font(.system(size: 14.5, weight: .semibold))
                .foregroundStyle(Color.muroInk)
            Text("新增功能、改进和修复内容将在这里列出。")
                .font(.system(size: 12.5))
                .foregroundStyle(Color.muroSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.glassSheen(0.05, 0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.muroInk.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: Footer

    private var footer: some View {
        SheetFooter {
            Text(
                store.latestRelease == nil
                    ? "当前使用 Muro \(AppStore.appVersion)，已是最新版本"
                    : "当前使用 Muro \(AppStore.appVersion)"
            )
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.muroSecondary)
        } actions: {
            GhostPill(title: "历史版本") {
                NSWorkspace.shared.open(WhatsNew.releasesURL)
            }
            PrimaryPill(title: "完成") { dismiss() }
        }
    }
}
