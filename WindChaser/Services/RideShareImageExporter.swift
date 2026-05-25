import SwiftUI
import UIKit

enum RideShareImageExporter {
    @MainActor
    static func exportPNG(summary: RideSummary, palette: ThemePalette) -> URL? {
        let card = RideShareCardView(summary: summary, palette: palette)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0

        guard let image = renderer.uiImage,
              let data = image.pngData() else {
            return nil
        }

        let fileName = "WindChaser-\(summary.startedAt.formatted(.dateTime.year().month().day().hour().minute())).png"
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: " ", with: "_")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
