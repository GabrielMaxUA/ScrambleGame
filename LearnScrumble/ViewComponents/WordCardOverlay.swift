//
//  WordCardOverlay.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-30.
//

import SwiftUI
import SwiftData

// MARK: - Flow of this file
// "My words": a tapped row grows into a card carousel over the darkened list.
//   MyWordsView passes the list, the tapped row's position, a namespace and `heroID`: the word whose row picture
//   flies into the front card on open (matchedGeometryEffect) and back into its row on close. Only that word's card
//   carries the effect, so swiping never pulls a picture out of the list; on close MyWordsView makes the front word
//   the hero first, so the picture flies back into the right row.
//   Carousel: one continuous `position` (2.4 = between the 3rd and 4th word). Every card's look comes from its
//   distance to it (CarouselCard, worked out on every frame): in front full size; the neighbours to the left and
//   right smaller, dimmed and turned away in depth (rotation3DEffect), like a turning wheel; further ones fade out.
//   The finger moves `position` directly, a release springs it to the nearest word (a flick goes one word on), so
//   the wheel turns smoothly from wherever the finger let go. The ends stretch a little and spring back.
//   Card: solid black with a thin light rim — no glass and nothing see-through, so it looks the same moving and at
//   rest (Liquid Glass turned in depth draws solid while moving and clears after it stops; a fading card shows the list
//   through it). Side cards are darkened (colorMultiply), not faded. Laid out like the game screen:
//     ✕ close (top left, where the game has the back arrow) · speaker (top right, the game's speaker button)
//     the picture (ImageComponent: report flag, no lightbulb — the hint is written below)
//     the word being learned, ⭐ when learned, its hint, right / wrong
//   Under the cards: "2 / 20" and "Swipe for the next word".
//   -> the word is read only when the speaker is tapped (not on its own when a card opens or turns: that was annoying)
//   -> swipe left / right (or tap a side card): next / previous word, the wheel turns
//   -> ✕ or a tap on the darkened background: onClose (MyWordsView animates the picture back into its row)
//   -> flag -> "Report this picture?" -> onReport (AppManager.reportSavedPicture): a new picture replaces the saved one
// Pictures are decoded once (WordImages) and shared with the list's rows, not on every frame of a swipe.

struct WordCardOverlay: View {
  let words: [SwiftDataWordModel]                        // the list as shown (hardest first)
  @Binding var index: Int                                // the front word; MyWordsView keeps it to close into the right row
  let heroID: PersistentIdentifier?                      // the word whose picture flies between its row and the card
  let namespace: Namespace.ID                            // shared with the rows' pictures
  let images: WordImages                                 // decoded pictures, shared with MyWordsView's rows
  var speak: (String) -> Void                            // MyWordsView's SpeechManager
  var onReport: (SwiftDataWordModel) async -> RequestModel.ReportResult
  var onClose: () -> Void

  @State private var report: PictureReport = .idle       // the front word's report; back to idle on the next word
  @State private var position: Double                    // the wheel: 0 = first word in front, 1.5 = between 2nd and 3rd
  @State private var dragStart: Double?                  // `position` when the finger came down; nil = not dragging

  private static let settle = Animation.spring(duration: 0.45, bounce: 0.12)   // the wheel coming to rest
  private static let buttonSize: CGFloat = 50            // the game's top-row buttons (ButtonsTopRow)
  private static let cardColor = Color.black            // the card: solid black, the rim shows its edge

  init(words: [SwiftDataWordModel], index: Binding<Int>, heroID: PersistentIdentifier?, namespace: Namespace.ID,
       images: WordImages, speak: @escaping (String) -> Void,
       onReport: @escaping (SwiftDataWordModel) async -> RequestModel.ReportResult, onClose: @escaping () -> Void) {
    self.words = words
    self._index = index
    self.heroID = heroID
    self.namespace = namespace
    self.images = images
    self.speak = speak
    self.onReport = onReport
    self.onClose = onClose
    self._position = State(initialValue: Double(index.wrappedValue))
  }

