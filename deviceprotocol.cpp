#include "deviceprotocol.h"
#include <QDataStream>
#include <QThread>
#include <QDebug>
#include <QFile>
#include <QElapsedTimer>
#include <QCoreApplication>

DeviceProtocol::DeviceProtocol(QObject *parent)
    : QObject(parent)
    , m_serialPort(new QSerialPort(this))
    , m_timeoutTimer(new QTimer(this))
{
    m_timeoutTimer->setSingleShot(true);
}

DeviceProtocol::~DeviceProtocol()
{
    closePort();
}

bool DeviceProtocol::openPort(const QString &portName, int baudrate)
{
    if (m_serialPort->isOpen()) {
        closePort();
    }

    m_serialPort->setPortName(portName);
    m_serialPort->setBaudRate(baudrate);
    m_serialPort->setDataBits(QSerialPort::Data8);
    m_serialPort->setParity(QSerialPort::NoParity);
    m_serialPort->setStopBits(QSerialPort::OneStop);
    m_serialPort->setFlowControl(QSerialPort::NoFlowControl);

    if (!m_serialPort->open(QIODevice::ReadWrite)) {
        emit errorOccurred(QString("Failed to open port %1: %2")
                          .arg(portName, m_serialPort->errorString()));
        return false;
    }

    // Clear any buffered data (like Python's reset_input_buffer/reset_output_buffer)
    m_serialPort->clear(QSerialPort::AllDirections);
    m_serialPort->flush();
    
    qDebug() << "Serial port opened:" << portName << "at" << baudrate << "baud";
    emit statusMessage(QString("Connected to %1").arg(portName));
    return true;
}

void DeviceProtocol::closePort()
{
    if (m_serialPort->isOpen()) {
        m_serialPort->close();
        emit statusMessage("Disconnected");
    }
}

bool DeviceProtocol::isConnected() const
{
    return m_serialPort && m_serialPort->isOpen();
}

QString DeviceProtocol::portName() const
{
    return m_serialPort ? m_serialPort->portName() : QString();
}

quint8 DeviceProtocol::calculateChecksum(const QByteArray &data) const
{
    quint8 checksum = 0;
    for (char byte : data) {
        checksum ^= static_cast<quint8>(byte);
    }
    return checksum;
}

void DeviceProtocol::sendAck()
{
    if (!m_serialPort->isOpen()) {
        qDebug() << "Cannot send ACK - port not open";
        return;
    }
    
    // Packet format: magic(2) + command(1) + length(2) + checksum(1)
    // For ACK: length=0, checksum of empty data = 0
    QByteArray packet;
    packet.reserve(6);
    
    // Little-endian magic (0xAA55)
    packet.append(static_cast<char>(USB_PROTO_MAGIC & 0xFF));        // 0x55
    packet.append(static_cast<char>((USB_PROTO_MAGIC >> 8) & 0xFF)); // 0xAA
    
    // Command
    packet.append(static_cast<char>(USB_PROTO_CMD_ACK));
    
    // Length (2 bytes, little-endian) = 0
    packet.append(static_cast<char>(0));
    packet.append(static_cast<char>(0));
    
    // Checksum of data (empty data = 0)
    packet.append(static_cast<char>(0));
    
    m_serialPort->write(packet);
    m_serialPort->flush();
    
    qDebug() << "Sent ACK:" << packet.toHex();
}

void DeviceProtocol::sendNack()
{
    if (!m_serialPort->isOpen()) {
        qDebug() << "Cannot send NACK - port not open";
        return;
    }
    
    // Packet format: magic(2) + command(1) + length(2) + checksum(1)
    QByteArray packet;
    packet.reserve(6);
    
    // Little-endian magic (0xAA55)
    packet.append(static_cast<char>(USB_PROTO_MAGIC & 0xFF));        // 0x55
    packet.append(static_cast<char>((USB_PROTO_MAGIC >> 8) & 0xFF)); // 0xAA
    
    // Command
    packet.append(static_cast<char>(USB_PROTO_CMD_NACK));
    
    // Length (2 bytes, little-endian) = 0
    packet.append(static_cast<char>(0));
    packet.append(static_cast<char>(0));
    
    // Checksum of data (empty data = 0)
    packet.append(static_cast<char>(0));
    
    m_serialPort->write(packet);
    m_serialPort->flush();
    
    qDebug() << "Sent NACK:" << packet.toHex();
}

