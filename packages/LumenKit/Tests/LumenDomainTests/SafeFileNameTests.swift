import LumenDomain
import Testing

@Test(arguments: [
    ("IMG_0001.HEIC", "IMG_0001.HEIC"),
    ("../../etc/passwd", "passwd"),
    ("/etc/passwd", "passwd"),
    ("..\\..\\secret.txt", "secret.txt"),
    ("foto de mamá.jpg", "foto de mamá.jpg"),
])
func keepsOnlyASafeLastComponent(input: String, expected: String) {
    #expect(SafeFileName.sanitize(input) == expected)
}

@Test(arguments: ["", "..", ".", "/", "../", ".hidden", "a\u{0}b", "a\nb", String(repeating: "x", count: 300)])
func rejectsDangerousNames(input: String) {
    #expect(SafeFileName.sanitize(input) == nil)
}

@Test func anOfferAddsUpItsResources() {
    let offer = TransferOffer(transferID: 1, resources: [
        TransferResource(index: 0, fileName: "a.heic", byteCount: 10),
        TransferResource(index: 1, fileName: "a.mov", byteCount: 5),
    ])
    #expect(offer.totalBytes == 15)
}
