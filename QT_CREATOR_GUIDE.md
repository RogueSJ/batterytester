# Qt Creator Quick Start Guide

This guide helps you build and run the Battery Tester application in Qt Creator.

## Prerequisites

✅ **Qt 6.8 or later** installed with:
- Qt Quick
- Qt SerialPort  
- Qt Charts
- Desktop GCC/MSVC compiler

## Step-by-Step Setup

### 1. Open Project in Qt Creator

1. Launch **Qt Creator**
2. Click **File → Open File or Project...**
3. Navigate to `/home/saj/cute/qt_training/batterytester`
4. Select **CMakeLists.txt**
5. Click **Open**

### 2. Configure Build Kit

Qt Creator will show the "Configure Project" screen:

1. **Select your Kit** (should auto-detect):
   - ✅ Desktop Qt 6.8.0 GCC 64bit (or similar)
   - ✅ Desktop Qt 6.9.0 (if you have it)

2. **Build directory** (default is fine):
   - Usually: `build/Desktop_Qt_6_9_0-Debug/`

3. Click **Configure Project**

### 3. Build the Project

#### Option A: Toolbar (Fastest)
- Click the **🔨 Build** icon (hammer) in bottom-left
- Or press **Ctrl+B**

#### Option B: Menu
- **Build → Build All Projects**
- Or **Build → Build Project "batterytester"**

#### Build Output
You should see:
```
[ 16%] Building CXX object CMakeFiles/appbatterytester.dir/main.cpp.o
[ 33%] Building CXX object CMakeFiles/appbatterytester.dir/deviceprotocol.cpp.o
[ 50%] Building CXX object CMakeFiles/appbatterytester.dir/devicemanager.cpp.o
[ 66%] Building CXX object CMakeFiles/appbatterytester.dir/csvdatamodel.cpp.o
[ 83%] Linking CXX executable appbatterytester
[100%] Built target appbatterytester
```

### 4. Run the Application

#### Option A: Toolbar (Fastest)
- Click the **▶️ Run** icon (green play button) in bottom-left
- Or press **Ctrl+R**

#### Option B: Menu
- **Build → Run**

The application window should launch!

## First Run Test

### Without Device (UI Testing)

1. **Check UI loads** - You should see:
   - Header with "⚡ Battery Tester Pro"
   - Left sidebar with "Device Connection"
   - Right side with chart area
   - Dark modern industrial theme

2. **Test file loading**:
   - Existing CSV files in `received_files/` should appear in the file list
   - Click any file (e.g., `test_results_ch_1.csv`)
   - Chart should populate with voltage data
   - Try switching between Voltage/Current/Temperature

3. **Test port refresh**:
   - Click the 🔄 refresh button
   - Available serial ports appear in dropdown

### With Device Connected

1. **Connect device** to USB
2. **Select port** from dropdown (e.g., `/dev/ttyACM0`)
3. **Click "Connect"** button
4. **Status** should show "Connected to /dev/ttyACM0"
5. **Green indicator** in header bar

6. **Download test** (if device has data):
   - Press download button on device (enters send mode)
   - Click **"Download Test Results"** in app
   - Progress bar shows transfer
   - Files appear in sidebar when complete

## Common Issues & Solutions

### ❌ "Qt SerialPort: No such file or directory"

**Problem**: Qt SerialPort module not installed

**Solution**:
```bash
# Install via Qt Maintenance Tool
~/Qt/MaintenanceTool
# → Add or remove components
# → Qt 6.8.0 → Qt Serial Port

# Or via package manager (Linux):
sudo apt install libqt6serialport6-dev
```

### ❌ "Qt Charts: No such file or directory"

**Problem**: Qt Charts module not installed

**Solution**:
```bash
# Install via Qt Maintenance Tool
~/Qt/MaintenanceTool
# → Add or remove components
# → Qt 6.8.0 → Qt Charts

# Or via package manager (Linux):
sudo apt install libqt6charts6-dev qml-module-qtcharts
```

