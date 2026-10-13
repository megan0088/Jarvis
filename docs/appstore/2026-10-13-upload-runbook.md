# Mengunggah build ke App Store Connect — runbook

Ditulis setelah empat hari hilang karena satu pilihan di layar Organizer.

## Jebakan yang memakan empat hari

Build pertama AppleMind terunggah lewat Xcode Organizer dengan opsi
**"TestFlight Internal Testing Only"**. Akibatnya build itu bertanda
`buildAudienceType: INTERNAL_ONLY`, dan tanda itu **permanen** — API menolak
mengubahnya:

```
409 ENTITY_ERROR.ATTRIBUTE.NOT_ALLOWED
The attribute 'buildAudienceType' can not be included in a 'UPDATE' operation
```

Gejalanya menyesatkan: build tampil normal di internal testing, muncul di dialog
"Add Build" tab Distribution, dan statusnya hijau "Ready to Test". Yang gagal hanya
dialog grup eksternal, dengan pesan `No builds available` tanpa penjelasan apa pun.
Pesan sebenarnya hanya muncul lewat API:

```
ENTITY_UNPROCESSABLE.BUILD_NOT_ALLOWED_FOR_EXTERNAL_TESTING
Build audience doesn't allow to submission for App Review.
```

Yang diperiksa dan ternyata **bukan** penyebabnya: export compliance, Test
Information, URL kebijakan privasi, age rating, dan primary category. Semuanya tetap
perlu diisi untuk rilis — tidak satu pun menyelesaikan masalah ini.

## Cara yang benar: unggah dari terminal

Tidak ada kotak centang yang bisa salah pilih. `docs/appstore/upload-options.plist`
menyetel `testFlightInternalTestingOnly` ke `false` secara eksplisit.

```bash
# 1. Naikkan CURRENT_PROJECT_VERSION di project.yml — nomor build tidak boleh terulang
# 2. Arsipkan
xcodegen generate
xcodebuild archive -project DinoPocket.xcodeproj -scheme DinoPocketMac \
  -destination 'generic/platform=macOS' \
  -archivePath ~/Library/Developer/Xcode/Archives/$(date +%F)/AppleMind.xcarchive \
  -allowProvisioningUpdates

# 3. Unggah (butuh App Store Connect API key)
xcodebuild -exportArchive \
  -archivePath ~/Library/Developer/Xcode/Archives/$(date +%F)/AppleMind.xcarchive \
  -exportOptionsPlist docs/appstore/upload-options.plist \
  -allowProvisioningUpdates \
  -authenticationKeyPath ~/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8 \
  -authenticationKeyID XXXXXXXXXX \
  -authenticationKeyIssuerID 5ea822c1-19a6-4a01-8d4d-8afe78d37aaa
```

## Pastikan audience-nya benar SEBELUM menunggu

Setelah pemrosesan selesai, nilai yang harus terbaca adalah
`APP_STORE_ELIGIBLE` — bukan `INTERNAL_ONLY`. Memeriksanya butuh satu permintaan API;
kalau salah, satu-satunya obat adalah menaikkan nomor build dan mengunggah ulang.

## Identitas yang tidak bisa diubah

- Bundle id **`com.Jarvis.Ega`** — warisan era nama lama, dipakai record AppleMind
  (Apple ID 6820788573), dan permanen setelah rilis pertama.
- Nama App Store **AppleMind**; nama di Dock tetap **Apl**.
- Kunci `.p8` **jangan** disimpan di repo ini — repo ini publik.
