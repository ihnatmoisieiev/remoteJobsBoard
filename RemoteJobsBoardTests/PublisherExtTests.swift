@testable import RemoteJobsBoard
import Combine
import CombineExt
import XCTest

final class PublisherExtTests: XCTestCase {

    // MARK: - Typealiases

    private typealias Completion<Error: Swift.Error> = (Subscribers.Completion<Error>) -> Void
    private typealias Value = (Int) -> Void

    // MARK: - Properties

    private var source: PassthroughSubject<Int, TestError>!
    private var subscriptions = SubscriptionsStore()
    private var value: Int?
    private var error: TestError?
    private var finished: Bool?

    private lazy var completionHandler: Completion<TestError> = { [weak self] in
        guard let self = self else { return }
        switch $0 {
        case .finished:
            self.finished = true
        case .failure(let error):
            self.error = error
        }
    }

    private lazy var valueHandler: Value = { [weak self] in
        self?.value = $0
    }

    // MARK: - Base Class

    override func setUp() {
        super.setUp()

        source = PassthroughSubject<Int, TestError>()
        value = nil
        subscriptions = SubscriptionsStore()
        error = nil
        finished = nil
    }

    // MARK: - Tests

    func test_sinkReceiveValue() {
        source
            .sink(receiveValue: valueHandler)
            .store(in: &subscriptions)

        let testValue = 10
        source.send(testValue)

        XCTAssertEqual(value, testValue)

        source.send(completion: .finished)

        XCTAssertEqual(value, testValue)
    }

    func test_sinkReceiveCompletion_finished() {
        source
            .sink(receiveCompletion: completionHandler)
            .store(in: &subscriptions)

        source.send(completion: .finished)

        XCTAssertNil(value)
        XCTAssertNil(error)
        XCTAssertEqual(finished, true)
    }

    func test_sinkReceiveCompletion_failure() {
        source
            .sink(receiveCompletion: completionHandler)
            .store(in: &subscriptions)

        let testValue = TestError.test
        source.send(completion: .failure(testValue))

        XCTAssertNil(value)
        XCTAssertNil(finished)
        XCTAssertEqual(testValue, error)
    }

    func test_sinkReceiveCompletion_value() {
        source
            .sink(receiveCompletion: completionHandler)
            .store(in: &subscriptions)

        source.send(10)

        XCTAssertNil(value)
        XCTAssertNil(finished)
    }

    func test_sinkReceiveFailure_finished() {
        source
            .sink(receiveFailure: { [weak self] error in
                self?.error = error
            })
            .store(in: &subscriptions)

        source.send(completion: .finished)

        XCTAssertNil(value)
        XCTAssertNil(finished)
        XCTAssertNil(error)
    }

    func test_sinkReceiveFailure_failure() {
        source
            .sink(receiveFailure: { [weak self] error in
                self?.error = error
            })
            .store(in: &subscriptions)

        let testValue = TestError.test
        source.send(completion: .failure(testValue))

        XCTAssertNil(value)
        XCTAssertNil(finished)
        XCTAssertEqual(testValue, error)
    }

    func test_catchWithHandler_error() {
        var handledError: TestError?

        source
            .sink(receiveCompletion: completionHandler, receiveValue: valueHandler)
            .store(in: &subscriptions)

        let testValue = 10
        source.send(testValue)
        XCTAssertEqual(testValue, value)

        let passthrough = PassthroughRelay<Result<Int, TestError>>()
        passthrough
            .tryMap {
                switch $0 {
                case .failure(let error):
                    throw error
                case .success(let value):
                    return value
                }
            }
            .catch { handledError = $0 as? TestError }
            .sink(receiveCompletion: { [weak source] in
                      switch $0 {
                      case .failure:
                          source?.send(completion: .failure(.test))
                      case .finished:
                          break
                      }
                  },
                  receiveValue: { [weak source] in source?.send($0) }
            )
            .store(in: &subscriptions)

        let testValue2 = 11
        passthrough.accept(.success(testValue2))
        XCTAssertEqual(testValue2, value)
        XCTAssertNil(finished)

        let testError = TestError.test
        passthrough.accept(.failure(testError))
        XCTAssertEqual(testError, handledError)
        XCTAssertNil(finished)

        let testValue3 = 12
        source.send(testValue3)
        XCTAssertEqual(testValue3, value)
    }

    func test_catchWithHandler_finished() {
        var handledError: TestError?

        source
            .sink(receiveCompletion: completionHandler, receiveValue: valueHandler)
            .store(in: &subscriptions)

        let passthrough = PassthroughSubject<Int, TestError>()
        passthrough
            .catch { handledError = $0 as? TestError }
            .sink(receiveCompletion: { [weak source] in
                      switch $0 {
                      case .failure:
                          source?.send(completion: .failure(.test))
                      case .finished:
                          source?.send(completion: .finished)
                      }
                  },
                  receiveValue: { [weak source] in source?.send($0) }
            )
            .store(in: &subscriptions)

        let testValue2 = 11
        passthrough.send(testValue2)
        XCTAssertEqual(testValue2, value)
        XCTAssertNil(handledError)
        XCTAssertNil(finished)

        passthrough.send(completion: .finished)
        XCTAssertEqual(testValue2, value)
        XCTAssertNil(handledError)
        XCTAssertTrue(finished ?? false)
    }

}

// MARK: - Test Error

private extension PublisherExtTests {

    enum TestError: Error {

        case test

    }

}
