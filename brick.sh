# The Brick Package Manager
# A frictionless wrapper for Git Submodules

brick() {
    # Parse arguments and flags
    local skip_prompt=false
    local target_branch=""
    local args=()

    while [[ $# -gt 0 ]]; do
        case $1 in
            -y|--yes)
                skip_prompt=true
                shift
                ;;
            -b|--branch)
                target_branch="$2"
                shift 2
                ;;
            -h|--help)
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
                echo "  -b, --branch        Specify a target branch (e.g., -b dev)"
                echo "  -h, --help          Show this help menu"
                echo ""
                echo "Usage Examples:"
                echo "  brick install gko/postfix"
                echo "  brick install zametka/tunnel services/tunnel"
                echo "  brick install gko/postfix -b v2.0"
                echo "  brick update services/tunnel"
                echo "  brick rm ghost-theme -y"
                return 0
                ;;
            *)
                args+=("$1")
                shift
                ;;
        esac
    done

    # --- SHELL COMPATIBILITY FIX ---
    set -- "${args[@]}"
    local action=$1
    local target=$2
    local dest_path=$3

    if [ -z "$action" ]; then
        brick -h
        return 0
    fi

    if [[ "$action" =~ ^(install|i|add|update|up|upgrade|delete|rm|remove|uninstall|list|ls)$ ]]; then
        local repo_root
        repo_root=$(git -C "${PWD}" rev-parse --show-toplevel 2>/dev/null)
        if [ -z "$repo_root" ]; then
            echo "❌ Error: You must be inside a Git repository to use bricks."
            return 1
        fi
    else
        brick -h
        return 0
    fi

    local repo_root
    repo_root=$(git -C "${PWD}" rev-parse --show-toplevel 2>/dev/null)

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
                echo "📦 Synchronizing bricks..."
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

            # --- CUSTOM PATH FIX ---
            local folder
            if [ -n "$dest_path" ]; then
                folder="${dest_path%/}" # Use custom path, strip trailing slash
            else
                folder=$(basename "$target" .git) # Fallback to default name
            fi
            local abs_folder="$repo_root/$folder"

            local pass_y=""
            if [ "$skip_prompt" = true ]; then pass_y="-y"; fi

            if [ -d "$abs_folder" ]; then
                echo "💡 Brick '$folder' is already installed."
                if [ -n "$target_branch" ]; then
                    echo "   Redirecting to switch branch to '$target_branch'..."
                    brick $pass_y update "$folder" -b "$target_branch"
                else
                    echo "   Redirecting to update..."
                    brick $pass_y update "$folder"
                fi
                return 0
            fi

            if [ -n "$target_branch" ]; then
                echo "📦 Installing brick into $folder (Branch: $target_branch)..."
                git -C "$repo_root" submodule add -b "$target_branch" "$repo_url" "$folder"
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
                        printf "Proceeding will OVERWRITE local tweaks. Force update all? (y/N): "
                        read -r confirm
                        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                            echo "❌ Global update aborted."
                            return 1
                        fi
                    fi
                fi

                echo "🔄 Updating all bricks to their latest tracking commits..."
                git -C "$repo_root" submodule update --init --recursive --remote --force

                # ACTIVE CHECKOUT: Ensure all submodules are on their tracked branches
                local submodules=$(git -C "$repo_root" config --file .gitmodules --get-regexp path | awk '{ print $1 }' | sed 's/submodule\.//' | sed 's/\.path//')
                for sub in $submodules; do
                    local checkout_branch=$(git -C "$repo_root" config --file .gitmodules --get "submodule.$sub.branch")

                    if [ -z "$checkout_branch" ]; then
                        checkout_branch=$(git -C "$repo_root/$sub" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
                        if [ -z "$checkout_branch" ]; then
                            if git -C "$repo_root/$sub" show-ref --verify --quiet refs/heads/main; then
                                checkout_branch="main"
                            else
                                checkout_branch="master"
                            fi
                        fi
                    fi
                    git -C "$repo_root/$sub" checkout -B "$checkout_branch" "origin/$checkout_branch" >/dev/null 2>&1
                done

                git -C "$repo_root" add .gitmodules
                echo "✅ All bricks updated."
                return 0
            fi

            # SPECIFIC UPDATE
            # --- CUSTOM PATH FIX ---
            # If the user typed the exact folder path (e.g., services/tunnel), use it.
            local folder
            if [ -d "$repo_root/${target%/}" ]; then
                folder="${target%/}"
            else
                folder=$(basename "$target" .git)
            fi

            local abs_folder="$repo_root/$folder"

            if [ -d "$abs_folder" ]; then
                if [ "$skip_prompt" = false ]; then
                    local is_dirty=$(git -C "$abs_folder" status --porcelain)
                    if [ -n "$is_dirty" ]; then
                        echo "⚠️  WARNING: The brick '$folder' has uncommitted local changes!"
                        echo "$is_dirty"
                        printf "Force update anyway? (y/N): "
                        read -r confirm
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

            if [ -n "$target_branch" ]; then
                echo "🔄 Switching '$folder' to branch '$target_branch'..."
                git -C "$repo_root" config -f .gitmodules submodule."$folder".branch "$target_branch"
            else
                echo "🔄 Updating brick: $folder..."
            fi

            git -C "$repo_root" submodule update --init --recursive --remote --force "$folder"

            # ACTIVE CHECKOUT: Ensure the specific submodule is on its tracked branch
            local checkout_branch="$target_branch"

            if [ -z "$checkout_branch" ]; then
                checkout_branch=$(git -C "$repo_root" config --file .gitmodules --get "submodule.$folder.branch")
            fi

            if [ -z "$checkout_branch" ]; then
                checkout_branch=$(git -C "$repo_root/$folder" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
                if [ -z "$checkout_branch" ]; then
                    if git -C "$repo_root/$folder" show-ref --verify --quiet refs/heads/main; then
                        checkout_branch="main"
                    else
                        checkout_branch="master"
                    fi
                fi
            fi

            git -C "$repo_root/$folder" checkout -B "$checkout_branch" "origin/$checkout_branch" >/dev/null 2>&1

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

            # --- CUSTOM PATH FIX ---
            local folder
            if [ -d "$repo_root/${target%/}" ]; then
                folder="${target%/}"
            else
                folder=$(basename "$target" .git)
            fi

            local abs_folder="$repo_root/$folder"

            if [ ! -d "$abs_folder" ]; then
                echo "❌ Error: Brick '$folder' is not installed."
                return 1
            fi

            if [ "$skip_prompt" = false ]; then
                printf "⚠️  Are you sure you want to permanently delete the brick '%s'? (y/N): " "$folder"
                read -r confirm
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
                    local sub_path=$(git -C "$repo_root" config --file .gitmodules --get "submodule.$sub.path")
                    local url=$(git -C "$repo_root" config --file .gitmodules --get "submodule.$sub.url")
                    local sub_branch=$(git -C "$repo_root" config --file .gitmodules --get "submodule.$sub.branch")

                    if [ -z "$sub_branch" ]; then sub_branch="(default)"; fi
                    printf "%-20s %-15s %-45s\n" "$sub_path" "$sub_branch" "$url"
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
            echo "  -b, --branch        Specify a target branch (e.g., -b dev)"
            echo ""
            echo "Usage Examples:"
            echo "  brick install gko/postfix"
            echo "  brick install zametka/tunnel services/tunnel"
            echo "  brick install gko/postfix -b v2.0"
            echo "  brick update services/tunnel"
            echo "  brick rm ghost-theme -y"
            ;;
    esac
}
