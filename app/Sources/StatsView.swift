import AppKit
import SwiftUI

/// "路易莎時光", modeled on GitHub's contribution graph: pick a year on the right,
/// click a day (or use the arrow keys) to see where you were.
struct StatsView: View {
    @ObservedObject var tracker: Tracker
    @State private var range: StatsRange = .pastYear
    @State private var selected: Date?

    private var years: [Int] {
        let current = Calendar.mondayFirst.component(.year, from: Date())
        return Array(Set(tracker.usage.keys.compactMap { Int($0.prefix(4)) } + [current])).sorted(by: >)
    }

    var body: some View {
        let period = Period(range)
        let perDay = tracker.usage.mapValues { $0.values.reduce(0, +) }
        let days = period.days.map { perDay[Tracker.dayKey.string(from: $0)] ?? 0 }
        let total = days.reduce(0, +)
        let visits = days.filter { $0 > 0 }.count
        let stores = storeTotals(period)

        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 22) {
                Text("\(range.heading)在路易莎待了 \(duration(total))").font(.title3.weight(.semibold))

                HStack(spacing: 12) {
                    Tile(label: "去了", value: "\(visits) 天")
                    Tile(label: "去過", value: "\(stores.filter { $0.name != Tracker.unknownStore }.count) 家")
                    Tile(label: "最長連續", value: "\(longestStreak(days)) 天")
                    Tile(label: "平均每次", value: visits > 0 ? duration(total / Double(visits)) : "—")
                }

                HeatmapGrid(period: period, perDay: perDay, selected: $selected)
                DayDetail(date: selected, stores: selected.flatMap { tracker.usage[Tracker.dayKey.string(from: $0)] } ?? [:])
                TopStores(stores: Array(stores.prefix(5)))
            }
            .frame(width: HeatmapGrid.width)

            YearPicker(ranges: [.pastYear] + years.map { .year($0) }, range: $range)
        }
        .padding(24)
        .modifier(ArrowKeys(selected: $selected, period: period))
        .onChange(of: range) { _ in selected = nil }
    }

    private func storeTotals(_ period: Period) -> [(name: String, seconds: Double)] {
        var totals: [String: Double] = [:]
        for day in period.days {
            for (name, s) in tracker.usage[Tracker.dayKey.string(from: day)] ?? [:] { totals[name, default: 0] += s }
        }
        return totals.map { (name: $0.key, seconds: $0.value) }.sorted { $0.seconds > $1.seconds }
    }

    private func longestStreak(_ days: [Double]) -> Int {
        var best = 0, run = 0
        for s in days {
            run = s > 0 ? run + 1 : 0
            best = max(best, run)
        }
        return best
    }
}

// MARK: - Range

enum StatsRange: Hashable {
    case pastYear
    case year(Int)

    var title: String {
        switch self {
        case .pastYear: return "過去一年"
        case .year(let y): return "\(y)"
        }
    }

    var heading: String {
        switch self {
        case .pastYear: return "過去一年"
        case .year(let y): return "\(y) 年"
        }
    }
}

/// The days a range covers and the Monday-aligned grid that shows them.
struct Period {
    let first: Date      // first day counted
    let last: Date       // last day counted, never after today
    let gridStart: Date  // Monday on or before `first`
    let weeks: Int

    init(_ range: StatsRange) {
        let cal = Calendar.mondayFirst
        let today = cal.startOfDay(for: Date())
        let end: Date
        switch range {
        case .pastYear:
            first = cal.date(byAdding: .day, value: -364, to: today)!
            end = today
        case .year(let y):
            first = cal.date(from: DateComponents(year: y, month: 1, day: 1))!
            end = cal.date(from: DateComponents(year: y, month: 12, day: 31))!
        }
        last = min(end, today)
        gridStart = cal.dateInterval(of: .weekOfYear, for: first)!.start
        let lastMonday = cal.dateInterval(of: .weekOfYear, for: end)!.start
        weeks = cal.dateComponents([.day], from: gridStart, to: lastMonday).day! / 7 + 1
    }

    func contains(_ date: Date) -> Bool { date >= first && date <= last }

