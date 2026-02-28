#!/usr/bin/env python3
"""
Finales Cleanup: Findet alle verbleibenden token-Referenzen in Svelte-Dateien
"""

import os
import re
from pathlib import Path

def find_token_references(directory):
    """Sucht nach token-Referenzen in Svelte-Dateien"""
    issues = []

    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.svelte'):
                filepath = os.path.join(root, file)
                with open(filepath, 'r', encoding='utf-8') as f:
                    lines = f.readlines()

                for i, line in enumerate(lines, 1):
                    # Skip comments
                    if line.strip().startswith('//'):
                        continue

                    # Skip CSS classes with "token" in name
                    if 'class=' in line or 'bg-' in line or 'surface-active-token' in line or 'surface-600-300-token' in line:
                        continue

                    # Check for problematic patterns
                    if re.search(r'\btoken\b', line) and 'resetToken' not in line and 'tokenUrl' not in line:
                        # Exclude password reset page and PasswordReset component (they use a different token variable)
                        if 'password_reset' not in filepath.lower() and 'PasswordReset.svelte' not in filepath:
                            issues.append({
                                'file': filepath,
                                'line': i,
                                'content': line.strip()
                            })

    return issues

if __name__ == "__main__":
    print("🔍 Suche nach verbleibenden token-Referenzen...\n")

    frontend_dir = "../../frontend/src"
    issues = find_token_references(frontend_dir)

    if issues:
        print(f"⚠️  {len(issues)} problematische Referenzen gefunden:\n")
        for issue in issues:
            rel_path = os.path.relpath(issue['file'], frontend_dir)
            print(f"📄 {rel_path}:{issue['line']}")
            print(f"   {issue['content']}\n")
    else:
        print("✅ Keine problematischen token-Referenzen gefunden!")


