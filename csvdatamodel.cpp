#include "csvdatamodel.h"
#include <QFile>
#include <QFileInfo>
#include <QTextStream>
#include <QDebug>
#include <QPointF>
#include <limits>

CsvDataModel::CsvDataModel(QObject *parent)
    : QObject(parent)
    , m_minVoltage(0)
    , m_maxVoltage(0)
    , m_avgVoltage(0)
    , m_minCurrent(0)
    , m_maxCurrent(0)
    , m_avgCurrent(0)
    , m_minTemperature(0)
    , m_maxTemperature(0)
    , m_avgTemperature(0)
{
}

void CsvDataModel::setFilename(const QString &filename)
{
    if (m_filename != filename) {
        m_filename = filename;
        emit filenameChanged();
    }
}

bool CsvDataModel::loadCsvFile(const QString &filepath)
{
    clearData();
    
    QFile file(filepath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        emit errorOccurred(QString("Failed to open file: %1").arg(file.errorString()));
        return false;
    }
    
    QTextStream in(&file);
    
    // Read header
    QString header = in.readLine();
    if (header.isEmpty() || !header.contains("time")) {
        emit errorOccurred("Invalid CSV format: missing header");
        return false;
    }
    
    // Read data lines
    int lineNumber = 1;
    while (!in.atEnd()) {
        QString line = in.readLine().trimmed();
        if (line.isEmpty()) {
            continue;
        }
        
        QStringList fields = line.split(',');
        if (fields.size() != 4) {
            qWarning() << "Line" << lineNumber << "has invalid format:" << line;
            lineNumber++;
            continue;
        }
        
        bool ok;
        BatteryDataPoint point;
        point.time = fields[0].toInt(&ok);
        if (!ok) continue;
        
        point.voltage = fields[1].toDouble(&ok);
        if (!ok) continue;
        
        point.current = fields[2].toDouble(&ok);
        if (!ok) continue;
        
        point.temperature = fields[3].toDouble(&ok);
        if (!ok) continue;
        
        m_dataPoints.append(point);
        lineNumber++;
    }
    
    file.close();
    
    if (m_dataPoints.isEmpty()) {
        emit errorOccurred("No valid data points found in CSV");
        return false;
    }
    
    calculateMinMax();
    
    setFilename(QFileInfo(filepath).fileName());
    emit dataChanged();
    
    qDebug() << "Loaded" << m_dataPoints.size() << "data points from" << filepath;
    return true;
}

QVariantList CsvDataModel::getVoltageData() const
{
    QVariantList result;
    for (const BatteryDataPoint &point : m_dataPoints) {
        result.append(QVariant::fromValue(QPointF(point.time, point.voltage)));
    }
    return result;
}

QVariantList CsvDataModel::getCurrentData() const
{
    QVariantList result;
    for (const BatteryDataPoint &point : m_dataPoints) {
        result.append(QVariant::fromValue(QPointF(point.time, point.current)));
    }
    return result;
}

QVariantList CsvDataModel::getTemperatureData() const
{
    QVariantList result;
    for (const BatteryDataPoint &point : m_dataPoints) {
        result.append(QVariant::fromValue(QPointF(point.time, point.temperature)));
    }
    return result;
}

QString CsvDataModel::getChannelNumber() const
{
    // Extract channel number from filename (e.g., "test_results_ch_1.csv" -> "1")
    QString name = m_filename;
    int chPos = name.indexOf("ch_");
    if (chPos >= 0) {
        QString numStr = name.mid(chPos + 3);
        int dotPos = numStr.indexOf('.');
        if (dotPos >= 0) {
            return numStr.left(dotPos);
        }
    }
    return "?";
}

void CsvDataModel::calculateMinMax()
{
    if (m_dataPoints.isEmpty()) {
        return;
    }
    
    m_minVoltage = m_maxVoltage = m_dataPoints[0].voltage;
    m_minCurrent = m_maxCurrent = m_dataPoints[0].current;
    m_minTemperature = m_maxTemperature = m_dataPoints[0].temperature;
    
    double sumVoltage = 0, sumCurrent = 0, sumTemperature = 0;
    
    for (const BatteryDataPoint &point : m_dataPoints) {
        m_minVoltage = qMin(m_minVoltage, point.voltage);
        m_maxVoltage = qMax(m_maxVoltage, point.voltage);
        m_minCurrent = qMin(m_minCurrent, point.current);
        m_maxCurrent = qMax(m_maxCurrent, point.current);
        m_minTemperature = qMin(m_minTemperature, point.temperature);
        m_maxTemperature = qMax(m_maxTemperature, point.temperature);
        
        sumVoltage += point.voltage;
        sumCurrent += point.current;
        sumTemperature += point.temperature;
    }
    
    int count = m_dataPoints.size();
    m_avgVoltage = sumVoltage / count;
    m_avgCurrent = sumCurrent / count;
    m_avgTemperature = sumTemperature / count;
}

void CsvDataModel::clearData()
{
    m_dataPoints.clear();
    m_minVoltage = m_maxVoltage = m_avgVoltage = 0;
    m_minCurrent = m_maxCurrent = m_avgCurrent = 0;
    m_minTemperature = m_maxTemperature = m_avgTemperature = 0;
}
