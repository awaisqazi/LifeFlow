# Performance

## Keep View body Simple

As mentioned in the Data Essentials talk from wwdc, making any side effects, including dispatching, will slow down the view's creation, and might cause frame drops. Try to make the body function be a pure structural representation of the view's state, without any extra work or complicated logic.

```swift
// fine
class SomeSourceOfTruth: ObservableObject {
    @Published var items: [Item]
    func provideItemsSomehow() {
        let itemsFromSomewhere = ...
        let fixedItems = sortItemsInSomeComplicatedWay(itemsFromSomewhere)
        self.items = fixedItems
    }
}

// avoid
@State var items: [Item]
var body: some View {
    let fixedItems = sortItemsInSomeComplicatedWay(items)
    List(fixedItems) { ...
}
```

## Avoid Redundant View Updates

**Note:  When using Observation, this does not apply — when a property changes in an observed object, only a view which calls that specific property will be refreshed. However — if the object itself changes to a different instance — then the view refreshes even if it’s not using any property.**

When keeping a @State struct, any property changed inside it is causing a recreation of the view tree. This is the same with @StateObject and its @Published properties. In both cases SwiftUI knows that the struct or object changed, but not what changed.

**Note:** Add let _= Self._printChanges() in your body to ensure the view is only updated when you expect it to. Even if a parent view is updated, a child’s body should still not be called if the child dependencies and state didn’t change as a result of the parent's change.

To avoid unnecessary diffing of the view hierarchy, pass to views only what they need, and avoid big catch-all "buckets" of state (names with “Context”, “Config”, etc. can be code smell).

```swift
// fine
@StateObject var config = SomeConfig()
var body: some View {
  MyView($config.someValue) // assuming someValue is @Published
}

// avoid
@StateObject var config = SomeConfig()
var body: some View {
  MyView($config)
}
```

## Split State To Custom View Types

A View’s state should be as small as possible. This include any non POD values (“Plain Old Data”, or in SwiftUI case — simple let variables passed during init) like binding, environment, observed object, etc. This also includes holding some “config” or "context" value which itself holds multiple other values.

When a single view has a complex body, and is using multiple states/bindings/dependencies etc. the entire body will get re-evaluated when each of those values change.

However, if the view is using composition to split its body into multiple child views, when a value is changed, only the child’s using it will diff. But not their siblings.

When possible, split a complex view based on the usage of its values to avoid redundant diffing, and redundant rendering. Note that SwiftUI tries to be smart about this, and sometimes succeeds. Still sometimes, body can get unnecessarily called. Starting iOS 15, use _printChanges() to ensure the behavior is as you expect.

**Note**: Breaking parts of body into other computed vars or View extension doesn't help — because we are staying within the same state scope and don't break the body tree (ie, if we po body in the debugger, we will still see the full tree…)

```swift
// fine
struct BigView: View {
    @State query: String = ""
    @Binding user: User
    @Environment colorScheme: ColorScheme
    var body: some View {
        VStack {
            SearchBar($query)
            UserHeader(model: user)
            BottomBar(colorScheme)
        }
    }
}

// avoid
struct BigView: View {
    @State query: String = ""
    @Binding user: User
    @Environment colorScheme: ColorScheme
    var body: some View {
        VStack {
            HStack {
                Text("Search:")
                TextField(text: $query, onEditingChanged: { ... })
            }
            HStack {
                Image(user...)
                Text(user.name)
                Button(user.followingTitle)
                ...
            }
            ZStack {
                Button(...)
                    .tintColor(colorScheme.dark ? ...)
            }
        }
    }
}
```

## Utilize POD or Equality For Fast Diffing

Strive to have views that are simple to diff, or implement your own equality if you want to ignore a certain view dependency or state.

