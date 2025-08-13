# StackGuardian Template Sync - Example Configuration

This document provides an example of how to configure the StackGuardian Template Sync in your repository.

## 1. GitHub Secrets Setup

First, you need to configure the following secrets in your GitHub repository:

1. Go to your repository settings
2. Click on "Secrets and variables" → "Actions"
3. Add the following secrets:
   - `SG_TOKEN`: Your StackGuardian API token
   - (Optional) `GITHUB_TOKEN`: GitHub token for creating pull requests (usually provided automatically)

## 2. Directory Structure

Create the following directory structure in your repository:

```
your-repo/
├── .github/
│   └── workflows/
│       └── stackguardian-template-sync.yml  # Your workflow file
├── .sg/                                     # Template files directory
│   ├── documentation.md                     # Template documentation
│   ├── schema.json                          # Template input schema
│   └── ui.json                              # Template UI schema
└── README.md
```

## 3. Workflow File Example

Create a workflow file at `.github/workflows/stackguardian-template-sync.yml`:

```yaml
name: StackGuardian Template Sync

on:
  push:
    branches:
      - main
    paths:
      - '.sg/**'
  schedule:
    - cron: '0 2 * * *'  # Run daily at 2 AM UTC
  workflow_dispatch:
    inputs:
      template:
        description: 'StackGuardian template name'
        required: true
      organization:
        description: 'StackGuardian organization name'
        required: true

jobs:
  push:
    name: Push changes to StackGuardian
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Push to StackGuardian
        uses: ./.github/actions/sync
        with:
          SG_TOKEN: ${{ secrets.SG_TOKEN }}
          SG_TEMPLATE: ${{ github.event.inputs.template }}
          SG_ORG: ${{ github.event.inputs.organization }}
          mode: push

  pull:
    name: Pull changes from StackGuardian
    runs-on: ubuntu-latest
    if: github.event_name == 'schedule' || github.event_name == 'workflow_dispatch'
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Pull from StackGuardian
        uses: ./.github/actions/sync
        with:
          SG_TOKEN: ${{ secrets.SG_TOKEN }}
          SG_TEMPLATE: ${{ github.event.inputs.template }}
          SG_ORG: ${{ github.event.inputs.organization }}
          mode: pull

      - name: Check for changes
        id: check_pull_changes
        run: |
          git add .sg/
          if git diff --staged --quiet .sg/; then
            echo "changes=false" >> $GITHUB_OUTPUT
          else
            echo "changes=true" >> $GITHUB_OUTPUT
          fi

      - name: Configure Git and Commit Changes
        if: steps.check_pull_changes.outputs.changes == 'true'
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git commit -m "Update StackGuardian template configuration"

      - name: Create Pull Request
        if: steps.check_pull_changes.outputs.changes == 'true'
        uses: peter-evans/create-pull-request@v5
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          commit-message: Update StackGuardian template configuration
          title: Update StackGuardian template configuration
          body: |
            This PR updates the StackGuardian template configuration files
            with the latest changes from the StackGuardian platform.
          branch: update/sg-template-config
          delete-branch: true
          add-paths: |
            .sg/
```

## 4. Template Files

Place your StackGuardian template files in the `.sg/` directory:

- `documentation.md`: Contains the template documentation/long description
- `schema.json`: Contains the template input schema
- `ui.json`: Contains the template UI schema

## 5. Manual Trigger

To manually trigger the workflow:

1. Go to the "Actions" tab in your repository
2. Select the "StackGuardian Template Sync" workflow
3. Click "Run workflow"
4. Provide the required inputs:
   - `template`: Your StackGuardian template name
   - `organization`: Your StackGuardian organization name

## 6. Customization Options

You can customize the following aspects:

- **Base Path**: Change the `SG_BASE_PATH` input to use a different directory
- **API URL**: Change the `SG_BASE_URL` input to use a different StackGuardian instance
- **Schedule**: Modify the cron schedule in the `schedule` section
- **Branch**: Change the branch name in the `push` section
- **Paths**: Modify the paths filter in the `push` section

For more advanced customization options, refer to the [README.md](README.md) file.