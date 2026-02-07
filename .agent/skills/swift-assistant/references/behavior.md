# Behavior

Principles that keep SwiftUI views doing what you intend.

## Prefer No Effect Modifiers over Conditional Views

Examples:

1. Prefer .opacity over conditionally including a view:

```swift
// fine
SomeView()
    .opacity(foo ? 1 : 0)

// avoid
if foo {
    SomeView()
}
```

```swift

```

2. Prefer “breaking” a modifier over a condition to include it:

```swift
// fine
SomeView()
    .matchedGeometryEffect(id: "id", in: ns, properties: matchTop ? .top : []])

if matchTop {
    SomeView()
        .matchedGeometryEffect(id: "id", in: ns, properties: .top)
} else {
    SomeView()
}
```

Here is what Raj Ramamurthy said towards the end of Demystify SwiftUI WWDC talk:

“Branches are great, and they exist in SwiftUI for a reason. But when used unnecessarily, they can cause poor performance, surprising animations, and […] even loss of state.

When you introduce a branch, pause for a second and consider whether you're representing multiple views or two states of the same view.”

## State and dependencies

Make sure to declare objects created inside the view as @StateObject, to avoid having them being re-created many times, slowing down view update lifecycle, as well as resetting their state.

When using Observation, state (value created inside the view) is always @State. Objects passed to the view, are usually simply let. @Bindable is only used when the view changes the object.

```swift
// fine
@StateObject private var data = Data() // created here
@ObservedObject var user: User // passed from somewhere

// fine (Observation)
@State private var data = Data() // created here
let user: User // passed from somewhere
@Bindable var user: User // passed and changed here

// avoid
@ObservedObject var data = DataProvider()
```

## Don't Declare Passed Values as @State or @StateObject

When declaring a state or state object, the value you provide is only an initial value. It will not stay the value for newer version of the view — those will reuse the existing value from before — injected to them from the SwiftUI framework. In fact — that's the point of state and state object — to retain your state between view updates.

This behavior also applies if you pass a value to a child view from a parent view, and the child declares this value as state or state object. What will happen is that the child will accept the initial value passed to it by the parent, but will ignore any future values passed to it.

If a view in your app is not getting updated — check to see if you declared your passed values as state or state object.

The correct declaration is also the easiest one — a simple let. If you need to mutate a struct or primitive, or change an object, use @Bindable or @ObservedObject respectively.

See also State is Private below to easily prevent this bug from ever happening.

See Declaring View Properties for how to correctly declare values in your Views.

```swift
// fine
struct ChildView: View {
  let item: Item // if passed from parent
  @Binding var item: Item // if mutated by child
  @ObservedObject var item: ItemObject // if changed by child
}

// avoid
struct ParentView: View {
  var body: some View {
    ChildView(item: item)
  }
}

struct ChildView: View {
  @State var item: Item
  ...
}
```

## Avoid Nested @ObservableObject

**Note: When using @Observable objects, this does not apply — the Observation framework fully supports any level of nesting observed (or non observed) objects.**

Sometimes we might find ourselves in a situation where we want to observe some ObservableObject. (Either via @StateObject, or some other published object like @EnvironmentObject, @ObservedObject), and that object is itself holding some other ObservableObject as a @Published variable. SwiftUI does not support this case — if the nested object changes, our view will not get notified, and won't be updated. There is a possible workaround, done via listening to the objectWillChange publisher of the nested object, and proxying it to the parent object:

```swift
// avoid
class MainThing: ObservableObject {
    @Published var element : SomeElement
    var cancellable : AnyCancellable?
    init(element : SomeElement) {
        self.element = element
        self.cancellable = self.element.$value.sink(
            receiveValue: { [weak self] _ in
                self?.objectWillChange.send()
            }
        )
    }
}
```

**Source: <https://rhonabwy.com/2021/02/13/nested-observable-objects-in-swiftui/>**

Other than being a hack, this also breaks SwiftUI. Since SwiftUI tracks changes itself, this breaks the chain by ending it (.sink{…}) and the publishing another, separate change  (.send()), and SwiftUI can't connect the two. In practice, this means that for example, animations are broken. For example, this change will not be animated even though we say it should:

```swift
// avoid
@StateObject var thing = MainThing()
// somewhere...
withAnimation {
    thing.element.blah = false
}
```

Sure, we can even workaround that, by adding withAnimation { … } inside the sink:

```swift
// avoid
self.cancellable = self.element.$value.sink(
    receiveValue: { [weak self] _ in
        withAnimation {
            self?.objectWillChange.send()
        }
    }
)
```

Othan than being an even hackier hack, this still doesn’t fully fix the issue because the original animation call might not use the default animation value.

The lesson here, is that this becomes ugly and broken very fast, likely in more ways than just animations, and the real solution would be to find ways to design the UI structure in such way that we won’t need a nested observable object in the first place. For the simple case, this means that the view should access the internal object directly (SomeElement in this example).

```swift
// fine
struct MainView: View {
    @StateObject private var thing = MainThing()
    var body: some View {
        MyView(element: thing.element)
    }
}

struct MyView: View {
    @ObservedObject var element: SomeElement

    // somewhere...
    withAnimation {
        element.blah = false
    }
}
```
