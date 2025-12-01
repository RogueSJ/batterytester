#ifndef DEVICEMANAGER_H
#define DEVICEMANAGER_H

#include <QObject>
#include <QStringList>
#include <QThread>
#include "deviceprotocol.h"

class DeviceManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(bool isConnected READ isConnected NOTIFY isConnectedChanged)
    Q_PROPERTY(int progress READ progress NOTIFY progressChanged)
    Q_PROPERTY(QStringList availablePorts READ availablePorts NOTIFY availablePortsChanged)
    Q_PROPERTY(QStringList receivedFiles READ receivedFiles NOTIFY receivedFilesChanged)

public:
    explicit DeviceManager(QObject *parent = nullptr);
    ~DeviceManager();

    QString status() const { return m_status; }
    bool isConnected() const { return m_isConnected; }
    int progress() const { return m_progress; }
    QStringList availablePorts() const { return m_availablePorts; }
    QStringList receivedFiles() const { return m_receivedFiles; }

    Q_INVOKABLE void refreshPorts();
    Q_INVOKABLE bool connectToDevice(const QString &portName);
    Q_INVOKABLE void disconnectFromDevice();
    Q_INVOKABLE void startDownload();
    Q_INVOKABLE void receiveResults(const QString &portName);  // Single-button operation
    Q_INVOKABLE QStringList getReceivedFilesList();
    Q_INVOKABLE void setSaveLocation(const QString &location);
    
    // Send settings operations
    Q_INVOKABLE void sendSettings(const QString &portName, int planIndex, int current, int sampleRate, int duration, int minTemp, int maxTemp);

signals:
    void statusChanged();
    void isConnectedChanged();
    void progressChanged();
    void availablePortsChanged();
    void receivedFilesChanged();
    void downloadComplete();
    void errorOccurred(const QString &error);

private slots:
    void onProtocolError(const QString &error);
    void onProtocolStatus(const QString &message);
    void onProtocolProgress(int percentage, int bytesReceived, int totalBytes);

private:
    void setStatus(const QString &status);
    void setConnected(bool connected);
    void setProgress(int progress);
    void updateReceivedFilesList();
    void doReceiveOperation();
    void cleanupAfterError(const QString &errorMessage);

    DeviceProtocol *m_protocol;
    
    QString m_status;
    bool m_isConnected;
    int m_progress;
    QStringList m_availablePorts;
    QStringList m_receivedFiles;
    QString m_outputDir;
};

#endif // DEVICEMANAGER_H
