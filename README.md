# Arc Warden Omnislash Defense

An Umbrella Lua script that automatically responds to a nearby enemy Juggernaut's Omnislash with Arc Warden's Magnetic Field.

## Installation

1. Make sure the Umbrella client is installed and Dota 2 is closed or in a safe state for changing scripts.
2. [Download the script](https://raw.githubusercontent.com/melltonU/arcwarden-omnislash/main/arc_warden_omnislash.lua) and save it as `C:\Umbrella\scripts\arc_warden_omnislash.lua`.
3. Refresh/reload Umbrella's scripts (or restart the client) so it loads the new file.
4. In Umbrella's menu, open Arc Warden's settings—or, if those settings are unavailable, open **Scripts → Arc Warden Omni → Settings**—and enable **Auto Magnetic Field**. This option is off by default. Also make sure Arc Warden itself is enabled in the hero settings, if that toggle is present.
5. **Debug log** is enabled by default and can be toggled in the switch's **Options** gear.

## How it works

- While enabled and playing Arc Warden, the script checks about every 0.03 seconds for a living enemy Juggernaut entering Omnislash's ability phase.
- It triggers only when Arc Warden is within the Omnislash cast range plus its slash radius. For a detected cast, it attempts to cast a learned, castable Magnetic Field just behind Arc Warden, based on the hero's facing direction.
- If the local Arc Warden's Tempest Double is found, the script also attempts to place its Magnetic Field on the opposite side. The clone's field must be learned, castable, and within cast range; the script retries while the detected Omnislash event window remains open.
- That response window is based on Omnislash's cast point and duration, with a small additional margin. The script does not cast fields for other enemies or abilities.

## Options and troubleshooting

- **Auto Magnetic Field:** master switch; disabled by default. The script also observes Umbrella's Arc Warden hero-enable setting when available.
- **Debug log:** writes detection, readiness, activation, and clone-status messages to the Umbrella log. Disable it in **Options** if you do not need diagnostics.
- If no field is cast, check that the script and Arc Warden are enabled, Magnetic Field is learned and available, and the enemy is a Juggernaut starting Omnislash within the detection range. The Tempest Double's cast can additionally fail if it is unavailable or out of cast range.

The script uses Umbrella's Lua API and is intended for that runtime; API or game updates may affect behavior.
