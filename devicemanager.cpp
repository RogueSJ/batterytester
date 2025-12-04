#include "devicemanager.h"
#include <QSerialPortInfo>
#include <QDir>
#include <QMetaObject>
#include <QDebug>
#include <QTimer>

DeviceManager::DeviceManager(QObject *parent)
    : QObject(parent)
    , m_protocol(nullptr)
    , m_status("Ready")
    , m_isConnected(false)
    , m_progress(0)
    , m_outputDir("./received_files")
{
    // Create output directory if it doesn't exist
    QDir dir;
    if (!dir.exists(m_outputDir)) {
        dir.mkpath(m_outputDir);
    }

    // Create protocol in main thread (no moveToThread - simpler and safer)
    m_protocol = new DeviceProtocol(this);
    
    // Connect signals
    connect(m_protocol, &DeviceProtocol::errorOccurred,
            this, &DeviceManager::onProtocolError);
    connect(m_protocol, &DeviceProtocol::statusMessage,
            this, &DeviceManager::onProtocolStatus);
    connect(m_protocol, &DeviceProtocol::progressUpdated,
            this, &DeviceManager::onProtocolProgress);
    
    // Initial port refresh
    refreshPorts();
    updateReceivedFilesList();
}

DeviceManager::~DeviceManager()
{
    // Close any open connection
    if (m_protocol && m_protocol->isConnected()) {
        m_protocol->closePort();
    }
    // m_protocol will be deleted automatically as child of this
}

void DeviceManager::refreshPorts()
{
    m_availablePorts.clear();
    
    QList<QSerialPortInfo> ports = QSerialPortInfo::availablePorts();
    for (const QSerialPortInfo &portInfo : ports) {
        m_availablePorts.append(portInfo.portName());
    }
    
    emit availablePortsChanged();
}

bool DeviceManager::connectToDevice(const QString &portName)
{
    if (m_isConnected) {
        disconnectFromDevice();
    }

    setStatus("Connecting...");
    
    bool success = m_protocol->openPort(portName);
    
    if (success) {
        setConnected(true);
        setStatus(QString("Connected to %1").arg(portName));
    } else {
        setStatus("Failed to connect");
    }
    
    return success;
}

void DeviceManager::disconnectFromDevice()
{
    m_protocol->closePort();
    setConnected(false);
    setStatus("Ready");
}

void DeviceManager::startDownload()
{
    if (!m_isConnected) {
        emit errorOccurred("Not connected to device");
        return;
    }

    setStatus("Waiting for device...");
    setProgress(0);
    
    // Call directly - waitForHandshake() uses processEvents() for UI responsiveness
    doReceiveOperation();
}

void DeviceManager::receiveResults(const QString &portName)
{
    // Single-button operation: connect + wait for handshake + download
    if (portName.isEmpty()) {
        emit errorOccurred("No port selected");
        return;
    }
    
    setStatus("Opening port...");
    setProgress(0);
    
    // Open port first
    if (!m_protocol->openPort(portName)) {
        setStatus("Failed to open port");
        emit errorOccurred("Failed to open port");
        return;
    }
    
    setConnected(true);
    setStatus("Waiting for device to start transfer...");
    
    // Call directly - no QTimer! The waitForHandshake() function
    // already uses processEvents() to keep UI responsive.
    // QTimer::singleShot(0,...) creates a race condition where the device
    // sends handshake before we start listening.
    doReceiveOperation();
}

void DeviceManager::doReceiveOperation()
{
    // This runs the actual receive operation with proper error handling
    
    // Step 1: Wait for handshake FROM the ESP32 (device initiates!)
    if (!m_protocol->waitForHandshake()) {
        cleanupAfterError("Timeout - no response from device");
        return;
    }
    
    setStatus("Handshake OK, receiving file list...");
    
    // Step 2: Receive file list
    QStringList fileList = m_protocol->receiveFileList();
    if (fileList.isEmpty()) {
        cleanupAfterError("No files to receive or device disconnected");
        return;
    }
    
    // Step 3: Receive each file
    for (int i = 0; i < fileList.size(); ++i) {
        setStatus(QString("Receiving file %1/%2...").arg(i + 1).arg(fileList.size()));
        
        QString savedFilename;
        if (!m_protocol->receiveFile(m_outputDir, savedFilename)) {
            cleanupAfterError(QString("Failed at file %1 - device may have disconnected").arg(i + 1));
            return;
        }
    }
    
    // Step 4: Done - close port and report success
    m_protocol->closePort();
    setConnected(false);
    setStatus(QString("Complete: %1 files received!").arg(fileList.size()));
    setProgress(100);
    updateReceivedFilesList();
    emit downloadComplete();
}

