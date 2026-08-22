import SwiftUI

struct OceanLayerMenu: View {
    @Binding var selectedLayers: Set<MapLayer>
    @Binding var visualizeTemperature: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ocean Layers")
                .font(.custom("Helvetica-Bold", size: 12, relativeTo: .caption))
                .foregroundStyle(Color.jellyInk)
            layerToggle("Predicted Route", symbol: "point.topleft.down.to.point.bottomright.curvepath", layer: .predictedPath)
            layerToggle("Water Temperature", symbol: "thermometer.variable", layer: .temperature)
            Toggle(isOn: $visualizeTemperature) {
                Label("Visualize Temperature", systemImage: "field.of.view.wide.fill")
                    .foregroundStyle(Color.jellyInk)
            }
            .tint(Color.jellyMint)
            .font(.custom("Helvetica", size: 13, relativeTo: .body))
            .padding(.vertical, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 21)
                .fill(.ultraThinMaterial)
                .overlay(Color.white.opacity(0.60))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 21)
                .stroke(Color.white.opacity(0.65), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
    }

    private func layerToggle(_ title: String, symbol: String, layer: MapLayer) -> some View {
        Toggle(isOn: Binding(
            get: { selectedLayers.contains(layer) },
            set: { enabled in
                if enabled { selectedLayers.insert(layer) }
                else { selectedLayers.remove(layer) }
            }
        )) {
            Label(title, systemImage: symbol).foregroundStyle(Color.jellyInk)
        }
        .tint(Color.jellyMint)
        .font(.custom("Helvetica", size: 13, relativeTo: .body))
        .padding(.vertical, 4)
    }
}

#Preview("Ocean Layer Menu") {
    @Previewable @State var layers: Set<MapLayer> = [.predictedPath]
    @Previewable @State var visualizeTemperature = false
    OceanLayerMenu(selectedLayers: $layers, visualizeTemperature: $visualizeTemperature)
        .padding()
        .background(Color(red: 0.78, green: 0.94, blue: 1.0))
}
