//
//  DataRepository.swift
//  Demo
//
//  Created by Saldivar on 21/10/24.
//

public protocol DataRepository {
    func fetchData() -> [String]
}

public final class DataRepositoryImpl: DataRepository {
    public init() {}
    
    public func fetchData() -> [String] {
        ["Hello", "World"]
    }
}
