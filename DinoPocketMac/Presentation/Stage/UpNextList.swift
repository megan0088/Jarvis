//
//  UpNextList.swift
//  Apl
//
//  Tiga reminder terdekat di stage, plus "See all" (spec B §5).
//

import SwiftUI

struct UpNextList: View {
    let viewModel: ReminderListViewModel
    let onOpenNotificationSettings: () -> Void

    @State private var showsAll = false

    var body: some View {
        // Diperbarui tiap menit, supaya reminder yang lewat hilang sendiri.
        TimelineView(.everyMinute) { context in
            let rows = viewModel.upNext(at: context.date)
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text("Up next")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("See all") { showsAll = true }
                        .buttonStyle(.link)
                        .font(.subheadline)
                        .popover(isPresented: $showsAll, arrowEdge: .trailing) {
                            RemindersPopover(viewModel: viewModel)
                        }
                }

                if rows.isEmpty {
                    Text("Ask me to remind you about something.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(rows) { row in
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                            Image(systemName: row.repeatsDaily ? "repeat" : "bell")
                                .foregroundStyle(AppColor.accent)
                                .frame(width: 16)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.reminder.title)
                                    .lineLimit(1)
                                Text(row.whenText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }

                // Reminder tetap tercatat, tapi tidak akan muncul (spec B §9).
                if !viewModel.notificationsAllowed {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "bell.slash")
                            .foregroundStyle(AppColor.statusWarning)
                        Text("Notifications are off")
                        Button("Turn On…", action: onOpenNotificationSettings)
                            .buttonStyle(.link)
                    }
                    .font(.caption)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview("Up next · Light") {
    UpNextList(viewModel: .preview(), onOpenNotificationSettings: {})
        .padding()
        .frame(width: 288)
}

#Preview("Up next · Empty, notifications off · Dark") {
    UpNextList(viewModel: .preview([], notificationsAllowed: false), onOpenNotificationSettings: {})
        .padding()
        .frame(width: 288)
        .preferredColorScheme(.dark)
}
