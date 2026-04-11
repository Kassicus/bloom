import SwiftUI
import SwiftData
import CoreText

@main
struct bloomApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Cycle.self,
            DailyLog.self,
            IntercourseEntry.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        registerCustomFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }

    private func registerCustomFonts() {
        guard let fontURL = Bundle.main.url(forResource: "Yellowtail-Regular", withExtension: "ttf", subdirectory: "Resources/Fonts") else {
            // Try without subdirectory (Xcode may flatten the bundle)
            if let flatURL = Bundle.main.url(forResource: "Yellowtail-Regular", withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(flatURL as CFURL, .process, nil)
            }
            return
        }
        CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
    }
}
