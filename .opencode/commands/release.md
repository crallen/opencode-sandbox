---
description: Prepare a release with changelog, version bump, and release notes
agent: git-manager
subtask: true
---

Prepare a release for this project. Analyze the commit history since the last tag to determine the appropriate version bump and generate release notes.

Recent tags:
!`git tag --sort=-version:refname | head -5`

Commits since last tag:
!`git log $(git describe --tags --abbrev=0 2>/dev/null || echo "HEAD~20")..HEAD --oneline`

$ARGUMENTS
