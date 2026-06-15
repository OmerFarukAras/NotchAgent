//
//  WeatherSurface.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 15.06.2026.
//

import SwiftUI

/// Weather display surface: compact current view, expanded dashboard.
struct WeatherSurface: View {
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        if isExpanded {
            expandedBody
        } else {
            compactBody
        }
    }

    private var compactBody: some View {
        WeatherHoverCell(onTap: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.yellow)
                    .symbolRenderingMode(.multicolor)

                VStack(alignment: .leading, spacing: 1) {
                    Text("23°")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Design.Colors.surfaceLabel)

                    Text("Partly Cloudy")
                        .font(Design.Typography.surfaceSubtitle)
                        .foregroundStyle(Design.Colors.surfaceSublabel)
                }

                Spacer()

                HStack(spacing: 10) {
                    WeatherForecastCell(hour: "14", icon: "sun.max.fill", temp: "24°", isExpanded: false, onTap: onTap)
                    WeatherForecastCell(hour: "17", icon: "cloud.sun.fill", temp: "22°", isExpanded: false, onTap: onTap)
                    WeatherForecastCell(hour: "20", icon: "cloud.fill", temp: "19°", isExpanded: false, onTap: onTap)
                }
            }
        }
        .padding(.horizontal, Design.Spacing.surfaceInternalPadding)
    }

    private var expandedBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            WeatherHoverCell(onTap: onTap) {
                currentConditions
            }

            HStack(spacing: 8) {
                WeatherForecastCell(hour: "14", icon: "sun.max.fill", temp: "24°", isExpanded: true, onTap: onTap)
                WeatherForecastCell(hour: "17", icon: "cloud.sun.fill", temp: "22°", isExpanded: true, onTap: onTap)
                WeatherForecastCell(hour: "20", icon: "cloud.fill", temp: "19°", isExpanded: true, onTap: onTap)
                WeatherForecastCell(hour: "23", icon: "moon.stars.fill", temp: "17°", isExpanded: true, onTap: onTap)
            }
        }
        .padding(.horizontal, Design.Spacing.surfaceInternalPadding)
    }

    private var currentConditions: some View {
        HStack(spacing: 14) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(.yellow)
                .symbolRenderingMode(.multicolor)
                .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 2) {
                Text("23°")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Design.Colors.surfaceLabel)

                Text("Partly cloudy")
                    .font(Design.Typography.surfaceSubtitle)
                    .foregroundStyle(Design.Colors.surfaceSublabel)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 5) {
                weatherMetric("Feels", "24°")
                weatherMetric("Wind", "11 km/h")
                weatherMetric("Rain", "8%")
            }
        }
    }

    private func weatherMetric(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Design.Colors.surfaceMuted)

            Text(value)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Design.Colors.surfaceSecondary)
        }
    }
}

struct WeatherHoverCell<Content: View>: View {
    let onTap: () -> Void
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        content()
            .padding(6)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
    }
}

struct WeatherForecastCell: View {
    let hour: String
    let icon: String
    let temp: String
    let isExpanded: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: isExpanded ? 4 : 3) {
            Text(hour)
                .font(.system(size: 9, weight: isExpanded ? .bold : .medium))
                .foregroundStyle(Design.Colors.surfaceSublabel)

            Image(systemName: icon)
                .font(.system(size: isExpanded ? 15 : 12, weight: .medium))
                .foregroundStyle(Design.Colors.surfaceSecondary)
                .symbolRenderingMode(.multicolor)

            Text(temp)
                .font(.system(size: isExpanded ? 11 : 10, weight: .bold))
                .foregroundStyle(Design.Colors.surfaceLabel)
        }
        .frame(maxWidth: isExpanded ? .infinity : nil)
        .padding(.vertical, isExpanded ? 8 : 4)
        .padding(.horizontal, isExpanded ? 0 : 6)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}
