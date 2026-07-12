import QtQuick
import qs.Common

QtObject {
    function check(done) {
        Proc.runCommand("screenRecorder.startupCheck", ["sh", "-c", "command -v gpu-screen-recorder >/dev/null 2>&1"], (stdout, exitCode) => {
            if (exitCode === 0) {
                done(null)
                return
            }
            done({
                title: "gpu-screen-recorder is required",
                details: "Install the native gpu-screen-recorder package, then enable the plugin again. Flatpak's GUI bundle does not provide the required command."
            })
        })
    }
}
