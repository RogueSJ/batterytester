#ifndef CSVDATAMODEL_H
#define CSVDATAMODEL_H

#include <QObject>
#include <QVariantList>
#include <QString>

struct BatteryDataPoint {
    int time;           // seconds
    double voltage;     // volts
    double current;     // amps
    double temperature; // celsius
};

class CsvDataModel : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString filename READ filename WRITE setFilename NOTIFY filenameChanged)
    Q_PROPERTY(int pointCount READ pointCount NOTIFY dataChanged)
    Q_PROPERTY(double minVoltage READ minVoltage NOTIFY dataChanged)
    Q_PROPERTY(double maxVoltage READ maxVoltage NOTIFY dataChanged)
    Q_PROPERTY(double avgVoltage READ avgVoltage NOTIFY dataChanged)
    Q_PROPERTY(double minCurrent READ minCurrent NOTIFY dataChanged)
    Q_PROPERTY(double maxCurrent READ maxCurrent NOTIFY dataChanged)
    Q_PROPERTY(double avgCurrent READ avgCurrent NOTIFY dataChanged)
    Q_PROPERTY(double minTemperature READ minTemperature NOTIFY dataChanged)
    Q_PROPERTY(double maxTemperature READ maxTemperature NOTIFY dataChanged)
    Q_PROPERTY(double avgTemperature READ avgTemperature NOTIFY dataChanged)

public:
    explicit CsvDataModel(QObject *parent = nullptr);

    QString filename() const { return m_filename; }
    void setFilename(const QString &filename);

    int pointCount() const { return m_dataPoints.size(); }
    double minVoltage() const { return m_minVoltage; }
    double maxVoltage() const { return m_maxVoltage; }
    double avgVoltage() const { return m_avgVoltage; }
    double minCurrent() const { return m_minCurrent; }
    double maxCurrent() const { return m_maxCurrent; }
    double avgCurrent() const { return m_avgCurrent; }
    double minTemperature() const { return m_minTemperature; }
    double maxTemperature() const { return m_maxTemperature; }
    double avgTemperature() const { return m_avgTemperature; }

    Q_INVOKABLE bool loadCsvFile(const QString &filepath);
    Q_INVOKABLE QVariantList getVoltageData() const;
    Q_INVOKABLE QVariantList getCurrentData() const;
    Q_INVOKABLE QVariantList getTemperatureData() const;
    Q_INVOKABLE QString getChannelNumber() const;

signals:
    void filenameChanged();
    void dataChanged();
    void errorOccurred(const QString &error);

private:
    void calculateMinMax();
    void clearData();

    QString m_filename;
    QVector<BatteryDataPoint> m_dataPoints;
    
    double m_minVoltage;
    double m_maxVoltage;
    double m_avgVoltage;
    double m_minCurrent;
    double m_maxCurrent;
    double m_avgCurrent;
    double m_minTemperature;
    double m_maxTemperature;
    double m_avgTemperature;
};

#endif // CSVDATAMODEL_H
