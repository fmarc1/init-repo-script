import { $ } from "bun";

const prompt = async (question) => {
  process.stdout.write(question);
  for await (const line of console) {
    return line.trim();
  }
};

// Display initial message
console.log("Ensure you have the following before running this script:");
console.log("1. Bun (https://bun.sh/) is installed.");
console.log("1. Git is installed and configured (username and email).");
console.log("2. GitHub CLI (gh) is installed and authenticated.");
console.log("   Run `gh auth login` to authenticate if not already logged in.\n");

// Check for Git and GitHub CLI installation
try {
  await $`git --version`;
} catch {
  console.error("Git is not installed or not found in the system PATH.");
  process.exit(1);
}

try {
  await $`gh --version`;
} catch {
  console.error("GitHub CLI (gh) is not installed or not found in the system PATH.");
  console.error("Install GitHub CLI from https://cli.github.com/. You can also use winget: `winget install --id GitHub.cli`.\n");
  process.exit(1);
}

// Collect user inputs
const githubUsername = await prompt("Enter your GitHub username: ");
if (!githubUsername) {
  console.error("GitHub username cannot be empty.");
  process.exit(1);
}

const repoName = await prompt("Enter the new repository name: ");
if (!repoName) {
  console.error("Repository name cannot be empty.");
  process.exit(1);
}

const description = await prompt("Enter a description for the repository (optional): ");
const visibility = (await prompt("Enter visibility (private/public) [default: private]: ")) || "private";
const mainBranch = (await prompt("Enter the main branch name (default: main): ")) || "main";
const cloneExisting = (await prompt("Is this a cloned repo you want to push to GitHub? (yes/no) [default: no]: ")) || "no";

if (cloneExisting.toLowerCase() === "yes") {
  const existingRepo = await prompt("Enter the URL of the repository to clone: ");
  if (!existingRepo) {
    console.error("Repository URL cannot be empty. Exiting.");
    process.exit(1);
  }

  await $`git clone ${existingRepo} ${repoName}`;
  process.chdir(repoName);

  const removeHistory = (await prompt("Do you want to remove Git history? (yes/no) [default: no]: ")) || "no";
  if (removeHistory.toLowerCase() === "yes") {
    await $`rm -rf .git`;
    await $`git init`;
    await $`git add .`;
    await $`git commit -m "Initial commit"`;
    console.log("Git history removed and new repository initialized.");
  }
} else {
  console.log(`Initializing a new local repository for ${repoName}.`);
  try {
    await $`mkdir ${repoName}`;
  } catch {
    console.error(`Error: A directory with the name '${repoName}' already exists. Exiting script.`);
    process.exit(1);
  }

  process.chdir(repoName);
  await $`git init`;
  console.log(`New local Git repository initialized in ${repoName}.`);

  await Bun.write("README.md", `This is the ${repoName} repository.`);
  await $`git add .`;
  await $`git commit -m "Initial commit"`;
  console.log("Initial commit created with README.md.");
}

// Create GitHub repository
const visibilityFlag = visibility.toLowerCase() === "public" ? "--public" : "--private";
await $`gh repo create ${repoName} ${visibilityFlag} ${description ? `--description "${description}"` : ""}`;
console.log(`Successfully created GitHub repository: ${repoName} (${visibility})`);

// Set up the remote origin
const remoteCheck = await $`git remote`.text();
if (remoteCheck.includes("origin")) {
  console.log(`Remote 'origin' already exists. Updating the remote URL.`);
  await $`git remote set-url origin https://github.com/${githubUsername}/${repoName}.git`;
} else {
  console.log(`Adding remote 'origin'.`);
  await $`git remote add origin https://github.com/${githubUsername}/${repoName}.git`;
}

// Push to GitHub
await $`git branch -M ${mainBranch}`;
await $`git push -u origin ${mainBranch}`;
console.log(`Repository ${repoName} created and pushed successfully.`);
