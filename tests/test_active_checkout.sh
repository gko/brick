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

setup_remote_with_branch() {
    local brick_name=$1
    local branch_name=$2
    local path="$REMOTE_DIR/$brick_name"
    mkdir -p "$path"
    cd "$path"
    git init -q
    git checkout -b "$branch_name" -q
    echo "initial content" > hello.txt
    git add hello.txt
    git commit -m "Initial commit" -q
    cd - > /dev/null
}

setup_main() {
    mkdir -p "$MAIN_DIR"
    cd "$MAIN_DIR"
    git init -q
    git commit --allow-empty -m "Init main repo" -q
    cd - > /dev/null
}

echo "🚀 Testing Active Checkout (Detached HEAD prevention)..."

# Setup
setup_remote_with_branch "brick_feat" "feature-x"
setup_main

PROJECT_ROOT=$(pwd)
source "$PROJECT_ROOT/brick.sh"
cd "$MAIN_DIR"

# 1. Install brick
brick install "$REMOTE_DIR/brick_feat"
# Manually set the tracked branch in .gitmodules to simulate a real setup
git config -f .gitmodules submodule.brick_feat.branch "feature-x"

# 2. Trigger Update
# This should normally leave us in detached HEAD, but brick now does an active checkout
brick update "brick_feat" -y

# 3. Verify Branch State
CURRENT_BRANCH=$(git -C "brick_feat" branch --show-current)
assert_eq "$CURRENT_BRANCH" "feature-x"

# 4. Verify it is NOT detached
# 'git symbolic-ref -q HEAD' returns the branch name if not detached, otherwise empty
IS_DETACHED=$(git -C "brick_feat" symbolic-ref -q HEAD || echo "DETACHED")
if [ "$IS_DETACHED" == "DETACHED" ]; then
    echo -e "${RED}FAIL: Submodule is still in detached HEAD state${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Active Checkout passed: Submodule is on 'feature-x' branch${NC}"

cd "$PROJECT_ROOT"
rm -rf "$TEST_DIR"
echo -e "\n${GREEN}✨ ACTIVE CHECKOUT VERIFIED!${NC}"