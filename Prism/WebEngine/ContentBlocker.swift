import Foundation
import WebKit

// MARK: - ContentBlocker

@MainActor
final class ContentBlocker {

    static let shared = ContentBlocker()

    private let ruleListIdentifier = "com.prism.contentblocker.v2"
    
    private let defaultRulesFileName = "blockerRules.json"

    // MARK: - Rule list JSON

    private var rulesJSON: String {
        if let url = Bundle.main.url(forResource: defaultRulesFileName, withExtension: nil),
           let data = try? Data(contentsOf: url),
           let jsonString = String(data: data, encoding: .utf8) {
            print("[Prism] Loaded content blocking rules from bundle: \(defaultRulesFileName)")
            return jsonString
        }
        
        print("[Prism] Using fallback content blocking rules (bundle file not found)")
        return fallbackRulesJSON
    }

    private let fallbackRulesJSON: String = """
    [
      {
        "trigger": { "url-filter": ".*\\\\.doubleclick\\\\.net.*" },
        "action":  { "type": "block" }
      },
      {
        "trigger": { "url-filter": ".*googlesyndication\\\\.com.*" },
        "action":  { "type": "block" }
      },
      {
        "trigger": { "url-filter": ".*amazon-adsystem\\\\.com.*" },
        "action":  { "type": "block" }
      },
      {
        "trigger": { "url-filter": ".*adnxs\\\\.com.*" },
        "action":  { "type": "block" }
      },
      {
        "trigger": { "url-filter": ".*moatads\\\\.com.*" },
        "action":  { "type": "block" }
      },
      {
        "trigger": { "url-filter": ".*adsafeprotected\\\\.com.*" },
        "action":  { "type": "block" }
      },
      {
        "trigger": { "url-filter": ".*google-analytics\\\\.com.*" },
        "action":  { "type": "block" }
      },
      {
        "trigger": { "url-filter": ".*googletagmanager\\\\.com.*" },
        "action":  { "type": "block" }
      },
      {
        "trigger": { "url-filter": ".*googletagservices\\\\.com.*" },
        "action":  { "type": "block" }
      },
      {
        "trigger": { "url-filter": ".*connect\\\\.facebook\\\\.net.*" },
        "action":  { "type": "block" }
      },
      {
        "trigger": { "url-filter": ".*facebook\\\\.com/tr.*" },
        "action":  { "type": "block" }
      },
      {
        "trigger": { "url-filter": ".*hotjar\\\\.com.*" },
        "action":  { "type": "block" }
      },
      {
        "trigger": { "url-filter": ".*mixpanel\\\\.com.*" },
        "action":  { "type": "block" }
      },
      {
        "trigger": { "url-filter": ".*segment\\\\.com.*" },
        "action":  { "type": "block" }
      },
      {
        "trigger": { "url-filter": ".*segment\\\\.io.*" },
        "action":  { "type": "block" }
      },
      {
        "trigger": { "url-filter": ".*amplitude\\\\.com.*" },
        "action":  { "type": "block" }
      },
      {
        "trigger": { "url-filter": ".*heap\\\\.io.*" },
        "action":  { "type": "block" }
      },
      {
        "trigger": { "url-filter": ".*intercom\\\\.io.*" },
        "action":  { "type": "block" }
      },
      {
        "trigger": { "url-filter": ".*intercomcdn\\\\.com.*" },
        "action":  { "type": "block" }
      },
      {
        "trigger": { "url-filter": ".*static\\\\.ads-twitter\\\\.com.*" },
        "action":  { "type": "block" }
      },
      {
        "trigger": { "url-filter": ".*ads\\\\.twitter\\\\.com.*" },
        "action":  { "type": "block" }
      },
      {
        "trigger": { "url-filter": ".*platform\\\\.twitter\\\\.com/widgets.*" },
        "action":  { "type": "block" }
      },
      {
        "trigger": { "url-filter": ".*like\\\\.facebook\\\\.com.*" },
        "action":  { "type": "block" }
      },
      {
        "trigger": { "url-filter": ".*platform\\\\.linkedin\\\\.com/in.*" },
        "action":  { "type": "block" }
      },
      {
        "trigger": { "url-filter": ".*apis\\\\.google\\\\.com/js/plusone.*" },
        "action":  { "type": "block" }
      },
      {
        "trigger": { "url-filter": ".*widgets\\\\.pinterest\\\\.com.*" },
        "action":  { "type": "block" }
      },
      {
        "trigger": { "url-filter": ".*cdn\\\\.taboola\\\\.com.*" },
        "action":  { "type": "block" }
      },
      {
        "trigger": { "url-filter": ".*outbrain\\\\.com.*" },
        "action":  { "type": "block" }
      },
      {
        "trigger": { "url-filter": ".*criteo\\\\.com.*" },
        "action":  { "type": "block" }
      },
      {
        "trigger": { "url-filter": ".*rubiconproject\\\\.com.*" },
        "action":  { "type": "block" }
      },
      {
        "trigger": { "url-filter": ".*openx\\\\.net.*" },
        "action":  { "type": "block" }
      },
      {
        "trigger": { "url-filter": ".*pubmatic\\\\.com.*" },
        "action":  { "type": "block" }
      },
      {
        "trigger": { "url-filter": ".*smartadserver\\\\.com.*" },
        "action":  { "type": "block" }
      }
    ]
    """

    // MARK: - Compile

    /// Compiles (or retrieves cached) content rule list and returns it.
    @MainActor
    func loadRuleList() async throws -> WKContentRuleList {
        return try await withCheckedThrowingContinuation { continuation in
            WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: ruleListIdentifier,
                encodedContentRuleList: rulesJSON
            ) { ruleList, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let ruleList {
                    continuation.resume(returning: ruleList)
                } else {
                    continuation.resume(throwing: ContentBlockerError.compilationFailed)
                }
            }
        }
    }

    func reload() async {
        do {
            _ = try await loadRuleList()
            print("[Prism] ContentBlocker reloaded successfully")
        } catch {
            print("[Prism] ContentBlocker reload failed: \(error)")
        }
    }

    // MARK: - Errors

    enum ContentBlockerError: Error, LocalizedError {
        case compilationFailed
        var errorDescription: String? { "Content rule list compilation failed." }
    }
}
