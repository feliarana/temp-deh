package main

import (
	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/app"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/widget"

	"ps-cmdr/tasks"
)

func main() {
	a := app.New()
	w := a.NewWindow("Tools Installer")

	ui := widget.NewMultiLineEntry()
	ui.SetPlaceHolder("Tasks in progress will be displayed here...when ready, please click the button below.")
	ui.Wrapping = fyne.TextWrapWord

	installButton := widget.NewButton("Install Tools", nil)

	installButton.OnTapped = func() {
		installButton.Disable()
		go func() {
			tasks.RunIt(ui, []map[string]interface{}{
				{"name": "Setting up homebrew (pkg manager)", "task": tasks.InstallBrew},
				{"name": "Installing packages (brew)", "task": tasks.PkgInstall},
				{"name": "Installing casks (brew)", "task": tasks.CaskInstall},
				{"name": "Setting up AWS configuration", "task": tasks.AwsSetupCfg},
			}, w, installButton)
		}()
	}

	w.SetContent(container.NewBorder(nil, installButton, nil, nil, ui))

	w.Resize(fyne.NewSize(600, 400))
	w.ShowAndRun()
}
