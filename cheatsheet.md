# GitHub Markdown Images and Download Exclusions Cheat Sheet

This cheat sheet explains how to reference images stored in different locations in a GitHub repository and how to exclude files or folders from downloadable ZIP archives.

## 1. Fix for this repository

Current layout:

```text
FEE-FI-FO-FUM/
├── TERRL-Guard/
│   └── docs/
│       └── TERRL-Guard-Solution-Guide.md
└── media/
    └── TERRL-Guard-Workbook-Demo.svg
```

The Markdown file is two directory levels below the repository root. Therefore, this path is incorrect:

```markdown
![TERRL Guard workbook demo](media/TERRL-Guard-Workbook-Demo.svg)
```

Use either of these forms instead.

### Recommended: document-relative path

```markdown
![TERRL Guard workbook demo](../../media/TERRL-Guard-Workbook-Demo.svg)
```

Path calculation:

```text
TERRL-Guard/docs/
        ../       -> TERRL-Guard/
        ../       -> repository root
        media/    -> media folder
```

### GitHub repository-root path

```markdown
![TERRL Guard workbook demo](/media/TERRL-Guard-Workbook-Demo.svg)
```

This is convenient on GitHub, but `../../media/...` is usually more portable in local Markdown viewers, clones and forks.

> Important: Paths are resolved from the directory containing the Markdown file, not from the repository root, unless the path starts with `/`.

---

## 2. Markdown image syntax

```markdown
![Alternative text](path-to-image "Optional title")
```

Example:

```markdown
![TERRL Guard workbook](../../media/TERRL-Guard-Workbook-Demo.svg "TERRL Guard workbook demo")
```

Do not put a space between `]` and `(`:

```markdown
<!-- Correct -->
![Demo](../../media/demo.png)

<!-- Incorrect -->
![Demo] (../../media/demo.png)
```

---

## 3. Relative-path examples

Assume this layout:

```text
repository-root/
├── README.md
├── media/
│   ├── architecture.png
│   └── workbook.svg
└── docs/
    ├── guide.md
    ├── images/
    │   └── local.png
    └── deployment/
        └── install.md
```

| Markdown file location | Image location | Markdown path |
|---|---|---|
| `README.md` | `media/architecture.png` | `![Architecture](media/architecture.png)` |
| `docs/guide.md` | `docs/images/local.png` | `![Local](images/local.png)` |
| `docs/guide.md` | `media/workbook.svg` | `![Workbook](../media/workbook.svg)` |
| `docs/deployment/install.md` | `media/architecture.png` | `![Architecture](../../media/architecture.png)` |
| Any GitHub-rendered Markdown file | `media/workbook.svg` from repo root | `![Workbook](/media/workbook.svg)` |

### Same directory

```markdown
![Screenshot](screenshot.png)
```

or:

```markdown
![Screenshot](./screenshot.png)
```

### Child directory

```markdown
![Screenshot](images/screenshot.png)
```

### Parent directory

```markdown
![Screenshot](../screenshot.png)
```

### Parent and sibling directory

```markdown
![Screenshot](../media/screenshot.png)
```

### Multiple parent levels

```markdown
![Screenshot](../../media/screenshot.png)
```

---

## 4. Images in another repository

Relative paths cannot cross into a separate GitHub repository. Use a raw image URL pinned to a branch, tag or commit.

### Branch URL

```markdown
![Shared diagram](https://raw.githubusercontent.com/OWNER/REPOSITORY/main/media/diagram.png)
```

### Tag URL

```markdown
![Shared diagram](https://raw.githubusercontent.com/OWNER/REPOSITORY/v1.0.0/media/diagram.png)
```

### Commit-pinned URL

```markdown
![Shared diagram](https://raw.githubusercontent.com/OWNER/REPOSITORY/COMMIT-SHA/media/diagram.png)
```

A tag or commit-pinned URL is safer for documentation that must not change unexpectedly.

Private-repository images might not render for users who do not have access.

---

## 5. Images with spaces or special characters

Best option: rename files to use hyphens.

```text
workbook-demo.png
```

If renaming is not possible, encode spaces as `%20`:

```markdown
![Workbook demo](../media/workbook%20demo.png)
```

Also check capitalization. Git paths are case-sensitive:

```text
Demo.png != demo.png
```

---

## 6. Clickable images

```markdown
[![Workbook preview](../../media/TERRL-Guard-Workbook-Demo.svg)](../../media/TERRL-Guard-Workbook-Demo.svg)
```

Clickable image linked to another page:

```markdown
[![Workbook preview](../../media/TERRL-Guard-Workbook-Demo.svg)](../workbook/README.md)
```

---

## 7. HTML image alternative

Use HTML when width or alignment control is required:

```html
<p align="center">
  <img src="../../media/TERRL-Guard-Workbook-Demo.svg"
       alt="TERRL Guard workbook demo"
       width="900">
</p>
```

Prefer standard Markdown unless HTML sizing or alignment is genuinely needed.

---

## 8. Troubleshooting checklist

1. Start from the folder containing the Markdown file.
2. Count how many `../` operations are needed to reach the common parent.
3. Add the path from that parent to the image.
4. Confirm the exact filename, extension and capitalization.
5. Remove any space between `]` and `(`.
6. Confirm the image has been committed and pushed.
7. Use the **Preview** tab in GitHub before committing.
8. Open the calculated image path directly in GitHub to confirm it exists.
9. Prefer `/` in paths, including when editing on Windows.
10. Avoid local paths such as `C:\Users\...`; other users and GitHub cannot access them.

