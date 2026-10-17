# DaggerSwift v2 (`dagger-swift`)

![Dagger 2 SwiftUI Dependency Injection Framework](./Assets/dagger2-hero.png)

Motor híbrido de **Resolución Explícita en Tiempo de Compilación (`@Module`, `@Scope`, `@Inject`)** y **Grafo Jerárquico de Dependencias (`@BusinessRule`, `@Precondition`, `teardownScope()`)** para Swift 6 y SwiftUI.

> 📘 **[Leer el Libro Completo: Resolución Explícita vs. Dinámica, Comparativa contra Otras Librerías y Benchmarks](./LIBRO_INYECCION_Y_BENCHMARKS.md)**

---

## 🎯 ¿Qué problema resolvemos?

La mayoría de las librerías de Inyección de Dependencias en Swift (*Swinject*, *Resolver*, *Factory*, *swift-dependencies*) dejan **5 huecos críticos** en aplicaciones modulares grandes:

1. **Resolución Dinámica que explota en Runtime (`try!` / `resolve()!`):** Registran closures en un diccionario global. Si alguien olvida registrar una dependencia, **el proyecto compila sin errores** y hace crash cuando el usuario abre la pantalla en producción.
2. **Contaminación de la Capa `Domain` (`@Injected` / `@Dependency`):** Te obligan a meter *property wrappers* dentro de tus Casos de Uso y ViewModels, acoplando tu Dominio a un contenedor global.
3. **Cero noción de `@Precondition` (Sesión por País / Deep Links):** Instancian repositorios y servicios privados antes de verificar si el usuario realmente tiene una sesión válida para ese módulo o país.
4. **Cero Evolución Versionada (`Module(0.1) -> Module(1.0) -> Module(2.0)`):** No tienen una paleta estática (`@Scope` estilo `CodingKeys`) para evolucionar un producto reutilizando providers anteriores (`includes:`) o alternar entre variantes hermanas (`🇲🇽 MX`, `🇺🇸 US`, `🇧🇷 BR`, `🇫🇷 FR`).
5. **Contenedores Globales Inmortales sin Auditoría de Memoria:** Las instancias quedan atrapadas en RAM aunque el usuario cierre el flujo (`Plug & UnPlug`), sin auditar *retain cycles*.

---

## ⚡ Lo que hacemos diferente en `DaggerSwift v2`

### 1. Resolución Explícita en Tiempo de Compilación + Paleta `@Scope` (Estilo `CodingKeys`)

En lugar de usar `try!` o `try?` contra un diccionario dinámico, declaras tu familia de módulos con `@Module(0.1)`, `@Module(1.0)`, `@Module(2.0)` y sintetizas la paleta con `@Scope`:

```swift
// 1. Contrato estático en Domain (Cero try!, cero try?, verificado por el compilador):
public protocol FintechModuleContract: GraphModule {
    static func coreBanking() -> any FintechCoreBankingProtocol
    static func cardEngine() -> any FintechCardEngineProtocol
}

// 2. Evolución de Producto en Data -> DI:
@Module(0.1, scope: FintechScope.self)
public enum FintechModuleV0_1: FintechModuleContract {
    @Scoped public static func coreBanking() -> any FintechCoreBankingProtocol { FintechCoreBankingImpl() }
    @Scoped public static func cardEngine() -> any FintechCardEngineProtocol { FintechCardEngineV0_1() }
}

@Module(1.0, scope: FintechScope.self, includes: [FintechModuleV0_1.self])
public enum FintechModuleV1: FintechModuleContract {
    @Scoped public static func cardEngine() -> any FintechCardEngineProtocol { FintechCardEngineV1() }
    public static func coreBanking() -> any FintechCoreBankingProtocol { FintechModuleV0_1.coreBanking() }
}

@Module(2.0, scope: FintechScope.self, includes: [FintechModuleV1.self])
public enum FintechModuleV2: FintechModuleContract {
    @Scoped public static func cardEngine() -> any FintechCardEngineProtocol { FintechCardEngineV2() }
    public static func coreBanking() -> any FintechCoreBankingProtocol { FintechModuleV1.coreBanking() }
}

// 3. @Scope sintetiza automáticamente `FintechScope.Palette` (0.1, 1.0, 2.0) y `FintechScope.module(for:)`:
@Scope(
    of: (any FintechModuleContract).self,
    v0_1: FintechModuleV0_1.self,
    v1_0: FintechModuleV1.self,
    v2_0: FintechModuleV2.self
)
extension FintechScope {}
```

### 2. `@Inject` Puro + Ley de Demeter en `UseCases` y `ViewModels`

`@Inject` genera el `public init(...)` limpio para que tus `UseCases` y `ViewModels` no tengan dependencias ocultas ni *property wrappers*:

```swift
@Inject
public struct GetFintechDashboardUseCase: Sendable {
    let coreBanking: any FintechCoreBankingProtocol // Encapsulado (Ley de Demeter)
    let cardEngine: any FintechCardEngineProtocol
    public let layoutVariant: any FintechHomeLayoutVariantProtocol
    public let creditOfferVariant: any FintechCreditOfferVariantProtocol

    public func execute() async -> FintechDashboardSnapshot {
        let transactions = await coreBanking.fetchRecentTransactions()
        return FintechDashboardSnapshot(
            account: coreBanking.fetchAccountSummary(),
            card: cardEngine.fetchCardProduct(),
            layoutVariant: layoutVariant,
            creditOfferVariant: creditOfferVariant,
            transactions: transactions
        )
    }
}
```

