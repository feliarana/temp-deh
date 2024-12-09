package tasks

import (
	"fmt"
	"io/ioutil"
	"os"
	"strings"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/widget"
)


/// TODO: fixme
func runTask(ui *widget.Entry, task map[string]interface{}, window fyne.Window) error {
    runnerName := task["name"].(string)
    taskFn := task["task"].(func(*widget.Entry, fyne.Window) (string, error))
    appendText(ui, fmt.Sprintf("Running task: [%s]", runnerName))
    result, err := taskFn(ui, window)
    if err != nil {
        appendText(ui, err.Error())
        return err
    }
    appendText(ui, result)
    appendText(ui, fmt.Sprintf("Finished task: [%s]", runnerName))
    return nil
}

/// Main runner to execute tasks. Tasks are just pairs of string names and functions
func RunIt(ui *widget.Entry, tasks []map[string]interface{}, window fyne.Window, button *widget.Button) {
    button.Disable()
    for _, task := range tasks {
        if err := runTask(ui, task, window); err != nil {
            appendText(ui, fmt.Sprintf("Execution stopped due to error: %s", err.Error()))
            continue
        }
    }
    sayDone(ui)
    button.Enable()

    // Clear the cached sudo password
    ClearSudoPassword()
}

func sayDone(ui *widget.Entry) {
	appendText(ui, "Work complete.\nYou can quit or retry if you experience issues.\n")
}

func createAskPassScript(password string) (string, error) {
    // Escape single quotes in the password
    escapedPassword := strings.ReplaceAll(password, `'`, `'\''`)
    scriptContent := fmt.Sprintf(`#!/bin/sh
echo '%s'
`, escapedPassword)

    tmpFile, err := ioutil.TempFile("", "askpass-*.sh")
    if err != nil {
        return "", err
    }
    tmpFile.Close()

    if err := os.WriteFile(tmpFile.Name(), []byte(scriptContent), 0700); err != nil {
        return "", err
    }

    return tmpFile.Name(), nil
}
