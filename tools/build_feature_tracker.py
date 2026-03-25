#!/usr/bin/env python3

from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parent.parent
DOCS_API = ROOT / "docs" / "api"
OUT_DIR = DOCS_API / "implementation-tracker"

CURATED_REF = DOCS_API / "swiftui-reference-2025-clade.md"
GENERATED_REF = DOCS_API / "swiftui-reference-2025-codex.md"
PARITY_REF = ROOT / "docs" / "architecture" / "swiftui-parity-matrix.md"
SOURCE_ROOT = ROOT / "Sources" / "SwiftOpenUI"


VIEW_GROUP_FILES = {
    "Text Views": "views.md",
    "Controls": "views.md",
    "Indicators": "views.md",
    "Images & Media": "views.md",
    "Layout Containers": "views.md",
    "Collection Views": "views.md",
    "Grouping & Disclosure": "views.md",
    "Navigation": "views.md",
    "Drawing & Graphics": "views.md",
    "Shapes": "views.md",
    "Structural / Utility Views": "views.md",
    "Map & Location": "views.md",
    "Auth Views": "views.md",
    "Presentation": "adjacent-apis.md",
    "Scenes": "adjacent-apis.md",
    "visionOS-Specific Views": "views.md",
    "StoreKit Views": "views.md",
    "WWDC25 (iOS 26 / macOS 26)": "views.md",
}

MODIFIER_GROUP_FILES = {
    "Layout Modifiers (~43)": "modifiers-01-layout.md",
    "Appearance Modifiers (~81)": "modifiers-02-appearance.md",
    "Text and Symbol Modifiers (~50)": "modifiers-03-text-symbol.md",
    "Style Modifiers (~21)": "modifiers-04-style.md",
    "Graphics and Rendering Modifiers (~53)": "modifiers-05-graphics-rendering.md",
    "Navigation and Auxiliary Modifiers (~48)": "modifiers-06-navigation-auxiliary.md",
    "Presentation Modifiers (~97)": "modifiers-07-presentation.md",
    "Input and Event Modifiers (~148)": "modifiers-08-input-events.md",
    "Search Modifiers (~16)": "modifiers-09-search.md",
    "Accessibility Modifiers (~67)": "modifiers-10-accessibility.md",
    "State and Environment Modifiers (~20)": "modifiers-11-state-environment.md",
    "Deprecated Modifiers and Replacements (~52)": "modifiers-11-state-environment.md",
}

MODIFIER_GENERATED_BUCKETS = (
    ("A-G", lambda name: name[0].upper() <= "G"),
    ("H-P", lambda name: "H" <= name[0].upper() <= "P"),
    ("Q-Z", lambda name: name[0].upper() >= "Q"),
)

ADJACENT_VIEW_NAMES = {
    "ActionSheet",
    "DocumentGroup",
    "ImmersiveSpace",
    "NavigationPath",
    "Path",
    "Settings",
    "Volume",
    "Window",
    "WindowGroup",
}

ADJACENT_MODIFIER_NAMES = {
    "withAnimation",
}


@dataclass
class Feature:
    name: str
    availability: str = "-"
    swiftui_status: str = "Current"
    origin: str = ""
    implementation_status: str = "Missing"
    evidence: str = "-"
    notes: str = "-"
    reference_overloads: int | None = None
    source_overloads: int | None = None


@dataclass
class CuratedInfo:
    availability: str = "-"
    swiftui_status: str = "Current"
    notes: str = "-"
    reference_overloads: int = 0


def clean_cell(text: str) -> str:
    text = text.strip()
    text = text.replace("**", "").replace("`", "")
    return re.sub(r"\s+", " ", text).strip()


def base_modifier_name(text: str) -> str:
    text = clean_cell(text)
    if text.startswith("."):
        text = text[1:]
    return text.split("(")[0].strip()


def is_table_separator(value: str) -> bool:
    stripped = value.strip()
    return bool(stripped) and set(stripped) <= {"-"}


