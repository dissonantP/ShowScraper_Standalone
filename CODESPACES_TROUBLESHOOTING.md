# Codespaces Troubleshooting

## If devcontainer changes aren't reflected:

### Option 1: Delete and recreate (recommended)
1. Go to your repository on GitHub
2. Click "Code" → "Codespaces"
3. Click the "..." menu next to your Codespace
4. Select "Delete"
5. Create a new Codespace

### Option 2: Full rebuild from Codespace
1. Open Command Palette (Cmd/Ctrl + Shift + P)
2. Run: "Codespaces: Full Rebuild Container"
   - NOT just "Rebuild Container" - you need the FULL rebuild

### Option 3: Force pull latest and rebuild
```bash
# Inside Codespace terminal
cd /workspaces/$(basename $GITHUB_REPOSITORY)
git fetch origin
git reset --hard origin/master
```

Then rebuild: Cmd/Ctrl + Shift + P → "Codespaces: Full Rebuild Container"

## Common Issues

### Issue: Codespace uses old production image
**Cause**: devcontainer.json pointed to production docker-compose.yml instead of dev version

**Fix**: Commit `ded5293` changed this - new Codespaces will use dev image

### Issue: Git not available in container
**Cause**: Production Dockerfile uses ruby:3.3-slim without dev tools

**Fix**: Dev Dockerfile (`.devcontainer/Dockerfile`) includes git and all dev tools

### Issue: Code changes don't reflect immediately
**Cause**: Production image copies code in (immutable)

**Fix**: Dev compose mounts workspace as volume (changes are instant)

## Verifying You're in Dev Container

Run inside Codespace:
```bash
which git        # Should return /usr/bin/git
ruby --version   # Should show ruby 3.3.x
ls -la /app      # Should show your source files
```

If git is missing or files look wrong, you're still using production image.
