# AppleMind — Naskah TestFlight (macOS)

Teks siap-tempel untuk **TestFlight → Test Information** di App Store Connect. Dua syarat
perangkat sengaja ditaruh di baris pertama "What to Test": tanpa itu, penguji akan
melaporkan keduanya sebagai bug, dan laporan palsu memakan waktu semua orang.

---

## Beta App Description

```
AppleMind is a small companion that lives on your Mac. Ask it anything, or tell it
"Remind me to stretch at 3 PM" in plain language and it will create the reminder for you.
A 3D robot on your desktop reacts to what's happening, and you can call it from anywhere
with a keyboard shortcut.

Everything runs on your Mac. There is no account, no server, and the app has no network
access at all — answers come from Apple Intelligence running on device.
```

## What to Test

```
BEFORE YOU START — two requirements:
• macOS 26 or later. Earlier versions cannot install this build.
• Chat needs Apple Intelligence turned on, on an Apple silicon Mac. Without it the app
  still runs and reminders still work, but every question answers "Apple Intelligence
  isn't available". That is expected, not a bug.

What we'd like you to try:
1. Say hi. Ask anything and watch the answer stream in.
2. Type "Remind me to stretch at 3 PM" — a reminder should be created, with a chip you can
   undo. Check that the notification actually fires.
3. Press ⌥Space from any app. A small bubble should appear next to the robot; ask one
   question there and close it with Esc.
4. Click the robot on your desktop.
5. Open the Code tab, choose a folder, attach a file, and ask about it.
6. Type "draw a small robot" to open Image Playground, and keep an image.
7. Settings → Erase All Data, and confirm everything is gone.

What we most want to hear:
• Anything that felt slow, confusing, or surprising.
• Answers that were wrong or cut off.
• Reminders that did not fire, or fired at the wrong time.
• Anything that looked broken in light mode, dark mode, or at large text sizes.
```

## Feedback Email

```
eganugrahaworkspace@gmail.com
```

## Privacy Policy URL

```
https://github.com/megan0088/Jarvis/blob/main/docs/appstore/2026-10-09-privacy-policy.md
```

## Beta App Review Information

Blok ini **wajib** untuk penguji eksternal dan letaknya di bawah pada halaman Test
Information — paling sering terlewat.

- **Sign-in required:** No. App ini tidak punya akun sama sekali.
- **Contact:** nama depan, nama belakang, nomor telepon, dan email pemilik akun. Nomor
  telepon diisi sendiri; tidak ada di repo ini.
- **Notes:** teks di bawah. Reviewer Apple kemungkinan menjalankannya di Mac tanpa Apple
  Intelligence; tanpa catatan ini, app yang menjawab "Apple Intelligence isn't available"
  akan terbaca sebagai app rusak.

```
AppleMind runs entirely on device. There is no account and no sign-in.

Please note two hardware requirements:
• macOS 26 or later.
• Chat answers come from Apple Intelligence, which needs an Apple silicon Mac with
  Apple Intelligence enabled in System Settings. On a Mac without it, the app still
  launches and reminders still work, but every question is answered with
  "Apple Intelligence isn't available yet". That message is the intended behaviour,
  not a failure.

Features that work without Apple Intelligence:
• Creating reminders from plain language, e.g. "Remind me to stretch at 3 PM",
  including the notification.
• The desktop companion, the keyboard shortcut, and Settings.

The app has no network entitlement and cannot make network connections.
```

---

## Catatan

- **Beta App Review** hanya dibutuhkan untuk penguji eksternal, dan biasanya selesai di
  bawah 24 jam. Penguji internal tidak melewati review sama sekali.
- Butir 5 dan 6 di "What to Test" menyentuh sisi Code dan fitur gambar, yang **belum pernah
  diverifikasi manual sampai tuntas** (lihat catatan eksekusi sub-project E dan G). Justru
  karena itu keduanya dicantumkan — penguji luar adalah mata pertama yang melihatnya.
