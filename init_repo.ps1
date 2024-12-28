# Display initial message with requirements
Write-Host "Ensure you have the following before running this script:" -ForegroundColor Cyan
Write-Host "1. Git is installed and configured (username and email)." -ForegroundColor Green
Write-Host "2. GitHub CLI (gh) is installed and authenticated." -ForegroundColor Green
Write-Host "   Run `gh auth login` to authenticate if not already logged in." -ForegroundColor Yellow
Write-Host ""


# Check for Git and GitHub CLI installation
if (-not (Get-Command "git" -ErrorAction SilentlyContinue)) {
    Write-Host "Git is not installed or not found in the system PATH." -ForegroundColor Red
    Exit 1
}

if (-not (Get-Command "gh" -ErrorAction SilentlyContinue)) {
    Write-Host "GitHub CLI (gh) is not installed or not found in the system PATH." -ForegroundColor Red
    Write-Host "Install GitHub CLI from https://cli.github.com/. You can also use winget: `winget install --id GitHub.cli`."
    Exit 1
}

# Collect user inputs
$githubUsername = Read-Host "Enter your GitHub username"
if (-not $githubUsername) {
    Write-Host "GitHub username cannot be empty." -ForegroundColor Red
    Exit 1
}

$repoName = Read-Host "Enter the new repository name"
if (-not $repoName) {
    Write-Host "Repository name cannot be empty." -ForegroundColor Red
    Exit 1
}

$description = Read-Host "Enter a description for the repository (optional)"
$visibility = Read-Host "Enter visibility (private/public) [default: private]"
if (-not $visibility) { $visibility = "private" }

$mainBranch = Read-Host "Enter the main branch name (default: main)"
if (-not $mainBranch) { $mainBranch = "main" }

$cloneExisting = Read-Host "Is this a cloned repo you want to push to GitHub? (yes/no) [default: no]"
if (-not $cloneExisting) { $cloneExisting = "no" }

# Optional: Clone an existing repository
if ($cloneExisting -ieq "yes") {
    $existingRepo = Read-Host "Enter the URL of the repository to clone"
    if (-not $existingRepo) {
        Write-Host "Repository URL cannot be empty. Exiting." -ForegroundColor Red
        Exit 1
    }

    git clone $existingRepo $repoName
    Set-Location $repoName

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to clone the repository. Exiting." -ForegroundColor Red
        Exit 1
    }

    Write-Host "Successfully cloned $existingRepo into $repoName."

    # Optional: Remove existing Git history
    $removeHistory = Read-Host "Do you want to remove Git history? (yes/no) [default: no]"
    if ($removeHistory -ieq "yes") {
        Remove-Item -Recurse -Force .git
        git init
        git add .
        git commit -m "Initial commit"
        Write-Host "Git history removed and new repository initialized."
    }

} else {
    #
    Write-Host "Initializing a new local repository for $repoName."
    # Create a new directory for the repository
    if (Test-Path -Path $repoName) {
        Write-Host "Error: A directory with the name '$repoName' already exists. Exiting script." -ForegroundColor Red
        Exit 1
    }
    New-Item -ItemType Directory -Path $repoName -Force | Out-Null
    Set-Location $repoName
    # Initialize a new Git repository
    git init
    Write-Host "New local Git repository initialized in $(Get-Location)."
    # Create a placeholder file for the initial commit
    "This is the $repoName repository." | Set-Content "README.md"
    git add .
    git commit -m "Initial commit"
    Write-Host "Initial commit created with README.md."
}


# Create the new repository on GitHub
$visibilityFlag = if ($visibility -ieq "public") { "--public" } else { "--private" }
if (-not $description) {
    gh repo create $repoName $visibilityFlag
} else {
    gh repo create $repoName $visibilityFlag --description $description
}

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to create GitHub repository. Exiting." -ForegroundColor Red
    Exit 1
}

Write-Host "Successfully created GitHub repository: $repoName ($visibility)" -ForegroundColor Green

# Set up the remote origin
$remoteExists = git remote | Select-String -Pattern '^origin$' -Quiet

if ($remoteExists) {
    Write-Host "Remote 'origin' already exists. Updating the remote URL to https://github.com/$githubUsername/$repoName.git." -ForegroundColor Yellow
    git remote set-url origin https://github.com/$githubUsername/$repoName.git
} else {
    Write-Host "Adding remote 'origin' (https://github.com/$githubUsername/$repoName.git)." -ForegroundColor Cyan
    git remote add origin https://github.com/$githubUsername/$repoName.git
}

# Push the new repository
git branch -M $mainBranch
git push -u origin $mainBranch

if ($LASTEXITCODE -eq 0) {
    Write-Host "Repository $repoName created and pushed successfully." -ForegroundColor Green
} else {
    Write-Host "Failed to push to GitHub. Please check your connection and try again." -ForegroundColor Red
}

Pause
