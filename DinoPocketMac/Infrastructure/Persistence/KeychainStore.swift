//
//  KeychainStore.swift
//  AplMac
//
//  Pembungkus tipis Keychain untuk rahasia kecil.
//
//  Identifier user dari Sign in with Apple disimpan di sini, bukan di
//  UserDefaults: UserDefaults tersimpan sebagai plist biasa yang bisa dibaca
//  proses lain milik user yang sama, sementara identifier itu kredensial.
//

import Foundation
import Security

enum KeychainStore {

    enum Failure: Error {
        case unexpectedStatus(OSStatus)
    }

    private static let service = "com.ega.apl.account"

    static func set(_ value: String, for key: String) throws {
        let data = Data(value.utf8)

        // Hapus dulu supaya `set` bersifat upsert, bukan gagal karena duplikat.
        SecItemDelete(query(for: key) as CFDictionary)

        var attributes = query(for: key)
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw Failure.unexpectedStatus(status) }
    }

    static func string(for key: String) -> String? {
        var q = query(for: key)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func remove(_ key: String) -> Bool {
        let status = SecItemDelete(query(for: key) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    private static func query(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }
}
