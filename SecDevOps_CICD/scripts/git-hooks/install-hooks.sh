#!/bin/bash

# Git hooks installation script for SecDevOps CI/CD Pipeline
# This script installs the custom git hooks into the repository

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_message "$BLUE" "=================================="
print_message "$BLUE" "Git Hooks Installation Script"
print_message "$BLUE" "=================================="
echo ""

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Get the git repository root
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)

if [ -z "$GIT_ROOT" ]; then
    print_message "$RED" "✗ Error: Not in a git repository"
    exit 1
fi

# Git hooks directory
GIT_HOOKS_DIR="$GIT_ROOT/.git/hooks"

# Custom hooks to install
HOOKS=(
    "pre-commit"
    "commit-msg"
    "pre-push"
)

print_message "$YELLOW" "Git repository root: $GIT_ROOT"
print_message "$YELLOW" "Installing hooks to: $GIT_HOOKS_DIR"
echo ""

# Create hooks directory if it doesn't exist
if [ ! -d "$GIT_HOOKS_DIR" ]; then
    mkdir -p "$GIT_HOOKS_DIR"
    print_message "$GREEN" "✓ Created hooks directory"
fi

# Function to backup existing hooks
backup_existing_hook() {
    local hook_name=$1
    local hook_path="$GIT_HOOKS_DIR/$hook_name"
    
    if [ -f "$hook_path" ] && [ ! -L "$hook_path" ]; then
        local backup_path="${hook_path}.backup.$(date +%Y%m%d_%H%M%S)"
        mv "$hook_path" "$backup_path"
        print_message "$YELLOW" "  ↳ Backed up existing $hook_name to $(basename "$backup_path")"
        return 0
    fi
    return 1
}

# Function to install a hook
install_hook() {
    local hook_name=$1
    local source_path="$SCRIPT_DIR/$hook_name"
    local dest_path="$GIT_HOOKS_DIR/$hook_name"
    
    print_message "$YELLOW" "→ Installing $hook_name hook..."
    
    # Check if source hook exists
    if [ ! -f "$source_path" ]; then
        print_message "$RED" "  ✗ Source hook not found: $source_path"
        return 1
    fi
    
    # Backup existing hook if needed
    backup_existing_hook "$hook_name"
    
    # Remove existing symlink if present
    if [ -L "$dest_path" ]; then
        rm "$dest_path"
    fi
    
    # Create symlink to the hook
    ln -sf "$source_path" "$dest_path"
    
    # Make sure the hook is executable
    chmod +x "$source_path"
    chmod +x "$dest_path"
    
    print_message "$GREEN" "  ✓ $hook_name hook installed successfully"
    
    return 0
}

# Install each hook
INSTALLED=0
FAILED=0

for hook in "${HOOKS[@]}"; do
    if install_hook "$hook"; then
        INSTALLED=$((INSTALLED + 1))
    else
        FAILED=$((FAILED + 1))
    fi
done

echo ""

# Install pre-commit framework hooks if available
if command -v pre-commit &> /dev/null; then
    print_message "$YELLOW" "→ Installing pre-commit framework hooks..."
    
    if [ -f "$GIT_ROOT/.pre-commit-config.yaml" ]; then
        cd "$GIT_ROOT"
        
        # Install pre-commit hooks
        if pre-commit install > /dev/null 2>&1; then
            print_message "$GREEN" "  ✓ pre-commit framework hooks installed"
        else
            print_message "$YELLOW" "  ⚠ pre-commit framework already installed"
        fi
        
        # Install commit-msg hook for pre-commit
        if pre-commit install --hook-type commit-msg > /dev/null 2>&1; then
            print_message "$GREEN" "  ✓ pre-commit commit-msg hook installed"
        else
            print_message "$YELLOW" "  ⚠ pre-commit commit-msg hook already installed"
        fi
        
        # Install pre-push hook for pre-commit
        if pre-commit install --hook-type pre-push > /dev/null 2>&1; then
            print_message "$GREEN" "  ✓ pre-commit pre-push hook installed"
        else
            print_message "$YELLOW" "  ⚠ pre-commit pre-push hook already installed"
        fi
    else
        print_message "$YELLOW" "  ⚠ .pre-commit-config.yaml not found"
    fi
