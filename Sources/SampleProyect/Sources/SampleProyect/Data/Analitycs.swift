//
//  Analitycs.swift
//  Demo
//
//  Created by Saldivar on 21/10/24.
//

public protocol Analytics: Actor {
    func track(event: String)
}

public actor AnalyticsImpl: Analytics {
    public init() {}
    public func track(event: String) {
        print("Analitycs: \(event)")
    }
}
