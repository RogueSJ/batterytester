# Future Implementation: Config Sender Integration

## Overview
This document outlines how to integrate the `usb_sender.py` functionality into the Qt application for uploading battery test settings to the device.

## Implementation Strategy

### Option A: Native C++ Port (Recommended)

Extend the existing `DeviceProtocol` class to support sending configuration files.

#### 1. Add to DeviceProtocol Class

```cpp
// deviceprotocol.h - Add new methods
public:
    bool sendConfigFile(const QString &filepath, quint8 fileIndex);
    bool sendFileInfo(const QString &filename, quint32 filesize, quint8 fileIndex);
    bool sendFileChunks(const QString &filepath, quint32 filesize);
    bool waitForAck(int timeoutMs);

// New signals
signals:
    void uploadProgressUpdated(int percentage, int bytesSent, int totalBytes);
```

#### 2. Implementation Pattern

The sender follows the reverse protocol:
1. PC sends file info (filename, size, index)
2. Wait for device ACK
3. Send file in 512-byte chunks
4. Wait for ACK after each chunk
5. Complete when all chunks sent

Key differences from receiver:
- PC initiates the transfer
- Device must be in "receive config" mode first
- Only one file sent at a time (setting_1.csv through setting_4.csv)

#### 3. Add to DeviceManager

```cpp
// devicemanager.h
public:
    Q_INVOKABLE void uploadConfigFile(const QString &filepath);
    Q_INVOKABLE QStringList getAvailableConfigs();
    
signals:
    void uploadComplete();
    void uploadProgress(int percentage);
```

#### 4. QML UI Extension

Add a new section in Main.qml:

```qml
GroupBox {
    title: "Configuration Upload"
    
    ColumnLayout {
        ComboBox {
            id: configFileCombo
            model: getConfigFiles() // setting_1.csv to setting_4.csv
        }
        
        Button {
            text: "Upload Settings"
            enabled: deviceManager.isConnected
            onClicked: {
                deviceManager.uploadConfigFile("./send_settings/" + configFileCombo.currentText)
            }
        }
        
        ProgressBar {
            value: deviceManager.uploadProgress / 100.0
        }
    }
}
```

### Option B: Python Process Bridge (Quick Implementation)

Use QProcess to call the existing Python script.

#### Advantages
- Minimal code changes
- Reuses tested Python implementation
- Quick to implement

#### Disadvantages
- Requires Python runtime on target system
- Less integrated experience
- Harder to provide real-time progress

#### Implementation

```cpp
// devicemanager.h
private:
    QProcess *m_senderProcess;

// devicemanager.cpp
void DeviceManager::uploadConfigViaPython(const QString &configFile) {
    m_senderProcess = new QProcess(this);
    
    connect(m_senderProcess, &QProcess::readyReadStandardOutput, this, [this]() {
        QString output = m_senderProcess->readAllStandardOutput();
        // Parse output for progress updates
        emit uploadProgress(parseProgress(output));
    });
    
    connect(m_senderProcess, QOverload<int>::of(&QProcess::finished),
            this, [this](int exitCode) {
        if (exitCode == 0) {
            emit uploadComplete();
        } else {
            emit errorOccurred("Upload failed");
        }
    });
    
    QStringList args;
    args << "usb_sender.py" << "--port" << portName() 
         << "--config-dir" << "./send_settings";
    
    m_senderProcess->start("python3", args);
}
```

## Protocol Implementation Details

### Send File Info Packet

```cpp
bool DeviceProtocol::sendFileInfo(const QString &filename, 
                                   quint32 filesize, 
                                   quint8 fileIndex)
{
    QByteArray data;
    QDataStream stream(&data, QIODevice::WriteOnly);
    stream.setByteOrder(QDataStream::LittleEndian);
    
    // Pack: file_index(1) + file_size(4) + filename(64)
    stream << fileIndex;
    stream << filesize;
    
    QByteArray filenameBytes = filename.toUtf8().leftJustified(64, '\0', true);
    data.append(filenameBytes);
    
    // Build packet
    QByteArray packet;
    QDataStream packetStream(&packet, QIODevice::WriteOnly);
    packetStream.setByteOrder(QDataStream::LittleEndian);
    
    packetStream << USB_PROTO_MAGIC;
    packetStream << USB_PROTO_CMD_FILE_DATA;
    packetStream << static_cast<quint16>(data.size());
    packetStream << calculateChecksum(data);
    
    packet.append(data);
    
    m_serialPort->write(packet);
    m_serialPort->flush();
    
    return waitForAck(5000);
}
```

### Send File Chunks

