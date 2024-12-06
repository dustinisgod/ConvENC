version=1.0.0

# Convergence Enchanter Bot Command Guide

### Start Script
- **Command:** `/lua run convenc`
- **Description:** Starts the Lua script Convergence Cleric.

## General Bot Commands
These commands control general bot functionality, allowing you to start, stop, or save configurations.

### Exit Bot
- **Command:** `/convenc exit`
- **Description:** Closes the bot’s GUI, effectively stopping any active commands.

### Enable Bot
- **Command:** `/convenc bot on`
- **Description:** Activates the bot, enabling it to start running automated functions.

### Disable Bot
- **Command:** `/convenc bot off`
- **Description:** Stops the bot from performing any actions, effectively pausing its behavior.

### Save Settings
- **Command:** `/convenc save`
- **Description:** Saves the current settings, preserving any configuration changes.

---

### Set Main Assist
- **Command:** `/convenc assist <name>`
- **Description:** Sets the main assist for the bot to follow in assisting with attacks.

### Set Assist Range
- **Command:** `/convenc assistRange <value>`
- **Description:** Specifies the distance within which the bot will assist the main assist's target.

### Set Assist Percent
- **Command:** `/convenc assistPercent <value>`
- **Description:** Sets the health percentage of the target at which the bot will begin assisting.

---

## Group or Raid Buff Control
These commands control who you want to buff.

### Set Buff Group
- **Command:** `/convenc buffgroup <on|off>`
- **Description:** Enables or disables group buffing for the current group members.

### Set Buff Raid
- **Command:** `/convenc buffraid <on|off>`
- **Description:** Enables or disables raid-wide buffing for all raid members.

---

## Other Utility Commands
Additional bot features to control epic use, meditating, and specific skills.

### Toggle Sit/Med
- **Command:** `/convenc sitmed <on|off>`
- **Description:** Allows the bot to enter sit/meditate mode for faster mana regeneration.

---

## Navigation Commands
Commands to control navigation settings and camping behavior.

### Set Camp Here
- **Command:** `/convenc camphere <distance|on|off>`
- **Description:** Sets the current location as the camp location, with optional distance.

### Enable Return to Camp
- **Command:** `/convenc camphere on`
- **Description:** Enables automatic return to camp when moving too far.

### Disable Return to Camp
- **Command:** `/convenc camphere off`
- **Description:** Disables automatic return to camp.

### Set Camp Distance
- **Command:** `/convenc camphere <distance>`
- **Description:** Sets the distance limit from camp before auto-return is triggered.
- **Usage:** Type `/convenc camphere 100`.

### Set Chase Target and Distance
- **Command:** `/convenc chase <target> <distance> | on | off`
- **Description:** Sets a target and distance for the bot to chase.
- **Usage:** Type `/convenc chase <target> <distance>` or `/convenc chase off`.
- **Example:** `/convenc chase John 30` will set the character John as the chase target at a distance of 30.
- **Example:** `/convenc chase off` will turn chasing off.

---
