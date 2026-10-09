import AppKit
import Vision
import ImageIO

let imageURL = URL(fileURLWithPath: CommandLine.arguments[1])
let image = NSImage(contentsOf: imageURL)!
var rect = CGRect(origin: .zero, size: image.size)
let bitmap = image.cgImage(forProposedRect: &rect, context: nil, hints: nil)!
let orientations: [CGImagePropertyOrientation] = [.up, .right, .down, .left]
for orientation in orientations {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    try VNImageRequestHandler(cgImage: bitmap, orientation: orientation).perform([request])
    let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    if text.uppercased().contains("BUCKSHOT") || text.uppercased().contains("ROULETTE") {
        print(text)
        exit(0)
    }
}
fputs("Expected original game title in simulator screenshot\n", stderr)
exit(1)
