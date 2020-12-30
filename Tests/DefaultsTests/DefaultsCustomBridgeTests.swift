import Foundation
import Defaults
import XCTest

final class User: Defaults.Serializable, Equatable {
	var username: String
	var password: String

	init(username: String, password: String) {
		self.username = username
		self.password = password
	}

	static func == (lhs: User, rhs: User) -> Bool {
		lhs.username == rhs.username && lhs.password == rhs.password
	}

	public static var bridge: DefaultsUserBridge { return DefaultsUserBridge() }
}

final class DefaultsUserBridge: Defaults.Bridge {
	public func serialize(_ value: User?) -> [String: String]? {
		return ["username": value?.username ?? "", "password": value?.password ?? ""]
	}

	public func deserialize(_ object: [String: String]?) -> User? {
		guard let object = object else {
			return nil
		}
		return User(username: object["username"] ?? "", password: object["password"] ?? "")
	}
}

private let fixtureCustomBridge = User(username: "hank121314", password: "123456")

extension Defaults.Keys {
	static let customBridge = Key<User>("customBridge", default: fixtureCustomBridge)
	static let customBridgeArray = Key<[User]>("array_customBridge", default: [fixtureCustomBridge])
	static let customBridgeDictionary = Key<[String: User]>("dictionary_customBridge", default: ["0": fixtureCustomBridge])
}


final class DefaultsCustomBridge: XCTestCase {
	override func setUp() {
		super.setUp()
		Defaults.removeAll()
	}

	override func tearDown() {
		super.setUp()
		Defaults.removeAll()
	}

	func testKey() {
		let key = Defaults.Key<User>("independentCustomBridgeKey", default: fixtureCustomBridge)
		XCTAssertEqual(Defaults[key], fixtureCustomBridge)
		let newUser = User(username: "sindresorhus", password: "123456789")
		Defaults[key] = newUser
		XCTAssertEqual(Defaults[key], newUser)
	}

	func testOptionalKey() {
		let key = Defaults.Key<User?>("independentCustomBridgeOptionalKey")
		XCTAssertNil(Defaults[key])
		Defaults[key] = fixtureCustomBridge
		XCTAssertEqual(Defaults[key], fixtureCustomBridge)
	}

	func testArrayKey() {
		let user = User(username: "hank121314" , password: "123456")
		let key = Defaults.Key<[User]>("independentCustomBridgeArrayKey", default: [user])
		XCTAssertEqual(Defaults[key][0], user)
		let newUser = User(username: "sindresorhus", password: "123456789")
		Defaults[key][0] = newUser
		XCTAssertEqual(Defaults[key][0], newUser)
	}

	func testArrayOptionalKey() {
		let key = Defaults.Key<[User]?>("independentCustomBridgeArrayOptionalKey")
		XCTAssertNil(Defaults[key])
		let newUser = User(username: "hank121314", password: "123456")
		Defaults[key] = [newUser]
		XCTAssertEqual(Defaults[key]?[0], newUser)
		Defaults[key] = nil
		XCTAssertNil(Defaults[key])
	}

	func testNestedArrayKey() {
		let key = Defaults.Key<[[User]]>("independentCustomBridgeNestedArrayKey", default: [[fixtureCustomBridge], [fixtureCustomBridge]])
		XCTAssertEqual(Defaults[key][0][0].username, fixtureCustomBridge.username)
		let newUsername = "John"
		let newPassword = "7891011"
		Defaults[key][0][0] = User(username: newUsername, password: newPassword)
		XCTAssertEqual(Defaults[key][0][0].username, newUsername)
		XCTAssertEqual(Defaults[key][0][0].password, newPassword)
		XCTAssertEqual(Defaults[key][1][0].username, fixtureCustomBridge.username)
		XCTAssertEqual(Defaults[key][1][0].password, fixtureCustomBridge.password)
	}

	func testArrayDictionaryKey() {
		let key = Defaults.Key<[[String: User]]>("independentCustomBridgeArrayDictionaryKey", default: [["0": fixtureCustomBridge], ["0": fixtureCustomBridge]])
		XCTAssertEqual(Defaults[key][0]["0"]?.username, fixtureCustomBridge.username)
		let newUsername = "John"
		let newPassword = "7891011"
		Defaults[key][0]["0"] = User(username: newUsername, password: newPassword)
		XCTAssertEqual(Defaults[key][0]["0"]?.username, newUsername)
		XCTAssertEqual(Defaults[key][0]["0"]?.password, newPassword)
		XCTAssertEqual(Defaults[key][1]["0"]?.username, fixtureCustomBridge.username)
		XCTAssertEqual(Defaults[key][1]["0"]?.password, fixtureCustomBridge.password)
	}

