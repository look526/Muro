import XCTest
@testable import MuroKit

final class ChineseUITests: XCTestCase {
    func testCatalogCategoryDisplayNamesAreChinese() {
        XCTAssertEqual(ChineseUI.name("Nature"), "自然")
        XCTAssertEqual(ChineseUI.name("Video Games"), "游戏")
        XCTAssertEqual(ChineseUI.name(importedVideoCategory), "我的视频")
        XCTAssertEqual(ChineseUI.name("All"), "全部")
    }

    func testUserNamesAndUnknownCategoriesRemainUntouched() {
        XCTAssertEqual(ChineseUI.name("My custom video"), "My custom video")
        XCTAssertEqual(ChineseUI.name("自定义壁纸"), "自定义壁纸")
        XCTAssertEqual(importedVideoCategory, "My Videos")
    }

    func testBundledWallpaperAndSystemFallbackNames() {
        XCTAssertEqual(ChineseUI.name("Snowfall in Forest"), "林间落雪")
        XCTAssertEqual(ChineseUI.name("Screen Savers"), "屏幕保护程序")
    }
}