def parse_markdown_tables(lines: Iterable[str]) -> list[list[str]]:
    rows: list[list[str]] = []
    for line in lines:
        if not line.startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if not cells or all(is_table_separator(cell) for cell in cells):
            continue
        rows.append(cells)
    return rows


def parse_generated_views() -> dict[str, Feature]:
    text = GENERATED_REF.read_text()
    match = re.search(
        r"## Views\n\n\| View \| Availability \| Status \| Notes \|\n\|---\|---\|---\|---\|\n(.*?)\n## View Modifiers",
        text,
        re.S,
    )
    assert match
    features: dict[str, Feature] = {}
    for cells in parse_markdown_tables(match.group(1).splitlines()):
        if cells[0] == "View":
            continue
        name = clean_cell(cells[0])
        features[name] = Feature(
            name=name,
            availability=clean_cell(cells[1]),
            swiftui_status=clean_cell(cells[2]),
            origin="Generated",
            notes=clean_cell(cells[3]) if len(cells) > 3 and clean_cell(cells[3]) != "-" else "-",
        )
    return features


def parse_generated_modifiers() -> dict[str, Feature]:
    text = GENERATED_REF.read_text()
    match = re.search(
        r"## View Modifiers\n\n\| Modifier \| Overloads \| Availability \| Status \| Notes \|\n\|---\|---:\|---\|---\|---\|\n(.*)",
        text,
        re.S,
    )
    assert match
    features: dict[str, Feature] = {}
    for cells in parse_markdown_tables(match.group(1).splitlines()):
        if cells[0] == "Modifier":
            continue
        name = base_modifier_name(cells[0])
        features[name] = Feature(
            name=name,
            availability=clean_cell(cells[2]),
            swiftui_status=clean_cell(cells[3]),
            origin="Generated",
            notes=clean_cell(cells[4]) if len(cells) > 4 and clean_cell(cells[4]) != "-" else "-",
            reference_overloads=int(cells[1]),
        )
    return features


def parse_curated_reference() -> tuple[
    dict[str, set[str]],
    dict[str, set[str]],
    dict[str, CuratedInfo],
    dict[str, CuratedInfo],
]:
    text = CURATED_REF.read_text()
    view_groups: dict[str, set[str]] = {}
    modifier_groups: dict[str, set[str]] = {}
    view_info: dict[str, CuratedInfo] = {}
    modifier_info: dict[str, CuratedInfo] = {}
    part = None
    current_group: str | None = None

    for raw_line in text.splitlines():
        line = raw_line.rstrip()
        if line.startswith("# Part 1: Views"):
            part = "views"
            current_group = None
            continue
        if line.startswith("# Part 2: Modifiers"):
            part = "modifiers"
            current_group = None
            continue
        if part == "views" and (
            line.startswith("## Deprecated Views Summary")
            or line.startswith("## Views by Release")
        ):
            part = None
            current_group = None
            continue
        if line.startswith("## Totals") or line.startswith("## New by Release"):
            break

        match = re.match(r"##\s+\d+\.\s+(.+)", line)
        if match:
            current_group = match.group(1).strip()
            continue

        if part not in {"views", "modifiers"} or current_group is None or not line.startswith("|"):
            continue

        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if not cells or is_table_separator(cells[0]):
            continue

        header = clean_cell(cells[0])
        if header in {"View", "View/Modifier", "Modifier", "Type", "Deprecated View", "Deprecated Modifier", "Release"}:
            continue

        if part == "views":
            name = clean_cell(cells[0]).split("(")[0].strip()
            if name.startswith("."):
                base = base_modifier_name(name)
                modifier_groups.setdefault(current_group, set()).add(base)
                info = modifier_info.setdefault(
                    base,
                    CuratedInfo(
                        availability=clean_cell(cells[2]) if len(cells) > 2 else "-",
                        swiftui_status="Current",
                        notes=clean_cell(cells[3]) if len(cells) > 3 and clean_cell(cells[3]) not in {"No", "Yes"} else "-",
                    ),
                )
                info.reference_overloads += 1
            else:
                view_groups.setdefault(current_group, set()).add(name)
                availability = clean_cell(cells[2]) if len(cells) > 2 else "-"
                deprecated = clean_cell(cells[3]) if len(cells) > 3 else "No"
                is_deprecated = bool(re.search(r"\bYes\b", deprecated))
                view_info.setdefault(
                    name,
                    CuratedInfo(
                        availability=availability,
                        swiftui_status="Deprecated" if is_deprecated else "Current",
                        notes=deprecated if is_deprecated else "-",
                    ),
                )
        else:
            name = clean_cell(cells[0])
            for part_name in [piece.strip() for piece in name.split("/")]:
                base = base_modifier_name(part_name)
                if base:
                    modifier_groups.setdefault(current_group, set()).add(base)
                    availability = clean_cell(cells[1]) if len(cells) > 1 else "-"
                    notes = clean_cell(cells[2]) if len(cells) > 2 else "-"
                    info = modifier_info.setdefault(
                        base,
                        CuratedInfo(
                            availability=availability if not current_group.startswith("Deprecated Modifiers") else "-",
                            swiftui_status="Deprecated" if current_group.startswith("Deprecated Modifiers") else "Current",
                            notes=notes,
                        ),
                    )
                    if not current_group.startswith("Deprecated Modifiers"):
                        info.reference_overloads += 1

    return view_groups, modifier_groups, view_info, modifier_info