	func testDictionaryKey() {
		let key = Defaults.Key<[String: User]>("independentCustomBridgeDictionaryKey", default: ["0": fixtureCustomBridge]);
		XCTAssertEqual(Defaults[key]["0"], fixtureCustomBridge)
		let newUser = User(username: "sindresorhus", password: "123456789")
		Defaults[key]["0"] = newUser
		XCTAssertEqual(Defaults[key]["0"], newUser)
	}

	func testDictionaryOptionalKey() {
		let key = Defaults.Key<[String: User]?>("independentCustomBridgeDictionaryOptionalKey");
		XCTAssertNil(Defaults[key])
		Defaults[key] = ["0": fixtureCustomBridge]
		XCTAssertEqual(Defaults[key]?["0"], fixtureCustomBridge)
	}

	func testDictionaryArrayKey() {
		let key = Defaults.Key<[String: [User]]>("independentCustomBridgeDictionaryArrayKey", default: ["0": [fixtureCustomBridge]])
		XCTAssertEqual(Defaults[key]["0"]?[0], fixtureCustomBridge)
		let newUser = User(username: "sindresorhus", password: "123456789")
		Defaults[key]["0"]?[0] = newUser
		Defaults[key]["0"]?.append(fixtureCustomBridge)
		XCTAssertEqual(Defaults[key]["0"]?[0], newUser)
		XCTAssertEqual(Defaults[key]["0"]?[0], newUser)
		XCTAssertEqual(Defaults[key]["0"]?[1], fixtureCustomBridge)
		XCTAssertEqual(Defaults[key]["0"]?[1], fixtureCustomBridge)
	}

	func testType() {
		XCTAssertEqual(Defaults[.customBridge], fixtureCustomBridge)
		let newUser = User(username: "sindresorhus", password: "123456789")
		Defaults[.customBridge] = newUser
		XCTAssertEqual(Defaults[.customBridge], newUser)
	}

	func testArrayType() {
		XCTAssertEqual(Defaults[.customBridgeArray][0], fixtureCustomBridge)
		let newUser = User(username: "sindresorhus", password: "123456789")
		Defaults[.customBridgeArray][0] = newUser
		XCTAssertEqual(Defaults[.customBridgeArray][0], newUser)
	}

	func testDictionaryType() {
		XCTAssertEqual(Defaults[.customBridgeDictionary]["0"], fixtureCustomBridge)
		let newUser = User(username: "sindresorhus", password: "123456789")
		Defaults[.customBridgeDictionary]["0"] = newUser
		XCTAssertEqual(Defaults[.customBridgeDictionary]["0"], newUser)
	}

