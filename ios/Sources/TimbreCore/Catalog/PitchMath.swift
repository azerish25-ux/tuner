import Foundation

public enum PitchMath {
    public static func frequency(midi: Double, reference: Double = 440) -> Double { reference * pow(2, (midi - 69) / 12) }
    public static func midi(frequency: Double, reference: Double = 440) -> Double { 69 + 12 * log2(frequency / reference) }
    public static func cents(target: Double, measured: Double) -> Double { 1200 * log2(measured / target) }
    public static func ratio(cents: Double) -> Double { pow(2, cents / 1200) }
    public static func pitchClass(midi: Int) -> Int { ((midi % 12) + 12) % 12 }
    public static func noteName(midi: Int, notation: String = "english") -> String {
        let pc = pitchClass(midi: midi)
        let octave = Int(floor(Double(midi) / 12)) - 1
        let scientific = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
        let table: [String]
        switch notation.lowercased() {
        case "german": table = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","H"]
        case "solfege": table = ["Do","Do#","Re","Re#","Mi","Fa","Fa#","Sol","Sol#","La","La#","Si"]
        case "sargam": table = ["Sa","Sa#","Re","Re#","Ga","Ma","Ma#","Pa","Pa#","Dha","Dha#","Ni"]
        case "numbered": table = ["1","1#","2","2#","3","4","4#","5","5#","6","6#","7"]
        default: table = scientific
        }
        return table[pc] + String(octave)
    }
    public static func parseNote(_ name: String) -> Int? {
        let names = ["C":0,"C#":1,"Db":1,"D":2,"D#":3,"Eb":3,"E":4,"F":5,"F#":6,"Gb":6,"G":7,"G#":8,"Ab":8,"A":9,"A#":10,"Bb":10,"B":11]
        let text = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = String(text.prefix(while: { $0.isLetter || $0 == "#" }))
        guard let pc = names[prefix], let octave = Int(text.dropFirst(prefix.count)) else { return nil }
        return (octave + 1) * 12 + pc
    }
}

/// Retains Android's shipped prototype offset tables and letter-relative degree rule.
/// Non-equal presets are approximations, not independently verified historical tunings.
public struct Temperament: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let name: String
    public let offsetsCents: [Double]
    public var isEqual: Bool { offsetsCents.allSatisfy { $0 == 0 } }
    public func offsetCents(midi: Int, letterName: String? = nil) -> Double {
        let pc = PitchMath.pitchClass(midi: midi)
        let natural = [0,0,2,2,4,5,5,7,7,9,9,11]
        let letterPC: [Character:Int] = ["C":0,"D":2,"E":4,"F":5,"G":7,"A":9,"B":11]
        let tonic = letterName?.first.flatMap { letterPC[$0] } ?? natural[pc]
        return offsetsCents[(pc - tonic + 12) % 12]
    }
    public func frequency(midi: Int, reference: Double = 440, letterName: String? = nil) -> Double {
        PitchMath.frequency(midi: Double(midi), reference: reference) * PitchMath.ratio(cents: offsetCents(midi: midi, letterName: letterName))
    }
    public static let equal = Temperament(id: "equal", name: "Equal", offsetsCents: Array(repeating: 0, count: 12))
    public static let just = Temperament(id: "just", name: "Just", offsetsCents: [0,11.7,3.9,-13.7,-2,-31,-13.7,2,17.6,-15.6,9.8,-11.7])
    public static let pythagorean = Temperament(id: "pythagorean", name: "Pythagorean", offsetsCents: [-6,6,4,-8,2,-10,4,2,8,-4,6,-2])
    public static let meantone = Temperament(id: "meantone", name: "Meantone", offsetsCents: [0,-8,4,-6,2,-16,-6,0,8,-8,6,-4])
    public static let werckmeister = Temperament(id: "werckmeister", name: "Werckmeister", offsetsCents: [0,-10,-8,-6,-10,-2,-12,-4,-8,-8,-6,-10])
    public static let all: [Temperament] = [equal,just,pythagorean,meantone,werckmeister]
    public static func byId(_ id: String) -> Temperament { all.first { $0.id == id } ?? .equal }
}
