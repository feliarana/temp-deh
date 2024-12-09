# DevOpsTools for PetScreening

Welcome to the **DevOpsTools** repository! This project provides a set of handy scripts designed to streamline various DevOps tasks at PetScreening.

## Getting Started

To start using these tools, you need to run the installation script, which will add the utilities to your command line path.

### Installation

1. Clone this repository to your local machine.
2. In the root of the project, run the following command to install:

```bash
./install
```

This script will automatically update your PATH to include the directories and scripts contained in this repository. After running the install script, you'll be able to run any of these scripts from the command line.

## Available Scripts

Got it! Here's an updated README section for the **aws_temp_session** script with that information:

---

### AWS Session Management

- **aws_temp_login**: This script creates a temporary session for AWS, but it requires the following prerequisites:

  1. **1Password Setup**:  
     Your AWS access token credentials must be securely stored in 1Password. Follow [this guide on 1Password](https://developer.1password.com/docs/cli/shell-plugins/aws#optional-set-up-multi-factor-authentication) to add your credentials using the 1Password command-line tool. You can download the tool [here](https://1password.com/downloads/command-line/).

     Make sure the credentials are stored in 1Password in the exact format required.

  2. **MFA Code**:  
     You will need an MFA code to authenticate your AWS session. Make sure you have the MFA device ARN associated with your AWS account ready.

  Example usage:

  ```bash
  . aws_temp_login
  ```

  The script will display a 1Password popup asking for your 1Password credentials.

---

### SSM Parameter Utilities

- **ssm_search**: Use this to search for SSM parameters by keyword or pattern.

  Example:

  ```bash
  ssm_search <environment-name> <parameter-name>
  ```
  - Use <parameter-name> = "ALL" to get all parameters for that environment.

- **ssm_set**: This allows you to set new or update existing SSM parameters.

  Example:

  ```bash
  ssm_set <environment-name> <parameter-name>
  ```

  The script will prompt you for the new value and if there is an existing value it will ask you if you want to overwrite it.

### Role Assumption

- **non-prod**: This script allows you to assume the non-production role within AWS, making it easier to access non-prod environments.

  Example:

  ```bash
  . non-prod
  ```

- **Alternative via config file**: The following is a template to
    replace with your actual use case to allow aws-vault to use this role.
    ```bash
    $ cat ~/.aws/config
    [profile existing-profile]
    ...
    [profile nonprod]
    source_profile = existing-profile
    role_arn = arn:aws:iam::163388034490:role/NonProdRole 
    
    $ aws-vault exec nonprod
    ```

### Database Utilities

Within the `dbutils` directory, you will find scripts to create tunnels through a Bastion server into RDS databases.

- **DB Tunnels**: Each script in this directory is specific to a database. It establishes an SSM session and tunnels through the Bastion server.

  Example:

  ```bash
  tunnel_<environment>
  ```

### Setup Utilities
- **Usage**:
  1. Download: [application url](https://github.com/PetScreeningInc/devops-tools/releases/download/v0.0.1/ps-cmdr.app.zip) 
  2. Open a terminal and run:
     ```bash
     xattr -cr $HOME/Downloads/ps-cmdr.app
     ```
  3. Run app -> click install tools -> provide password if prompted

- **Building**:
  ```bash
   go build -o <name-of-binary> .
   ```

- **Packaging**:
  ```bash
   ~/go/bin/fyne package -os darwin -icon Icon.png --release
   ```

## Contributing

If you have improvements or new features to add to these scripts, feel free to open a pull request or suggest changes.
