import XCTest
@testable import SafeOrbit

final class ServerConfigurationTests: XCTestCase {
    func testLocalAndSecureServers() {
        XCTAssertNotNil(ServerConfiguration.validatedURL("http://192.168.1.20:3000"))
        XCTAssertNotNil(ServerConfiguration.validatedURL("https://example.com"))
    }

    func testInvalidServersAreRejected() {
        for value in ["", "192.168.1.20:3000", "file:///tmp/server", "http://", "https://user:password@example.com"] {
            XCTAssertNil(ServerConfiguration.validatedURL(value), value)
        }
    }
}