void DeviceManager::cleanupAfterError(const QString &errorMessage)
{
    // Clean up after any error - ensure port is closed and state is reset
    qDebug() << "Cleanup after error:" << errorMessage;
    
    if (m_protocol->isConnected()) {
        m_protocol->closePort();
    }
    
    setConnected(false);
    setProgress(0);
    setStatus(errorMessage);
    emit errorOccurred(errorMessage);
}

QStringList DeviceManager::getReceivedFilesList()
{
    updateReceivedFilesList();
    return m_receivedFiles;
}

void DeviceManager::setSaveLocation(const QString &location)
{
    if (location.isEmpty()) return;
    
    m_outputDir = location;
    
    // Create output directory if it doesn't exist
    QDir dir;
    if (!dir.exists(m_outputDir)) {
        dir.mkpath(m_outputDir);
    }
    
    updateReceivedFilesList();
}

void DeviceManager::onProtocolError(const QString &error)
{
    setStatus(QString("Error: %1").arg(error));
    emit errorOccurred(error);
}

void DeviceManager::onProtocolStatus(const QString &message)
{
    qDebug() << "Protocol:" << message;
}

void DeviceManager::onProtocolProgress(int percentage, int bytesReceived, int totalBytes)
{
    setProgress(percentage);
    setStatus(QString("Receiving: %1% (%2/%3 bytes)")
              .arg(percentage)
              .arg(bytesReceived)
              .arg(totalBytes));
}

void DeviceManager::setStatus(const QString &status)
{
    if (m_status != status) {
        m_status = status;
        emit statusChanged();
    }
}

void DeviceManager::setConnected(bool connected)
{
    if (m_isConnected != connected) {
        m_isConnected = connected;
        emit isConnectedChanged();
    }
}

void DeviceManager::setProgress(int progress)
{
    if (m_progress != progress) {
        m_progress = progress;
        emit progressChanged();
    }
}

void DeviceManager::updateReceivedFilesList()
{
    QDir dir(m_outputDir);
    QStringList filters;
    filters << "*.csv";
    
    QStringList files = dir.entryList(filters, QDir::Files, QDir::Name);
    
    if (files != m_receivedFiles) {
        m_receivedFiles = files;
        emit receivedFilesChanged();
    }
}

void DeviceManager::sendSettings(const QString &portName, int planIndex, int current, int sampleRate, int duration, int minTemp, int maxTemp)
{
    qDebug() << "sendSettings called:" << portName << planIndex << current << sampleRate << duration << minTemp << maxTemp;
    
    // Validate parameters
    if (portName.isEmpty()) {
        setStatus("Error: No port selected");
        emit errorOccurred("No port selected");
        return;
    }
    
    if (planIndex < 1 || planIndex > 4) {
        setStatus("Error: Invalid plan index (must be 1-4)");
        emit errorOccurred("Invalid plan index");
        return;
    }
    
    // Validate ranges
    if (current < 1 || current > 500) {
        setStatus("Error: Current must be 1-500 mA");
        emit errorOccurred("Invalid current value");
        return;
    }
    
    if (sampleRate < 1 || sampleRate > 1000) {
        setStatus("Error: Sample rate must be 1-1000 minutes");
        emit errorOccurred("Invalid sample rate");
        return;
    }
    
    if (duration < 1 || duration > 1000) {
        setStatus("Error: Duration must be 1-1000 hours");
        emit errorOccurred("Invalid duration");
        return;
    }
    
    if (minTemp < -40 || minTemp > 85) {
        setStatus("Error: Min temp must be -40 to 85 °C");
        emit errorOccurred("Invalid min temperature");
        return;
    }
    
    if (maxTemp < -40 || maxTemp > 85) {
        setStatus("Error: Max temp must be -40 to 85 °C");
        emit errorOccurred("Invalid max temperature");
        return;
    }
    
    if (minTemp >= maxTemp) {
        setStatus("Error: Min temp must be less than max temp");
        emit errorOccurred("Min temp must be less than max temp");
        return;
    }
    
    setProgress(0);
    setStatus("Connecting to device...");
    
    // Step 1: Open port
    if (!m_protocol->openPort(portName)) {
        cleanupAfterError("Failed to open port - check connection");
        return;
    }
    
    setConnected(true);
    setStatus("Connected. Sending configuration to Plan " + QString::number(planIndex) + "...");
    
    // Step 2: Send config file (device is waiting for file info when in receive mode)
    if (!m_protocol->sendConfigFile(planIndex, current, sampleRate, duration, minTemp, maxTemp)) {
        cleanupAfterError("Failed to send configuration");
        return;
    }
    
    // Step 3: Done - close port and report success
    m_protocol->closePort();
    setConnected(false);
    setStatus(QString("Success! Plan %1 updated.").arg(planIndex));
    setProgress(100);
}
