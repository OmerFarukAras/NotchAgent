//
//  CalendarSurface.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 15.06.2026.
//

import SwiftUI

/// Calendar surface: compact week strip, expanded month grid.
struct CalendarSurface: View {
    let isExpanded: Bool
    let nextEventTitle: String
    let nextEventTime: String
    let eventDays: Set<String>
    let holidayDays: Set<String>
    let onDayTap: (Date) -> Void

    private let calendar = Calendar.current
    private let today = Date()
    private let df: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var body: some View {
        if isExpanded {
            monthBody
        } else {
            weekBody
        }
    }

    private var weekBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(today.formatted(.dateTime.month(.wide).year()))
                .font(Design.Typography.surfaceTitle)
                .foregroundStyle(Design.Colors.surfaceLabel)

            HStack(spacing: 0) {
                ForEach(weekDays, id: \.self) { date in
                    weekDayCell(for: date)
                        .frame(maxWidth: .infinity)
                }
            }
            
            nextEventView
        }
        .padding(.horizontal, Design.Spacing.surfaceInternalPadding)
    }

    private var monthBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(today.formatted(.dateTime.month(.wide).year()))
                    .font(Design.Typography.surfaceTitle)
                    .foregroundStyle(Design.Colors.surfaceLabel)

                Spacer()

                Text(today.formatted(.dateTime.weekday(.wide).day()))
                    .font(Design.Typography.surfaceCaption)
                    .foregroundStyle(Design.Colors.surfaceMuted)
            }

            weekdayHeader
            monthGrid
            
            nextEventView
        }
        .padding(.horizontal, Design.Spacing.surfaceInternalPadding)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Design.Colors.surfaceSublabel)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7),
            spacing: 4
        ) {
            ForEach(monthDays, id: \.self) { date in
                monthDayCell(for: date)
            }
        }
    }

    @ViewBuilder
    private var nextEventView: some View {
        if !nextEventTitle.isEmpty && nextEventTitle != "No Upcoming Event" {
            HStack(spacing: 6) {
                Circle()
                    .fill(Design.Colors.mirrorCyan)
                    .frame(width: 6, height: 6)
                
                Text(nextEventTitle)
                    .font(Design.Typography.surfaceCaption)
                    .foregroundStyle(Design.Colors.surfaceLabel)
                    .lineLimit(1)
                
                Spacer()
                
                if !nextEventTime.isEmpty {
                    Text(nextEventTime)
                        .font(Design.Typography.surfaceCaption)
                        .foregroundStyle(Design.Colors.surfaceMuted)
                }
            }
            .padding(.top, 4)
        } else if nextEventTitle == "No Upcoming Event" {
            HStack(spacing: 6) {
                Circle()
                    .fill(Design.Colors.surfaceSecondary)
                    .frame(width: 6, height: 6)
                
                Text(nextEventTitle)
                    .font(Design.Typography.surfaceCaption)
                    .foregroundStyle(Design.Colors.surfaceSecondary)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.top, 4)
        }
    }

    private var weekDays: [Date] {
        let start = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        )!
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...]) + Array(symbols[..<first])
    }

    private var monthDays: [Date] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: today),
            let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
            let lastWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.end.addingTimeInterval(-1))
        else { return [] }

        var dates: [Date] = []
        var cursor = firstWeek.start
        while cursor < lastWeek.end {
            dates.append(cursor)
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor.addingTimeInterval(86_400)
        }
        return dates
    }

    private func weekDayCell(for date: Date) -> some View {
        let isToday = calendar.isDateInToday(date)
        let dayStr = df.string(from: date)
        let hasEvent = eventDays.contains(dayStr)
        let hasHoliday = holidayDays.contains(dayStr)

        return CalendarWeekDayCell(
            date: date,
            isToday: isToday,
            hasEvent: hasEvent,
            hasHoliday: hasHoliday,
            onTap: { onDayTap(date) }
        )
    }

    private func monthDayCell(for date: Date) -> some View {
        let isToday = calendar.isDateInToday(date)
        let isCurrentMonth = calendar.isDate(date, equalTo: today, toGranularity: .month)
        let dayStr = df.string(from: date)
        let hasEvent = eventDays.contains(dayStr)
        let hasHoliday = holidayDays.contains(dayStr)

        return CalendarMonthDayCell(
            date: date,
            isToday: isToday,
            isCurrentMonth: isCurrentMonth,
            hasEvent: hasEvent,
            hasHoliday: hasHoliday,
            onTap: { onDayTap(date) }
        )
    }
}

struct CalendarWeekDayCell: View {
    let date: Date
    let isToday: Bool
    let hasEvent: Bool
    let hasHoliday: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 2) {
            Text(date.formatted(.dateTime.weekday(.abbreviated)))
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Design.Colors.surfaceSublabel)

            VStack(spacing: 2) {
                Text(date.formatted(.dateTime.day()))
                    .font(.system(size: 13, weight: isToday ? .bold : .medium))
                    .foregroundStyle(isToday ? .white : Design.Colors.surfaceSecondary)
                    .frame(width: 26, height: 26)
                    .background(
                        isToday ? Design.Colors.controlBackgroundActive : (isHovered ? Design.Colors.surfaceSecondary.opacity(0.2) : Color.clear),
                        in: Circle()
                    )
                
                HStack(spacing: 2) {
                    if hasEvent {
                        Circle().fill(Design.Colors.mirrorCyan).frame(width: 3, height: 3)
                    }
                    if hasHoliday {
                        Circle().fill(Color.pink).frame(width: 3, height: 3)
                    }
                }
                .frame(height: 3)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture(perform: onTap)
    }
}

struct CalendarMonthDayCell: View {
    let date: Date
    let isToday: Bool
    let isCurrentMonth: Bool
    let hasEvent: Bool
    let hasHoliday: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 1) {
            Text(date.formatted(.dateTime.day()))
                .font(.system(size: 11, weight: isToday ? .bold : .semibold))
                .foregroundStyle(dayColor(isToday: isToday, isCurrentMonth: isCurrentMonth))
                .frame(height: 15)
                .frame(maxWidth: .infinity)
                
            HStack(spacing: 2) {
                if hasEvent {
                    Circle().fill(Design.Colors.mirrorCyan).frame(width: 2.5, height: 2.5)
                }
                if hasHoliday {
                    Circle().fill(Color.pink).frame(width: 2.5, height: 2.5)
                }
            }
            .frame(height: 2.5)
        }
        .frame(height: 19)
        .background(
            isToday ? Design.Colors.controlBackgroundActive : (isHovered ? Design.Colors.surfaceSecondary.opacity(0.2) : Color.clear),
            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
        )
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture(perform: onTap)
    }

    private func dayColor(isToday: Bool, isCurrentMonth: Bool) -> Color {
        if isToday { return .white }
        return isCurrentMonth ? Design.Colors.surfaceSecondary : Design.Colors.surfaceMuted.opacity(0.55)
    }
}
