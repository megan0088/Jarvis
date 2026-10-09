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

Isi dengan URL tempat `docs/appstore/2026-10-09-privacy-policy.md` dipublikasikan.

---

## Catatan

- **Beta App Review** hanya dibutuhkan untuk penguji eksternal, dan biasanya selesai di
  bawah 24 jam. Penguji internal tidak melewati review sama sekali.
- Butir 5 dan 6 di "What to Test" menyentuh sisi Code dan fitur gambar, yang **belum pernah
  diverifikasi manual sampai tuntas** (lihat catatan eksekusi sub-project E dan G). Justru
  karena itu keduanya dicantumkan — penguji luar adalah mata pertama yang melihatnya.
