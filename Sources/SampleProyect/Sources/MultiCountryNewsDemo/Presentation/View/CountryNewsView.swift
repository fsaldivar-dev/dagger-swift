//
//  CountryNewsView.swift
//  MultiCountryNewsDemo · Presentation -> View (MVVM)
//

import SwiftUI
import AppFoundation

public struct CountryNewsFeatureView: View {
    @ObservedObject private var viewModel: CountryNewsPortalViewModel

    public init(viewModel: CountryNewsPortalViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    countryPickerBar

                    if viewModel.isAuthenticated {
                        newsFeedSection
                    } else {
                        loginCardSection
                    }
                }
                .padding(16)
            }
            .navigationTitle(viewModel.currentCopy.regionBadge)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .task {
                await viewModel.loadInitialCountry()
            }
        }
    }

    private var countryPickerBar: some View {
        HStack(spacing: 8) {
            ForEach(SupportedCountry.allCases) { country in
                let isSelected = viewModel.selectedCountry == country
                Button {
                    withAnimation(.snappy(duration: 0.25)) {
                        viewModel.selectCountry(country)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(country.flagEmoji)
                        Text(country.displayName)
                            .font(.caption.weight(.bold))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isSelected ? Color.indigo : Color.showcaseCardBackground)
                    )
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var loginCardSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(viewModel.currentCopy.loginTitle)
                .font(.title2.weight(.bold))

            Text(viewModel.currentCopy.loginSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField(viewModel.currentCopy.identifierPlaceholder, text: $viewModel.identifierInput)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.showcaseSubtleFill)
                )

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.login()
                }
            } label: {
                Text(viewModel.currentCopy.loginButtonTitle)
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.indigo)
                    )
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.showcaseCardBackground)
        )
    }

    private var newsFeedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.currentCopy.breakingTag)
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(.red)
                    Text(viewModel.currentCopy.newsHeaderTitle)
                        .font(.title3.weight(.bold))
                    Text(viewModel.currentCopy.newsHeaderSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    withAnimation(.snappy(duration: 0.25)) {
                        viewModel.logout()
                    }
                } label: {
                    Text(viewModel.currentCopy.logoutButtonTitle)
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

            ForEach(viewModel.headlines) { article in
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
            }
        }
    }
}
