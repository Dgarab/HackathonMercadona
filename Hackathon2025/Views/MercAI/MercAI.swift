import SwiftUI
import Combine
import SwiftData

	struct MercAI: View {
	@Environment(\.modelContext) private var modelContext
	@StateObject private var viewModelHolder = ViewModelHolder()

	var body: some View {
		NavigationStack {
			Group {
				if let viewModel = viewModelHolder.viewModel {
					chatView(viewModel: viewModel)
				} else {
					Color.clear
						.onAppear {
							viewModelHolder.viewModel = MercAIViewModel(modelContext: modelContext)
						}
				}
			}
			.navigationTitle("Cora")
		}
	}
	
	@ViewBuilder
	private func chatView(viewModel: MercAIViewModel) -> some View {
		ChatContentView(viewModel: viewModel)
	}
}

private struct ChatContentView: View {
	@ObservedObject var viewModel: MercAIViewModel
	
	var body: some View {
		VStack(spacing: 0) {
			ScrollView {
				LazyVStack(alignment: .leading, spacing: 12) {
					ForEach(viewModel.messages) { message in
						MessageRow(message: message)
							.padding(.horizontal)
					}

					if !viewModel.suggestedProducts.isEmpty {
						VStack(alignment: .leading, spacing: 8) {
							Text("Recomendaciones")
								.font(.headline)
							ScrollView(.horizontal, showsIndicators: false) {
								HStack(spacing: 12) {
									ForEach(viewModel.suggestedProducts) { product in
										ProductCard(product: product)
									}
								}
								.padding(.horizontal)
							}
						}
						.padding(.top, 8)
						.padding(.horizontal)
					}
				}
				.padding(.top, 12)
			}

			if viewModel.isProcessing {
				HStack {
					ProgressView()
						.padding(.trailing, 8)
					Text("Pensando...")
						.font(.footnote)
						.foregroundStyle(.secondary)
				}
				.padding()
			}
			
			if let error = viewModel.errorMessage {
				HStack {
					Image(systemName: "exclamationmark.triangle.fill")
						.foregroundStyle(.orange)
					Text(error)
						.font(.caption)
						.foregroundStyle(.secondary)
				}
				.padding(.horizontal)
				.padding(.vertical, 4)
			}
			
			HStack(spacing: 8) {
				TextField("Pregunta por productos, ofertas, etc.", text: $viewModel.inputText)
					.textFieldStyle(.roundedBorder)
					.disabled(viewModel.isProcessing)
					.onSubmit {
						Task { await viewModel.send() }
					}
				Button {
					Task { await viewModel.send() }
				} label: {
					Image(systemName: "paperplane.fill")
						.font(.system(size: 16, weight: .semibold))
				}
				.disabled(viewModel.isProcessing || viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
			}
			.padding()
			.background(.ultraThinMaterial)
		}
	}
}

private final class ViewModelHolder: ObservableObject {
	@Published var viewModel: MercAIViewModel?
}

private struct MessageRow: View {
	let message: AIMessage

	var body: some View {
		HStack(alignment: .top) {
			if message.role == .assistant {
				Image(systemName: "sparkles")
					.foregroundStyle(.green)
			} else {
				Image(systemName: "person.crop.circle")
					.foregroundStyle(.secondary)
			}
			VStack(alignment: .leading, spacing: 4) {
				Text(message.text)
					.font(.body)
					.foregroundStyle(.primary)
				Text(message.createdAt, style: .time)
					.font(.caption2)
					.foregroundStyle(.secondary)
			}
			.frame(maxWidth: .infinity, alignment: .leading)
		}
	}
}

private struct ProductCard: View {
	let product: Product

	var body: some View {
		VStack(spacing: 8) {
			ZStack {
				RoundedRectangle(cornerRadius: 10)
					.fill(Color(uiColor: .secondarySystemBackground))
					.frame(width: 110, height: 80)
				Image(product.imageName)
					.resizable()
					.scaledToFit()
					.frame(width: 90, height: 70)
					.clipped()
			}
			Text(product.name)
				.font(.footnote)
				.lineLimit(2)
				.multilineTextAlignment(.center)
				.frame(maxWidth: 110)
			Text(formattedPrice(product.priceCents))
				.font(.footnote).bold()
				.foregroundStyle(.green)
		}
		.padding(8)
		.background(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2)))
	}

	private func formattedPrice(_ cents: Int) -> String {
		let euros = Double(cents) / 100.0
		let formatter = NumberFormatter()
		formatter.locale = Locale(identifier: "es_ES")
		formatter.numberStyle = .currency
		return formatter.string(from: NSNumber(value: euros)) ?? "€\(euros)"
	}
}
