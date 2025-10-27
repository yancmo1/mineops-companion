import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "gearshape.2.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 90, height: 90)
                    .foregroundStyle(.blue)
                    .padding(.top, 60)

                Text("MineOps Companion")
                    .font(.title)
                    .bold()

                NavigationLink("Import Screenshots") {
                    OCRReviewView()
                }
                .buttonStyle(.borderedProminent)

                NavigationLink("Strategy Summary") {
                    StrategySummaryView()
                }
                .buttonStyle(.bordered)

                Spacer()
            }
            .padding()
            .navigationTitle("Dashboard")
        }
    }
}
