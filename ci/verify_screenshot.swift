import AppKit
import Vision

let imageURL = URL(fileURLWithPath: CommandLine.arguments[1])
let image = NSImage(contentsOf: imageURL)!
var rect = CGRect(origin: .zero, size: image.size)
let bitmap = image.cgImage(forProposedRect: &rect, context: nil, hints: nil)!
let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
try VNImageRequestHandler(cgImage: bitmap).perform([request])
let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
print(text)
guard text.uppercased().contains("BUCKSHOT") || text.uppercased().contains("ROULETTE") else {
    fputs("Expected original game title in simulator screenshot\n", stderr)
    exit(1)
}

