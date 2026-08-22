import SwiftUI

enum AppColor {
    enum Primitive {
        enum Green {
            static let shade050 = color(red: 0.9215686321, green: 1, blue: 0.9882352941)
            static let shade100 = color(red: 0.8000000119, green: 1, blue: 0.9735293984)
            static let shade200 = color(red: 0.6000000238, green: 1, blue: 0.9470588565)
            static let shade300 = color(red: 0.4000000060, green: 1, blue: 0.9205882549)
            static let shade400 = color(red: 0.2000000030, green: 1, blue: 0.8941176534)
            static let shade500 = color(red: 0, green: 1, blue: 0.8676470518)
            static let shade600 = color(red: 0, green: 0.8000000119, blue: 0.6941176653)
            static let shade700 = color(red: 0, green: 0.6000000238, blue: 0.5215686560)
            static let shade800 = color(red: 0, green: 0.4000000060, blue: 0.3490196168)
            static let shade900 = color(red: 0, green: 0.2000000030, blue: 0.1725490242)
        }

        enum Red {
            static let shade050 = color(red: 1, green: 0.9137254953, blue: 0.8980392218)
            static let shade100 = color(red: 1, green: 0.8274509907, blue: 0.8000000119)
            static let shade200 = color(red: 1, green: 0.6549019814, blue: 0.6000000238)
            static let shade300 = color(red: 1, green: 0.4784313738, blue: 0.4000000060)
            static let shade400 = color(red: 1, green: 0.3058823645, blue: 0.2000000030)
            static let shade500 = color(red: 1, green: 0.1333333403, blue: 0)
        }

        enum Orange {
            static let shade050 = color(red: 1, green: 0.9568627477, blue: 0.8980392218)
            static let shade100 = color(red: 1, green: 0.9176470637, blue: 0.8000000119)
            static let shade200 = color(red: 1, green: 0.8352941275, blue: 0.6000000238)
            static let shade300 = color(red: 1, green: 0.7490196228, blue: 0.4000000060)
            static let shade400 = color(red: 1, green: 0.6666666865, blue: 0.2000000030)
            static let shade500 = color(red: 1, green: 0.5843137503, blue: 0)
        }

        enum Blue {
            static let shade500 = color(red: 0, green: 0.4784313725, blue: 1)
            static let shade600 = color(red: 0, green: 0.38, blue: 0.82)
        }

        enum Cyan {
            static let shade500 = color(red: 0.2, green: 0.86, blue: 1)
        }

        enum Yellow {
            static let shade500 = color(red: 1, green: 0.8, blue: 0)
        }

        enum Purple {
            static let shade500 = color(red: 0.6862745098, green: 0.3215686275, blue: 0.8705882353)
        }

        enum Indigo {
            static let shade500 = color(red: 0.3450980392, green: 0.3372549020, blue: 0.8392156863)
        }

        enum Common {
            static let shade000 = color(red: 1, green: 1, blue: 1)
            static let shade050 = color(red: 0.9764705896, green: 0.9843137264, blue: 0.9843137264)
            static let shade100 = color(red: 0.8901960850, green: 0.9098039269, blue: 0.9058823586)
            static let shade200 = color(red: 0.7803921700, green: 0.8196078539, blue: 0.8156862855)
            static let shade300 = color(red: 0.6705882549, green: 0.7294117808, blue: 0.7215686440)
            static let shade400 = color(red: 0.5607843399, green: 0.6392157078, blue: 0.6274510026)
            static let shade500 = color(red: 0.4509803951, green: 0.5490196347, blue: 0.5333333611)
            static let shade600 = color(red: 0.3607843220, green: 0.4392156899, blue: 0.4274509847)
            static let shade700 = color(red: 0.2705882490, green: 0.3294117749, blue: 0.3215686381)
            static let shade800 = color(red: 0.1803921610, green: 0.2196078449, blue: 0.2156862766)
            static let shade900 = color(red: 0.0800000000, green: 0.1200000000, blue: 0.1138461605)
        }
    }

