import Foundation
import SwiftUI

struct FilterList: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let url: String
    var isEnabled: Bool
    var lastUpdated: Date?
    var ruleCount: Int?

    init(id: String, name: String, url: String, isEnabled: Bool = true, lastUpdated: Date? = nil, ruleCount: Int? = nil) {
        self.id = id
        self.name = name
        self.url = url
        self.isEnabled = isEnabled
        self.lastUpdated = lastUpdated
        self.ruleCount = ruleCount
    }
}

extension FilterList {
    static let defaultLists: [FilterList] = [
        FilterList(
            id: "easylist",
            name: "EasyList",
            url: "https://easylist.to/easylist/easylist.txt",
            isEnabled: true
        ),
        FilterList(
            id: "easyprivacy",
            name: "EasyPrivacy",
            url: "https://easylist.to/easylist/easyprivacy.txt",
            isEnabled: true
        ),
        FilterList(
            id: "fanboy-annoyance",
            name: "Fanboy's Annoyances",
            url: "https://easylist.to/easylist/fanboy-annoyance.txt",
            isEnabled: true
        ),
        FilterList(
            id: "easylist-cookies",
            name: "EasyList Cookie List",
            url: "https://easylist.to/easylist/easyprivacy_cookie.txt",
            isEnabled: false
        ),
        FilterList(
            id: "fanboy-social",
            name: "Fanboy's Social",
            url: "https://easylist.to/easylist/fanboy-social.txt",
            isEnabled: false
        ),
        FilterList(
            id: "i-dont-care-about-cookies",
            name: "I Don't Care About Cookies",
            url: "https://www.i-dont-care-about-cookies.eu/abp/",
            isEnabled: false
        )
    ]
}