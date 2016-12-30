g//
//  TextField.swift
//  PhoneNumberKit
//
//  Created by Roy Marmelstein on 07/11/2015.
//  Copyright © 2015 Roy Marmelstein. All rights reserved.
//

import Foundation
import UIKit

open class PhoneNumberTextFieldDelegate: NSObject, UITextFieldDelegate {
    
    weak open var delegate: UITextFieldDelegate?
    
    let phoneNumberKit = PhoneNumberKit()
    let partialFormatter: PartialFormatter
    
    private let nonNumericSet: NSCharacterSet = {
        var mutableSet = NSMutableCharacterSet.decimalDigit().inverted
        mutableSet.remove(charactersIn: PhoneNumberConstants.plusChars)
        return mutableSet as NSCharacterSet
    }()
    
    override init() {
        self.partialFormatter = PartialFormatter(phoneNumberKit: self.phoneNumberKit,
                                                 defaultRegion: PhoneNumberKit.defaultRegionCode(),
                                                 withPrefix: true)
        super.init()
    }
    
    // MARK: Phone number formatting
    
    /**
     *  To keep the cursor position, we find the character immediately after the cursor and count the number of times it repeats in the remaining string as this will remain constant in every kind of editing.
     */
    
    private struct CursorPosition {
        let numberAfterCursor: String
        let repetitionCountFromEnd: Int
    }
    
    private func extractCursorPosition(textField: UITextField) -> CursorPosition? {
        var repetitionCountFromEnd = 0
        // Check that there is text in the UITextField
        guard let text = textField.text, let selectedTextRange = textField.selectedTextRange else {
            return nil
        }
        let textAsNSString = text as NSString
        let cursorEnd = textField.offset(from: textField.beginningOfDocument, to: selectedTextRange.end)
        // Look for the next valid number after the cursor, when found return a CursorPosition struct
        for i in cursorEnd ..< textAsNSString.length  {
            let cursorRange = NSMakeRange(i, 1)
            let candidateNumberAfterCursor: NSString = textAsNSString.substring(with: cursorRange) as NSString
            if (candidateNumberAfterCursor.rangeOfCharacter(from: nonNumericSet as CharacterSet).location == NSNotFound) {
                for j in cursorRange.location ..< textAsNSString.length  {
                    let candidateCharacter = textAsNSString.substring(with: NSMakeRange(j, 1))
                    if candidateCharacter == candidateNumberAfterCursor as String {
                        repetitionCountFromEnd += 1
                    }
                }
                return CursorPosition(numberAfterCursor: candidateNumberAfterCursor as String, repetitionCountFromEnd: repetitionCountFromEnd)
            }
        }
        return nil
    }
    
    // Finds position of previous cursor in new formatted text
    private func selectionRangeForNumberReplacement(textField: UITextField, formattedText: String) -> NSRange? {
        let textAsNSString = formattedText as NSString
        var countFromEnd = 0
        guard let cursorPosition = extractCursorPosition(textField: textField) else {
            return nil
        }
        
        for i in stride(from: (textAsNSString.length - 1), through: 0, by: -1) {
            let candidateRange = NSMakeRange(i, 1)
            let candidateCharacter = textAsNSString.substring(with: candidateRange)
            if candidateCharacter == cursorPosition.numberAfterCursor {
                countFromEnd += 1
                if countFromEnd == cursorPosition.repetitionCountFromEnd {
                    return candidateRange
                }
            }
        }
        
        return nil
    }
    
    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let text = textField.text else {
            return false
        }
        
        // allow delegate to intervene
        guard delegate?.textField?(textField, shouldChangeCharactersIn: range, replacementString: string) ?? true else {
            return false
        }
        
        let textAsNSString = text as NSString
        let changedRange = textAsNSString.substring(with: range) as NSString
        let modifiedTextField = textAsNSString.replacingCharacters(in: range, with: string)
        let formattedNationalNumber = partialFormatter.formatPartial(modifiedTextField as String)
        var selectedTextRange: NSRange?
        
