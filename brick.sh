# The Brick Package Manager
# A frictionless wrapper for Git Submodules

brick() {
    # Find the root of the current git repository
    local repo_root
    repo_root=$(git -C "${PWD}" rev-parse --show-toplevel 2>/dev/null)

    if [ -z "$repo_root" ]; then
        echo "❌ Error: You must be inside a Git repository to use bricks."
        return 1
    fi

    # Parse arguments for -y / --yes flag
    local skip_prompt=false
    local args=()
    for arg in "$@"; do
        if [[ "$arg" == "-y" || "$arg" == "--yes" ]]; then
            skip_prompt=true
        else
            args+=("$arg")
        fi
    done

    local action=${args[0]}
    local target=${args[1]}
    local branch=${args[2]}

    case $action in
        # ==========================================
        # ALIASES: install, i, add
        # ==========================================
        install|i|add)
            # GLOBAL INSTALL: No target provided
            if [ -z "$target" ]; then
                if [ ! -f "$repo_root/.gitmodules" ]; then
                    echo "📦 No bricks to install (missing .gitmodules)."
                    return 0
                fi
                echo "📦 Installing all missing bricks..."
                git -C "$repo_root" submodule update --init --recursive
                echo "✅ All bricks installed."
                return 0
            fi

            # SPECIFIC INSTALL
            local repo_url
            if [[ "$target" =~ ^https?:// ]] || [[ "$target" =~ ^git@ ]] || [[ "$target" =~ ^/ ]] || [[ "$target" =~ ^\.\/ ]]; then
                repo_url="$target"
            else
                repo_url="https://github.com/$target.git"
            fi

            local folder=$(basename "$target" .git)
            local abs_folder="$repo_root/$folder"

            if [ -d "$abs_folder" ]; then
                echo "💡 Brick '$folder' is already installed."
                if [ -n "$branch" ]; then
                    echo "   Redirecting to switch branch to '$branch'..."
                    brick update "$folder" "$branch" $skip_prompt_flag
                else
                    echo "   Redirecting to update..."
                    brick update "$folder" $skip_prompt_flag
                fi
                return 0
            fi

            if [ -n "$branch" ]; then
                echo "📦 Installing brick into $folder (Branch: $branch)..."
                git -C "$repo_root" submodule add -b "$branch" "$repo_url" "$folder"
            else
                echo "📦 Installing brick into $folder..."
                git -C "$repo_root" submodule add "$repo_url" "$folder"
            fi
            ;;

        # ==========================================
        # ALIASES: update, up, upgrade
        # ==========================================
        update|up|upgrade)
            # GLOBAL UPDATE: No target provided
            if [ -z "$target" ]; then
                if [ ! -f "$repo_root/.gitmodules" ]; then
                    echo "📦 No bricks to update."
                    return 0
                fi

                if [ "$skip_prompt" = false ]; then
                    # Check if ANY submodule is dirty
                    local dirty_modules=$(git -C "$repo_root" submodule foreach --quiet 'git status --porcelain' | wc -l)
                    if [ "$dirty_modules" -gt 0 ]; then
                        echo "⚠️  WARNING: One or more bricks have uncommitted local changes!"
                        read -p "Proceeding will OVERWRITE local tweaks. Force update all? (y/N): " confirm
                        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                            echo "❌ Global update aborted."
                            return 1
                        fi
                    fi
                fi

                echo "🔄 Updating all bricks to their latest tracking commits..."
                git -C "$repo_root" submodule update --init --recursive --remote --force
                git -C "$repo_root" add .gitmodules
                echo "✅ All bricks updated."
                return 0
            fi

            # SPECIFIC UPDATE
            local folder=$(basename "$target" .git)
            local abs_folder="$repo_root/$folder"

            if [ -d "$abs_folder" ]; then
                if [ "$skip_prompt" = false ]; then
                    local is_dirty=$(git -C "$abs_folder" status --porcelain)
                    if [ -n "$is_dirty" ]; then
                        echo "⚠️  WARNING: The brick '$folder' has uncommitted local changes!"
                        echo "$is_dirty"
                        read -p "Force update anyway? (y/N): " confirm
                        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                            echo "❌ Update aborted."
                            return 1
                        fi
                    fi
                fi
            else
                echo "❌ Error: Brick '$folder' does not exist."
                return 1
            fi

            if [ -n "$branch" ]; then
                echo "🔄 Switching '$folder' to branch '$branch'..."
                git -C "$repo_root" config -f .gitmodules submodule."$folder".branch "$branch"
            else
                echo "🔄 Updating brick: $folder..."
            fi

            git -C "$repo_root" submodule update --init --recursive --remote --force "$folder"
            git -C "$repo_root" add "$folder" .gitmodules
            echo "✅ $folder updated."
            ;;

        # ==========================================
        # ALIASES: delete, rm, remove, uninstall
        # ==========================================
        delete|rm|remove|uninstall)
            if [ -z "$target" ]; then
                echo "❌ Error: Please specify a brick to remove."
                return 1
            fi

            local folder=$(basename "$target" .git)
            local abs_folder="$repo_root/$folder"

            if [ ! -d "$abs_folder" ]; then
                echo "❌ Error: Brick '$folder' is not installed."
                return 1
            fi

            if [ "$skip_prompt" = false ]; then
                read -p "⚠️  Are you sure you want to permanently delete the brick '$folder'? (y/N): " confirm
                if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                    echo "❌ Deletion aborted."
                    return 1
                fi
            fi

            echo "🗑️  Purging brick: $folder..."

            # The complex but completely clean way to delete a git submodule
            git -C "$repo_root" submodule deinit -f -- "$folder" >/dev/null 2>&1
            rm -rf "$repo_root/.git/modules/$folder"
            git -C "$repo_root" rm -f "$folder" >/dev/null 2>&1

            echo "✅ Brick '$folder' cleanly removed."
            ;;

        # ==========================================
        # ALIASES: list, ls
        # ==========================================
        list|ls)
            if [ ! -f "$repo_root/.gitmodules" ]; then
                echo "📦 No bricks installed."
                return 0
            fi

            echo "📦 Installed Bricks:"
            echo "---------------------------------------------------------------------------------"
            printf "%-20s %-15s %-45s\n" "FOLDER" "BRANCH" "REMOTE URL"
            printf "%-20s %-15s %-45s\n" "------" "------" "----------"

            local submodules=$(git -C "$repo_root" config --file .gitmodules --get-regexp path | awk '{ print $1 }' | sed 's/submodule\.//' | sed 's/\.path//')

            if [ -z "$submodules" ]; then
                 echo "No bricks found."
            else
                for sub in $submodules; do
                    local path=$(git -C "$repo_root" config --file .gitmodules --get "submodule.$sub.path")
                    local url=$(git -C "$repo_root" config --file .gitmodules --get "submodule.$sub.url")
                    local sub_branch=$(git -C "$repo_root" config --file .gitmodules --get "submodule.$sub.branch")

                    if [ -z "$sub_branch" ]; then sub_branch="(default)"; fi
                    printf "%-20s %-15s %-45s\n" "$path" "$sub_branch" "$url"
                done
            fi
            echo "---------------------------------------------------------------------------------"
            ;;

        *)
            echo "Brick - The Git Submodule Package Manager"
            echo ""
            echo "Commands:"
            echo "  install, i, add     Install a brick (run empty to init all missing)"
            echo "  update, up, upgrade Update a brick (run empty to update all)"
            echo "  delete, rm, remove  Safely purge a brick from the repository"
            echo "  list, ls            List all installed bricks"
            echo ""
            echo "Flags:"
            echo "  -y, --yes           Skip confirmation prompts (dirty checks/deletions)"
            echo ""
            echo "Usage Examples:"
            echo "  brick install gko/postfix"
            echo "  brick update -y"
            echo "  brick rm ghost-theme"
            ;;
    esac
}
