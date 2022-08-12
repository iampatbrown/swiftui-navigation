import SwiftUI

struct IdentifiedBinding<Value>: Identifiable {
  let id: BindingIdentifier
  let base: Binding<Value>

  init(_ base: Binding<Value>, id: AnyHashable) {
    self.id = BindingIdentifier(Value.self, id: id)
    self.base = base
  }

  init?(unwrapping base: Binding<Value?>, id: AnyHashable) {
    guard let base = Binding(unwrapping: base)
    else { return nil }
    self.init(base, id: id)
  }

  init?<Enum>(
    unwrapping base: Binding<Enum?>,
    case casePath: CasePath<Enum, Value>
  ) {
    guard
      let `enum` = Binding(unwrapping: base),
      let `case` = Binding(unwrapping: `enum`, case: casePath)
    else { return nil }
    self.init(`case`, id: enumTag(`enum`.wrappedValue))
  }
}

struct BindingIdentifier: Hashable {
  let id: AnyHashable
  let discriminator: ObjectIdentifier

  init(_ type: Any.Type, id: AnyHashable) {
    self.id = id
    self.discriminator = ObjectIdentifier(type)
  }
}

extension Binding {
  func id<ID: Hashable, Wrapped>(_ id: ID) -> Binding<IdentifiedBinding<Wrapped>?>
  where Value == Wrapped? {
    .init(
      get: { IdentifiedBinding(unwrapping: self, id: id) },
      set: { newValue, transaction in
        self.transaction(transaction).wrappedValue = newValue?.base.wrappedValue
      }
    )
  }

  func id<Wrapped>(_ id: Any.Type) -> Binding<IdentifiedBinding<Wrapped>?>
  where Value == Wrapped? {
    .init(
      get: { IdentifiedBinding(unwrapping: self, id: ObjectIdentifier(id)) },
      set: { newValue, transaction in
        self.transaction(transaction).wrappedValue = newValue?.base.wrappedValue
      }
    )
  }

  func id<Enum, Case>(case casePath: CasePath<Enum, Case>) -> Binding<IdentifiedBinding<Case>?>
  where Value == Enum? {
    .init(
      get: { IdentifiedBinding(unwrapping: self, case: casePath) },
      set: { newValue, transaction in
        self.transaction(transaction).wrappedValue = newValue
          .map { casePath.embed($0.base.wrappedValue) }
      }
    )
  }
}
