// The initial coordinator is DocumentRepository's private atomic commit path.
// Import this compatibility entry point; no alternate writer bypass exists.
export 'studio_store.dart' show DocumentRepository, WriterToken, CommitReceipt;
