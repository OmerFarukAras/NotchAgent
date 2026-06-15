//
//  NotchBodyShape.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 15.06.2026.
//

import SwiftUI

/// Custom notch shape with animatable bottom corner radii.
///
/// Top corners stay nearly flat (flush with screen edge).
/// Bottom corners smoothly interpolate between compact and expanded radii.
struct NotchBodyShape: Shape {
    var bottomRadius: CGFloat

    var animatableData: CGFloat {
        get { bottomRadius }
        set { bottomRadius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        UnevenRoundedRectangle(
            topLeadingRadius: Design.Radii.notchTop,
            bottomLeadingRadius: bottomRadius,
            bottomTrailingRadius: bottomRadius,
            topTrailingRadius: Design.Radii.notchTop,
            style: .continuous
        ).path(in: rect)
    }
}