def extract_public_surface() -> tuple[
    dict[str, str],
    dict[str, str],
    dict[str, str],
    dict[str, int],
    dict[str, int],
]:
    type_paths: dict[str, str] = {}
    view_modifier_paths: dict[str, str] = {}
    function_paths: dict[str, str] = {}
    view_modifier_counts: dict[str, int] = {}
    function_counts: dict[str, int] = {}

    type_pattern = re.compile(
        r"public\s+(?:struct|enum|protocol|class)\s+([A-Za-z_][A-Za-z0-9_]*)"
    )
    function_pattern = re.compile(
        r"^\s*public func\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?:<[^>]+>)?\s*\(",
        re.M,
    )
    modifier_pattern = re.compile(
        r"public func\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?:<[^>]+>)?\s*\("
    )

    for path in SOURCE_ROOT.rglob("*.swift"):
        rel = path.relative_to(ROOT).as_posix()
        text = path.read_text()

        for match in type_pattern.finditer(text):
            type_paths.setdefault(match.group(1), rel)

        for match in function_pattern.finditer(text):
            name = match.group(1)
            function_paths.setdefault(name, rel)
            function_counts[name] = function_counts.get(name, 0) + 1

        lines = text.splitlines()
        in_view_extension = False
        brace_depth = 0
        for line in lines:
            if re.match(r"\s*extension View\s*\{", line):
                in_view_extension = True
                brace_depth = line.count("{") - line.count("}")
                continue
            if not in_view_extension:
                continue
            brace_depth += line.count("{") - line.count("}")
            func_match = modifier_pattern.search(line)
            if func_match:
                name = func_match.group(1)
                view_modifier_paths.setdefault(name, rel)
                view_modifier_counts[name] = view_modifier_counts.get(name, 0) + 1
            if brace_depth <= 0:
                in_view_extension = False

    return type_paths, view_modifier_paths, function_paths, view_modifier_counts, function_counts


def parse_parity_notes() -> tuple[dict[str, str], dict[str, str]]:
    text = PARITY_REF.read_text()
    view_notes: dict[str, str] = {}
    modifier_notes: dict[str, str] = {}
    section = None

    for line in text.splitlines():
        if line.startswith("## Views"):
            section = "views"
            continue
        if line.startswith("## Modifiers"):
            section = "modifiers"
            continue
        if line.startswith("## ") and not line.startswith("## Views") and not line.startswith("## Modifiers"):
            section = None
            continue
        if section is None or not line.startswith("|"):
            continue

        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if not cells or is_table_separator(cells[0]):
            continue

        if section == "views":
            if cells[0] in {"View", "Feature", "Category"}:
                continue
            name = clean_cell(cells[0])
            notes = clean_cell(cells[-1]) if clean_cell(cells[-1]) else "-"
            if notes and notes != "-":
                view_notes[name] = notes
        elif section == "modifiers":
            if cells[0] in {"Modifier", "Feature", "Category"}:
                continue
            name = clean_cell(cells[0]).lstrip(".")
            name = name.split("(")[0].strip()
            notes = clean_cell(cells[-1]) if clean_cell(cells[-1]) else "-"
            if notes and notes != "-":
                modifier_notes[name] = notes

    return view_notes, modifier_notes


