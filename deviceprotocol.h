#ifndef DEVICEPROTOCOL_H
#define DEVICEPROTOCOL_H

#include <QObject>
#include <QSerialPort>
#include <QByteArray>
#include <QString>
#include <QTimer>

// Protocol Constants (matching ESP32 firmware)
const quint16 USB_PROTO_MAGIC = 0xAA55;
const quint8 USB_PROTO_CMD_HANDSHAKE = 0x01;
const quint8 USB_PROTO_CMD_FILE_LIST = 0x02;
const quint8 USB_PROTO_CMD_FILE_DATA = 0x03;
const quint8 USB_PROTO_CMD_FILE_END = 0x04;
const quint8 USB_PROTO_CMD_ACK = 0x05;
const quint8 USB_PROTO_CMD_NACK = 0x06;
const quint8 USB_PROTO_CMD_CONFIG_REQ = 0x07;

const int USB_CHUNK_SIZE = 512;
const int USB_TIMEOUT_MS = 30000;

struct PacketHeader {
    quint16 magic;
    quint8 command;
    quint16 length;
    quint8 checksum;
    
    bool isValid() const { return magic == USB_PROTO_MAGIC; }
};

struct FileInfo {
    quint8 fileIndex;
    quint32 fileSize;
    QString filename;
};

struct ChunkInfo {
    quint16 chunkNumber;
    quint16 chunkSize;
    QByteArray data;
};

class DeviceProtocol : public QObject
{
    Q_OBJECT

public:
    explicit DeviceProtocol(QObject *parent = nullptr);
    ~DeviceProtocol();

    // Connection management
    bool openPort(const QString &portName, int baudrate = 115200);
    void closePort();
    bool isConnected() const;
    QString portName() const;

    // Protocol operations
    bool waitForHandshake(int timeoutMs = USB_TIMEOUT_MS);
    QStringList receiveFileList();
    bool receiveFile(const QString &outputDir, QString &savedFilename);
    
    // Send config operations
    bool sendConfigFile(int planIndex, int current, int sampleRate, int duration, int minTemp, int maxTemp);
    
    // Low-level protocol helpers
    void sendAck();
    void sendNack();
    PacketHeader readPacketHeader();
    quint8 calculateChecksum(const QByteArray &data) const;

signals:
    void errorOccurred(const QString &error);
    void statusMessage(const QString &message);
    void progressUpdated(int percentage, int bytesReceived, int totalBytes);

private:
    QSerialPort *m_serialPort;
    QTimer *m_timeoutTimer;
    
    bool waitForData(int timeoutMs);
    QByteArray readData(int length, int timeoutMs);
};

#endif // DEVICEPROTOCOL_H
