//
//  GuessedLettersRow.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-25.
//

import SwiftUI

// MARK: - Flow of this file
// Lays out the answer slots for ALL words of the answer, so every slot shares one size
// and word breaks stay obvious:
//   - short words can share a line, separated by a slot-wide gap
//   - each new word gets a clearly bigger vertical gap than a wrapped line of the same word
//   - a word too long for one line is split evenly and ends its broken lines with a dim "-"
//   MainView passes WordVM's segmentRanges (where each word starts/ends) + guessedWord (placed letters)
//   -> layout() picks one slot size and splits the slots into lines -> body draws a GuessedLetterView per slot
//   -> tapping a placed letter -> onDeselect -> WordVM.deselectLetter puts it back in the tray.
struct GuessedLettersRow: View {
  let segments: [Range<Int>]       // vm.segmentRanges, one range per word
  let guessedWord: [LetterModel?]  // one entry per slot; nil = still empty
  let width: CGFloat               // contentWidth from MainView (side padding already removed)
  let isDimmed: Bool               // vm.overlayShown
  let onDeselect: (LetterModel) -> Void // vm.deselectLetter
  
  private let maxSlot: CGFloat = 30      // default slot size, short words never grow past this
  private let minSlot: CGFloat = 22      // below this letters get hard to read -> wrap onto another line instead
  private let gapRatio: CGFloat = 0.2    // gap between slots, as a fraction of slot size
  private let wordGapRatio: CGFloat = 1  // horizontal gap between two words on one line: one empty slot
  private let hyphenRatio: CGFloat = 0.5 // width of the "-" shown at the end of a broken word's line
  private let wordLineGap: CGFloat = 0.8 // vertical gap before a line that starts a new word
  private let wrapLineGap: CGFloat = 0.25 // vertical gap before a line that continues the same word
  
  private struct Piece: Hashable {   // one word (or one part of a split word) on a line
    let slots: [Int]      // indices into guessedWord
    let continues: Bool   // true when the word goes on to the next line
  }
  
  private struct Line {              // one row of slots
    let pieces: [Piece]     // the words / word parts on this row
    let startsNewWord: Bool // false only for the 2nd+ line of a split word
  }
  
  var body: some View {
    let (slot, lines) = layout()                                   // slot size + rows, worked out below
    
    VStack(spacing: 0) {
      ForEach(Array(lines.enumerated()), id: \.offset) { lineIndex, line in
        HStack(spacing: slot * wordGapRatio) {
          ForEach(line.pieces, id: \.self) { piece in
            HStack(spacing: slot * gapRatio) {
              ForEach(piece.slots, id: \.self) { slotIndex in
                let letter = slotIndex < guessedWord.count ? guessedWord[slotIndex] : nil
                GuessedLetterView(letter: letter, size: slot) { onDeselect($0) }
              }
              if piece.continues {                                   // word goes on next line: dim "-"
                Text("-")
                  .font(.system(size: slot * 0.75))
                  .frame(width: slot * hyphenRatio, height: slot * 1.5)
                  .opacity(0.5)
                  .accessibilityHidden(true)
              }
            }
          }
        }
        .padding(.top, lineIndex == 0 ? 0 : slot * (line.startsNewWord ? wordLineGap : wrapLineGap))   // bigger gap before a new word than before a wrapped line
      }
    }
    .foregroundStyle(isDimmed ? .white.opacity(0.05) : .white)     // almost hidden while the answer result shows
  }
  
  // MARK: - Layout math (all widths in "slot units", i.e. multiples of the slot size)
  
  // MARK: - units(_:)
  // Width of `count` slots with gaps between them, in slot units.
  private func units(_ count: Int) -> CGFloat {
    CGFloat(count) + CGFloat(max(count - 1, 0)) * gapRatio
  }
  
  // MARK: - fittingSlot(_:hyphen:)
  // Widest slot that fits `count` slots on one line (plus room for the "-" when the word continues).
  private func fittingSlot(_ count: Int, hyphen: Bool) -> CGFloat {
    width / (units(max(count, 1)) + (hyphen ? gapRatio + hyphenRatio : 0))
  }
  
  // MARK: - lineCount(for:)
  // How many lines a word needs: 1 if it fits readably as a whole, otherwise the fewest even split that does.
  // Readable = slot at least minSlot. Tries 2, 3… lines (letters spread evenly) until each line fits.
  private func lineCount(for count: Int) -> Int {
    guard fittingSlot(count, hyphen: false) < minSlot else { return 1 }
    var lines = 1
    var perLine = count
    repeat {
      lines += 1
      perLine = Int((Double(count) / Double(lines)).rounded(.up))
    } while fittingSlot(perLine, hyphen: true) < minSlot && perLine > 1
    return lines
  }
  
