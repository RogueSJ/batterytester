# Battery Tester - Professional Edition

A modern, industrial-grade Qt Quick application for downloading and analyzing battery test results from an ESP32-S3 based battery tester device.

![Battery Tester Application](docs/screenshot.png)

## Features

- **USB Device Communication**: Native C++ implementation using Qt SerialPort
- **Real-time Download**: Download test results from 6 battery channels via USB CDC
- **Data Visualization**: Interactive charts for voltage, current, and temperature
- **Modern UI**: Professional dark theme with industrial design
- **CSV Export**: Automatically saves test results as CSV files
- **Multi-channel**: Supports 6 independent battery test channels

## Architecture

### Backend (C++)
- **DeviceProtocol**: Low-level USB CDC protocol implementation (handshake, file transfer, checksums)
- **DeviceManager**: High-level device management with Qt threading for non-blocking operations
- **CsvDataModel**: CSV parsing and data model for chart visualization

### Frontend (QML)
- **Modern Industrial UI**: Dark theme with accent colors
- **Split View Layout**: Device controls on left, charts on right
- **Interactive Charts**: Qt Charts integration for real-time data visualization
- **Responsive Design**: Adaptive layout for different screen sizes

## Requirements

### Build Requirements
- Qt 6.8 or later
- CMake 3.16 or later
- C++17 compatible compiler
- Qt Modules:
  - Qt Quick
  - Qt SerialPort
  - Qt Charts

### Runtime Requirements
- USB CDC driver (automatically available on Linux/macOS, Windows needs driver)
- Permission to access serial ports (on Linux: add user to `dialout` group)

## Building the Project

### Qt Creator (Recommended for Development)

1. **Open the project**:
   ```
   File → Open File or Project → Select CMakeLists.txt
   ```

2. **Configure the kit**:
   - Select your Qt 6.8+ kit
   - Choose build directory (default: `build/`)
   - Click "Configure Project"

3. **Build**:
   - Press `Ctrl+B` or click the hammer icon
   - Or: Build → Build All

4. **Run**:
   - Press `Ctrl+R` or click the play icon
   - Or: Build → Run

### Command Line Build (Linux/macOS)

```bash
# Create build directory
mkdir build && cd build

# Configure with CMake
cmake .. -DCMAKE_PREFIX_PATH=/path/to/Qt/6.8.0/gcc_64

# Build
cmake --build .

# Run
./appbatterytester
```

### Command Line Build (Windows)

```powershell
# Create build directory
mkdir build
cd build

# Configure with CMake
cmake .. -DCMAKE_PREFIX_PATH=C:\Qt\6.8.0\msvc2022_64 -G "NMake Makefiles"

# Build
cmake --build .

# Run
appbatterytester.exe
```

### Windows Deployment

After building in Release mode on Windows:

```powershell
# Create deployment folder
mkdir deploy
copy build\Release\appbatterytester.exe deploy\

# Run windeployqt to gather all Qt dependencies
windeployqt --qmldir . --release deploy\appbatterytester.exe

# The deploy folder now contains the complete standalone application
```

### GitHub Actions (Automated Windows Build)

The project includes a GitHub Actions workflow for automated Windows builds:
- Push to `main`/`master` or create a tag to trigger builds
- Download artifacts from the Actions tab
- Tagged releases automatically create downloadable ZIP files

See `.github/workflows/build-windows.yml`

### Application Icon

The app icon is located at `resources/icons/app_icon.svg`.

To create the Windows ICO file:

**Option 1: Using ImageMagick (Linux)**
```bash
sudo apt install imagemagick
./create_icon.sh
```

