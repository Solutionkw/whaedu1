/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

@testable import FBSDKCoreKit

import TestTools
import XCTest

final class AuthenticationStatusUtilityTests: XCTestCase {

  // swiftlint:disable implicitly_unwrapped_optional
  let url = URL(string: "m.facebook.com/platform/oidc/status/")! // swiftlint:disable:this force_unwrapping
  var sessionDataTask: TestSessionDataTask!
  var sessionDataTaskProvider: TestSessionProvider!
  // swiftlint:enable implicitly_unwrapped_optional

  override func setUp() {
    super.setUp()

    _AuthenticationStatusUtility.resetClassDependencies()

    TestAccessTokenWallet.stubbedCurrentAccessToken = SampleAccessTokens.validToken
    TestAuthenticationTokenWallet.current = SampleAuthenticationToken.validToken
    TestProfileProvider.current = SampleUserProfiles.createValid()

    sessionDataTask = TestSessionDataTask()
    sessionDataTaskProvider = TestSessionProvider()
    sessionDataTaskProvider.stubbedDataTask = sessionDataTask

    _AuthenticationStatusUtility.configure(
      profileSetter: TestProfileProvider.self,
      sessionDataTaskProvider: sessionDataTaskProvider,
      accessTokenWallet: TestAccessTokenWallet.self,
      authenticationTokenWallet: TestAuthenticationTokenWallet.self
    )
  }

  override func tearDown() {
    _AuthenticationStatusUtility.resetClassDependencies()
    TestAccessTokenWallet.reset()
    TestAuthenticationTokenWallet.reset()
    TestProfileProvider.reset()
    sessionDataTask = nil
    sessionDataTaskProvider = nil

    super.tearDown()
  }

  func testDefaultClassDependencies() {
    _AuthenticationStatusUtility.resetClassDependencies()

    XCTAssertNil(
      _AuthenticationStatusUtility.profileSetter,
      "Should not have a profile setter by default"
    )
    XCTAssertNil(
      _AuthenticationStatusUtility.sessionDataTaskProvider,
      "Should not have a session data task provider by default"
    )
    XCTAssertNil(
      _AuthenticationStatusUtility.accessTokenWallet,
      "Should not have an access token default"
    )
    XCTAssertNil(
      _AuthenticationStatusUtility.authenticationTokenWallet,
      "Should not have an authentication token by default"
    )
  }

  func testConfiguringWithCustomClassDependencies() {
    XCTAssertTrue(
      _AuthenticationStatusUtility.profileSetter === TestProfileProvider.self,
      "Should be able to set a custom profile setter"
    )
    XCTAssertTrue(
      _AuthenticationStatusUtility.sessionDataTaskProvider === sessionDataTaskProvider,
      "Should be able to set a custom session data task provider"
    )
    XCTAssertTrue(
      _AuthenticationStatusUtility.accessTokenWallet === TestAccessTokenWallet.self,
      "Should be able to set a custom access token"
    )
    XCTAssertTrue(
      _AuthenticationStatusUtility.authenticationTokenWallet === TestAuthenticationTokenWallet.self,
      "Should be able to set a custom authentication token"
    )
  }

  func testCheckAuthenticationStatusWithNoToken() {
    TestAuthenticationTokenWallet.current = nil
    _AuthenticationStatusUtility.checkAuthenticationStatus()

    XCTAssertNil(
      sessionDataTaskProvider.capturedRequest,
      "Should not create a request if there is no authentication token"
    )

    XCTAssertNotNil(
      TestAccessTokenWallet.current,
      "Should not reset the current access token on failure to check the status of an authentication token"
    )
    XCTAssertNotNil(
      TestProfileProvider.current,
      "Should not reset the current profile on failure to check the status of an authentication token"
    )
  }

  func testRequestURL() {
    let url = _AuthenticationStatusUtility._requestURL()

    XCTAssertEqual(url.host, "m.facebook.com")
    XCTAssertEqual(url.path, "/platform/oidc/status")

    let params = InternalUtility.shared.parameters(fromFBURL: url)
    XCTAssertNotNil(
      params["id_token"],
      "Incorrect ID token parameter in request url"
    )
  }

  func testHandleNotAuthorizedResponse() {
    let header = ["fb-s": "not_authorized"]
    let response = HTTPURLResponse(
      url: url,
      statusCode: 200,
      httpVersion: nil,
      headerFields: header
    )! // swiftlint:disable:this force_unwrapping

    _AuthenticationStatusUtility._handle(response)

    XCTAssertNil(
      TestAuthenticationTokenWallet.current,
      "Authentication token should be cleared when not authorized"
    )
    XCTAssertNil(
      TestAccessTokenWallet.current,
      "Access token should be cleared when not authorized"
    )
    XCTAssertNil(
      TestProfileProvider.current,
      "Profile should be cleared when not authorized"
    )
  }

  func testHandleConnectedResponse() {
    let header = ["fb-s": "connected"]
    let response = HTTPURLResponse(
      url: url,
      statusCode: 200,
      httpVersion: nil,
      headerFields: header
    )! // swiftlint:disable:this force_unwrapping

    _AuthenticationStatusUtility._handle(response)

    XCTAssertNotNil(
      TestAuthenticationTokenWallet.current,
      "Authentication token should not be cleared when connected"
    )
    XCTAssertNotNil(
      TestAccessTokenWallet.current,
      "Access token should not be cleared when connected"
    )
    XCTAssertNotNil(
      TestProfileProvider.current,
      "Profile should not be cleared when connected"
    )
  }

  func testHandleNoStatusResponse() {
    let response = HTTPURLResponse(
      url: url,
      statusCode: 200,
      httpVersion: nil,
      headerFields: [:]
    )! // swiftlint:disable:this force_unwrapping

    _AuthenticationStatusUtility._handle(response)

    XCTAssertNotNil(
      TestAuthenticationTokenWallet.current,
      "Authentication token should not be cleared when connected"
    )
    XCTAssertNotNil(
      TestAccessTokenWallet.current,
      "Access token should not be cleared when connected"
    )
    XCTAssertNotNil(
      TestProfileProvider.current,
      "Profile should not be cleared when connected"
    )
  }

  func testHandleResponseWithFuzzyData() {
    for _ in 0 ..< 100 {
      let header = [
        "fb-s": Fuzzer.random.description,
        "some_header_key": Fuzzer.random.description,
      ]

      let response = HTTPURLResponse(
        url: url,
        statusCode: 200,
        httpVersion: nil,
        headerFields: header as? [String: String]
      )! // swiftlint:disable:this force_unwrapping

      _AuthenticationStatusUtility._handle(response)
    }
  }
}
