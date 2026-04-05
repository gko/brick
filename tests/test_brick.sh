#!/bin/bash

# Setup colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Initialize test environment
export GIT_CONFIG_PARAMETERS="'protocol.file.allow=always'"
TEST_DIR=$(mktemp -d)
REMOTE_DIR="$TEST_DIR/remotes"
MAIN_DIR="$TEST_DIR/main_repo"
mkdir -p "$REMOTE_DIR"

# Helper to assert equality
assert_eq() {
    if [ "$1" != "$2" ]; then
        echo -e "${RED}FAIL: Expected '$2', got '$1'${NC}"
        exit 1
    fi
}

# Helper to assert file exists
assert_exists() {
    if [ ! -e "$1" ]; then
        echo -e "${RED}FAIL: File/Dir $1 does not exist${NC}"
        exit 1
    fi
}

# Setup: Create remote bricks
setup_remotes() {
    local brick_name=$1
    local path="$REMOTE_DIR/$brick_name"
    mkdir -p "$path"
    cd "$path"
    git init -q
    echo "content from $brick_name" > hello.txt
    git add hello.txt
    git commit -m "Initial commit" -q
    cd - > /dev/null
}

# Setup: Create main repo
setup_main() {
    mkdir -p "$MAIN_DIR"
    cd "$MAIN_DIR"
    git init -q
    git commit --allow-empty -m "Init main repo" -q
    cd - > /dev/null
}

# --- Execution ---

echo "🚀 Starting brick integration tests..."

# 1. Setup Environment
setup_remotes "brick1"
setup_remotes "brick2"
setup_main

# Source brick.sh (assuming it's in the root of the project)
# We use the absolute path to the project root
PROJECT_ROOT=$(pwd)
source "$PROJECT_ROOT/brick.sh"

# Change to the main repo for the rest of the tests
cd "$MAIN_DIR"

# --- Test Case 1: Install ---
echo "Testing: brick install..."
brick install "$REMOTE_DIR/brick1"
assert_exists "brick1/hello.txt"
assert_exists ".gitmodules"
grep -q "brick1" .gitmodules || { echo -e "${RED}FAIL: brick1 not in .gitmodules${NC}"; exit 1; }
echo -e "${GREEN}✅ Install passed${NC}"

# --- Test Case 2: Update ---
echo "Testing: brick update..."
# Change the remote brick
cd "$REMOTE_DIR/brick1"
echo "updated content" > hello.txt
git add hello.txt
git commit -m "Update content" -q
cd "$MAIN_DIR"

# Update the brick
brick update "brick1" -y
RESULT=$(cat brick1/hello.txt)
assert_eq "$RESULT" "updated content"
echo -e "${GREEN}✅ Update passed${NC}"

# --- Test Case 3: List ---
echo "Testing: brick ls..."
brick install "$REMOTE_DIR/brick2"
LIST_OUT=$(brick ls)
echo "$LIST_OUT" | grep -q "brick1" || { echo -e "${RED}FAIL: brick1 missing from list${NC}"; exit 1; }
echo "$LIST_OUT" | grep -q "brick2" || { echo -e "${RED}FAIL: brick2 missing from list${NC}"; exit 1; }
echo -e "${GREEN}✅ List passed${NC}"

# --- Test Case 4: Remove ---
echo "Testing: brick rm..."
brick rm "brick1" -y
if [ -d "brick1" ]; then
    echo -e "${RED}FAIL: brick1 directory still exists${NC}"
    exit 1
fi
# Check if it's gone from .gitmodules
grep -q "brick1" .gitmodules && { echo -e "${RED}FAIL: brick1 still in .gitmodules${NC}"; exit 1; }
echo -e "${GREEN}✅ Remove passed${NC}"

# Cleanup
cd "$PROJECT_ROOT"
rm -rf "$TEST_DIR"

echo -e "\n${GREEN}✨ ALL CRITICAL TESTS PASSED!${NC}"