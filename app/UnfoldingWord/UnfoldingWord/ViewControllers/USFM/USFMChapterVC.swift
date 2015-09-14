//
//  USFMChapterVC.swift
//  UnfoldingWord
//
//  Created by David Solberg on 9/9/15.
//  Copyright (c) 2015 Acts Media Inc. All rights reserved.
//

import Foundation

enum TOCArea {
    case Main
    case Side
}

class USFMChapterVC : UIViewController, UITextViewDelegate {
    
    let CONSTANT_SHOWING_SIDE : CGFloat = 2
    let CONSTANT_HIDDEN_SIDE : CGFloat = 1
    
    var tocMain : UWTOC? = nil {
        didSet {
            arrayMainChapters = chaptersFromTOC(tocMain)
        }
    }
    var tocSide : UWTOC? = nil {
        didSet {
            arrayMainChapters = chaptersFromTOC(tocSide)
        }
    }
    private var arrayMainChapters: [USFMChapter]? = nil
    private var arraySideChapters: [USFMChapter]? = nil
    
    var chapterNumber : Int! { // It's a programming error if this isn't set before needed!
        didSet {
            assert(chapterNumber > 0, "The chapter number \(chapterNumber) must be greater than zero!")
        }
    }
    
    private var isSideShowing : Bool {
        get {
            return (constraintMainViewProportion.constant == CONSTANT_SHOWING_SIDE) ? true : false
        }
    }
    
    private var isSettingUp = true
    
    @IBOutlet weak var viewMain: UIView!
    @IBOutlet weak var viewSideDiglot: UIView!
    
    @IBOutlet weak var textViewMain: UITextView!
    @IBOutlet weak var textViewSideDiglot: UITextView!
    
    @IBOutlet weak var buttonMain: UIButton!
    @IBOutlet weak var buttonSideDiglot: UIButton!
    
    @IBOutlet weak var labelEmptyMain: UILabel!
    @IBOutlet weak var labelEmptySide: UILabel!
    
    @IBOutlet weak var constraintMainViewProportion: NSLayoutConstraint!
    
    // Managing State across scrollviews - Is there a better way to do this?
    var lastMainOffset : CGPoint = CGPointZero
    var lastSideOffset : CGPoint = CGPointZero
    var countSetup : Int = 0
    