bool DeviceProtocol::waitForData(int timeoutMs)
{
    QElapsedTimer timer;
    timer.start();
    
    while (timer.elapsed() < timeoutMs) {
        // Process Qt events to keep UI responsive
        QCoreApplication::processEvents(QEventLoop::AllEvents, 10);
        
        if (m_serialPort->bytesAvailable() > 0) {
            return true;
        }
        
        if (m_serialPort->waitForReadyRead(50)) {
            return true;
        }
        
        // Check if port is still valid
        if (!m_serialPort->isOpen()) {
            return false;
        }
    }
    return false;
}

QByteArray DeviceProtocol::readData(int length, int timeoutMs)
{
    QByteArray data;
    int totalRead = 0;
    QElapsedTimer timer;
    timer.start();
    
    while (totalRead < length && timer.elapsed() < timeoutMs) {
        // Process Qt events to keep UI responsive
        QCoreApplication::processEvents(QEventLoop::AllEvents, 10);
        
        // Check if port is still open
        if (!m_serialPort->isOpen()) {
            qDebug() << "Serial port closed during read";
            return data;
        }
        
        if (m_serialPort->bytesAvailable() > 0 || m_serialPort->waitForReadyRead(50)) {
            QByteArray chunk = m_serialPort->read(length - totalRead);
            if (chunk.isEmpty() && m_serialPort->error() != QSerialPort::NoError) {
                qDebug() << "Serial port error:" << m_serialPort->errorString();
                return data;
            }
            data.append(chunk);
            totalRead += chunk.size();
        }
        
        // Check for serial port errors
        if (m_serialPort->error() != QSerialPort::NoError && 
            m_serialPort->error() != QSerialPort::TimeoutError) {
            qDebug() << "Serial port error:" << m_serialPort->errorString();
            return data;
        }
    }
    
    return data;
}

PacketHeader DeviceProtocol::readPacketHeader()
{
    PacketHeader header = {0, 0, 0, 0};
    
    QByteArray headerData = readData(6, USB_TIMEOUT_MS);
    if (headerData.size() != 6) {
        emit errorOccurred(QString("Incomplete header received (got %1 bytes)").arg(headerData.size()));
        return header;
    }
    
    qDebug() << "Received header bytes:" << headerData.toHex();
    
    // Parse little-endian manually to avoid QDataStream issues
    header.magic = static_cast<quint8>(headerData[0]) | 
                   (static_cast<quint8>(headerData[1]) << 8);
    header.command = static_cast<quint8>(headerData[2]);
    header.length = static_cast<quint8>(headerData[3]) | 
                    (static_cast<quint8>(headerData[4]) << 8);
    header.checksum = static_cast<quint8>(headerData[5]);
    
    qDebug() << "Parsed header - magic:" << Qt::hex << header.magic 
             << "cmd:" << header.command 
             << "len:" << header.length 
             << "checksum:" << header.checksum;
    
    if (!header.isValid()) {
        emit errorOccurred(QString("Invalid magic number: 0x%1 (expected 0xAA55)").arg(header.magic, 4, 16, QChar('0')));
    }
    
    return header;
}