---

# Excluding content from downloaded ZIP archives

## 9. Use `.gitattributes`, not `.gitignore`

`.gitignore` prevents untracked files from being added to Git. It does not remove tracked files from an archive.

The `export-ignore` attribute tells `git archive` to omit matching paths. GitHub source ZIP and TAR archives are generated using `git archive`.

Create this file at the repository root:

```text
.gitattributes
```

## 10. Exact example for this repository

Based on the current structure, use:

```gitattributes
# Exclude TERRL-Guard documentation from exported archives
/TERRL-Guard/docs/ export-ignore

# Exclude the repository-root media folder from exported archives
/media/ export-ignore
```

This excludes:

```text
TERRL-Guard/docs/
media/
```

It does not delete anything from the repository. It only excludes the paths when an archive is generated.

> Because the image used by the guide is in `/media`, excluding `/media` means the image will not exist inside the downloaded archive. That is acceptable only if the documentation using the image is also excluded or the image is not required offline.

---

## 11. Common `export-ignore` examples

### Exclude root folders

```gitattributes
/docs/ export-ignore
/media/ export-ignore
/tests/ export-ignore
```

### Exclude a nested folder

```gitattributes
/TERRL-Guard/docs/ export-ignore
```

### Exclude individual files

```gitattributes
/CONTRIBUTING.md export-ignore
/SECURITY.md export-ignore
/.editorconfig export-ignore
```

### Exclude GitHub configuration

```gitattributes
/.github/ export-ignore
```

### Exclude all Markdown files

```gitattributes
*.md export-ignore
```

Use this carefully because it also removes root `README.md` files from the archive.

### Exclude all files with an extension

```gitattributes
*.psd export-ignore
*.drawio export-ignore
*.log export-ignore
```

### Exclude development and test content

```gitattributes
/.github/ export-ignore
/tests/ export-ignore
/dev/ export-ignore
*.Tests.ps1 export-ignore
```

### Exclude `.gitattributes` from its own archive

```gitattributes
/.gitattributes export-ignore
```

---

## 12. Suggested `.gitattributes` for FEE-FI-FO-FUM

```gitattributes
# Normalise text files
* text=auto

# PowerShell line endings
*.ps1  text eol=crlf
*.psm1 text eol=crlf
*.psd1 text eol=crlf

# Exclude documentation and media from release/download archives
/TERRL-Guard/docs/ export-ignore
/media/ export-ignore

# Optional repository-only content
/.github/ export-ignore
/.gitignore export-ignore
/.gitattributes export-ignore
```

Only include the optional entries if they are not required by recipients of the ZIP.

---

## 13. Test the archive before pushing

### PowerShell

```powershell
# Run from the repository root
$OutputPath = Join-Path $PWD 'FEE-FI-FO-FUM-test.zip'

git archive `
    --format=zip `
    --output=$OutputPath `
    HEAD

Write-Host "Archive created: $OutputPath"
```

### List the archive without extracting

```powershell
Add-Type -AssemblyName System.IO.Compression.FileSystem

$ZipPath = Join-Path $PWD 'FEE-FI-FO-FUM-test.zip'
$Zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)

try {
    $Zip.Entries.FullName | Sort-Object
}
finally {
    $Zip.Dispose()
}
```

### Check specifically for excluded paths

```powershell
Add-Type -AssemblyName System.IO.Compression.FileSystem

$ZipPath = Join-Path $PWD 'FEE-FI-FO-FUM-test.zip'
$Zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)

try {
    $Unexpected = $Zip.Entries.FullName | Where-Object {
        $_ -like 'TERRL-Guard/docs/*' -or
        $_ -like 'media/*'
    }

    if ($Unexpected) {
        Write-Warning 'Excluded content was found:'
        $Unexpected
    }
    else {
        Write-Host 'PASS: docs and media paths are absent from the archive.' -ForegroundColor Green
    }
}
finally {
    $Zip.Dispose()
}
```

### Azure Cloud Shell or Bash

```bash
git archive --format=zip --output=FEE-FI-FO-FUM-test.zip HEAD
unzip -l FEE-FI-FO-FUM-test.zip
```

---

## 14. Important distinctions

| File or feature | Purpose |
|---|---|
| `.gitignore` | Prevents matching untracked files from being added to Git |
| `.gitattributes` with `export-ignore` | Excludes tracked paths from `git archive` output |
| GitHub **Download ZIP** | Downloads a source-code snapshot, not the complete Git history |
| `git clone` | Downloads the tracked repository content and Git history; `export-ignore` does not remove files from a clone |
| Release asset uploaded manually | Contains whatever was placed in the uploaded asset; `.gitattributes` does not rewrite an already-created ZIP |

If a release must contain only deployable files, generate and validate a dedicated release ZIP with `git archive`, then upload that ZIP as a release asset.

---

## 15. Quick copy-and-paste answer

For `TERRL-Guard/docs/TERRL-Guard-Solution-Guide.md` targeting the root-level `media` folder:

```markdown
![TERRL Guard workbook demo](../../media/TERRL-Guard-Workbook-Demo.svg)
```

At the repository root, create `.gitattributes` containing:

```gitattributes
/TERRL-Guard/docs/ export-ignore
/media/ export-ignore
```
