import AppKit
import Foundation

let svgContent = """
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <!-- 背景：深曜石钛金暗夜渐变 (Space Obsidian Titanium) -->
    <linearGradient id="bgGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#262A38"/>
      <stop offset="45%" stop-color="#181A24"/>
      <stop offset="100%" stop-color="#0C0D14"/>
    </linearGradient>

    <!-- 中心聚光灯 (Apple Spotlight) 烘托中枢空窗的深邃呼吸感 -->
    <radialGradient id="centerSpotlight" cx="512" cy="512" r="440" gradientUnits="userSpaceOnUse">
      <stop offset="0%" stop-color="#3A4056" stop-opacity="0.50"/>
      <stop offset="55%" stop-color="#202434" stop-opacity="0.15"/>
      <stop offset="100%" stop-color="#0C0D14" stop-opacity="0"/>
    </radialGradient>

    <!-- 顶部钛金玻璃边缘反光 -->
    <linearGradient id="topHighlight" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.22"/>
      <stop offset="40%" stop-color="#FFFFFF" stop-opacity="0.03"/>
      <stop offset="100%" stop-color="#000000" stop-opacity="0.28"/>
    </linearGradient>

    <!-- 纯白钛金 Deck 底座渐变 (中央方块) -->
    <linearGradient id="titaniumDeckGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#FFFFFF"/>
      <stop offset="100%" stop-color="#E5E8F2"/>
    </linearGradient>

    <!-- 日光珊瑚暖阳橙渐变 (Apple Ultra / Action Button 专属活力橙) -->
    <linearGradient id="coralOrange4D" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#FF764C"/>
      <stop offset="50%" stop-color="#FF562E"/>
      <stop offset="100%" stop-color="#E83818"/>
    </linearGradient>

    <!-- 全局精工柔影 (针对深曜暗灰底深度调配) -->
    <filter id="globalShadow" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="10" stdDeviation="12" flood-color="#000000" flood-opacity="0.6"/>
      <feDropShadow dx="0" dy="26" stdDeviation="28" flood-color="#000000" flood-opacity="0.75"/>
    </filter>

    <!-- 4 个珊瑚橙 D 叠压在钛金白底座上的精密切割微阴影 -->
    <filter id="dLayerShadow" x="-10%" y="-10%" width="120%" height="120%">
      <feDropShadow dx="0" dy="4" stdDeviation="5" flood-color="#000000" flood-opacity="0.55"/>
    </filter>

    <!-- 100% 完整大写字母 D (日光珊瑚橙，精密平直脊柱与饱满外弧) -->
    <g id="branchCoralD">
      <path d="
        M 588 436
        V 264
        C 588 252, 598 244, 610 244
        H 666
        C 756 244, 788 296, 788 350
        C 788 404, 756 436, 666 436
        H 588
        Z
      " fill="none" stroke="url(#coralOrange4D)" stroke-width="58" stroke-linejoin="round" stroke-linecap="square"/>
    </g>
  </defs>

  <!-- macOS 标准圆角矩形基底 (曜石钛金暗夜) -->
  <rect x="92" y="92" width="840" height="840" rx="195" fill="url(#bgGrad)"/>
  <rect x="92" y="92" width="840" height="840" rx="195" fill="url(#centerSpotlight)"/>
  <rect x="92" y="92" width="840" height="840" rx="195" fill="url(#topHighlight)" stroke="#FFFFFF" stroke-opacity="0.18" stroke-width="3"/>

  <!-- 精致工装 HUD 刻度环 (沉稳钛银微光) -->
  <g opacity="0.16">
    <circle cx="512" cy="512" r="320" fill="none" stroke="#FFFFFF" stroke-width="2" stroke-dasharray="14 14"/>
    <line x1="512" y1="164" x2="512" y2="184" stroke="#FFFFFF" stroke-width="3" stroke-linecap="round"/>
    <line x1="512" y1="840" x2="512" y2="860" stroke="#FFFFFF" stroke-width="3" stroke-linecap="round"/>
    <line x1="164" y1="512" x2="184" y2="512" stroke="#FFFFFF" stroke-width="3" stroke-linecap="round"/>
    <line x1="840" y1="512" x2="860" y2="512" stroke="#FFFFFF" stroke-width="3" stroke-linecap="round"/>
  </g>

  <!-- 主体 Command 4D 符号 (深曜工作站精工风格) -->
  <g filter="url(#globalShadow)">
    <!-- 1. 底层：纯白钛金 Deck 方框 (中空通透，作为坚固中枢底座) -->
    <rect x="436" y="436" width="152" height="152" fill="none" stroke="url(#titaniumDeckGrad)" stroke-width="58" stroke-linejoin="miter"/>

    <!-- 2. 表层：4 个日光珊瑚橙 D (90° 旋转无缝嵌合，活力拉满，极具辨识度) -->
    <g filter="url(#dLayerShadow)">
      <use href="#branchCoralD"/>
      <use href="#branchCoralD" transform="rotate(90, 512, 512)"/>
      <use href="#branchCoralD" transform="rotate(180, 512, 512)"/>
      <use href="#branchCoralD" transform="rotate(270, 512, 512)"/>
    </g>
  </g>
</svg>
"""

let outputDir = URL(fileURLWithPath: "Resources")
let svgURL = outputDir.appendingPathComponent("AppIcon.svg")
try! svgContent.write(to: svgURL, atomically: true, encoding: .utf8)

guard let svgData = svgContent.data(using: .utf8), let img = NSImage(data: svgData) else {
    print("❌ Failed to parse SVG")
    exit(1)
}

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: 1024,
    pixelsHigh: 1024,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
img.draw(in: NSRect(x: 0, y: 0, width: 1024, height: 1024))
NSGraphicsContext.restoreGraphicsState()

let masterPngURL = outputDir.appendingPathComponent("AppIcon_1024.png")
if let pngData = rep.representation(using: .png, properties: [:]) {
    try! pngData.write(to: masterPngURL)
}

// 自动生成 .iconset 并编译 AppIcon.icns
let iconsetDir = outputDir.appendingPathComponent("AppIcon.iconset")
let fm = FileManager.default
try? fm.removeItem(at: iconsetDir)
try? fm.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

let sizes: [(String, Int, Int)] = [
    ("icon_16x16.png", 16, 16),
    ("icon_16x16@2x.png", 32, 32),
    ("icon_32x32.png", 32, 32),
    ("icon_32x32@2x.png", 64, 64),
    ("icon_128x128.png", 128, 128),
    ("icon_128x128@2x.png", 256, 256),
    ("icon_256x256.png", 256, 256),
    ("icon_256x256@2x.png", 512, 512),
    ("icon_512x512.png", 512, 512),
    ("icon_512x512@2x.png", 1024, 1024)
]

for (filename, w, h) in sizes {
    let resizedRep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: w,
        pixelsHigh: h,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: resizedRep)
    img.draw(in: NSRect(x: 0, y: 0, width: w, height: h))
    NSGraphicsContext.restoreGraphicsState()
    if let data = resizedRep.representation(using: .png, properties: [:]) {
        try! data.write(to: iconsetDir.appendingPathComponent(filename))
    }
}

let icnsURL = outputDir.appendingPathComponent("AppIcon.icns")
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetDir.path, "-o", icnsURL.path]
try! process.run()
process.waitUntilExit()

try? fm.removeItem(at: iconsetDir)
print("✅ Space Obsidian Titanium & Coral Orange AppIcon.icns generated successfully!")
