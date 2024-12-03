#Requires AutoHotkey v2.0
#MaxThreads 30

; =============================================================================
; Global variables (Customisable)
; =============================================================================

; Path to nircmd.exe by Nir Sofer (Third party requirement for some functionality, https://www.nirsoft.net/utils/nircmd.html) 
PathToNircmd := "nircmd.exe"

; The order and names of the current modes
VolumeButtonModes := ["Volume", "Brightness"]

; The index of the mode (above) that is active when the program begins
VolumeButtonMode := 1

; The interval the volume will change each button press, if 0 will use default volume button functionpality
VolumeInterval := 0.00

; Will display volume notifications. Values: "Default", "Tray", "None"
VolumeNotification := "Default"

; The interval the brightness with change each button press
BrightnessInterval := 0.05

; Will display volume notifications. Values: "Tray", "None"
BrightnessNotification := "None"

; The when a button is pushed down that is buffered. Prevents accidentally pressing one volume button when trying to press both
VolumeButtonLockTimeMs := 75

; =============================================================================
; Global variables (Shouldn't need to be changed)
; =============================================================================

; Relative to the max value frmo nircmd
MaxVolumeValue := 65535

; Prevents both buttons being held to spin cycle
CycleModeLocked := false

; Used to buffer the vol down button to prevent using it when trying to cycle modes
VolDownLocked := false

; Used to buffer the vol up button to prevent using it when trying to cycle modes
VolUpLocked := false

; Prevents the [VolDownLocked] and [VolUpLocked] buffers from firing when a cycle was intended rather than pressing the buttons
PostCycleButtonLock := false

; Used to detect the down stroke of the volume down key press
VolDownHeld := false

; Used to detect the down stroke of the volume up key press
VolUpHeld := false

; =============================================================================
; Hooks
; =============================================================================
$Volume_Down::OnVolDownPress
$Volume_Up::OnVolUpPress
Volume_Down UP::OnVolDownRelease
Volume_Up UP::OnVolUpRelease

; =============================================================================
; Function (Actions)
; =============================================================================

VolDownAction() {
    Mode := CurrentVolumeButtonMode()
    if(Mode == "Volume") {
        AdjustVolumeDown()
    } else if(Mode == "Brightness") {
        AdjustBrightnessDown()
    } else {
        throw ValueError("VolumeButtonMode does not have a vol down action.", -1 Mode)
    }
}

VolUpAction() {
    Mode := CurrentVolumeButtonMode()
    if(Mode == "Volume") {
        AdjustVolumeUp()
    } else if(Mode == "Brightness") {
        AdjustBrightnessUp()
    } else {
        throw ValueError("VolumeButtonMode does not have a vol up action.", -1 Mode)
    }
}

; =============================================================================
; Functions (Buttons and button locks/buffers)
; =============================================================================

OnVolDownPress() {
    ; Check for Both keys pressed
    if(VolUpHeld) {
        CycleVolumeButtonMode()
        return
    }

    ; Check for lock
    global VolDownLocked
    if(VolDownLocked) {
        return
    }

    ; Check for first down press
    global VolDownHeld
    if(!VolDownHeld) {
        VolDownHeld := true
        OnVolDownInitialPress()
        return
    }
    
    ; Normal action
    VolDownAction()
}

OnVolUpPress() {
    ; Check for both keys pressed
    if(VolDownHeld) {
        CycleVolumeButtonMode()
        return
    }

    ; Check for lock
    global VolUpLocked
    if(VolUpLocked) {
        return
    }

    ; Check for first down press
    global VolUpHeld
    if(!VolUpHeld) {
        VolUpHeld := true
        OnVolUpInitialPress()
        return
    }
    
    ; Normal action
    VolUpAction()
}

OnVolDownInitialPress() {
    global VolDownLocked
    VolDownLocked := true
    SetTimer(UnlockVolDown, VolumeButtonLockTimeMs)
}

OnVolUpInitialPress() {
    global VolUpLocked
    VolUpLocked := true
    SetTimer(UnlockVolUp, VolumeButtonLockTimeMs)
}

OnVolDownRelease() {
    global CycleModeLocked, VolDownHeld
    CycleModeLocked := false
    VolDownHeld := false
}

OnVolUpRelease() {
    global CycleModeLocked, VolUpHeld
    CycleModeLocked := false
    VolUpHeld := false
}

UnlockVolDown() {
    global VolDownLocked
    if(VolDownLocked) {
        VolDownLocked := false
        if(!PostCycleButtonLock) {
            VolDownAction()
        }
    }
}

UnlockVolUp() {
    global VolUpLocked
    if(VolUpLocked) {
        VolUpLocked := false
        if(!PostCycleButtonLock) {
            VolUpAction()
        }
    }
}

CycleVolumeButtonMode() {
    ; Check if locked
    global CycleModeLocked
    if(CycleModeLocked) {
        return
    }
    CycleModeLocked := true

    ; Apply post cycle lock
    global PostCycleButtonLock
    PostCycleButtonLock := true
    SetTimer(UnlockPostCycleButtonLock, VolumeButtonLockTimeMs)

    ; Cycle mode
    global VolumeButtonMode, VolumeButtonModeCount
    if(VolumeButtonMode == VolumeButtonModes.Length) {
        VolumeButtonMode := 1
    } else {
        VolumeButtonMode := VolumeButtonMode + 1
    }

    NotifyUser("Volume Button Mode: " CurrentVolumeButtonMode())
}

UnlockPostCycleButtonLock() {
    global PostCycleButtonLock
    PostCycleButtonLock := false
}

; =============================================================================
; Functions (Global data handlers)
; =============================================================================

CurrentVolumeButtonMode() {
    global VolumeButtonMode, VolumeButtonModeCount
    return VolumeButtonModes[VolumeButtonMode]
}

; =============================================================================
; Functions (Notifications)
; =============================================================================

NotifyUser(Message) {
    TrayTip
    TrayTip(Message)
}

; =============================================================================
; Functions (Action: Volume)
; =============================================================================

AdjustVolumeUp() {
    if(!VolumeInterval) {
        Send "{Volume_Up}"
        return
    }
    ManuallyAdjustVolume(MaxVolumeValue * VolumeInterval)
}

AdjustVolumeDown() {
    if(!VolumeInterval) {
        Send "{Volume_Down}"
        return
    }
    ManuallyAdjustVolume(MaxVolumeValue * VolumeInterval * -1)
}

ManuallyAdjustVolume(VolumeChange) {
    DisplayVolumeChange(VolumeChange)
    Run(PathToNircmd " changesysvolume " VolumeChange)
}

DisplayVolumeChange(VolumeChange) {
    if(VolumeNotification == "Default") {
        send "{Volume_Mute}"
        send "{Volume_Mute}"
    } else if(VolumeNotification == "Tray" && VolumeChange) {
        NotifyUser("Volume: " VolumeChange)
    }
}

; =============================================================================
; Functions (Action: Brightness)
; =============================================================================

AdjustBrightnessUp() {
    AdjustBrightness(BrightnessInterval * 100)
}

AdjustBrightnessDown() {
    AdjustBrightness(BrightnessInterval * -100)
}

AdjustBrightness(BrightnessChange) {
    Run(PathToNircmd " changebrightness " BrightnessChange)
    DisplayBrightnessChange(BrightnessChange)
}

DisplayBrightnessChange(BrightnessChange) {
    if(BrightnessNotification == "Tray" && BrightnessChange) {
        NotifyUser("Brightness: " BrightnessChange)
    }
}
