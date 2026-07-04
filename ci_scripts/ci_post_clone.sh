#!/bin/sh

# Fail the post-clone step immediately if any command fails. Without this,
# a failed `tuist generate` is swallowed and the build dies later with the
# misleading "A scheme called MusicX does not exist" error.
set -e

# Mise installation taken from https://mise.jdx.dev/continuous-integration.html#xcode-cloud
curl https://mise.run | sh # Install Mise
export PATH="$HOME/.local/bin:$PATH"

mise install # Installs the version from .mise.toml

# Runs the version of Tuist indicated in the .mise.toml file {#runs-the-version-of-tuist-indicated-in-the-misetoml-file}
mise exec -- tuist install --path ../ # `--path` needed as this is run from within the `ci_scripts` directory
mise exec -- tuist generate -p ../ --no-open # `-p` needed as this is run from within the `ci_scripts` directory

# Disable macro validation
defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES
