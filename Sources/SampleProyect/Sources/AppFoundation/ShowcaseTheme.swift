//
//  ShowcaseTheme.swift
//  AppFoundation
//
//  Capa Foundation · Design System multiplataforma (iOS & macOS).
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

extension Color {
    public static var showcaseCardBackground: Color {
        #if os(iOS)
        return Color(uiColor: .secondarySystemGroupedBackground)
        #elseif os(macOS)
        return Color(nsColor: .controlBackgroundColor)
        #else
        return Color.secondary.opacity(0.08)
        #endif
    }

    public static var showcaseHeaderBackground: Color {
        #if os(iOS)
        return Color(uiColor: .secondarySystemBackground)
        #elseif os(macOS)
        return Color(nsColor: .windowBackgroundColor)
        #else
        return Color.secondary.opacity(0.06)
        #endif
    }

    public static var showcaseSubtleFill: Color {
        #if os(iOS)
        return Color(uiColor: .tertiarySystemFill)
        #elseif os(macOS)
        return Color(nsColor: .quaternaryLabelColor)
        #else
        return Color.secondary.opacity(0.12)
        #endif
    }

    public static var showcaseSystemBackground: Color {
        #if os(iOS)
        return Color(uiColor: .systemBackground)
        #elseif os(macOS)
        return Color(nsColor: .windowBackgroundColor)
        #else
        return Color.white
        #endif
    }
}
