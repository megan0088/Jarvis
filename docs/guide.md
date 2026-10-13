# AppleMind — User Guide

AppleMind is a small companion that lives on your Mac. Its character is called Apl.
Everything happens on this Mac: there is no account, no server, and the app has no network
access at all.

**Requirements:** macOS 26 or later. Chat needs Apple Intelligence turned on, on an Apple
silicon Mac. Reminders, the desktop character, and the shortcut all work without it.

---

## Talking to Apl

Type in the box at the bottom and press Return. The answer streams in as it is written.

- **⇧Return** adds a line break instead of sending.
- **Esc** stops an answer that is still being written. What was already written stays, marked
  *Stopped*.
- An answer that fails shows **Retry** — only on the most recent one, because a new answer
  always responds to your last message.
- **Conversation → Clear Conversation** forgets the chat. Your reminders stay.

Apl remembers this conversation across launches, but its memory is small — roughly the last
stretch of conversation, not everything you have ever said.

## Reminders

Write them the way you would say them:

```
Remind me to stretch at 3 PM
Remind me to take the bread out in 20 minutes
Remind me to water the plants every day at 9
```

Apl creates the reminder, shows a chip under its reply with the time, and lists it under
**Up next**. The chip has **Undo** for as long as the reminder is still ahead.

This never involves the model. Reminders work even with Apple Intelligence switched off —
which also means Apl will not "almost" create one: either it understood you, or it asks for
the time.

**If you deny notification permission,** reminders are still saved and listed, but nothing
will sound. Apl says so instead of pretending.

## The character on your desktop

Apl stands on your desktop above other windows and wanders slowly. Its face follows what is
happening: thinking while it answers, celebrating when a reminder is set, sleepy when this
Mac runs hot or the battery gets low.

- **Click it** to ask something without leaving the app you are in.
- **Hide Buddy** in the main window puts it away. **Esc** does the same when it has focus.
- Size, opacity, "keep on top", and wandering are in **Settings → Character**.

## Asking from any app

Press **⌥Space** anywhere and a small bubble opens next to the character. Whatever you ask
there joins the same conversation as the main window.

The shortcut can be changed or switched off in **Settings → Character**. It does not use the
Accessibility permission.

## When Apl speaks first

Apl occasionally says something without being asked — five minutes before a reminder, or
when this Mac is running hot or low on battery. That is the whole list.

It stays quiet when another app is full screen, when the screen is locked, and when you are
already in AppleMind. There is a daily limit, and balloons disappear on their own after a
few seconds; hovering keeps them. Click one to continue in the conversation.

You can have these spoken aloud in **Settings → Character**.

## The Code side

The **Code** tab is a separate conversation with its own memory, meant for code.

1. **Choose Folder** picks the folder you are working in.
2. Attach the files you want Apl to see. Small text files only — the context window is tiny,
   and the meter shows how much room is left.
3. Ask. Apl answers about the files you attached, not the whole project.

Apl can **write directly** to a file when you accept its suggestion. Three safety rules are
not negotiable: it never writes outside the folder you chose, it refuses when the file has
changed on disk since you attached it, and every write makes a backup so **Undo** can put it
back. Undo also refuses if the file changed again after the write.

## Images

Type `draw a small robot` — or use the photo menu next to the box — and Image Playground
opens with your idea filled in. Choose an image and it lands in the conversation, where it
stays. **Save** writes it anywhere you like.

The app keeps the most recent images only; older ones are removed when they fall out of the
conversation.

## Your data

Everything is stored on this Mac, inside the app's own container: conversations, reminders,
your nickname, images, and backups. Nothing is uploaded or synced.

**Settings → Privacy → Erase All Data** deletes all of it, cancels pending notifications, and
returns the app to its first-run state.

## What AppleMind does not do

Said plainly, so you do not go looking:

- **No sync.** There is no iPhone or iPad version, and nothing travels between devices.
- **No internet.** The app has no network entitlement; it cannot reach a server even in
  principle.
- **No accounts, no sign-in, no subscription.**
- Chat quality is whatever Apple's on-device model can do. It is small, it is fast, and it
  is not a cloud model.

## Something wrong?

Email **eganugrahaworkspace@gmail.com**, or send feedback straight from TestFlight if you
are testing a beta.
