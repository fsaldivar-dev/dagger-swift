//
//  Module.swift
//  DaggerSwift
//
//  Created by Saldivar on 18/10/24.
//


public protocol Modulable { }

public protocol Component {
    associatedtype Module: Modulable
    static var module: Module.Type { get }
}

public extension Component {
    static public var module: Module.Type { ModuleContainer.instances[String(describing: Module.self)] as! Self.Module.Type }
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


private enum ModuleContainer {
    static var instances: [String: Any] = [:]

    // Método para resolver o crear la instancia de un tipo
    static func resolve<T>(_ type: T.Type, initializer: () -> T.Type) -> T.Type {
        let key = String(describing: T.self)
        if let instance = instances[key] as? T.Type {
            return instance
        } else {
            let newInstance = initializer()
            instances[key] = newInstance
            return newInstance
        }
    }
}

public func startModule<T>(_ module: @autoclosure @escaping () -> T.Type) where T: Modulable {
    ModuleContainer.resolve(T.self, initializer: module)
}