def feature_origin(name: str, in_curated: bool, in_generated: bool) -> str:
    if in_curated and in_generated:
        return "Both"
    if in_curated:
        return "Curated only"
    if in_generated:
        return "Generated only"
    return "Unknown"


def merge_notes(*values: str | None) -> str:
    notes = []
    for value in values:
        if value and value != "-" and value not in notes:
            notes.append(value)
    return " | ".join(notes) if notes else "-"


def resolve_swiftui_metadata(curated: CuratedInfo | None, generated: Feature | None) -> tuple[str, str, str]:
    if curated is not None:
        return curated.availability, curated.swiftui_status, curated.notes
    if generated is not None:
        return generated.availability, generated.swiftui_status, generated.notes
    return "-", "Current", "-"


def resolve_modifier_implementation(
    name: str,
    curated: CuratedInfo | None,
    generated: Feature | None,
    modifier_paths: dict[str, str],
    function_paths: dict[str, str],
    modifier_counts: dict[str, int],
    function_counts: dict[str, int],
) -> tuple[str, str, int | None]:
    canonical_reference_overloads = 0
    if curated and curated.reference_overloads > 0:
        canonical_reference_overloads = curated.reference_overloads
    elif generated and generated.reference_overloads:
        canonical_reference_overloads = generated.reference_overloads

    if name in modifier_paths:
        source_count = modifier_counts.get(name, 1)
        if canonical_reference_overloads and source_count < canonical_reference_overloads:
            return "Partial", modifier_paths[name], source_count
        return "Implemented", modifier_paths[name], source_count
    if name in function_paths:
        source_count = function_counts.get(name, 1)
        if canonical_reference_overloads and source_count < canonical_reference_overloads:
            return "Partial", function_paths[name], source_count
        return "Implemented", function_paths[name], source_count
    return "Missing", "-", None


def build_view_inventory(
    generated_views: dict[str, Feature],
    curated_view_groups: dict[str, set[str]],
    curated_view_info: dict[str, CuratedInfo],
    type_paths: dict[str, str],
    parity_notes: dict[str, str],
) -> tuple[dict[str, list[Feature]], list[Feature], list[Feature]]:
    grouped: dict[str, list[Feature]] = {group: [] for group in VIEW_GROUP_FILES if VIEW_GROUP_FILES[group] == "views.md"}
    adjacent: list[Feature] = []
    generated_only: list[Feature] = []

    curated_lookup = {
        name: group
        for group, names in curated_view_groups.items()
        for name in names
    }

    all_view_names = set(generated_views) | {
        name for names in curated_view_groups.values() for name in names
    }

    for name in sorted(all_view_names):
        generated = generated_views.get(name)
        group = curated_lookup.get(name)
        curated = curated_view_info.get(name)
        availability, swiftui_status, source_notes = resolve_swiftui_metadata(curated, generated)
        feature = Feature(
            name=name,
            availability=availability,
            swiftui_status=swiftui_status,
            origin=feature_origin(name, group is not None, generated is not None),
            implementation_status="Implemented" if name in type_paths else "Missing",
            evidence=type_paths.get(name, "-"),
            notes=merge_notes(source_notes, parity_notes.get(name)),
        )
        if name in ADJACENT_VIEW_NAMES or VIEW_GROUP_FILES.get(group or "") == "adjacent-apis.md":
            adjacent.append(feature)
        elif group in grouped:
            grouped[group].append(feature)
        elif generated is not None:
            generated_only.append(feature)
        else:
            adjacent.append(feature)

    grouped = {group: features for group, features in grouped.items() if features}
    return grouped, generated_only, adjacent


