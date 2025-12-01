import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtCharts

ApplicationWindow {
    id: root
    width: 1280
    height: 800
    minimumWidth: 1024
    minimumHeight: 600
    visible: true
    title: qsTr("Battery Tester")
    
    // Modern industrial color scheme
    palette {
        window: "#1e1e2e"
        windowText: "#cdd6f4"
        base: "#181825"
        alternateBase: "#313244"
        text: "#cdd6f4"
        button: "#313244"
        buttonText: "#cdd6f4"
        brightText: "#f5c2e7"
        highlight: "#89b4fa"
        highlightedText: "#1e1e2e"
    }
    
    // Background
    background: Rectangle {
        color: "#1e1e2e"
    }
    
    // Properties
    property int selectedChannel: -1
    property string currentPlotType: "voltage"
    property string saveLocation: ""
    property string selectedCsvFile: ""
    
    // Axis range properties
    property bool useAutoYAxis: true
    property double customYMin: 0
    property double customYMax: 100
    property bool useAutoXAxis: true
    property double customXMin: 0
    property double customXMax: 100
    
    // Data-based defaults (updated when data loads)
    property double dataYMin: 0
    property double dataYMax: 100
    property double dataXMax: 100
    
    // Folder dialog for save location
    FolderDialog {
        id: folderDialog
        title: "Select Save Location"
        onAccepted: {
            // Handle both Windows (file:///C:/) and Linux (file://) paths
            var path = selectedFolder.toString()
            if (Qt.platform.os === "windows") {
                // Windows: file:///C:/path -> C:/path
                path = path.replace(/^file:\/\/\//, "")
            } else {
                // Linux/Mac: file:///path -> /path
                path = path.replace(/^file:\/\//, "")
            }
            saveLocation = path
        }
    }
    
    // File dialog for CSV selection
    FileDialog {
        id: csvFileDialog
        title: "Select CSV File"
        nameFilters: ["CSV files (*.csv)", "All files (*)"]
        onAccepted: {
            // Handle both Windows (file:///C:/) and Linux (file://) paths
            var path = selectedFile.toString()
            if (Qt.platform.os === "windows") {
                // Windows: file:///C:/path -> C:/path
                path = path.replace(/^file:\/\/\//, "")
            } else {
                // Linux/Mac: file:///path -> /path
                path = path.replace(/^file:\/\//, "")
            }
            selectedCsvFile = path
            if (csvModel) {
                csvModel.loadCsvFile(selectedCsvFile)
                selectedChannel = 0
                currentPlotType = "voltage"  // Reset to voltage
                updateChartData()  // Immediately update chart
            }
        }
    }
    
    // Main layout: Vertical tab bar on left, content on right
    RowLayout {
        anchors.fill: parent
        spacing: 0
        
        // Vertical Tab Bar
        Rectangle {
            Layout.preferredWidth: 200
            Layout.fillHeight: true
            color: "#181825"
            
            Rectangle {
                width: 1
                height: parent.height
                anchors.right: parent.right
                color: "#45475a"
            }
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 5
                
                // App Logo/Title
                Rectangle {
                    Layout.fillWidth: true
                    height: 60
                    color: "transparent"
                    
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        
                        Label {
                            text: "⚡"
                            font.pixelSize: 24
                        }
                        
                        Label {
                            text: "Battery Tester"
                            font.pixelSize: 16
                            font.bold: true
                            color: "#89b4fa"
                        }
                    }
                }
                
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#45475a"
                }
                
                Item { height: 10 }
                
                // Tab Buttons
                Repeater {
                    model: [
                        { text: "📥  Download Results", index: 0 },
                        { text: "📤  Send Settings", index: 1 },
                        { text: "📊  Charts", index: 2 },
                        { text: "⚙️  App Settings", index: 3 }
                    ]
                    
                    delegate: Button {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 50
                        
                        property bool isSelected: tabStack.currentIndex === modelData.index
                        
                        background: Rectangle {
                            color: isSelected ? "#313244" : (parent.hovered ? "#262637" : "transparent")
                            radius: 8
                            border.color: isSelected ? "#89b4fa" : "transparent"
                            border.width: 2
                        }
                        
                        contentItem: Text {
                            text: modelData.text
                            color: isSelected ? "#89b4fa" : "#cdd6f4"
                            font.pixelSize: 14
                            font.bold: isSelected
                            horizontalAlignment: Text.AlignLeft
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 15
                        }
                        
                        onClicked: tabStack.currentIndex = modelData.index
                    }
                }
                
                Item { Layout.fillHeight: true }
                
                // Status indicator
                Rectangle {
                    Layout.fillWidth: true
                    height: 60
                    color: "#313244"
                    radius: 8
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10
                        
                        Rectangle {
                            width: 12
                            height: 12
                            radius: 6
                            color: (deviceManager && deviceManager.isConnected) ? "#a6e3a1" : "#6c7086"
                            
                            SequentialAnimation on opacity {
                                running: deviceManager && deviceManager.isConnected
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.3; duration: 800 }
                                NumberAnimation { to: 1.0; duration: 800 }
                            }
                        }
                        
                        Label {
                            text: deviceManager ? (deviceManager.isConnected ? "Connected" : "Disconnected") : "..."
                            font.pixelSize: 12
                            color: (deviceManager && deviceManager.isConnected) ? "#a6e3a1" : "#9399b2"
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
        
        // Content Area - StackLayout
        StackLayout {
            id: tabStack
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: 0
            
            // ===== TAB 0: Download Results =====
            Rectangle {
                color: "#1e1e2e"
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 30
                    spacing: 25
                    
                    // Header
                    Label {
                        text: "Download Test Results"
                        font.pixelSize: 28
                        font.bold: true
                        color: "#89b4fa"
                    }
                    
                    Label {
                        text: "Receive test results from your battery tester device via USB"
                        font.pixelSize: 14
                        color: "#9399b2"
                    }
                    
                    Item { height: 15 }
                    
                    // Settings Group
                    GroupBox {
                        Layout.fillWidth: true
                        title: "Connection Settings"
                        topPadding: 50
                        leftPadding: 15
                        rightPadding: 15
                        bottomPadding: 15
                        
                        background: Rectangle {
                            y: 35
                            width: parent.width
                            height: parent.height - 35
                            color: "#313244"
                            border.color: "#45475a"
                            radius: 8
                        }
                        
                        label: Label {
                            x: parent.leftPadding
                            y: 8
                            text: parent.title
                            color: "#89b4fa"
                            font.bold: true
                            font.pixelSize: 14
                        }
                        
                        GridLayout {
                            anchors.fill: parent
                            columns: 2
                            columnSpacing: 20
                            rowSpacing: 15
                            
                            // Port Selection
                            Label {
                                text: "Serial Port:"
                                font.pixelSize: 14
                                color: "#cdd6f4"
                            }
                            
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                
                                ComboBox {
                                    id: portComboBox
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 40
                                    model: deviceManager ? deviceManager.availablePorts : []
                                    enabled: deviceManager ? !deviceManager.isConnected : true
                                    
                                    background: Rectangle {
                                        color: portComboBox.enabled ? "#45475a" : "#313244"
                                        border.color: portComboBox.hovered ? "#89b4fa" : "#6c7086"
                                        radius: 6
                                    }
                                    
                                    contentItem: Text {
                                        text: portComboBox.displayText || "Select port..."
                                        color: "#cdd6f4"
                                        verticalAlignment: Text.AlignVCenter
                                        leftPadding: 12
                                        font.pixelSize: 14
                                    }
                                }
                                
                                Button {
                                    text: "🔄"
                                    Layout.preferredWidth: 40
                                    Layout.preferredHeight: 40
                                    enabled: deviceManager ? !deviceManager.isConnected : true
                                    
                                    background: Rectangle {
                                        color: parent.down ? "#6c7086" : (parent.hovered ? "#585b70" : "#45475a")
                                        border.color: "#6c7086"
                                        radius: 6
                                    }
                                    
                                    contentItem: Text {
                                        text: parent.text
                                        color: "#cdd6f4"
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        font.pixelSize: 16
                                    }
                                    
                                    onClicked: { if (deviceManager) deviceManager.refreshPorts() }
                                }
                            }
                            
                            // Save Location
                            Label {
                                text: "Save Location:"
                                font.pixelSize: 14
                                color: "#cdd6f4"
                            }
                            
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                
                                TextField {
                                    id: saveLocationField
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 40
                                    text: saveLocation || "./received_files"
                                    readOnly: true
                                    font.pixelSize: 14
                                    
                                    background: Rectangle {
                                        color: "#45475a"
                                        border.color: "#6c7086"
                                        radius: 6
                                    }
                                    
                                    color: "#cdd6f4"
                                }
                                
                                Button {
                                    text: "Browse..."
                                    Layout.preferredHeight: 40
                                    
                                    background: Rectangle {
                                        color: parent.down ? "#6c7086" : (parent.hovered ? "#585b70" : "#45475a")
                                        border.color: "#6c7086"
                                        radius: 6
                                    }
                                    
                                    contentItem: Text {
                                        text: parent.text
                                        color: "#cdd6f4"
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        font.pixelSize: 14
                                    }
                                    
                                    onClicked: folderDialog.open()
                                }
                            }
                        }
                    }
                    
                    // Single Action Button
                    Button {
                        id: receiveButton
                        text: "⬇️  Receive Results"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60
                        enabled: deviceManager && portComboBox.currentText !== "" && !deviceManager.isConnected
                        
                        background: Rectangle {
                            color: parent.enabled ? (parent.down ? "#74c7ec" : (parent.hovered ? "#94e2d5" : "#89b4fa")) : "#313244"
                            radius: 10
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            color: parent.enabled ? "#181825" : "#6c7086"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 20
                            font.bold: true
                        }
                        
                        onClicked: {
                            if (deviceManager && portComboBox.currentText) {
                                if (saveLocation) {
                                    deviceManager.setSaveLocation(saveLocation)
                                }
                                deviceManager.receiveResults(portComboBox.currentText)
                            }
                        }
                    }
                    
                    // Status display
                    Rectangle {
                        Layout.fillWidth: true
                        height: 50
                        color: "#313244"
                        radius: 8
                        visible: deviceManager && deviceManager.status !== "Disconnected"
                        
                        Label {
                            anchors.centerIn: parent
                            text: deviceManager ? deviceManager.status : ""
                            font.pixelSize: 14
                            color: "#cdd6f4"
                        }
                    }
                    
                    // Progress
                    ProgressBar {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 8
                        value: deviceManager ? deviceManager.progress / 100.0 : 0
                        visible: deviceManager && deviceManager.progress > 0 && deviceManager.progress < 100
                        
                        background: Rectangle {
                            color: "#313244"
                            radius: 4
                        }
                        
                        contentItem: Item {
                            Rectangle {
                                width: parent.width * parent.parent.value
                                height: parent.height
                                radius: 4
                                color: "#89b4fa"
                            }
                        }
                    }
                    
                    // Downloaded Files List
                    GroupBox {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        title: "Downloaded Files"
                        
                        background: Rectangle {
                            y: parent.topPadding - parent.padding
                            width: parent.width
                            height: parent.height - parent.topPadding + parent.padding
                            color: "#313244"
                            border.color: "#45475a"
                            radius: 8
                        }
                        
                        label: Label {
                            x: parent.leftPadding
                            text: parent.title
                            color: "#89b4fa"
                            font.bold: true
                            font.pixelSize: 14
                        }
                        
                        ListView {
                            id: downloadedFilesList
                            anchors.fill: parent
                            clip: true
                            spacing: 5
                            model: deviceManager ? deviceManager.receivedFiles : []
                            
                            delegate: ItemDelegate {
                                width: downloadedFilesList.width
                                height: 45
                                
                                background: Rectangle {
                                    color: parent.hovered ? "#45475a" : "transparent"
                                    radius: 6
                                }
                                
                                contentItem: RowLayout {
                                    spacing: 15
                                    
                                    Rectangle {
                                        width: 10
                                        height: 10
                                        radius: 5
                                        color: "#a6e3a1"
                                    }
                                    
                                    Label {
                                        text: modelData
                                        Layout.fillWidth: true
                                        color: "#cdd6f4"
                                        font.pixelSize: 14
                                        elide: Text.ElideRight
                                    }
                                    
                                    Label {
                                        text: "✓"
                                        color: "#a6e3a1"
                                        font.pixelSize: 16
                                    }
                                }
                            }
                            
                            Label {
                                anchors.centerIn: parent
                                text: "No files downloaded yet"
                                color: "#6c7086"
                                font.pixelSize: 14
                                visible: downloadedFilesList.count === 0
                            }
                        }
                    }
                }
            }
            
            // ===== TAB 1: Send Settings =====
            Rectangle {
                color: "#1e1e2e"
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 30
                    spacing: 20
                    
                    Label {
                        text: "Send Settings"
                        font.pixelSize: 28
                        font.bold: true
                        color: "#89b4fa"
                    }
                    
                    Label {
                        text: "Configure and upload test parameters to the battery tester device"
                        font.pixelSize: 14
                        color: "#9399b2"
                    }
                    
                    // Main content area
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 30
                        
                        // Left panel - Settings Form
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: "#313244"
                            radius: 12
                            border.color: "#45475a"
                            
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 25
                                spacing: 20
                                
                                Label {
                                    text: "⚙️ Test Parameters"
                                    font.pixelSize: 18
                                    font.bold: true
                                    color: "#f9e2af"
                                }
                                
                                // Plan Selection
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 15
                                    
                                    Label {
                                        text: "Target Plan:"
                                        font.pixelSize: 14
                                        color: "#cdd6f4"
                                        Layout.preferredWidth: 120
                                    }
                                    
                                    ComboBox {
                                        id: planComboBox
                                        Layout.preferredWidth: 200
                                        model: ["Plan 1", "Plan 2", "Plan 3", "Plan 4"]
                                        currentIndex: 0
                                        
                                        background: Rectangle {
                                            color: "#45475a"
                                            radius: 6
                                            border.color: parent.focus ? "#89b4fa" : "#585b70"
                                        }
                                        
                                        contentItem: Text {
                                            text: parent.displayText
                                            color: "#cdd6f4"
                                            leftPadding: 10
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        
                                        popup: Popup {
                                            y: parent.height
                                            width: parent.width
                                            padding: 1
                                            
                                            contentItem: ListView {
                                                implicitHeight: contentHeight
                                                model: planComboBox.popup.visible ? planComboBox.delegateModel : null
                                                clip: true
                                            }
                                            
                                            background: Rectangle {
                                                color: "#45475a"
                                                radius: 6
                                                border.color: "#585b70"
                                            }
                                        }
                                        
                                        delegate: ItemDelegate {
                                            width: planComboBox.width
                                            
                                            contentItem: Text {
                                                text: modelData
                                                color: "#cdd6f4"
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            
                                            background: Rectangle {
                                                color: parent.highlighted ? "#585b70" : "transparent"
                                            }
                                        }
                                    }
                                    
                                    Item { Layout.fillWidth: true }
                                }
                                
                                Rectangle { height: 1; Layout.fillWidth: true; color: "#45475a" }
                                
                                // Current Setting
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 15
                                    
                                    Label {
                                        text: "Current (mA):"
                                        font.pixelSize: 14
                                        color: "#cdd6f4"
                                        Layout.preferredWidth: 120
                                    }
                                    
                                    SpinBox {
                                        id: currentSpinBox
                                        from: 0
                                        to: 500
                                        value: 250
                                        stepSize: 10
                                        editable: true
                                        Layout.preferredWidth: 150
                                        
                                        background: Rectangle {
                                            color: "#45475a"
                                            radius: 6
                                            border.color: parent.focus ? "#89b4fa" : "#585b70"
                                        }
                                        
                                        contentItem: TextInput {
                                            text: parent.value
                                            color: "#cdd6f4"
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            readOnly: !parent.editable
                                            validator: parent.validator
                                            inputMethodHints: Qt.ImhDigitsOnly
                                            selectByMouse: true
                                        }
                                        
                                        up.indicator: Rectangle {
                                            x: parent.width - width
                                            height: parent.height / 2
                                            width: 30
                                            color: parent.up.pressed ? "#6c7086" : "#585b70"
                                            radius: 4
                                            Text {
                                                text: "+"
                                                color: "#cdd6f4"
                                                anchors.centerIn: parent
                                                font.bold: true
                                            }
                                        }
                                        
                                        down.indicator: Rectangle {
                                            x: parent.width - width
                                            y: parent.height / 2
                                            height: parent.height / 2
                                            width: 30
                                            color: parent.down.pressed ? "#6c7086" : "#585b70"
                                            radius: 4
                                            Text {
                                                text: "-"
                                                color: "#cdd6f4"
                                                anchors.centerIn: parent
                                                font.bold: true
                                            }
                                        }
                                    }
                                    
                                    Label {
                                        text: "(0 - 500)"
                                        font.pixelSize: 12
                                        color: "#6c7086"
                                    }
                                    
                                    Item { Layout.fillWidth: true }
                                }
                                
                                // Sample Rate Setting
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 15
                                    
                                    Label {
                                        text: "Sample Rate (min):"
                                        font.pixelSize: 14
                                        color: "#cdd6f4"
                                        Layout.preferredWidth: 120
                                    }
                                    
                                    SpinBox {
                                        id: sampleRateSpinBox
                                        from: 0
                                        to: 1000
                                        value: 1
                                        stepSize: 1
                                        editable: true
                                        Layout.preferredWidth: 150
                                        
                                        background: Rectangle {
                                            color: "#45475a"
                                            radius: 6
                                            border.color: parent.focus ? "#89b4fa" : "#585b70"
                                        }
                                        
                                        contentItem: TextInput {
                                            text: parent.value
                                            color: "#cdd6f4"
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            readOnly: !parent.editable
                                            validator: parent.validator
                                            inputMethodHints: Qt.ImhDigitsOnly
                                            selectByMouse: true
                                        }
                                        
                                        up.indicator: Rectangle {
                                            x: parent.width - width
                                            height: parent.height / 2
                                            width: 30
                                            color: parent.up.pressed ? "#6c7086" : "#585b70"
                                            radius: 4
                                            Text {
                                                text: "+"
                                                color: "#cdd6f4"
                                                anchors.centerIn: parent
                                                font.bold: true
                                            }
                                        }
                                        
                                        down.indicator: Rectangle {
                                            x: parent.width - width
                                            y: parent.height / 2
                                            height: parent.height / 2
                                            width: 30
                                            color: parent.down.pressed ? "#6c7086" : "#585b70"
                                            radius: 4
                                            Text {
                                                text: "-"
                                                color: "#cdd6f4"
                                                anchors.centerIn: parent
                                                font.bold: true
                                            }
                                        }
                                    }
                                    
                                    Label {
                                        text: "(0 - 1,000)"
                                        font.pixelSize: 12
                                        color: "#6c7086"
                                    }
                                    
                                    Item { Layout.fillWidth: true }
                                }
                                
                                // Duration Setting
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 15
                                    
                                    Label {
                                        text: "Duration (hours):"
                                        font.pixelSize: 14
                                        color: "#cdd6f4"
                                        Layout.preferredWidth: 120
                                    }
                                    
                                    SpinBox {
                                        id: durationSpinBox
                                        from: 0
                                        to: 1000
                                        value: 3
                                        stepSize: 1
                                        editable: true
                                        Layout.preferredWidth: 150
                                        
                                        background: Rectangle {
                                            color: "#45475a"
                                            radius: 6
                                            border.color: parent.focus ? "#89b4fa" : "#585b70"
                                        }
                                        
                                        contentItem: TextInput {
                                            text: parent.value
                                            color: "#cdd6f4"
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            readOnly: !parent.editable
                                            validator: parent.validator
                                            inputMethodHints: Qt.ImhDigitsOnly
                                            selectByMouse: true
                                        }
                                        
                                        up.indicator: Rectangle {
                                            x: parent.width - width
                                            height: parent.height / 2
                                            width: 30
                                            color: parent.up.pressed ? "#6c7086" : "#585b70"
                                            radius: 4
                                            Text {
                                                text: "+"
                                                color: "#cdd6f4"
                                                anchors.centerIn: parent
                                                font.bold: true
                                            }
                                        }
                                        
                                        down.indicator: Rectangle {
                                            x: parent.width - width
                                            y: parent.height / 2
                                            height: parent.height / 2
                                            width: 30
                                            color: parent.down.pressed ? "#6c7086" : "#585b70"
                                            radius: 4
                                            Text {
                                                text: "-"
                                                color: "#cdd6f4"
                                                anchors.centerIn: parent
                                                font.bold: true
                                            }
                                        }
                                    }
                                    
                                    Label {
                                        text: "(0 - 1,000)"
                                        font.pixelSize: 12
                                        color: "#6c7086"
                                    }
                                    
                                    Item { Layout.fillWidth: true }
                                }
                                
                                Rectangle { height: 1; Layout.fillWidth: true; color: "#45475a" }
                                
                                // Temperature Range
                                Label {
                                    text: "🌡️ Temperature Limits"
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: "#f9e2af"
                                }
                                
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 15
                                    
                                    Label {
                                        text: "Min Temp (°C):"
                                        font.pixelSize: 14
                                        color: "#cdd6f4"
                                        Layout.preferredWidth: 120
                                    }
                                    
                                    SpinBox {
                                        id: minTempSpinBox
                                        from: -40
                                        to: 85
                                        value: -20
                                        stepSize: 1
                                        editable: true
                                        Layout.preferredWidth: 150
                                        
                                        background: Rectangle {
                                            color: "#45475a"
                                            radius: 6
                                            border.color: parent.focus ? "#89b4fa" : "#585b70"
                                        }
                                        
                                        contentItem: TextInput {
                                            text: parent.value
                                            color: "#cdd6f4"
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            readOnly: !parent.editable
                                            validator: parent.validator
                                            inputMethodHints: Qt.ImhDigitsOnly
                                            selectByMouse: true
                                        }
                                        
                                        up.indicator: Rectangle {
                                            x: parent.width - width
                                            height: parent.height / 2
                                            width: 30
                                            color: parent.up.pressed ? "#6c7086" : "#585b70"
                                            radius: 4
                                            Text {
                                                text: "+"
                                                color: "#cdd6f4"
                                                anchors.centerIn: parent
                                                font.bold: true
                                            }
                                        }
                                        
                                        down.indicator: Rectangle {
                                            x: parent.width - width
                                            y: parent.height / 2
                                            height: parent.height / 2
                                            width: 30
                                            color: parent.down.pressed ? "#6c7086" : "#585b70"
                                            radius: 4
                                            Text {
                                                text: "-"
                                                color: "#cdd6f4"
                                                anchors.centerIn: parent
                                                font.bold: true
                                            }
                                        }
                                        
                                        textFromValue: function(value, locale) {
                                            return value.toString()
                                        }
                                        
                                        valueFromText: function(text, locale) {
                                            return parseInt(text)
                                        }
                                    }
                                    
                                    Label {
                                        text: "Max Temp (°C):"
                                        font.pixelSize: 14
                                        color: "#cdd6f4"
                                        Layout.leftMargin: 30
                                    }
                                    
                                    SpinBox {
                                        id: maxTempSpinBox
                                        from: -40
                                        to: 85
                                        value: 30
                                        stepSize: 1
                                        editable: true
                                        Layout.preferredWidth: 150
                                        
                                        background: Rectangle {
                                            color: "#45475a"
                                            radius: 6
                                            border.color: parent.focus ? "#89b4fa" : "#585b70"
                                        }
                                        
                                        contentItem: TextInput {
                                            text: parent.value
                                            color: "#cdd6f4"
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            readOnly: !parent.editable
                                            validator: parent.validator
                                            inputMethodHints: Qt.ImhDigitsOnly
                                            selectByMouse: true
                                        }
                                        
                                        up.indicator: Rectangle {
                                            x: parent.width - width
                                            height: parent.height / 2
                                            width: 30
                                            color: parent.up.pressed ? "#6c7086" : "#585b70"
                                            radius: 4
                                            Text {
                                                text: "+"
                                                color: "#cdd6f4"
                                                anchors.centerIn: parent
                                                font.bold: true
                                            }
                                        }
                                        
                                        down.indicator: Rectangle {
                                            x: parent.width - width
                                            y: parent.height / 2
                                            height: parent.height / 2
                                            width: 30
                                            color: parent.down.pressed ? "#6c7086" : "#585b70"
                                            radius: 4
                                            Text {
                                                text: "-"
                                                color: "#cdd6f4"
                                                anchors.centerIn: parent
                                                font.bold: true
                                            }
                                        }
                                        
                                        textFromValue: function(value, locale) {
                                            return value.toString()
                                        }
                                        
                                        valueFromText: function(text, locale) {
                                            return parseInt(text)
                                        }
                                    }
                                    
                                    Item { Layout.fillWidth: true }
                                }
                                
                                Item { Layout.fillHeight: true }
                            }
                        }
                        
                        // Right panel - Connection & Send
                        Rectangle {
                            Layout.preferredWidth: 320
                            Layout.fillHeight: true
                            color: "#313244"
                            radius: 12
                            border.color: "#45475a"
                            
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 25
                                spacing: 20
                                
                                Label {
                                    text: "📡 Device Connection"
                                    font.pixelSize: 18
                                    font.bold: true
                                    color: "#f9e2af"
                                }
                                
                                // Port selection
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    
                                    ComboBox {
                                        id: sendPortComboBox
                                        Layout.fillWidth: true
                                        model: deviceManager ? deviceManager.availablePorts : []
                                        
                                        background: Rectangle {
                                            color: "#45475a"
                                            radius: 6
                                            border.color: parent.focus ? "#89b4fa" : "#585b70"
                                        }
                                        
                                        contentItem: Text {
                                            text: parent.displayText || "Select Port"
                                            color: parent.displayText ? "#cdd6f4" : "#6c7086"
                                            leftPadding: 10
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        
                                        popup: Popup {
                                            y: parent.height
                                            width: parent.width
                                            padding: 1
                                            
                                            contentItem: ListView {
                                                implicitHeight: contentHeight
                                                model: sendPortComboBox.popup.visible ? sendPortComboBox.delegateModel : null
                                                clip: true
                                            }
                                            
                                            background: Rectangle {
                                                color: "#45475a"
                                                radius: 6
                                                border.color: "#585b70"
                                            }
                                        }
                                        
                                        delegate: ItemDelegate {
                                            width: sendPortComboBox.width
                                            
                                            contentItem: Text {
                                                text: modelData
                                                color: "#cdd6f4"
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            
                                            background: Rectangle {
                                                color: parent.highlighted ? "#585b70" : "transparent"
                                            }
                                        }
                                    }
                                    
                                    Button {
                                        text: "🔄"
                                        Layout.preferredWidth: 40
                                        Layout.preferredHeight: 40
                                        
                                        background: Rectangle {
                                            color: parent.down ? "#6c7086" : (parent.hovered ? "#585b70" : "#45475a")
                                            radius: 6
                                        }
                                        
                                        onClicked: {
                                            if (deviceManager) deviceManager.refreshPorts()
                                        }
                                    }
                                }
                                
                                Rectangle { height: 1; Layout.fillWidth: true; color: "#45475a" }
                                
                                // Summary
                                Label {
                                    text: "📋 Configuration Summary"
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: "#89b4fa"
                                }
                                
                                GridLayout {
                                    columns: 2
                                    rowSpacing: 8
                                    columnSpacing: 15
                                    Layout.fillWidth: true
                                    
                                    Label { text: "Plan:"; font.pixelSize: 12; color: "#9399b2" }
                                    Label { text: planComboBox.currentText; font.pixelSize: 12; color: "#cdd6f4"; font.bold: true }
                                    
                                    Label { text: "Current:"; font.pixelSize: 12; color: "#9399b2" }
                                    Label { text: currentSpinBox.value + " mA"; font.pixelSize: 12; color: "#cdd6f4"; font.bold: true }
                                    
                                    Label { text: "Sample Rate:"; font.pixelSize: 12; color: "#9399b2" }
                                    Label { text: sampleRateSpinBox.value + " min"; font.pixelSize: 12; color: "#cdd6f4"; font.bold: true }
                                    
                                    Label { text: "Duration:"; font.pixelSize: 12; color: "#9399b2" }
                                    Label { text: durationSpinBox.value + " hours"; font.pixelSize: 12; color: "#cdd6f4"; font.bold: true }
                                    
                                    Label { text: "Temp Range:"; font.pixelSize: 12; color: "#9399b2" }
                                    Label { text: minTempSpinBox.value + "°C to " + maxTempSpinBox.value + "°C"; font.pixelSize: 12; color: "#cdd6f4"; font.bold: true }
                                }
                                
                                Item { Layout.fillHeight: true }
                                
                                // Validation warning
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 40
                                    color: "#f38ba8"
                                    radius: 6
                                    visible: minTempSpinBox.value >= maxTempSpinBox.value
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "⚠️ Min temp must be less than max temp"
                                        font.pixelSize: 12
                                        color: "#1e1e2e"
                                    }
                                }
                                
                                // Status display
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 50
                                    color: "#45475a"
                                    radius: 8
                                    visible: deviceManager && deviceManager.status !== "Disconnected"
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: deviceManager ? deviceManager.status : ""
                                        font.pixelSize: 12
                                        color: "#cdd6f4"
                                        wrapMode: Text.WordWrap
                                        horizontalAlignment: Text.AlignHCenter
                                        width: parent.width - 20
                                    }
                                }
                                
                                // Progress bar
                                ProgressBar {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 8
                                    value: deviceManager ? deviceManager.progress / 100.0 : 0
                                    visible: deviceManager && deviceManager.progress > 0 && deviceManager.progress < 100
                                    
                                    background: Rectangle {
                                        color: "#45475a"
                                        radius: 4
                                    }
                                    
                                    contentItem: Item {
                                        Rectangle {
                                            width: parent.width * parent.parent.value
                                            height: parent.height
                                            radius: 4
                                            color: "#a6e3a1"
                                        }
                                    }
                                }
                                
                                // Send Button
                                Button {
                                    text: "📤  Send to Device"
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 50
                                    enabled: sendPortComboBox.currentText !== "" && minTempSpinBox.value < maxTempSpinBox.value
                                    
                                    background: Rectangle {
                                        color: parent.enabled ? 
                                            (parent.down ? "#74c7ec" : (parent.hovered ? "#94e2d5" : "#a6e3a1")) :
                                            "#45475a"
                                        radius: 8
                                    }
                                    
                                    contentItem: Text {
                                        text: parent.text
                                        color: parent.enabled ? "#1e1e2e" : "#6c7086"
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        font.pixelSize: 16
                                        font.bold: true
                                    }
                                    
                                    onClicked: {
                                        if (deviceManager && sendPortComboBox.currentText) {
                                            deviceManager.sendSettings(
                                                sendPortComboBox.currentText,
                                                planComboBox.currentIndex + 1,  // 1-4
                                                currentSpinBox.value,
                                                sampleRateSpinBox.value,
                                                durationSpinBox.value,
                                                minTempSpinBox.value,
                                                maxTempSpinBox.value
                                            )
                                        }
                                    }
                                }
                                
                                Label {
                                    text: "Press 'Receive Config' on device first!"
                                    font.pixelSize: 11
                                    color: "#f9e2af"
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }
                    }
                }
            }
            
            // ===== TAB 2: Charts =====
            Rectangle {
                color: "#1e1e2e"
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 15
                    
                    // Header with file selector
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 15
                        
                        Label {
                            text: "Charts"
                            font.pixelSize: 28
                            font.bold: true
                            color: "#89b4fa"
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        Button {
                            text: "📂  Select CSV File"
                            Layout.preferredHeight: 40
                            
                            background: Rectangle {
                                color: parent.down ? "#6c7086" : (parent.hovered ? "#585b70" : "#45475a")
                                border.color: "#89b4fa"
                                radius: 6
                            }
                            
                            contentItem: Text {
                                text: parent.text
                                color: "#cdd6f4"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                font.pixelSize: 14
                            }
                            
                            onClicked: csvFileDialog.open()
                        }
                    }
                    
                    // Selected file info
                    Label {
                        text: selectedCsvFile ? "File: " + selectedCsvFile : "No file selected - click 'Select CSV File' to load data"
                        font.pixelSize: 12
                        color: selectedCsvFile ? "#a6e3a1" : "#9399b2"
                        elide: Text.ElideMiddle
                        Layout.fillWidth: true
                    }
                    
                    // Chart type selector
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        visible: selectedChannel >= 0
                        
                        Label {
                            text: "Plot Type:"
                            font.pixelSize: 14
                            color: "#cdd6f4"
                        }
                        
                        ButtonGroup {
                            id: plotTypeGroup
                            onClicked: function(button) {
                                currentPlotType = button.plotType
                                updateChartData()
                            }
                        }
                        
                        Repeater {
                            model: [
                                { text: "Voltage", type: "voltage" },
                                { text: "Current", type: "current" },
                                { text: "Temperature", type: "temperature" }
                            ]
                            
                            Button {
                                text: modelData.text
                                property string plotType: modelData.type
                                checkable: true
                                checked: modelData.type === "voltage"
                                ButtonGroup.group: plotTypeGroup
                                
                                background: Rectangle {
                                    color: parent.checked ? "#89b4fa" : (parent.hovered ? "#585b70" : "#45475a")
                                    radius: 6
                                }
                                
                                contentItem: Text {
                                    text: parent.text
                                    color: parent.checked ? "#181825" : "#cdd6f4"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    font.bold: parent.checked
                                    font.pixelSize: 14
                                }
                            }
                        }
                        
                        Item { width: 20 }
                        
                        // Axis range controls
                        Rectangle {
                            width: 1
                            height: 30
                            color: "#45475a"
                        }
                        
                        Button {
                            text: "📐 Axis Settings"
                            Layout.preferredHeight: 36
                            
                            background: Rectangle {
                                color: parent.down ? "#6c7086" : (parent.hovered ? "#585b70" : "#45475a")
                                border.color: "#f9e2af"
                                radius: 6
                            }
                            
                            contentItem: Text {
                                text: parent.text
                                color: "#cdd6f4"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                font.pixelSize: 13
                            }
                            
                            onClicked: axisSettingsPopup.open()
                        }
                        
                        Item { Layout.fillWidth: true }
                    }
                    
                    // Chart
                    ChartView {
                        id: chartView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        antialiasing: true
                        backgroundColor: "#313244"
                        plotAreaColor: "#1e1e2e"
                        titleColor: "#cdd6f4"
                        legend.visible: false
                        theme: ChartView.ChartThemeDark
                        visible: selectedChannel >= 0
                        
                        ValueAxis {
                            id: axisX
                            titleText: "Time (seconds)"
                            color: "#cdd6f4"
                            gridLineColor: "#45475a"
                            labelsColor: "#cdd6f4"
                        }
                        
                        ValueAxis {
                            id: axisY
                            color: "#cdd6f4"
                            gridLineColor: "#45475a"
                            labelsColor: "#cdd6f4"
                        }
                        
                        LineSeries {
                            id: dataSeries
                            axisX: axisX
                            axisY: axisY
                            color: "#89b4fa"
                            width: 2
                        }
                    }
                    
                    // Placeholder when no file selected
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: "#313244"
                        radius: 12
                        visible: selectedChannel < 0
                        
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 20
                            
                            Label {
                                text: "📊"
                                font.pixelSize: 64
                                Layout.alignment: Qt.AlignHCenter
                            }
                            
                            Label {
                                text: "No Data to Display"
                                font.pixelSize: 20
                                font.bold: true
                                color: "#cdd6f4"
                                Layout.alignment: Qt.AlignHCenter
                            }
                            
                            Label {
                                text: "Select a CSV file to view charts"
                                font.pixelSize: 14
                                color: "#9399b2"
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }
                    
                    // Statistics panel
                    Rectangle {
                        Layout.fillWidth: true
                        height: 80
                        color: "#313244"
                        radius: 8
                        border.color: "#45475a"
                        visible: selectedChannel >= 0
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 15
                            spacing: 30
                            
                            ColumnLayout {
                                spacing: 5
                                Label {
                                    text: "Data Points"
                                    font.pixelSize: 12
                                    color: "#9399b2"
                                }
                                Label {
                                    text: csvModel ? csvModel.pointCount.toString() : "0"
                                    font.pixelSize: 18
                                    font.bold: true
                                    color: "#89b4fa"
                                }
                            }
                            
                            Rectangle { width: 1; Layout.fillHeight: true; color: "#45475a" }
                            
                            ColumnLayout {
                                spacing: 5
                                Label {
                                    text: currentPlotType === "voltage" ? "Min Voltage" : 
                                          currentPlotType === "current" ? "Min Current" : "Min Temp"
                                    font.pixelSize: 12
                                    color: "#9399b2"
                                }
                                Label {
                                    text: {
                                        if (!csvModel) return "--"
                                        if (currentPlotType === "voltage") return csvModel.minVoltage.toFixed(3) + " V"
                                        if (currentPlotType === "current") return csvModel.minCurrent.toFixed(3) + " A"
                                        return csvModel.minTemperature.toFixed(2) + " °C"
                                    }
                                    font.pixelSize: 18
                                    font.bold: true
                                    color: "#f38ba8"
                                }
                            }
                            
                            Rectangle { width: 1; Layout.fillHeight: true; color: "#45475a" }
                            
                            ColumnLayout {
                                spacing: 5
                                Label {
                                    text: currentPlotType === "voltage" ? "Max Voltage" : 
                                          currentPlotType === "current" ? "Max Current" : "Max Temp"
                                    font.pixelSize: 12
                                    color: "#9399b2"
                                }
                                Label {
                                    text: {
                                        if (!csvModel) return "--"
                                        if (currentPlotType === "voltage") return csvModel.maxVoltage.toFixed(3) + " V"
                                        if (currentPlotType === "current") return csvModel.maxCurrent.toFixed(3) + " A"
                                        return csvModel.maxTemperature.toFixed(2) + " °C"
                                    }
                                    font.pixelSize: 18
                                    font.bold: true
                                    color: "#a6e3a1"
                                }
                            }
                            
                            Rectangle { width: 1; Layout.fillHeight: true; color: "#45475a" }
                            
                            ColumnLayout {
                                spacing: 5
                                Label {
                                    text: currentPlotType === "voltage" ? "Avg Voltage" : 
                                          currentPlotType === "current" ? "Avg Current" : "Avg Temp"
                                    font.pixelSize: 12
                                    color: "#9399b2"
                                }
                                Label {
                                    text: {
                                        if (!csvModel) return "--"
                                        if (currentPlotType === "voltage") return csvModel.avgVoltage.toFixed(3) + " V"
                                        if (currentPlotType === "current") return csvModel.avgCurrent.toFixed(3) + " A"
                                        return csvModel.avgTemperature.toFixed(2) + " °C"
                                    }
                                    font.pixelSize: 18
                                    font.bold: true
                                    color: "#f9e2af"
                                }
                            }
                            
                            Item { Layout.fillWidth: true }
                        }
                    }
                }
            }
            
            // ===== TAB 3: Application Settings =====
            Rectangle {
                color: "#1e1e2e"
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 30
                    spacing: 25
                    
                    Label {
                        text: "Application Settings"
                        font.pixelSize: 28
                        font.bold: true
                        color: "#89b4fa"
                    }
                    
                    Label {
                        text: "Configure application preferences and behavior"
                        font.pixelSize: 14
                        color: "#9399b2"
                    }
                    
                    Item { Layout.fillHeight: true }
                    
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 300
                        height: 200
                        color: "#313244"
                        radius: 12
                        border.color: "#45475a"
                        
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 15
                            
                            Label {
                                text: "⚙️"
                                font.pixelSize: 48
                                Layout.alignment: Qt.AlignHCenter
                            }
                            
                            Label {
                                text: "Coming Soon"
                                font.pixelSize: 18
                                font.bold: true
                                color: "#f9e2af"
                                Layout.alignment: Qt.AlignHCenter
                            }
                            
                            Label {
                                text: "Settings will be available here"
                                font.pixelSize: 12
                                color: "#9399b2"
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }
                    
                    Item { Layout.fillHeight: true }
                }
            }
        }
    }
    
    // Helper function to calculate default Y-axis range based on plot type
    function getDefaultYRange(plotType, minVal, maxVal) {
        if (plotType === "temperature") {
            // Temperature can be negative: use min - 20 to max + 20
            return { min: minVal - 20, max: maxVal + 20 }
        } else {
            // Voltage and Current: start from 0 to max + 10%
            var yMax = maxVal * 1.1
            if (yMax <= 0) yMax = 1  // Ensure some range if max is 0 or negative
            return { min: 0, max: yMax }
        }
    }
    
    // Helper function to validate and apply axis ranges
    function applyAxisRanges() {
        if (useAutoYAxis) {
            axisY.min = dataYMin
            axisY.max = dataYMax
        } else {
            // Validate custom Y range
            var yMin = customYMin
            var yMax = customYMax
            
            // Ensure min < max
            if (yMin >= yMax) {
                yMax = yMin + 1
            }
            
            axisY.min = yMin
            axisY.max = yMax
        }
        
        if (useAutoXAxis) {
            axisX.min = 0
            axisX.max = dataXMax
        } else {
            // Validate custom X range
            var xMin = customXMin
            var xMax = customXMax
            
            // Ensure min >= 0 for time axis
            if (xMin < 0) xMin = 0
            
            // Ensure min < max
            if (xMin >= xMax) {
                xMax = xMin + 1
            }
            
            axisX.min = xMin
            axisX.max = xMax
        }
    }
    
    // Helper function to update chart
    function updateChartData() {
        if (!csvModel || selectedChannel < 0) return
        
        dataSeries.clear()
        
        var data
        var minVal
        var maxVal
        if (currentPlotType === "voltage") {
            data = csvModel.getVoltageData()
            axisY.titleText = "Voltage (V)"
            minVal = csvModel.minVoltage
            maxVal = csvModel.maxVoltage
        } else if (currentPlotType === "current") {
            data = csvModel.getCurrentData()
            axisY.titleText = "Current (A)"
            minVal = csvModel.minCurrent
            maxVal = csvModel.maxCurrent
        } else {
            data = csvModel.getTemperatureData()
            axisY.titleText = "Temperature (°C)"
            minVal = csvModel.minTemperature
            maxVal = csvModel.maxTemperature
        }
        
        // Calculate default Y-axis range based on plot type
        var yRange = getDefaultYRange(currentPlotType, minVal, maxVal)
        dataYMin = yRange.min
        dataYMax = yRange.max
        
        var maxTime = 0
        for (var i = 0; i < data.length; i++) {
            var point = data[i]
            dataSeries.append(point.x, point.y)
            maxTime = Math.max(maxTime, point.x)
        }
        
        dataXMax = maxTime > 0 ? maxTime : 100
        
        // Apply the axis ranges (auto or custom)
        applyAxisRanges()
    }
    
    Connections {
        target: csvModel
        function onDataChanged() {
            updateChartData()
        }
    }
    
    Connections {
        target: deviceManager
        function onDownloadComplete() {
            if (deviceManager) deviceManager.getReceivedFilesList()
        }
    }
    
    Component.onCompleted: {
        if (deviceManager) deviceManager.refreshPorts()
    }
    
    // Axis Settings Popup
    Popup {
        id: axisSettingsPopup
        anchors.centerIn: parent
        width: 450
        height: 420
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        
        background: Rectangle {
            color: "#313244"
            radius: 12
            border.color: "#45475a"
            border.width: 2
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 15
            
            Label {
                text: "📐 Axis Range Settings"
                font.pixelSize: 20
                font.bold: true
                color: "#89b4fa"
            }
            
            Rectangle { height: 1; Layout.fillWidth: true; color: "#45475a" }
            
            // Y-Axis Settings
            Label {
                text: "Y-Axis (" + axisY.titleText + ")"
                font.pixelSize: 16
                font.bold: true
                color: "#f9e2af"
            }
            
            RowLayout {
                spacing: 15
                
                CheckBox {
                    id: autoYCheckbox
                    text: "Auto Range"
                    checked: useAutoYAxis
                    onCheckedChanged: {
                        useAutoYAxis = checked
                        applyAxisRanges()
                    }
                    
                    indicator: Rectangle {
                        implicitWidth: 20
                        implicitHeight: 20
                        x: parent.leftPadding
                        y: parent.height / 2 - height / 2
                        radius: 4
                        color: parent.checked ? "#89b4fa" : "#45475a"
                        border.color: "#89b4fa"
                        
                        Text {
                            text: "✓"
                            color: "#181825"
                            anchors.centerIn: parent
                            visible: parent.parent.checked
                            font.bold: true
                        }
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: "#cdd6f4"
                        leftPadding: parent.indicator.width + 8
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                
                Label {
                    text: "Current: " + dataYMin.toFixed(2) + " to " + dataYMax.toFixed(2)
                    font.pixelSize: 12
                    color: "#9399b2"
                    visible: useAutoYAxis
                }
            }
            
            RowLayout {
                spacing: 15
                enabled: !useAutoYAxis
                opacity: useAutoYAxis ? 0.5 : 1.0
                
                Label {
                    text: "Min:"
                    font.pixelSize: 14
                    color: "#cdd6f4"
                }
                
                TextField {
                    id: yMinField
                    Layout.preferredWidth: 100
                    text: customYMin.toFixed(2)
                    validator: DoubleValidator { bottom: -999999; top: 999999 }
                    color: "#cdd6f4"
                    
                    background: Rectangle {
                        color: "#45475a"
                        radius: 4
                        border.color: parent.focus ? "#89b4fa" : "#585b70"
                    }
                    
                    onEditingFinished: {
                        var val = parseFloat(text)
                        if (!isNaN(val)) {
                            customYMin = val
                            applyAxisRanges()
                        }
                    }
                }
                
                Label {
                    text: "Max:"
                    font.pixelSize: 14
                    color: "#cdd6f4"
                }
                
                TextField {
                    id: yMaxField
                    Layout.preferredWidth: 100
                    text: customYMax.toFixed(2)
                    validator: DoubleValidator { bottom: -999999; top: 999999 }
                    color: "#cdd6f4"
                    
                    background: Rectangle {
                        color: "#45475a"
                        radius: 4
                        border.color: parent.focus ? "#89b4fa" : "#585b70"
                    }
                    
                    onEditingFinished: {
                        var val = parseFloat(text)
                        if (!isNaN(val)) {
                            customYMax = val
                            applyAxisRanges()
                        }
                    }
                }
            }
            
            Rectangle { height: 1; Layout.fillWidth: true; color: "#45475a" }
            
            // X-Axis Settings
            Label {
                text: "X-Axis (Time)"
                font.pixelSize: 16
                font.bold: true
                color: "#f9e2af"
            }
            
            RowLayout {
                spacing: 15
                
                CheckBox {
                    id: autoXCheckbox
                    text: "Auto Range"
                    checked: useAutoXAxis
                    onCheckedChanged: {
                        useAutoXAxis = checked
                        applyAxisRanges()
                    }
                    
                    indicator: Rectangle {
                        implicitWidth: 20
                        implicitHeight: 20
                        x: parent.leftPadding
                        y: parent.height / 2 - height / 2
                        radius: 4
                        color: parent.checked ? "#89b4fa" : "#45475a"
                        border.color: "#89b4fa"
                        
                        Text {
                            text: "✓"
                            color: "#181825"
                            anchors.centerIn: parent
                            visible: parent.parent.checked
                            font.bold: true
                        }
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: "#cdd6f4"
                        leftPadding: parent.indicator.width + 8
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                
                Label {
                    text: "Current: 0 to " + dataXMax.toFixed(2)
                    font.pixelSize: 12
                    color: "#9399b2"
                    visible: useAutoXAxis
                }
            }
            
            RowLayout {
                spacing: 15
                enabled: !useAutoXAxis
                opacity: useAutoXAxis ? 0.5 : 1.0
                
                Label {
                    text: "Min:"
                    font.pixelSize: 14
                    color: "#cdd6f4"
                }
                
                TextField {
                    id: xMinField
                    Layout.preferredWidth: 100
                    text: customXMin.toFixed(2)
                    validator: DoubleValidator { bottom: 0; top: 999999 }
                    color: "#cdd6f4"
                    
                    background: Rectangle {
                        color: "#45475a"
                        radius: 4
                        border.color: parent.focus ? "#89b4fa" : "#585b70"
                    }
                    
                    onEditingFinished: {
                        var val = parseFloat(text)
                        if (!isNaN(val) && val >= 0) {
                            customXMin = val
                            applyAxisRanges()
                        }
                    }
                }
                
                Label {
                    text: "Max:"
                    font.pixelSize: 14
                    color: "#cdd6f4"
                }
                
                TextField {
                    id: xMaxField
                    Layout.preferredWidth: 100
                    text: customXMax.toFixed(2)
                    validator: DoubleValidator { bottom: 0; top: 999999 }
                    color: "#cdd6f4"
                    
                    background: Rectangle {
                        color: "#45475a"
                        radius: 4
                        border.color: parent.focus ? "#89b4fa" : "#585b70"
                    }
                    
                    onEditingFinished: {
                        var val = parseFloat(text)
                        if (!isNaN(val) && val >= 0) {
                            customXMax = val
                            applyAxisRanges()
                        }
                    }
                }
            }
            
            Item { Layout.fillHeight: true }
            
            // Buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                
                Button {
                    text: "Reset to Auto"
                    Layout.preferredWidth: 120
                    
                    background: Rectangle {
                        color: parent.down ? "#6c7086" : (parent.hovered ? "#585b70" : "#45475a")
                        radius: 6
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: "#cdd6f4"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        useAutoYAxis = true
                        useAutoXAxis = true
                        applyAxisRanges()
                    }
                }
                
                Item { Layout.fillWidth: true }
                
                Button {
                    text: "Close"
                    Layout.preferredWidth: 100
                    
                    background: Rectangle {
                        color: parent.down ? "#7f849c" : (parent.hovered ? "#6c7086" : "#89b4fa")
                        radius: 6
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: "#181825"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.bold: true
                    }
                    
                    onClicked: axisSettingsPopup.close()
                }
            }
        }
    }
}
