# DaggerSwift v2 (`dagger-swift`)

![Dagger 2 SwiftUI Dependency Injection Framework](./Assets/dagger2-hero.png)

Motor híbrido de **Resolución Explícita en Tiempo de Compilación (`@Module`, `@Scope`, `@Inject`)** y **Grafo Jerárquico de Dependencias (`@BusinessRule`, `@Precondition`, `teardownScope()`)** para Swift 6, SwiftUI, UIKit y Actores de Concurrencia.

> **Qué es compile-time y qué es runtime (honesto):** las macros (`@Module`, `@Inject`, …) generan código
> al compilar, pero **resolver** el grafo (`resolve`) ocurre en runtime. La validación del grafo en compilación
> (bindings faltantes, ciclos, scopes no abiertos) la hace la herramienta **`dagger-graph`** (CLI o build plugin),
> y `dagger-graph generate` puede reemplazar `resolve` por factories directas. Ver [§6](#6--compile-time-vs-runtime-qué-valida-cada-capa).

> 📘 **[Leer el Libro Completo: Resolución Explícita vs. Dinámica, Comparativa contra Otras Librerías y Benchmarks](./LIBRO_INYECCION_Y_BENCHMARKS.md)**

---

## 📑 Tabla de Contenidos (Manual Completo)

1. **[Cómo Funciona el Grafo de Dependencias (Diagrama General)](#1--cómo-funciona-el-grafo-de-dependencias-diagrama-general)**
2. **[Manual de Conceptos y Decoradores](#2--manual-de-conceptos-y-decoradores)**
   - [2.1 ¿Qué es un `@Module`?](#21-qué-es-un-module)
   - [2.2 ¿Qué es una Variante y cómo se modela? (3 Tipos de Variantes)](#22-qué-es-una-variante-y-cómo-se-modela-3-tipos-de-variantes)
   - [2.3 ¿Cómo funciona `@Inject` y `@Inject(scope:)` por dentro?](#23-cómo-funciona-inject-y-injectscope-por-dentro)
   - [2.4 ¿Qué es una `@Precondition` (Candado de Estado / Sesión por País)?](#24-qué-es-una-precondition-candado-de-estado--sesión-por-país)
   - [2.5 Ciclo de Vida, Memoria y `Plug & UnPlug` (`teardownScope()`)](#25-ciclo-de-vida-memoria-y-plug--unplug-teardownscope)
   - [2.6 Fronteras de la Librería: Ciclo de Vida de Memoria (DI) vs. Ciclo de Vida de la App (RootComposer)](#26-fronteras-de-la-librería-ciclo-de-vida-de-memoria-di-vs-ciclo-de-vida-de-la-app-rootcomposer)
3. **[Manual Completo de Pruebas (`DaggerSwiftTesting` + Unit Tests + Linter)](#3--manual-completo-de-pruebas-daggerswifttesting--unit-tests--linter)**
   - [3.1 Nivel 1: Pruebas Unitarias Puras (Sin Grafo)](#31-nivel-1-pruebas-unitarias-puras-sin-grafo)
   - [3.2 Nivel 2: Pruebas del Grafo de Dependencias (`expectGraph` DSL)](#32-nivel-2-pruebas-del-grafo-de-dependencias-expectgraph-dsl)
   - [3.3 Nivel 3: Linter Automático de Arquitectura y SOLID](#33-nivel-3-linter-automático-de-arquitectura-y-solid)
4. **[Benchmarks y Comparativa contra Otras Librerías](#4--benchmarks-y-comparativa-contra-otras-librerías)**
5. **[Demos Reales Incluidas (`SampleProyect`) y Estructura del Repositorio](#5--demos-reales-incluidas-sampleproyect-y-estructura-del-repositorio)**
6. **[Compile-time vs runtime: qué valida cada capa](#6--compile-time-vs-runtime-qué-valida-cada-capa)**
7. **[Herramientas: `dagger-graph` (CLI, plugin, `generate`, manifiestos)](#7--herramientas-dagger-graph-cli-plugin-generate-manifiestos)**
8. **[Distribución: dev desde fuente, release como binario](#8--distribución-dev-desde-fuente-release-como-binario)**
9. **[Errores del grafo y el patrón Coordinator](#9--errores-del-grafo-y-el-patrón-coordinator)**
10. **[Notas de versión (borrador v2.1.0)](#10--notas-de-versión-borrador-v210)**

---

## 1. 🧠 Cómo Funciona el Grafo de Dependencias (Diagrama General)

A diferencia de un *Service Locator* tradicional (donde todo vive revuelto en un diccionario global), **DaggerSwift v2** organiza tus dependencias como un **Grafo Acíclico Dirigido (DAG)** dividido en **3 tipos de nodos** (*Precondición*, *Regla de Negocio* y *Dominio*) y **3 niveles de ciclo de vida en memoria (Scopes)**:

```mermaid
flowchart TD
    subgraph UI_Layer ["1. Capa Presentation (MVVM)"]
        View["SwiftUI View / UIViewController"] --> VM["@Inject ViewModel\n(@MainActor)"]
    end

    subgraph Domain_Layer ["2. Capa Domain (Clean Architecture)"]
        VM -->|"Llama solo a execute()"| UC["@Inject UseCase\n(Encapsula Repositorios - Ley de Demeter)"]
    end

    subgraph Graph_Engine ["3. Evaluación del Grafo DaggerSwift v2"]
        UC -->|"Paso 1: Verifica Candado"| PRE{"🔒 @Precondition\n¿Existe Sesión Válida\nen este País/Flujo?"}
        PRE -->|"❌ NO (nil)"| BLOCK["⛔ Cortocircuito Inmediato\nNo instancia ningún repositorio hijo\n(Devuelve GraphError.unmetPrecondition)"]
        PRE -->|"✅ SÍ"| BIZ{"🔀 @BusinessRule\nEvalúa Flags / Experimentos A/B"}
        BIZ -->|"Variante A"| VAR_A["ClassicLayout / StandardCredit"]
        BIZ -->|"Variante B"| VAR_B["WealthBento / InstantBoost"]
        BIZ -->|"Paso 3: Resuelve Datos"| MOD["📦 @Module Activo\n(Paleta @Scope: 0.1 / 1.0 / 2.0\no País: MX / US / BR / FR)"]
    end

    subgraph Memory_Scopes ["4. Árbol Jerárquico de Memoria (Scopes)"]
        MOD --> S_MOD["Scope de Módulo (@Scoped)\nEj. FintechScope / CountryNewsScope\n💥 Muere al hacer teardownScope() (UnPlug)"]
        S_MOD -->|"parent"| S_SES["Scope de Sesión (@Precondition)\nEj. AuthenticatedCountrySession\n💥 Muere al hacer Logout"]
        S_SES -->|"parent"| S_GLO["GlobalScope (@Singleton)\nEj. AuthRepository / FeatureFlags\n♾️ Vive toda la App"]
    end
```

### ¿Qué ocurre paso a paso cuando pides un componente?
1. **Verificación de `@Precondition` (Cortocircuito):** Si el `UseCase` o `ViewModel` requiere una precondición (como `AuthenticatedCountrySession` o `ValidatedSession`), el grafo evalúa primero esa función. Si devuelve `nil`, **detiene inmediatamente la construcción** sin instanciar un solo objeto del sub-árbol.
2. **Evaluación de `@BusinessRule` (Variantes A/B en caliente):** Si el componente depende de una regla de negocio o experimento A/B, evalúa el estado actual de los flags y entrega la variante correspondiente.
3. **Resolución por Scope (`@Scoped` / `@Singleton` / `@Provider`):**
   - Si es `@Provider`, crea una instancia nueva.
   - Si es `@Scoped`, busca la instancia en la caja del módulo activo (y la registra en `WeakObjectBox` para auditar que no existan *retain cycles* cuando el módulo se cierre).
   - Si es `@Singleton`, sube hasta el `GlobalScope` raíz y reutiliza la instancia única.

---

## 2. 🛠 Manual de Conceptos y Decoradores

### 2.1 ¿Qué es un Módulo (`@Module`)?

#### Definición Conceptual y Arquitectónica
En Clean Architecture, tus capas de **Dominio (`Domain`)** y **Presentación (`Presentation`)** solo conocen **abstracciones** (`Protocols` y `Entities`); jamás deben saber si los datos vienen de un `actor` en memoria, de `URLSession`, de `CoreData` o de un `Fake` de pruebas.

Un **Módulo (`@Module`)** en `DaggerSwift v2` es una **unidad autocontenida de ensamblaje, versión y ciclo de vida de memoria** que vive en la capa `Data / DI` y cumple **3 funciones**:

1. **Recetario Perezoso de Dependencias (*Lazy Factory*):** Declara qué clase o `actor` concreto satisface cada protocolo del Dominio. Registrar un `@Module` tiene **costo cero de memoria al arrancar la app**: no instancia ningún objeto hasta el instante en que un `UseCase` o `ViewModel` lo solicita.
2. **Frontera de Memoria (`GraphScope`):** Todo `@Module` es automáticamente un `GraphScope` con su propio identificador único en tiempo de compilación (`ScopeID`). Los objetos marcados con `@Scoped` dentro de ese módulo nacen cuando el módulo se activa y **se destruyen automáticamente de la memoria RAM** cuando el módulo se desconecta con `teardownScope()`.
3. **Pieza Conectable y Desconectable (*Plug & UnPlug*):** Como un bloque de LEGO, puedes conectar (`Plug`) un módulo completo o desconectarlo (`UnPlug`) para cambiar de país, de versión (`0.1 -> 1.0 -> 2.0`) o de entorno (`Live -> Fake`) sin tocar una sola línea de tus `UseCases`, `ViewModels` o `Views`.

```mermaid
flowchart LR
    subgraph Domain ["Capa Domain (Contratos)"]
        P1["protocol FintechCoreBankingProtocol"]
        P2["protocol FintechCardEngineProtocol"]
    end

    subgraph ModuleBox ["📦 @Module(1.0, scope: FintechScope.self)"]
        M1["1. Recetario Lazy (@Scoped / @Singleton)"]
        M2["2. Caja de Memoria Propia (ScopeID)"]
        M3["3. Metadato de Versión (moduleVersion = '1.0')"]
    end

    subgraph Data ["Capa Data (Implementaciones)"]
        I1["actor FintechBankingActor"]
        I2["struct FintechCardEngineV1"]
    end

    Data -->|"Se registran en"| ModuleBox
    ModuleBox -->|"Satisface sin acoplar"| Domain
```

#### ¿Qué decoradores puedes usar dentro de un `@Module`?

| Decorador dentro de `@Module` | Ciclo de Vida | Cuándo se instancia | Cuándo muere en RAM |
| :--- | :--- | :--- | :--- |
| **`@Singleton`** | `GlobalScope` | *Lazy* (la primera vez que alguien lo pide) | Al cerrar la aplicación. |
| **`@Scoped`** | Scope del `@Module` (o el indicado en `@Module(scope:)`) | *Lazy* al entrar al módulo/flujo | Al llamar a `Module.teardownScope()` o salir de `GraphScopeView`. |
| **`@Scoped(OtroScope.self)`** | Scope explícito (ej. `ValidatedSession.self`) | *Lazy* mientras ese Scope esté activo | Cuando `OtroScope` ejecuta `teardown()`. |
| **`@Provider`** | Transitorio (*Transient*) | Crea una instancia **nueva** en cada resolución | En cuanto el consumidor suelta la referencia ARC. |
| **`@BusinessRule`** | Dinámico por evaluación | Se re-evalúa al consultar la regla/flag | No se cachea; entrega la variante activa al momento. |
| **`@Precondition("Razón")`** | Candado de Sub-Grafo | Se evalúa **antes** que cualquier nodo que dependa de ella | Si devuelve `nil`, aborta la resolución con `unmetPrecondition`. |

#### ¿Qué genera el macro `@Module` por debajo?

Cuando escribes un módulo declarativo:

```swift
@Module(1.0, scope: CountryNewsScope.self)
public enum MexicoNewsModule: CountryNewsModuleContract {
    @Precondition("Se requiere sesión activa en México (🇲🇽)")
    public static func validateSession(auth: any CountryAuthRepositoryProtocol) -> AuthenticatedCountrySession? {
        auth.session(for: .mexico)
    }

    @Scoped
    public static func localeProvider() -> any CountryLocaleProviderProtocol { MexicoLocaleProvider() }

    @Scoped
    public static func newsRepository() -> any CountryNewsRepositoryProtocol { MexicoNewsRepository() }
}
```

El Compiler Plugin de `DaggerSwift` expande automáticamente la conformidad a `GraphScope`, `GraphModule` y `Modulable`, generando el registro tipado en el grafo:

```swift
// Generado automáticamente en tiempo de compilación:
extension MexicoNewsModule: DaggerSwift.GraphScope, DaggerSwift.GraphModule, DaggerSwift.Modulable {
    nonisolated public static let moduleVersion: String = "1.0"

    nonisolated public static func register(in container: DaggerSwift.ScopeContainer) {
        container.addCompatibleScope(CountryNewsScope.self)
        container.providePrecondition(AuthenticatedCountrySession.self, reasonIfUnmet: "Se requiere sesión activa en México (🇲🇽)") { (auth: any CountryAuthRepositoryProtocol) in
            Self.validateSession(auth: auth)
        }
        container.provideScoped(in: CountryNewsScope.self, (any CountryLocaleProviderProtocol).self) {
            Self.localeProvider()
        }
        container.provideScoped(in: CountryNewsScope.self, (any CountryNewsRepositoryProtocol).self) {
            Self.newsRepository()
        }
    }
}
```

---

### 2.2 ¿Qué es una Variante y cómo se modela? (Los 3 Tipos de Variantes)

#### ¿Qué es una Variante?
Una **Variante** es una configuración alternativa de un mismo flujo o capacidad del producto que **cumple exactamente el mismo contrato de Dominio**, permitiendo que la aplicación cambie sus implementaciones sin que el `UseCase`, el `ViewModel` ni la `View` se enteren.

En aplicaciones reales existen **3 dimensiones de variación**, y cada una se modela de forma distinta en `DaggerSwift v2`:

| Tipo de Variante | Caso de Uso Real | ¿Hereda código de otra variante? | Mecanismo en `DaggerSwift v2` |
| :--- | :--- | :--- | :--- |
| **1. Variante Horizontal (Hermana)** | Multi-Country (`🇲🇽 MX`, `🇺🇸 US`, `🇧🇷 BR`, `🇫🇷 FR`) | **No.** Cada país provee sus propias implementaciones independientes bajo el mismo contrato. | `@Module(1.0, scope: SharedScope.self)` + `ModuleContract` |
| **2. Variante Vertical (Evolución `0.1 -> 1.0 -> 2.0` o `Fake`)** | Evolución de un producto en el tiempo o reemplazo parcial en Tests | **Sí.** Conserva todos los proveedores del módulo base y **solo declara la función que cambió**. | `@Module(2.0, includes: [BaseModule.self])` + `@Scope` Palette |
| **3. Variante Dinámica A/B (`@BusinessRule`)** | Feature Flags y Experimentos A/B en tiempo real | Conmuta en caliente entre Variante A y Variante B según el estado de un Flag. | `@BusinessRule` dentro del `@Module` |

```mermaid
flowchart TB
    subgraph V_Hor ["1. Variantes Horizontales (Hermanas: Cero Herencia, Mismo Contrato)"]
        direction LR
        ContractH["CountryNewsModuleContract\n(validateSession + localeProvider + newsRepository)"]
        ContractH --> MX["🇲🇽 MexicoNewsModule\n(Implementa las 3 para MX)"]
        ContractH --> US["🇺🇸 USANewsModule\n(Implementa las 3 para US)"]
        ContractH --> BR["🇧🇷 BrazilNewsModule\n(Implementa las 3 para BR)"]
        ContractH --> FR["🇫🇷 FranceNewsModule\n(Implementa las 3 para FR)"]
    end

    subgraph V_Ver ["2. Variantes Verticales (Evolución con Herencia Real: Solo escribes lo que cambia)"]
        direction LR
        V01["@Module(0.1) FintechModuleV0_1\n✅ Implementa coreBanking()\n✅ Implementa cardEngine() (V0.1)"]
        V10["@Module(1.0, includes: [V0_1])\nFintechModuleV1\n🔹 Hereda coreBanking()\n✏️ SOLO implementa cardEngine() (V1.0)"]
        V20["@Module(2.0, includes: [V1])\nFintechModuleV2\n🔹 Hereda coreBanking()\n✏️ SOLO implementa cardEngine() (Metal V2)"]
        V01 -->|"Hereda"| V10 -->|"Hereda"| V20
    end
```

---

#### Detalle 1: Variantes Horizontales (Variantes Hermanas / Multi-Country)
Cuando lanzas la misma Feature en **México, USA, Brasil y Francia**, ninguna variante es "hija" de otra: México no hereda las noticias ni la sesión de USA. Son **módulos hermanos** que viven al mismo nivel jerárquico:

1. Comparten el mismo `scope: CountryNewsScope.self` para que el `GetLocalizedNewsFeedUseCase` (`@Inject(scope: CountryNewsScope.self)`) funcione con cualquiera de ellos.
2. Conforman el mismo contrato `CountryNewsModuleContract`, por lo que el compilador te garantiza que ningún país quede incompleto.
3. Al cambiar de país en la UI (`CountryNewsScope.module(for: country)`), haces `previousModule.teardownScope()` (*UnPlug*) y conectas el nuevo país (*Plug*).

---

#### Detalle 2: Variantes Verticales (Evolución `0.1 -> 1.0 -> 2.0` con Herencia Real — *Solo implementas lo que cambia*)

Cuando un producto evoluciona de la versión `0.1` a la `1.0` y luego a la `2.0` (o cuando creas un módulo `Fake` para pruebas), **no quieres volver a escribir los proveedores que no cambiaron**.

En `DaggerSwift v2`, al usar **`includes: [ModuloAnterior.self]`** junto con el contrato base:
- En el **Módulo Base (`0.1`)** implementas todos los proveedores iniciales (`coreBanking()` y `cardEngine()`).
- En los **Módulos Evolucionados (`1.0` y `2.0`)** **SOLO escribes la función que evolucionó** (`cardEngine()`). Todo lo demás (`coreBanking()`) se hereda automáticamente sin re-escribirlo:

```swift
// 1. Contrato en Domain:
public protocol FintechModuleContract: GraphModule {
    static func coreBanking() -> any FintechCoreBankingProtocol
    static func cardEngine() -> any FintechCardEngineProtocol
}

// 2. Módulo Base 0.1 (MVP): Implementa todos los proveedores base
@Module(0.1, scope: FintechScope.self)
public enum FintechModuleV0_1: FintechModuleContract {
    @Scoped
    public static func coreBanking() -> any FintechCoreBankingProtocol {
        FintechCoreBankingImpl()
    }

    @Scoped
    public static func cardEngine() -> any FintechCardEngineProtocol {
        FintechCardEngineV0_1()
    }
}

// Default del contrato hacia la base 0.1 para herencia estática en compile-time:
public extension FintechModuleContract {
    static func coreBanking() -> any FintechCoreBankingProtocol {
        FintechModuleV0_1.coreBanking()
    }
}

// 3. Evolución 1.0: Hereda `coreBanking()` de V0_1 y SOLO implementa `cardEngine()`
@Module(1.0, scope: FintechScope.self, includes: [FintechModuleV0_1.self])
public enum FintechModuleV1: FintechModuleContract {
    @Scoped
    public static func cardEngine() -> any FintechCardEngineProtocol {
        FintechCardEngineV1()
    }
}

// 4. Evolución 2.0: Hereda `coreBanking()` y SOLO implementa `cardEngine()` (Metal V2)
@Module(2.0, scope: FintechScope.self, includes: [FintechModuleV1.self])
public enum FintechModuleV2: FintechModuleContract {
    @Scoped
    public static func cardEngine() -> any FintechCardEngineProtocol {
        FintechCardEngineV2()
    }
}
```

Lo mismo ocurre en [`ServiceModules.swift`](./Sources/SampleProyect/Sources/Services/ServiceModules.swift) y en [`AppUnitTests.swift`](./Sources/SampleProyect/Tests/AppUnitTests/AppUnitTests.swift):
- `LiveGitHubModule` (`1.0`) provee `gitHubRepository()`, `authRepository()` y `featureFlags()`.
- `LiveGitHubModuleV2` (`@Module(2.0, includes: [LiveGitHubModule.self])`) **solo implementa `authRepository()`** (OAuth V2) y hereda automáticamente `gitHubRepository()` y `featureFlags()`.
- `FakerGitHubModule` (`@Module(includes: [LiveGitHubModule.self])`) en los tests **solo implementa `gitHubRepository()`** (con datos Fake) y hereda el resto del módulo de producción.

##### Paleta `@Scope` (Estilo `CodingKeys` para Evolución `0.1 / 1.0 / 2.0`):
Para no escribir `enum`s ni `switch` manuales al cambiar entre versiones `0.1`, `1.0` y `2.0`, el macro **`@Scope`** genera en tiempo de compilación el tipo `FintechScope.Palette` (`ModulePalette`) y el método estático `FintechScope.module(for:)`:

```swift
@Scope(
    of: (any FintechModuleContract).self,
    v0_1: FintechModuleV0_1.self,
    v1_0: FintechModuleV1.self,
    v2_0: FintechModuleV2.self
)
extension FintechScope {}

// Selecciona en tiempo de compilación la versión de la paleta (.v0_1, .v1_0 o .v2_0):
let module = FintechScope.module(for: .v2_0)
```

---

#### Detalle 3: Variantes Dinámicas / Experimentos A/B (`@BusinessRule`)
Cuando la variante no depende del país ni de la versión del módulo, sino de un **Feature Flag o Experimento A/B en tiempo real**, declaras un nodo `@BusinessRule`.

El grafo inyecta automáticamente el repositorio de banderas (`FintechABFlagsRepositoryProtocol`) en la función `@BusinessRule` y evalúa qué variante entregar sin ensuciar el `UseCase` ni el `ViewModel` con `if/else` de banderas:

```swift
@Module(1.0)
public enum FintechCoreModule {
    @BusinessRule
    public static func provideHomeLayoutVariant(
        flags: any FintechABFlagsRepositoryProtocol
    ) -> any FintechHomeLayoutVariantProtocol {
        flags.isWealthBentoVariantB ? WealthBentoLayoutVariant() : ClassicBalanceLayoutVariant()
    }

    @BusinessRule
    public static func provideCreditOfferVariant(
        flags: any FintechABFlagsRepositoryProtocol
    ) -> any FintechCreditOfferVariantProtocol {
        flags.isInstantCreditBoostVariantB ? InstantBoostCreditOfferVariant() : StandardCreditOfferVariant()
    }
}
```

---

### 2.3 ¿Cómo funciona `@Inject` y `@Inject(scope:)` por dentro?

En otras librerías tienes que ensuciar tus propiedades con `@Injected var repo: Repo` (lo cual mete un *Service Locator* oculto dentro de tu clase) o escribir inicializadores boilerplate interminables.

En **DaggerSwift v2**, colocas `@Inject` arriba de tu `struct` o `class`:

```swift
// Lo único que tú escribes en Domain:
@Inject
public struct GetProfileUseCase: Sendable {
    let gitHubRepository: any GitHubRepositoryProtocol

    public func execute(username: String = "fsaldivar-dev") async throws -> GitHubUserProfile {
        try await gitHubRepository.fetchProfile(username: username)
    }
}
```

#### ¿Qué expande automáticamente el macro `@Inject` en tiempo de compilación?

```swift
// Generado automáticamente por DaggerSwiftMacrosPlugin:
extension GetProfileUseCase: DaggerSwift.Injectable {
    // 1. Inicializador explícito 100% puro (para resolución en compile-time y Unit Tests sin grafo):
    public init(gitHubRepository: any GitHubRepositoryProtocol) {
        self.gitHubRepository = gitHubRepository
    }

    // 2. Inicializador desde el contenedor DAG:
    public init(from container: DaggerSwift.ScopeContainer) throws {
        self.init(gitHubRepository: try container.resolve((any GitHubRepositoryProtocol).self))
    }

    // 3. Auto-registro Just-In-Time (no necesitas registrarlo manualmente en ningún @Module):
    nonisolated public static func register(in container: DaggerSwift.ScopeContainer) {
        container.provide(Self.self) { (gitHubRepository: any GitHubRepositoryProtocol) in
            Self(gitHubRepository: gitHubRepository)
        }
    }
}
```

> **💡 Regla inteligente con `@Published` y `@State`:** Si aplicas `@MainActor @Inject` a un `ViewModel` de SwiftUI, el macro detecta automáticamente qué propiedades son dependencias (`let useCase: MyUseCase`) y **excluye** del `init` las propiedades `@Published`, `@State` o con valor por defecto (`= []`).

---

### 2.4 ¿Qué es una `@Precondition` (Candado de Estado / Sesión por País)?

Una **`@Precondition`** es un tipo que conforma el protocolo `Precondition` (por ejemplo, `AuthenticatedCountrySession` o `ValidatedSession`) y representa un **requisito obligatorio de estado** para que un sub-grafo pueda existir.

1. Declaras el modelo de tu precondición en `Domain`:
   ```swift
   public struct AuthenticatedCountrySession: Precondition, Sendable, Equatable {
       public let country: SupportedCountry
       public let userIdentifier: String
       public let sessionToken: String
   }
   ```
2. Tu `UseCase` la pide como parámetro en su estructura `@Inject`:
   ```swift
   @Inject(scope: CountryNewsScope.self)
   public struct GetLocalizedNewsFeedUseCase: Sendable {
       public let session: AuthenticatedCountrySession // <- Exige la @Precondition
       let localeProvider: any CountryLocaleProviderProtocol
       let newsRepository: any CountryNewsRepositoryProtocol
   }
   ```
3. Tu `@Module` declara cómo validar esa precondición con `@Precondition("...")` devolviendo un opcional (`AuthenticatedCountrySession?`):
   - Si devuelve `nil` (por ejemplo, el usuario inició sesión en **🇲🇽 México** pero intenta abrir las noticias de **🇺🇸 USA**), **el grafo bloquea el acceso** antes de tocar `USANewsRepository`.

---

### 2.5 Ciclo de Vida, Memoria y `Plug & UnPlug` (`teardownScope()`)

Cuando cambias de un módulo a otro en caliente (por ejemplo, de `MexicoNewsModule` a `FranceNewsModule`, o de `FintechModuleV1` a `FintechModuleV2`), aplicas el patrón **Plug & UnPlug**:

```swift
public func selectPalette(_ option: FintechScope.Palette) {
    // 1. UNPLUG: Desconecta el módulo anterior y libera todas sus instancias @Scoped de RAM
    let previousModule = FintechScope.module(for: selectedPalette)
    let leakedClasses = previousModule.teardownScope()
    assert(leakedClasses.isEmpty, "Se detectó un retain cycle en: \(leakedClasses)")

    // 2. PLUG: Conecta el nuevo módulo de la paleta (0.1, 1.0 o 2.0)
    selectedPalette = option
    Task { await reloadFromActiveModule() }
}
```

Si una clase `@Scoped` necesita cancelar un `Task`, cerrar un WebSocket o limpiar un `Timer` cuando su módulo se desconecta, simplemente conforma **`ScopeDisposable`**:

```swift
@Inject(scope: RepoDetailModule.self)
public final class RepoDetailInspector: ScopeDisposable, Sendable {
    public let session: ValidatedSession

    public func onScopeTeardown() {
        // Se ejecuta automáticamente en el instante en que se llama a RepoDetailModule.teardownScope()
    }
}
```

---

### 2.6 Fronteras de la Librería: Solo una Pieza del Rompecabezas (DI vs. App Lifecycle vs. Coordinator)

Un error muy común en la industria es pretender que una librería de Inyección de Dependencias resuelva **toda la arquitectura de la aplicación**. Para mantener Clean Architecture estricta y alta cohesión, `DaggerSwift v2` asume con honestidad sus fronteras: **solo resuelve una pieza del rompecabezas**.

```text
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                   🧩 EL ROMPECABEZAS DE UNA APLICACIÓN ENTERPRISE                      │
├────────────────────────────┬───────────────────────────────────────────────────────────┤
│ 1. DaggerSwift v2 (DI)     │ ✅ Memoria, Grafos, Scopes (@Scoped), Contratos y @Preconditions │
│ 2. RootComposer (Factory)  │ 🏭 Ensamblaje de Vistas + ViewModels sin Singletons               │
│ 3. AppCoordinator (Flows)  │ 🧭 Máquina de Estados de Navegación, Modales y Deep Links         │
│ 4. AppEventsBus (Reactive) │ 📡 AsyncStreams y Eventos Desacoplados (Login, Logout, Sync)      │
└────────────────────────────┴───────────────────────────────────────────────────────────┘
```

#### Los 4 Fallos Comunes en la Industria (Que ocurren si no separas estas capas)

Sin esta delimitación rigurosa de responsabilidades, las aplicaciones iOS/macOS caen sistemáticamente en estos 4 antipatrones:

1. **💥 El Crash del Deep Link Huérfano:**
   - *El error:* Un Deep Link externo abre directamente una pantalla privada (`app://loans/apply` o `app://banking/transfer`). El `ViewModel` o `UseCase` asume que `session!` o `user.token!` existen y la app crashea en producción si el usuario no estaba autenticado.
   - *Cómo ayuda DaggerSwift:* `@Precondition` evalúa la sesión en la raíz del sub-grafo y **bloquea la construcción antes de tocar la red** (`allocations == 0`), devolviendo un error tipado explícito (`GraphError.unmetPrecondition`).
2. **🐘 El Monolito del Inyector Todopoderoso:**
   - *El error:* Forzar al framework de DI a ser Router, Navigation Manager y State Machine, guardando referencias a `UINavigationController` o ventanas de SwiftUI dentro del contenedor.
   - *La postura de DaggerSwift:* **Cero UI.** El motor de dependencias jamás debe saber qué es un `NavigationStack`, un `sheet` o un modal.
3. **🍝 Acoplamiento Espagueti entre Pantallas:**
   - *El error:* Que la pantalla de Login tenga que saber a dónde ir después:
     ```swift
     // ❌ Antipatrón: Login acoplado a toda la app
     if cameFromLoans { navigateToLoans() }
     else if cameFromProfile { navigateToProfile() }
     ```
   - *La solución limpia:* El módulo de Login **jamás conoce a los demás módulos**. Solo emite un evento desacoplado `AppEvent.userAuthenticated(session)`. Quien decide qué hacer es el `AppCoordinator`.
4. **🧟 Fuga de Estado Zombie al hacer Logout (*Captive Session Bug*):**
   - *El error:* Al cerrar sesión, los ViewModels o Repositorios viejos siguen vivos en diccionarios estáticos globales. Si otro usuario se loguea en el mismo teléfono, ve el saldo o las tarjetas del usuario anterior.
   - *Cómo lo resuelve DaggerSwift:* Cada flujo vive en un `GraphScope` aislado. Al hacer logout se ejecuta `teardownScope()`, vaciando la memoria y auditando con `WeakObjectBox` que no quede ningún retain cycle.

---

#### El Flujo Canónico Completo: ¿Quién resuelve lo que falta?

Si intentas abrir `LoansFeatureView` mediante un Deep Link cuando la sesión no existe, **el Scope no puede ni debe resolver la sesión solo** (obtener credenciales requiere interacción humana de UI). 

La colaboración armónica entre las 4 capas se orquesta así:

```mermaid
sequenceDiagram
    autonumber
    participant OS as Sistema / DeepLink
    participant Coord as AppCoordinator (Navegación / Flujos)
    participant Comp as RootComposer (Ensamblador de Pantallas)
    participant Dagger as DaggerSwift v2 (Scopes & Preconditions)
    participant Events as AppEventsBus (AsyncSequence / Events)
    participant Login as LoginFlowView (Feature UI)
    participant Loans as LoansFeatureView (Feature UI)

    OS->>Coord: Abre DeepLink ("app://loans/apply")
    Note over Coord: El Coordinator intenta navegar al flujo de Préstamos
    Coord->>Comp: Pide ensamblar LoansFeatureView
    Comp->>Dagger: Intenta resolver GetLoansDashboardUseCase
    Note over Dagger: Evalúa @Precondition(AuthenticatedCountrySession)
    Dagger-->>Comp: Cortocircuito: GraphError.unmetPrecondition(AuthenticatedCountrySession.self)
    Comp-->>Coord: Error Explícito: .requiresPrerequisite(AuthenticatedCountrySession.self)

    Note over Coord: ¡El Coordinator toma el control del flujo UI!
    Coord->>Events: Se suscribe a AppEvent.userAuthenticated
    Coord->>Login: Presenta modal interactivo de Login

    Note over Login: Usuario ingresa credenciales o FaceID
    Login->>Events: Emite AppEvent.userAuthenticated(session)

    Note over Coord: AppCoordinator recibe el evento de éxito
    Coord->>Login: Cierra modal de Login
    Coord->>Dagger: Alimenta SessionScope con la nueva sesión (Plug)
    Coord->>Comp: Reintenta ensamblar LoansFeatureView (¡Ahora sí cumple @Precondition!)
    Comp->>Dagger: Resuelve dependencias con éxito (allocations > 0)
    Comp-->>Coord: Devuelve LoansFeatureView lista
    Coord->>Loans: Navega a LoansFeatureView
```

---

#### Ejemplo de Código: Separación por Capas en Swift 6

##### 1. Capa de Eventos Reactivos (`AppEventsBus`)
```swift
public enum AppEvent: Sendable {
    case userAuthenticated(AuthenticatedCountrySession)
    case userLoggedOut
}

public actor AppEventsBus {
    public static let shared = AppEventsBus()
    private var continuations: [UUID: AsyncStream<AppEvent>.Continuation] = [:]

    public func subscribe() -> AsyncStream<AppEvent> {
        let id = UUID()
        return AsyncStream { continuation in
            continuation.onTermination = { [weak self] _ in
                Task { await self?.remove(id) }
            }
            self.continuations[id] = continuation
        }
    }

    public func emit(_ event: AppEvent) {
        for continuation in continuations.values {
            continuation.yield(event)
        }
    }

    private func remove(_ id: UUID) { continuations.removeValue(forKey: id) }
}
```

##### 2. Capa de Ensamblaje (`RootComposer` - Composition Root)
```swift
@MainActor
public enum RootComposer {
    public enum AssemblyResult {
        case success(AnyView)
        case requiresPrerequisite(Any.Type, retry: () -> AnyView)
    }

    public static func makeLoansFeature() -> AssemblyResult {
        // Intenta resolver con DaggerSwift:
        do {
            let useCase = try FintechScope.resolve(GetLoansDashboardUseCase.self)
            let viewModel = LoansViewModel(useCase: useCase)
            return .success(AnyView(LoansFeatureView(viewModel: viewModel)))
        } catch let GraphError.unmetPrecondition(type, _) {
            // Traduce el error de memoria a una intención de navegación:
            return .requiresPrerequisite(AuthenticatedCountrySession.self) {
                // Closure de reintento una vez que la sesión esté satisfecha
                let useCase = try! FintechScope.resolve(GetLoansDashboardUseCase.self)
                return AnyView(LoansFeatureView(viewModel: LoansViewModel(useCase: useCase)))
            }
        } catch {
            fatalError("Error irrecuperable: \(error)")
        }
    }
}
```

##### 3. Capa de Navegación y Flujos (`AppCoordinator`)
```swift
@MainActor
@Observable
public final class AppCoordinator {
    public var currentView: AnyView?
    public var presentedModal: AnyView?

    public func handleDeepLink(_ url: URL) {
        if url.path == "/loans/apply" {
            switch RootComposer.makeLoansFeature() {
            case .success(let view):
                self.currentView = view
            case .requiresPrerequisite(let prerequisite, let retryClosure):
                if prerequisite == AuthenticatedCountrySession.self {
                    // 1. Abre el modal de Login:
                    self.presentedModal = AnyView(LoginFeatureView())
                    // 2. Escucha el evento de login exitoso para reanudar el flujo:
                    Task {
                        for await event in await AppEventsBus.shared.subscribe() {
                            if case .userAuthenticated(let session) = event {
                                self.presentedModal = nil
                                self.currentView = retryClosure()
                                break
                            }
                        }
                    }
                }
            }
        }
    }
}
```

* **Independencia Total:** `LoginFeatureView` jamás conoce a `LoansFeatureView`.
* **Pureza de `Domain`:** Tu capa de dominio no sabe de routers, ventanas ni eventos de UI.
* **Separación de Responsabilidades:** `DaggerSwift` gestiona la **memoria y las dependencias**, `RootComposer` **ensambla**, `AppCoordinator` **navega**, y `AppEventsBus` **comunica**.

---

### 2.7 Pureza en la UI: Inmunidad al Vendor Lock-In, Previews Nativas y Taxonomía de Estados

Un principio no negociable en Clean Architecture es que **la capa de presentación (UI) jamás debe acoplarse a un framework de Inyección de Dependencias**.

#### 1. La Regla de Oro: Las Vistas NO hacen `import DaggerSwift`

Tentar al desarrollador con modificadores como `.daggerScope(MyScope.self)` o `.daggerPreview(...)` dentro de las vistas de SwiftUI es un **antipatrón grave**:
* **Acoplamiento Directo (Vendor Lock-In):** Si la librería de DI se rompe, se depreca o se sustituye en el futuro, tendrías que modificar o reescribir **cada una de las vistas** de la aplicación.
* **Invasión de Responsabilidades:** Una vista de SwiftUI solo debe saber cómo renderizar su estado y emitir eventos de interacción. Jamás debe gestionar el ciclo de vida de un contenedor de memoria.

> [!IMPORTANT]
> **En DaggerSwift v2:** Los archivos de vistas (`*View.swift`) **nunca importan `DaggerSwift`**. Solo usan constructores de Swift puro (`init(viewModel:)` o `init(useCase:)`).

#### 2. Previews Nativas de SwiftUI en Milisegundos

Al usar inyección por constructor estándar, las Previews de Xcode compilan y renderizan de forma **100% nativa**, sin inicializar contenedores, sin `@TaskLocal` y sin overrides globales:

```swift
// LoansFeatureView.swift
// ⚠️ Observa: ¡CERO imports de DaggerSwift!
import SwiftUI

public struct LoansFeatureView: View {
    @State private var viewModel: LoansViewModel

    public init(viewModel: LoansViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        VStack(spacing: 16) {
            Text("Saldo Disponible: $\(viewModel.balance)")
            Button("Solicitar Crédito") {
                viewModel.applyForLoan()
            }
        }
    }
}

// ✅ Previews nativas con Mocks por constructor:
#Preview("Usuario con Préstamo Activo") {
    LoansFeatureView(viewModel: LoansViewModel(
        useCase: MockLoansUseCase(balance: 15_000)
    ))
}

#Preview("Usuario Sin Préstamos") {
    LoansFeatureView(viewModel: LoansViewModel(
        useCase: MockLoansUseCase(balance: 0)
    ))
}
```

#### 3. El Ciclo de Vida del Scope Pertenece al `AppCoordinator`, No a la Vista

¿Por qué no usamos un cache débil automático (`@WeakShared` o `.shared` de Factory)?
* **Limitación Técnica de Swift:** Los caches débiles (`weak`) **solo funcionan con clases (`class: AnyObject`)**. Fallan rotundamente con tipos por valor (`struct`), tuplas o `actor`.
* **Riesgo Crítico de Pérdida de Estado:** En transiciones de navegación entre pantallas secundarias, si durante 1 frame o milisegundo ninguna vista retiene el servicio, **ARC purga la instancia débil**, perdiendo el estado en memoria de forma silenciosa e impredecible.
* **Control Determinístico:** El ciclo de vida de un scope (`teardownScope()`) no debe dejarse al azar del recolector de basura. El `AppCoordinator` abre el scope cuando entra al flujo y lo destruye de forma explícita y auditada al terminar el flujo.

```swift
// LoansCoordinator.swift
@MainActor
public final class LoansCoordinator {
    public var currentSheet: AnyView?

    public func finishLoansFlow() {
        // 1. Cierra la pantalla en la UI:
        self.currentSheet = nil
        
        // 2. Destruye el Scope de Memoria (Solo el Coordinator conoce el Scope):
        let leaks = FintechScope.teardownScope()
        assert(leaks.isEmpty, "Fuga detectada al salir de Loans: \(leaks)")
    }
}
```

#### 4. Taxonomía de Estados (`States`) y sus Fronteras Reales

Para no mezclar el estado de la UI con el estado del negocio ni con las dependencias:

| Tipo de Estado | ¿Dónde vive en RAM? | ¿Quién lo gestiona? | ¿Conoce `DaggerSwift`? |
| :--- | :--- | :--- | :---: |
| **1. UI State** | `@State`, `@FocusState` | La Vista de SwiftUI | ❌ **No**. Swift nativo efímero. |
| **2. Feature State** | `@Observable ViewModel` | La Vista lo retiene, el `RootComposer` lo ensambla | ❌ **No**. Recibe UseCases en su `init`. |
| **3. Session State** | `UserSession`, `AuthTokens` | En el Grafo (`@Scoped`) con `@Precondition` | ✅ **Sí** (`SessionScope`). Muere al Logout. |
| **4. Global State** | Remote Config, Theme, Network | En el Grafo (`@Singleton`) | ✅ **Sí** (`GlobalScope`). Vive con la App. |

---

## 3. 🧪 Manual Completo de Pruebas (`DaggerSwiftTesting` + Unit Tests + Linter)

DaggerSwift v2 está diseñado para probar tu aplicación en **3 niveles complementarios**:

### 3.1 Nivel 1: Pruebas Unitarias Puras (Sin Grafo)

Gracias a que `@Inject` genera un `public init(...)` estándar y limpio, tus pruebas unitarias en [`AppUnitTests.swift`](./Sources/SampleProyect/Tests/AppUnitTests/AppUnitTests.swift) **no necesitan inicializar ningún contenedor de DI**:

```swift
import Testing
import Core

@Test("GetProfileUseCase obtiene el perfil de @fsaldivar-dev")
func testObtenerPerfil() async throws {
    // 1. Instancias tu UseCase directamente pasando un Fake por constructor:
    let useCase = GetProfileUseCase(gitHubRepository: FakerGitHubRepository())
    let profile = try await useCase.execute()

    #expect(profile.login == "fsaldivar-dev")
}

@Test("FeedViewModel filtra repositorios conectando un FakeModule con Plug & UnPlug")
@MainActor
func testFeedViewModelConFakeModule() async {
    // 2. O conectas un @Module Fake completo en 1 línea:
    let viewModel = FeedViewModel.plug(FakerGitHubModule.self)
    await viewModel.loadInitialData()
    viewModel.searchText = "AutoPilot"

    #expect(viewModel.filteredRepositories.count == 1)
}
```

---

### 3.2 Nivel 2: Pruebas del Grafo de Dependencias (`expectGraph` DSL)

El target **`DaggerSwiftTesting`** incluye un DSL declarativo ([`AppGraphTests.swift`](./Sources/SampleProyect/Tests/AppGraphTests/AppGraphTests.swift)) para auditar tu grafo de dependencias completo en milisegundos sin levantar simuladores ni vistas:

#### A. Validar que un grafo resuelve todos sus componentes y cumple el contrato de otro módulo
```swift
import Testing
import DaggerSwiftTesting

@Test("El módulo V2 y el módulo Fake cumplen exactamente el contrato de V1")
func testContratoYResolucion() {
    expectGraph(ShowcaseCoreModule.self, FakerGitHubModule.self)
        .matchesContract(of: LiveGitHubModule.self) // Verifica que provea exactamente los mismos tipos
        .resolved((any GitHubRepositoryProtocol).self)
        .resolved(GetProfileUseCase.self)
        .resolved(FeedViewModel.self)
}
```

#### B. Reemplazar una dependencia al vuelo con un Fake (`whenResolved(...).returns(...)`)
```swift
@Test("Inyectar un Fake al vuelo sobre el grafo de producción")
func testOverrideAlVuelo() {
    expectGraph(ShowcaseCoreModule.self, LiveGitHubModule.self)
        .whenResolved((any GitHubRepositoryProtocol).self).returns(FakerGitHubRepository.self)
        .resolved(FeedViewModel.self)
}
```

#### C. Probar candados `@Precondition` y aislamiento por País (`.preconditionFailure()` + `.when`)
```swift
@Test("Iniciar sesión en México desbloquea México, pero USA sigue bloqueado por @Precondition")
func testAislamientoPorPais() {
    // 1. Si el usuario se loguea en México, intentar resolver USA falla con preconditionFailure()
    expectGraph(CountryAuthServiceModule.self, USANewsModule.self)
        .when { (auth: any CountryAuthRepositoryProtocol) in
            auth.login(identifier: "+52 55 8421 0900", country: .mexico)
        }
        .dependency(GetLocalizedNewsFeedUseCase.self).preconditionFailure()
        // 2. Al autenticarse en USA, la precondición de USANewsModule se libera:
        .when { (auth: any CountryAuthRepositoryProtocol) in
            auth.login(identifier: "+1 415 890 4210", country: .usa)
        }
        .dependency(GetLocalizedNewsFeedUseCase.self).resolved {
            $0.copy.languageCode == "en-US"
        }
}
```

#### D. Probar el cambio dinámico de `@BusinessRule` (Experimentos A/B)
```swift
@Test("Conmutar flags A/B en vivo actualiza las variantes entregadas por el grafo")
func testBusinessRulesAB() {
    expectGraph(FintechCoreModule.self, FintechSharedFlagsModule.self, FintechModuleV2.self)
        .dependency(GetFintechDashboardUseCase.self).resolved {
            $0.cardProduct.moduleVersionTag.contains("Module(2.0)") &&
            $0.layoutVariant.variantCode == "B" &&
            $0.creditOfferVariant.experimentCode == "Exp-B"
        }
        .when { (flags: any FintechABFlagsRepositoryProtocol) in
            flags.setWealthBentoVariantB(false)
            flags.setInstantCreditBoostVariantB(false)
        }
        .dependency(GetFintechDashboardUseCase.self).resolved {
            $0.layoutVariant.variantCode == "A" &&
            $0.creditOfferVariant.experimentCode == "Control-A"
        }
}
```

#### E. Detectar dependencias faltantes (`.unresolvedFailure()`)
```swift
@Test("Si falta el módulo de servicios, el grafo reporta unresolvedFailure()")
func testModuloFaltante() {
    expectGraph(ShowcaseCoreModule.self)
        .dependency(GetProfileUseCase.self).unresolvedFailure()
}
```

---

### 3.3 Nivel 3: Linter Automático de Arquitectura y SOLID

En [`ArchitectureLinterTests.swift`](./Sources/SampleProyect/Tests/AppGraphTests/ArchitectureLinterTests.swift) incluimos un **Linter de Arquitectura en Swift** que escanea todo el código fuente de `SampleProyect` en cada `swift test` y falla si alguien rompe cualquiera de estas **7 reglas**:

1. **`[RULE-01]` División por Capas:** Exige las carpetas `Domain/Entities`, `Domain/Repositories`, `Domain/UseCases`, `Data/Repositories`, `Data/DI`, `Presentation/View`, `Presentation/ViewModel` y prohíbe `*Composer.swift` manuales.
2. **`[RULE-02]` Pureza de `Domain`:** Prohíbe `import SwiftUI` o referencias a `*Impl`, `*Actor` o `Live*` dentro de `Domain/`.
3. **`[RULE-03]` SOLID en `UseCases` + Ley de Demeter:** Exige `@Inject`, `func execute(...)` y prohíbe exponer los repositorios como `public let`.
4. **`[RULE-04]` UnCoupling en `Presentation`:** Prohíbe que `View` o `ViewModel` instancien tipos de `Data` o atraviesen un `UseCase` para llamar a un repositorio.
5. **`[RULE-05]` Plug & UnPlug:** Exige `@Module` en `DI/` y `teardownScope()` en cada `ViewModel`.
6. **`[RULE-06]` Seguridad & Swift 6 Concurrency:** Prohíbe `try!`, `try?`, `ScopeContainer`, `NSLock` y `@unchecked Sendable` en la app.
7. **`[RULE-07]` Simplicidad de Lectura:** Ningún archivo de ejemplo supera las **180 líneas**.

---

## 4. 🥊 Debate Empírico y Benchmarks Reales (`DaggerSwift` vs `Point-Free TCA` vs `Factory` vs `Swinject`)

Para mantener el paquete principal `DaggerSwift` con **0 dependencias externas**, los benchmarks y el debate contra las librerías reales del ecosistema viven en un **paquete SPM dedicado e independiente**: [`Benchmarks/Package.swift`](./Benchmarks/Package.swift).

Ese paquete descarga e importa las versiones oficiales de:
- **[`pointfreeco/swift-dependencies`](https://github.com/pointfreeco/swift-dependencies)** (la librería de DI de **TCA / The Composable Architecture**)
- **[`hmlongco/Factory`](https://github.com/hmlongco/Factory)** (`Container` + `@Injected`)
- **[`Swinject/Swinject`](https://github.com/Swinject/Swinject)** (`Swinject.Container`)
- **`DaggerSwift`** (Modo Explícito Compile-Time y Modo Motor DAG `ScopeContainer`)

```bash
# Ejecutar el debate cara a cara contra las librerías reales (10 tests empíricos):
swift test --package-path Benchmarks
```

### 4.1 Gráfico Visual de Rendimiento (10,000 Resoluciones Reales en Apple Silicon)

Medido en release (M-series, Swift 6.3.3) con el motor actual:

```text
  1. DaggerSwift Explícito (@Module/@Scope) |   0.27 ms (  1.0x)   ← ver advertencia
  2. Point-Free swift-dependencies (TCA)    |   3.82 ms ( 14.0x)
  3. DaggerSwift Motor DAG (ScopeContainer) |   7.95 ms ( 29.2x)
  4. Swinject (Dynamic Dictionary)          |  11.32 ms ( 41.6x)
  5. Factory (Container.shared)             |  12.12 ms ( 44.6x)
```

> ⚠️ **Advertencia de honestidad:** el "Explícito" de este round llama funciones del módulo que crean un repositorio
> y un cliente **nuevos en cada iteración** (no hay caché ni búsqueda), así que no mide lo mismo que un contenedor.
> La comparación justa es el **Round 4** (misma semántica: `@Singleton` real, `@Scoped` cacheado, use case transient):

```text
  A mano (misma semántica)            |  0.06 ms  (piso teórico)
  Generado (dagger-graph generate)    |  0.19–0.22 ms  (con lock: thread-safe)
  Motor DAG (ScopeContainer.resolve)  |  7.3–10 ms
  Arranque en frío ×1000 (construir grafo + 1ª resolución): DAG ~11 ms · generado ~0.12 ms
```

Fuente: `Benchmarks/Tests/DIFrameworksDebateTests/SameSemanticsBenchmarkTests.swift`
(`swift test -c release --package-path Benchmarks --filter SameSemantics`).

### Matriz Comparativa de Capacidades

| Capacidad Arquitectónica | Swinject | Factory | Point-Free `swift-dependencies` (TCA) | **DaggerSwift v2** |
| :--- | :---: | :---: | :---: | :---: |
| **Verificación en Tiempo de Compilación** | ❌ No (`nil` en Runtime) | ⚠️ Parcial | ⚠️ Falla en Runtime si falta `testValue` | **✅ Con `dagger-graph` (plugin/CI): faltantes, ciclos y scopes por raíz. Sin él, solo en runtime** |
| **Cero contaminación en `Domain` (`init` puro)** | ❌ `resolver.resolve` | ❌ `@Injected` | ❌ `@Dependency` dentro de `Domain` | **✅ Sí (`@Inject` genera `init` limpio)** |
| **Variantes de Producto (Multi-Country/Versiones) sin Naming Layers** | ❌ No (Parche con `name:` String) | ❌ No (Muta contenedor global) | ⚠️ Solo en Tests (`withDependencies`) | **✅ Sí (Nativo con `@Module` + `@Scope`)** |
| **Nodos `@Precondition` (Cortocircuito de Sesión)** | ❌ No existe | ❌ No existe | ❌ No existe | **✅ Sí (`@Precondition` nativo, 0 allocs)** |
| **Nodos `@BusinessRule` (A/B Flags en el Grafo)** | ❌ Manual | ❌ Manual | ❌ Manual | **✅ Sí (`@BusinessRule` auditable)** |
| **Herencia de Evolución `@Module(0.1 -> 1.0 -> 2.0)`** | ❌ No existe | ❌ No existe | ❌ No existe | **✅ Sí (`@Scope` + `includes:`)** |
| **`teardown()` Jerárquico + Auditoría de Retain Cycles** | ❌ No audita leaks | ❌ No audita leaks | ❌ No audita leaks | **✅ Sí (`WeakObjectBox` devuelve fugas)** |
| **Weak Cache `.shared` automático sin `teardown()`** | ❌ No | **✅ Sí (`.shared`)** | ❌ No | ❌ `@Scoped` exige llamar a `teardown()` |
| **Override `@TaskLocal` profundo sin tocar `init`** | ❌ No | ❌ No | **✅ Sí (`withDependencies`)** | ❌ Exige constructor o `ScopeContainer` |

---

### 4.2 Round 1: Obligando a Fallar a las Otras Librerías (Donde Gana `DaggerSwift`)

En [`DIFrameworksDebateTests.swift`](./Benchmarks/Tests/DIFrameworksDebateTests/DIFrameworksDebateTests.swift) escribimos pruebas que fuerzan a cada librería real a exhibir sus huecos arquitectónicos:

| Test en `DIFrameworksDebateTests` | Qué Librería Falla y Cómo | Cómo Gana `DaggerSwift` |
| :--- | :--- | :--- |
| **`Round 1.1` (`testSwinjectFailsAtRuntimeOnMissingRegistration`)** | ❌ **`Swinject`**: Si olvidas hacer `container.register(BenchRepositoryProtocol.self)`, el código **compila con 0 errores** y `swinject.resolve(...)` devuelve `nil` en Runtime (o crashea con `!`). | ✅ **Verificación Compile-Time:** Con `BenchModuleContract` + `@Module`, si falta una dependencia el archivo **no compila en Xcode**. |
| **`Round 1.2` (`testPointFreeDependenciesFailsWhenUnconfiguredInTest`)** | ❌ **`Point-Free swift-dependencies` (TCA)**: Si un `UseCase` usa `@Dependency(\.unconfiguredRepo)` y alguien lo invoca sin envolverlo en `withDependencies { ... }`, el proyecto compila pero **dispara un Issue/Fallo en Runtime**. Además, obliga a `Domain` a hacer `import Dependencies`. | ✅ **Pureza de `Domain`:** `@Inject` solo sintetiza un `public init(...)` puro sin acoplar `Domain` a ningún contenedor ni `@TaskLocal` oculto. |
| **`Round 1.3` (`testFactoryGlobalStatePollutionWhenResetIsForgotten`)** | ❌ **`Factory`**: Cuando un flujo o test hace `Container.shared.benchRepo.register { ... }` y olvida llamar a `Container.shared.manager.reset()`, **contamina globalmente** a todas las pantallas siguientes (`420` en vez de `42`). | ✅ **Aislamiento por Instancia/Módulo:** Cada `ScopeContainer` o `@Module` es 100% independiente; no existe estado mutable global compartido por accidente. |
| **`Round 1.4` (`testAllThreeLibrariesAllocateDependenciesBeforeCheckingPreconditions`)** | ❌ **`Swinject` + `Factory` + `Point-Free TCA`**: Ninguna tiene `@Precondition`. Aunque la sesión sea `nil`, las tres **instancian el `Repository` en RAM (`allocations == 1`)** antes de que la pantalla descubra que no había sesión. | ✅ **Cortocircuito `@Precondition`:** `DaggerSwift` evalúa `@Precondition` en la raíz del sub-grafo y aborta antes de crear dependencias hijas (**`allocations == 0`**). |
| **`Round 1.5` (`testMemoryLeakDetectionOnFeatureTeardown`)** | ❌ **`Swinject` + `Factory` + `Point-Free TCA`**: Si un `ViewModel` tiene un *retain cycle* (`self.selfRetainCycle = { _ = self }`), ninguna de las 3 librerías te avisa al cerrar la pantalla. | ✅ **Auditoría `WeakObjectBox`:** `featureScope.teardown()` devuelve `["LeakyFeatureViewModel"]` detectando la fuga de memoria automáticamente. |
| **`Round 1.6` (`testCaptiveDependencyScopeHierarchyViolation`)** | ❌ **`Swinject` + `Factory` + `Point-Free TCA`**: Permiten que el contenedor raíz resuelva y secuestre un objeto efímero de pantalla (*Captive Dependency Bug*). | ✅ **Regla de Oro de Scopes:** Intentar resolver un `@Scoped` de `BenchFeatureScope` desde `root` sin abrir `makeChildScope` lanza `GraphError.scopeViolation`. |

---

### 4.3 Round 2: Comparativa de Decisiones de Diseño y Cómo Resolver Variantes sin "Naming Layer"

Un buen diseño reconoce qué decisiones tomó cada librería y por qué:

```mermaid
flowchart TD
    subgraph Round2 ["🥊 Comparativa de Paradigmas"]
        PF["Point-Free TCA\nwithDependencies (@TaskLocal)\nPropagación implícita a 3 niveles\nsin tocar init()"] -->|"Trade-off"| D_PF["DaggerSwift: Pureza de Inyección por Constructor\nDomain no importa DI ni usa @TaskLocal mágicos"]
        FAC["Factory\nScope .shared (Weak Cache)\nSe libera solo con ARC\nsin llamar a teardown()"] -->|"Trade-off"| D_FAC["DaggerSwift: Ciclo de Vida Explícito\nScopeContainer controla teardown() y audita retain cycles"]
        SW["Swinject\nregister(..., name: 'mx')\nBolsa de gatos con Strings mágicos\ny resolución directa por contenedor"] -->|"Solución Limpia"| D_SW["DaggerSwift: Variantes Tipadas sin Naming Layer\nEl tipo es el contrato; el Scope selecciona el @Module"]
    end
```

#### ¿Por qué no usamos `name: String` o "Naming Layers"?
En `Swinject`, cuando necesitan dos implementaciones del mismo protocolo (ej. México y USA), recurren a strings dinámicos (`name: "mexico"`). Esto introduce:
1. **Riesgo de Typos en Runtime:** Escribir `"mejico"` o `"usa_v2"` compila sin advertencias y crashea en producción.
2. **Contaminación con Service Locator:** Obliga a invocar directamente al contenedor (`container.resolve(..., name: "mexico")`).
3. **Capa Artificial Innecesaria:** Se inventa un *layer name* para parchar la falta de soporte modular de primer nivel.

#### Cómo resuelve `DaggerSwift` las Variantes sin Naming Layers (Clean Architecture):
En `DaggerSwift`, indexamos estrictamente por tipo (`TypeKey` / `ObjectIdentifier(T.self)`) para garantizar **seguridad en tiempo de compilación y cero costo en CPU**. Las variantes se modelan limpiamente en los 3 ejes de la arquitectura:
- **1. Variantes Hermanas (Multi-Country / Regional):** `MexicoNewsModule` y `USANewsModule` conforman el mismo contrato `CountryNewsModuleContract`. El caso de uso solo pide `any CountryLocaleProviderProtocol`. Quien conmuta la variante es el `@Scope` activo (`CountryNewsScope.module(for: .mexico)`). **Cero strings mágicos.**
- **2. Variantes de Evolución (`0.1 -> 1.0 -> 2.0`):** `@Module(1.0, includes: [FintechModuleV0_1.self])` evoluciona componentes específicos con herencia real sin duplicar código.
- **3. Variantes Dinámicas / A/B:** `@BusinessRule` conmuta entre variantes en caliente según Feature Flags del servidor.

👉 **Lee el análisis completo en [`LIBRO_INYECCION_Y_BENCHMARKS.md`](./LIBRO_INYECCION_Y_BENCHMARKS.md).**

---

## 5. 📱 Demos Reales Incluidas (`SampleProyect`) y Estructura del Repositorio

```text
├── Package.swift                        # Paquete principal DaggerSwift (0 dependencias externas)
├── Benchmarks/                          # Paquete SPM Independiente de Debate y Benchmarks Reales:
│   ├── Package.swift                    # Importa DaggerSwift + Point-Free swift-dependencies + Factory + Swinject
│   └── Tests/DIFrameworksDebateTests/
│       ├── DIFrameworksDebateTests.swift # Round 1 (Ellos fallan), Round 2 (DaggerSwift falla), Round 3 (Benchmark + Gráfico)
│       └── SwinjectHelper.swift         # Desambiguación de tipos Container entre Swinject y Factory
├── Assets/
│   └── dagger2-hero.png                 # Portada oficial de DaggerSwift v2
├── LIBRO_INYECCION_Y_BENCHMARKS.md      # Libro Técnico: Resolución Explícita vs Dinámica y Benchmarks
├── Sources/
│   ├── DaggerSwift/                     # Motor DAG, GraphScope, ScopeContainer, Macros (@Module, @Scope, @Inject...)
│   ├── DaggerSwiftMacros/               # Compiler Plugin nativo Swift 6 (protocolo JSON HostToPluginMessage, <0.3s build)
│   ├── DaggerSwiftTesting/              # DSL declarativo para pruebas del grafo (expectGraph, matchesContract, when)
│   ├── DaggerCLI/                       # Herramienta de terminal (swift run dagger-cli)
│   ├── SampleProyect/                   # Paquete SPM Modular con 3 Demos (Clean Architecture + MVVM + SOLID + Plug & UnPlug):
│   │   ├── Sources/
│   │   │   ├── AppFoundation/           # Modelos base y Design System compartido
│   │   │   ├── MultiCountryNewsDemo/    # Demo 1: Login Multi-Country + Noticias en 4 Idiomas (MX, US, BR, FR)
│   │   │   ├── FintechMockupDemo/       # Demo 2: App Mockup Fintech con Paleta @Module(0.1/1.0/2.0) + @Scope + A/B Flags
│   │   │   ├── Core/                    # Demo 3 (Domain): Protocolos, @Precondition ValidatedSession y UseCases (@Inject)
│   │   │   ├── Services/                # Demo 3 (Data): LiveGitHubRepository + LiveGitHubModule (1.0) / LiveGitHubModuleV2 (2.0)
│   │   │   ├── Features/                # Demo 3 (Presentation): FeedViewModel (@Inject), FeedView y Sub-Scope RepoDetailModule
│   │   │   └── SampleProyect/           # ShowcaseRootView: Selector de las 3 Demos y switch Plug & UnPlug en vivo
│   │   └── Tests/
│   │       ├── AppUnitTests/            # Pruebas unitarias de UseCases y ViewModels con Fakes sin grafo
│   │       └── AppGraphTests/           # Pruebas del grafo (DaggerSwiftTesting) + ArchitectureLinterTests (Linter SOLID/Clean)
│   └── Demo/                            # Proyecto Xcode iOS / iPadOS / macOS (Targets Demo y DemoFaker)
└── Test/
    ├── ModuleTest.swift                 # Pruebas de retrocompatibilidad DaggerSwift v1
    ├── DaggerMacrosV2Tests.swift        # Pruebas de expansión de macros @Module y @Inject
    └── GraphEngineV2Tests.swift         # Pruebas de motor DAG, Scopes, Preconditions y Retain Cycles
```


---

## 6. 🔍 Compile-time vs runtime: qué valida cada capa

| Capa | Cuándo | Qué detecta / hace |
|---|---|---|
| Macros (`@Module`, `@Inject`, …) | Compilación | Generan `register(in:)`, `init` limpio, `init(from:)`. **No** validan el grafo. |
| `dagger-graph` (CLI / build plugin) | Compilación / CI | Bindings faltantes (global y **por raíz**), ciclos (con la cadena completa), `@Singleton` que depende de un scope hijo, **`scopeNotActive` estático** (pedir un `@Scoped(X)` desde una raíz que nunca abre X). Listas de módulos no literales → warning. |
| `dagger-graph generate` | Compilación (opt-in) | Factories tipadas directas por raíz: sin `resolve`, sin diccionarios. |
| Tests de humo generados | Tests / CI | Cada raíz literal se arma con el **runtime real** y resuelve cada binding. |
| `ScopeContainer` (runtime) | Ejecución | Red de seguridad: vuelve a detectar todo lo anterior + errores de **estado** (`unmetPrecondition`, `scopeClosed`). |

Lo que **no** se puede validar estáticamente: raíces con listas no literales, `bindInstance`/`provide*` imperativos,
composición dinámica (`CountryNewsScope.module(for:)`), y tipos comparados por texto (typealias, genéricos complejos).
Para eso queda el runtime y los tests de humo.

## 7. 🧰 Herramientas: `dagger-graph` (CLI, plugin, `generate`, manifiestos)

Vive en [`Tools/DaggerGraph`](./Tools/DaggerGraph) (paquete separado: `DaggerSwift` sigue con 0 dependencias).
Detalle y mediciones: [`Tools/DaggerGraph/SPIKE.md`](./Tools/DaggerGraph/SPIKE.md).

```bash
# Validar (diagnósticos archivo:línea:col; exit 1 si hay errores)
swift run -c release --package-path Tools/DaggerGraph dagger-graph --timings Sources/SampleProyect Benchmarks

# Regenerar el código generado y los tests de humo del repo
scripts/generate-graphs.sh

# Multi-paquete (prototipo): publicar y unir manifiestos de grafo
dagger-graph manifest --name ServicesKit --out ServicesKit.json Sources/Services
dagger-graph --manifest ServicesKit.json Sources/Features
```

Build plugin (valida en cada build; +24–27 ms por build medido en SampleProyect):

```swift
.target(name: "App", plugins: [.plugin(name: "DaggerGraphBuildPlugin", package: "DaggerGraph")])
```

Costos medidos (Apple Silicon): repo completo en frío ~15 ms, sin cambios ~5 ms, 1 archivo editado ~9 ms.

## 8. 📦 Distribución: dev desde fuente, release como binario

- **`main` / desarrollo:** todo desde fuente (`swift build`, CI en cada PR: [`ci.yml`](./.github/workflows/ci.yml)).
- **Release (tag `v*`):** [`release.yml`](./.github/workflows/release.yml) publica `DaggerSwiftCore.xcframework`
  (el runtime) y `dagger-graph.artifactbundle`; el commit del tag usa `binaryTarget(url:checksum:)`.
  Las **macros siguen en fuente** (SwiftPM no admite macros binarias): `DaggerSwift` es un target delgado con las
  declaraciones de macros + `@_exported import DaggerSwiftCore`. En Linux el manifiesto cae a fuente.
- Ensayo local completo, sin publicar nada: `scripts/release-dry-run.sh`.
- Medido: build limpio de un consumidor ~5 s con fuente o binario (el runtime es chico); la ganancia grande es
  `dagger-graph` como artifactbundle (1.4 s vs. 150+ s compilando swift-syntax).

## 9. 🚦 Errores del grafo y el patrón Coordinator

Los errores de resolución se manejan en **un solo `catch`, en el Coordinator**:
`GraphError.isProgrammerError` → reportar + pantalla de respaldo; `unmetPrecondition` / `scopeClosed` → navegación.
En debug los errores de programación truenan (`ScopeContainer.programmerErrorPolicy = .assertInDebug`).
Guía completa con ejemplo: [`docs/COORDINATOR.md`](./docs/COORDINATOR.md).

## 10. 📝 Notas de versión (borrador v2.1.0)

**Cambios que pueden requerir ajustes**
- `GraphError` tiene dos casos nuevos: `.mainActorRequired` y `.scopeClosed`. Un `switch` exhaustivo sin `default`
  deja de compilar: agrega los casos o un `default`.
- El paquete se partió en `DaggerSwiftCore` (runtime) + `DaggerSwift` (macros). La API pública es la misma
  (`import DaggerSwift` sigue funcionando); los nombres de tipos del runtime en snapshots pasan a `DaggerSwiftCore.X`.
- **Después de actualizar, haz un build limpio:** SwiftPM no recompila los archivos que usan macros cuando cambia
  el plugin de macros, y podrías quedarte con expansiones viejas.

**Correcciones**
- `@MainActor @Inject` resuelto desde background ya no crashea (`mainActorRequired`; `resolveOnMainActor(_:)`), y un
  miembro `@MainActor` ya no vuelve `@MainActor` a todo el tipo.
- Las factories ya no corren con el lock tomado; `@Singleton`/`@Scoped` se construyen una sola vez con concurrencia;
  ciclos entre hilos lanzan error en vez de bloquearse.
- Las cachés de los scopes hijos se invalidan cuando un ancestro registra.
- Todas las `@Precondition` del subgrafo se evalúan antes de construir nada (0 allocations si fallan).
- `autoTeardown` funciona sin Objective-C (Linux); `visionOS` en `platforms`.

**Nuevo**
- `GraphError.isProgrammerError`, `ScopeContainer.programmerErrorPolicy`.
- `dagger-graph`: validación por raíz, `scopeNotActive` estático, build plugin, `generate`, tests de humo, manifiestos.

---

## 🚀 Comandos Rápidos

```bash
# 1. Debate empírico y benchmarks (Rounds 1–4) contra Point-Free TCA, Factory y Swinject
swift test --package-path Benchmarks

# 2. Tests del motor DaggerSwift (runtime, macros, scopes anidados generados)
swift test

# 3. Linter de arquitectura + unit tests + graph tests + tests de humo del SampleProyect
swift test --package-path Sources/SampleProyect

# 4. Validar el grafo y regenerar código generado
scripts/generate-graphs.sh

# 5. Ejecutar el CLI interactivo de DaggerSwift
swift run dagger-cli help
```

---

## 📚 Documentación Adicional

- 📘 **[El Libro de DaggerSwift v2: Resolución Explícita vs. Dinámica, Comparativa y Benchmarks](./LIBRO_INYECCION_Y_BENCHMARKS.md)**
- 📄 **[Memoria Técnica: Limitaciones de DaggerSwift v1 y Dolores en Apps Productivas](./MEMORIA_DAGGER_V1.md)**
- 📜 **[Manifiesto](./MANIFESTO.md)**

## Licencia

MIT

