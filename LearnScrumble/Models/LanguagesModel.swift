import Foundation
import AVFoundation
import Speech

enum Languages: String, CaseIterable, Codable, Identifiable {

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
    case bhojpuriIndia = "bho-IN"
    case bodo = "brx-IN"
    case dogri = "doi-IN"
    case gujarati = "gu-IN"
    case hindi = "hi-IN"
    case kannada = "kn-IN"
    case konkani = "kok-IN"
    case maithili = "mai-IN"
    case malayalam = "ml-IN"
    case manipuri = "mni-IN"
    case marathi = "mr-IN"
    case nepali = "ne-NP"
    case odia = "or-IN"
    case punjabi = "pa-IN"
    case sanskrit = "sa-IN"
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

    // MARK: - Display

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {

        case .albanian:
            "Albanian"

        case .arabic:
            "Arabic"

        case .assamese:
            "Assamese"

        case .basque:
            "Basque"

        case .catalan:
            "Catalan"

        case .galician:
            "Galician"

        case .valencian:
            "Valencian"

        case .bengaliIndia:
            "Bengali (India)"

        case .bhojpuriIndia:
            "Bhojpuri (India)"

        case .bodo:
            "Bodo"

        case .dogri:
            "Dogri"

        case .gujarati:
            "Gujarati"

        case .hindi:
            "Hindi"

        case .kannada:
            "Kannada"

        case .konkani:
            "Konkani"

        case .maithili:
            "Maithili"

        case .malayalam:
            "Malayalam"

        case .manipuri:
            "Manipuri"

        case .marathi:
            "Marathi"

        case .nepali:
            "Nepali"

        case .odia:
            "Odia"

        case .punjabi:
            "Punjabi"

        case .sanskrit:
            "Sanskrit"

        case .tamil:
            "Tamil"

        case .telugu:
            "Telugu"

        case .bulgarian:
            "Bulgarian"

        case .chineseMainland:
            "Chinese (China Mainland)"

        case .chineseLiaoning:
            "Chinese (Liaoning)"

        case .chineseShaanxi:
            "Chinese (Shaanxi)"

        case .chineseSichuan:
            "Chinese (Sichuan)"

        case .chineseTaiwan:
            "Chinese (Taiwan)"

        case .cantoneseHongKong:
            "Cantonese (Hong Kong)"

        case .shanghainese:
            "Shanghainese"

        case .croatian:
            "Croatian"

        case .czech:
            "Czech"

        case .danish:
            "Danish"

        case .dutchBelgium:
            "Dutch (Belgium)"

        case .dutchNetherlands:
            "Dutch (Netherlands)"

        case .englishAustralia:
            "English (Australia)"

        case .englishIndia:
            "English (India)"

        case .englishIreland:
            "English (Ireland)"

        case .englishScotland:
            "English (Scotland)"

        case .englishSouthAfrica:
            "English (South Africa)"

        case .englishUK:
            "English (UK)"

        case .englishUS:
            "English (US)"

        case .farsi:
            "Farsi"

        case .finnish:
            "Finnish"

        case .frenchBelgium:
            "French (Belgium)"

        case .frenchCanada:
            "French (Canada)"

        case .frenchFrance:
            "French (France)"

        case .german:
            "German"

        case .greek:
            "Greek"

        case .hebrew:
            "Hebrew"

        case .hungarian:
            "Hungarian"

        case .indonesian:
            "Indonesian"

        case .italian:
            "Italian"

        case .japanese:
            "Japanese"

        case .kazakh:
            "Kazakh"

        case .korean:
            "Korean"

        case .lithuanian:
            "Lithuanian"

        case .malay:
            "Malay"

        case .norwegian:
            "Norwegian"

        case .polish:
            "Polish"

        case .portugueseBrazil:
            "Portuguese (Brazil)"

        case .portuguesePortugal:
            "Portuguese (Portugal)"

        case .romanian:
            "Romanian"

        case .russian:
            "Russian"

        case .slovak:
            "Slovak"

        case .slovenian:
            "Slovenian"

        case .spanishArgentina:
            "Spanish (Argentina)"

        case .spanishChile:
            "Spanish (Chile)"

        case .spanishColombia:
            "Spanish (Colombia)"

        case .spanishMexico:
            "Spanish (Mexico)"

        case .spanishSpain:
            "Spanish (Spain)"

        case .swedish:
            "Swedish"

        case .thai:
            "Thai"

        case .turkish:
            "Turkish"

        case .ukrainian:
            "Ukrainian"

        case .vietnamese:
            "Vietnamese"
        }
    }
    
}
