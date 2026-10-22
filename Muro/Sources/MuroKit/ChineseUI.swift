import Foundation

/// Display names only. Catalog categories and persisted identifiers stay unchanged.
public enum ChineseUI {
    public static func name(_ value: String) -> String {
        names[value] ?? value
    }

    private static let names: [String: String] = [
        "All": "全部", "Anime": "动漫", "Video Games": "游戏", "Cars": "汽车",
        "Nature": "自然", "Sci-fi": "科幻", "Movies": "影视", "Abstract": "抽象",
        "My Videos": "我的视频", "My Pictures": "我的图片", "Other": "其他", "Landscape": "风景",
        "Cityscape": "城市", "Underwater": "水下", "Earth": "地球", "Space": "太空",
        "Landscapes": "风景", "Cityscapes": "城市",
        "Dynamic Wallpapers": "动态壁纸", "Screen Savers": "屏幕保护程序",
        "Snowfall in Forest": "林间落雪", "Arabesque": "蔓延", "Drift": "漂流",
        "Flurry": "飘移", "Hello": "你好", "Shell": "贝壳", "Word of the Day": "每日一词",
        "New": "新增", "Added": "新增", "Fixed": "修复", "Changed": "变更",
        "Improved": "改进", "Improvements": "改进", "Bug Fixes": "问题修复",
    ]
}
