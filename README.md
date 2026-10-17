# Nova_UI

A modern, dark-themed Roblox UI library built for Luau. Nova_UI is designed to look clean, premium, and easy to use for in-game menus, configuration panels, admin tools, and dashboards.

<p align="center">
  <img src="https://img.shields.io/badge/Language-Lua-2C2D72?logo=lua&logoColor=white" alt="Lua" />
  <img src="https://img.shields.io/badge/Platform-Roblox-000000?logo=roblox&logoColor=white" alt="Roblox" />
  <img src="https://img.shields.io/badge/Style-Dark%20UI-1F1F2E" alt="Dark UI" />
</p>

## Highlights

- Minimal dark gray interface with accent gradient colors
- Dynamic Island style collapsed window
- Left-side navigation rail
- Tab + section-based layout
- Built-in toggles, buttons, sliders, labels, and dropdowns
- Notification system with success / warning / error states
- Multiple theme presets: Neon, Crimson, Cyber, Toxic
- Resize and drag support for the window

## Demo

```lua
local NovaUI = require(game:GetService("ReplicatedStorage"):WaitForChild("NovaUI"))

NovaUI:SetTheme("Crimson")

local Window = NovaUI:CreateWindow({
    Title = "Nova UI",
    Version = "v1.0",
    Subtitle = "Control Center",
    Logo = "◈",
    ToggleKey = Enum.KeyCode.RightShift,
})

local Home = Window:AddTab({
    Name = "Home",
    Group = "Main",
    Icon = "🏠",
    Color = Color3.fromRGB(168, 85, 247),
})

local General = Home:AddSection({
    Title = "General",
    Description = "Core settings",
    Icon = "⚙️",
})

General:AddToggle({
    Title = "Enable effects",
    Description = "Toggle visual enhancements",
    Default = true,
    Callback = function(enabled)
        print("Effects:", enabled)
    end,
})

General:AddButton({
    Title = "Refresh",
    Description = "Refresh current state",
    ButtonText = "Run",
    Callback = function()
        print("Refresh clicked")
    end,
})

General:AddSlider({
    Title = "Volume",
    Description = "Adjust output level",
    Min = 0,
    Max = 100,
    Step = 1,
    Default = 70,
    Suffix = "%",
    Callback = function(value)
        print("Volume:", value)
    end,
})

local Settings = Window:AddTab({
    Name = "Settings",
    Group = "Config",
    Icon = "🧩",
})

local Tools = Settings:AddSection({
    Title = "Tools",
    Description = "Utility options",
})

Tools:AddDropdown({
    Title = "Theme",
    Description = "Choose display style",
    Options = { "Neon", "Crimson", "Cyber", "Toxic" },
    Default = "Neon",
    Callback = function(value)
        print("Selected theme:", value)
    end,
})
```

## Installation

### Roblox project setup

1. Place the file `NovaUI.lua` into a ModuleScript.
2. Name the ModuleScript `NovaUI`.
3. Require it from your LocalScript.

Example:

```lua
local NovaUI = require(game:GetService("ReplicatedStorage"):WaitForChild("NovaUI"))
```

You can also place it in `StarterPlayerScripts` or any shared module path you prefer.

## API overview

### Theme

```lua
NovaUI:SetTheme("Neon")
NovaUI:SetTheme({
    Accent = Color3.fromRGB(255, 45, 85),
    Accent2 = Color3.fromRGB(255, 122, 60),
})
```

### Window

```lua
local Window = NovaUI:CreateWindow({
    Title = "Nova UI",
    Version = "v1.0",
    Subtitle = "Dashboard",
    Logo = "◈",
    Size = Vector2.new(900, 620),
    ToggleKey = Enum.KeyCode.RightShift,
    Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"),
})
```

### Tab

```lua
local Tab = Window:AddTab({
    Name = "Debug",
    Group = "Tools",
    Icon = "🛠️",
    Color = Color3.fromRGB(0, 200, 255),
})
```

### Section

```lua
local Section = Tab:AddSection({
    Title = "Gameplay",
    Description = "Player settings",
    Icon = "🎮",
    Color = Color3.fromRGB(57, 255, 120),
})
```

### Widgets

```lua
Section:AddToggle({ Title = "Toggle", Default = false, Callback = function(v) end })
Section:AddButton({ Title = "Button", ButtonText = "Run", Callback = function() end })
Section:AddSlider({ Title = "Slider", Min = 0, Max = 100, Default = 25, Callback = function(v) end })
Section:AddLabel("This is a label")
Section:AddDropdown({
    Title = "Options",
    Options = { "A", "B", "C" },
    Default = "A",
    Callback = function(value) end,
})
```

## Available themes

```lua
NovaUI:SetTheme("Neon")
NovaUI:SetTheme("Crimson")
NovaUI:SetTheme("Cyber")
NovaUI:SetTheme("Toxic")
```

Preset palette:

- Neon: purple / cyan
- Crimson: red / orange
- Cyber: cyan / blue
- Toxic: green / lime

## Features details

- Window animations: open / close transitions with floating capsule mode
- Custom icon support: emoji, image asset URLs, avatar thumbnails, and player avatars
- Dropdown with single or multi-select support
- Notification toasts for user feedback
- Resize handles so the window can be adjusted like a desktop app
- Dynamic layout for smaller screens and mobile-friendly display

## Notes

This library is focused on a sleek modern design and a smooth user experience. It is especially suitable for admin panels, utility GUIs, and custom Roblox game interfaces.

## License

This project is provided as-is for personal and project use. Please respect the repository owner’s licensing terms if a license file is added later.

## Contact

If you want to improve or extend this library, feel free to open an issue or contribute via pull requests.