SwiftUI needs a way to compare 2 instances of each view, and determine wether they’re the same, or needs to be re-rendered. This is done either via a == function (if implemented), or reflection (which might check each property dynamically, or use memcmp for better performance). This is an implementation detail of the framework, and is subject to change, but it seems like as of now, POD types always use memcmp, unless == is forced via EquatableView (only implementing == is not enough for POD views!).

memcmp is likely the fastest option of the 3, followed by custom == (if done correctly), with full dynamic reflection of the views being last. To check if a view is POD, use _isPOD(FooView.self).

From the point of view of SwiftUI, the behavior might be explained as that implementing == doesn't force anything, it just helps to prevent a redraw on your terms, but the system might still decide to memcmp for performance reasons. To force usage of your ==, wrap the view in EquatableView.

I'll create a markdown table based on the Swift view comparison image:

## POD View Behavior

|      Feature    |  As-is  | Wrapped in EquatableView |
|-----------------|---------|--------------------------|
| memcmp          | ✓       | —                        |
| Equality ("==") | Ignored | ✓                        |
| Reflection      | Never   | Never                    |

**Note:** POD View always uses `memcmp` unless wrapped in `EquatableView`

## Non-POD View Behavior

| Feature         | As-is | Wrapped in EquatableView |
|-----------------|-------|--------------------------|
| memcmp          | Never | Never                    |
| Equality ("==") | ✓     | ✓ (redundant)            |
| Reflection      | ✓     | —                        |

**Note:** Non-POD View always uses reflection unless it’s Equatable

**Note: Be cautious with custom equality — if you ever add a new state or dependency to your view, you will have to remember to also check it in your == func!**

In certain scenarios you might have an expensive view that is not POD, and you want to avoid calling body (diffing) unnecessarily. A way to "trick" SwiftUI and avoid custom equality is to wrap that view in a parent view that is POD, keeping state in the internal view. For example:

```swift
// Instead this:
struct ExpensiveView: View {
  let value: Int
  @State private var item: Item?
  var body: some View { ... }
}

// Consider:
struct ExpensiveView: View {
  let value: Int
  var body: some View { ExpensiveViewInternal(value: value) }
}

private struct ExpensiveViewInternal: View {
  let value: Int
  @State private var item: Item?
  var body: some View { ... }
}
```

**Note: There seems to be a difference in behavior between iOS 14 and 15, where iOS 15 is better at avoiding redraw. This post on Swift Forums provides more context and asking for information.**

## Don’t Pass .indices to ForEach and List

Using indices to avoid making your model conform to Identifiable also changes ForEach from displaying dynamic content to static content. For example, removing an element from the list being iterated over, might crash. Docs: developer.apple.com/documentation/swiftui/foreach/3364099-init

**Note: Apple Docs for ForEach.init(_:content:): “The instance only reads the initial value of the provided data and doesn’t need to identify views across updates. To compute views on demand over a dynamic range, use ForEach.init(_:id:content:).”**

```swift
// fine
extension User: Identifiable { ... }

... in some body
LazyVStack {
    ForEach(users) { 
        content(user: $0)
        ...

// also fine
ForEach(users, id: \.userId) {
    content(user: $0)

// avoid
ForEach(users.indices) {
    content(user: users[$0])
```

## Avoid Keeping View Closures

This one is from the following blog post: Don't use escaping closures in SwiftUI

When writing a view that accepts another view closure as content, prefer to evaluate the closure that returns the view immediately and store the content in the view, instead of keeping a reference to the closure (ie, making it escaping) and only evaluate it when in the body.

Note that unlike a class reference, Swift won’t necessarily know that passing “the same” closure to a view is actually the same for diffing purposes. Closures don’t guarantee stable equality like 2 equal references to a certain object instance do.

```swift
// fine
struct SomeView<Content: View>: View {
  let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }
}

// avoid
struct SomeView<Content: View>: View {
  let content: () -> Content

  init(@ViewBuilder content: @escaping () -> Content) {
    self.content = content
  }
}
```