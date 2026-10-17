//
//  CountryNewsFeatureView.swift
//  Features
//
//  Demo 1 · Login Multi-Country + Home de Noticias en 4 Idiomas (ES, EN, PT, FR).
//  Demuestra `@Module(scope: CountryNewsScope.self)` + `@Precondition` (`AuthenticatedCountrySession`).
//

import SwiftUI
import DaggerSwift
import AppFoundation

@MainActor
public final class CountryNewsPortalViewModel: ObservableObject {
    private let rootContainer: ScopeContainer
    private let authRepository: any CountryAuthRepositoryProtocol
    private let moduleResolver: (SupportedCountry) -> any GraphModule.Type
    private var activeCountryScope: ScopeContainer?

    @Published public var selectedCountry: SupportedCountry = .mexico
    @Published public var currentCopy: LocalizedCountryCopy
    @Published public var identifierInput: String = ""
    @Published public var activeUseCase: GetLocalizedNewsFeedUseCase?
    @Published public var blockedReason: String?
    @Published public var scopeTeardownCount: Int = 0

    public init(
        rootContainer: ScopeContainer,
        moduleResolver: @escaping (SupportedCountry) -> any GraphModule.Type
    ) throws {
        self.rootContainer = rootContainer
        self.authRepository = try rootContainer.resolve((any CountryAuthRepositoryProtocol).self)
        self.moduleResolver = moduleResolver

        let initialModule = moduleResolver(.mexico)
        let initialScope = rootContainer.makeChildScope(for: initialModule)
        self.activeCountryScope = initialScope
        let locale = try initialScope.resolve((any CountryLocaleProviderProtocol).self)
        self.currentCopy = locale.copy
        self.identifierInput = locale.copy.defaultIdentifier
        tryResolveNewsHome(in: initialScope)
    }

    public func selectCountry(_ country: SupportedCountry) {
        selectedCountry = country
        // Destruir el Scope del país anterior (ARC Memory Teardown)
        if let oldScope = activeCountryScope {
            _ = oldScope.teardown()
            scopeTeardownCount += 1
        }

        let countryModule = moduleResolver(country)
        let newScope = rootContainer.makeChildScope(for: countryModule)
        activeCountryScope = newScope

        if let locale = try? newScope.resolve((any CountryLocaleProviderProtocol).self) {
            currentCopy = locale.copy
            identifierInput = locale.copy.defaultIdentifier
        }

        // Si ya había sesión activa, actualizamos el país de la sesión para que veas el cambio de idioma inmediato
        if authRepository.currentSession != nil {
            authRepository.login(identifier: identifierInput, country: country)
        }
        tryResolveNewsHome(in: newScope)
    }

    public func loginInCurrentCountry() {
        let id = identifierInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? currentCopy.defaultIdentifier
            : identifierInput
        authRepository.login(identifier: id, country: selectedCountry)
        if let scope = activeCountryScope {
            tryResolveNewsHome(in: scope)
        }
    }

    public func logout() {
        authRepository.logout()
        if let scope = activeCountryScope {
            tryResolveNewsHome(in: scope)
        }
    }

    private func tryResolveNewsHome(in scope: ScopeContainer) {
        do {
            let useCase = try scope.resolve(GetLocalizedNewsFeedUseCase.self)
            activeUseCase = useCase
            blockedReason = nil
        } catch let GraphError.unmetPrecondition(_, reason) {
            activeUseCase = nil
            blockedReason = reason
        } catch {
            activeUseCase = nil
            blockedReason = error.localizedDescription
        }
    }
}

public struct CountryNewsFeatureView: View {
    @ObservedObject private var viewModel: CountryNewsPortalViewModel

    public init(viewModel: CountryNewsPortalViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    countrySelectorBar

                    scopeTelemetryStrip

                    if let newsUseCase = viewModel.activeUseCase {
                        authenticatedNewsHomeView(useCase: newsUseCase)
                    } else {
                        localizedLoginGateCard
                    }
                }
                .padding(16)
            }
            .navigationTitle("1. Multi-Country News")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }

    // MARK: - Selector de Variantes Hermanas (@Module(scope: CountryNewsScope.self))

    private var countrySelectorBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("VARIANTES HERMANAS · @Module(scope: CountryNewsScope.self)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(SupportedCountry.allCases) { country in
                    let isSelected = viewModel.selectedCountry == country
                    Button {
                        withAnimation(.snappy(duration: 0.25)) {
                            viewModel.selectCountry(country)
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(country.flagEmoji)
                            Text(country.rawValue)
                                .font(.caption.weight(.bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(isSelected ? Color.indigo : Color.showcaseCardBackground)
                        )
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.primary.opacity(isSelected ? 0 : 0.08), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var scopeTelemetryStrip: some View {
        HStack(spacing: 8) {
            Text(viewModel.currentCopy.regionBadge)
                .font(.caption.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.indigo.opacity(0.14)))
                .foregroundStyle(.indigo)

            Spacer()

            Label("Teardowns: \(viewModel.scopeTeardownCount)", systemImage: "arrow.triangle.2.circlepath")
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Pantalla 1: Login Localizado (Cuando @Precondition devuelve nil)

    private var localizedLoginGateCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "lock.shield.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.currentCopy.loginTitle)
                        .font(.title3.weight(.bold))
                    Text("Idioma activo: \(viewModel.currentCopy.languageCode)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

            Text(viewModel.currentCopy.loginSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.currentCopy.identifierPlaceholder)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField(viewModel.currentCopy.identifierPlaceholder, text: $viewModel.identifierInput)
                    .textFieldStyle(.plain)
                    .font(.subheadline.monospaced())
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.showcaseSubtleFill)
                    )
            }

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.loginInCurrentCountry()
                }
            } label: {
                HStack {
                    Image(systemName: "key.fill")
                    Text(viewModel.currentCopy.loginButtonTitle)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.indigo)
                )
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.Icircle.fill")
                    .foregroundStyle(.orange)
                Text(viewModel.currentCopy.preconditionBlockedMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.orange.opacity(0.1))
            )
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.showcaseCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Pantalla 2: Home de Noticias en el Idioma del País (Tras cumplir @Precondition)

    private func authenticatedNewsHomeView(useCase: GetLocalizedNewsFeedUseCase) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(useCase.copy.breakingTag)
                            .font(.caption2.weight(.heavy))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.red.opacity(0.15)))
                            .foregroundStyle(.red)

                        Text("Token: \(useCase.session.sessionToken)")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }

                    Text(useCase.copy.newsHeaderTitle)
                        .font(.title3.weight(.bold))

                    Text(useCase.copy.newsHeaderSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    withAnimation(.snappy(duration: 0.25)) {
                        viewModel.logout()
                    }
                } label: {
                    Text(useCase.copy.logoutButtonTitle)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.red.opacity(0.14)))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.showcaseCardBackground)
            )

            ForEach(useCase.headlines) { article in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(article.category, systemImage: article.symbolName)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.indigo)
                        Spacer()
                        Text("\(article.source) · \(article.readTime)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Text(article.title)
                        .font(.headline)

                    Text(article.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.showcaseCardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
            }
        }
    }
}
