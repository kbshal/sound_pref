// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright © 2026 OpenSoundSource Contributors

import CoreAudio
import AudioToolbox
import Foundation

// MARK: - Core Audio Property Helpers

/// Errors that can occur during Core Audio operations.
enum CoreAudioError: Error, LocalizedError {
    case propertyNotSupported(AudioObjectID, AudioObjectPropertySelector)
    case getPropertyDataSizeFailed(OSStatus)
    case getPropertyDataFailed(OSStatus)
    case setPropertyDataFailed(OSStatus)
    case createTapFailed(OSStatus)
    case destroyTapFailed(OSStatus)
    case createAggregateFailed(OSStatus)
    case destroyAggregateFailed(OSStatus)
    case addListenerFailed(OSStatus)
    case removeListenerFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .propertyNotSupported(let id, let sel):
            return "Property \(fourCharString(sel)) not supported on object \(id)"
        case .getPropertyDataSizeFailed(let s):
            return "AudioObjectGetPropertyDataSize failed: \(s) (\(fourCharString(UInt32(bitPattern: s))))"
        case .getPropertyDataFailed(let s):
            return "AudioObjectGetPropertyData failed: \(s) (\(fourCharString(UInt32(bitPattern: s))))"
        case .setPropertyDataFailed(let s):
            return "AudioObjectSetPropertyData failed: \(s) (\(fourCharString(UInt32(bitPattern: s))))"
        case .createTapFailed(let s):
            return "AudioHardwareCreateProcessTap failed: \(s) (\(fourCharString(UInt32(bitPattern: s))))"
        case .destroyTapFailed(let s):
            return "AudioHardwareDestroyProcessTap failed: \(s)"
        case .createAggregateFailed(let s):
            return "AudioHardwareCreateAggregateDevice failed: \(s)"
        case .destroyAggregateFailed(let s):
            return "AudioHardwareDestroyAggregateDevice failed: \(s)"
        case .addListenerFailed(let s):
            return "AudioObjectAddPropertyListenerBlock failed: \(s)"
        case .removeListenerFailed(let s):
            return "AudioObjectRemovePropertyListenerBlock failed: \(s)"
        }
    }
}

/// Convert a FourCC UInt32 to a readable 4-character string.
func fourCharString(_ value: UInt32) -> String {
    let bytes: [UInt8] = [
        UInt8((value >> 24) & 0xFF),
        UInt8((value >> 16) & 0xFF),
        UInt8((value >> 8) & 0xFF),
        UInt8(value & 0xFF)
    ]
    if bytes.allSatisfy({ $0 >= 0x20 && $0 <= 0x7E }) {
        return String(bytes: bytes, encoding: .ascii) ?? "\(value)"
    }
    return "\(value)"
}

// MARK: - Generic Property Accessors

/// Get the value of a Core Audio property that returns a single value of type T.
func getAudioObjectProperty<T>(
    objectID: AudioObjectID,
    address: AudioObjectPropertyAddress
) throws -> T {
    var addr = address
    var dataSize = UInt32(MemoryLayout<T>.size)
    let value = UnsafeMutableRawPointer.allocate(
        byteCount: MemoryLayout<T>.size,
        alignment: MemoryLayout<T>.alignment
    )
    defer { value.deallocate() }

    let status = AudioObjectGetPropertyData(objectID, &addr, 0, nil, &dataSize, value)
    guard status == noErr else {
        throw CoreAudioError.getPropertyDataFailed(status)
    }
    return value.load(as: T.self)
}

/// Get a Core Audio property that returns an array of values of type T.
func getAudioObjectPropertyArray<T>(
    objectID: AudioObjectID,
    address: AudioObjectPropertyAddress
) throws -> [T] {
    var addr = address
    var dataSize: UInt32 = 0

    var status = AudioObjectGetPropertyDataSize(objectID, &addr, 0, nil, &dataSize)
    guard status == noErr else {
        throw CoreAudioError.getPropertyDataSizeFailed(status)
    }

    guard dataSize > 0 else { return [] }

    let count = Int(dataSize) / MemoryLayout<T>.size
    var array = [T](repeating: unsafeBitCast(0, to: T.self), count: count)

    status = AudioObjectGetPropertyData(objectID, &addr, 0, nil, &dataSize, &array)
    guard status == noErr else {
        throw CoreAudioError.getPropertyDataFailed(status)
    }

    // Recalculate count in case the size changed between calls
    let actualCount = Int(dataSize) / MemoryLayout<T>.size
    return Array(array.prefix(actualCount))
}