	@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, iOSApplicationExtension 13.0, macOSApplicationExtension 10.15, tvOSApplicationExtension 13.0, watchOSApplicationExtension 6.0, *)
	func testObserveKeyCombine() {
		let key = Defaults.Key<User>("observeCustomBridgeKeyCombine", default: fixtureCustomBridge)
		let newUser = User(username: "sindresorhus", password: "123456789")
		let expect = expectation(description: "Observation closure being called")

		let publisher = Defaults
			.publisher(key, options: [])
			.map { ($0.oldValue, $0.newValue) }
			.collect(2)

		let cancellable = publisher.sink { tuples in
			for (i, expected) in [(fixtureCustomBridge, newUser), (newUser, fixtureCustomBridge)].enumerated() {
				XCTAssertEqual(expected.0, tuples[i].0)
				XCTAssertEqual(expected.1, tuples[i].1)
			}

			expect.fulfill()
		}

		Defaults[key] = newUser
		Defaults[key] = fixtureCustomBridge
		cancellable.cancel()

		waitForExpectations(timeout: 10)
	}

	@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, iOSApplicationExtension 13.0, macOSApplicationExtension 10.15, tvOSApplicationExtension 13.0, watchOSApplicationExtension 6.0, *)
	func testObserveOptionalKeyCombine() {
		let key = Defaults.Key<User?>("observeCustomBridgeOptionalKeyCombine")
		let newUser = User(username: "sindresorhus", password: "123456789")
		let expect = expectation(description: "Observation closure being called")

		let publisher = Defaults
			.publisher(key, options: [])
			.map { ($0.oldValue, $0.newValue) }
			.collect(3)

		let expectedValue: [(User?, User?)] = [(nil, fixtureCustomBridge), (fixtureCustomBridge, newUser), (newUser, nil)]

		let cancellable = publisher.sink { tuples in
			for (i, expected) in expectedValue.enumerated() {
				XCTAssertEqual(expected.0, tuples[i].0)
				XCTAssertEqual(expected.1, tuples[i].1)
			}

			expect.fulfill()
		}

		Defaults[key] = fixtureCustomBridge
		Defaults[key] = newUser
		Defaults.reset(key)
		cancellable.cancel()

		waitForExpectations(timeout: 10)
	}

	@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, iOSApplicationExtension 13.0, macOSApplicationExtension 10.15, tvOSApplicationExtension 13.0, watchOSApplicationExtension 6.0, *)
	func testObserveArrayKeyCombine() {
		let key = Defaults.Key<[User]>("observeCustomBridgeArrayKeyCombine", default: [fixtureCustomBridge])
		let newUser = User(username: "sindresorhus", password: "123456789")
		let expect = expectation(description: "Observation closure being called")

		let publisher = Defaults
			.publisher(key, options: [])
			.map { ($0.oldValue, $0.newValue) }
			.collect(2)

		let cancellable = publisher.sink { tuples in
			for (i, expected) in [([fixtureCustomBridge], [newUser]), ([newUser], [newUser, fixtureCustomBridge])].enumerated() {
				XCTAssertEqual(expected.0, tuples[i].0)
				XCTAssertEqual(expected.1, tuples[i].1)
			}

			expect.fulfill()
		}

		Defaults[key][0] = newUser
		Defaults[key].append(fixtureCustomBridge)
		cancellable.cancel()

		waitForExpectations(timeout: 10)
	}

	@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, iOSApplicationExtension 13.0, macOSApplicationExtension 10.15, tvOSApplicationExtension 13.0, watchOSApplicationExtension 6.0, *)
	func testObserveDictionaryCombine() {
		let key = Defaults.Key<[String: User]>("observeCustomBridgeDictionaryKeyCombine", default: ["0": fixtureCustomBridge])
		let newUser = User(username: "sindresorhus", password: "123456789")
		let expect = expectation(description: "Observation closure being called")

		let publisher = Defaults
			.publisher(key, options: [])
			.map { ($0.oldValue, $0.newValue) }
			.collect(2)

		let cancellable = publisher.sink { tuples in
			for (i, expected) in [(fixtureCustomBridge, newUser), (newUser, fixtureCustomBridge)].enumerated() {
				XCTAssertEqual(expected.0, tuples[i].0["0"])
				XCTAssertEqual(expected.1, tuples[i].1["0"])
			}

			expect.fulfill()
		}

		Defaults[key]["0"] = newUser
		Defaults[key]["0"] = fixtureCustomBridge
		cancellable.cancel()

		waitForExpectations(timeout: 10)
	}

	func testObserveKey() {
		let key = Defaults.Key<User>("observeCustomBridgeKey", default: fixtureCustomBridge)
		let newUser = User(username: "sindresorhus", password: "123456789")
		let expect = expectation(description: "Observation closure being called")

		var observation: Defaults.Observation!
		observation = Defaults.observe(key, options: []) { change in
			XCTAssertEqual(change.oldValue, fixtureCustomBridge)
			XCTAssertEqual(change.newValue, newUser)
			observation.invalidate()
			expect.fulfill()
		}

		Defaults[key] = newUser
		observation.invalidate()
		
		waitForExpectations(timeout: 10)
	}

	func testObserveOptionalKey() {
		let key = Defaults.Key<User?>("observeCustomBridgeOptionalKey")
		let expect = expectation(description: "Observation closure being called")

		var observation: Defaults.Observation!
		observation = Defaults.observe(key, options: []) { change in
			XCTAssertNil(change.oldValue)
			XCTAssertEqual(change.newValue, fixtureCustomBridge)
			observation.invalidate()
			expect.fulfill()
		}

		Defaults[key] = fixtureCustomBridge
		observation.invalidate()

		waitForExpectations(timeout: 10)
	}

	func testObserveArrayKey() {
		let key = Defaults.Key<[User]>("observeCustomBridgeArrayKey", default: [fixtureCustomBridge])
		let newUser = User(username: "sindresorhus", password: "123456789")
		let expect = expectation(description: "Observation closure being called")

		var observation: Defaults.Observation!
		observation = Defaults.observe(key, options: []) { change in
			XCTAssertEqual(change.oldValue[0], fixtureCustomBridge)
			XCTAssertEqual(change.newValue[0], newUser)
			observation.invalidate()
			expect.fulfill()
		}

		Defaults[key][0] = newUser
		observation.invalidate()

		waitForExpectations(timeout: 10)
	}

	func testObserveDictionaryKey() {
		let key = Defaults.Key<[String: User]>("observeCustomBridgeDictionaryKey", default: ["0": fixtureCustomBridge])
		let newUser = User(username: "sindresorhus", password: "123456789")
		let expect = expectation(description: "Observation closure being called")

		var observation: Defaults.Observation!
		observation = Defaults.observe(key, options: []) { change in
			XCTAssertEqual(change.oldValue["0"], fixtureCustomBridge)
			XCTAssertEqual(change.newValue["0"], newUser)
			observation.invalidate()
			expect.fulfill()
		}

		Defaults[key]["0"] = newUser
		observation.invalidate()

		waitForExpectations(timeout: 10)
	}
}