  // MARK: - layout
  // No letters at all -> default slot, no lines.
  // 1. One slot size for the whole answer: the largest size where every word that CAN stay whole does,
  //    and every word that can't is split as little as possible.
  // 2. Build lines: whole words are packed together when they fit, split words get their own lines.
  //    - whole word fits after the words already on the line (with a word gap) -> joins that line
  //    - otherwise the current line is closed and the word starts a new one
  //    - a split word closes the current line, then its parts go on their own lines, balanced
  //      (e.g. 15 -> 8 + 7); every part except the last is marked `continues` (gets the "-")
  // Returns the slot size and the finished lines.
  private func layout() -> (slot: CGFloat, lines: [Line]) {
    guard segments.contains(where: { !$0.isEmpty }) else { return (maxSlot, []) }
    
    var slot = maxSlot
    for segment in segments where !segment.isEmpty {
      let lines = lineCount(for: segment.count)
      let perLine = Int((Double(segment.count) / Double(lines)).rounded(.up))
      slot = min(slot, fittingSlot(perLine, hyphen: lines > 1))
    }
    
    let lineUnits = width / slot
    var lines: [Line] = []
    var current: [Piece] = []
    var currentUnits: CGFloat = 0
    
    for segment in segments where !segment.isEmpty {
      let indices = Array(segment)
      let chunkCount = lineCount(for: indices.count)
      if chunkCount == 1 {
        let needed = units(indices.count)
        if !current.isEmpty, currentUnits + wordGapRatio + needed <= lineUnits {
          current.append(Piece(slots: indices, continues: false))
          currentUnits += wordGapRatio + needed
        } else {
          if !current.isEmpty { lines.append(Line(pieces: current, startsNewWord: true)) }
          current = [Piece(slots: indices, continues: false)]
          currentUnits = needed
        }
      } else {
        if !current.isEmpty { lines.append(Line(pieces: current, startsNewWord: true)) }
        current = []
        currentUnits = 0
        let perChunk = Int((Double(indices.count) / Double(chunkCount)).rounded(.up))
        let starts = Array(stride(from: 0, to: indices.count, by: perChunk))
        for (n, start) in starts.enumerated() {
          let chunk = Array(indices[start..<min(start + perChunk, indices.count)])
          lines.append(Line(pieces: [Piece(slots: chunk, continues: n < starts.count - 1)],
                            startsNewWord: n == 0))
        }
      }
    }
    if !current.isEmpty { lines.append(Line(pieces: current, startsNewWord: true)) }
    return (slot, lines)
  }
}

// MARK: - previewGuess(_:filled:)
// Previews only. Builds a guess where the first `filled` slots hold letters of `answer` (spaces skipped),
// the rest are empty, plus the per-word ranges — the same shapes WordVM gives MainView.
private func previewGuess(_ answer: String, filled: Int) -> (segments: [Range<Int>], guess: [LetterModel?]) {
  var segments: [Range<Int>] = []
  var cursor = 0
  for word in answer.split(separator: " ") {
    segments.append(cursor..<(cursor + word.count))
    cursor += word.count
  }
  let letters = answer.filter { $0 != " " }
  let guess = letters.enumerated().map { i, ch in
    i < filled ? LetterModel(id: i, letter: String(ch), isUsed: true) : nil
  }
  return (segments, guess)
}

#Preview {
  // 353 = iPhone width (393) minus MainView's 20pt side padding
  let samples = ["hammer", "measuringtape", "go to work", "measuring tape", "Kreuzschlitz schraubendreher", "Rohrleitungsdichtungsmittel"]
  ScrollView {
    VStack(spacing: 28) {
      ForEach(samples, id: \.self) { answer in
        let data = previewGuess(answer, filled: max(answer.count - 6, 1))
        VStack(spacing: 6) {
          Text(answer).font(.caption).foregroundStyle(.gray)
          GuessedLettersRow(segments: data.segments, guessedWord: data.guess,
                            width: 353, isDimmed: false, onDeselect: { _ in })
        }
      }
    }
    .frame(width: 353)
    .padding(.horizontal, 20)
    .padding(.vertical)
  }
  .background(.black)
}