bool DeviceProtocol::waitForHandshake(int timeoutMs)
{
    emit statusMessage("Waiting for handshake from device...");
    
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
        
        if (header.command == USB_PROTO_CMD_HANDSHAKE) {
            QByteArray data = readData(header.length, USB_TIMEOUT_MS);
            if (data.size() != header.length) {
                emit errorOccurred("Incomplete handshake data");
                sendNack();
                continue;
            }
            
            quint8 calcChecksum = calculateChecksum(data);
            if (calcChecksum != header.checksum) {
                emit errorOccurred("Handshake checksum mismatch");
                sendNack();
                continue;
            }
            
            QDataStream stream(data);
            stream.setByteOrder(QDataStream::LittleEndian);
            quint8 version;
            quint32 timestamp;
            stream >> version >> timestamp;
            
            emit statusMessage(QString("Handshake received (version: %1, timestamp: %2)")
                              .arg(version).arg(timestamp));
            sendAck();
            return true;
        }
    }
    
    emit errorOccurred("Handshake timeout");
    return false;
}

QStringList DeviceProtocol::receiveFileList()
{
    emit statusMessage("Waiting for file list...");
    
    PacketHeader header = readPacketHeader();
    if (!header.isValid() || header.command != USB_PROTO_CMD_FILE_LIST) {
        emit errorOccurred("Expected FILE_LIST command");
        sendNack();
        return QStringList();
    }
    
    QByteArray data = readData(header.length, USB_TIMEOUT_MS);
    if (data.size() != header.length) {
        emit errorOccurred("Incomplete file list data");
        sendNack();
        return QStringList();
    }
    
    quint8 calcChecksum = calculateChecksum(data);
    if (calcChecksum != header.checksum) {
        emit errorOccurred("File list checksum mismatch");
        sendNack();
        return QStringList();
    }
    
    quint8 fileCount = static_cast<quint8>(data[0]);
    emit statusMessage(QString("File list received: %1 files").arg(fileCount));
    
    QStringList filenames;
    for (int i = 0; i < fileCount; ++i) {
        int offset = 1 + (i * 64);
        QByteArray filenameBytes = data.mid(offset, 64);
        int nullPos = filenameBytes.indexOf('\0');
        if (nullPos >= 0) {
            filenameBytes = filenameBytes.left(nullPos);
        }
        QString filename = QString::fromUtf8(filenameBytes);
        
        // Extract basename
        int lastSlash = filename.lastIndexOf('/');
        if (lastSlash >= 0) {
            filename = filename.mid(lastSlash + 1);
        }
        
        filenames.append(filename);
        emit statusMessage(QString("  [%1] %2").arg(i + 1).arg(filename));
    }
    
    sendAck();
    return filenames;
}

