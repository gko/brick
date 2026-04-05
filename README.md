# brick — A Git Submodule Package Manager

![tests](https://github.com/gko/brick/actions/workflows/test.yml/badge.svg)

`brick` is a frictionless wrapper for Git Submodules. It simplifies the process of adding, updating, and removing submodules, treating them as "bricks" that you can easily plug into your project.

## Features

* **Simple Installation**: Add new submodules (bricks) using a simple shorthand.
* **Global Init**: Install all missing bricks defined in `.gitmodules` with a single command.
* **Smart Updates**: Update specific bricks or all of them to their latest tracking commits.
* **Branch Tracking**: Automatically keeps bricks on their tracked branches after updates, avoiding detached HEAD states.
* **Safe Removal**: Cleanly purge a brick from the repository, including its internal git metadata.
* **Quick Overview**: List all installed bricks, their current branches, and remote URLs in a clean table.
* **Automation Friendly**: Use the `-y` or `--yes` flag to skip confirmation prompts for dirty checks and deletions.

## Installation

### Manual

1. Clone this repository or download the `brick.sh` script.
```shell
git clone https://github.com/gko/brick.git
```

2. Source the `brick.sh` script in your shell's configuration file (e.g., `~/.bashrc`, `~/.zshrc`). Add the following line:
```shell
# Make sure to use the correct path to where you cloned the repo
source /path/to/brick/brick.sh
```

3. Restart your shell or source the configuration file for the changes to take effect:
```shell
source ~/.zshrc
```
or
```shell
source ~/.bashrc
```

### With [zinit](https://github.com/zdharma-continuum/zinit)

In your `.zshrc`:
```shell
zinit light gko/brick
```

### With [antigen](https://github.com/zsh-users/antigen)

In your `.zshrc`:
```shell
antigen bundle gko/brick
```

## Usage

```
Usage: brick [command] [target] [branch] [flags]

Commands:
  install, i, add     Install a brick (run empty to init all missing)
  update, up, upgrade Update a brick (run empty to update all)
  delete, rm, remove  Safely purge a brick from the repository
  list, ls            List all installed bricks

Flags:
  -y, --yes           Skip confirmation prompts (dirty checks/deletions)

Example:
  brick install gko/postfix           # Install a brick from GitHub
  brick install                      # Install all missing bricks
  brick update -y                    # Update all bricks without prompts
  brick update my-brick main         # Update 'my-brick' to the 'main' branch
  brick rm ghost-theme               # Remove the 'ghost-theme' brick
  brick ls                          # List all installed bricks
```

## License

This project is open source and available under the [GPLv3](/LICENSE) license.
