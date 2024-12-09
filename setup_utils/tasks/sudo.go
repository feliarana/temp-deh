package tasks

import (
    "sync"

    "fyne.io/fyne/v2"
)

var (
    sudoPassword     string
    sudoPasswordOnce sync.Once
    sudoPasswordErr  error
)

func GetSudoPassword(window fyne.Window) (string, error) {
    sudoPasswordOnce.Do(func() {
        sudoPassword, sudoPasswordErr = promptForPassword(window)
    })
    return sudoPassword, sudoPasswordErr
}

func ClearSudoPassword() {
    sudoPassword = ""
    sudoPasswordOnce = sync.Once{}
}