    var days: [Date] {
        var out: [Date] = []
        var d = first
        while d <= last {
            out.append(d)
            d = Calendar.mondayFirst.date(byAdding: .day, value: 1, to: d)!
        }
        return out
    }
}

// MARK: - Heatmap

struct HeatmapGrid: View {
    let period: Period
    let perDay: [String: Double]
    @Binding var selected: Date?

    static let cell: CGFloat = 11
    static let gap: CGFloat = 3
    static let labelWidth: CGFloat = 20
    static let width = labelWidth + 54 * (cell + gap)  // a year never spans more than 54 weeks

    var body: some View {
        let cal = Calendar.mondayFirst
        let columns = (0..<period.weeks).map { w in
            (0..<7).map { cal.date(byAdding: .day, value: w * 7 + $0, to: period.gridStart)! }
        }
        let months = monthLabels(columns)

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: Self.gap) {
                Color.clear.frame(width: Self.labelWidth, height: 1)
                ForEach(0..<period.weeks, id: \.self) { w in
                    Text(months[w] ?? "")
                        .font(.caption2).foregroundStyle(.secondary)
                        .fixedSize().frame(width: Self.cell, alignment: .leading)
                }
            }
            HStack(alignment: .top, spacing: Self.gap) {
                VStack(spacing: Self.gap) {
                    ForEach(0..<7, id: \.self) { d in
                        Text(["一", "", "三", "", "五", "", "日"][d])
                            .font(.caption2).foregroundStyle(.secondary)
                            .frame(width: Self.labelWidth, height: Self.cell, alignment: .leading)
                    }
                }
                ForEach(0..<period.weeks, id: \.self) { w in
                    VStack(spacing: Self.gap) {
                        ForEach(0..<7, id: \.self) { d in cell(columns[w][d]) }
                    }
                }
            }
            HStack(spacing: Self.gap) {
                Text("點一下格子看那天去了哪裡").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("少").font(.caption2).foregroundStyle(.secondary)
                ForEach([0, 1, 1800, 3600, 7200] as [Double], id: \.self) {
                    RoundedRectangle(cornerRadius: 2).fill(Palette.level($0)).frame(width: Self.cell, height: Self.cell)
                }
                Text("多").font(.caption2).foregroundStyle(.secondary)
            }
            .help("0 ・ 30 分以內 ・ 1 小時以內 ・ 2 小時以內 ・ 2 小時以上")
        }
        .frame(width: Self.width, alignment: .leading)
    }

    @ViewBuilder private func cell(_ date: Date) -> some View {
        let inPeriod = period.contains(date)
        let seconds = perDay[Tracker.dayKey.string(from: date)] ?? 0
        RoundedRectangle(cornerRadius: 2)
            .fill(inPeriod ? Palette.level(seconds) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(Color.primary, lineWidth: 1.5)
                    .opacity(selected == date ? 1 : 0)
            )
            .frame(width: Self.cell, height: Self.cell)
            .contentShape(Rectangle())
            .onTapGesture {
                guard inPeriod else { return }
                selected = selected == date ? nil : date
            }
            .help(inPeriod ? "\(dayLabel(date))：\(seconds > 0 ? duration(seconds) : "沒去")" : "")
    }

    /// Like GitHub: label the first week of each month, skipping labels that would collide.
    private func monthLabels(_ columns: [[Date]]) -> [Int: String] {
        let cal = Calendar.mondayFirst
        var labels: [Int: String] = [:]
        var lastLabeled = -10
        var lastMonth = -1
        for (w, week) in columns.enumerated() {
            guard let day = week.first(where: period.contains) else { continue }
            let month = cal.component(.month, from: day)
            if month != lastMonth && w - lastLabeled >= 3 {
                labels[w] = "\(month)月"
                lastLabeled = w
            }
            lastMonth = month
        }
        return labels
    }
}

/// Arrow keys move the selected day like GitHub's graph: ↑↓ by day, ←→ by week.
struct ArrowKeys: ViewModifier {
    @Binding var selected: Date?
    let period: Period
    @FocusState private var focused: Bool

