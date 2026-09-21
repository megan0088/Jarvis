//
//  WorkspaceFile.swift
//  Apl
//
//  Satu berkas di folder kerja (spec E §5).
//

struct WorkspaceFile: Equatable, Identifiable, Hashable {
    let relativePath: String
    let byteCount: Int

    var id: String { relativePath }
    var name: String { relativePath.split(separator: "/").last.map(String.init) ?? relativePath }
}