bool DeviceProtocol::receiveFile(const QString &outputDir, QString &savedFilename)
{
    emit statusMessage("Receiving file...");
    
    // Read file info header
    PacketHeader header = readPacketHeader();
    if (!header.isValid() || header.command != USB_PROTO_CMD_FILE_DATA) {
        emit errorOccurred("Expected FILE_DATA command");
        sendNack();
        return false;
    }
    
    QByteArray data = readData(header.length, USB_TIMEOUT_MS);
    if (data.size() != header.length) {
        emit errorOccurred("Incomplete file info data");
        sendNack();
        return false;
    }
    
    quint8 calcChecksum = calculateChecksum(data);
    if (calcChecksum != header.checksum) {
        emit errorOccurred("File info checksum mismatch");
        sendNack();
        return false;
    }
    
    // Parse file info
    QDataStream stream(data);
    stream.setByteOrder(QDataStream::LittleEndian);
    
    quint8 fileIndex;
    quint32 fileSize;
    stream >> fileIndex >> fileSize;
    
    QByteArray filenameBytes = data.mid(5, 64);
    int nullPos = filenameBytes.indexOf('\0');
    if (nullPos >= 0) {
        filenameBytes = filenameBytes.left(nullPos);
    }
    QString filename = QString::fromUtf8(filenameBytes);
    
    // Extract basename
    int lastSlash = filename.lastIndexOf('/');
    if (lastSlash >= 0) {
        filename = filename.mid(lastSlash + 1);
    }
    
    emit statusMessage(QString("File: %1 (index: %2, size: %3 bytes)")
                      .arg(filename).arg(fileIndex).arg(fileSize));
    
    sendAck(); // ACK file info
    
    // Receive file chunks
    QByteArray fileData;
    int chunkNumber = 0;
    int expectedChunks = (fileSize + USB_CHUNK_SIZE - 1) / USB_CHUNK_SIZE;
    
    while (fileData.size() < static_cast<int>(fileSize)) {
        header = readPacketHeader();
        if (!header.isValid() || header.command != USB_PROTO_CMD_FILE_DATA) {
            emit errorOccurred("Expected FILE_DATA chunk");
            sendNack();
            return false;
        }
        
        data = readData(header.length, USB_TIMEOUT_MS);
        if (data.size() != header.length) {
            emit errorOccurred("Incomplete chunk data");
            sendNack();
            return false;
        }
        
        calcChecksum = calculateChecksum(data);
        if (calcChecksum != header.checksum) {
            emit errorOccurred(QString("Chunk %1 checksum mismatch").arg(chunkNumber));
            sendNack();
            return false;
        }
        
        QDataStream chunkStream(data);
        chunkStream.setByteOrder(QDataStream::LittleEndian);
        
        quint16 recvChunkNum;
        quint16 chunkSize;
        chunkStream >> recvChunkNum >> chunkSize;
        
        if (recvChunkNum != chunkNumber) {
            emit errorOccurred(QString("Chunk number mismatch (expected %1, got %2)")
                              .arg(chunkNumber).arg(recvChunkNum));
            sendNack();
            return false;
        }
        
        QByteArray chunkData = data.mid(4, chunkSize);
        fileData.append(chunkData);
        chunkNumber++;
        
        sendAck(); // ACK chunk
        
        int progress = (fileData.size() * 100) / fileSize;
        emit progressUpdated(progress, fileData.size(), fileSize);
    }
    
    // Save file
    QString outputPath = outputDir + "/" + filename;
    QFile file(outputPath);
    if (!file.open(QIODevice::WriteOnly)) {
        emit errorOccurred(QString("Failed to save file: %1").arg(file.errorString()));
        return false;
    }
    
    file.write(fileData);
    file.close();
    
    savedFilename = filename;
    emit statusMessage(QString("File saved: %1").arg(outputPath));
    return true;
}

