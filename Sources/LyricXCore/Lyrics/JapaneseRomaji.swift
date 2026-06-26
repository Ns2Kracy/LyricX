import Foundation

public enum JapaneseRomaji {
    public static func romanizedText(for text: String) -> String? {
        guard containsJapanese(text) else {
            return nil
        }

        let characters = Array(text)
        var tokens: [String] = []
        var index = 0

        while index < characters.count {
            let character = characters[index]

            if character.isWhitespace {
                tokens.append(" ")
                index += 1
            } else if character == "っ" || character == "ッ" {
                guard let next = romanizedKanaUnit(in: characters, at: index + 1),
                      let consonant = next.first,
                      !"aeiou".contains(consonant)
                else {
                    return nil
                }
                tokens.append(String(consonant))
                index += 1
            } else if character == "ー" {
                guard let vowel = lastVowel(in: tokens) else {
                    return nil
                }
                tokens.append(String(vowel))
                index += 1
            } else if let romanizedKana = romanizedKanaUnit(in: characters, at: index) {
                tokens.append(romanizedKana)
                index += isYoonStart(in: characters, at: index) ? 2 : 1
            } else if containsJapanese(String(character)) {
                return nil
            } else {
                tokens.append(String(character))
                index += 1
            }
        }

        let romanized = tokens.joined()
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return romanized.nilIfBlank
    }

