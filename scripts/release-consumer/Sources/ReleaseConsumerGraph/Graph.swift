import DaggerSwift

public protocol ClockProtocol: Sendable {
    var now: Int { get }
}

@Inject
public final class SystemClock: ClockProtocol, Sendable {
    public var now: Int { 42 }
}

@Inject
public struct Greeter: Sendable {
    let clock: any ClockProtocol

    public func greet() -> String { "hola @ \(clock.now)" }
}

public enum ConsumerScope: GraphScope {}

@Module(scope: ConsumerScope.self)
public enum ConsumerModule {
    @Singleton
    public static func clock() -> any ClockProtocol { SystemClock() }
}
