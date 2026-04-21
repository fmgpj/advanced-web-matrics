#!/bin/bash

set -e

echo "Release preparation"
echo "==================="

CURRENT_BRANCH=$(git branch --show-current)
echo "Current branch: $CURRENT_BRANCH"

RELEASE_BRANCH="main"
STAGING_BRANCH="main"

if [ "$CURRENT_BRANCH" != "$STAGING_BRANCH" ]; then
    echo ""
    echo "This script must be run from '$STAGING_BRANCH'."
    exit 1
fi

echo ""
echo "Running checks..."
npm run pre-deploy

if ! grep -q "## \[Unreleased\]" CHANGELOG.md; then
    echo ""
    echo "CHANGELOG.md must contain an [Unreleased] section."
    exit 1
fi

CURRENT_VERSION=$(node -p "require('./package.json').version")
echo ""
echo "Current version: $CURRENT_VERSION"
echo "Choose version bump type:"
echo "1) Patch"
echo "2) Minor"
echo "3) Major"
echo "4) Skip"

read -p "Enter choice (1-4): " VERSION_CHOICE

case $VERSION_CHOICE in
    1)
        npm version patch --no-git-tag-version
        ;;
    2)
        npm version minor --no-git-tag-version
        ;;
    3)
        npm version major --no-git-tag-version
        ;;
    4)
        echo "Skipping version bump"
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

NEW_VERSION=$(node -p "require('./package.json').version")
echo "Selected version: $NEW_VERSION"

if [ "$VERSION_CHOICE" != "4" ]; then
    CURRENT_DATE=$(date +%Y-%m-%d)
    NEW_SECTION="## [${NEW_VERSION}] - ${CURRENT_DATE}

### Added

### Changed

### Fixed

### Removed

"

    awk -v new_section="$NEW_SECTION" '
    /^## \[Unreleased\]/ {
        print $0
        while ((getline) && !/^## \[/) {
            print $0
        }
        printf "%s", new_section
        print $0
        next
    }
    { print }
    ' CHANGELOG.md > CHANGELOG.tmp && mv CHANGELOG.tmp CHANGELOG.md

    echo ""
    echo "Move your release notes from [Unreleased] into [${NEW_VERSION}], then clear [Unreleased]."
    read -p "Press Enter when CHANGELOG.md is ready..."

    git add package.json CHANGELOG.md package-lock.json 2>/dev/null || true
    git commit -m "chore: release v${NEW_VERSION}" || echo "No release changes to commit"
    git tag "v${NEW_VERSION}" || echo "Tag already exists or could not be created"
fi

echo ""
echo "Pushing release branch..."
git push origin "$STAGING_BRANCH"

echo ""
echo "Promoting $STAGING_BRANCH to $RELEASE_BRANCH..."
git checkout "$RELEASE_BRANCH"
git merge --no-ff "$STAGING_BRANCH" -m "chore: promote ${STAGING_BRANCH} to ${RELEASE_BRANCH} for release v${NEW_VERSION}"

if [ "$VERSION_CHOICE" != "4" ]; then
    git push origin "$RELEASE_BRANCH" --tags
else
    git push origin "$RELEASE_BRANCH"
fi

git checkout "$STAGING_BRANCH"

echo ""
echo "Release complete"
echo "Version: $(node -p "require('./package.json').version")"