bool DeviceProtocol::sendConfigFile(int planIndex, int current, int sampleRate, int duration, int minTemp, int maxTemp)
{
    emit statusMessage("Preparing configuration data...");
    
    // Create CSV content: "current,sample rate,duration,min temp,max temp\n250,1,3,-20,30"
    QString csvContent = QString("current,sample rate,duration,min temp,max temp\n%1,%2,%3,%4,%5")
        .arg(current)
        .arg(sampleRate)
        .arg(duration)
        .arg(minTemp)
        .arg(maxTemp);
    
    QByteArray fileData = csvContent.toUtf8();
    quint32 fileSize = fileData.size();
    QString filename = QString("setting_%1.csv").arg(planIndex);
    
    emit statusMessage(QString("Sending file info: %1 (%2 bytes)").arg(filename).arg(fileSize));
    
    // Build file info packet: file_index(1) + file_size(4) + filename(64)
    QByteArray infoData;
    infoData.append(static_cast<char>(planIndex));  // file_index (1-4)
    
    // file_size (4 bytes, little-endian)
    infoData.append(static_cast<char>(fileSize & 0xFF));
    infoData.append(static_cast<char>((fileSize >> 8) & 0xFF));
    infoData.append(static_cast<char>((fileSize >> 16) & 0xFF));
    infoData.append(static_cast<char>((fileSize >> 24) & 0xFF));
    
    // filename (64 bytes, null-padded)
    QByteArray filenameBytes = filename.toUtf8().left(64);
    filenameBytes.append(QByteArray(64 - filenameBytes.size(), '\0'));
    infoData.append(filenameBytes);
    
    // Build packet header
    QByteArray packet;
    packet.append(static_cast<char>(USB_PROTO_MAGIC & 0xFF));
    packet.append(static_cast<char>((USB_PROTO_MAGIC >> 8) & 0xFF));
    packet.append(static_cast<char>(USB_PROTO_CMD_FILE_DATA));
    
    quint16 length = infoData.size();
    packet.append(static_cast<char>(length & 0xFF));
    packet.append(static_cast<char>((length >> 8) & 0xFF));
    
    quint8 checksum = calculateChecksum(infoData);
    packet.append(static_cast<char>(checksum));
    packet.append(infoData);
    
    // Send file info
    m_serialPort->write(packet);
    if (!m_serialPort->waitForBytesWritten(5000)) {
        emit errorOccurred("Failed to send file info");
        return false;
    }
    
    // Process events to keep UI responsive
    QCoreApplication::processEvents();
    
    // Wait for ACK
    emit statusMessage("Waiting for device acknowledgment...");
    if (!waitForData(10000)) {
        emit errorOccurred("No response from device for file info");
        return false;
    }
    
    PacketHeader header = readPacketHeader();
    if (!header.isValid() || header.command != USB_PROTO_CMD_ACK) {
        emit errorOccurred("Device did not acknowledge file info");
        sendNack();
        return false;
    }
    
    emit statusMessage("Sending file chunks...");
    
    // Send file data in chunks
    int totalSent = 0;
    quint16 chunkNumber = 0;
    
    while (totalSent < fileSize) {
        int chunkSize = qMin(USB_CHUNK_SIZE, static_cast<int>(fileSize - totalSent));
        QByteArray chunkData = fileData.mid(totalSent, chunkSize);
        
        // Build chunk packet: chunk_number(2) + chunk_size(2) + data[512]
        QByteArray chunkPayload;
        chunkPayload.append(static_cast<char>(chunkNumber & 0xFF));
        chunkPayload.append(static_cast<char>((chunkNumber >> 8) & 0xFF));
        chunkPayload.append(static_cast<char>(chunkSize & 0xFF));
        chunkPayload.append(static_cast<char>((chunkSize >> 8) & 0xFF));
        chunkPayload.append(chunkData);
        
        // Build chunk packet header
        QByteArray chunkPacket;
        chunkPacket.append(static_cast<char>(USB_PROTO_MAGIC & 0xFF));
        chunkPacket.append(static_cast<char>((USB_PROTO_MAGIC >> 8) & 0xFF));
        chunkPacket.append(static_cast<char>(USB_PROTO_CMD_FILE_DATA));
        
        quint16 chunkLength = chunkPayload.size();
        chunkPacket.append(static_cast<char>(chunkLength & 0xFF));
        chunkPacket.append(static_cast<char>((chunkLength >> 8) & 0xFF));
        
        quint8 chunkChecksum = calculateChecksum(chunkPayload);
        chunkPacket.append(static_cast<char>(chunkChecksum));
        chunkPacket.append(chunkPayload);
        
        // Send chunk
        m_serialPort->write(chunkPacket);
        if (!m_serialPort->waitForBytesWritten(5000)) {
            emit errorOccurred(QString("Failed to send chunk %1").arg(chunkNumber));
            return false;
        }
        
        // Process events to keep UI responsive
        QCoreApplication::processEvents();
        
        // Wait for ACK
        if (!waitForData(10000)) {
            emit errorOccurred(QString("No ACK for chunk %1").arg(chunkNumber));
            return false;
        }
        
        header = readPacketHeader();
        if (!header.isValid() || header.command != USB_PROTO_CMD_ACK) {
            emit errorOccurred(QString("Device NACK for chunk %1").arg(chunkNumber));
            return false;
        }
        
        totalSent += chunkSize;
        chunkNumber++;
        
        int progress = (totalSent * 100) / fileSize;
        emit progressUpdated(progress, totalSent, fileSize);
    }
    
    emit statusMessage(QString("Configuration sent successfully: %1").arg(filename));
    emit progressUpdated(100, fileSize, fileSize);
    return true;
}
