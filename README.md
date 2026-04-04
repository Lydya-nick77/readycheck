<<<<<<< HEAD
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

## Usage

1. Load the addon:

   /addon load readycheck

2. Start a ready check:

   /readycheck

## Chat Messages

ReadyCheck uses these party messages:

- Trigger: `Are you ready? Sent by ReadyCheck`
- Yes: `I am ready - Sent by ReadyCheck`
- No: `I am not ready - Sent by ReadyCheck`
- Summary: `Players not ready: ...`

## Behavior Notes

- If a player does not answer in 30 seconds, their popup closes without sending No.
- On the sender side, non-responders are treated as not ready after timeout.
- Both windows use an XIDB-inspired style and disable title collapse.

## Customization

You can edit these values in `readycheck.lua`:

- Trigger/Yes/No message strings
- Timeout duration (currently 30 seconds)
- Sound file path (currently `sound\\levelup2.wav`)
=======
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

## Usage

1. Load the addon:

   /addon load readycheck

2. Start a ready check:

   /readycheck

## Chat Messages

ReadyCheck uses these party messages:

- Trigger: `Are you ready? Sent by ReadyCheck`
- Yes: `I am ready - Sent by ReadyCheck`
- No: `I am not ready - Sent by ReadyCheck`
- Summary: `Players not ready: ...`

## Behavior Notes

- If a player does not answer in 30 seconds, their popup closes without sending No.
- On the sender side, non-responders are treated as not ready after timeout.
- Both windows use an XIDB-inspired style and disable title collapse.

## Customization

You can edit these values in `readycheck.lua`:

- Trigger/Yes/No message strings
- Timeout duration (currently 30 seconds)
- Sound file path (currently `sound\\levelup2.wav`)
>>>>>>> a8732035a4db881e1a584cf6675d8db20ec0885d
