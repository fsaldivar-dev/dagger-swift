# dagger-swift

Inyección de dependencias para Swift resueltas en **compile-time**, no en runtime.

Inspirado en [Dagger (Android)](https://dagger.dev): defines un módulo, declaras qué provee, y el compilador garantiza que todo conecta. Sin reflexión. Sin contenedores en runtime. Sin service locators.

## Por qué

La mayoría de las soluciones DI en Swift (Swinject, Resolver, Factory) resuelven dependencias **en runtime**: registras closures en un contenedor y rezas para que el tipo correcto esté ahí cuando lo pidas. Si no está, crash en runtime.

Dagger-Swift toma el enfoque opuesto: **si compila, las dependencias están resueltas.**

## Cómo funciona

Tres piezas:

### 1. Módulo — define qué se provee

```swift
protocol AppModule: Modulable {
    static func provideApiService() -> ApiService
    static func provideUserRepository(apiService: ApiService) -> UserRepository
    static var analisisRepository: AnalisiRepository { get set }
}

enum AppModuleImpl: AppModule {
    @Singleton(wrappedValue: .init(apiService: provideApiService()))
    static var analisisRepository: AnalisiRepository

    static func provideApiService() -> ApiService { .init() }
    static func provideUserRepository(apiService: ApiService) -> UserRepository {
        .init(apiService: apiService)
    }
}
```

### 2. Component — conecta módulo con feature

```swift
struct LoginComponent<Module: AppModule>: AppComponent {
    static func injectLoginSubModule() -> LoginSubModule {
        .init(
            analisiRepository: Module.analisisRepository,
            userRepository: Module.provideUserRepository(apiService: Module.provideApiService())
        )
    }
}
```

### 3. Property Wrappers

| Wrapper | Comportamiento |
|---|---|
| `@Singleton` | Una sola instancia, thread-safe via `actor` |
| `@Provider` | Nueva instancia cada vez que se accede |

```swift
@Singleton(wrappedValue: ApiService())
static var apiService: ApiService  // Siempre la misma instancia

@Provider(wrappedValue: UserSession())
static var session: UserSession    // Nueva instancia cada vez
```

## Instalación

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/fsaldivar-dev/dagger-swift.git", from: "1.0.0")
]
```

```swift
import DaggerSwift
```

## Plataformas

macOS 10.15+ | iOS 13+ | tvOS 13+ | watchOS 6+ | Mac Catalyst 13+

## Licencia

MIT
