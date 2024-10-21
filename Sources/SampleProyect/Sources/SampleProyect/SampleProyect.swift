// The Swift Programming Language
// https://docs.swift.org/swift-book

import DaggerSwift
import SwiftUI

@MainActor
public func SampleStartModule<T: AppModule>(module: T.Type) -> any View {
    startModule(module)
    return LoginComponentImpl<T>.loginView()
}
