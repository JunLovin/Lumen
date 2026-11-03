import Accelerate

public struct MatchedFilter {
    private let template: [Float]

    public init(template: [Float]) {
        self.template = template
    }

    public func envelope(of signal: [Float]) -> [Float] {
        guard signal.count >= template.count, !template.isEmpty else { return [] }
        let count = Self.nextPowerOfTwo(signal.count + template.count)
        guard
            let forward = Self.transform(count: count, direction: .forward),
            let inverse = Self.transform(count: count, direction: .inverse)
        else { return [] }

        let signalSpectrum = Self.spectrum(of: signal, count: count, using: forward)
        let templateSpectrum = Self.spectrum(of: template, count: count, using: forward)
        var real = [Float](repeating: 0, count: count)
        var imaginary = real
        for bin in 1 ..< count / 2 {
            real[bin] = signalSpectrum.real[bin] * templateSpectrum.real[bin]
                + signalSpectrum.imaginary[bin] * templateSpectrum.imaginary[bin]
            imaginary[bin] = signalSpectrum.imaginary[bin] * templateSpectrum.real[bin]
                - signalSpectrum.real[bin] * templateSpectrum.imaginary[bin]
        }
        let analytic = Self.apply(inverse, real: real, imaginary: imaginary)
        let magnitudes = vDSP.hypot(analytic.real, analytic.imaginary)
        return Array(magnitudes[0 ... signal.count - template.count])
    }

    private static func transform(
        count: Int,
        direction: vDSP.FourierTransformDirection
    ) -> vDSP.DiscreteFourierTransform<Float>? {
        try? vDSP.DiscreteFourierTransform(
            count: count,
            direction: direction,
            transformType: .complexComplex,
            ofType: Float.self
        )
    }

    private static func spectrum(
        of samples: [Float],
        count: Int,
        using transform: vDSP.DiscreteFourierTransform<Float>
    ) -> (real: [Float], imaginary: [Float]) {
        let padded = samples + [Float](repeating: 0, count: count - samples.count)
        return apply(transform, real: padded, imaginary: [Float](repeating: 0, count: count))
    }

    private static func apply(
        _ transform: vDSP.DiscreteFourierTransform<Float>,
        real: [Float],
        imaginary: [Float]
    ) -> (real: [Float], imaginary: [Float]) {
        var outputReal = [Float](repeating: 0, count: real.count)
        var outputImaginary = outputReal
        transform.transform(
            inputReal: real,
            inputImaginary: imaginary,
            outputReal: &outputReal,
            outputImaginary: &outputImaginary
        )
        return (outputReal, outputImaginary)
    }

    private static func nextPowerOfTwo(_ value: Int) -> Int {
        1 << (Int.bitWidth - (value - 1).leadingZeroBitCount)
    }
}
