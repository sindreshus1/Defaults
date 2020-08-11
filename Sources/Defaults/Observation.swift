import Foundation

public protocol DefaultsObservation: AnyObject {
	func invalidate()

	/**
	Keep this observation alive for as long as, and no longer than, another object exists.

	```
	Defaults.observe(.xyz) { [unowned self] change in
		self.xyz = change.newValue
	}.tieToLifetime(of: self)
	```
	*/
	@discardableResult
	func tieToLifetime(of weaklyHeldObject: AnyObject) -> Self

	/**
	Break the lifetime tie created by `tieToLifetime(of:)`, if one exists.

	- Postcondition: The effects of any call to `tieToLifetime(of:)` are reversed.
	- Note: If the tied-to object has already died, then self is considered to be invalidated, and this method has no logical effect.
	*/
	func removeLifetimeTie()
}

extension Defaults {
	public typealias Observation = DefaultsObservation

	public enum ObservationOption {
		/// Whether a notification should be sent to the observer immediately, before the observer registration method even returns.
		case initial

		/// Whether separate notifications should be sent to the observer before and after each change, instead of a single notification after the change.
		case prior
	}

	public typealias ObservationOptions = Set<ObservationOption>

	private static func deserialize<Value: Decodable>(_ value: Any?, to type: Value.Type) -> Value? {
		guard
			let value = value,
			!(value is NSNull)
		else {
			return nil
		}

		// This handles the case where the value was a plist value using `isNativelySupportedType`
		if let value = value as? Value {
			return value
		}

		// Using the array trick as done below in `UserDefaults#_set()`
		return [Value].init(jsonString: "\([value])")?.first
	}

	@available(iOS 11.0, macOS 10.13, tvOS 11.0, watchOS 4.0, iOSApplicationExtension 11.0, macOSApplicationExtension 10.13, tvOSApplicationExtension 11.0, watchOSApplicationExtension 4.0, *)
	private static func deserialize<Value: NSSecureCoding>(_ value: Any?, to type: Value.Type) -> Value? {
		guard
			let value = value,
			!(value is NSNull)
		else {
			return nil
		}

		// This handles the case where the value was a plist value using `isNativelySupportedType`
		if let value = value as? Value {
			return value
		}

		guard let dataValue = value as? Data else {
			return nil
		}

		return try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(dataValue) as? Value
	}

	struct BaseChange {
		let kind: NSKeyValueChange
		let indexes: IndexSet?
		let isPrior: Bool
		let newValue: Any?
		let oldValue: Any?

		init(change: [NSKeyValueChangeKey: Any]) {
			kind = NSKeyValueChange(rawValue: change[.kindKey] as! UInt)!
			indexes = change[.indexesKey] as? IndexSet
			isPrior = change[.notificationIsPriorKey] as? Bool ?? false
			oldValue = change[.oldKey]
			newValue = change[.newKey]
		}
	}

	public struct KeyChange<Value: Codable> {
		public let kind: NSKeyValueChange
		public let indexes: IndexSet?
		public let isPrior: Bool
		public let newValue: Value
		public let oldValue: Value

		init(change: BaseChange, defaultValue: Value) {
			self.kind = change.kind
			self.indexes = change.indexes
			self.isPrior = change.isPrior
			self.oldValue = deserialize(change.oldValue, to: Value.self) ?? defaultValue
			self.newValue = deserialize(change.newValue, to: Value.self) ?? defaultValue
		}
	}

	@available(iOS 11.0, macOS 10.13, tvOS 11.0, watchOS 4.0, iOSApplicationExtension 11.0, macOSApplicationExtension 10.13, tvOSApplicationExtension 11.0, watchOSApplicationExtension 4.0, *)
	public struct NSSecureCodingKeyChange<Value: NSSecureCoding> {
		public let kind: NSKeyValueChange
		public let indexes: IndexSet?
		public let isPrior: Bool
		public let newValue: Value
		public let oldValue: Value

		init(change: BaseChange, defaultValue: Value) {
			self.kind = change.kind
			self.indexes = change.indexes
			self.isPrior = change.isPrior
			self.oldValue = deserialize(change.oldValue, to: Value.self) ?? defaultValue
			self.newValue = deserialize(change.newValue, to: Value.self) ?? defaultValue
		}
	}

	@available(iOS 11.0, macOS 10.13, tvOS 11.0, watchOS 4.0, iOSApplicationExtension 11.0, macOSApplicationExtension 10.13, tvOSApplicationExtension 11.0, watchOSApplicationExtension 4.0, *)
	public struct NSSecureCodingOptionalKeyChange<Value: NSSecureCoding> {
		public let kind: NSKeyValueChange
		public let indexes: IndexSet?
		public let isPrior: Bool
		public let newValue: Value?
		public let oldValue: Value?