    override init(nibName nibNameOrNil: String!, bundle nibBundleOrNil: NSBundle!) {
        super.init(nibName: nibNameOrNil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        loadContentForArea(.Main)
        if tocSide != nil {
            setSideViewToShowing(true, animated: false)
            loadContentForArea(.Side)
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        countSetup++
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        countSetup--
    }
    
    // Outside Methods
    func showDiglotWithToc(toc : UWTOC) {
        tocSide = toc
        loadContentForArea(.Side)
        setSideViewToShowing(true, animated: true)
    }
    
    func hideDiglot() {
        tocSide = nil
        setSideViewToShowing(false, animated: true)
    }
    
    // Scrollview Delegate
    
    func scrollViewDidScroll(scrollView: UIScrollView)
    {
        if isSideShowing == false || countSetup > 0 {
            return
        }
        
        if scrollView.isEqual(textViewMain) {
            let difference = textViewMain.contentOffset.y - lastMainOffset.y
            lastMainOffset = textViewMain.contentOffset
            adjustScrollView(textViewSideDiglot, byYPoints: difference)
        }
        else if scrollView.isEqual(textViewSideDiglot) {
            let difference = textViewSideDiglot.contentOffset.y - lastSideOffset.y
            lastSideOffset = textViewSideDiglot.contentOffset
            adjustScrollView(textViewMain, byYPoints: difference)
            
        }
        else {
            assertionFailure("The scrollview could not be identified \(scrollView)")
        }
    }
    
    func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
        if let textView = scrollView as? UITextView {
            handleTextViewDoneDragging(textView)
        }
    }
    
    func scrollViewDidEndDragging(scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if let textView = scrollView as? UITextView where decelerate == false {
            handleTextViewDoneDragging(textView)
        }
    }
    
    private func adjustScrollView(scrollView : UIScrollView, byYPoints difference : CGFloat) {
        countSetup++
        var changedOffset = scrollView.contentOffset
        changedOffset.y += difference
        changedOffset.y = fmax(changedOffset.y, 0)
        changedOffset.y = fmin(changedOffset.y, scrollView.contentSize.height - scrollView.frame.size.height)
        scrollView.contentOffset = changedOffset
        countSetup--
    }
    
    private func handleTextViewDoneDragging(textView : UITextView) {
        
        if isSideShowing == false || countSetup > 0 {
            return
        }
        
        guard let verseContainer = versesInTextView(textView) else {
            assertionFailure("Could not find verses in view \(textView)")
            return
        }
        
        if textView.isEqual(textViewSideDiglot) {
            adjustTextView(textViewMain, usingVerses: verseContainer, animated : true)
        }
        else if textView.isEqual(textViewMain) {
            adjustTextView(textViewSideDiglot, usingVerses: verseContainer, animated : true)
        }
        else {
            assertionFailure("The textview could not be identified \(textView)")
        }
    }
    
    private func adjustTextView(textView : UITextView, usingVerses verses : VerseContainer, animated: Bool) {
        if isSideShowing == false || countSetup > 0 {
            return
        }
        countSetup++
        
        let attribText = textView.attributedText
        let verseToFind =  Bool(verses.maxIsAtEnd) ? verses.max : verses.min
        guard let firstY =  minYForVerseNumber(verseToFind, inAttributedString: attribText, inTextView: textView) else {
            assertionFailure("Could not find verse \(verseToFind) in \(textView)")
            return
        }
        var minY = firstY
        
        var relativeOffset : CGFloat = 0
        
        let yOriginOffset : CGFloat = verses.minRectRelativeToScreenPosition.origin.y
        let verseHeight : CGFloat = verses.minRectRelativeToScreenPosition.size.height
        
        let remoteVisiblePoints = verseHeight + yOriginOffset
        let remotePercentAboveOrigin = remoteVisiblePoints / verseHeight
        let percentBelowOrigin = 1 - remotePercentAboveOrigin
        
        guard let nextY = minYForVerseNumber(verseToFind+1, inAttributedString: attribText, inTextView: textView) else {
            assertionFailure("Could not find verse \(verseToFind+1) in \(textView)")
            return
        }
        let distanceBetweenVerses = nextY - minY
        
        // 90 points is approximately a line or two. If we only have a couple of lines, then just match with the next verse, balanced by the percent showing across verses
        if remoteVisiblePoints < 90 && verseHeight > 90 {
            minY = nextY
            relativeOffset = remoteVisiblePoints * remotePercentAboveOrigin
        }
        else {
            // Trying to show relatively the same amount of verse for both sides. This is important because some verses are more than twice as long as their matching verses in another language or bible version.
            relativeOffset = -distanceBetweenVerses * percentBelowOrigin
        }
        
        // Adjust so the first visible verse starts in the same place on both screens.
        minY -= relativeOffset
        
        // Prevent the screen from scrolling past the end
        minY = fmin(minY, textView.contentSize.height - textView.frame.size.height)
        let offset = fabs( textView.contentOffset.y - minY)
        
        if offset > textView.frame.size.height {
            assertionFailure("This should not happen")
        }
        
        textView.userInteractionEnabled = false
        textView.setContentOffset(CGPointMake(0, minY), animated: true)
        
        delay(0.5) { [weak self, weak textView] () -> Void in
            if let strongself = self, strongText = textView {
                strongself.countSetup--
                strongText.userInteractionEnabled = true
            }
        }
    }

    private func minYForVerseNumber(verseNumToFind : Int, inAttributedString attribString : NSAttributedString, inTextView textView : UITextView) -> CGFloat? {
        
        var minY : CGFloat = CGFloat.max
        textView.attributedText.enumerateAttributesInRange(NSMakeRange(0, textView.attributedText.length), options: []) { [weak self] (attributes : [String : AnyObject], rangeEnum, stop) -> Void in
            if let
                strongSelf = self,
                verse = attributes[Constants.USFM_VERSE_NUMBER] as? NSString where verse.integerValue == verseNumToFind,
                let locationRect = strongSelf.frameOfTextRange(rangeEnum, inTextView: textView)
            {
                minY = fmin(minY, locationRect.origin.y)
            }
        }
        return minY < CGFloat.max ? minY : nil
    }

    
    // Private
    
    private func loadContentForArea(area : TOCArea) {
        
        guard let chapters = chaptersForArea(area) else {
            showNothingLoadedViewInArea(area)
            return
        }
        
        guard chapterNumber >= chapters.count else {
            showNextChapterViewInArea(area)
            return
        }
        
        guard let toc = tocForArea(area) else {
            assertionFailure("We have chapters for area \(area) but no TOC. That shouldn't be possible.")
            showNothingLoadedViewInArea(area)
            return
        }
        
        // Okay, everything's good, so show the chapter in the textview
        let chapter : USFMChapter = chapters[chapterNumber]
        showChapter(chapter, withTOC: toc, inArea: area)
    }
    
    private func showChapter(chapter : USFMChapter, withTOC toc: UWTOC, inArea area : TOCArea) {
        let textView = textViewForArea(area)
        textView.textAlignment = LanguageInfoController.textAlignmentForLanguageCode(toc.version.language.lc)
        textView.attributedText = chapter.attributedString;
        hideAllViewsExcept(textView, inArea: area)
    }
    
    private func showNextChapterViewInArea(area : TOCArea) {
        let button = buttonForArea(area)
        if let toc = tocForArea(area) {
            let goto = NSLocalizedString("Go to", comment: "Name of bible chapter goes after this text")
            let buttonTitle = "\(goto) \(toc.title)"
            button.setTitle(buttonTitle, forState: .Normal)
        }
        else {
            assertionFailure("Could not find a toc. No sense in having a next chapter button. Fix the count")
        }
        hideAllViewsExcept(button, inArea: area)
    }
    
    private func showNothingLoadedViewInArea(area : TOCArea) {
        let label = labelForArea(area)
        label.text = NSLocalizedString("Choose a Bible Version from the top of the screen.", comment: "")
        hideAllViewsExcept(label, inArea: area)
    }
    
    // View Control
    
    private func setSideViewToShowing(isShowing : Bool, animated isAnimated : Bool) {
        constraintMainViewProportion.constant = isShowing ? CONSTANT_SHOWING_SIDE : CONSTANT_HIDDEN_SIDE
        self.view.setNeedsUpdateConstraints()
        if isAnimated == false {
            self.view.layoutIfNeeded()
        }
        else {
            UIView.animateWithDuration(0.25, delay: 0.0, usingSpringWithDamping: 0.85, initialSpringVelocity: 1.2, options: UIViewAnimationOptions.CurveEaseIn, animations: { () -> Void in
                self.view.layoutIfNeeded()
                }, completion: { (completed) -> Void in
                    
            })
        }
    }
    
    private func hideAllViewsExcept(view : UIView, inArea area : TOCArea) {
        let label = labelForArea(area)
        let textView = textViewForArea(area)
        let button = buttonForArea(area)
        
        label.layer.opacity = label.isEqual(view) ? 1.0 : 0.0
        textView.layer.opacity = textView.isEqual(view) ? 1.0 : 0.0
        button.layer.opacity = button.isEqual(view) ? 1.0 : 0.0
    }
    
    // Helpers for TOC Items
    private func tocAfterTOC(toc : UWTOC) -> UWTOC? {
        
        let sortedTocs = toc.version.sortedTOCs() as! [UWTOC]
        for (i, aToc) in sortedTocs.enumerate() {
            if toc.isEqual(aToc) && (i+1) < sortedTocs.count {
                return sortedTocs[i+1]
            }
        }
        
        assertionFailure("Should never reach this point. Either there should not have been a next chapter button or else we failed to match the toc.")
        return nil
    }
    
    // Matching Areas in Diglot View
    private func chaptersForArea(area : TOCArea) -> [USFMChapter]? {
        switch area {
        case .Main:
            return arrayMainChapters
        case .Side:
            return arraySideChapters
        }
    }
    
    private func tocForArea(area : TOCArea) -> UWTOC? {
        switch area {
        case .Main:
            return tocMain
        case .Side:
            return tocSide
        }
    }
    
    private func textViewForArea(area : TOCArea) -> UITextView {
        switch area {
        case .Main:
            return textViewMain
        case .Side:
            return textViewSideDiglot
        }
    }
    
    private func buttonForArea(area : TOCArea) -> UIButton {
        switch area {
        case .Main:
            return buttonMain
        case .Side:
            return buttonSideDiglot
        }
    }
    
    private func labelForArea(area : TOCArea) -> UILabel {
        switch area {
        case .Main:
            return labelEmptyMain
        case .Side:
            return labelEmptySide
        }
    }
    
    // Helpers
    
    private func chaptersFromTOC(toc : UWTOC?) -> [USFMChapter]? {
        if let toc = toc, chapters = toc.usfmInfo.chapters() as? [USFMChapter] {
            return chapters
        }
        else {
            return nil
        }
    }
    
    // Matching Verses

    private func versesVisibleInArea(area : TOCArea) -> VerseContainer? {
        let textView = textViewForArea(area)
        return versesInTextView(textView)
    }
    
    private func visibleRangeOfTextView(textView : UITextView) -> NSRange? {
        
        var bounds = textView.frame
        bounds.origin = textView.contentOffset
        bounds.size.height -= 30 // ignore the bottom range
        
        if let
            start : UITextPosition = textView.characterRangeAtPoint(bounds.origin)?.start,
            end : UITextPosition = textView.characterRangeAtPoint(CGPointMake(CGRectGetMaxX(bounds), CGRectGetMaxY(bounds)))?.end {
                
                let location = textView.offsetFromPosition(textView.beginningOfDocument, toPosition: start)
                let length = textView.offsetFromPosition(textView.beginningOfDocument, toPosition: end) - location
                return NSMakeRange(location, length)
        }
        return nil
    }
    
    private func frameOfTextRange(range : NSRange, inTextView textView : UITextView) -> CGRect? {
        let previousSelection = textView.selectedRange
        defer {
            textView.selectedRange = previousSelection
        }
        
        textView.selectedRange = range
        if let textRange = textView.selectedTextRange {
            let frame = textView.firstRectForRange(textRange)
            textView.selectedRange = previousSelection
            return frame
        }
        else {
            assertionFailure("Could not create the range \(range) in the textview \(textView)")
            return nil
        }
    }
    
    func unadjustedFrameOfTextRange(range : NSRange, inTextView textView : UITextView) -> CGRect? {
        let previousSelection = textView.selectedRange
        defer {
            textView.selectedRange = previousSelection
        }
        
        textView.selectedRange = range
        guard let textRange = textView.selectedTextRange else {
            assertionFailure("Could not create the range \(range) in the textview \(textView)")
            return nil
        }
        
        var finalRect = CGRectZero
        let selectedRects = textView.selectionRectsForRange(textRange) as! [UITextSelectionRect]
        var isSetOnce = false
        
        for (_, textSelRect) in selectedRects.enumerate() {
            let foundRect = textSelRect.rect
            if isSetOnce == false {
                finalRect = foundRect
                isSetOnce = true
            }
            else {
                finalRect.origin.x = fmin(finalRect.origin.x, foundRect.origin.x)
                finalRect.origin.y = fmin(finalRect.origin.y, foundRect.origin.y)
                let height = CGRectGetMaxY(foundRect) - finalRect.origin.y
                finalRect.size.height = fmax(finalRect.size.height, height)
                finalRect.size.width = fmax(finalRect.size.width, foundRect.size.width)
            }
        }
        return finalRect
    }
    
    private func fullFrameOfVerseNumber(verseNumber : Int, inTextView textView : UITextView) -> CGRect {
        var frame = CGRectMake(CGFloat.max, CGFloat.max, 0, 0)
        
        textView.attributedText.enumerateAttributesInRange(NSMakeRange(0, textView.attributedText.length), options: []) { [weak self] (attributes : [String : AnyObject], rangeEnum, stop) -> Void in
            if let
                strongSelf = self,
                verse = attributes[Constants.USFM_VERSE_NUMBER] as? NSString,
                unadjustedFrame = strongSelf.unadjustedFrameOfTextRange(rangeEnum, inTextView: textView)
                where verse.integerValue == verseNumber
            {
                frame.origin.x = fmin(frame.origin.x, unadjustedFrame.origin.x)
                frame.origin.y = fmin(frame.origin.y, (unadjustedFrame.origin.y - textView.contentOffset.y) )
                let currentHeight = (unadjustedFrame.origin.y - frame.origin.y) + unadjustedFrame.size.height
                frame.size.height = fmax(frame.size.height, currentHeight)
                frame.size.width = fmax(frame.size.width, unadjustedFrame.size.width)
            }
        }
        
        assert(frame.origin.x != CGFloat.max && frame.origin.y != CGFloat.max, "The frame was not set for verse \(verseNumber) in textview \(textView)")
        
        return frame
    }
    
    private func versesInTextView(textView: UITextView) -> VerseContainer? {

        guard let visibleRange = visibleRangeOfTextView(textView) else {
            assertionFailure("Could not find a visible range in textview \(textView)")
            return nil
        }
        let textInRange = textView.attributedText.attributedSubstringFromRange(visibleRange)
        
        var rowHeight : Float = 0
        var minVerse : Int = NSInteger.max
        var maxVerse : Int = 0
        var minRelativeRect = CGRectZero
        var maxRelativeRect = CGRectZero
        var minIsAtStart = false
        var maxIsAtEnd = false
        
        textInRange.enumerateAttributesInRange(NSMakeRange(0, textInRange.length), options: []) { [weak self] (attributes : [String : AnyObject], rangeEnum, stop) -> Void in
            if let
                strongself = self,
                verse = attributes[Constants.USFM_VERSE_NUMBER] as? NSString,
                frame = strongself.frameOfTextRange(rangeEnum, inTextView: textView)
            {
                rowHeight = fmaxf(rowHeight, Float(frame.size.height))
                let number = verse.integerValue
                if minVerse >= number && frame.size.width > 15 && rangeEnum.length > 5 { // the 5 is to catch newlines and other trailing characters
                    minRelativeRect = strongself.fullFrameOfVerseNumber(number, inTextView: textView)
                    if textView.contentOffset.y < 5 { // 5 = wiggle room
                        minIsAtStart = true
                    }
                    minVerse = number
                }
                if maxVerse < number || maxVerse == number {
                    maxVerse = number
                    maxRelativeRect = strongself.fullFrameOfVerseNumber(number, inTextView: textView)
                    if (textView.contentOffset.y + textView.frame.size.height) >= (textView.contentSize.height - 10) {
                        maxIsAtEnd = true
                    }
                }
            }
        }
        
        if minVerse == NSInteger.max {
            assertionFailure("No verses were found in textview \(textView)")
            return nil
        }
        
        var container = VerseContainer()
        container.min = minVerse
        container.max = maxVerse
        container.minIsAtStart = ObjCBool.init(minIsAtStart)
        container.maxIsAtEnd = ObjCBool.init( maxIsAtEnd)
        container.minRectRelativeToScreenPosition = minRelativeRect
        container.maxRectRelativeToScreenPosition = maxRelativeRect
        container.rowHeight = CGFloat(rowHeight)
        return container
    }
}