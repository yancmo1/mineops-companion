import SwiftUI
import UIKit

struct StrategySummaryView: View {
    @StateObject private var viewModel = StrategySummaryViewModel()

    var body: some View {
        ScrollView {
            Text(viewModel.strategyText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle("Strategy Summary")
    }
}


