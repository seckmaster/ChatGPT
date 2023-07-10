//
//  TextView.swift
//  ChatGPT
//
//  Created by Toni K. Turk on 08/06/2023.
//

import SwiftUI
#if os(iOS)
import UIKit

typealias ViewRepresentable = UIViewRepresentable
typealias OldSchoolScrollView = UIScrollView
typealias OldSchoolTextView = UITextView
typealias OldSchoolTextViewDelegate = UITextViewDelegate
typealias OldSchoolColor = UIColor
#elseif os(macOS)
import AppKit

typealias ViewRepresentable = NSViewRepresentable
typealias OldSchoolScrollView = NSScrollView
typealias OldSchoolTextView = NSTextView
typealias OldSchoolTextViewDelegate = NSTextViewDelegate
typealias OldSchoolColor = NSColor
#endif

struct TextView<ViewModel: EditingViewModel>: ViewRepresentable {
  @Binding var text: AttributedString
  weak var delegate: TextViewDelegate<ViewModel>?
  
#if os(macOS)
  func makeNSView(context: Context) -> OldSchoolTextView {
    let textView = OldSchoolTextView()
    textView.backgroundColor = .clear
    delegate?.textView = textView
    updateNSView(textView, context: context)
    return textView
  }
  
  func updateNSView(_ textView: OldSchoolTextView, context: Context) {
    let attributedString = NSAttributedString(text)
    let ranges = textView.selectedRanges
    textView.delegate = nil
    textView.textStorage!.setAttributedString(attributedString)
    textView.selectedRanges = ranges
    textView.delegate = delegate
  }
#elseif os(iOS)
  func makeUIView(context: Context) -> OldSchoolTextView {
    let textView = OldSchoolTextView()
    delegate?.textView = textView
    updateUIView(textView, context: context)
    return textView
  } 
  
  func updateUIView(_ textView: OldSchoolTextView, context: Context) {
    guard delegate?.viewModel.text != text else { return }
    
    let scroll = textView.contentOffset
    let attributedString = NSAttributedString(text)
    let range = textView.selectedRange
    
    textView.delegate = nil
    textView.attributedText = attributedString
    textView.selectedRange = range
    textView.setContentOffset(scroll, animated: false)
    textView.delegate = delegate
    delegate?.text = text
    delegate?.viewModel.updateDocument()
  }
#endif
}

protocol EditingViewModel: ObservableObject {
  var isBoldHighlighted: Bool { get set }
  var isItalicHighlighted: Bool { get set }
  var isUnderlineHighlighted: Bool { get set }
  var isHeading1: Bool { get set }
  var isHeading2: Bool { get set }
  var isHeading3: Bool { get set }
  var selectedRanges: [NSRange] { get set }
  var text: AttributedString { get set }
  func update()
}

class TextViewDelegate<ViewModel: EditingViewModel>: NSObject, OldSchoolTextViewDelegate {
  let viewModel: ViewModel
  weak var textView: OldSchoolTextView?
  
  init(viewModel: ViewModel) {
    self.viewModel = viewModel
  }
  
#if os(macOS)
  func textView(_ textView: NSTextView, shouldChangeTextInRanges affectedRanges: [NSValue], replacementStrings: [String]?) -> Bool {
    guard let replacementStrings else { return true }
    guard let range = affectedRanges.first as? NSRange else { return true }
    guard let replacement = replacementStrings.first else { return true }
   
    guard let convertedRange = Range(range, in: self.viewModel.text) else { return true }
    self.viewModel.text.replaceSubrange(
      convertedRange, 
      with: AttributedString(replacement)
    )
    self.viewModel.update()
    
    textView.selectedRanges = [range as NSValue]
    return true
  }
#endif
}

extension String {
  func character(at index: Int) -> String.Element? {
    guard index >= 0 && index < utf16.count else { return nil }
    return self[self.index(startIndex, offsetBy: index)]
  }
}

extension NSMutableAttributedString {
  func setRichTextAttributes(
    _ attributes: [NSAttributedString.Key: Any],
    at range: NSRange
  ) {
    let range = safeRange(for: range)
    let string = self
    string.beginEditing()
    attributes.forEach { attribute, newValue in
      string.enumerateAttribute(attribute, in: range, options: .init()) { _, range, _ in
        string.removeAttribute(attribute, range: range)
        string.addAttribute(attribute, value: newValue, range: range)
        string.fixAttributes(in: range)
      }
    }
    string.endEditing()
  }
  
  func safeRange(for range: NSRange) -> NSRange {
    let length = self.length
    return NSRange(
      location: max(0, min(length-1, range.location)),
      length: min(range.length, max(0, length - range.location))
    )
  }
}

class Box<T> {
  var value: T
  
  init(value: T) {
    self.value = value
  }
}
