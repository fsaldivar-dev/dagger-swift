//
//  Module.swift
//  DaggerSwift
//
//  Created by Saldivar on 18/10/24.
//
import UIKit

public protocol Modulable { }

public protocol Component {
    associatedtype Module: Modulable
    static var module: Module.Type { get }
}

public extension Component {
    static var module: Module.Type { Module.self }
}

private enum SingletonContainer {
    nonisolated(unsafe) static var instances: [String: Any] = [:]
    
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
    
    public init(_ wrappedValue: @autoclosure @escaping () -> T) {
        self.wrappedValue = SingletonContainer.resolve(T.self, initializer: wrappedValue)
    }
}

@propertyWrapper
public struct Provider<T> {
    public var wrappedValue: T
    
    public init(_ wrappedValue: @autoclosure @escaping () -> T) {
        self.wrappedValue = wrappedValue()
    }
}
