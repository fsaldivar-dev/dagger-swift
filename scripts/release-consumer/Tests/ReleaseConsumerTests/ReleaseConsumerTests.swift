import Testing
import DaggerSwift
import ReleaseConsumerGraph

@Suite("Consumidor de release")
struct ReleaseConsumerTests {
    @Test("@Module + @Inject resuelven contra el binario (singleton compartido)")
    func resolvesGraph() throws {
        let graph = ConsumerModule.buildGraph()
        let greeter = try graph.resolve(Greeter.self)
        #expect(greeter.greet() == "hola @ 42")
        let first = try graph.resolve((any ClockProtocol).self) as AnyObject
        let second = try graph.resolve((any ClockProtocol).self) as AnyObject
        let sameSingleton = first === second
        #expect(sameSingleton)
    }
}
