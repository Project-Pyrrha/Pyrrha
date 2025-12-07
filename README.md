# Pyrrha 1.2

## 📋 Features

### 🔫 Weapon
- **NoSpread**: Removes weapon spread for perfect accuracy.
- **NoReload**: Disables reloading animations.
- **Instant Crosshair**: Shows crosshair immediately when aiming.
- **Hitsound**: Plays a sound feedback upon damaging enemies.

### 👁️ Visuals (ESP)
- **Player ESP**: Box (Full/Corner styles), Skeleton, and Snap Lines.
- **Info Tags**: Name tags, Distance, Health & Armor bars.
- **Head Dot**: Visual indicator for head position.
- **Info Bar**: Displays FPS, Ping, Time, and Coordinates on screen.

### 🚗 Vehicle Manager
- **Speed Control**: Set target speeds, cruise control, and speed boost.
- **Drift Mode**: Configurable drift handling (Hold/Toggle/Always).
- **Handling Mods**: Perfect Handling, Tank Mode, Ground Stick.
- **Cheats**: GodMode Car, GM Wheels, AntiBoom, WaterDrive, FireCar.
- **Utilities**: Fix Wheels, Fast Exit, Gear Limit Remover.

### 🛠️ Miscellaneous
- **Player Cheats**: GodMode, AntiStun, NoFall, Infinite Oxygen.
- **Movement**: Mega Jump, BMX Mega Jump, QuickStop.
- **Network**: FakeAFK, FakeLag, Reconnect system.

## ⚙️ Requirements

Ensure you have **MoonLoader 0.26+** installed along with the following libraries:
- `SAMP.lua`
- `imgui`
- `vkeys`
- Standard libraries: `encoding`, `memory`, `ffi`, `lfs`

## 📥 Installation

1. Download the script.
2. Place `Pyrrha.lua` into your GTA San Andreas `moonloader` folder.
3. (Optional) Ensure `moonloader/resource/pyrrha/tick.mp3` exists for hitsounds.
4. Launch the game.

## 🎮 Usage

### Default Keybinds
| Key | Action |
| :--- | :--- |
| **U** | Toggle Main Menu |
| **F4** | Toggle ESP |
| **F5** | Toggle ESP Lines |
| **LShift** | Drift (Hold/Toggle) |
| **LCtrl** | Speed Boost |
| **O** | Toggle Speed Control |
| **P / L** | Increase / Decrease Target Speed |
| **F3** | AntiStun |
| **F9** | GodMode |
| **LShift + 0** | Reconnect |

*Note: All keybinds can be customized inside the **Keybinds** tab in the menu.*

## 💾 Configuration

Settings are saved automatically or manually via the menu.
- **Config Location**: `moonloader/config/Pyrrha/`
- **Profiles**: You can create, load, and delete multiple configuration profiles for different servers or playstyles.

## 📝 Credits

- **Author**: rmux
- **Version**: 1.1

---
*Disclaimer: Use at your own risk. This script contains features that may be banned on certain servers.*
