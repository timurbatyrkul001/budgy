import WidgetKit
import SwiftUI

// Budgy ana ekran widget'ı. Veriyi Flutter tarafı (home_widget) App Group
// UserDefaults'a yazar; burada okunup gösterilir.
// App Group id, lib/core/widget_service.dart içindeki appGroupId ile aynı olmalı.
private let appGroupId = "group.co.ggtech.kopilkaApp"
private let budgyGreen = Color(red: 0.059, green: 0.62, blue: 0.424) // #0F9E6C

struct BudgyEntry: TimelineEntry {
    let date: Date
    let today: String
    let moneyLeft: String
    let streak: Int
    let todayLabel: String
    let moneyLeftLabel: String
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> BudgyEntry {
        BudgyEntry(date: Date(), today: "0", moneyLeft: "0", streak: 0,
                   todayLabel: "Bugün", moneyLeftLabel: "Kalan")
    }

    func getSnapshot(in context: Context, completion: @escaping (BudgyEntry) -> Void) {
        completion(readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BudgyEntry>) -> Void) {
        // Bir sonraki güne kadar geçerli; uygulama güncelledikçe yenilenir.
        let next = Calendar.current.date(byAdding: .hour, value: 6, to: Date()) ?? Date()
        completion(Timeline(entries: [readEntry()], policy: .after(next)))
    }

    private func readEntry() -> BudgyEntry {
        let ud = UserDefaults(suiteName: appGroupId)
        return BudgyEntry(
            date: Date(),
            today: ud?.string(forKey: "today") ?? "—",
            moneyLeft: ud?.string(forKey: "moneyLeft") ?? "—",
            streak: ud?.integer(forKey: "streak") ?? 0,
            todayLabel: ud?.string(forKey: "todayLabel") ?? "Bugün",
            moneyLeftLabel: ud?.string(forKey: "moneyLeftLabel") ?? "Kalan"
        )
    }
}

struct BudgyWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.9))
                Text("Budgy")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(.white)
                Spacer()
                if entry.streak > 0 {
                    Text("🔥\(entry.streak)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            Spacer()
            Text(entry.todayLabel.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
            Text(entry.today)
                .font(.system(size: 24, weight: .heavy))
                .foregroundColor(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text("\(entry.moneyLeftLabel): \(entry.moneyLeft)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

@main
struct BudgyWidget: Widget {
    let kind = "BudgyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOSApplicationExtension 17.0, *) {
                BudgyWidgetEntryView(entry: entry)
                    .containerBackground(budgyGreen, for: .widget)
            } else {
                BudgyWidgetEntryView(entry: entry)
                    .background(budgyGreen)
            }
        }
        .configurationDisplayName("Budgy")
        .description("Bugünkü kazanç ve cepte kalan.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