    func body(content: Content) -> some View {
        if #available(macOS 14, *) {
            content
                .focusable()
                .focusEffectDisabled()
                .focused($focused)
                .onAppear { focused = true }
                .onMoveCommand { direction in
                    let step: Int
                    switch direction {
                    case .up: step = -1
                    case .down: step = 1
                    case .left: step = -7
                    case .right: step = 7
                    @unknown default: return
                    }
                    guard let current = selected else { return selected = period.last }
                    let next = Calendar.mondayFirst.date(byAdding: .day, value: step, to: current)!
                    if period.contains(next) { selected = next }
                }
        } else {
            content
        }
    }
}

// MARK: - Pieces

struct DayDetail: View {
    let date: Date?
    let stores: [String: Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let date {
                let rows = stores.sorted { $0.value > $1.value }
                Text("\(dayLabel(date))（\(weekday(date))）· \(rows.isEmpty ? "沒去" : duration(stores.values.reduce(0, +)))")
                    .font(.headline)
                ForEach(rows, id: \.key) { row in
                    HStack {
                        Text(row.key)
                        Spacer()
                        Text(duration(row.value)).foregroundStyle(.secondary).monospacedDigit()
                    }
                }
            } else {
                Text("選一天看看那天在哪一家、待了多久。").foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.5)))
    }

    private func weekday(_ date: Date) -> String {
        "星期" + ["日", "一", "二", "三", "四", "五", "六"][Calendar.mondayFirst.component(.weekday, from: date) - 1]
    }
}

struct TopStores: View {
    let stores: [(name: String, seconds: Double)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("最常去的門市").font(.headline)
            if stores.isEmpty {
                Text("這段期間還沒有紀錄。連上路易莎之後會開始計時。").foregroundStyle(.secondary)
            }
            ForEach(stores, id: \.name) { row in
                HStack(spacing: 10) {
                    Text(row.name).frame(width: 140, alignment: .leading).lineLimit(1)
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Palette.bar)
                            .frame(width: max(2, geo.size.width * row.seconds / stores[0].seconds))
                    }
                    .frame(height: 14)
                    Text(duration(row.seconds)).foregroundStyle(.secondary).monospacedDigit()
                        .frame(width: 100, alignment: .trailing)
                }
            }
        }
    }
}

struct Tile: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2.weight(.semibold)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.5)))
    }
}

struct YearPicker: View {
    let ranges: [StatsRange]
    @Binding var range: StatsRange

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(ranges, id: \.self) { r in
                Button { range = r } label: {
                    Text(r.title)
                        .frame(width: 72, alignment: .leading)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .foregroundStyle(range == r ? Color.white : Color.primary)
                        .background(RoundedRectangle(cornerRadius: 6).fill(range == r ? Color.accentColor : Color.clear))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
    }
}

// MARK: - Shared

extension Calendar {
    static var mondayFirst: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        return c
    }
}

/// One-hue sequential ramp (blue), with its own steps for dark mode.
enum Palette {
    private static let empty = dynamic(light: 0xF0EFEC, dark: 0x383835)
    private static let steps = [
        dynamic(light: 0xB7D3F6, dark: 0x184F95),
        dynamic(light: 0x6DA7EC, dark: 0x256ABF),
        dynamic(light: 0x2A78D6, dark: 0x3987E5),
        dynamic(light: 0x104281, dark: 0x86B6EF),
    ]
    static let bar = dynamic(light: 0x2A78D6, dark: 0x3987E5)

    static func level(_ seconds: Double) -> Color {
        switch seconds {
        case ..<1: return empty
        case ..<1800: return steps[0]
        case ..<3600: return steps[1]
        case ..<7200: return steps[2]
        default: return steps[3]
        }
    }

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        })
    }
}

func dayLabel(_ date: Date) -> String {
    let c = Calendar.mondayFirst
    return "\(c.component(.month, from: date))月\(c.component(.day, from: date))日"
}

func duration(_ seconds: Double) -> String {
    let minutes = Int(seconds / 60)
    return minutes >= 60 ? "\(minutes / 60) 小時 \(minutes % 60) 分" : "\(minutes) 分"
}
