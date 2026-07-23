import Foundation

extension Foundation.Bundle {
    static nonisolated let module: Bundle = {
        let mainPath = Bundle.main.bundleURL.appendingPathComponent("OpenSoundSource_OpenSoundSource.bundle").path
        let buildPath = "/Users/kbshal/mero_space/projects/soundcore_alternative_open_ss/OpenSoundSource/.build/arm64-apple-macosx/debug/OpenSoundSource_OpenSoundSource.bundle"

        let preferredBundle = Bundle(path: mainPath)

        guard let bundle = preferredBundle ?? Bundle(path: buildPath) else {
            // Users can write a function called fatalError themselves, we should be resilient against that.
            Swift.fatalError("could not load resource bundle: from \(mainPath) or \(buildPath)")
        }

        return bundle
    }()
}