**Option 2: Online converter**
1. Go to [cloudconvert.com/svg-to-ico](https://cloudconvert.com/svg-to-ico)
2. Upload `resources/icons/app_icon.svg`
3. Convert to ICO with sizes: 16, 24, 32, 48, 64, 128, 256
4. Save as `resources/app_icon.ico`

## Usage

### Connecting to Device

1. **Connect your battery tester** to the PC via USB
2. **Launch the application**
3. **Select the COM port** from the dropdown (e.g., `/dev/ttyACM0` on Linux, `COM3` on Windows)
4. **Click "Connect"**

### Downloading Test Results

1. **Ensure device is connected** (green indicator in header)
2. **Press the download button on the device** (triggers handshake)
3. **Click "Download Test Results"** in the application
4. **Wait for transfer** - progress bar shows download status
5. **Files appear** in the "Test Results Files" list

### Viewing Data

1. **Click on any file** in the left sidebar (e.g., `test_results_ch_1.csv`)
2. **Select data type**: Voltage, Current, or Temperature
3. **View chart** with interactive zoom and statistics
4. **Statistics panel** shows:
   - Total data points
   - Min/Max values
   - Current measurement type

### File Location

Downloaded files are saved to:
```
./received_files/
├── test_results_ch_1.csv
├── test_results_ch_2.csv
├── test_results_ch_3.csv
├── test_results_ch_4.csv
├── test_results_ch_5.csv
└── test_results_ch_6.csv
```

## CSV Format

Test result files use standard CSV format:

```csv
time,voltage,current,temperature
60,4.977,9.445,24.73
120,4.978,9.433,24.74
180,4.979,9.470,24.75
...
```

- **time**: Elapsed time in seconds
- **voltage**: Battery voltage in volts
- **current**: Load current in amperes
- **temperature**: Battery temperature in Celsius

## Protocol Details

The application implements a custom USB CDC protocol matching the ESP32 firmware:

### Packet Structure
```
Header (6 bytes):
  - Magic: 0xAA55 (2 bytes)
  - Command: 0x01-0x07 (1 byte)
  - Length: data length (2 bytes, little-endian)
  - Checksum: XOR checksum (1 byte)

Data (variable length):
  - Command-specific payload
```

### Commands
- `0x01`: HANDSHAKE - Device identification
- `0x02`: FILE_LIST - List of available files
- `0x03`: FILE_DATA - File info or chunk data
- `0x04`: FILE_END - End of file transfer
- `0x05`: ACK - Acknowledgment
- `0x06`: NACK - Negative acknowledgment

### Transfer Flow
1. PC opens serial port
2. Device sends HANDSHAKE
3. PC responds with ACK
4. Device sends FILE_LIST
5. PC responds with ACK
6. For each file:
   - Device sends FILE_DATA (file info)
   - PC responds with ACK
   - Device sends FILE_DATA (chunks)
   - PC responds with ACK for each chunk
7. Transfer complete

## Troubleshooting

### Linux: Permission Denied on Serial Port

Add your user to the `dialout` group:
```bash
sudo usermod -a -G dialout $USER
# Log out and log back in
```

### Windows: Device Not Recognized

Install the USB CDC driver:
1. Right-click device in Device Manager
2. Update Driver → Browse my computer
3. Select "USB Serial Device" or install ESP32-S3 driver

### Qt Charts Not Found

Ensure Qt Charts is installed:
```bash
# Qt Maintenance Tool
Qt Maintenance Tool → Add or remove components → Qt Charts
```

Or install via package manager:
```bash
# Ubuntu/Debian
sudo apt install qml-module-qtcharts

# Arch Linux
sudo pacman -S qt6-charts
```

### Build Errors in Qt Creator

1. **Clean build**:
   - Build → Clean All
   - Delete `build/` directory
   - Reconfigure CMake

2. **Check Qt version**:
   - Tools → Options → Kits
   - Ensure Qt 6.8+ is selected

3. **Missing modules**:
   - Install Qt SerialPort and Qt Charts via Qt Maintenance Tool

## Future Enhancements

- [ ] Integrate `usb_sender.py` functionality (upload settings to device)
- [ ] Multi-channel comparison view
- [ ] Export plots as images (PNG/SVG)
- [ ] Database storage for test history
- [ ] Advanced statistics (capacity calculation, energy, etc.)
- [ ] Custom theming options
- [ ] Report generation (PDF)

## Development

### Project Structure
```
batterytester/
├── CMakeLists.txt           # Build configuration
├── main.cpp                 # Application entry point
├── Main.qml                 # Main UI layout
├── deviceprotocol.h/cpp     # USB protocol implementation
├── devicemanager.h/cpp      # Device management (QObject)
├── csvdatamodel.h/cpp       # CSV parsing and data model
├── received_files/          # Downloaded test results
├── send_settings/           # Configuration files (future)
├── usb_receiver.py          # Reference Python implementation
└── usb_sender.py            # Reference Python implementation
```

### Adding New Features

1. **Backend** (C++):
   - Add methods to `DeviceManager`
   - Expose as `Q_INVOKABLE` or Q_PROPERTY
   - Emit signals for async operations

2. **Frontend** (QML):
   - Access via `deviceManager` or `csvModel`
   - Connect to signals for updates
   - Update UI accordingly

### Coding Style
- C++: Qt conventions, camelCase for methods
- QML: Qt Quick conventions, camelCase for properties
- Signals/Slots: Use new-style connections

## License

This project is part of the Battery Tester hardware/software suite. See LICENSE file for details.

## Support

For issues or questions:
- Open an issue on the repository
- Check the ESP32 firmware documentation
- Review the Python reference implementations (`usb_receiver.py`, `usb_sender.py`)

## Credits

- **Qt Framework**: Cross-platform application framework
- **ESP32-S3**: Microcontroller platform
- **Catppuccin**: Color scheme inspiration for modern industrial theme
