import SwiftUI

struct OceanLayerMenu: View {
    @Binding var selectedLayers: Set<MapLayer>
    @Binding var visualizeTemperature: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            Text("Ocean Layers")
                .font(.custom("Helvetica-Bold", size: 14, relativeTo: .caption))
                .foregroundStyle(AppColor.Text.normal)

            VStack(spacing: 19) {
                layerToggle("Predicted Route", symbol: "point.topleft.down.to.point.bottomright.curvepath", layer: .predictedPath)
                layerToggle("Water Temperature", symbol: "thermometer.variable", layer: .temperature)
                toggleRow("Visualize Temperature", symbol: "diamond.fill", isOn: $visualizeTemperature)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 19)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, minHeight: 219, maxHeight: 219, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 30)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 30)
                        .fill(AppColor.Fill.filterPanelSurface)
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 30)
                .stroke(AppColor.Stroke.light, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .shadow(color: AppColor.Shadow.light, radius: 20, y: 8)
    }

    private func layerToggle(_ title: String, symbol: String, layer: MapLayer) -> some View {
        toggleRow(title, symbol: symbol, isOn: Binding(
            get: { selectedLayers.contains(layer) },
            set: { enabled in
                if enabled { selectedLayers.insert(layer) }
                else { selectedLayers.remove(layer) }
            }
        ))
    }

    private func toggleRow(_ title: String, symbol: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColor.Icon.accent)
                .frame(width: 24)
            Text(title)
                .font(.custom("Helvetica", size: 16, relativeTo: .body))
                .foregroundStyle(AppColor.Text.normal)
            Spacer(minLength: 12)
            Toggle(title, isOn: isOn)
                .labelsHidden()
                .tint(AppColor.Fill.Button.accent)
        }
        .frame(height: 33)
    }
}

#Preview("Ocean Layer Menu") {
    @Previewable @State var layers: Set<MapLayer> = [.predictedPath]
    @Previewable @State var visualizeTemperature = false
    OceanLayerMenu(selectedLayers: $layers, visualizeTemperature: $visualizeTemperature)
        .padding()
        .background(AppColor.Preview.cyanBackdrop)
}
