# Structure

## State is Private

When adding properties to a view, they might be created by the view (State, constants, AppStorage etc.) or be dependencies (Binding, let, ObservedObject). Everything that is not passed to the view from above, should be private. Environment is a special case since it is a dependency, but is injected by the framework, and therefore can be private as well.

This makes it clear what external data the view depends on, versus what it creates by itself, and makes code auto completion of the generated initializer more accurate.

```swift
// prefer
@State private var item = Item()
@StateObject private var object = Object()
@AppStorage("someFlag") private var flag = false
@Environment(\.timeZone) private var timezone: TimeZone
@EnvironmentObject private var data: DataProvider
```

## Avoid Single Use Constants

As much as possible, we aim to align with SwiftUI’s framework design of declarative, easy to read "top-down” UI structure and layout. This means that overall we try to inline things as long as we keep DRY, as well as layout and logic separation. For constants — "magic numbers" — this entails inlining them within the view's structure code (body or wherever it is used). This is unlike patterns like inner Constants struct, common in UIKit.

When the same value is used in multiple places within a view, we either use a PreferenceKey if it makes sense (for example, when determining between 2 values based on given geometry), or a Constants struct like before. This pattern also aligns with ComponentKit — a "battle proven" declarative UI framework for iOS.

## Generic Dependency Injection

Views should lack any app/domain-specific knowledge. A view can have an extension, with convenience initializer, which injects any needed app/domain specific values/objects in a generic way.

For example, a view which presents a list of items from a provider object, shouldn’t know how the provider is constructed or it’s dependencies:

```swift
// fine
struct SomeFeed: View {
    @ObservedObject data: FeedProvider
    var body: some View {
        List(data.items) { ...
    }
}

// somewhere...
SomeFeed(data: FeedProvider(appAuth, cache))

// avoid
struct SomeFeed: View {
    @ObservedObject var appAuth: AppAuth
    @ObservedObject var cache: DiskStorage
    @StateObject var data = FeedProvider()
    var body: some View {
        List(data.items) { ... }
            .onAppear {
                data.auth = appAuth
                data.diskStorage = cache
            }
    }
```

## Generic Rendering (Context Agnostic Layout)

Views should be able to be rendered in any context (inside another screen, as full cover modal, pushed in navigation, as a tab in tab bar, etc.). This means you should never use something like device screen for determining size. Instead — use and manipulate the given space. You can add Spacer() to fill in "gaps”, read the offered bounds with GeometryReader, etc.

```swift
// fine
GeometryReader { geometry in
    List(someItems) { item in
        SomeItem(item)
            .frame(height: geometry.size.height)
        }
    }
}

// avoid
List(someItems) { item in
    SomeItem(item)
        .frame(height: UIScreen.main.bounds.height)
}
```

## Relative Layout Over Constants

Many times we use constants to align the layout with the design to be “pixel-perfect”, but the design is presenting a single screen, on a single device, in a single scenario. It doesn’t include different screens sizes, orientation, and state (eg, active phone call status bar on iPhone SE). Where possible, layout adjustments (for example, setting offset of views, or “nudging” them in some direction) should be done based on a calculation of the dynamic layout, and not a “magic number”.

For example, offset for a view under the navigation bar should read and use its size instead of hardcoding the common value of 44. GeometryReader and AnchorPreferences provide the needed info at runtime.

## Containers and Content

Custom views should own their "container" view if it’s a static list (Stack, Form, List), but not if it's lazy or repeatable (LazyStack, List with data, LazyGrid, ForEach).

```swift
// fine
struct SomeHeader: some View {
    var body: some View {
        ZStack {
            SomeView(..)
            Button(..)
        }
    }
}

// avoid
struct SomeHeader: some View {
    var body: some View {
        SomeView(..)
        Button(..)
    }
}

// ...later
ZStack {
    SomeHeader()
}
```

## Break layout and functionality

The body of a view should only reference a method to act on an event, not the logic of it.

```swift
// fine
Button("Publish Project", action: handlePublish)

// avoid
Button("Publish Project") {
    showingLoading = true
    apiService.publish(project) {
        if case .error = $0 { showingError = true }
        showingLoading = false
    }
}
```