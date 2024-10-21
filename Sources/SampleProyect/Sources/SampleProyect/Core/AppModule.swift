//
//  AppModule.swift
//  SampleProyect
//
//  Created by Saldivar on 21/10/24.
//

import DaggerSwift
import Foundation

public protocol AppModule: Modulable {
    static var appClient: ApiClient { get }
    static var analytics: Analytics { get }
    static var appRepository: AppRepository { get }
    static var dataRepository: DataRepository { get }
}
