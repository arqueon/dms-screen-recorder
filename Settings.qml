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
        text: "Inicia, detiene y configura grabaciones de pantalla en Wayland (niri, Hyprland, etc.). Requiere gpu-screen-recorder instalado."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    SelectionSetting {
        settingKey: "fps"
        label: "Frames por segundo (FPS)"
        description: "Tasa de grabación"
        options: [
            { label: "30 FPS", value: "30" },
            { label: "60 FPS", value: "60" }
        ]
        defaultValue: "60"
    }

    SelectionSetting {
        settingKey: "quality"
        label: "Calidad de vídeo"
        description: "Calidad de codificación h264"
        options: [
            { label: "Media", value: "medium" },
            { label: "Alta", value: "high" },
            { label: "Muy alta", value: "very_high" }
        ]
        defaultValue: "very_high"
    }

    ToggleSetting {
        settingKey: "recordCursor"
        label: "Grabar cursor"
        description: "Incluir el puntero del ratón en la grabación"
        defaultValue: true
    }

    SelectionSetting {
        settingKey: "captureSource"
        label: "Origen de captura"
        description: "portal = elegir ventana/pantalla; screen = primera pantalla"
        options: [
            { label: "Portal (elegir)", value: "portal" },
            { label: "Pantalla completa", value: "screen" }
        ]
        defaultValue: "portal"
    }

    StringSetting {
        settingKey: "outputDir"
        label: "Carpeta de grabaciones"
        description: "Vacío = ~/Videos/Screencasting"
        placeholder: "${XDG_VIDEOS_DIR:-$HOME/Videos}/Screencasting"
        defaultValue: ""
    }
}