  var body: some View {
    GeometryReader { geo in
      let cardWidth = min(geo.size.width - 72, 340)      // room for the side cards to peek out
      let spacing = cardWidth * CarouselCard.sideShift   // one word further = this far to the side

      ZStack {
        Color.black.opacity(0.9)                         // dark enough to keep the card readable; the glass still shows a hint of the list
          .ignoresSafeArea()
          .onTapGesture(perform: onClose)
          .accessibilityHidden(true)

        VStack(spacing: 18) {
          Spacer(minLength: 0)
          ZStack {
            ForEach(visiblePositions, id: \.self) { item in
              let isFront = item == index
              card(for: words[item], isFront: isFront, width: cardWidth)
                .modifier(CarouselCard(distance: Double(item) - position, spacing: spacing))
                .onTapGesture { if !isFront { turn(to: item) } }   // a side card brings itself to the front
            }
          }
          .frame(maxWidth: .infinity)
          .contentShape(Rectangle())
          .gesture(
            DragGesture(minimumDistance: 12)
              .onChanged { value in
                let start = dragStart ?? position
                dragStart = start
                position = stretched(start - value.translation.width / spacing)
              }
              .onEnded { value in
                let start = dragStart ?? position
                dragStart = nil
                let flung = start - value.predictedEndTranslation.width / spacing       // where a flick would go
                let target = min(max(flung.rounded(), start.rounded() - 1), start.rounded() + 1)   // one word at a time
                turn(to: Int(min(max(target, 0), Double(words.count - 1))))
              }
          )

          VStack(spacing: 4) {
            Text("\(index + 1) / \(words.count)")
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(.white.opacity(0.7))
              .monospacedDigit()
              .contentTransition(.numericText())
            if words.count > 1 {
              Text("Swipe for the next word")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.5))
            }
          }
          Spacer(minLength: 0)
        }
      }
    }
    .onChange(of: index) { report = .idle }             // a new word: its own report state
  }

  // MARK: - visiblePositions
  // The cards drawn: two on each side of the wheel's position (the outer ones are faded out, ready to turn in).
  private var visiblePositions: [Int] {
    let low = max(0, Int(position.rounded(.down)) - 2)
    let high = min(words.count - 1, Int(position.rounded(.up)) + 2)
    return low <= high ? Array(low...high) : []
  }

  // MARK: - stretched(_:)
  // Past the first or last word the wheel moves at a third of the finger's speed, then springs back on release.
  private func stretched(_ value: Double) -> Double {
    let last = Double(words.count - 1)
    if value < 0 { return value / 3 }
    if value > last { return last + (value - last) / 3 }
    return value
  }

  // MARK: - turn(to:)
  // Springs the wheel to a word (swipe release or side-card tap) and makes it the front word.
  private func turn(to item: Int) {
    withAnimation(Self.settle) {
      position = Double(item)
      index = item
    }
  }

  // MARK: - card(for:isFront:width:)
  // One word's card: buttons, picture, word, hint, right / wrong. Side cards look the same but can't be used.
  private func card(for word: SwiftDataWordModel, isFront: Bool, width: CGFloat) -> some View {
    VStack(spacing: 14) {
      HStack {                                           // close left, speaker right — as the game's top row
        circleButton("xmark", label: "Close", action: onClose)
        Spacer()
        circleButton("speaker.wave.2.fill", label: "Say the word") { speak(word.targetWord) }
      }

      if isFront && word.persistentModelID == heroID {   // only the hero's picture flies to and from its row
        ImageComponent(image: images.image(for: word), hint: word.originWord, showsHint: false, framed: false,
                       report: report, onReport: { Task { await sendReport(for: word) } },
                       maxSide: width - 32)
          .matchedGeometryEffect(id: word.persistentModelID, in: namespace)
      } else if isFront {
        ImageComponent(image: images.image(for: word), hint: word.originWord, showsHint: false, framed: false,
                       report: report, onReport: { Task { await sendReport(for: word) } },
                       maxSide: width - 32)
      } else {
        ImageComponent(image: images.image(for: word), hint: word.originWord, showsHint: false, framed: false,
                       maxSide: width - 32)
      }

      VStack(spacing: 6) {
        HStack(spacing: 8) {
          Text(verbatim: word.targetWord)
            .font(.title.bold())
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.6)
            .lineLimit(2)
          if word.isLearned {
            Image(systemName: "star.fill")
              .font(.title3)
              .foregroundStyle(.yellow)
              .accessibilityLabel(Text("Learned"))
          }
        }
        Text(verbatim: word.originWord)
          .font(.title3)
          .foregroundStyle(.white.opacity(0.7))
          .multilineTextAlignment(.center)
          .lineLimit(2)
        HStack(spacing: 18) {
          count(word.correct, icon: "checkmark.circle.fill", tint: .green, label: "Right")
          count(word.incorrect, icon: "xmark.circle.fill", tint: .red, label: "Wrong")
        }
        .padding(.top, 4)
      }
    }
    .padding(16)
    .frame(width: width)
    .background(Self.cardColor, in: RoundedRectangle(cornerRadius: 26))   // solid, the same moving and at rest
    .overlay {                                           // a light rim, so the black card's edge shows on the dark backdrop
      RoundedRectangle(cornerRadius: 26)
        .stroke(.white.opacity(0.25), lineWidth: 1)
    }
    .compositingGroup()                                  // one flat layer: darkens and fades as a whole (CarouselCard)
    .allowsHitTesting(isFront)                           // side cards: only the tap that brings them forward (above)
    .accessibilityHidden(!isFront)
  }

  // MARK: - sendReport(for:)
  // The flag: sends the report; a new picture replaces the saved one on the phone (SwiftData), so the list and the
  // review show it too. The outcome shows as a note on the picture (ImageComponent).
  private func sendReport(for word: SwiftDataWordModel) async {
    guard report == .idle || report == .failed else { return }
    let shownIndex = index
    report = .sending
    let result = await onReport(word)
    guard index == shownIndex else { return }            // swiped away meanwhile
    switch result {
    case .newPicture(let data, let link):
      word.imageData = data
      word.imageURL = link
      images.forget(word)                                // decode the new picture next time
      try? PersistenceController.shared.context.save()
      report = .redrawn
    case .received: report = .received
    case .tooMany:  report = .tooMany
    case .failed:   report = .failed
    }
  }

  // MARK: - circleButton(_:label:action:)
  // A 50×50 round button, white SF Symbol on a flat grey circle — the size of the game's top-row buttons, but not
  // glass (glass draws a ring and changes as the card turns).
  private func circleButton(_ icon: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: icon)
        .frame(width: Self.buttonSize, height: Self.buttonSize)
        .foregroundStyle(.white)
        .background(.white.opacity(0.14), in: Circle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(Text(label))
  }

  // MARK: - count(_:icon:tint:label:)
  private func count(_ value: Int, icon: String, tint: Color, label: LocalizedStringKey) -> some View {
    HStack(spacing: 4) {
      Image(systemName: icon)
        .foregroundStyle(tint)
        .accessibilityLabel(Text(label))
      Text(value, format: .number)
        .foregroundStyle(.white)
        .monospacedDigit()
    }
    .font(.headline)
  }
}

