#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDebug>
#include <QFile>
#include <QTextStream>
#include <QDateTime>
#include <QDir>
#include <QStandardPaths>
#include "devicemanager.h"
#include "csvdatamodel.h"

static QFile g_logFile;

static void messageHandler(QtMsgType type, const QMessageLogContext &context, const QString &msg)
{
    QString level;
    switch (type) {
    case QtDebugMsg: level = "DEBUG"; break;
    case QtInfoMsg: level = "INFO"; break;
    case QtWarningMsg: level = "WARN"; break;
    case QtCriticalMsg: level = "CRIT"; break;
    case QtFatalMsg: level = "FATAL"; break;
    }

    QString timestamp = QDateTime::currentDateTime().toString("yyyy-MM-dd hh:mm:ss.zzz");
    QString location = QString("%1:%2").arg(context.file ? context.file : "").arg(context.line);
    QString out = QString("%1 [%2] %3 (%4)").arg(timestamp, level, msg, location);

    // Always print to stderr so running from a console sees messages
    fprintf(stderr, "%s\n", out.toLocal8Bit().constData());
    fflush(stderr);

    // Also write to file if enabled
    if (g_logFile.isOpen()) {
        QTextStream ts(&g_logFile);
        ts << out << "\n";
        ts.flush();
    }

    if (type == QtFatalMsg) {
        abort();
    }
}

int main(int argc, char *argv[])
{
    // Install message handler if requested via env var
    QByteArray logPath = qEnvironmentVariable("BATTERYTESTER_LOG");
    if (!logPath.isEmpty()) {
        QString path = QString::fromLocal8Bit(logPath);
        QDir dir = QFileInfo(path).absoluteDir();
        if (!dir.exists()) dir.mkpath(".");
        g_logFile.setFileName(path);
        if (!g_logFile.open(QIODevice::Append | QIODevice::Text)) {
            qWarning() << "Failed to open log file:" << path;
        } else {
            qInstallMessageHandler(messageHandler);
            qInfo() << "Logging to file:" << path;
        }
    }

    // Use QApplication instead of QGuiApplication for QtCharts support
    QApplication app(argc, argv);
    
    app.setOrganizationName("BatteryTester");
    app.setOrganizationDomain("batterytester.local");
    app.setApplicationName("Battery Tester");

    // Create backend instances
    DeviceManager deviceManager;
    CsvDataModel csvModel;

    QQmlApplicationEngine engine;
    
    // Add QML import paths
    engine.addImportPath("/opt/Qt/6.9.0/gcc_64/qml");
    
    // Expose backend to QML BEFORE loading
    engine.rootContext()->setContextProperty("deviceManager", &deviceManager);
    engine.rootContext()->setContextProperty("csvModel", &csvModel);
    
    // Connect to see detailed errors
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { 
            qCritical() << "QML object creation failed!";
            QCoreApplication::exit(-1); 
        },
        Qt::QueuedConnection);
    
    // Load QML
    const QUrl url(QStringLiteral("qrc:/qt/qml/batterytester/Main.qml"));
    engine.load(url);
    
    // Check if any root objects were created
    if (engine.rootObjects().isEmpty()) {
        qCritical() << "Failed to load QML!";
        return -1;
    }
    
    return app.exec();
}
