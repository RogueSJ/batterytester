#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDebug>
#include "devicemanager.h"
#include "csvdatamodel.h"

int main(int argc, char *argv[])
{
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
