// swift-tools-version:5.10
import PackageDescription
import CompilerPluginSupport

let package = Package(
	name: "Defaults",
	platforms: [
		.macOS(.v11),
		.iOS(.v14),
		.tvOS(.v14),
		.watchOS(.v9),
		.visionOS(.v1)
	],
	products: [
		.library(
			name: "Defaults",
			targets: [
				"Defaults"
			]
		),
		.library(
			name: "DefaultsMacros",
			targets: [
				"DefaultsMacros"
			]
		)
	],
	dependencies: [
		.package(url: "https://github.com/swiftlang/swift-syntax", from: "600.0.0")
	],
	targets: [
		.target(
			name: "Defaults",
			resources: [.copy("PrivacyInfo.xcprivacy")]
		),
		.macro(
			name: "DefaultsMacrosDeclarations",
			dependencies: [
				"Defaults",
				.product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
				.product(name: "SwiftCompilerPlugin", package: "swift-syntax")
			]
		),
		.target(
			name: "DefaultsMacros",
			dependencies: ["Defaults", "DefaultsMacrosDeclarations"]
		),
		.testTarget(
			name: "DefaultsTests",
			dependencies: [
				"Defaults"
			]
		),
		.testTarget(
			name: "DefaultsMacrosTests",
			dependencies: [
				"DefaultsMacros",
				"DefaultsMacrosDeclarations",
				.product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
				.product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
			]
		)
	]
)