def build_modifier_inventory(
    generated_modifiers: dict[str, Feature],
    curated_modifier_groups: dict[str, set[str]],
    curated_modifier_info: dict[str, CuratedInfo],
    modifier_paths: dict[str, str],
    function_paths: dict[str, str],
    modifier_counts: dict[str, int],
    function_counts: dict[str, int],
    parity_notes: dict[str, str],
) -> tuple[dict[str, list[Feature]], dict[str, list[Feature]], list[Feature]]:
    grouped: dict[str, list[Feature]] = {}
    generated_only_buckets: dict[str, list[Feature]] = {label: [] for label, _ in MODIFIER_GENERATED_BUCKETS}
    adjacent: list[Feature] = []

    curated_lookup = {
        name: group
        for group, names in curated_modifier_groups.items()
        for name in names
    }

    curated_names = {name for names in curated_modifier_groups.values() for name in names}
    all_names = set(generated_modifiers) | curated_names

    for name in sorted(all_names):
        generated = generated_modifiers.get(name)
        group = curated_lookup.get(name)
        curated = curated_modifier_info.get(name)
        availability, swiftui_status, source_notes = resolve_swiftui_metadata(curated, generated)
        implementation_status, evidence, source_overloads = resolve_modifier_implementation(
            name,
            curated,
            generated,
            modifier_paths,
            function_paths,
            modifier_counts,
            function_counts,
        )
        partial_note = "-"
        canonical_reference_overloads = 0
        canonical_reference_label = "generated SwiftUI baseline"
        if curated and curated.reference_overloads > 0:
            canonical_reference_overloads = curated.reference_overloads
            canonical_reference_label = "curated reference families"
        elif generated and generated.reference_overloads:
            canonical_reference_overloads = generated.reference_overloads
            canonical_reference_label = "generated SwiftUI baseline overloads"

        if implementation_status == "Partial" and canonical_reference_overloads and source_overloads:
            partial_note = (
                f"Public surface exists, but only {source_overloads} overload(s) are present "
                f"vs {canonical_reference_overloads} in the {canonical_reference_label}."
            )
        feature = Feature(
            name=name,
            availability=availability,
            swiftui_status=swiftui_status,
            origin=feature_origin(name, group is not None, generated is not None),
            implementation_status=implementation_status,
            evidence=evidence,
            notes=merge_notes(source_notes, partial_note, parity_notes.get(name)),
            reference_overloads=canonical_reference_overloads or None,
            source_overloads=source_overloads,
        )

        if name in ADJACENT_MODIFIER_NAMES:
            adjacent.append(feature)
            continue

        file_name = MODIFIER_GROUP_FILES.get(group or "")
        if file_name:
            grouped.setdefault(file_name, []).append(feature)
            continue

        if generated is None:
            adjacent.append(feature)
            continue

        for label, predicate in MODIFIER_GENERATED_BUCKETS:
            if predicate(name):
                generated_only_buckets[label].append(feature)
                break

    return grouped, generated_only_buckets, adjacent


def markdown_table(features: list[Feature]) -> str:
    def esc(value: str) -> str:
        return value.replace("|", "\\|").replace("\n", " ").strip()

    lines = [
        "| Feature | Seen In | SwiftUI Availability | SwiftUI Status | SwiftOpenUI | Evidence | Notes |",
        "|---|---|---|---|---|---|---|",
    ]
    for feature in features:
        lines.append(
            f"| `{esc(feature.name)}` | {esc(feature.origin)} | {esc(feature.availability)} | {esc(feature.swiftui_status)} | {esc(feature.implementation_status)} | `{esc(feature.evidence)}` | {esc(feature.notes)} |"
        )
    return "\n".join(lines)


def summary_line(features: list[Feature]) -> str:
    implemented = sum(1 for feature in features if feature.implementation_status == "Implemented")
    partial = sum(1 for feature in features if feature.implementation_status == "Partial")
    missing = len(features) - implemented - partial
    return f"{len(features)} total, {implemented} implemented, {partial} partial, {missing} missing."