		init(change: BaseChange) {
			self.kind = change.kind
			self.indexes = change.indexes
			self.isPrior = change.isPrior
			self.oldValue = deserialize(change.oldValue, to: Value.self)
			self.newValue = deserialize(change.newValue, to: Value.self)
		}
	}
	
	private static var preventPropagationThreadDictKey: String {
		"\(type(of: Observation.self))_threadUpdatingValuesFlag"
	}
	
	/**
	Execute block without triggering events of changes made at defaults keys.
	
	Example:
	```
	let observer = Defaults.observe(keys: .key1, .key2) {
		// …
		Defaults.withoutPropagation {
			// update some value at .key1
			// this will not be propagated
			Defaults[.key1] = 11
		}
		// this will be propagated
		Defaults[.someKey] = true
	}
	```
	
	This only works with defaults `observe` or `publisher`. User made KVO will not be affected.
	*/
	public static func withoutPropagation(block: () -> Void) {
		// How does it work?
		// KVO observation callbacks are executed right after change is made,
		// and run on the same thread as the caller. So it works by storing a flag in current
		// thread's dictionary, which is then evaluated in `observeValue` callback
		
		let key = preventPropagationThreadDictKey
		Thread.current.threadDictionary[key] = true
		block()
		Thread.current.threadDictionary[key] = false
	}

	final class UserDefaultsKeyObservation: NSObject, Observation {
		typealias Callback = (BaseChange) -> Void

		private weak var object: UserDefaults?
		private let key: String
		private let callback: Callback

		init(object: UserDefaults, key: String, callback: @escaping Callback) {
			self.object = object
			self.key = key
			self.callback = callback
		}

		deinit {
			invalidate()
		}

		func start(options: ObservationOptions) {
			object?.addObserver(self, forKeyPath: key, options: options.toNSKeyValueObservingOptions, context: nil)
		}

		public func invalidate() {
			object?.removeObserver(self, forKeyPath: key, context: nil)
			object = nil
			lifetimeAssociation?.cancel()
		}

		private var lifetimeAssociation: LifetimeAssociation? = nil

		public func tieToLifetime(of weaklyHeldObject: AnyObject) -> Self {
			lifetimeAssociation = LifetimeAssociation(of: self, with: weaklyHeldObject, deinitHandler: { [weak self] in
				self?.invalidate()
			})

			return self
		}

		public func removeLifetimeTie() {
			lifetimeAssociation?.cancel()
		}

		// swiftlint:disable:next block_based_kvo
		override func observeValue(
			forKeyPath keyPath: String?,
			of object: Any?,
			change: [NSKeyValueChangeKey: Any]?, // swiftlint:disable:this discouraged_optional_collection
			context: UnsafeMutableRawPointer?
		) {
			guard let selfObject = self.object else {
				invalidate()
				return
			}

			guard
				selfObject == object as? NSObject,
				let change = change
			else {
				return
			}
			
			let key = preventPropagationThreadDictKey
			let updatingValuesFlag = (Thread.current.threadDictionary[key] as? Bool) ?? false
			guard !updatingValuesFlag else {
				return
			}

			callback(BaseChange(change: change))
		}
	}
	
	private final class CompositeUserDefaultsKeyObservation: NSObject, Observation {
		private static var observationContext = 0
		
		private final class SuiteKeyPair {
			weak var suite: UserDefaults?
			let key: String
			
			init(suite: UserDefaults, key: String) {
				self.suite = suite
				self.key = key
			}
		}
		
		private var observables: [SuiteKeyPair]
		private var lifetimeAssociation: LifetimeAssociation? = nil
		private let callback: UserDefaultsKeyObservation.Callback
		
		init(observables: [(suite: UserDefaults, key: String)], callback: @escaping UserDefaultsKeyObservation.Callback) {
			self.observables = observables.map { SuiteKeyPair(suite: $0.suite, key: $0.key) }
			self.callback = callback
			super.init()
		}
		
		deinit {
			invalidate()
		}
		
		public func start(options: ObservationOptions) {
			for observable in observables {
				observable.suite?.addObserver(
					self,
					forKeyPath: observable.key,
					options: options.toNSKeyValueObservingOptions,
					context: &type(of: self).observationContext
				)
			}
		}
		
		public func invalidate() {
			for observable in observables {
				observable.suite?.removeObserver(self, forKeyPath: observable.key, context: &type(of: self).observationContext)
				observable.suite = nil
			}

			lifetimeAssociation?.cancel()
		}
		
