import Foundation

// MARK: - Flow of this file
// Every language the app offers, both as the user's native language and as the language to learn.
//   rawValue  = BCP-47 code ("uk-UA") — sent to GPT, used as Firebase translation key, voice language, SwiftData scope
//   locale    -> AppManager.locale: the whole UI is shown in the native language
//   isRtL     -> right-to-left layout for Arabic, Hebrew, Farsi…
//   displayName -> the language's own name ("Deutsch"), shown in the pickers (EntryView, SettingsView)

enum Languages: String, CaseIterable, Codable, Identifiable {
  var id: String { rawValue }                                   // pickers / ForEach need an id — the code is unique
  var locale: Locale { Locale(identifier: rawValue) }           // for SwiftUI's environment and number/percent formatting
  var isRtL: Bool {                                             // written right-to-left
    locale.language.characterDirection == .rightToLeft
  }
    // MARK: - Albanian

    case albanian = "sq-AL"

    // MARK: - Arabic

    case arabic = "ar-SA"

    // MARK: - Assamese

    case assamese = "as-IN"

    // MARK: - Basque / Iberian

    case basque = "eu-ES"
    case catalan = "ca-ES"
    case galician = "gl-ES"
    case valencian = "ca-ES-valencia"

    // MARK: - Bengali / South Asia

    case bengaliIndia = "bn-IN"
    case gujarati = "gu-IN"
    case hindi = "hi-IN"
    case kannada = "kn-IN"
    case malayalam = "ml-IN"
    case marathi = "mr-IN"
    case nepali = "ne-NP"
    case odia = "or-IN"
    case punjabi = "pa-IN"
    case tamil = "ta-IN"
    case telugu = "te-IN"

    // MARK: - Bulgarian

    case bulgarian = "bg-BG"

    // MARK: - Chinese

    case chineseMainland = "zh-CN"
    case chineseLiaoning = "zh-CN-liaoning"
    case chineseShaanxi = "zh-CN-shaanxi"
    case chineseSichuan = "zh-CN-sichuan"
    case chineseTaiwan = "zh-TW"
    case cantoneseHongKong = "yue-HK"
    case shanghainese = "wuu-CN"

    // MARK: - Croatian

    case croatian = "hr-HR"

    // MARK: - Czech

    case czech = "cs-CZ"

    // MARK: - Danish

    case danish = "da-DK"

    // MARK: - Dutch

    case dutchBelgium = "nl-BE" // "Flemish" in Apple's current naming
    case dutchNetherlands = "nl-NL"

    // MARK: - English

    case englishAustralia = "en-AU"
    case englishIndia = "en-IN"
    case englishIreland = "en-IE"
    case englishScotland = "en-GB-scotland"
    case englishSouthAfrica = "en-ZA"
    case englishUK = "en-GB"
    case englishUS = "en-US"

    // MARK: - Farsi

    case farsi = "fa-IR"

    // MARK: - Finnish

    case finnish = "fi-FI"

    // MARK: - French

    case frenchBelgium = "fr-BE"
    case frenchCanada = "fr-CA"
    case frenchFrance = "fr-FR"

    // MARK: - German

    case german = "de-DE"

    // MARK: - Greek

    case greek = "el-GR"

    // MARK: - Hebrew

    case hebrew = "he-IL"

    // MARK: - Hungarian

    case hungarian = "hu-HU"

    // MARK: - Indonesian

    case indonesian = "id-ID"

    // MARK: - Italian

    case italian = "it-IT"

    // MARK: - Japanese

    case japanese = "ja-JP"

    // MARK: - Kazakh

    case kazakh = "kk-KZ"

    // MARK: - Korean

    case korean = "ko-KR"

    // MARK: - Lithuanian

    case lithuanian = "lt-LT"

    // MARK: - Malay

    case malay = "ms-MY"

    // MARK: - Norwegian

    case norwegian = "nb-NO"

    // MARK: - Polish

    case polish = "pl-PL"

    // MARK: - Portuguese

    case portugueseBrazil = "pt-BR"
    case portuguesePortugal = "pt-PT"

    // MARK: - Romanian

    case romanian = "ro-RO"

    // MARK: - Russian

    case russian = "ru-RU"

    // MARK: - Slovak

    case slovak = "sk-SK"

    // MARK: - Slovenian

    case slovenian = "sl-SI"

    // MARK: - Spanish

    case spanishArgentina = "es-AR"
    case spanishChile = "es-CL"
    case spanishColombia = "es-CO"
    case spanishMexico = "es-MX"
    case spanishSpain = "es-ES"

