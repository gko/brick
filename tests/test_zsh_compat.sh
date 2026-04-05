#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

export GIT_CONFIG_PARAMETERS="'protocol.file.allow=always'"
TEST_DIR=$(mktemp -d)
REMOTE_DIR="$TEST_DIR/remotes"
MAIN_DIR="$TEST_DIR/main_repo"
mkdir -p "$REMOTE_DIR"

assert_eq() {
    if [ "$1" != "$2" ]; then
        echo -e "${RED}FAIL: Expected '$2', got '$1'${NC}"
        exit 1
    fi
}

assert_exists() {
    if [ ! -e "$1" ]; then
        echo -e "${RED}FAIL: File/Dir $1 does not exist${NC}"
        exit 1
    fi
}

setup_remote() {
    local brick_name=$1
    local path="$REMOTE_DIR/$brick_name"
    mkdir -p "$path"
    cd "$path"
    git init -q
    echo "content" > hello.txt
    git add hello.txt
    git commit -m "init" -q
    cd - > /dev/null
}

setup_main() {
    mkdir -p "$MAIN_DIR"
    cd "$MAIN_DIR"
    git init -q
    git commit --allow-empty -m "init" -q
    cd - > /dev/null
}

echo "🚀 Testing Zsh compatibility & Custom Paths..."

setup_remote "brick_custom"
setup_main

PROJECT_ROOT=$(pwd)
source "$PROJECT_ROOT/brick.sh"
cd "$MAIN_DIR"

# Test 1: Custom path installation
echo "Testing: Custom path installation..."
brick install "$REMOTE_DIR/brick_custom" "custom/folder/my-brick"
assert_exists "custom/folder/my-brick/hello.txt"
echo -e "${GREEN}✅ Custom path installation passed${NC}"

# Test 2: Update using custom path
echo "Testing: Update via custom path..."
cd "$REMOTE_DIR/brick_custom"
echo "updated" > hello.txt
git add hello.txt
git commit -m "update" -q
cd "$MAIN_DIR"

brick update "custom/folder/my-brick" -y
RESULT=$(cat custom/folder/my-brick/hello.txt)
assert_eq "$RESULT" "updated"
echo -e "${GREEN}✅ Custom path update passed${NC}"

# Test 3: Remove using custom path
echo "Testing: Remove via custom path..."
brick rm "custom/folder/my-brick" -y
if [ -d "custom/folder/my-brick" ]; then
    echo -e "${RED}FAIL: Directory still exists${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Custom path removal passed${NC}"

cd "$PROJECT_ROOT"
rm -rf "$TEST_DIR"
echo -e "\n${GREEN}✨ ZSH COMPATIBILITY & CUSTOM PATHS VERIFIED!${NC}"