package tasks

import (
	"archive/zip"
	"errors"
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"path/filepath"
	"strings"
	"time"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/dialog"
	"fyne.io/fyne/v2/widget"
)

func appendText(ui *widget.Entry, text string) {
	ui.SetText(strings.TrimSpace(ui.Text + "\n" + text))
}

func promptForPassword(window fyne.Window) (string, error) {
	passwordChan := make(chan string)
	defer close(passwordChan)

	passwordEntry := widget.NewPasswordEntry()
	passwordDialog := dialog.NewCustomConfirm("Password", "OK", "Cancel", passwordEntry, func(confirm bool) {
		if confirm {
			passwordChan <- passwordEntry.Text
		} else {
			passwordChan <- ""
		}
	}, window)
	passwordDialog.Show()

	select {
	case password := <-passwordChan:
		if strings.TrimSpace(password) == "" {
			return "", errors.New("No password entered")
		}
		return password, nil
	case <-time.After(30 * time.Second):
		passwordDialog.Hide()
		return "", errors.New("Password entry cancelled")
	}
}

func unzip(src string, dest string) error {
	r, err := zip.OpenReader(src)
	if err != nil {
		return err
	}
	defer r.Close()

	for _, f := range r.File {
		fpath := filepath.Join(dest, f.Name)
		// Check for ZipSlip vulnerability
		if !strings.HasPrefix(fpath, filepath.Clean(dest)+string(os.PathSeparator)) {
			return fmt.Errorf("illegal file path: %s", fpath)
		}
		if f.FileInfo().IsDir() {
			os.MkdirAll(fpath, os.ModePerm)
			continue
		}
		if err := os.MkdirAll(filepath.Dir(fpath), os.ModePerm); err != nil {
			return err
		}
		outFile, err := os.OpenFile(fpath, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, f.Mode())
		if err != nil {
			return err
		}
		rc, err := f.Open()
		if err != nil {
			return err
		}
		if _, err = io.Copy(outFile, rc); err != nil {
			outFile.Close()
			rc.Close()
			return err
		}
		outFile.Close()
		rc.Close()
	}
	return nil
}

func lineExistsIn(line, filePath string) (bool, error) {
	content, err := ioutil.ReadFile(filePath)
	if err != nil {
		if os.IsNotExist(err) {
			return false, nil
		}
		return false, err
	}

	lines := strings.Split(string(content), "\n")
	for _, l := range lines {
		if strings.TrimSpace(l) == line {
			return true, nil
		}
	}

	return false, nil
}
