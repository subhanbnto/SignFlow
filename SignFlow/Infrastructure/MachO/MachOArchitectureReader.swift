import Foundation

enum MachOArchitectureReader {
    private static let machOMagic: UInt32 = 0xFEEDFACE
    private static let machOMagic64: UInt32 = 0xFEEDFACF
    private static let machOMagicSwapped: UInt32 = 0xCEFAEDFE
    private static let machOMagic64Swapped: UInt32 = 0xCFFAEDFE
    private static let fatMagic: UInt32 = 0xCAFEBABE
    private static let fatMagicSwapped: UInt32 = 0xBEBAFECA
    private static let fatMagic64: UInt32 = 0xCAFEBABF
    private static let fatMagic64Swapped: UInt32 = 0xBFBAFECA

    static func readArchitectures(at url: URL) throws -> [MachOArchitecture] {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        guard let magicData = try handle.read(upToCount: 4), magicData.count == 4 else {
            throw SignFlowError.unsupportedMachO(detail: "File too small to contain Mach-O header.")
        }

        let magic = magicData.withUnsafeBytes { $0.load(as: UInt32.self) }

        if magic == fatMagic || magic == fatMagicSwapped || magic == fatMagic64 || magic == fatMagic64Swapped {
            return try readFatBinary(handle: handle, magic: magic)
        } else if magic == machOMagic || magic == machOMagic64 || magic == machOMagicSwapped || magic == machOMagic64Swapped {
            return try readThinBinary(handle: handle, magic: magic)
        } else {
            throw SignFlowError.unsupportedMachO(detail: "Unrecognized binary format (magic: \(String(format: "0x%08X", magic))).")
        }
    }

    private static func readFatBinary(handle: FileHandle, magic: UInt32) throws -> [MachOArchitecture] {
        let swapped = (magic == fatMagicSwapped || magic == fatMagic64Swapped)
        let is64 = (magic == fatMagic64 || magic == fatMagic64Swapped)

        guard let countData = try handle.read(upToCount: 4), countData.count == 4 else {
            throw SignFlowError.unsupportedMachO(detail: "Could not read fat header arch count.")
        }

        var archCount = countData.withUnsafeBytes { $0.load(as: UInt32.self) }
        if swapped { archCount = archCount.byteSwapped }

        guard archCount < 20 else {
            throw SignFlowError.unsupportedMachO(detail: "Unreasonable architecture count: \(archCount).")
        }

        var architectures: [MachOArchitecture] = []
        let entrySize = is64 ? 32 : 20

        for _ in 0..<archCount {
            guard let entryData = try handle.read(upToCount: entrySize), entryData.count == entrySize else {
                break
            }
            var cpuType = entryData.withUnsafeBytes { $0.load(fromByteOffset: 0, as: Int32.self) }
            if swapped { cpuType = cpuType.byteSwapped }
            var cpuSubtype = entryData.withUnsafeBytes { $0.load(fromByteOffset: 4, as: Int32.self) }
            if swapped { cpuSubtype = cpuSubtype.byteSwapped }
            architectures.append(mapCPUType(cpuType, subtype: cpuSubtype))
        }

        return architectures
    }

    private static func readThinBinary(handle: FileHandle, magic: UInt32) throws -> [MachOArchitecture] {
        let swapped = (magic == machOMagicSwapped || magic == machOMagic64Swapped)

        guard let cpuData = try handle.read(upToCount: 8), cpuData.count == 8 else {
            throw SignFlowError.unsupportedMachO(detail: "Could not read Mach-O CPU type.")
        }

        var cpuType = cpuData.withUnsafeBytes { $0.load(fromByteOffset: 0, as: Int32.self) }
        var cpuSubtype = cpuData.withUnsafeBytes { $0.load(fromByteOffset: 4, as: Int32.self) }
        if swapped {
            cpuType = cpuType.byteSwapped
            cpuSubtype = cpuSubtype.byteSwapped
        }

        return [mapCPUType(cpuType, subtype: cpuSubtype)]
    }

    private static func mapCPUType(_ cpuType: Int32, subtype: Int32) -> MachOArchitecture {
        let subtypeMask: Int32 = 0x00FFFFFF
        let maskedSubtype = subtype & subtypeMask

        switch (cpuType, maskedSubtype) {
        case (0x0100000C, 2):  return .arm64e  // CPU_TYPE_ARM64 | CPU_SUBTYPE_ARM64E
        case (0x0100000C, _):  return .arm64
        case (0x01000007, _):  return .x86_64
        case (12, 9):         return .armv7
        case (12, 11):        return .armv7s
        case (12, _):         return .armv7
        default:              return .unknown
        }
    }

    static func isMachO(at url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url),
              let data = try? handle.read(upToCount: 4),
              data.count == 4 else {
            return false
        }
        try? handle.close()

        let magic = data.withUnsafeBytes { $0.load(as: UInt32.self) }
        let knownMagics: Set<UInt32> = [
            machOMagic, machOMagic64, machOMagicSwapped, machOMagic64Swapped,
            fatMagic, fatMagicSwapped, fatMagic64, fatMagic64Swapped
        ]
        return knownMagics.contains(magic)
    }
}