/// Get a Core Audio property that returns a CFString.
func getAudioObjectPropertyString(
    objectID: AudioObjectID,
    address: AudioObjectPropertyAddress
) throws -> String {
    var addr = address
    var dataSize = UInt32(MemoryLayout<CFString>.size)
    var value: CFString = "" as CFString

    let status = AudioObjectGetPropertyData(objectID, &addr, 0, nil, &dataSize, &value)
    guard status == noErr else {
        throw CoreAudioError.getPropertyDataFailed(status)
    }
    return value as String
}

/// Set a Core Audio property with a single value of type T.
func setAudioObjectProperty<T>(
    objectID: AudioObjectID,
    address: AudioObjectPropertyAddress,
    value: T
) throws {
    var addr = address
    var mutableValue = value
    let dataSize = UInt32(MemoryLayout<T>.size)

    let status = AudioObjectSetPropertyData(objectID, &addr, 0, nil, dataSize, &mutableValue)
    guard status == noErr else {
        throw CoreAudioError.setPropertyDataFailed(status)
    }
}

/// Check if a Core Audio property exists on an object.
func hasAudioObjectProperty(
    objectID: AudioObjectID,
    address: AudioObjectPropertyAddress
) -> Bool {
    var addr = address
    return AudioObjectHasProperty(objectID, &addr)
}

// MARK: - Property Address Builders

/// Create an AudioObjectPropertyAddress with common defaults.
func makePropertyAddress(
    selector: AudioObjectPropertySelector,
    scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
    element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(
        mSelector: selector,
        mScope: scope,
        mElement: element
    )
}

// MARK: - Property Listener Management

/// Token returned from adding a property listener, used for removal.
final class PropertyListenerToken: @unchecked Sendable {
    let objectID: AudioObjectID
    let address: AudioObjectPropertyAddress
    let queue: DispatchQueue
    let block: AudioObjectPropertyListenerBlock

    init(objectID: AudioObjectID, address: AudioObjectPropertyAddress,
         queue: DispatchQueue, block: @escaping AudioObjectPropertyListenerBlock) {
        self.objectID = objectID
        self.address = address
        self.queue = queue
        self.block = block
    }

    deinit {
        remove()
    }

    func remove() {
        var addr = address
        AudioObjectRemovePropertyListenerBlock(objectID, &addr, queue, block)
    }
}

/// Add a property listener block to a Core Audio object.
/// Returns a token that removes the listener when deallocated.
func addPropertyListener(
    objectID: AudioObjectID,
    address: AudioObjectPropertyAddress,
    queue: DispatchQueue = .main,
    block: @escaping AudioObjectPropertyListenerBlock
) throws -> PropertyListenerToken {
    var addr = address
    let status = AudioObjectAddPropertyListenerBlock(objectID, &addr, queue, block)
    guard status == noErr else {
        throw CoreAudioError.addListenerFailed(status)
    }
    return PropertyListenerToken(objectID: objectID, address: address, queue: queue, block: block)
}

// MARK: - Tap UID Helper

/// Get the UID string of a process tap from its AudioObjectID.
func getTapUID(tapID: AudioObjectID) throws -> String {
    let address = makePropertyAddress(
        selector: kAudioTapPropertyUID
    )
    return try getAudioObjectPropertyString(objectID: tapID, address: address)
}

// MARK: - Aggregate Device Keys

// These string constants are used when building the aggregate device description dictionary.
// They map to Core Audio's `kAudioAggregateDevice*Key` constants.

var kAggregateDeviceUIDKey: CFString { "uid" as CFString }
var kAggregateDeviceNameKey: CFString { "name" as CFString }
var kAggregateDeviceIsPrivateKey: CFString { "private" as CFString }
var kAggregateDeviceIsStackedKey: CFString { "stacked" as CFString }
var kAggregateDeviceTapListKey: CFString { "taps" as CFString }
var kAggregateDeviceTapUIDKey: CFString { "uid" as CFString }
var kAggregateDeviceMainSubDeviceKey: CFString { "master" as CFString }
