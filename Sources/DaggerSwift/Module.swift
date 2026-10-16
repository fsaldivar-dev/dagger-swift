//
//  Module.swift
//  DaggerSwift
//
//  Created by Saldivar on 18/10/24.
//
import Foundation

@MainActor
public protocol Modulable { }

@MainActor
public protocol Component {
    associatedtype Module: Modulable
    static var module: Module.Type { get }
}

public extension Component {
    static var module: Module.Type { Module.self }
}

@MainActor
private final class SingletonContainer {
    static let shared = SingletonContainer()
    private var instances: [String: Any] = [:]

    func resolve<T>(_ type: T.Type, initializer: @MainActor () -> T) -> T {
        let key = String(reflecting: T.self)
        if let instance = instances[key] as? T {
            return instance
        } else {
            let newInstance = initializer()
            instances[key] = newInstance
            return newInstance
        }
    }

    func reset() {
        instances.removeAll()
    }
}

@MainActor
@propertyWrapper
public struct Singleton<T>: @unchecked Sendable {
    private let initializer: @MainActor () -> T

    public var wrappedValue: T {
        SingletonContainer.shared.resolve(T.self, initializer: initializer)
    }

    public init(_ wrappedValue: @autoclosure @escaping @MainActor () -> T) {
        self.initializer = wrappedValue
    }

    public init(wrappedValue: @autoclosure @escaping @MainActor () -> T) {
        self.initializer = wrappedValue
    }
}

@MainActor
@propertyWrapper
public struct Provider<T>: @unchecked Sendable {
    private let factory: @MainActor () -> T

    public var wrappedValue: T {
        factory()
    }

    public init(_ wrappedValue: @autoclosure @escaping @MainActor () -> T) {
        self.factory = wrappedValue
    }

    public init(wrappedValue: @autoclosure @escaping @MainActor () -> T) {
        self.factory = wrappedValue
    }
}

