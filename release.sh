#!/usr/bin/env bash
set -ex

# Check required tools
for tool in git gh docker git-cliff; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Error: $tool is not installed." >&2
    exit 1
  fi
done

# Step 1: Generate changelog and get new version

NEW_VERSION=$(git cliff --bumped-version --unreleased | cut -dv -f2)
if [ -z "$NEW_VERSION" ]; then
  echo "Error: Could not determine new version from git cliff." >&2
  exit 1
fi

echo "New version: $NEW_VERSION"

# Step 2: Update shard.yml version
sed -i "s/^version: .*/version: $NEW_VERSION/" shard.yml

echo "Updated shard.yml to version $NEW_VERSION"

# Step 3: Generate full changelog
GIT_CLIFF_CHANGELOG="CHANGELOG-$NEW_VERSION.md"
git cliff --tag "$NEW_VERSION" --output "$GIT_CLIFF_CHANGELOG"

# Step 3b: Update persistent CHANGELOG.md (all releases)
git cliff --output CHANGELOG.md

echo "Generated changelog: $GIT_CLIFF_CHANGELOG"



# Step 5: Build static binaries and files
./build_static.sh

echo "Static binaries built."

# Step 4: Update dependencies and commit version bump, changelogs, and lockfile
shards update --production
if ! git diff --quiet shard.yml "$GIT_CLIFF_CHANGELOG" CHANGELOG.md shard.lock; then
  git add shard.yml "$GIT_CLIFF_CHANGELOG" CHANGELOG.md shard.lock
  git commit -m "chore(release): v$NEW_VERSION"
fi

git tag "v$NEW_VERSION"
git push
git push --tags

echo "Committed and pushed release tag v$NEW_VERSION"



# Step 6: Build, tag, and push Docker images
./upload_docker.sh "$NEW_VERSION"

echo "Docker images built and pushed with tag $NEW_VERSION."

# Step 7: Create GitHub release and upload artifacts
GH_RELEASE_ARGS=("v$NEW_VERSION" "--title" "Pasto $NEW_VERSION" "--notes-file" "$GIT_CLIFF_CHANGELOG")
GH_ASSETS=(bin/pasto-static-linux-amd64 bin/pasto-ssh-static-linux-amd64 bin/pasto-static-linux-arm64 bin/pasto-ssh-static-linux-arm64 index.html)
for asset in "${GH_ASSETS[@]}"; do
  if [ -f "$asset" ]; then
    GH_RELEASE_ARGS+=("$asset")
  fi
done

gh release create "${GH_RELEASE_ARGS[@]}"

echo "GitHub release created and assets uploaded."
