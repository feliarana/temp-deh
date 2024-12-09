package tasks

import (
	"fmt"
	"io"
	"io/ioutil"
	"net/http"
	"os"
	"os/exec"
	"os/user"
	"path/filepath"
	"runtime"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/widget"
)

func AwsSetupCfg(ui *widget.Entry, window fyne.Window) (string, error) {
    defaultRegion := "us-east-1"
    appendText(ui, "Setting up AWS config")

    // Get the current user's username
    currentUser, err := user.Current()
    if err != nil {
        return "", fmt.Errorf("failed to get current user: %v", err)
    }
    profileName := currentUser.Username
    appendText(ui, fmt.Sprintf("Got user: %s", profileName))

    // Check if the AWS config file exists
    awsConfigPath := filepath.Join(currentUser.HomeDir, ".aws", "config")
    if _, err := os.Stat(awsConfigPath); err == nil {
        appendText(ui, "AWS config already exists")
    } else if os.IsNotExist(err) {
        // Create the .aws directory if it doesn't exist
        awsDir := filepath.Join(currentUser.HomeDir, ".aws")
        if _, err := os.Stat(awsDir); os.IsNotExist(err) {
            if err := os.Mkdir(awsDir, 0700); err != nil {
                return "", fmt.Errorf("failed to create ~/.aws directory: %v", err)
            }
        }

        // Write the AWS config file
        configContent := fmt.Sprintf(`[default]
region = %s
output = json

[profile %s]
region = %s
[plugins]
clisessionmanager = session-manager-plugin
`, defaultRegion, profileName, defaultRegion)

        if err := os.WriteFile(awsConfigPath, []byte(configContent), 0644); err != nil {
            return "", fmt.Errorf("failed to write AWS config file: %v", err)
        }
        appendText(ui, fmt.Sprintf("AWS config set up using %s for your profile name.", profileName))
    } else {
        return "", fmt.Errorf("failed to check AWS config file: %v", err)
    }

    if isSessionManagerPluginInstalled() {
        appendText(ui, "Session Manager Plugin is already installed.")
        return "Session Manager Plugin is already installed. AWS config done.", nil
    }
    // Create a temporary directory
    tempDir, err := ioutil.TempDir("", "sessionmanager")
    if err != nil {
        return "", fmt.Errorf("failed to create temp directory: %v", err)
    }
    defer os.RemoveAll(tempDir)

    // Get the download URL for the Session Manager Plugin
    zipURL, err := getSessionManagerPluginURL()
    if err != nil {
        return "", fmt.Errorf("failed to get session manager plugin URL: %v", err)
    }
    zipFilePath := filepath.Join(tempDir, "sessionmanager-bundle.zip")

    // Download the zip file
    out, err := os.Create(zipFilePath)
    if err != nil {
        return "", fmt.Errorf("failed to create zip file: %v", err)
    }
    defer out.Close()

    resp, err := http.Get(zipURL)
    if err != nil {
        return "", fmt.Errorf("failed to download the session manager bundle: %v", err)
    }
    defer resp.Body.Close()

    if resp.StatusCode != http.StatusOK {
        return "", fmt.Errorf("failed to download the session manager bundle: %v", resp.Status)
    }

    if _, err = io.Copy(out, resp.Body); err != nil {
        return "", fmt.Errorf("failed to save the session manager bundle: %v", err)
    }

    // Unzip the downloaded file
    if err := unzip(zipFilePath, tempDir); err != nil {
        return "", fmt.Errorf("failed to unzip the session manager bundle: %v", err)
    }

    // Make the install script executable
    installScriptPath := filepath.Join(tempDir, "sessionmanager-bundle", "install")
    if err := os.Chmod(installScriptPath, 0755); err != nil {
        return "", fmt.Errorf("failed to make install script executable: %v", err)
    }

    password, err := GetSudoPassword(window)
    if err != nil {
        return "", err
    }

    askPassScript, err := createAskPassScript(password)
    if err != nil {
        return "", err
    }
    defer os.Remove(askPassScript)

    cmd := exec.Command("bash", installScriptPath, "-i", "/usr/local/sessionmanagerplugin", "-b", "/usr/local/bin/session-manager-plugin")
    cmd.Env = append(os.Environ(), fmt.Sprintf("SUDO_ASKPASS=%s", askPassScript))
    cmd.Stdout = os.Stdout
    cmd.Stderr = os.Stderr

    if err := cmd.Run(); err != nil {
        return "", fmt.Errorf("failed to install the session manager plugin: %v", err)
    }

    // Verify the installation
    cmd = exec.Command("session-manager-plugin", "--version")
    cmdOutput, err := cmd.CombinedOutput()
    if err != nil {
        appendText(ui, string(cmdOutput))
        return "", fmt.Errorf("failed to verify the session manager plugin installation: %v", err)
    }

    appendText(ui, string(cmdOutput))
    appendText(ui, "Session Manager Plugin installed successfully.")
    return "AWS configuration done. Please note you will still need to add MFA to your config.", nil
}

func getSessionManagerPluginURL() (string, error) {
	baseURL := "https://s3.amazonaws.com/session-manager-downloads/plugin/latest"
	var url string

	switch runtime.GOOS {
	case "darwin":
		switch runtime.GOARCH {
		case "amd64":
			url = fmt.Sprintf("%s/%s/sessionmanager-bundle.zip", baseURL, "mac_os")
		case "arm64":
			url = fmt.Sprintf("%s/%s/sessionmanager-bundle.zip", baseURL, "mac_arm64")
		default:
			return "", fmt.Errorf("unsupported architecture: %s", runtime.GOARCH)
		}
	case "linux":
		switch runtime.GOARCH {
		case "amd64":
			url = fmt.Sprintf("%s/%s_%s/sessionmanager-bundle.zip", baseURL, "linux", "64bit")
		case "arm64":
			url = fmt.Sprintf("%s/%s_%s/sessionmanager-bundle.zip", baseURL, "linux", "arm64")
		default:
			return "", fmt.Errorf("unsupported architecture: %s", runtime.GOARCH)
		}
	case "windows":
		switch runtime.GOARCH {
		case "amd64":
			url = fmt.Sprintf("%s/%s_%s/sessionmanager-bundle.zip", baseURL, "windows", "64bit")
		default:
			return "", fmt.Errorf("unsupported architecture: %s", runtime.GOARCH)
		}
	default:
		return "", fmt.Errorf("unsupported OS: %s", runtime.GOOS)
	}

	return url, nil
}

func isSessionManagerPluginInstalled() bool {
    cmd := exec.Command("session-manager-plugin", "--version")
    if err := cmd.Run(); err != nil {
        return false
    }
    return true
}
