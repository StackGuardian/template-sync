# StackGuardian Template Sync

This repository contains GitHub Actions workflows and scripts to synchronize StackGuardian templates between your local repository and the StackGuardian platform.

## Overview

The StackGuardian Template Sync solution provides automated synchronization of template configurations between your GitHub repository and StackGuardian. It supports both push (upload) and pull (download) operations:

- **Push**: Upload local template changes to StackGuardian when changes are detected in your repository
- **Pull**: Download template updates from StackGuardian on a schedule or manual trigger, creating pull requests for any changes

## Prerequisites

1. A StackGuardian account with appropriate permissions
2. A StackGuardian API token
3. A StackGuardian organization and template
4. GitHub repository with appropriate secrets configured

## Setup

### 1. Configure GitHub Secrets

Add the following secrets to your GitHub repository:

- `SG_TOKEN`: Your StackGuardian API token
- (Optional) `GITHUB_TOKEN`: GitHub token for creating pull requests (usually provided automatically)

### 2. Directory Structure

The action expects your StackGuardian template files in a specific directory structure:

```
.sg/
├── documentation.md  # Template documentation/long description
├── schema.json       # Template input schema (base64 encoded)
└── ui.json           # Template UI schema (base64 encoded)
```

### 3. Workflow Configuration

The default workflow file [`.github/workflows/sync.yml`](.github/workflows/sync.yml) can be customized through workflow dispatch inputs:

- `template`: (Required) StackGuardian template name
- `organization`: (Required) StackGuardian organization name
- `branch`: (Optional) Branch to monitor for changes (default: `main`)
- `base_path`: (Optional) Base path for template files (default: `.sg`)
- `schedule`: (Optional) Cron schedule for pull operations (default: `0 2 * * *`)
- `api_url`: (Optional) StackGuardian API URL (default: `https://api.app.stackguardian.io`)

## Usage

### Automatic Push

The workflow automatically pushes changes to StackGuardian when commits are made to the configured branch that modify files in the template directory.

### Scheduled Pull

The workflow pulls changes from StackGuardian daily at 2 AM UTC. If changes are detected, a pull request is automatically created.

### Manual Trigger

You can manually trigger the workflow through GitHub's Actions interface, allowing you to specify all configuration parameters.

## Files

- [`.github/workflows/sync.yml`](.github/workflows/sync.yml): Main workflow file
- [`.github/actions/sync/action.yml`](.github/actions/sync/action.yml): Reusable composite action
- [`push.sh`](push.sh): Script to push template changes to StackGuardian
- [`pull.sh`](pull.sh): Script to pull template changes from StackGuardian
- [`.sg/`](.sg/): Directory containing template files

## Customization

To use this in your own repository:

1. Copy the `.github` directory to your repository
2. Create your template files in the `.sg` directory (or your preferred base path)
3. Configure the required GitHub secrets
4. Customize the workflow file as needed for your use case

## Troubleshooting

If you encounter issues:

1. Check that all required secrets are configured correctly
2. Verify that your StackGuardian API token has appropriate permissions
3. Ensure your template and organization names are correct
4. Check the workflow logs for detailed error messages

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.