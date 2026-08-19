//
//  BeeCountQuickAddWidget.swift
//  BeeCountWidget
//

import WidgetKit
import SwiftUI
import UIKit

struct BeeCountQuickAddEntry: TimelineEntry {
    let date: Date
    let widgetImagePath: String
}

struct BeeCountQuickAddProvider: TimelineProvider {
    private func imageKey(for family: WidgetFamily) -> String {
        switch family {
        case .systemSmall:
            return "widget_quickAdd_small"
        default:
            return "widget_quickAdd_medium"
        }
    }

    func placeholder(in context: Context) -> BeeCountQuickAddEntry {
        BeeCountQuickAddEntry(
            date: Date(),
            widgetImagePath: WidgetPreviewAssets.path(forImageKey: imageKey(for: context.family))
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (BeeCountQuickAddEntry) -> ()) {
        if context.isPreview {
            completion(BeeCountQuickAddEntry(
                date: Date(),
                widgetImagePath: WidgetPreviewAssets.path(forImageKey: imageKey(for: context.family))))
            return
        }
        let userDefaults = UserDefaults(suiteName: "group.com.tntlikely.beecount")
        let imagePath = userDefaults?.string(forKey: imageKey(for: context.family)) ?? ""
        completion(BeeCountQuickAddEntry(date: Date(), widgetImagePath: imagePath))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let userDefaults = UserDefaults(suiteName: "group.com.tntlikely.beecount")
        let imagePath = userDefaults?.string(forKey: imageKey(for: context.family)) ?? ""
        let entry = BeeCountQuickAddEntry(date: Date(), widgetImagePath: imagePath)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

private let quickAddActionURLs: [URL] = [
    URL(string: "beecount://voice")!,
    URL(string: "beecount://ai-chat")!,
    URL(string: "beecount://camera")!,
    URL(string: "beecount://new?type=expense")!,
]

struct BeeCountQuickAddWidgetEntryView : View {
    var entry: BeeCountQuickAddProvider.Entry
    @Environment(\.widgetFamily) var widgetFamily

    private var isSmall: Bool { widgetFamily == .systemSmall }

    var body: some View {
        if let uiImage = UIImage(contentsOfFile: entry.widgetImagePath) {
            GeometryReader { geometry in
                ZStack {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)

                    if isSmall {
                        smallClickLayer(size: geometry.size)
                    } else {
                        mediumClickLayer(size: geometry.size)
                    }
                }
            }
        } else {
            ZStack {
                Color(red: 1.0, green: 0.76, blue: 0.03)
                VStack {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                    Text("快速记账")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .widgetURL(quickAddActionURLs[0])
        }
    }

    @ViewBuilder
    private func smallClickLayer(size: CGSize) -> some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: size.height * 0.20)
            HStack(spacing: 0) {
                ForEach(0..<2, id: \.self) { col in
                    Link(destination: quickAddActionURLs[col]) { Color.clear }
                }
            }
            .frame(height: size.height * 0.40)
            HStack(spacing: 0) {
                ForEach(2..<4, id: \.self) { col in
                    Link(destination: quickAddActionURLs[col]) { Color.clear }
                }
            }
            .frame(height: size.height * 0.40)
        }
    }

    @ViewBuilder
    private func mediumClickLayer(size: CGSize) -> some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: size.height * 0.22)
            HStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { col in
                    Link(destination: quickAddActionURLs[col]) { Color.clear }
                }
            }
            .frame(height: size.height * 0.78)
        }
    }
}

struct BeeCountQuickAddWidget: Widget {
    let kind: String = "BeeCountQuickAddWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BeeCountQuickAddProvider()) { entry in
            if #available(iOS 17.0, *) {
                BeeCountQuickAddWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        Color.clear
                    }
            } else {
                BeeCountQuickAddWidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("快速记账")
        .description("语音 / AI / 拍照 / 记一笔")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}
