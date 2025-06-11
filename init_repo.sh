#!/bin/zsh

# Display initial message with requirements
echo "\033[0;36mEnsure you have the following before running this script:\033[0m"
echo "\033[0;32m1. Git is installed and configured (username and email).\033[0m"
echo "\033[0;32m2. GitHub CLI (gh) is installed and authenticated.\033[0m"
echo "\033[0;33m   Run \`gh auth login\` to authenticate if not already logged in.\033[0m"
echo ""

# Check for Git and GitHub CLI installation
if ! command -v git >/dev/null 2>&1; then
    echo "\033[0;31mGit is not installed or not found in the system PATH.\033[0m"
    exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
    echo "\033[0;31mGitHub CLI (gh) is not installed or not found in the system PATH.\033[0m"
    echo "Install GitHub CLI from https://cli.github.com/"
    exit 1
fi

# Collect user inputs
read "?Enter your GitHub username: " githubUsername
if [[ -z "$githubUsername" ]]; then
    echo "\033[0;31mGitHub username cannot be empty.\033[0m"
    exit 1
fi

read "?Enter the new repository name: " repoName
if [[ -z "$repoName" ]]; then
    echo "\033[0;31mRepository name cannot be empty.\033[0m"
    exit 1
fi

read "?Enter a description for the repository (optional): " description
read "?Enter visibility (private/public) [default: private]: " visibility
visibility=${visibility:-private}

read "?Enter the main branch name (default: main): " mainBranch
mainBranch=${mainBranch:-main}

read "?Is this a cloned repo you want to push to GitHub? (yes/no) [default: no]: " cloneExisting
cloneExisting=${cloneExisting:-no}

# Optional: Clone an existing repository
if [[ "$cloneExisting" == "yes" ]]; then
    read "?Enter the URL of the repository to clone: " existingRepo
    if [[ -z "$existingRepo" ]]; then
        echo "\033[0;31mRepository URL cannot be empty. Exiting.\033[0m"
        exit 1
    fi

    git clone "$existingRepo" "$repoName"
    cd "$repoName" || { echo "\033[0;31mFailed to enter repo directory.\033[0m"; exit 1; }

    if [[ $? -ne 0 ]]; then
        echo "\033[0;31mFailed to clone the repository. Exiting.\033[0m"
        exit 1
    fi

    echo "Successfully cloned $existingRepo into $repoName."

    read "?Do you want to remove Git history? (yes/no) [default: no]: " removeHistory
    removeHistory=${removeHistory:-no}
    if [[ "$removeHistory" == "yes" ]]; then
        rm -rf .git
        git init
        git add .
        git commit -m "Initial commit"
        echo "Git history removed and new repository initialized."
    fi
else
    echo "Initializing a new local repository for $repoName."
    if [[ -d "$repoName" ]]; then
        echo "\033[0;31mError: A directory with the name '$repoName' already exists. Exiting script.\033[0m"
        exit 1
    fi
    mkdir "$repoName"
    cd "$repoName" || exit
    git init
    echo "New local Git repository initialized in $(pwd)."
    echo "This is the $repoName repository." > README.md
    git add .
    git commit -m "Initial commit"
    echo "Initial commit created with README.md."
fi

# Create the new repository on GitHub
visibilityFlag="--private"
[[ "$visibility" == "public" ]] && visibilityFlag="--public"

if [[ -z "$description" ]]; then
    gh repo create "$repoName" $visibilityFlag --source=. --remote=origin --push
else
    gh repo create "$repoName" $visibilityFlag --description "$description" --source=. --remote=origin --push
fi

if [[ $? -ne 0 ]]; then
    echo "\033[0;31mFailed to create GitHub repository. Exiting.\033[0m"
    exit 1
fi

echo "\033[0;32mSuccessfully created GitHub repository: $repoName ($visibility)\033[0m"

# Set up the remote origin
if git remote get-url origin >/dev/null 2>&1; then
    echo "\033[0;33mRemote 'origin' already exists. Updating the remote URL to https://github.com/$githubUsername/$repoName.git.\033[0m"
    git remote set-url origin "https://github.com/$githubUsername/$repoName.git"
else
    echo "\033[0;36mAdding remote 'origin' (https://github.com/$githubUsername/$repoName.git).\033[0m"
    git remote add origin "https://github.com/$githubUsername/$repoName.git"
fi

# Push the new repository
git branch -M "$mainBranch"
git push -u origin "$mainBranch"

if [[ $? -eq 0 ]]; then
    echo "\033[0;32mRepository $repoName created and pushed successfully.\033[0m"
else
    echo "\033[0;31mFailed to push to GitHub. Please check your connection and try again.\033[0m"
fi
