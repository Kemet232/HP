import AppKit
import Foundation
let root = CommandLine.arguments[1]
func png(size: Int, path: String) {
    let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    let scale = CGFloat(size) / 1024
    context.scaleBy(x: scale, y: scale)
    context.setFillColor(CGColor(red: 0.06, green: 0.12, blue: 0.11, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
    context.setFillColor(CGColor(red: 0.22, green: 0.33, blue: 0.29, alpha: 1))
    context.addPath(CGPath(roundedRect: CGRect(x: 156, y: 390, width: 712, height: 244), cornerWidth: 90, cornerHeight: 90, transform: nil))
    context.fillPath()
    context.addPath(CGPath(roundedRect: CGRect(x: 178, y: 412, width: 464, height: 200), cornerWidth: 72, cornerHeight: 72, transform: nil))
    context.clip()
    let colors = [CGColor(red: 0.20, green: 0.69, blue: 0.43, alpha: 1), CGColor(red: 0.54, green: 0.92, blue: 0.67, alpha: 1)] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
    context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 412), end: CGPoint(x: 0, y: 612), options: [])
    let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
    try! bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}
let ios = root + "/Apple/Resources/Assets.xcassets/AppIcon.appiconset"
let watch = root + "/Apple/WatchResources/Assets.xcassets/AppIcon.appiconset"
try! FileManager.default.createDirectory(atPath: watch, withIntermediateDirectories: true)
png(size: 1024, path: ios + "/AppIcon.png")
func json(_ value: Any, _ path: String) { try! JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: path)) }
json(["images": [["filename":"AppIcon.png", "idiom":"universal", "platform":"ios", "size":"1024x1024"]], "info":["author":"xcode","version":1]], ios + "/Contents.json")
var images: [[String:String]] = []
let specs: [(String,String,String,String)] = [("24","2x","notificationCenter","38mm"),("27.5","2x","notificationCenter","42mm"),("29","2x","companionSettings",""),("29","3x","companionSettings",""),("40","2x","appLauncher","38mm"),("44","2x","appLauncher","40mm"),("46","2x","appLauncher","41mm"),("50","2x","appLauncher","44mm"),("51","2x","appLauncher","45mm"),("54","2x","appLauncher","49mm"),("86","2x","quickLook","38mm"),("98","2x","quickLook","42mm"),("108","2x","quickLook","44mm"),("117","2x","quickLook","45mm"),("129","2x","quickLook","49mm")]
for (size,scale,role,subtype) in specs {
 let pixels = Int(Double(size)! * Double(scale.prefix(1))!)
 let filename = "Icon-\(role)-\(subtype)-\(pixels).png"
 png(size:pixels, path:watch + "/" + filename)
 var item = ["filename":filename,"idiom":"watch","size":"\(size)x\(size)","scale":scale,"role":role]
 if !subtype.isEmpty { item["subtype"] = subtype }
 images.append(item)
}
png(size:1024,path:watch + "/Marketing.png")
images.append(["filename":"Marketing.png","idiom":"watch-marketing","size":"1024x1024","scale":"1x"])
json(["images":images,"info":["author":"xcode","version":1]],watch + "/Contents.json")
