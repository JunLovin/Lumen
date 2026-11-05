import Darwin
import LumenApplication

public struct SystemClockAdapter: ClockPort {
    public init() {}

    public func nowNanoseconds() -> UInt64 {
        clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
    }
}
