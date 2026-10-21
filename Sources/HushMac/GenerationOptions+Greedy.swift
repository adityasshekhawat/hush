#if canImport(FoundationModels)
import FoundationModels

@available(macOS 26.0, *)
extension GenerationOptions {
    /// Greedy decoding, the same answer every time. The macOS 27 SDK (FoundationModels 2) renamed `sampling:` to
    /// `samplingMode:`; the macOS 26 SDKs only have `sampling:`, so pick by the framework's version (a friend's build
    /// with the 26.5 Command Line Tools failed on this).
    static var greedy: GenerationOptions {
        #if canImport(FoundationModels, _version: 2.0)
        GenerationOptions(samplingMode: .greedy)
        #else
        GenerationOptions(sampling: .greedy)
        #endif
    }
}
#endif
