//
//  ChatMessage.swift
//  SharedCore
//

import Foundation

struct ChatMessage: Identifiable, Codable, Equatable {

    enum Role: String, Codable { case user, assistant }

    /// Data yang menempel pada pesan, supaya UI merender dari fakta — chip
    /// reminder tidak ditebak dari bunyi teks konfirmasi (spec B §6).
    enum Attachment: Codable, Equatable {
        case reminder(UUID)
    }

    /// Nasib jawaban. Kegagalan dan penghentian dicatat di sini, bukan
    /// ditulis sebagai teks peringatan di dalam isi pesan.
    enum Status: String, Codable {
        case complete
        case failed
        case stopped
    }

    let id: UUID
    let role: Role
    var text: String
    let date: Date
    var attachment: Attachment?
    var status: Status

    init(id: UUID = UUID(), role: Role, text: String, date: Date = .now,
         attachment: Attachment? = nil, status: Status = .complete) {
        self.id = id
        self.role = role
        self.text = text
        self.date = date
        self.attachment = attachment
        self.status = status
    }

    private enum CodingKeys: String, CodingKey {
        case id, role, text, date, attachment, status
    }

    /// Kunci baru boleh tidak ada: percakapan yang tersimpan sebelum B tetap
    /// terbaca. `encode(to:)` tetap disintesis.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        role = try container.decode(Role.self, forKey: .role)
        text = try container.decode(String.self, forKey: .text)
        date = try container.decode(Date.self, forKey: .date)
        attachment = try container.decodeIfPresent(Attachment.self, forKey: .attachment)
        status = try container.decodeIfPresent(Status.self, forKey: .status) ?? .complete
    }
}
