import Foundation
import Libgit2Module

extension Repository {
    // MARK: - Status

    /// The status of the current repository
    /// - Parameter options: The status options
    /// - Returns: An array of `StatusEntry`
    public func status(options: StatusOptions = [.includeUntracked]) -> Result<[StatusEntry], NSError> {
        var returnArray = [StatusEntry]()

        // Do this because GIT_STATUS_OPTIONS_INIT is unavailable in swift
        let pointer = UnsafeMutablePointer<git_status_options>.allocate(capacity: 1)
        let optionsResult = git_status_options_init(pointer, UInt32(GIT_STATUS_OPTIONS_VERSION))
        guard optionsResult == GIT_OK.rawValue else {
            return .failure(NSError(gitError: optionsResult, pointOfFailure: "git_status_init_options"))
        }

        var listOptions = pointer.move()
        listOptions.flags = options.rawValue
        pointer.deallocate()

        var unsafeStatus: OpaquePointer?
        defer { git_status_list_free(unsafeStatus) }
        let statusResult = git_status_list_new(&unsafeStatus, self.pointer, &listOptions)
        guard statusResult == GIT_OK.rawValue, let unwrapStatusResult = unsafeStatus else {
            return .failure(NSError(gitError: statusResult, pointOfFailure: "git_status_list_new"))
        }

        let count = git_status_list_entrycount(unwrapStatusResult)

        for i in 0 ..< count {
            let sERTY = git_status_byindex(unwrapStatusResult, i)
            if sERTY?.pointee.status.rawValue == GIT_STATUS_CURRENT.rawValue {
                continue
            }

            let statusEntry = StatusEntry(from: sERTY!.pointee)
            returnArray.append(statusEntry)
        }

        return .success(returnArray)
    }

    /// Returns the number of commits `localCommit` is ahead of and behind `upstreamCommit`, in that order.
    public func graphAheadBehind(localCommit: Commit, upstreamCommit: Commit) -> Result<(Int, Int), NSError> {
        let aheadPointer = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        let behindPointer = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        var oid = localCommit.oid.oid
        var rOid = upstreamCommit.oid.oid
        let result = git_graph_ahead_behind(aheadPointer, behindPointer, pointer, &oid, &rOid)
        guard result == GIT_OK.rawValue else {
            return Result.failure(NSError(gitError: result, pointOfFailure: "git_merge_analysis"))
        }

        return .success((aheadPointer.pointee, behindPointer.pointee))
    }
}
