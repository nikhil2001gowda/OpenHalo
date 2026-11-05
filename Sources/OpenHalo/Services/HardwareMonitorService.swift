import Foundation
import Darwin

@MainActor
public final class HardwareMonitorService: ObservableObject {
    @Published public var cpuUsagePercent: Double = 0.0
    @Published public var memoryUsagePercent: Double = 0.0
    @Published public var usedMemoryGB: Double = 0.0
    @Published public var totalMemoryGB: Double = 0.0

    private var timer: Timer?
    private var previousCPULoad: host_cpu_load_info?

    public init() {
        totalMemoryGB = Double(ProcessInfo.processInfo.physicalMemory) / (1024.0 * 1024.0 * 1024.0)
        sampleMetrics()
    }

    public func startPolling(interval: TimeInterval = 2.0) {
        guard timer == nil else { return }
        sampleMetrics()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.sampleMetrics()
            }
        }
    }

    public func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    public func sampleMetrics() {
        updateCPUUsage()
        updateMemoryUsage()
    }

    private func updateCPUUsage() {
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        var cpuInfo = host_cpu_load_info()

        let result = withUnsafeMutablePointer(to: &cpuInfo) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPointer in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, intPointer, &count)
            }
        }

        guard result == KERN_SUCCESS else { return }

        if let prev = previousCPULoad {
            let userDiff = Double(cpuInfo.cpu_ticks.0 - prev.cpu_ticks.0)
            let sysDiff = Double(cpuInfo.cpu_ticks.1 - prev.cpu_ticks.1)
            let idleDiff = Double(cpuInfo.cpu_ticks.2 - prev.cpu_ticks.2)
            let niceDiff = Double(cpuInfo.cpu_ticks.3 - prev.cpu_ticks.3)

            let totalTicks = userDiff + sysDiff + idleDiff + niceDiff
            if totalTicks > 0 {
                let activeTicks = userDiff + sysDiff + niceDiff
                let percent = (activeTicks / totalTicks) * 100.0
                self.cpuUsagePercent = min(max(percent, 0.0), 100.0)
            }
        }

        previousCPULoad = cpuInfo
    }

    private func updateMemoryUsage() {
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var vmStat = vm_statistics64()

        let result = withUnsafeMutablePointer(to: &vmStat) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPointer in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPointer, &count)
            }
        }

        guard result == KERN_SUCCESS else { return }

        let pageSize = Double(vm_kernel_page_size)
        let activeBytes = Double(vmStat.active_count) * pageSize
        let wiredBytes = Double(vmStat.wire_count) * pageSize
        let compressedBytes = Double(vmStat.compressor_page_count) * pageSize

        let usedBytes = activeBytes + wiredBytes + compressedBytes
        let totalBytes = Double(ProcessInfo.processInfo.physicalMemory)

        self.usedMemoryGB = usedBytes / (1024.0 * 1024.0 * 1024.0)
        if totalBytes > 0 {
            self.memoryUsagePercent = min(max((usedBytes / totalBytes) * 100.0, 0.0), 100.0)
        }
    }
}

