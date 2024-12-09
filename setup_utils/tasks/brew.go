package tasks

import (
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
	"os/exec"
	"strings"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/widget"
)

func downloadBrewInstallScript() (string, error) {
	resp, err := http.Get("https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh")
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	return string(body), nil
}

func ConfigureShell(ui *widget.Entry, window fyne.Window) (string, error) {

	appendText(ui, "Checking if profile is configured...")
	brewenv := `eval "$(/opt/homebrew/bin/brew shellenv)"`
	zprofilePath := os.Getenv("HOME") + "/.zprofile"
	cfgExists, err := lineExistsIn(brewenv,zprofilePath)

	if err != nil {
		return "", fmt.Errorf("failed to find config in .zprofile: %s", err.Error())
	}

	if !cfgExists {
		file, err := os.OpenFile(zprofilePath, os.O_APPEND|os.O_WRONLY|os.O_CREATE, 0600)
		if err != nil {
			return "", fmt.Errorf("Failed to open .zprofile: %s", err.Error())
		}
		defer file.Close()

		if _, err := file.WriteString("\n" + brewenv + "\n"); err != nil {
			return "", fmt.Errorf("Failed to append to .zprofile: %s", err.Error())
		}
		appendText(ui, ".zprofile updated to use brew. Please open a new shell or source .zprofile.")
	} else {
		appendText(ui, ".zprofile already setup.")
	}
	return "shell configuration done", nil
}

func InstallBrew(ui *widget.Entry, window fyne.Window) (string, error) {

	appendText(ui, "Checking if Homebrew is already installed...")
	cmd := exec.Command("command", "-v", "brew")
	if err := cmd.Run(); err == nil {
		return "Homebrew already installed.", nil
	}

	password, err := promptForPassword(window)
	if err != nil {
		return "", err
	}

	appendText(ui, "Downloading Homebrew install script...")
	installScript, err := downloadBrewInstallScript()
	if err != nil {
		return "", err
	}

	appendText(ui, "Starting Homebrew install script...")

	askPassScript, err := createAskPassScript(password)
	if err != nil {
		return "", err
	}
	defer os.Remove(askPassScript)

	cmd = exec.Command("bash", "-c", installScript)
	cmd.Env = append(os.Environ(), fmt.Sprintf("SUDO_ASKPASS=%s", askPassScript), "NONINTERACTIVE=1")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	err = cmd.Start()
	if err != nil {
		return "", err
	}

	if err := cmd.Wait(); err != nil {
		return "", fmt.Errorf("Homebrew installation failed: %s", err.Error())
	}

	appendText(ui, "Homebrew installed.")
	appendText(ui, "Assessing shell configuration")
	out, err := ConfigureShell(ui, window)
	if err != nil {
		return "", err
	}
	appendText(ui, out)

	return "Homebrew installed and .zprofile updated.", nil
}

func runBrewCommand(args ...string) (string, error) {
	cmd := exec.Command("bash", "-c", fmt.Sprintf(`eval "$(/opt/homebrew/bin/brew shellenv)" && brew %s`, strings.Join(args, " ")))

	output, err := cmd.CombinedOutput()
	if err != nil {
		return string(output), fmt.Errorf("error: %v, output: %s", err, output)
	}

	return string(output), nil
}

func CaskInstall(ui *widget.Entry, window fyne.Window) (string, error) {

	casks := []string{"aws-vault", "docker"}

	var output strings.Builder

	for _, cask := range casks {
		result, err := runBrewCommand("list", "--cask", cask)
		if err == nil {
			//output.WriteString(fmt.Sprintf("%s is already installed.\n", cask))
			appendText(ui, fmt.Sprintf("%s is already installed.\n", cask))
			continue
		} else {
			//output.WriteString(fmt.Sprintf("Installing %s...\n", cask))
			appendText(ui, fmt.Sprintf("Installing %s...", cask))
			result, err = runBrewCommand("install", "--cask", cask)
			if err != nil {
				if strings.Contains(result, "already a cask at") || strings.Contains(result, "already a Binary at") {
					//output.WriteString(fmt.Sprintf("%s is already installed.", cask))
					appendText(ui, fmt.Sprintf("%s is already installed.", cask))
				} else {
					//output.WriteString(fmt.Sprintf("Error installing %s: %v\n", cask, err))
					appendText(ui, fmt.Sprintf("Error installing %s: %v\n", cask, err))
					//output.WriteString(result)
					return result, err
				}
			} else {
				output.WriteString(result)
			}
		}
	}

	return output.String(), nil
}

func PkgInstall(ui *widget.Entry, window fyne.Window) (string, error) {

	packages := []string{"git", "git-flow", "docker-compose", "coreutils", "jq", "bash"}

	var output strings.Builder

	for _, pkg := range packages {
		result, err := runBrewCommand("list", "--formula", pkg)
		if err == nil {
			//output.WriteString(fmt.Sprintf("%s is already installed.\n", pkg))
			appendText(ui, fmt.Sprintf("%s is already installed.\n", pkg))
		} else {
			appendText(ui, fmt.Sprintf("Installing %s...\n", pkg))
			result, err = runBrewCommand("install", pkg)
			if err != nil {
				appendText(ui, fmt.Sprintf("Error installing %s: %v\n", pkg, err))
				//				output.WriteString(fmt.Sprintf("Error installing %s: %v\n", pkg, err))
				output.WriteString(result)
				return output.String(), err
			}
			return result, nil
		}
	}
	return output.String(), nil
}
