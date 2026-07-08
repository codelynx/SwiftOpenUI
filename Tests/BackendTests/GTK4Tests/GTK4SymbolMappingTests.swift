import XCTest
import SwiftOpenUISymbols

/// The catalog icons the librano pilot surfaced as placeholders must
/// resolve: SF names map to Material glyphs that exist in the Win32
/// codepoint table (GTK renders by ligature; Win32 needs the codepoint).
///
/// Own file, deliberately: this file + the `SwiftOpenUISymbols` test-target
/// dependency belong to the symbols commit, separate from the core
/// conditional-flattening commit (review condition: each commit compiles
/// and passes independently).
final class GTK4SymbolMappingTests: XCTestCase {
    func testPilotCatalogSymbolsResolve() {
        for sfName in ["building.2", "building.2.fill", "books.vertical", "books.vertical.fill",
                       "tag.fill", "lock.fill"] {
            let material = SFSymbolCompatibility.materialName(for: sfName)
            XCTAssertNotNil(material, "\(sfName) has no Material mapping")
            if let material {
                XCTAssertNotNil(MaterialSymbolsCodepoints.codepoint(for: material),
                                "\(material) missing from the Win32 codepoint table")
            }
        }
    }

    func testEveryMappedMaterialNameHasACodepoint() {
        for (sfName, material) in SFSymbolCompatibility.map {
            XCTAssertNotNil(
                MaterialSymbolsCodepoints.codepoint(for: material),
                "map entry \(sfName) → \(material) has no Win32 codepoint — add it to MaterialSymbolsCodepoints")
        }
    }
}
