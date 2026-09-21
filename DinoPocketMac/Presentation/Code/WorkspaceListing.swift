//
//  WorkspaceListing.swift
//  Apl
//
//  Menyaring isi folder jadi daftar yang masuk akal dibicarakan (spec E §5).
//
//  Murni: penelusuran disk terjadi di `CodeWorkspace`, aturan penyaringannya di
//  sini — supaya "apa yang dilewati" bisa dibuktikan tanpa folder sungguhan.
//

import Foundation

enum WorkspaceListing {

    struct Entry: Equatable {
        let relativePath: String
        let byteCount: Int
        var isDirectory = false
    }

    /// Folder yang isinya hasil generate, unduhan, atau riwayat — bukan tulisan
    /// yang akan dibicarakan seseorang.
    static let skippedDirectories: Set<String> = [
        ".git", ".build", ".swiftpm", "build", "DerivedData",
        "node_modules", "Pods", "Carthage", ".venv", "venv", "__pycache__",
    ]

    /// Di atas ini tidak akan pernah muat di konteks (spec E §4).
    static let maxFileBytes = 200_000

    static let textExtensions: Set<String> = [
        "swift", "m", "mm", "h", "hpp", "c", "cc", "cpp", "java", "kt", "go", "rs",
        "js", "jsx", "ts", "tsx", "py", "rb", "php", "sh", "zsh", "bash",
        "json", "yml", "yaml", "toml", "xml", "plist", "md", "txt", "css", "scss", "html", "sql",
    ]

    static func filter(_ entries: [Entry]) -> [WorkspaceFile] {
        entries
            .filter { !$0.isDirectory }
            .filter { entry in
                let parts = entry.relativePath.split(separator: "/").map(String.init)
                guard !parts.contains(where: { $0.hasPrefix(".") }) else { return false }
                guard !parts.dropLast().contains(where: skippedDirectories.contains) else { return false }
                guard entry.byteCount <= maxFileBytes else { return false }
                let ext = (entry.relativePath as NSString).pathExtension.lowercased()
                return textExtensions.contains(ext)
            }
            .map { WorkspaceFile(relativePath: $0.relativePath, byteCount: $0.byteCount) }
            .sorted { $0.relativePath < $1.relativePath }
    }
}
