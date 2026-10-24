//
//  Runtime.swift
//  DaggerSwiftCore
//
//  Created by Saldivar on 18/10/24.
//  Evolved to DaggerSwift v2 (Declarative Macros + DAG Engine) on 16/10/26.
//
import Foundation

@MainActor
public protocol Modulable: GraphScope { }

@MainActor
public protocol Component {
    associatedtype Module: Modulable
    static var module: Module.Type { get }
}

public extension Component {
    static var module: Module.Type { Module.self }
}

@MainActor
public final class SingletonContainer {
    public static let shared = SingletonContainer()
    private var instances: [String: Any] = [:]

    public init() {}

    public func resolve<T>(_ type: T.Type, initializer: @MainActor () -> T) -> T {
        let key = String(reflecting: T.self)
        if let instance = instances[key] as? T {
            return instance
        } else {
            let newInstance = initializer()
            instances[key] = newInstance
            return newInstance
        }
    }

    public func reset() {
        instances.removeAll()
    }
}

// MARK: - Paleta de versiones (usada por la macro @Scope)

/// Paleta estándar de versiones de `@Module` integrada en `DaggerSwift` (estilo `CodingKeys`).
public enum ModulePalette: String, CaseIterable, Identifiable, Sendable, CustomStringConvertible {
    case v0_1 = "0.1"
    case v1_0 = "1.0"
    case v2_0 = "2.0"

    public var id: String { rawValue }

    public var buttonLabel: String {
        "Module(\(rawValue))"
    }

    public var description: String {
        buttonLabel
    }
}

