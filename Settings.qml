import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "screenRecorder"

    StyledText {
        width: parent.width
        text: "Screen Recorder (gpu-screen-recorder)"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }
    StyledText {
        width: parent.width
        text: "Start, stop, and configure screen captures in Wayland (niri, Hyprland, etc.). Requires gpu-screen-recorder installed."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    SelectionSetting {
        settingKey: "fps"
        label: "Frames per second (FPS)"
        description: "Recording framerate"
        options: [
            { label: "30 FPS", value: "30" },
            { label: "60 FPS", value: "60" }
        ]
        defaultValue: "60"
    }

    SelectionSetting {
        settingKey: "quality"
        label: "Video quality"
        description: "h264 encoding quality"
        options: [
            { label: "Medium", value: "medium" },
            { label: "High", value: "high" },
            { label: "Very high", value: "very_high" }
        ]
        defaultValue: "very_high"
    }

    ToggleSetting {
        settingKey: "recordCursor"
        label: "Record cursor"
        description: "Include the mouse pointer in the recording"
        defaultValue: true
    }

    SelectionSetting {
        settingKey: "captureSource"
        label: "Capture source"
        description: "portal = choose window/screen; screen = first screen"
        options: [
            { label: "Portal (choose)", value: "portal" },
            { label: "Full screen", value: "screen" }
        ]
        defaultValue: "portal"
    }

    StringSetting {
        settingKey: "outputDir"
        label: "Recordings folder"
        description: "Empty = ~/Videos/Screencasting"
        placeholder: "${XDG_VIDEOS_DIR:-$HOME/Videos}/Screencasting"
        defaultValue: ""
    }
}
