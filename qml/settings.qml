import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import RinUI
import ClassWidgets.Plugins

/*!
    以管理员权限启动/重启 —— 设置页。

    两条互不相干的能力：
      1. 计划任务：登录 Windows 时以最高权限（RunLevel Highest）启动主程序；
      2. 以管理员权限重启：弹 UAC，把当前实例换成一个提权实例。
    创建 / 删除任务需要管理员权限，后端在后台线程里提权执行，完成后发 statusChanged，
    这里据此刷新状态并显示结果。

    注意：主程序自己也有一个「开机自启动」（注册表 Run），两者同时开着会在登录时
    把 Class Widgets 2 拉起两次，所以检测到它还开着时，这里只提供
    「关闭当前开机自启并创建管理员权限启动」这一条路。
*/

PluginPage {
    id: page
    pluginId: "com.classwidgets.startupasadmin"
    title: qsTr("以管理员权限启动/重启")

    property var info: ({})
    property bool busy: false
    property string resultText: ""
    property bool resultOk: true
    property string pendingAction: "create"   // create / disableAndCreate

    readonly property bool appAutoStart: info.appAutoStart === true
    readonly property bool taskExists: info.exists === true
    readonly property bool elevated: info.elevated === true
    // 主程序自己的开机自启开关在哪
    readonly property string autoStartWhere: qsTr("设置 → 通用 → 开机自启动")

    Component.onCompleted: Qt.callLater(reload)
    onBackendChanged: { if (backend) Qt.callLater(reload) }

    Connections {
        target: backend
        function onStatusChanged() {
            page.busy = false
            var r = backend ? backend.getLastResult() : null
            if (r && r.message)
                page.showResult(r.ok === true, String(r.message))
            page.reload()
        }
    }

    function reload() {
        if (!backend) return
        var s = backend.getStatus()
        if (s) info = s
    }

    function showResult(ok, text) {
        page.resultOk = ok
        page.resultText = text
        if (resultBar) {
            resultBar.opacity = 1
            resultBar.visible = text !== ""
        }
    }

    function hideResult() {
        page.resultText = ""
        if (resultBar) resultBar.visible = false
    }

    // 0 = 出错，1 = 待处理，2 = 已就绪
    function stateLevel() {
        if (info.supported === false || info.appFound === false) return 0
        if (info.exists !== true || info.upToDate !== true) return 1
        return 2
    }

    function stateShort() {
        if (info.supported === false) return qsTr("系统不支持")
        if (info.appFound === false) return qsTr("未找到主程序")
        if (info.exists !== true) return qsTr("尚未创建")
        if (info.upToDate !== true) return qsTr("建议更新")
        return qsTr("已就绪")
    }

    function stateText() {
        if (info.supported === false) return qsTr("当前系统不支持（仅 Windows）")
        if (info.appFound === false) return qsTr("未找到主程序")
        if (info.exists !== true) return qsTr("尚未创建计划任务")
        if (info.upToDate !== true) return qsTr("已创建，但指向的程序已变化，建议更新")
        return qsTr("已就绪：登录时将自动以管理员身份启动")
    }

    function stateColor() {
        if (stateLevel() === 0) return Theme.currentTheme.colors.systemCriticalColor
        if (stateLevel() === 1) return Theme.currentTheme.colors.systemCautionColor
        return Theme.currentTheme.colors.systemSuccessColor
    }

    // ── 动作 ────────────────────────────────────────────────

    function runPending() {
        if (!backend) return
        page.busy = true
        page.hideResult()
        if (page.pendingAction === "disableAndCreate")
            backend.requestDisableAutostartAndCreate()
        else
            backend.requestCreate()
    }

    // 主程序自己的开机自启还开着 → 先按主程序「重复打开」那样提示一次
    function beginCreate() {
        if (page.busy) return
        page.pendingAction = "create"
        if (page.appAutoStart)
            duplicateDialog.open()
        else
            page.runPending()
    }

    function beginDisableAutostartAndCreate() {
        if (page.busy) return
        page.pendingAction = "disableAndCreate"
        if (page.appAutoStart)
            duplicateDialog.open()
        else
            page.runPending()
    }

    function removeTask() {
        if (page.busy || !backend) return
        page.busy = true
        page.hideResult()
        backend.requestDelete()
    }

    function restartApp() {
        if (page.busy || !backend) return
        page.busy = true
        page.hideResult()
        backend.requestRestart()
    }

    // ── 重复打开提示（照主程序 CheckSingleInstanceDialog 的样子） ────

    Dialog {
        id: duplicateDialog
        title: qsTr("重复启动提醒")
        modal: true

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Icon {
                Layout.alignment: Qt.AlignTop
                size: 42
                name: "ic_fluent_warning_20_filled"
                color: Theme.currentTheme.colors.systemCautionColor
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("若已开启开机自启，在创建计划任务后会在下次开机时重复开启 Class Widgets 2，是否删除已创建的计划任务？")
            }
        }

        footer: DialogButtonBox {
            Layout.fillWidth: true

            Button {
                Layout.fillWidth: true
                text: qsTr("取消")
                onClicked: duplicateDialog.close()
            }

            Button {
                Layout.fillWidth: true
                text: qsTr("继续创建")
                highlighted: true
                onClicked: {
                    duplicateDialog.close()
                    page.runPending()
                }
            }
        }
    }

    // ── 页面内容 ────────────────────────────────────────────

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4

        // 计划任务状态
        Frame {
            Layout.fillWidth: true
            leftPadding: 18
            rightPadding: 18
            topPadding: 16
            bottomPadding: 16

            ColumnLayout {
                anchors.fill: parent
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Icon {
                        Layout.alignment: Qt.AlignTop
                        size: 22
                        name: "ic_fluent_shield_checkmark_20_regular"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            typography: Typography.Body
                            text: qsTr("计划任务状态")
                        }

                        Text {
                            Layout.fillWidth: true
                            typography: Typography.Caption
                            color: Theme.currentTheme.colors.textSecondaryColor
                            text: qsTr("计划任务会在你登录 Windows 时，以最高权限启动 Class Widgets 2。")
                        }
                    }

                    PillButton {
                        text: page.stateShort()
                        checkable: false
                        highlighted: page.stateLevel() === 2
                    }

                    ToolButton {
                        icon.name: "ic_fluent_arrow_sync_20_regular"
                        enabled: !page.busy
                        onClicked: page.reload()

                        ToolTip {
                            text: qsTr("刷新状态")
                            parent: parent
                            visible: parent.hovered
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: Math.max(1, Theme.currentTheme.appearance.borderWidth)
                    color: Theme.currentTheme.colors.cardBorderColor
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        Layout.fillWidth: true
                        typography: Typography.BodyStrong
                        color: page.stateColor()
                        text: page.stateText()
                    }

                    Text {
                        Layout.fillWidth: true
                        typography: Typography.Caption
                        color: Theme.currentTheme.colors.textSecondaryColor
                        text: qsTr("任务名称：") + (page.info.taskName || "")
                    }

                    Text {
                        Layout.fillWidth: true
                        typography: Typography.Caption
                        color: Theme.currentTheme.colors.textSecondaryColor
                        text: qsTr("主程序：") + (page.info.appPath || qsTr("未找到"))
                    }

                    Text {
                        Layout.fillWidth: true
                        typography: Typography.Caption
                        color: Theme.currentTheme.colors.textSecondaryColor
                        visible: page.taskExists
                        text: qsTr("已注册：") + (page.info.registeredExe || "")
                              + (page.info.runLevel ? qsTr("（运行级别 ") + page.info.runLevel + qsTr("）") : "")
                    }

                    Text {
                        Layout.fillWidth: true
                        typography: Typography.Caption
                        color: Theme.currentTheme.colors.textSecondaryColor
                        text: qsTr("当前运行权限：") + (page.elevated ? qsTr("管理员") : qsTr("标准用户"))
                    }

                    Text {
                        Layout.fillWidth: true
                        typography: Typography.Caption
                        visible: page.info.appFound === false
                        color: Theme.currentTheme.colors.systemCriticalColor
                        text: qsTr("没能自动找到主程序，请在下方「高级」里手动指定 Class Widgets 2 的 exe 路径。")
                    }
                }
            }
        }

        // 主程序自己的开机自启还开着时才会出现
        Frame {
            Layout.fillWidth: true
            visible: page.appAutoStart
            leftPadding: 18
            rightPadding: 18
            topPadding: 16
            bottomPadding: 16

            ColumnLayout {
                anchors.fill: parent
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Icon {
                        Layout.alignment: Qt.AlignTop
                        size: 22
                        name: "ic_fluent_warning_20_filled"
                        color: Theme.currentTheme.colors.systemCautionColor
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            typography: Typography.Body
                            text: qsTr("主程序自己也开着开机自启")
                        }

                        Text {
                            Layout.fillWidth: true
                            typography: Typography.Caption
                            color: Theme.currentTheme.colors.textSecondaryColor
                            text: qsTr("这两边都会在登录时启动 Class Widgets 2，同时开着就会启动两次。"
                                      + "可以在「" + page.autoStartWhere + "」里手动关掉，"
                                      + "也可以直接点下面的按钮，一次关掉并创建管理员权限启动。")
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Button {
                        text: qsTr("关闭当前开机自启并创建管理员权限启动")
                        highlighted: true
                        enabled: !page.busy && page.info.appFound !== false
                        onClicked: page.beginDisableAutostartAndCreate()
                    }
                }
            }
        }

        // 动作
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Button {
                // 主程序自启还开着时，创建动作在上面的提示里
                visible: !page.appAutoStart
                text: page.taskExists ? qsTr("更新计划任务") : qsTr("创建计划任务")
                highlighted: !page.taskExists
                enabled: !page.busy && page.info.appFound !== false
                onClicked: page.beginCreate()
            }

            Button {
                text: qsTr("以管理员权限重启")
                highlighted: page.taskExists
                enabled: !page.busy && page.info.appFound !== false
                onClicked: page.restartApp()
            }

            Button {
                visible: page.taskExists
                text: qsTr("删除计划任务")
                enabled: !page.busy
                onClicked: page.removeTask()
            }

            BusyIndicator {
                Layout.alignment: Qt.AlignVCenter
                size: 16
                running: page.busy
                visible: page.busy
            }

            Text {
                Layout.fillWidth: true
                verticalAlignment: Text.AlignVCenter
                visible: page.busy
                typography: Typography.Caption
                color: Theme.currentTheme.colors.textSecondaryColor
                text: qsTr("正在等待管理员授权…")
            }
        }

        InfoBar {
            id: resultBar
            Layout.fillWidth: true
            visible: false
            severity: page.resultOk ? Severity.Success : Severity.Error
            text: page.resultText
        }

        // 高级
        SettingExpander {
            Layout.fillWidth: true
            icon.name: "ic_fluent_settings_20_regular"
            title: qsTr("高级")
            description: qsTr("自动探测失败，或想换一个任务名时使用。")
            expanded: false

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12

                SettingCard {
                    Layout.fillWidth: true
                    title: qsTr("主程序路径")
                    description: qsTr("留空则自动探测。填错会导致自启动失败。")

                    TextField {
                        Layout.preferredWidth: 400
                        placeholderText: qsTr("例如 D:\\ClassWidgets\\Class Widgets 2.exe")
                        text: page.info.customExe || ""
                        selectByMouse: true
                        onEditingFinished: {
                            if (backend) backend.setCustomExe(text)
                            page.reload()
                        }
                    }
                }

                SettingCard {
                    Layout.fillWidth: true
                    title: qsTr("计划任务名称")
                    description: qsTr("显示在「任务计划程序」里的名字。改名后需要重新创建任务。")

                    TextField {
                        Layout.preferredWidth: 280
                        text: page.info.taskName || ""
                        selectByMouse: true
                        onEditingFinished: {
                            if (backend) backend.setTaskName(text)
                            page.reload()
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            typography: Typography.Caption
            color: Theme.currentTheme.colors.textSecondaryColor
            text: qsTr("提示：创建 / 删除计划任务、以管理员权限重启都会弹 UAC 授权窗口；"
                      + "创建好的任务不会随插件卸载而删除，需要时请回到这里手动删除；"
                      + "若之后移动了 Class Widgets 2 的位置，请回来点一次「更新计划任务」。")
        }
    }
}
