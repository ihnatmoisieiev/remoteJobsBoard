import Combine
import CombineExt
import Foundation
@testable import RemoteJobsBoard

final class GenericMockAPIService: APIServiceType {

    func getJobs() -> JobsPublisher {
        do {
            let data = try MockJSONLoader.loadJSON(named: MockJSON.full.fileName)
            return Just(data)
                .tryMap { try JSONDecoder().decode(APIService.JobsResponseModel.self, from: $0) }
                .map { $0.jobs.map { Job(apiModel: $0) } }
                .delay(for: 0.5, scheduler: DispatchQueue.global())
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }

}