```cpp
bool DeviceProtocol::sendFileChunks(const QString &filepath, quint32 filesize)
{
    QFile file(filepath);
    if (!file.open(QIODevice::ReadOnly)) {
        emit errorOccurred("Failed to open config file");
        return false;
    }
    
    int chunkNumber = 0;
    int totalSent = 0;
    
    while (totalSent < static_cast<int>(filesize)) {
        QByteArray chunkData = file.read(USB_CHUNK_SIZE);
        if (chunkData.isEmpty()) {
            break;
        }
        
        quint16 chunkSize = chunkData.size();
        
        // Build chunk packet
        QByteArray data;
        QDataStream stream(&data, QIODevice::WriteOnly);
        stream.setByteOrder(QDataStream::LittleEndian);
        
        stream << static_cast<quint16>(chunkNumber);
        stream << chunkSize;
        data.append(chunkData);
        
        // Build packet
        QByteArray packet;
        QDataStream packetStream(&packet, QIODevice::WriteOnly);
        packetStream.setByteOrder(QDataStream::LittleEndian);
        
        packetStream << USB_PROTO_MAGIC;
        packetStream << USB_PROTO_CMD_FILE_DATA;
        packetStream << static_cast<quint16>(data.size());
        packetStream << calculateChecksum(data);
        
        packet.append(data);
        
        m_serialPort->write(packet);
        m_serialPort->flush();
        
        if (!waitForAck(5000)) {
            emit errorOccurred(QString("Failed to get ACK for chunk %1").arg(chunkNumber));
            return false;
        }
        
        totalSent += chunkSize;
        chunkNumber++;
        
        int progress = (totalSent * 100) / filesize;
        emit uploadProgressUpdated(progress, totalSent, filesize);
    }
    
    file.close();
    return true;
}
```

### Wait for ACK Helper

```cpp
bool DeviceProtocol::waitForAck(int timeoutMs)
{
    QElapsedTimer timer;
    timer.start();
    
    while (timer.elapsed() < timeoutMs) {
        if (!waitForData(100)) {
            continue;
        }
        
        PacketHeader header = readPacketHeader();
        if (!header.isValid()) {
            continue;
        }
        
        if (header.command == USB_PROTO_CMD_ACK) {
            // Read any remaining data
            if (header.length > 0) {
                readData(header.length, 1000);
            }
            return true;
        } else if (header.command == USB_PROTO_CMD_NACK) {
            return false;
        }
    }
    
    return false;
}
```

## Configuration File Format

Config files in `send_settings/` directory:
- `setting_1.csv` - Channel 1 test parameters
- `setting_2.csv` - Channel 2 test parameters
- `setting_3.csv` - Channel 3 test parameters
- `setting_4.csv` - Channel 4 test parameters

Expected format (example):
```csv
parameter,value
voltage_cutoff,3.0
current_load,10.0
duration,3600
temperature_limit,60
```

## UI/UX Considerations

### Upload Flow
1. User selects config file from dropdown
2. User presses "Receive Config" button on device
3. User clicks "Upload Settings" in app
4. App sends file to device
5. Progress bar shows upload status
6. Success/error notification

### Error Handling
- Device not in receive mode → Show error: "Device not ready. Press 'Receive Config' button."
- File not found → Show error: "Config file not found"
- Transfer timeout → Show error: "Upload timeout. Check device connection."
- Device NACK → Show error: "Device rejected transfer. Try again."

## Testing Plan

1. **Unit Tests**
   - Test packet construction
   - Test checksum calculation
   - Test file chunking logic

2. **Integration Tests**
   - Send small config file (< 512 bytes)
   - Send large config file (> 512 bytes)
   - Test error cases (disconnection, timeout)
   - Verify device receives correct data

3. **User Acceptance**
   - Upload all 4 config files
   - Verify device applies settings
   - Run battery test with new settings
   - Confirm test runs with expected parameters

## Implementation Priority

**Phase 1** (Immediate - Recommended):
- [ ] Implement native C++ sender methods in DeviceProtocol
- [ ] Add upload methods to DeviceManager
- [ ] Basic QML UI for file selection and upload

**Phase 2** (Polish):
- [ ] Config file editor/validator
- [ ] Preview config before upload
- [ ] Upload history/logging

**Phase 3** (Advanced):
- [ ] Batch upload (all channels at once)
- [ ] Config templates library
- [ ] Remote config management

## Estimated Effort

- **Native C++ Implementation**: 4-6 hours
  - DeviceProtocol extension: 2 hours
  - DeviceManager integration: 1 hour
  - QML UI: 1 hour
  - Testing: 1-2 hours

- **Python Bridge**: 2-3 hours
  - QProcess integration: 1 hour
  - Output parsing: 30 minutes
  - QML UI: 30 minutes
  - Testing: 1 hour

## Recommendation

**Use Option A (Native C++ Port)** because:
1. Consistent with existing architecture
2. Better user experience (no Python dependency)
3. Proper progress reporting
4. Easier to maintain and extend
5. Professional single-binary deployment

The implementation follows the same pattern as the receiver, just in reverse, making it straightforward to add.