        let nonNumericRange = (changedRange.rangeOfCharacter(from: nonNumericSet as CharacterSet).location != NSNotFound)
        if (range.length == 1 && string.isEmpty && nonNumericRange)
        {
            selectedTextRange = selectionRangeForNumberReplacement(textField: textField, formattedText: modifiedTextField)
            textField.text = modifiedTextField
        }
        else {
            selectedTextRange = selectionRangeForNumberReplacement(textField: textField, formattedText: formattedNationalNumber)
            textField.text = formattedNationalNumber
        }
        textField.sendActions(for: .editingChanged)
        if let selectedTextRange = selectedTextRange, let selectionRangePosition = textField.position(from: textField.beginningOfDocument, offset: selectedTextRange.location) {
            let selectionRange = textField.textRange(from: selectionRangePosition, to: selectionRangePosition)
            textField.selectedTextRange = selectionRange
        }
        
        return false
    }
    
    //MARK: UITextfield Delegate
    
    public func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        return self.delegate?.textFieldShouldBeginEditing?(textField) ?? true
    }
    
    public func textFieldDidBeginEditing(_ textField: UITextField) {
        self.delegate?.textFieldDidBeginEditing?(textField)
    }
    
    public func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        return self.delegate?.textFieldShouldEndEditing?(textField) ?? true
    }
    
    public func textFieldDidEndEditing(_ textField: UITextField) {
        self.delegate?.textFieldDidEndEditing?(textField)
    }
    
    public func textFieldShouldClear(_ textField: UITextField) -> Bool {
        return self.delegate?.textFieldShouldClear?(textField) ?? true
    }
    
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return self.delegate?.textFieldShouldReturn?(textField) ?? true
    }
}

/// Custom text field that formats phone numbers
open class PhoneNumberTextField: UITextField, UITextFieldDelegate {
    
    private let proxyDelegate = PhoneNumberTextFieldDelegate()
    
    /// Override region to set a custom region. Automatically uses the default region code.
    public var defaultRegion: String {
        didSet {
            self.proxyDelegate.partialFormatter.defaultRegion = self.defaultRegion
        }
    }
    
    public var withPrefix: Bool = true {
        didSet {
            self.proxyDelegate.partialFormatter.withPrefix = withPrefix
            if self.withPrefix == false {
                self.keyboardType = UIKeyboardType.numberPad
            }
            else {
                self.keyboardType = UIKeyboardType.phonePad
            }
        }
    }
    
    open override var delegate: UITextFieldDelegate? {
        set {
            self.proxyDelegate.delegate = newValue
        }
        get {
            return self.proxyDelegate.delegate
        }
    }
    
    //MARK: Status
    
    public var currentRegion: String {
        get {
            return self.proxyDelegate.partialFormatter.currentRegion
        }
    }
    
    public var isValidNumber: Bool {
        get {
            let rawNumber = self.text ?? String()
            do {
                _ = try self.proxyDelegate.phoneNumberKit.parse(rawNumber, withRegion: currentRegion)
                return true
            } catch {
                return false
            }
        }
    }
    
    //MARK: Lifecycle
    
    /**
     Init with frame
     
     - parameter frame: UITextfield F
     
     - returns: UITextfield
     */
    override public init(frame:CGRect)
    {
        self.defaultRegion = proxyDelegate.partialFormatter.defaultRegion
        super.init(frame:frame)
        self.setup()
    }
    
    /**
     Init with coder
     
     - parameter aDecoder: decoder
     
     - returns: UITextfield
     */
    required public init(coder aDecoder: NSCoder) {
        self.defaultRegion = proxyDelegate.partialFormatter.defaultRegion
        super.init(coder: aDecoder)!
        self.setup()
    }
    
    func setup(){
        super.delegate = self.proxyDelegate
        self.autocorrectionType = .no
        self.keyboardType = UIKeyboardType.phonePad
    }
}
