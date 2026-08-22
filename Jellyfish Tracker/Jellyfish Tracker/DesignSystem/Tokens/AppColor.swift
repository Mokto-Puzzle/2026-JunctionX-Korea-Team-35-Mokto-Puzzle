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

        enum OnMap {
            static let red = color(red: 1, green: 0.1333333403, blue: 0, opacity: 0.2000000029)
            static let orange = color(red: 1, green: 0.5843137503, blue: 0, opacity: 0.2000000029)
            static let green = color(red: 0, green: 0.8000000119, blue: 0.6941176653, opacity: 0.2000000029)
        }

        enum Button {
            static let accent = Primitive.Green.shade600
            static let normal = color(red: 1, green: 1, blue: 1, opacity: 0.5)
        }
    }

    enum Text {
        static let normal = Primitive.Common.shade900
        static let accent = Primitive.Green.shade600
        static let caption = Primitive.Common.shade500
        static let white = Primitive.Common.shade000
    }

    enum Icon {
        static let accent = Primitive.Green.shade600
        static let normal = Primitive.Green.shade050
    }

    private static func color(red: Double, green: Double, blue: Double, opacity: Double = 1) -> Color {
        Color(red: red, green: green, blue: blue).opacity(opacity)
    }
}
