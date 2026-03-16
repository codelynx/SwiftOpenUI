# Issue: `ObservableObject` / `Published` namespace conflict on macOS

## Problem

SwiftOpenUI defines its own `ObservableObject` protocol and `Published` property wrapper for platforms where Combine is unavailable (Linux, Windows). On macOS, Foundation re-exports these same names as typealiases to Combine's implementations:

```
Foundation.ObservableObject → Combine.ObservableObject
Foundation.Published        → Combine.Published
```

Any code that imports both `SwiftOpenUI` and Foundation (implicit) gets ambiguity errors:

```swift
// error: 'ObservableObject' is ambiguous for type lookup in this context
class MyModel: ObservableObject {
    @Published var count = 0  // error: 'Published' is ambiguous
}
```

## Scope

- **Affected files in tests:** `StateTests.swift`, `ModifierTests.swift` — requires `SwiftOpenUI.ObservableObject` / `SwiftOpenUI.Published` disambiguation
- **NOT affected:** Example apps — they use `import SwiftUI` on macOS (not `import SwiftOpenUI`)
- **NOT affected:** Linux/Windows builds — no Combine, no conflict

## Current workaround

Tests use explicit module-qualified names:

```swift
class Counter: SwiftOpenUI.ObservableObject {
    @SwiftOpenUI.Published var count = 0
}
```

## Why a simple `#if` gate doesn't work

The observable stack is tightly coupled:

```
ObservableObject (protocol)
  └─ Published (property wrapper) → conforms to AnyPublishedProvider
       └─ PublishedStorage → conforms to AnyPublishedStorage
            └─ wirePublished() — walks Mirror to find AnyPublishedProvider children

ObservedObject / StateObject / EnvironmentObject
  └─ all constrain on ObservableObject
  └─ all use AnyPublishedProvider / wirePublished() for rebuild wiring
```

Gating just the two conflicting types (`ObservableObject`, `Published`) with `#if !canImport(Combine)` breaks the chain — Combine's `Published` doesn't conform to `AnyPublishedProvider`, so the wiring code can't observe property changes.

## Options to resolve

### Option A: Gate the entire observable stack (recommended for clean separation)

Wrap everything in `ObservableObject.swift` with `#if !canImport(Combine)`:

```swift
#if canImport(Combine)
import Combine
// On Apple platforms, ObservableObject/Published come from Combine.
// ObservedObject/StateObject/EnvironmentObject come from SwiftUI.
// SwiftOpenUI's custom implementations are not needed.
#else
// Full custom implementation for Linux/Windows
public protocol ObservableObject: AnyObject {}
@propertyWrapper public struct Published<Value>: AnyPublishedProvider { ... }
public struct ObservedObject<ObjectType: ObservableObject> { ... }
// ... etc
#endif
```

**Trade-off:** Observable-related tests only run on Linux/Windows (where they matter). On macOS, Combine/SwiftUI provides the real implementations. The rest of the core framework still compiles on macOS because `EnvironmentModifiers.swift` and `Environment.swift` only use `ObservableObject` as a type constraint — Combine's version satisfies that.

### Option B: Keep current approach (explicit module prefix)

Minimal change. Only 6 occurrences in 2 test files. Tests verify SwiftOpenUI's implementation on all platforms including macOS.

### Option C: Rename SwiftOpenUI's types

Use different names (e.g. `OpenObservableObject`, `OpenPublished`). Breaks the goal of SwiftUI API compatibility.

## Recommendation

Option A is the cleanest architecturally — SwiftOpenUI's custom observable stack exists specifically for platforms without Combine. On macOS, it's redundant. Gating it out eliminates the conflict entirely and aligns with the project's design: on macOS, use real SwiftUI.

The core framework types (`EnvironmentObjectModifierView`, `EnvironmentValues.setObject/getObject`) use `ObservableObject` only as a generic constraint, which Combine's protocol satisfies. These continue to compile on macOS without changes.