### ❌ "Cannot open serial port: Permission denied"

**Problem**: User doesn't have permission to access `/dev/ttyACM0`

**Solution** (Linux):
```bash
# Add user to dialout group
sudo usermod -a -G dialout $USER

# Log out and log back in (or reboot)
# Verify:
groups  # Should show 'dialout'
```

### ❌ Build fails with "No rule to make target"

**Problem**: CMake cache is stale

**Solution** in Qt Creator:
1. **Build → Clean All Projects**
2. Delete `build/` directory manually
3. **Build → Run CMake**
4. **Build → Build All Projects**

### ❌ Application crashes on startup

**Problem**: Likely QML import issue

**Solution**:
1. Check **Application Output** pane in Qt Creator
2. Look for QML errors like:
   - `module "QtCharts" is not installed`
   - `module "QtQuick.Controls" is not installed`
3. Install missing QML modules via Qt Maintenance Tool

### ⚠️ Warning: "QObject::connect: No such signal"

**Problem**: Signal/slot connection issue (usually harmless during development)

**Solution**: Check spelling in connections between C++ and QML

## Debugging Tips

### Enable QML Debugging

In Qt Creator:
1. **Projects** (left sidebar)
2. **Run** section
3. Enable **"Enable QML"** under Debugger Settings

### View Debug Output

**Application Output** pane shows:
- `qDebug()` messages from C++
- `console.log()` from QML
- Protocol status messages

Example output:
```
Protocol: "Waiting for handshake from device..."
Protocol: "Handshake received (version: 1, timestamp: 123456)"
Protocol: "File list received: 6 files"
Loaded 60 data points from ./received_files/test_results_ch_1.csv
```

### Breakpoint Debugging

1. **Set breakpoint**: Click left margin in code editor
2. **Debug mode**: Click 🐛 (bug icon) or press **F5**
3. **Step through**: F10 (over), F11 (into), Shift+F11 (out)

Good breakpoint locations:
- `DeviceManager::startDownload()` - When download starts
- `CsvDataModel::loadCsvFile()` - When CSV loads
- `DeviceProtocol::receiveFile()` - During file transfer

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Build | Ctrl+B |
| Run | Ctrl+R |
| Debug | F5 |
| Stop | Shift+F5 |
| Find | Ctrl+F |
| Switch Header/Source | F4 |
| Open file | Ctrl+K |
| Build & Run | Ctrl+Shift+R |

## Project Files Overview

### C++ Backend
- `main.cpp` - Entry point, creates DeviceManager and CsvDataModel
- `deviceprotocol.h/cpp` - USB protocol implementation (low-level)
- `devicemanager.h/cpp` - Device management (high-level, QML interface)
- `csvdatamodel.h/cpp` - CSV parsing and data model

### QML Frontend  
- `Main.qml` - Main window layout and UI

### Build Files
- `CMakeLists.txt` - CMake build configuration
- `build/` - Build output directory (auto-generated)

### Data Files
- `received_files/*.csv` - Downloaded test results
- `send_settings/*.csv` - Config files (for future upload feature)

## Next Steps

1. ✅ **Build successful** → Test with sample CSVs
2. ✅ **UI works** → Try connecting real device
3. ✅ **Download works** → Verify data integrity
4. 🔜 **Customize** → Modify colors, add features
5. 🔜 **Deploy** → Build release version for Windows

## Getting Help

- **Qt Creator**: Help → About Plugins → Check enabled plugins
- **Qt Docs**: Press F1 on any Qt class in code
- **Examples**: Help → Examples → Look for Qt Charts examples
- **Community**: forum.qt.io

## Build for Release (Optional)

When ready to deploy:

1. **Projects** (left sidebar)
2. Add **Release** build configuration
3. **Switch to Release** in build selector dropdown
4. **Build → Build All Projects**
5. Executable in `build/Desktop_Qt_6_9_0-Release/appbatterytester`

Happy coding! 🚀
