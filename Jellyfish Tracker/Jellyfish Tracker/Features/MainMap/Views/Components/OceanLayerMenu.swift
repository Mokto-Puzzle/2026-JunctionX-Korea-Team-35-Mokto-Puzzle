import SwiftUI

struct OceanLayerMenu: View {
    @Binding var selectedLayers: Set<MapLayer>
    @Binding var visualizeTemperature: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ocean Layers")
                .font(.custom("Helvetica-Bold", size: 12, relativeTo: .caption))
                .foregroundStyle(AppColor.Text.normal)
            layerToggle("Predicted Route", symbol: "point.topleft.down.to.point.bottomright.curvepath", layer: .predictedPath)
            layerToggle("Water Temperature", symbol: "thermometer.variable", layer: .temperature)
            Toggle(isOn: $visualizeTemperature) {
                Label("Visualize Temperature", systemImage: "field.of.view.wide.fill")
                    .foregroundStyle(AppColor.Text.normal)
            }
            .tint(AppColor.Text.accent)
            .font(.custom("Helvetica", size: 13, relativeTo: .body))
            .padding(.vertical, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 21)
                .fill(.ultraThinMaterial)
                .overlay(AppColor.Fill.translucentControl)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 21)
                .stroke(AppColor.Stroke.light, lineWidth: 1)
        }
        .shadow(color: AppColor.Shadow.light, radius: 20, y: 8)
    }

    private func layerToggle(_ title: String, symbol: String, layer: MapLayer) -> some View {
        Toggle(isOn: Binding(
            get: { selectedLayers.contains(layer) },
            set: { enabled in
                if enabled { selectedLayers.insert(layer) }
                else { selectedLayers.remove(layer) }
            }
        )) {
            Label(title, systemImage: symbol).foregroundStyle(AppColor.Text.normal)
        }
        .tint(AppColor.Text.accent)
        .font(.custom("Helvetica", size: 13, relativeTo: .body))
        .padding(.vertical, 4)
    }
}

#Preview("Ocean Layer Menu") {
    @Previewable @State var layers: Set<MapLayer> = [.predictedPath]
    @Previewable @State var visualizeTemperature = false
    OceanLayerMenu(selectedLayers: $layers, visualizeTemperature: $visualizeTemperature)
        .padding()
        .background(AppColor.Preview.cyanBackdrop)
}
