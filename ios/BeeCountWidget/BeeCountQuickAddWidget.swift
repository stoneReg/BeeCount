//
//  BeeCountQuickAddWidget.swift
//  BeeCountWidget
//
//  Created by matrix on 2026/7/19.
//

import WidgetKit
import SwiftUI
import UIKit

struct BeeCountQuickAddEntry: TimelineEntry {
    let date: Date
    let widgetImagePath: String
}

struct BeeCountQuickAddProvider: TimelineProvider {
    /// 按 widget family 选渲染管线写入的图片 key（对应
    /// `lib/widget/widget_spec.dart` 的 `quickAddSmall/Medium`）。
    private func imageKey(for family: WidgetFamily) -> String {
        switch family {
        case .systemSmall:
            return "widget_quickAdd_small"
        default:
            return "widget_quickAdd_medium"
        }
    }

    private func categoryMetaKey(for family: WidgetFamily) -> String {
        family == .systemSmall
            ? "widget_quickAdd_categoryIds_small"
            : "widget_quickAdd_categoryIds_medium"
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

private func parseCategoryIds(metaKey: String) -> [Int] {
    guard let raw = UserDefaults(suiteName: "group.com.tntlikely.beecount")?.string(forKey: metaKey),
          let data = raw.data(using: .utf8),
          let arr = try? JSONSerialization.jsonObject(with: data) as? [Int] else {
        return []
    }
    return arr
}

private func expenseURL(categoryId: Int?) -> URL {
    if let id = categoryId {
        return URL(string: "beecount://new?type=expense&category=\(id)")!
    }
    return URL(string: "beecount://new?type=expense")!
}

private let voiceURL = URL(string: "beecount://voice")!

struct BeeCountQuickAddWidgetEntryView : View {
    var entry: BeeCountQuickAddProvider.Entry
    @Environment(\.widgetFamily) var widgetFamily

    private var isSmall: Bool { widgetFamily == .systemSmall }
    private var columns: Int { isSmall ? 2 : 4 }
    private var cellCount: Int { isSmall ? 4 : 8 }
    private var categorySlots: Int { cellCount - 1 }

    var body: some View {
        if let uiImage = UIImage(contentsOfFile: entry.widgetImagePath) {
            GeometryReader { geometry in
                let metaKey = isSmall
                    ? "widget_quickAdd_categoryIds_small"
                    : "widget_quickAdd_categoryIds_medium"
                let categoryIds = parseCategoryIds(metaKey: metaKey)

                ZStack {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()

                    // 透明点击层:跳过标题 ~18%,下方 2×2 / 2×4 网格(与 Android 对齐)
                    VStack(spacing: 0) {
                        Color.clear.frame(height: geometry.size.height * 0.18)
                        ForEach(0..<2, id: \.self) { row in
                            HStack(spacing: 0) {
                                ForEach(0..<columns, id: \.self) { col in
                                    let index = row * columns + col
                                    if index < categorySlots {
                                        Link(destination: expenseURL(categoryId: categoryIds.indices.contains(index) ? categoryIds[index] : nil)) {
                                            Color.clear
                                        }
                                    } else if index == categorySlots {
                                        Link(destination: voiceURL) {
                                            Color.clear
                                        }
                                    } else {
                                        Color.clear
                                    }
                                }
                            }
                            .frame(height: geometry.size.height * 0.41)
                        }
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
            .widgetURL(voiceURL)
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
        .description("常用分类一键速记 · 末格语音记账")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}
