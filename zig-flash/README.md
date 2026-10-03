# zig-flash

A utility for flashing UF2 firmware files to microcontrollers (like the Raspberry Pi Pico) by copying them to a USB mass storage device.

## Features

- **Automatic Detection**: Automatically finds the target USB drive by its volume label.
- **Cross-Platform**: Supports Windows, macOS, and Linux.
- **Wait Mode**: Waits for the drive to appear if it's not currently connected.
- **Configurable**: Allows specifying the input UF2 file and the target mount point or label.

## CLI Usage

```bash
zig-flash [input_path] [mount_point_or_label]
```

- **`input_path`**: Path to the UF2 file (default: `zig-out/firmware/firmware.uf2`).
- **`mount_point_or_label`**: The volume label or an absolute path to the mount point (default: `RPI-RP2`).

### Platform-Specific Detection

When a label is provided (like the default `RPI-RP2`), `zig-flash` searches for the drive as follows:
- **Windows**: Uses PowerShell to find the drive letter matching the label.
- **macOS**: Looks for the drive at `/Volumes/<label>`.
- **Linux**: Looks for the drive at `/run/media/$USER/<label>`.

If an absolute path is provided, `zig-flash` will wait for that specific path to become accessible.

## Integration in build.zig

First, add this project as a dependency:
```bash
zig fetch --save git+https://codeberg.org/OpenKeyboardCollective/zig-flash.git
```

Then add the following section to your `build.zig`:
```zig
const flash = @import("zig_flash");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ... your firmware build logic ...

    const flash_dep = b.dependency("zig_flash", .{
        .target = target,
        .optimize = optimize,
    });
    const flash_exe = flash_dep.artifact("zig_flash");

    _ = flash.addFlashStep(b, flash_exe, .{
        .input_name = "my-awesome-firmware.uf2", // Name of the UF2 file
        .input_path = "zig-out/firmware",        // Directory containing the UF2
        .mount_point_or_label = "RPI-RP2",       // Target drive label or path
    });
}
```

You can now flash your board by running:
```bash
zig build flash
```
