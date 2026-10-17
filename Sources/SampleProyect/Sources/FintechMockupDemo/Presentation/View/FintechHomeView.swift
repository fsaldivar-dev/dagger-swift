//
//  FintechHomeView.swift
//  FintechMockupDemo · Presentation -> View (MVVM)
//

import SwiftUI
import AppFoundation

public struct FintechMockupFeatureView: View {
    @StateObject private var viewModel: FintechMockupViewModel

    public init(
        viewModel: FintechMockupViewModel = FintechMockupViewModel(
            flagsRepository: FintechSharedFlagsModule.abFlagsRepository()
        )
    ) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        ScrollView {
            if let data = viewModel.snapshot {
                VStack(alignment: .leading, spacing: 14) {
                    paletteAndABCard(data: data)
                    balanceAndCardSection(data: data)
                    creditOfferABBanner(data: data)
                    transactionsSection(items: data.transactions)
                }
                .padding(16)
            }
        }
        .task { await viewModel.loadInitialDashboard() }
    }

    private func paletteAndABCard(data: FintechDashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(FintechScope.Palette.allCases) { option in
                    let isSelected = viewModel.selectedPalette == option
                    Button {
                        withAnimation(.snappy) { viewModel.selectPalette(option) }
                    } label: {
                        Text(option.buttonLabel)
                            .font(.caption.weight(.bold).monospaced())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(isSelected ? Color.indigo : Color.showcaseSubtleFill))
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(data.layoutVariant.badgeTitle).font(.caption.weight(.bold))
                    Text(data.layoutVariant.subtitle).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: Binding(get: { viewModel.isWealthBentoVariantB }, set: { _ in viewModel.toggleLayoutAB() }))
                    .labelsHidden()
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Crédito A/B (\(data.creditOfferVariant.experimentCode))").font(.caption.weight(.bold))
                    Text("Pre-aprobado: \(data.creditOfferVariant.preapprovedAmountFormatted)").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: Binding(get: { viewModel.isInstantCreditBoostVariantB }, set: { _ in viewModel.toggleCreditOfferAB() }))
                    .labelsHidden()
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.showcaseCardBackground))
    }

    private func balanceAndCardSection(data: FintechDashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(data.account.holderName).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    Spacer()
                    Text(data.account.accountNumberMasked).font(.caption2.monospaced()).foregroundStyle(.secondary)
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(data.account.balanceFormatted).font(.system(size: 30, weight: .heavy, design: .rounded))
                    Text(data.account.currency).font(.caption.weight(.bold)).foregroundStyle(.secondary)
                }
                if data.layoutVariant.showsWealthAnalyticsChart {
                    Label(data.account.monthlyYieldFormatted, systemImage: "arrow.up.right.circle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.green)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.green.opacity(0.1)))
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color.showcaseCardBackground))

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: data.card.isMetalV2 ? "creditcard.and.123" : "creditcard")
                    Text(data.card.cardTitle).font(.headline.weight(.bold))
                    Spacer()
                    Text(data.card.moduleVersionTag)
                        .font(.caption2.weight(.heavy).monospaced())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(0.2)))
                }
                Text(data.card.cashbackText).font(.subheadline.weight(.semibold))
                ForEach(data.card.perks, id: \.self) { perk in
                    Label(perk, systemImage: "checkmark.circle.fill").font(.caption)
                }
            }
            .padding(18)
            .foregroundStyle(.white)
            .background(RoundedRectangle(cornerRadius: 18).fill(cardGradient))
        }
    }

    private var cardGradient: LinearGradient {
        switch viewModel.selectedPalette {
        case .v0_1: return LinearGradient(colors: [.gray, .teal], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .v1_0: return LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .v2_0: return LinearGradient(colors: [.black, .indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private func creditOfferABBanner(data: FintechDashboardSnapshot) -> some View {
        let offer = data.creditOfferVariant
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(offer.bannerTitle).font(.subheadline.weight(.bold))
                Spacer()
                Text(offer.experimentCode).font(.caption2.weight(.bold)).foregroundStyle(.purple)
            }
            Text(offer.bannerSubtitle).font(.caption).foregroundStyle(.secondary)
            HStack {
                Text(offer.preapprovedAmountFormatted).font(.title3.weight(.heavy))
                Spacer()
                Button(offer.ctaTitle) { viewModel.triggerCreditOfferCTA() }
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.purple))
                    .foregroundStyle(.white)
                    .buttonStyle(.plain)
            }
            if let msg = viewModel.boostActivatedMessage {
                Text(msg).font(.caption.weight(.semibold)).foregroundStyle(.green)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.showcaseCardBackground))
    }

    private func transactionsSection(items: [FintechTransactionItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Movimientos Recientes").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            ForEach(items) { item in
                HStack(spacing: 12) {
                    Image(systemName: item.icon).foregroundStyle(item.isPositive ? .green : .indigo)
                    VStack(alignment: .leading) {
                        Text(item.merchant).font(.subheadline.weight(.semibold))
                        Text(item.category).font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(item.amountFormatted).font(.subheadline.weight(.bold)).foregroundStyle(item.isPositive ? .green : .primary)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.showcaseCardBackground))
            }
        }
    }
}
