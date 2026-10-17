//
//  FintechMockupFeatureView.swift
//  FintechMockupDemo
//
//  Demo 2 · App Mockup de Fintech con Paleta `Module(0.1)`, `Module(1.0)`, `Module(2.0)`
//  + `@BusinessRule` A/B Feature Flags en vivo.
//

import SwiftUI
import DaggerSwift
import AppFoundation

public enum FintechModulePaletteOption: String, CaseIterable, Identifiable, Sendable {
    case v0_1 = "0.1"
    case v1_0 = "1.0"
    case v2_0 = "2.0"

    public var id: String { rawValue }

    public var moduleType: any GraphModule.Type {
        switch self {
        case .v0_1: return FintechModuleV0_1.self
        case .v1_0: return FintechModuleV1.self
        case .v2_0: return FintechModuleV2.self
        }
    }

    public var buttonLabel: String {
        "Module(\(moduleType.moduleVersion))"
    }
}

@MainActor
public final class FintechMockupViewModel: ObservableObject {
    private let rootContainer: ScopeContainer
    private let flagsRepository: any FintechABFlagsRepositoryProtocol
    private var activeFintechScope: ScopeContainer?

    @Published public var selectedPalette: FintechModulePaletteOption = .v2_0
    @Published public var isWealthBentoVariantB: Bool = true
    @Published public var isInstantCreditBoostVariantB: Bool = true
    @Published public var dashboard: GetFintechDashboardUseCase
    @Published public var boostActivatedMessage: String? = nil

    public init(rootContainer: ScopeContainer) throws {
        self.rootContainer = rootContainer
        self.flagsRepository = try rootContainer.resolve((any FintechABFlagsRepositoryProtocol).self)

        let scope = rootContainer.makeChildScope(for: FintechModuleV2.self)
        self.activeFintechScope = scope
        self.dashboard = try scope.resolve(GetFintechDashboardUseCase.self)
        self.isWealthBentoVariantB = flagsRepository.isWealthBentoVariantB
        self.isInstantCreditBoostVariantB = flagsRepository.isInstantCreditBoostVariantB
    }

    public func selectPalette(_ option: FintechModulePaletteOption) {
        selectedPalette = option
        boostActivatedMessage = nil
        activeFintechScope?.teardown()

        let newScope = rootContainer.makeChildScope(for: option.moduleType)
        activeFintechScope = newScope
        if let updated = try? newScope.resolve(GetFintechDashboardUseCase.self) {
            dashboard = updated
        }
    }

    public func toggleLayoutAB() {
        let next = !isWealthBentoVariantB
        isWealthBentoVariantB = next
        flagsRepository.setWealthBentoVariantB(next)
        refreshDashboardFromGraph()
    }

    public func toggleCreditOfferAB() {
        let next = !isInstantCreditBoostVariantB
        isInstantCreditBoostVariantB = next
        flagsRepository.setInstantCreditBoostVariantB(next)
        boostActivatedMessage = nil
        refreshDashboardFromGraph()
    }

    public func triggerCreditOfferCTA() {
        let offer = dashboard.creditOfferVariant
        if offer.isInstantBoostEnabled {
            boostActivatedMessage = "✅ ¡Depósito inmediato de \(offer.preapprovedAmountFormatted) acreditado vía Experimento B!"
        } else {
            boostActivatedMessage = "📋 Solicitud tradicional enviada a revisión (24-48 hrs · Control A)."
        }
    }

    private func refreshDashboardFromGraph() {
        guard let scope = activeFintechScope,
              let updated = try? scope.resolve(GetFintechDashboardUseCase.self) else { return }
        dashboard = updated
    }
}

public struct FintechMockupFeatureView: View {
    @ObservedObject private var viewModel: FintechMockupViewModel

    public init(viewModel: FintechMockupViewModel) {
        self.viewModel = viewModel
    }

    private var summary: FintechAccountSummary {
        viewModel.dashboard.coreBanking.fetchAccountSummary()
    }

    private var cardProduct: FintechCardProduct {
        viewModel.dashboard.cardEngine.fetchCardProduct()
    }

    private var transactions: [FintechTransactionItem] {
        viewModel.dashboard.coreBanking.fetchRecentTransactions()
    }

    private var layoutVariant: any FintechHomeLayoutVariantProtocol {
        viewModel.dashboard.layoutVariant
    }

