import Foundation
@testable import KanaCore

/// Packs with status "planned" live next to their sources in packs/<lang>/, not in the
/// app. Their gates still run, against that file.
let parkedPacks: PackLibrary = {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    return PackLibrary(directory: root.appendingPathComponent("packs/zh-Hans"))
}()