def write_file(path: Path, text: str) -> None:
    path.write_text(text.rstrip() + "\n")


def build_docs() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    curated_view_groups, curated_modifier_groups, curated_view_info, curated_modifier_info = parse_curated_reference()
    generated_views = parse_generated_views()
    generated_modifiers = parse_generated_modifiers()
    type_paths, modifier_paths, function_paths, modifier_counts, function_counts = extract_public_surface()
    parity_view_notes, parity_modifier_notes = parse_parity_notes()

    view_groups, generated_only_views, adjacent_views = build_view_inventory(
        generated_views,
        curated_view_groups,
        curated_view_info,
        type_paths,
        parity_view_notes,
    )
    modifier_groups, generated_only_modifiers, adjacent_modifiers = build_modifier_inventory(
        generated_modifiers,
        curated_modifier_groups,
        curated_modifier_info,
        modifier_paths,
        function_paths,
        modifier_counts,
        function_counts,
        parity_modifier_notes,
    )

    all_views = [feature for features in view_groups.values() for feature in features] + generated_only_views
    all_modifiers = [feature for features in modifier_groups.values() for feature in features]
    for bucket_features in generated_only_modifiers.values():
        all_modifiers.extend(bucket_features)

    readme = f"""# SwiftUI Implementation Tracker

Merged from:

- `docs/api/swiftui-reference-2025-clade.md`
- `docs/api/swiftui-reference-2025-codex.md`

Status is derived from the public SwiftOpenUI surface under `Sources/SwiftOpenUI/`.

Rules for this tracker:

- `Implemented` means SwiftOpenUI exposes a matching public type or `View` modifier today.
- `Partial` currently applies to modifier families: SwiftOpenUI exposes the base name, but only a subset of the curated canonical family set (or the generated baseline when no curated family count exists).
- `Missing` means no matching public surface exists yet.
- `Seen In` shows whether the feature came from the curated reference, the SDK-scan reference, or both.
- Curated grouping comes from `swiftui-reference-2025-clade.md`.
- Extra public surface found only by the SDK scan is split into separate generated-only files.
- View-adjacent and modifier-adjacent items that do not fit the direct `View` / `View`-modifier model are kept in `adjacent-apis.md`.
- When curated and generated metadata disagree, the curated reference is treated as canonical for availability, status, and human notes.
- This tracker is surface-first. Backend and behavioral parity still belong in `docs/architecture/swiftui-parity-matrix.md`.
- Views are still tracked at type presence level today; view-specific surface limitations stay in row notes until the tracker grows a reliable view-family metric.

Regenerate with:

- `python3 tools/build_feature_tracker.py`

## Coverage

- Views: {summary_line(all_views)}
- Modifiers: {summary_line(all_modifiers)}
- Adjacent APIs: {summary_line(adjacent_views + adjacent_modifiers)}

## Files

- `views.md`: curated view groups that map cleanly onto direct `View` types
- `views-generated-only.md`: SDK-scan-only public `View` types
- `modifiers-01-layout.md`
- `modifiers-02-appearance.md`
- `modifiers-03-text-symbol.md`
- `modifiers-04-style.md`
- `modifiers-05-graphics-rendering.md`
- `modifiers-06-navigation-auxiliary.md`
- `modifiers-07-presentation.md`
- `modifiers-08-input-events.md`
- `modifiers-09-search.md`
- `modifiers-10-accessibility.md`
- `modifiers-11-state-environment.md`
- `modifiers-generated-a-g.md`
- `modifiers-generated-h-p.md`
- `modifiers-generated-q-z.md`
- `adjacent-apis.md`
"""
    write_file(OUT_DIR / "README.md", readme)

    view_file_parts = [
        "# Views",
        "",
        f"Summary: {summary_line([feature for features in view_groups.values() for feature in features])}",
    ]
    for group in view_groups:
        features = sorted(view_groups[group], key=lambda feature: feature.name.lower())
        view_file_parts.extend(["", f"## {group}", "", summary_line(features), "", markdown_table(features)])
    write_file(OUT_DIR / "views.md", "\n".join(view_file_parts))

    generated_views_text = "\n".join(
        [
            "# Generated-Only Views",
            "",
            "Public `View` types found in the SDK-scan reference but not listed in the curated reference.",
            "",
            f"Summary: {summary_line(generated_only_views)}",
            "",
            markdown_table(sorted(generated_only_views, key=lambda feature: feature.name.lower())),
        ]
    )
    write_file(OUT_DIR / "views-generated-only.md", generated_views_text)

    modifier_titles = {
        "modifiers-01-layout.md": "Layout Modifiers",
        "modifiers-02-appearance.md": "Appearance Modifiers",
        "modifiers-03-text-symbol.md": "Text and Symbol Modifiers",
        "modifiers-04-style.md": "Style Modifiers",
        "modifiers-05-graphics-rendering.md": "Graphics and Rendering Modifiers",
        "modifiers-06-navigation-auxiliary.md": "Navigation and Auxiliary Modifiers",
        "modifiers-07-presentation.md": "Presentation Modifiers",
        "modifiers-08-input-events.md": "Input and Event Modifiers",
        "modifiers-09-search.md": "Search Modifiers",
        "modifiers-10-accessibility.md": "Accessibility Modifiers",
        "modifiers-11-state-environment.md": "State, Environment, and Deprecated Modifiers",
    }

    file_to_groups: dict[str, list[str]] = {}
    for group_name, file_name in MODIFIER_GROUP_FILES.items():
        file_to_groups.setdefault(file_name, []).append(group_name)

    for file_name, title in modifier_titles.items():
        group_names = file_to_groups[file_name]
        features = []
        for group_name in group_names:
            features.extend(
                feature for feature in modifier_groups.get(file_name, [])
                if curated_modifier_groups.get(group_name) and feature.name in curated_modifier_groups[group_name]
            )

        unique = {feature.name: feature for feature in features}
        ordered_features = sorted(unique.values(), key=lambda feature: feature.name.lower())

        parts = [f"# {title}", "", f"Summary: {summary_line(ordered_features)}"]
        for group_name in group_names:
            group_features = [
                unique[name]
                for name in sorted(curated_modifier_groups.get(group_name, []), key=str.lower)
                if name in unique
            ]
            if not group_features:
                continue
            parts.extend(["", f"## {group_name}", "", summary_line(group_features), "", markdown_table(group_features)])
        write_file(OUT_DIR / file_name, "\n".join(parts))

    for label, features in generated_only_modifiers.items():
        file_name = f"modifiers-generated-{label.lower().replace('-', '-')}.md"
        title = f"Generated-Only Modifiers ({label})"
        body = "\n".join(
            [
                f"# {title}",
                "",
                "Public `View` modifier names found in the SDK-scan reference but not listed in the curated reference.",
                "",
                f"Summary: {summary_line(features)}",
                "",
                markdown_table(sorted(features, key=lambda feature: feature.name.lower())),
            ]
        )
        write_file(OUT_DIR / file_name, body)

    adjacent_parts = [
        "# Adjacent APIs",
        "",
        "Items mentioned in the curated reference that do not fit cleanly into the direct `View` or `View`-modifier inventories.",
        "",
    ]
    if adjacent_views:
        adjacent_parts.extend(
            [
                "## View-Adjacent",
                "",
                summary_line(adjacent_views),
                "",
                markdown_table(sorted(adjacent_views, key=lambda feature: feature.name.lower())),
                "",
            ]
        )
    if adjacent_modifiers:
        adjacent_parts.extend(
            [
                "## Modifier-Adjacent",
                "",
                summary_line(adjacent_modifiers),
                "",
                markdown_table(sorted(adjacent_modifiers, key=lambda feature: feature.name.lower())),
                "",
            ]
        )
    write_file(OUT_DIR / "adjacent-apis.md", "\n".join(adjacent_parts))


if __name__ == "__main__":
    build_docs()
