//
//  ScopeEventLog.swift
//  SampleProyect
//
//  Clean Architecture · Presentation Layer · Telemetry Model
//

import Foundation

public struct ScopeEventLog: Identifiable, Sendable, Equatable {
    public let id = UUID()
    public let timestamp: Date
    public let category: String
    public let message: String
    public let isError: Bool

    public init(category: String, message: String, isError: Bool = false) {
        self.timestamp = Date()
        self.category = category
        self.message = message
        self.isError = isError
    }
}
