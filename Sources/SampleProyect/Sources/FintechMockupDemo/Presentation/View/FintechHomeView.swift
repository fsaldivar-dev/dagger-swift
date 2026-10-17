//
//  FintechHomeView.swift
//  FintechMockupDemo · Presentation -> View (MVVM)
//

import SwiftUI
import AppFoundation

public struct FintechMockupFeatureView: View {
    @StateObject private var viewModel: FintechMockupViewModel

    public init(viewModel: FintechMockupViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        ScrollView {
            if let dashboard = viewModel.dashboard {
                VStack(alignment: .leading, spacing: 16) {
                    paletteAndABCard(dashboard: dashboard)

                    balanceAndCardSection(dashboard: dashboard)

                    creditOfferABBanner(dashboard: dashboard)

                    transactionsSection
                }
                .padding(16)
            }
        }
        .task {
            viewModel.loadInitialDashboard()
        }
    }

    // MARK: - 1. Selector Limpio de Variantes Module(0.1 / 1.0 / 2.0) y A/B Flags

    private func paletteAndABCard(dashboard: GetFintechDashboardUseCase) -> some View {
        let layoutVariant = dashboard.layoutVariant
        let creditVariant = dashboard.creditOfferVariant
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ForEach(FintechScope.Palette.allCases) { option in
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

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(layoutVariant.badgeTitle)
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

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Experimento Crédito (\(creditVariant.experimentCode))")
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
    }

    // MARK: - 2. Saldo y Tarjeta

    private func balanceAndCardSection(dashboard: GetFintechDashboardUseCase) -> some View {
        let summary = dashboard.coreBanking.fetchAccountSummary()
        let cardProduct = dashboard.cardEngine.fetchCardProduct()
        let layoutVariant = dashboard.layoutVariant
        return VStack(alignment: .leading, spacing: 12) {
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
                        Label(summary.monthlyYieldFormatted, systemImage: "arrow.up.right.circle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.green)

                        HStack(alignment: .bottom, spacing: 8) {
                            ForEach([0.35, 0.48, 0.55, 0.68, 0.82, 1.0], id: \.self) { ratio in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(LinearGradient(colors: [.green.opacity(0.7), .mint], startPoint: .bottom, endPoint: .top))
                                    .frame(height: CGFloat(40 * ratio))
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(height: 42)
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

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: cardProduct.isMetalV2 ? "creditcard.and.123" : "creditcard")
                        .font(.title3)
                    Text(cardProduct.cardTitle)
                        .font(.headline.weight(.bold))
                    Spacer()
                    Text(cardProduct.moduleVersionTag)
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

    // MARK: - 3. Oferta de Crédito A/B

    private func creditOfferABBanner(dashboard: GetFintechDashboardUseCase) -> some View {
        let creditVariant = dashboard.creditOfferVariant
        return VStack(alignment: .leading, spacing: 10) {
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
    }

    // MARK: - 4. Movimientos

    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Movimientos Recientes")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            ForEach(viewModel.transactions) { item in
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
