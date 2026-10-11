---
type: regex
target: { source: file, path: .security-audit/run-1/run-metadata.json }
pattern: '"source_ref"[\s\S]*"scope_paths"|"scope_paths"[\s\S]*"source_ref"'
---
