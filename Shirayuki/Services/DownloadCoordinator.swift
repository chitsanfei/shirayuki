import Foundation

nonisolated struct DownloadRequest: Sendable {
    let comicID: String
    let title: String
    let thumbURL: String
    let createdAt: String
    let updatedAt: String
    let chapters: [PicaChapter]
    let quality: AppImageQuality
    let allChapters: [PicaChapter]
    let allowDownload: Bool
}

nonisolated enum DownloadCoordinatorError: Error, Equatable, Sendable {
    case invalidRequest
    case downloadNotAllowed
    case conflict(existingJobIDs: [String])
    case unknownJob
}

/// Serializes all download entry points and exposes one observable job registry.
actor DownloadCoordinator {
    static let shared = DownloadCoordinator()

nonisolated struct DownloadChapterKey: Hashable, Sendable {
    let comicID: String
    let chapterID: String
}

    private struct Job: Sendable {
        let request: DownloadRequest
        var snapshot: AgentDownloadSnapshot
        var task: Task<Void, Never>?
        var keys: Set<DownloadChapterKey>
    }

    private var jobs: [String: Job] = [:]
    private var queue: [String] = []
    private var activeJobID: String?
    private var occupiedKeys: [DownloadChapterKey: String] = [:]
    private var continuations: [String: [UUID: AsyncStream<AgentDownloadSnapshot>.Continuation]] = [:]

    private init() {}
    nonisolated static func conflictingJobIDs(
        comicID: String,
        chapterIDs: [String],
        occupiedKeys: [DownloadChapterKey: String]
    ) -> [String] {
        Set(chapterIDs.compactMap {
            occupiedKeys[DownloadChapterKey(comicID: comicID, chapterID: $0)]
        }).sorted()
    }

    /// Enqueues a complete request, rejecting every overlapping chapter key atomically.
    func start(request: DownloadRequest) throws -> String {
        let trimmedID = request.comicID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty,
              request.allowDownload,
              !request.chapters.isEmpty,
              request.chapters.allSatisfy({ chapter in
                  request.allChapters.contains(where: { candidate in candidate.id == chapter.id })
              }) else {
            if !request.allowDownload { throw DownloadCoordinatorError.downloadNotAllowed }
            throw DownloadCoordinatorError.invalidRequest
        }

        let chapterIDs = request.chapters.map(\.id)
        guard Set(chapterIDs).count == chapterIDs.count else {
            throw DownloadCoordinatorError.invalidRequest
        }

        let keys = Set(request.chapters.map { DownloadChapterKey(comicID: trimmedID, chapterID: $0.id) })
        let conflicts = Set(Self.conflictingJobIDs(
            comicID: trimmedID,
            chapterIDs: request.chapters.map(\.id),
            occupiedKeys: occupiedKeys
        ))
        guard conflicts.isEmpty else {
            throw DownloadCoordinatorError.conflict(existingJobIDs: conflicts.sorted())
        }

        let jobID = UUID().uuidString
        let snapshot = AgentDownloadSnapshot(
            id: jobID,
            comicID: trimmedID,
            title: request.title,
            chapterIDs: chapterIDs,
            state: .queued,
            completedImages: 0,
            totalImages: 0,
            errorMessage: nil
        )
        jobs[jobID] = Job(request: request, snapshot: snapshot, task: nil, keys: keys)
        queue.append(jobID)
        for key in keys { occupiedKeys[key] = jobID }
        emit(snapshot)
        pumpIfNeeded()
        return jobID
    }

    func snapshot(jobID: String) throws -> AgentDownloadSnapshot {
        guard let snapshot = jobs[jobID]?.snapshot else { throw DownloadCoordinatorError.unknownJob }
        return snapshot
    }

    /// Returns queued and active jobs; completed jobs are queried by explicit ID.
    func activeSnapshots() -> [AgentDownloadSnapshot] {
        queue.compactMap { jobs[$0]?.snapshot } + (activeJobID.flatMap { jobs[$0]?.snapshot }.map { [$0] } ?? [])
    }

    func allSnapshots() -> [AgentDownloadSnapshot] {
        jobs.values.map(\.snapshot).sorted { $0.id < $1.id }
    }

    func updates(for jobID: String) -> AsyncStream<AgentDownloadSnapshot> {
        AsyncStream { continuation in
            let id = UUID()
            continuations[jobID, default: [:]][id] = continuation
            if let snapshot = jobs[jobID]?.snapshot {
                continuation.yield(snapshot)
            }
            continuation.onTermination = { _ in
                Task { await self.removeContinuation(jobID: jobID, id: id) }
            }
        }
    }

    func cancel(jobID: String) throws {
        guard var job = jobs[jobID] else { throw DownloadCoordinatorError.unknownJob }
        if activeJobID == jobID {
            job.task?.cancel()
            jobs[jobID] = job
            return
        }
        guard let queueIndex = queue.firstIndex(of: jobID) else {
            throw DownloadCoordinatorError.unknownJob
        }
        queue.remove(at: queueIndex)
        releaseKeys(for: jobID, keys: job.keys)
        job.snapshot = AgentDownloadSnapshot(
            id: job.snapshot.id,
            comicID: job.snapshot.comicID,
            title: job.snapshot.title,
            chapterIDs: job.snapshot.chapterIDs,
            state: .cancelled,
            completedImages: job.snapshot.completedImages,
            totalImages: job.snapshot.totalImages,
            errorMessage: nil
        )
        jobs[jobID] = job
        emit(job.snapshot)
    }

    private func pumpIfNeeded() {
        guard activeJobID == nil, let nextJobID = queue.first, var job = jobs[nextJobID] else { return }
        queue.removeFirst()
        activeJobID = nextJobID
        job.snapshot = AgentDownloadSnapshot(
            id: job.snapshot.id,
            comicID: job.snapshot.comicID,
            title: job.snapshot.title,
            chapterIDs: job.snapshot.chapterIDs,
            state: .downloading,
            completedImages: 0,
            totalImages: 0,
            errorMessage: nil
        )
        let request = job.request
        jobs[nextJobID] = job
        let task = Task { [weak self] in
            do {
                try await OfflineComicStore.shared.download(
                    comicID: request.comicID,
                    title: request.title,
                    thumbURL: request.thumbURL,
                    createdAt: request.createdAt,
                    updatedAt: request.updatedAt,
                    chapters: request.chapters,
                    quality: request.quality,
                    allChapters: request.allChapters,
                    progress: { progress in
                        Task { await self?.updateProgress(jobID: nextJobID, progress: progress) }
                    }
                )
                await self?.finish(jobID: nextJobID, state: .completed, errorMessage: nil)
            } catch is CancellationError {
                await self?.finish(jobID: nextJobID, state: .cancelled, errorMessage: nil)
            } catch {
                await self?.finish(jobID: nextJobID, state: .failed, errorMessage: Self.sanitizedMessage(error))
            }
        }
        jobs[nextJobID]?.task = task
        emit(job.snapshot)
    }

    private func updateProgress(jobID: String, progress: OfflineDownloadProgress) {
        guard let job = jobs[jobID], activeJobID == jobID else { return }
        let snapshot = AgentDownloadSnapshot(
            id: job.snapshot.id,
            comicID: job.snapshot.comicID,
            title: job.snapshot.title,
            chapterIDs: job.snapshot.chapterIDs,
            state: .downloading,
            completedImages: progress.completedImages,
            totalImages: progress.totalImages,
            errorMessage: nil
        )
        jobs[jobID]?.snapshot = snapshot
        emit(snapshot)
    }

    private func finish(jobID: String, state: AgentDownloadState, errorMessage: String?) {
        guard var job = jobs[jobID], activeJobID == jobID else { return }
        let previous = job.snapshot
        job.snapshot = AgentDownloadSnapshot(
            id: previous.id,
            comicID: previous.comicID,
            title: previous.title,
            chapterIDs: previous.chapterIDs,
            state: state,
            completedImages: previous.completedImages,
            totalImages: previous.totalImages,
            errorMessage: errorMessage
        )
        job.task = nil
        jobs[jobID] = job
        releaseKeys(for: jobID, keys: job.keys)
        activeJobID = nil
        emit(job.snapshot)
        pumpIfNeeded()
    }

    private func releaseKeys(for jobID: String, keys: Set<DownloadChapterKey>) {
        for key in keys where occupiedKeys[key] == jobID {
            occupiedKeys.removeValue(forKey: key)
        }
    }

    private func emit(_ snapshot: AgentDownloadSnapshot) {
        for continuation in continuations[snapshot.id]?.values ?? [:].values {
            continuation.yield(snapshot)
        }
    }

    private func removeContinuation(jobID: String, id: UUID) {
        continuations[jobID]?.removeValue(forKey: id)
        if continuations[jobID]?.isEmpty == true {
            continuations.removeValue(forKey: jobID)
        }
    }

    private static func sanitizedMessage(_ error: Error) -> String {
        if let error = error as? URLError { return error.code.rawValue.description }
        if let error = error as? APIError {
            switch error {
            case .unauthorized: return "unauthorized"
            case .serverError(let code, _): return "server_\(code)"
            case .networkError: return "network_error"
            case .invalidURL: return "invalid_url"
            case .invalidResponse: return "invalid_response"
            case .emptyData: return "empty_data"
            case .encodingError: return "encoding_error"
            case .decodingError: return "decoding_error"
            }
        }
        return "download_failed"
    }
}
