import LumenDomain
import Testing

@Test(arguments: [
    ("IMG_0001.HEIC", ["IMG_0001.HEIC"]),
    ("Proyecto/docs/a.pdf", ["Proyecto", "docs", "a.pdf"]),
    ("foto de mamá.jpg", ["foto de mamá.jpg"]),
    (".git/config", [".git", "config"]),
])
func keepsSafePaths(input: String, expected: [String]) {
    #expect(SafeRelativePath.components(of: input) == expected)
}

@Test(arguments: [
    "", "..", ".", "/", "/etc/passwd", "../evil", "a/../../evil", "a/./b", "a//b", "a/",
    "..\\evil", "a\u{0}b", "a\nb", "C:evil", String(repeating: "x", count: 300),
])
func rejectsDangerousPaths(input: String) {
    #expect(SafeRelativePath.components(of: input) == nil)
}

@Test func anOfferAddsUpItsResources() {
    let offer = TransferOffer(transferID: 1, resources: [
        TransferResource(index: 0, fileName: "a.heic", byteCount: 10),
        TransferResource(index: 1, fileName: "a.mov", byteCount: 5),
    ])
    #expect(offer.totalBytes == 15)
}
