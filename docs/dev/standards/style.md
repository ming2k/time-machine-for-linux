# Documentation Style & Hyperlink Standards

This document specifies the style guide, markdown conventions, and hyperlink standards for all documentation in the repository.

---

## 1. Hyperlink Standards

1. **Relative Paths**: All cross-references between documentation files must use explicit relative paths (e.g., `[Unified CLI Architecture](../../adr/0001-unified-cli-architecture.md)`).
2. **Never Use Absolute Locators**: Never write hardcoded local paths (e.g., `/home/...` or `file://...`) or absolute repo URLs that break across mirrors or offline workflows.
3. **Target Existence**: Every relative link must resolve to a valid file on disk. Dead links or broken targets degrade epistemic trust and fail validation.
4. **Anchor Hygiene**: When linking to section headers, use clean kebab-case anchors matching the heading text.

---

## 2. Formatting & Markdown Conventions

1. **Header Hierarchy**:
   - Exactly one `# Level 1 Heading` per file at line 1.
   - Subsections descend logically: `## Level 2`, followed by `### Level 3`. Avoid skipping heading levels arbitrarily.
2. **Typed Code Blocks**:
   - Always declare an explicit language identifier on fenced code blocks (e.g., ````bash````, ````text````, ````yaml````). Never leave fences untyped.
3. **Lists and Tables**:
   - Use clean Markdown tables with aligned delimiters.
   - For lists, prefer `-` for unordered bullet points and `1.` for sequential procedures.

---

## 3. Tone and Vocabulary

1. **Pragmatic and Objective**: Write in active, direct, and unambiguous language. Avoid marketing hyperbole or unnecessary jargon.
2. **Mechanisms Over Aspirations**: When describing behavioral constraints, describe the concrete enforcing mechanism (Bash assertions, exit codes, preflight checks, test suites) rather than vague prose.
3. **Zero Dead Links**: Never link to non-existent historical files or dead local paths.
