# Legacy — karakter SpriteKit 2D

Tidak ikut build (`excludes: ["Legacy/**"]` di `project.yml`).

Karakter 2D generasi pertama: `WalkingJarvisScene` (1.196 baris), `JarvisScene`,
`RobotStyle`. Digantikan karakter RealityKit 3D (`RobotCharacterView` + `Robot.usdz`).

Disimpan karena desain 3D belum final. Bila 2D dipanggil kembali, ia menjadi
implementasi kedua dari `CharacterPresenting` (Wave 1) — bukan dihidupkan kembali
apa adanya.

Untuk mengaktifkan sementara: hapus `Legacy/**` dari `excludes`, lalu `xcodegen generate`.

## Tautan menggantung yang perlu diketahui

`DinoPocketMac/Presentation/Views/ContentView.swift:75` masih mereferensikan
`JarvisScene`:

```swift
@State private var jarvisScene = JarvisScene(size: CGSize(width: 320, height: 320))
```

Keduanya sama-sama di luar build hari ini — `ContentView.swift` dibekukan bersama
jalur iOS, `JarvisScene` ada di sini. Jadi tidak ada yang rusak sekarang.

Tapi siapa pun yang menghidupkan kembali jalur iOS untuk spec companion iPhone akan
menabrak ini: ia harus memutuskan apakah karakter iOS memakai SpriteKit 2D atau
`CharacterPresenting` yang sama dengan Mac. Jawaban yang disarankan adalah yang kedua.