### 3. Plug & UnPlug Real con `@Precondition` por País y `teardownScope()`

Cada módulo de país valida su propia `@Precondition` (`auth.session(for: .mexico)`). Si el usuario inicia sesión en **🇲🇽 México** y cambia a **🇺🇸 USA**, la precondición de USA bloquea el acceso hasta que se autentique en ese país, y `previousModule.teardownScope()` destruye las instancias del país anterior liberando RAM:

```swift
@Module(1.0, scope: CountryNewsScope.self)
public enum MexicoNewsModule: CountryNewsModuleContract {
    @Precondition("Se requiere sesión activa en México (🇲🇽)")
    public static func validateSession(auth: any CountryAuthRepositoryProtocol) -> AuthenticatedCountrySession? {
        auth.session(for: .mexico)
    }

    @Scoped public static func localeProvider() -> any CountryLocaleProviderProtocol { MexicoLocaleProvider() }
    @Scoped public static func newsRepository() -> any CountryNewsRepositoryProtocol { MexicoNewsRepository() }
}
```

---

## 📊 Benchmarks y Comparativa contra Otras Librerías

Resultados medidos en [`Test/BenchmarkComparisonTests.swift`](./Test/BenchmarkComparisonTests.swift) (**10,000 resoluciones** en Apple Silicon `arm64e-apple-macos`):

| Escenario / Librería | Tiempo (10,000 iter.) | Latencia / Resolución | Seguridad en Compilación | Cortocircuito `@Precondition` | Auditoría Leaks (`WeakObjectBox`) |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **1. DaggerSwift Modo Explícito (`@Module` + `@Scope` + `@Inject`)** | **`1.74 ms`** | **`~174 ns`** | **✅ 100% Compile-Time** | **✅ Sí** | **✅ Sí** |
| **2. Service Locator Dinámico (Swinject / Resolver style)** | `13.62 ms` | `~1.36 µs` | ❌ Falla en Runtime (`nil` / `try!`) | ❌ No existe | ❌ No existe |
| **3. DaggerSwift Motor DAG (`ScopeContainer` + CycleCheck)** | `23.05 ms` | `~2.30 µs` | ✅ Verificado con `expectGraph` | **✅ Sí (`3.82 µs` bloqueo en frío)** | **✅ Sí (`teardown() -> [String]`)** |

👉 **Lee el análisis completo de puntos fuertes, puntos débiles y los 5 huecos de otras librerías en [`LIBRO_INYECCION_Y_BENCHMARKS.md`](./LIBRO_INYECCION_Y_BENCHMARKS.md).**

---

## 📱 Demos Incluidas en `Sources/SampleProyect` (Clean Architecture + MVVM + SOLID)

Al compilar la aplicación (`Demo` en Xcode) verás un selector interactivo con **3 aplicaciones demo reales** auditadas por nuestro Linter ([`ArchitectureLinterTests.swift`](./Sources/SampleProyect/Tests/AppGraphTests/ArchitectureLinterTests.swift)):

1. **🌎 Demo 1 (`MultiCountryNewsDemo`) — Login Multi-Country + Noticias en 4 Idiomas:**
   - Variantes hermanas **🇲🇽 Español**, **🇺🇸 English**, **🇧🇷 Português** y **🇫🇷 Français** usando actores nativos de Swift 6 (`public actor`).
   - Acceso estricto por país mediante `@Precondition`: iniciar sesión en México solo desbloquea México; al cambiar a USA/Brasil/Francia el grafo bloquea el feed hasta autenticarse en ese país.
2. **💳 Demo 2 (`FintechMockupDemo`) — Paleta `@Module(0.1 / 1.0 / 2.0)` + A/B Flags:**
   - Demuestra la evolución de producto con `@Scope` (`Module(0.1)` Starter $\rightarrow$ `Module(1.0)` Clásica $\rightarrow$ `Module(2.0)` Metal) y switches en vivo de `@BusinessRule` (Layout Clásico vs. Wealth Bento + Crédito A/B).
3. **🐙 Demo 3 (`Core` + `Services` + `Features`) — GitHub Developer Profile (`@fsaldivar-dev`):**
   - Dividida físicamente en 3 targets SPM independientes con switch Plug & UnPlug en vivo entre `LiveGitHubModule` (`Module(1.0)`) y `LiveGitHubModuleV2` (`Module(2.0)`).

---

## 🧪 Ejecutar Pruebas, Benchmarks y Linter de Arquitectura

```bash
# 1. Ejecutar tests del motor principal DaggerSwift + Benchmarks comparativos (20 tests)
swift test

# 2. Ejecutar Linter de Arquitectura/SOLID + Unit Tests + Graph Tests del SampleProyect (12 tests)
swift test --package-path Sources/SampleProyect
```

---

## 📚 Documentación y Libros del Proyecto

- 📘 **[El Libro de DaggerSwift v2: Resolución Explícita vs. Dinámica, Comparativa y Benchmarks](./LIBRO_INYECCION_Y_BENCHMARKS.md)**
- 📄 **[Memoria Técnica: Limitaciones de DaggerSwift v1 y Dolores en Apps Productivas](./MEMORIA_DAGGER_V1.md)**
- 📜 **[Manifiesto](./MANIFESTO.md)**

## Licencia

MIT
