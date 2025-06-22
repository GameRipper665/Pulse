# Pulse

**Pulse** is a lightweight, path-based module loader for Roblox that improves initial load times and memory usage by lazy-loading modules on demand using string paths. Pulse automatically scans and registers modules from `ReplicatedStorage` and `ServerScriptService`, respecting client, server, and shared boundaries.

---

## Features

- **Path-Based Module Loading**: Require modules with a simple string path, e.g., `"Services.DataService"`.
- **Lazy Loading**: Modules are only loaded when needed, not at startup.
- **Automatic Registration**: Modules are automatically scanned and registered from your game hierarchy.
- **Asset & Config Loading**: Automatically loads assets and configuration folders into accessible tables.
- **Debug Support**: Easily enable debug mode for verbose logging.
- **Client/Server Aware**: Only loads appropriate modules depending on whether running on the client or server.
- **Immutable API**: The Pulse API is frozen to prevent accidental modification.

---

## Usage

### 1. Installation

Copy `main.luau` from `src/ReplicatedStorage/Library/main.luau` into your project, or include the Pulse source folder as-is.

### 2. Folder Structure

Pulse expects your folders to be structured like this (at minimum):

```
ReplicatedStorage
└── Library
    ├── Modules
    │   └── Shared
    │       ├── ExampleModule.luau
    │       └── ...
    ├── Classes
    ├── Services
    ├── Handlers
    └── Configuration
ServerScriptService
└── Library
    ├── Classes
    ├── Services
    ├── Handlers
    └── Configuration
ReplicatedStorage
└── Assets
```

- **Modules/Shared**: Shared modules for both client and server.
- **Classes/Services/Handlers**: Server-side or client-side specific logic (depending on location).
- **Assets**: Any Roblox Instances/objects you want to load as assets.
- **Configuration**: Folders with `ValueBase` objects (e.g., `StringValue`, `IntValue`) for config loading.

### 3. Basic Example

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Pulse = require(ReplicatedStorage.Library.main)

-- Require a module by path
local DataService = Pulse:require("Services.DataService")

-- Access assets
local MyAsset = Pulse.assets.MyAssetName

-- Access config values
local MySetting = Pulse.config.MySetting
```

### 4. Enabling Debug Mode

Set the `_debug` property in your configuration folder (as a `BoolValue`) to enable debug logging:

```
ReplicatedStorage
└── Library
    └── Configuration
        └── _debug (BoolValue)
```

---

## API Reference

### `Pulse:require(modulePath: string): any`

Loads and returns the module for the given string path.
- Throws an error if the module is not found or cannot be loaded.

### `Pulse.assets: { [string]: Instance }`

A table containing all assets loaded from the `Assets` folder and its subfolders.

### `Pulse.config: { [string]: any }`

A table containing all configuration values loaded from `Configuration` folders.

### `Pulse._debug: boolean`

Whether debug mode is active (set via config).

---

## Advanced

- **Automatic Scanning**: On initialization, Pulse scans through the relevant folders (`Library`, `Modules.Shared`, `Classes`, `Services`, `Handlers`, `Assets`, `Configuration`) and registers all `ModuleScript` instances for easy path-based requiring.
- **Caching**: Once a module is loaded, it is cached for future use.
- **Error Handling**: If a module fails to load, an error is printed and rethrown with details.

---

## Contribution

Feel free to suggest improvements or open issues!

---

## License

MIT