else
    print_message "$YELLOW" "ℹ pre-commit framework not installed"
    print_message "$YELLOW" "  Install with: pip install pre-commit"
fi

echo ""

# Verify installation
print_message "$YELLOW" "→ Verifying installation..."

VERIFIED=0
for hook in "${HOOKS[@]}"; do
    hook_path="$GIT_HOOKS_DIR/$hook"
    if [ -f "$hook_path" ] || [ -L "$hook_path" ]; then
        if [ -x "$hook_path" ]; then
            print_message "$GREEN" "  ✓ $hook is installed and executable"
            VERIFIED=$((VERIFIED + 1))
        else
            print_message "$RED" "  ✗ $hook is installed but not executable"
        fi
    else
        print_message "$RED" "  ✗ $hook is not installed"
    fi
done

echo ""

# Show usage information
print_message "$BLUE" "=================================="
print_message "$BLUE" "Installation Summary"
print_message "$BLUE" "=================================="

print_message "$GREEN" "✓ Installed: $INSTALLED hooks"
if [ $FAILED -gt 0 ]; then
    print_message "$RED" "✗ Failed: $FAILED hooks"
fi
print_message "$GREEN" "✓ Verified: $VERIFIED hooks"

echo ""
print_message "$BLUE" "Hook Descriptions:"
print_message "$YELLOW" "  • pre-commit:  Runs before each commit"
print_message "$YELLOW" "    - Checks for secrets and credentials"
print_message "$YELLOW" "    - Validates code formatting and linting"
print_message "$YELLOW" "    - Checks for large files"
print_message "$YELLOW" "    - Validates YAML/JSON syntax"

print_message "$YELLOW" "  • commit-msg:  Validates commit messages"
print_message "$YELLOW" "    - Enforces conventional commits format"
print_message "$YELLOW" "    - Checks message length"
print_message "$YELLOW" "    - Validates commit type"

print_message "$YELLOW" "  • pre-push:    Runs before pushing"
print_message "$YELLOW" "    - Prevents force push to protected branches"
print_message "$YELLOW" "    - Scans for secrets in commits"
print_message "$YELLOW" "    - Runs unit tests"
print_message "$YELLOW" "    - Validates Terraform files"

echo ""
print_message "$BLUE" "Usage:"
print_message "$YELLOW" "  To temporarily skip hooks, use:"
print_message "$YELLOW" "    git commit --no-verify"
print_message "$YELLOW" "    git push --no-verify"

print_message "$YELLOW" "  To uninstall hooks, run:"
print_message "$YELLOW" "    $0 --uninstall"

echo ""

# Handle uninstall option
if [ "$1" == "--uninstall" ]; then
    print_message "$RED" "=================================="
    print_message "$RED" "Uninstalling Git Hooks"
    print_message "$RED" "=================================="
    
    for hook in "${HOOKS[@]}"; do
        hook_path="$GIT_HOOKS_DIR/$hook"
        if [ -L "$hook_path" ]; then
            rm "$hook_path"
            print_message "$GREEN" "✓ Removed $hook"
        fi
        
        # Restore backup if exists
        backup=$(ls -t "${hook_path}.backup."* 2>/dev/null | head -n1)
        if [ -n "$backup" ]; then
            mv "$backup" "$hook_path"
            print_message "$YELLOW" "↳ Restored original $hook from backup"
        fi
    done
    
    # Uninstall pre-commit framework hooks
    if command -v pre-commit &> /dev/null; then
        cd "$GIT_ROOT"
        pre-commit uninstall > /dev/null 2>&1
        pre-commit uninstall --hook-type commit-msg > /dev/null 2>&1
        pre-commit uninstall --hook-type pre-push > /dev/null 2>&1
        print_message "$GREEN" "✓ Uninstalled pre-commit framework hooks"
    fi
    
    print_message "$GREEN" "✓ Hooks uninstalled successfully"
    exit 0
fi

# Success message
if [ $FAILED -eq 0 ]; then
    print_message "$GREEN" "=================================="
    print_message "$GREEN" "✓ Installation completed successfully!"
    print_message "$GREEN" "=================================="
    exit 0
else
    print_message "$RED" "=================================="
    print_message "$RED" "✗ Installation completed with errors"
    print_message "$RED" "=================================="
    exit 1
fi