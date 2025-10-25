//
//  SelectableMessageText.swift
//  MessageAI
//
//  Custom text view with AI-powered text selection menu
//

import SwiftUI
import UIKit

struct SelectableMessageText: UIViewRepresentable {
    let text: String
    let isFromCurrentUser: Bool
    let onSummarize: (String) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> UITextView {
        let textView = CustomMenuTextView()
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.textContainer.widthTracksTextView = true
        textView.textContainer.maximumNumberOfLines = 0 // No line limit
        textView.font = .systemFont(ofSize: 17)
        textView.dataDetectorTypes = [.link, .phoneNumber, .address]
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        
        // Set text color based on sender
        textView.textColor = isFromCurrentUser ? .white : .label
        textView.tintColor = isFromCurrentUser ? .white : .systemBlue
        
        // Configure the custom menu handler
        if let customTextView = textView as? CustomMenuTextView {
            customTextView.onSummarize = onSummarize
        }
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        // Only update if text actually changed to avoid layout loops
        guard uiView.text != text else { return }
        
        uiView.text = text
        uiView.textColor = isFromCurrentUser ? .white : .label
        uiView.tintColor = isFromCurrentUser ? .white : .systemBlue
        
        if let customTextView = uiView as? CustomMenuTextView {
            customTextView.onSummarize = onSummarize
        }
    }
    
    class Coordinator {
        // Coordinator to manage text view state
    }
}

// MARK: - Custom UITextView with Menu Customization

class CustomMenuTextView: UITextView {
    var onSummarize: ((String) -> Void)?
    
    override var intrinsicContentSize: CGSize {
        // Calculate the size needed to display all text
        let textWidth = bounds.width > 0 ? bounds.width : 300 // Fallback width
        let size = sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude))
        return CGSize(width: UIView.noIntrinsicMetric, height: ceil(size.height))
    }
    
    override var text: String! {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }
    
    override var bounds: CGRect {
        didSet {
            if bounds.width != oldValue.width {
                invalidateIntrinsicContentSize()
            }
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        invalidateIntrinsicContentSize()
    }
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        // Add our custom action to the menu
        if action == #selector(summarizeText(_:)) {
            // Only show if selection is more than 100 words
            if let selectedRange = self.selectedTextRange,
               !selectedRange.isEmpty {
                let selectedText = self.text(in: selectedRange) ?? ""
                let wordCount = selectedText.components(separatedBy: .whitespacesAndNewlines)
                    .filter { !$0.isEmpty }.count
                return wordCount > 100
            }
            return false
        }
        
        // Keep default actions
        return super.canPerformAction(action, withSender: sender)
    }
    
    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)
        
        // Add custom menu item
        let summarizeCommand = UIKeyCommand(
            title: "Summarize",
            action: #selector(summarizeText(_:)),
            input: ""
        )
        
        let summarizeMenu = UIMenu(
            title: "",
            options: .displayInline,
            children: [summarizeCommand]
        )
        
        builder.insertChild(summarizeMenu, atStartOfMenu: .standardEdit)
    }
    
    @objc private func summarizeText(_ sender: Any?) {
        guard let selectedRange = self.selectedTextRange,
              !selectedRange.isEmpty else {
            return
        }
        
        let selectedText = self.text(in: selectedRange) ?? ""
        onSummarize?(selectedText)
        
        // Clear selection after action
        self.selectedTextRange = nil
    }
}

// MARK: - Preview Support

#Preview {
    VStack {
        SelectableMessageText(
            text: "This is a long message that can be selected. " + String(repeating: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. ", count: 30),
            isFromCurrentUser: false,
            onSummarize: { text in
                print("Summarize: \(text)")
            }
        )
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray5))
        .cornerRadius(16)
        .padding()
    }
}