    // MARK: - Swedish

    case swedish = "sv-SE"

    // MARK: - Thai

    case thai = "th-TH"

    // MARK: - Turkish

    case turkish = "tr-TR"

    // MARK: - Ukrainian

    case ukrainian = "uk-UA"

    // MARK: - Vietnamese

    case vietnamese = "vi-VN"

    // MARK: - name(in:)
    // The language's name in the given language (the app's language), e.g. "English (United States)" for an English UI,
    // "Английский (США)" for a Russian one. Used where the user reads about a language rather than picks it
    // (WelcomeBackView's cards, MyWordsView). Falls back to displayName if iOS has no name for it.
    // First letter capitalized: many languages write language names in lowercase ("іспанська (Чилі)"), which looks
    // wrong as a title. Only the first letter, in that language's rules — the rest stays as iOS wrote it.
    func name(in locale: Locale) -> String {
        let name = locale.localizedString(forIdentifier: rawValue) ?? displayName
        return name.prefix(1).uppercased(with: locale) + name.dropFirst()
    }

    // MARK: - Display

  var displayName: String {                                     // name in the language itself — readable for its speakers whatever the UI language
    switch self {
    case .albanian:           "Shqip"
    case .arabic:             "العربية"
    case .assamese:           "অসমীয়া"
    case .basque:             "Euskara"
    case .catalan:            "Català"
    case .galician:           "Galego"
    case .valencian:          "Valencià"
    case .bengaliIndia:       "বাংলা (ভারত)"
    case .gujarati:           "ગુજરાતી"
    case .hindi:              "हिन्दी"
    case .kannada:            "ಕನ್ನಡ"
    case .malayalam:          "മലയാളം"
    case .marathi:            "मराठी"
    case .nepali:             "नेपाली"
    case .odia:               "ଓଡ଼ିଆ"
    case .punjabi:            "ਪੰਜਾਬੀ"
    case .tamil:              "தமிழ்"
    case .telugu:             "తెలుగు"
    case .bulgarian:          "Български"
    case .chineseMainland:    "中文（中国大陆）"
    case .chineseLiaoning:    "中文（辽宁）"
    case .chineseShaanxi:     "中文（陕西）"
    case .chineseSichuan:     "中文（四川）"
    case .chineseTaiwan:      "中文（台灣）"
    case .cantoneseHongKong:  "粵語（香港）"
    case .shanghainese:       "上海话"
    case .croatian:           "Hrvatski"
    case .czech:              "Čeština"
    case .danish:             "Dansk"
    case .dutchBelgium:       "Nederlands (België)"
    case .dutchNetherlands:   "Nederlands (Nederland)"
    case .englishAustralia:   "English (Australia)"
    case .englishIndia:       "English (India)"
    case .englishIreland:     "English (Ireland)"
    case .englishScotland:    "English (Scotland)"
    case .englishSouthAfrica: "English (South Africa)"
    case .englishUK:          "English (UK)"
    case .englishUS:          "English (US)"
    case .farsi:              "فارسی"
    case .finnish:            "Suomi"
    case .frenchBelgium:      "Français (Belgique)"
    case .frenchCanada:       "Français (Canada)"
    case .frenchFrance:       "Français (France)"
    case .german:             "Deutsch"
    case .greek:              "Ελληνικά"
    case .hebrew:             "עברית"
    case .hungarian:          "Magyar"
    case .indonesian:         "Bahasa Indonesia"
    case .italian:            "Italiano"
    case .japanese:           "日本語"
    case .kazakh:             "Қазақ тілі"
    case .korean:             "한국어"
    case .lithuanian:         "Lietuvių"
    case .malay:              "Bahasa Melayu"
    case .norwegian:          "Norsk"
    case .polish:             "Polski"
    case .portugueseBrazil:   "Português (Brasil)"
    case .portuguesePortugal: "Português (Portugal)"
    case .romanian:           "Română"
    case .russian:            "Русский"
    case .slovak:             "Slovenčina"
    case .slovenian:          "Slovenščina"
    case .spanishArgentina:   "Español (Argentina)"
    case .spanishChile:       "Español (Chile)"
    case .spanishColombia:    "Español (Colombia)"
    case .spanishMexico:      "Español (México)"
    case .spanishSpain:       "Español (España)"
    case .swedish:            "Svenska"
    case .thai:               "ไทย"
    case .turkish:            "Türkçe"
    case .ukrainian:          "Українська"
    case .vietnamese:         "Tiếng Việt"
    }
  }
    
}
