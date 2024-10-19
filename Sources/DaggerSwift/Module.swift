//
//  Module.swift
//  DaggerSwift
//
//  Created by Saldivar on 18/10/24.
//


public protocol Modulable { }

public protocol Component {
    associatedtype Module: Modulable
}

public extension Component {
    var module: Module.Type { Module.self }
}

private enum SingletonContainer {
    static var instances: [String: Any] = [:]

    // Método para resolver o crear la instancia de un tipo
    static func resolve<T>(_ type: T.Type, initializer: () -> T) -> T {
        let key = String(describing: T.self)
        if let instance = instances[key] as? T {
            return instance
        } else {
            let newInstance = initializer()
            instances[key] = newInstance
            return newInstance
        }
    }
}

@propertyWrapper
public struct Singleton<T> {
    public var wrappedValue: T

    public init(wrappedValue: @autoclosure @escaping () -> T) {
        self.wrappedValue = SingletonContainer.resolve(T.self, initializer: wrappedValue)
    }
}
