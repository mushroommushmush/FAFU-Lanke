import AppKit
import Foundation

// Render the same leaf.fill symbol used by the app and the supplied reference.
// No pre-rendered gloss: Icon Composer and iOS provide lighting and glass.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let icon = root.appendingPathComponent("FAFUCampus/AppIcon.icon")
let assets = root.appendingPathComponent("FAFUCampus/Assets.xcassets/AppIcon.appiconset")
let green = NSColor(srgbRed: 0.094, green: 0.337, blue: 0.247, alpha: 1)
let mint = NSColor(srgbRed: 0.60, green: 0.86, blue: 0.72, alpha: 1)
let light = NSColor(srgbRed: 0.949, green: 0.949, blue: 0.973, alpha: 1)
func render(color: NSColor, background: NSColor?, to url: URL) throws {
    guard let symbol = NSImage(systemSymbolName: "leaf.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 400, weight: .regular)
            .applying(NSImage.SymbolConfiguration(paletteColors: [color]))),
          let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
            bitsPerSample: 8, samplesPerPixel: background == nil ? 4 : 3, hasAlpha: background == nil, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
          let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        fatalError("Unable to render leaf icon")
    }
    bitmap.size = NSSize(width: 1024, height: 1024)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    (background ?? NSColor.clear).setFill()
    NSRect(x: 0, y: 0, width: 1024, height: 1024).fill()
    let width: CGFloat = 400
    let height = width * symbol.size.height / symbol.size.width
    symbol.draw(in: NSRect(x: (1024-width)/2, y: (1024-height)/2, width: width, height: height),
                from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("PNG encoding failed") }
    try png.write(to: url)
}
try render(color: green, background: nil, to: icon.appendingPathComponent("Assets/Leaf.png"))
try render(color: green, background: light, to: assets.appendingPathComponent("AppIcon.png"))
try render(color: mint, background: NSColor(srgbRed: 0.08, green: 0.12, blue: 0.10, alpha: 1),
           to: assets.appendingPathComponent("AppIcon-dark.png"))
try render(color: .white, background: .black, to: assets.appendingPathComponent("AppIcon-tinted.png"))
let jsonURL = icon.appendingPathComponent("icon.json")
var json = try JSONSerialization.jsonObject(with: Data(contentsOf: jsonURL)) as! [String: Any]
var groups = json["groups"] as! [[String: Any]]
var layers = groups[0]["layers"] as! [[String: Any]]
layers[0]["image-name"] = "Leaf.png"
groups[0]["layers"] = layers
json["groups"] = groups
try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]).write(to: jsonURL)
let images: [[String: Any]] = [
    ["filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"],
    ["filename": "AppIcon-dark.png", "idiom": "universal", "platform": "ios", "size": "1024x1024",
     "appearances": [["appearance": "luminosity", "value": "dark"]]],
    ["filename": "AppIcon-tinted.png", "idiom": "universal", "platform": "ios", "size": "1024x1024",
     "appearances": [["appearance": "luminosity", "value": "tinted"]]]
]
try JSONSerialization.data(withJSONObject: ["images": images, "info": ["author": "xcode", "version": 1]],
    options: [.prettyPrinted, .sortedKeys]).write(to: assets.appendingPathComponent("Contents.json"))
print("Rendered layered leaf icon and light/dark/tinted fallback assets")