    public static func containsJapanese(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x3040...0x30FF).contains(Int(scalar.value)) ||
            (0x4E00...0x9FFF).contains(Int(scalar.value))
        }
    }

    private static func romanizedKanaUnit(in characters: [Character], at index: Int) -> String? {
        guard characters.indices.contains(index) else {
            return nil
        }

        if isYoonStart(in: characters, at: index) {
            return yoonMap[String(characters[index]) + String(characters[index + 1])]
        }

        return kanaMap[characters[index]]
    }

    private static func isYoonStart(in characters: [Character], at index: Int) -> Bool {
        characters.indices.contains(index + 1) && yoonMap[String(characters[index]) + String(characters[index + 1])] != nil
    }

    private static func lastVowel(in tokens: [String]) -> Character? {
        tokens.reversed().lazy.compactMap { token in
            token.reversed().first { "aeiou".contains($0) }
        }.first
    }

    private static let kanaMap: [Character: String] = [
        "あ": "a", "い": "i", "う": "u", "え": "e", "お": "o",
        "か": "ka", "き": "ki", "く": "ku", "け": "ke", "こ": "ko",
        "さ": "sa", "し": "shi", "す": "su", "せ": "se", "そ": "so",
        "た": "ta", "ち": "chi", "つ": "tsu", "て": "te", "と": "to",
        "な": "na", "に": "ni", "ぬ": "nu", "ね": "ne", "の": "no",
        "は": "ha", "ひ": "hi", "ふ": "fu", "へ": "he", "ほ": "ho",
        "ま": "ma", "み": "mi", "む": "mu", "め": "me", "も": "mo",
        "や": "ya", "ゆ": "yu", "よ": "yo",
        "ら": "ra", "り": "ri", "る": "ru", "れ": "re", "ろ": "ro",
        "わ": "wa", "を": "wo", "ん": "n",
        "が": "ga", "ぎ": "gi", "ぐ": "gu", "げ": "ge", "ご": "go",
        "ざ": "za", "じ": "ji", "ず": "zu", "ぜ": "ze", "ぞ": "zo",
        "だ": "da", "ぢ": "ji", "づ": "zu", "で": "de", "ど": "do",
        "ば": "ba", "び": "bi", "ぶ": "bu", "べ": "be", "ぼ": "bo",
        "ぱ": "pa", "ぴ": "pi", "ぷ": "pu", "ぺ": "pe", "ぽ": "po",
        "ア": "a", "イ": "i", "ウ": "u", "エ": "e", "オ": "o",
        "カ": "ka", "キ": "ki", "ク": "ku", "ケ": "ke", "コ": "ko",
        "サ": "sa", "シ": "shi", "ス": "su", "セ": "se", "ソ": "so",
        "タ": "ta", "チ": "chi", "ツ": "tsu", "テ": "te", "ト": "to",
        "ナ": "na", "ニ": "ni", "ヌ": "nu", "ネ": "ne", "ノ": "no",
        "ハ": "ha", "ヒ": "hi", "フ": "fu", "ヘ": "he", "ホ": "ho",
        "マ": "ma", "ミ": "mi", "ム": "mu", "メ": "me", "モ": "mo",
        "ヤ": "ya", "ユ": "yu", "ヨ": "yo",
        "ラ": "ra", "リ": "ri", "ル": "ru", "レ": "re", "ロ": "ro",
        "ワ": "wa", "ヲ": "wo", "ン": "n",
        "ガ": "ga", "ギ": "gi", "グ": "gu", "ゲ": "ge", "ゴ": "go",
        "ザ": "za", "ジ": "ji", "ズ": "zu", "ゼ": "ze", "ゾ": "zo",
        "ダ": "da", "ヂ": "ji", "ヅ": "zu", "デ": "de", "ド": "do",
        "バ": "ba", "ビ": "bi", "ブ": "bu", "ベ": "be", "ボ": "bo",
        "パ": "pa", "ピ": "pi", "プ": "pu", "ペ": "pe", "ポ": "po",
        "ぁ": "a", "ぃ": "i", "ぅ": "u", "ぇ": "e", "ぉ": "o",
        "ァ": "a", "ィ": "i", "ゥ": "u", "ェ": "e", "ォ": "o",
        "ヴ": "vu"
    ]

    private static let yoonMap: [String: String] = [
        "きゃ": "kya", "きゅ": "kyu", "きょ": "kyo",
        "しゃ": "sha", "しゅ": "shu", "しょ": "sho",
        "ちゃ": "cha", "ちゅ": "chu", "ちょ": "cho",
        "にゃ": "nya", "にゅ": "nyu", "にょ": "nyo",
        "ひゃ": "hya", "ひゅ": "hyu", "ひょ": "hyo",
        "みゃ": "mya", "みゅ": "myu", "みょ": "myo",
        "りゃ": "rya", "りゅ": "ryu", "りょ": "ryo",
        "ぎゃ": "gya", "ぎゅ": "gyu", "ぎょ": "gyo",
        "じゃ": "ja", "じゅ": "ju", "じょ": "jo",
        "びゃ": "bya", "びゅ": "byu", "びょ": "byo",
        "ぴゃ": "pya", "ぴゅ": "pyu", "ぴょ": "pyo",
        "キャ": "kya", "キュ": "kyu", "キョ": "kyo",
        "シャ": "sha", "シュ": "shu", "ショ": "sho",
        "チャ": "cha", "チュ": "chu", "チョ": "cho",
        "ニャ": "nya", "ニュ": "nyu", "ニョ": "nyo",
        "ヒャ": "hya", "ヒュ": "hyu", "ヒョ": "hyo",
        "ミャ": "mya", "ミュ": "myu", "ミョ": "myo",
        "リャ": "rya", "リュ": "ryu", "リョ": "ryo",
        "ギャ": "gya", "ギュ": "gyu", "ギョ": "gyo",
        "ジャ": "ja", "ジュ": "ju", "ジョ": "jo",
        "ビャ": "bya", "ビュ": "byu", "ビョ": "byo",
        "ピャ": "pya", "ピュ": "pyu", "ピョ": "pyo",
        "ティ": "ti", "ディ": "di",
        "ファ": "fa", "フィ": "fi", "フェ": "fe", "フォ": "fo",
        "ヴァ": "va", "ヴィ": "vi", "ヴェ": "ve", "ヴォ": "vo"
    ]
}
