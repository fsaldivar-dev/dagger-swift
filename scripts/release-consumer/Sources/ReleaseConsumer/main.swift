import DaggerSwift

let graph = ConsumerModule.buildGraph()
let greeter = try graph.resolve(Greeter.self)
print("ReleaseConsumer OK: \(greeter.greet())")
