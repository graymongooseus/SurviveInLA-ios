import Foundation

struct SeededRandomNumberGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    var checkpoint: UInt64 { state }

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    init(checkpoint: UInt64) {
        state = checkpoint
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}
