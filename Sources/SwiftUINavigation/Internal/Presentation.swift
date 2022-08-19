struct Presentation<Enum, Case>: DynamicProperty {
  let `enum`: Binding<Enum?>
  let casePath: CasePath<Enum, Case>
  @State var proxy: Proxy

  init(enum: Binding<Enum?>, casePath: CasePath<Enum, Case>) {
    self.enum = `enum`
    self.casePath = casePath
    _proxy = .init(wrappedValue: Proxy(enum: `enum`, casePath: casePath))
  }

  func update() {
    self.proxy.enum = self.enum
    self.proxy.casePath = self.casePath
  }

  class Proxy: ObservableObject {
    @Published var `enum`: Binding<Enum?>
    @Published var casePath: CasePath<Enum, Case>

    init(enum: Binding<Enum?>, casePath: CasePath<Enum, Case>) {
      self.enum = `enum`
      self.casePath = casePath
    }

    var item: Binding<PresentationItem?> {
      Binding(
        get: { [`enum`, casePath] in
          `enum`.wrappedValue.flatMap {
            PresentationItem(destinations: $0, destination: casePath.extract(from:))
          }
        },
        set: { [`enum`, casePath] newValue, transaction in
          guard newValue == nil, `enum`.wrappedValue.flatMap(casePath.extract) != nil
          else { return }
          `enum`.transaction(transaction).wrappedValue = nil
        }
      )
    }
  }
}

struct WithPresentation<Enum, Case, Content: View>: View {
  let presentation: Presentation<Enum, Case>
  @ViewBuilder var content: (Presentation<Enum, Case>) -> Content

  init(
    enum: Binding<Enum?>,
    casePath: CasePath<Enum, Case>,
    @ViewBuilder content: @escaping (Presentation<Enum, Case>) -> Content
  ) {
    self.presentation = Presentation(enum: `enum`, casePath: casePath)
    self.content = content
  }

  var body: some View {
    RemoveDuplicates(enum: presentation.enum) {
      content(presentation)
    }
  }
}

struct RemoveDuplicates<Enum, Content: View>: View, Equatable {
  @Storage var wrappedValue: Enum?
  @ViewBuilder var content: () -> Content

  init(enum: Binding<Enum?>, content: @escaping () -> Content) {
    self.wrappedValue = `enum`.wrappedValue
    self.content = content
  }

  var body: some View {
    content()
  }

  @propertyWrapper
  struct Storage { var wrappedValue: Enum? }

  static func == (lhs: Self, rhs: Self) -> Bool {
    (lhs.wrappedValue != nil) == (rhs.wrappedValue != nil)
      && lhs.wrappedValue.flatMap(enumTag) == rhs.wrappedValue.flatMap(enumTag)
  }
}

struct IfLetPresentation<Enum, Case, Content: View>: View {
  @ObservedObject var proxy: Presentation<Enum, Case>.Proxy
  @ViewBuilder var content: (Binding<Case>) -> Content

  init(
    presentation: Presentation<Enum, Case>,
    content: @escaping (Binding<Case>) -> Content
  ) {
    self.proxy = presentation.proxy
    self.content = content
  }

  var body: some View {
    Binding(unwrapping: proxy.enum.case(proxy.casePath)).map(content)
  }
}

struct PresentationItem: Identifiable {
  struct ID: Hashable {
    let tag: UInt32?
    let discriminator: ObjectIdentifier
  }

  let id: ID

  init?<Destination, Destinations>(
    destinations: Destinations,
    destination toDestination: (Destinations) -> Destination?
  ) {
    guard let destination = toDestination(destinations) else { return nil }
    self.id = ID(
      tag: enumTag(destinations),
      discriminator: ObjectIdentifier(type(of: destination))
    )
  }
}
