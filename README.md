# ReadyCheck

ReadyCheck is an Ashita v4 addon for HorizonXI that runs a party/alliance ready check.

## Features

- Sends a ready check message to party chat.
- Shows a Yes/No popup for players who receive the check.
- Auto-closes the popup after 30 seconds if no answer is given.
- Shows a sender tracker window with party/alliance member status:
  - White = pending
  - Green = ready
  - Red = not ready
- At completion (all answered or timeout), announces not-ready players in party chat.
- Players **without** the addon can reply in party chat with `yes`, `no`, `/`, or `\` and be counted.

## Usage

1. Load the addon:

   /addon load readycheck

2. Start a ready check:

   /readycheck

3. Show or change the sound file:

   /readycheck sound
   /readycheck sound wow-readycheck.wav
   /readycheck sound C:\path\to\custom.wav

   If only a filename is given (no path separators), it is looked up in the addon's `sound\` folder.
   The setting is saved to `settings.txt` and restored automatically on reload.

## Chat Messages

ReadyCheck uses hidden marker strings for addon-to-addon communication, invisible to players without the addon. The trigger message includes a human-readable suffix so non-addon players know what is happening:

- Trigger: `[RC]check Are you ready?`
- Yes/No: hidden marker only (addon players only)
- Summary: `Players not ready: ...`

### Non-addon responses

While a ready check is active, the following plain party-chat messages are accepted from players who do not have the addon:

| Message | Result    |
|---------|-----------|
| `yes`   | Ready     |
| `no`    | Not ready |
| `/`     | Ready     |
| `\`     | Ready     |

## Behavior Notes

- If a player does not answer in 30 seconds, their popup closes without sending a reply.
- On the sender side, non-responders are treated as not ready after timeout.

## Customization

You can edit these values in `readycheck.lua`:

- `SOUND_ON_CHECKER` — play sound when you start a ready check (default: `true`)
- `SOUND_ON_PROMPT` — play sound when you receive a ready-check prompt (default: `true`)
- Timeout duration (currently 30 seconds)

The sound file path is configurable at runtime via `/readycheck sound` and persists across reloads.