// MARK: - CarouselCard
// Places one card on the wheel from its distance to the wheel's position (0 = in front, -1 = one word to the left,
// 0.5 = halfway to the right). Animatable, so a spring recomputes everything on every frame: the card slides, grows,
// turns and brightens together, from wherever the finger let go.
struct CarouselCard: ViewModifier, Animatable {
  var distance: Double
  let spacing: CGFloat                                   // one word further = this far to the side

  static let sideShift: CGFloat = 0.74                   // a neighbour's center, in card widths from the middle
  private static let sideAngle: Double = 32              // how far a neighbour is turned away (degrees)
  private static let sideScale: Double = 0.82            // neighbours are smaller…
  private static let sideBrightness: Double = 0.45       // …and darker (colorMultiply: the black card stays black)

  var animatableData: Double {
    get { distance }
    set { distance = newValue }
  }

  func body(content: Content) -> some View {
    let away = abs(distance)
    let near = min(away, 1)                              // 0 in front … 1 a neighbour (and beyond)
    let brightness = 1 - (1 - Self.sideBrightness) * near   // front -> neighbour: darkens, stays solid
    let opacity = max(0, min(1, 2 - away))               // only past a neighbour: fades out (two away = gone)
    content
      .colorMultiply(Color(white: brightness))
      .scaleEffect(1 - (1 - Self.sideScale) * near)
      .rotation3DEffect(.degrees(max(-1, min(1, distance)) * Self.sideAngle),
                        axis: (x: 0, y: 1, z: 0),
                        anchor: distance >= 0 ? .leading : .trailing,   // turns on the edge facing the middle, so the
                        perspective: 0.6)                               // outer edge goes back, not toward the user;
                                                                        // the switch is at 0°, so it can't jump
      .opacity(opacity)
      .offset(x: CGFloat(distance) * spacing)
      .zIndex(-away)                                     // the nearest card on top
  }
}

// MARK: - WordImages
// The words' pictures, decoded once per open My words screen (SwiftDataWordModel.image decodes the stored data on
// every call). MyWordsView's rows and the cards share it; a reported picture is forgotten and decoded again.
final class WordImages {
  private var cache: [PersistentIdentifier: UIImage] = [:]

  func image(for word: SwiftDataWordModel) -> UIImage? {
    if let image = cache[word.persistentModelID] { return image }
    let image = word.image
    cache[word.persistentModelID] = image
    return image
  }

  func forget(_ word: SwiftDataWordModel) {
    cache[word.persistentModelID] = nil
  }
}