		public func tieToLifetime(of weaklyHeldObject: AnyObject) -> Self {
			lifetimeAssociation = LifetimeAssociation(of: self, with: weaklyHeldObject, deinitHandler: { [weak self] in
				self?.invalidate()
			})
			
			return self
		}

		public func removeLifetimeTie() {
			lifetimeAssociation?.cancel()
		}
		
		// swiftlint:disable:next block_based_kvo
		override func observeValue(
			forKeyPath keyPath: String?,
			of object: Any?,
			change: [NSKeyValueChangeKey: Any]?, // swiftlint:disable:this discouraged_optional_collection
			context: UnsafeMutableRawPointer?
		) {
			guard
				context == &type(of: self).observationContext
			else {
				super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
				return
			}
			
			guard
				object is UserDefaults,
				let change = change
			else {
				return
			}
			
			let key = preventPropagationThreadDictKey
			let updatingValuesFlag = (Thread.current.threadDictionary[key] as? Bool) ?? false
			if updatingValuesFlag {
				return
			}
				
			callback(BaseChange(change: change))
		}
	}
	
	/**
	Observe a defaults key.

	```
	extension Defaults.Keys {
		static let isUnicornMode = Key<Bool>("isUnicornMode", default: false)
	}

	let observer = Defaults.observe(.isUnicornMode) { change in
		print(change.newValue)
		//=> false
	}
	```
	*/
	public static func observe<Value: Codable>(
		_ key: Key<Value>,
		options: ObservationOptions = [.initial],
		handler: @escaping (KeyChange<Value>) -> Void
	) -> Observation {
		let observation = UserDefaultsKeyObservation(object: key.suite, key: key.name) { change in
			handler(
				KeyChange(change: change, defaultValue: key.defaultValue)
			)
		}
		observation.start(options: options)
		return observation
	}

	/**
	Observe a defaults key.
	*/
	@available(iOS 11.0, macOS 10.13, tvOS 11.0, watchOS 4.0, iOSApplicationExtension 11.0, macOSApplicationExtension 10.13, tvOSApplicationExtension 11.0, watchOSApplicationExtension 4.0, *)
	public static func observe<Value: NSSecureCoding>(
		_ key: NSSecureCodingKey<Value>,
		options: ObservationOptions = [.initial],
		handler: @escaping (NSSecureCodingKeyChange<Value>) -> Void
	) -> Observation {
		let observation = UserDefaultsKeyObservation(object: key.suite, key: key.name) { change in
			handler(
				NSSecureCodingKeyChange(change: change, defaultValue: key.defaultValue)
			)
		}
		observation.start(options: options)
		return observation
	}

	/**
	Observe an optional defaults key.
	*/
	@available(iOS 11.0, macOS 10.13, tvOS 11.0, watchOS 4.0, iOSApplicationExtension 11.0, macOSApplicationExtension 10.13, tvOSApplicationExtension 11.0, watchOSApplicationExtension 4.0, *)
	public static func observe<Value: NSSecureCoding>(
		_ key: NSSecureCodingOptionalKey<Value>,
		options: ObservationOptions = [.initial],
		handler: @escaping (NSSecureCodingOptionalKeyChange<Value>) -> Void
	) -> Observation {
		let observation = UserDefaultsKeyObservation(object: key.suite, key: key.name) { change in
			handler(
				NSSecureCodingOptionalKeyChange(change: change)
			)
		}
		observation.start(options: options)
		return observation
	}
	
	/**
	Observe multiple keys of any type, but without specific information about changes.
	
	```
	extension Defaults.Keys {
		static let setting1 = Key<Bool>("setting1", default: false)
		static let setting2 = Key<Bool>("setting2", default: true)
	}

	let observer = Defaults.observe(keys: .setting1, .setting2) {
		//...
	}
	```
	*/
	public static func observe(
		keys: Keys...,
		options: ObservationOptions = [.initial],
		handler: @escaping () -> Void
	) -> Observation {
		let pairs = keys.map {
			(suite: $0.suite, key: $0.name)
		}
		let compositeObservation = CompositeUserDefaultsKeyObservation(observables: pairs) { _ in
			handler()
		}
		compositeObservation.start(options: options)
		
		return compositeObservation
	}
}

extension Defaults.ObservationOptions {
	var toNSKeyValueObservingOptions: NSKeyValueObservingOptions {
		var options: NSKeyValueObservingOptions = [.old, .new]

		if contains(.initial) {
			options.insert(.initial)
		} else if contains(.prior) {
			options.insert(.prior)
		}

		return options
	}
}