    enum Fill {
        static let secondary = Primitive.Common.shade100
        static let elevatedSurface = Primitive.Common.shade000.opacity(0.28)
        static let resultCard = Primitive.Common.shade000.opacity(0.62)
        static let translucentControl = Primitive.Common.shade000.opacity(0.58)
        static let searchSheetSurface = Primitive.Common.shade000.opacity(0.74)
        static let filterPanelSurface = Primitive.Common.shade000.opacity(0.64)
        static let transparentOverlay = Primitive.Common.shade900.opacity(0)
        static let screenBackground = Primitive.Common.shade050

        enum OnMap {
            static let red = color(red: 1, green: 0.1333333403, blue: 0, opacity: 0.2000000029)
            static let orange = color(red: 1, green: 0.5843137503, blue: 0, opacity: 0.2000000029)
            static let green = color(red: 0, green: 0.8000000119, blue: 0.6941176653, opacity: 0.2000000029)
            static let unknown = Primitive.Common.shade500.opacity(0.18)
        }

        enum Button {
            static let accent = Primitive.Green.shade600
            static let normal = color(red: 1, green: 1, blue: 1, opacity: 0.5)
            static let normalSoft = Primitive.Common.shade000.opacity(0.42)
            static let normalMedium = Primitive.Common.shade000.opacity(0.58)
            static let normalStrong = Primitive.Common.shade000.opacity(0.72)
            static let normalRaised = Primitive.Common.shade000.opacity(0.74)
            static let border = Primitive.Common.shade000.opacity(0.68)
        }

        enum Comparison {
            static let goodCard = Primitive.Green.shade100.opacity(0.46)
            static let cautionCard = Primitive.Orange.shade100.opacity(0.45)
            static let highCard = Primitive.Red.shade100.opacity(0.42)
        }
    }

    enum Text {
        static let normal = Primitive.Common.shade900
        static let accent = Primitive.Green.shade600
        static let caption = Primitive.Common.shade500
        static let secondary = caption
        static let white = Primitive.Common.shade000
    }

    enum Icon {
        static let accent = Primitive.Green.shade600
        static let normal = Primitive.Green.shade050
        static let secondary = Primitive.Common.shade600
        static let warning = Primitive.Orange.shade500
    }

    enum Stroke {
        static let light = Primitive.Common.shade000.opacity(0.65)
        static let strongLight = Primitive.Common.shade000.opacity(0.9)
    }

    enum Shadow {
        static let light = Primitive.Common.shade900.opacity(0.12)
        static let medium = Primitive.Common.shade900.opacity(0.24)
        static let strong = Primitive.Common.shade900.opacity(0.55)
        static let topStrong = Primitive.Common.shade900.opacity(0.75)
        static let whiteGlow = Primitive.Common.shade000
    }

    enum Risk {
        static let good = Primitive.Green.shade600
        static let caution = Primitive.Orange.shade500
        static let high = Primitive.Red.shade500
        static let unknown = Primitive.Common.shade500
    }

    enum Map {
        static let routeHistory = Primitive.Common.shade000.opacity(0.9)
        static let beachedParticle = Primitive.Orange.shade500.opacity(0.26)
        static let error = Primitive.Orange.shade500
    }

    enum Preview {
        static let cyanBackdrop = color(red: 0.78, green: 0.94, blue: 1.0)
        static let lightCyanBackdrop = color(red: 0.75, green: 0.94, blue: 1.0)
        static let controlBackdrop = color(red: 0.68, green: 0.91, blue: 1.0)
        static let markerBackdrop = color(red: 0.72, green: 0.92, blue: 0.98)
    }

    enum LegacyTracker {
        static let navy = color(red: 0.02, green: 0.08, blue: 0.13)
        static let panel = color(red: 0.05, green: 0.18, blue: 0.23)
        static let cyan = Primitive.Cyan.shade500
        static let cream = Primitive.Orange.shade050
        static let coral = Primitive.Red.shade400
        static let seafoam = Primitive.Green.shade600
    }

    static func risk(_ risk: RiskLevel) -> Color {
        switch risk {
        case .good: AppColor.Risk.good
        case .caution: AppColor.Risk.caution
        case .later: AppColor.Risk.high
        case .unknown: AppColor.Risk.unknown
        }
    }

    private static func color(red: Double, green: Double, blue: Double, opacity: Double = 1) -> Color {
        Color(red: red, green: green, blue: blue).opacity(opacity)
    }
}