    private var creditVariant: any FintechCreditOfferVariantProtocol {
        viewModel.dashboard.creditOfferVariant
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                daggerControlLabCard

                balanceAndCardSection

                creditOfferABBanner

                transactionsSection
            }
            .padding(16)
        }
    }

    // MARK: - 1. Paleta de Módulos Module(0.1) | Module(1.0) | Module(2.0) + @BusinessRule A/B Flags

    private var daggerControlLabCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Paleta de Versiones @Module", systemImage: "swatchpalette.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.indigo)
                Spacer()
                Text(cardProduct.moduleVersionTag)
                    .font(.caption2.monospaced())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.indigo.opacity(0.14)))
                    .foregroundStyle(.indigo)
            }

            // Paleta de 3 botones: Module(0.1) | Module(1.0) | Module(2.0)
            HStack(spacing: 8) {
                ForEach(FintechModulePaletteOption.allCases) { option in
                    let isSelected = viewModel.selectedPalette == option
                    Button {
                        withAnimation(.snappy(duration: 0.25)) {
                            viewModel.selectPalette(option)
                        }
                    } label: {
                        Text(option.buttonLabel)
                            .font(.caption.weight(.bold).monospaced())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(isSelected ? Color.indigo : Color.showcaseSubtleFill)
                            )
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            // Switch A/B 1: Layout de Home
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("@BusinessRule 1 · \(layoutVariant.badgeTitle)")
                        .font(.caption.weight(.bold))
                    Text(layoutVariant.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { viewModel.isWealthBentoVariantB },
                    set: { _ in
                        withAnimation(.snappy(duration: 0.25)) {
                            viewModel.toggleLayoutAB()
                        }
                    }
                ))
                .labelsHidden()
            }

            // Switch A/B 2: Experimento de Crédito
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("@BusinessRule 2 · Experimento Crédito (\(creditVariant.experimentCode))")
                        .font(.caption.weight(.bold))
                    Text("Pre-aprobado: \(creditVariant.preapprovedAmountFormatted)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { viewModel.isInstantCreditBoostVariantB },
                    set: { _ in
                        withAnimation(.snappy(duration: 0.25)) {
                            viewModel.toggleCreditOfferAB()
                        }
                    }
                ))
                .labelsHidden()
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.showcaseCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.indigo.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - 2. Sección de Saldo y Tarjeta (Cambia según Module(0.1 / 1.0 / 2.0) y Layout A/B)

    private var balanceAndCardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(summary.holderName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(summary.accountNumberMasked)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(summary.balanceFormatted)
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                    Text(summary.currency)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }

                if layoutVariant.showsWealthAnalyticsChart {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label(summary.monthlyYieldFormatted, systemImage: "arrow.up.right.circle.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.green)
                            Spacer()
                            Text("Bento Analytics B")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.green)
                        }

                        HStack(alignment: .bottom, spacing: 8) {
                            ForEach([0.35, 0.48, 0.55, 0.68, 0.82, 1.0], id: \.self) { ratio in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(LinearGradient(colors: [.green.opacity(0.7), .mint], startPoint: .bottom, endPoint: .top))
                                    .frame(height: CGFloat(44 * ratio))
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(height: 46)
                        .padding(.top, 4)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.green.opacity(0.08))
                    )
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.showcaseCardBackground)
            )

            // Tarjeta de Producto (Cambia al instante entre Module(0.1), Module(1.0) y Module(2.0))
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: cardProduct.isMetalV2 ? "creditcard.and.123" : "creditcard")
                        .font(.title3)
                    Text(cardProduct.cardTitle)
                        .font(.headline.weight(.bold))
                    Spacer()
                    Text("Module(\(viewModel.selectedPalette.rawValue))")
                        .font(.caption2.weight(.heavy).monospaced())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(0.2)))
                }

                Text(cardProduct.cashbackText)
                    .font(.subheadline.weight(.semibold))
                    .opacity(0.95)

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(cardProduct.perks, id: \.self) { perk in
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                            Text(perk)
                                .font(.caption)
                        }
                    }
                }
            }
            .padding(18)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(cardGradient)
            )
        }
    }

    private var cardGradient: LinearGradient {
        switch viewModel.selectedPalette {
        case .v0_1:
            return LinearGradient(colors: [Color.gray, Color.teal.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .v1_0:
            return LinearGradient(colors: [Color.blue, Color.cyan.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .v2_0:
            return LinearGradient(colors: [Color.black, Color.indigo, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    // MARK: - 3. Banner A/B de Oferta de Crédito (@BusinessRule 2)

    private var creditOfferABBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(creditVariant.bannerTitle)
                    .font(.subheadline.weight(.bold))
                Spacer()
                Text(creditVariant.experimentCode)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(creditVariant.isInstantBoostEnabled ? Color.purple.opacity(0.2) : Color.secondary.opacity(0.15)))
                    .foregroundStyle(creditVariant.isInstantBoostEnabled ? .purple : .secondary)
            }

            Text(creditVariant.bannerSubtitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text(creditVariant.preapprovedAmountFormatted)
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(creditVariant.isInstantBoostEnabled ? .purple : .primary)

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.triggerCreditOfferCTA()
                    }
                } label: {
                    Text(creditVariant.ctaTitle)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            Capsule().fill(creditVariant.isInstantBoostEnabled ? Color.purple : Color.primary.opacity(0.1))
                        )
                        .foregroundStyle(creditVariant.isInstantBoostEnabled ? Color.white : Color.primary)
                }
                .buttonStyle(.plain)
            }

            if let msg = viewModel.boostActivatedMessage {
                Text(msg)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
                    .padding(.top, 2)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(creditVariant.isInstantBoostEnabled ? Color.purple.opacity(0.08) : Color.showcaseCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(creditVariant.isInstantBoostEnabled ? Color.purple.opacity(0.3) : Color.primary.opacity(0.07), lineWidth: 1)
        )
    }

    // MARK: - 4. Movimientos Recientes

    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Movimientos Recientes (Core Bancario heredado desde Module(0.1))")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            ForEach(transactions) { item in
                HStack(spacing: 12) {
                    Image(systemName: item.icon)
                        .font(.title3)
                        .foregroundStyle(item.isPositive ? .green : .indigo)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.showcaseSubtleFill))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.merchant)
                            .font(.subheadline.weight(.semibold))
                        Text(item.category)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(item.amountFormatted)
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(item.isPositive ? .green : .primary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.showcaseCardBackground)
                )
            }
        }
    }
}
