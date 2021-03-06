//
//  ULIThikryaView.m
//  Thikrya
//
//  Created by Uli Kusterer on 2014-05-13.
//  Copyright (c) 2014 Uli Kusterer. All rights reserved.
//

#import "ULIThikryaView.h"


static NSInteger	CharacterIndexAtXPosOfString( CGFloat xpos, NSAttributedString* str )
{
	NSInteger	x = 0, count = str.length;
	CGFloat		lastXPos = 0;
	while( x < count )
	{
		NSRange	seqRange = [str.string rangeOfComposedCharacterSequenceAtIndex: x];
		NSAttributedString*	substr = [str attributedSubstringFromRange: NSMakeRange(0,seqRange.location+seqRange.length)];
		NSSize	measuredSize = [substr size];
		if( xpos <= measuredSize.width )
		{
			if( xpos <= (lastXPos +((measuredSize.width -lastXPos) /2)) )	// We hit this character in its first half?
				return x;
			// Second half will be covered by next character, because mouse loc is closer to the end of this character, and cursors are always between characters.
		}
		
		lastXPos = measuredSize.width;
		x += seqRange.length;
	}
	
	return count;
}


typedef struct _ULISignedRange
{
	NSInteger	location;
	NSInteger	length;
} ULISignedRange;


static NSRange	ULISignedRangeToUnsigned( ULISignedRange inRange )
{
	if( inRange.length < 0 )
		return NSMakeRange(inRange.location +inRange.length, -inRange.length);
	else
		return NSMakeRange(inRange.location, inRange.length);
}


static ULISignedRange	ULISignedRangeFromUnsigned( NSRange inRange )
{
	return (ULISignedRange){ inRange.location, inRange.length };
}


@interface ULIThikryaView ()
{
	BOOL			isFirstResponder;
	NSInteger		editedCapsule;
	NSRange			selectedRange;
	ULISignedRange	trackingSelectedRange;
	NSTimer*		insertionMarkTimer;
	BOOL			insertionMarkVisible;
}

@property (weak) NSWindow*	lastWindowWeWereIn;

@end


@implementation ULIThikryaCapsule

-(id)	init
{
	self = [super init];
	if( self )
	{
		self.name = @"";
	}
	return self;
}


-(NSDictionary*)	textAttributes
{
	return @{ NSFontAttributeName: [NSFont fontWithName: @"Avenir Next" size: 16] };
}


-(NSPoint)	textPosInRect: (NSRect)inBox
{
	return NSMakePoint(NSMinX(inBox) +12,NSMinY(inBox));
}


-(void)	drawInRect: (NSRect)inBox selected: (BOOL)isSelected active: (BOOL)isActive selectedRange: (NSRange)selectedRange insertionMarkVisible: (BOOL)insertionMarkVisible
{
	NSDictionary				*	attrs = self.textAttributes;
	NSMutableAttributedString	*	attrStr = [[NSMutableAttributedString alloc] initWithString: self.name attributes: attrs];
	NSPoint							textPos = [self textPosInRect: inBox];
	if( isSelected )
	{
		if( selectedRange.length > 0 )
		{
			[attrStr addAttribute: NSBackgroundColorAttributeName value: isActive ? [NSColor selectedTextBackgroundColor] : [NSColor secondarySelectedControlColor] range: selectedRange];
			[attrStr addAttribute: NSForegroundColorAttributeName value: isActive ? [NSColor selectedTextColor] : [NSColor blackColor] range: selectedRange];
		}
		else if( insertionMarkVisible )
		{
			NSSize	beforeSelectionSize = [[self.name substringToIndex: selectedRange.location] sizeWithAttributes: attrs];
			[NSColor.blackColor set];
			CGFloat	xpos = truncf(textPos.x +beforeSelectionSize.width) +0.5;
			[NSBezierPath strokeLineFromPoint: NSMakePoint( xpos, textPos.y) toPoint:NSMakePoint(xpos, textPos.y +beforeSelectionSize.height)];
		}
	}
	[attrStr drawAtPoint: textPos];
}


-(NSInteger)	selectedIndexFromPoint: (NSPoint)pos inRect: (NSRect)inBox
{
	NSDictionary				*	attrs = self.textAttributes;
	NSMutableAttributedString	*	attrStr = [[NSMutableAttributedString alloc] initWithString: self.name attributes: attrs];
	return CharacterIndexAtXPosOfString( pos.x -[self textPosInRect: inBox].x, attrStr );
}

@end


@implementation ULIThikryaView

-(id)	initWithFrame: (NSRect)frame
{
	self = [super initWithFrame: frame];
	if( self )
	{
		self.capsules = [NSMutableArray array];
		[self.capsules addObject: [ULIThikryaCapsule new]];
	}
	return self;
}


-(id)	initWithCoder: (NSCoder *)aDecoder
{
	self = [super initWithCoder: aDecoder];
	if( self )
	{
		self.capsules = [NSMutableArray array];
		[self.capsules addObject: [ULIThikryaCapsule new]];
	}
	return self;
}


-(void)	showInsertionMark
{
	insertionMarkVisible = YES;
	[insertionMarkTimer setFireDate: [NSDate dateWithTimeIntervalSinceNow: insertionMarkTimer.timeInterval]];	// Make sure it stays visible for a full period and isn't immediately hidden again.
}


-(void)	toggleInsertionMark: (NSTimer*)sender
{
	insertionMarkVisible = !insertionMarkVisible;
	[self setNeedsDisplay: YES];
}


-(NSRect)	rectForCapsuleAtIndex: (NSInteger)idx
{
	NSRect		box = self.bounds;
	box.size.height = 32;
	
	box.origin.y += box.size.height * idx;
	
	return box;
}


-(void)	drawRect: (NSRect)dirtyRect
{
	[[NSColor controlBackgroundColor] set];
	[NSBezierPath fillRect: dirtyRect];
	
	NSRect		box = self.bounds;
	NSRect		selectedRect = NSZeroRect;
	
	box.size.height = 32;
	
	BOOL		shouldDrawSelected = isFirstResponder && self.window.isKeyWindow;
	NSInteger	idx = 0;
	for( ULIThikryaCapsule* currCapsule in self.capsules )
	{
		NSRect	box = [self rectForCapsuleAtIndex: idx];
		if( NSIntersectsRect( dirtyRect, box ) )
		{
			[currCapsule drawInRect: box selected: (idx == editedCapsule) active: shouldDrawSelected selectedRange: selectedRange insertionMarkVisible: insertionMarkVisible];
			if( idx == editedCapsule )
				selectedRect = box;
		}
		idx++;
	}
	
	if( shouldDrawSelected )
	{
		[[NSColor keyboardFocusIndicatorColor] set];
	}
	else
	{
		[[NSColor lightGrayColor] set];
	}
	
	[NSBezierPath setDefaultLineWidth: 2];
	[[NSBezierPath bezierPathWithRoundedRect: NSInsetRect(selectedRect,1,1) xRadius: 4 yRadius: 4] stroke];
	[NSBezierPath setDefaultLineWidth: 1];
}


-(void)	mouseDown: (NSEvent *)theEvent
{
	NSPoint	pos = [self convertPoint: theEvent.locationInWindow fromView: nil];
	
	[self setNeedsDisplayInRect: [self rectForCapsuleAtIndex: editedCapsule]];

	editedCapsule = NSNotFound;
	NSInteger	idx = 0, count = self.capsules.count;
	for( idx = 0; idx < count; idx++ )
	{
		NSRect	box = [self rectForCapsuleAtIndex: idx];
		if( NSPointInRect( pos, box) )
		{
			editedCapsule = idx;
			selectedRange.location = [self.capsules[idx] selectedIndexFromPoint: pos inRect: box];
			if( selectedRange.location == NSNotFound )
				selectedRange.location = [self.capsules[editedCapsule] name].length;
			selectedRange.length = 0;
			trackingSelectedRange = ULISignedRangeFromUnsigned( selectedRange );
			break;
		}
	}
	
	if( editedCapsule == NSNotFound )	// Click below existing rows?
	{
		while( true )	// Insert as many empty lines as needed to let the user enter text there.
		{
			[self.capsules addObject: [ULIThikryaCapsule new]];
			NSRect	box = [self rectForCapsuleAtIndex: count];
			if( NSPointInRect( pos, box ) )
			{
				editedCapsule = count;
				selectedRange = NSMakeRange( [self.capsules[editedCapsule] name].length, 0 );
				trackingSelectedRange = ULISignedRangeFromUnsigned( selectedRange );
				break;
			}
			count++;
		}
	}
	
	[self showInsertionMark];
	[self setNeedsDisplayInRect: [self rectForCapsuleAtIndex: editedCapsule]];
}


-(void)	mouseDragged: (NSEvent *)theEvent
{
	ULIThikryaCapsule*	caps = self.capsules[editedCapsule];
	NSPoint				pos = [self convertPoint: theEvent.locationInWindow fromView: nil];
	NSRect				box = [self rectForCapsuleAtIndex: editedCapsule];
	NSInteger			mouseCharIdx = [caps selectedIndexFromPoint: pos inRect: box];
	
	trackingSelectedRange.length = mouseCharIdx -trackingSelectedRange.location;
	selectedRange = ULISignedRangeToUnsigned(trackingSelectedRange);
	
	[self showInsertionMark];
	[self setNeedsDisplayInRect: [self rectForCapsuleAtIndex: editedCapsule]];
}


-(void)	keyDown: (NSEvent *)theEvent
{
	[self interpretKeyEvents: @[theEvent]];
}


-(void)	deleteBackward: (id)sender
{
	ULIThikryaCapsule	*	caps = self.capsules[editedCapsule];
	NSString			*	oldName = caps.name;
	if( oldName.length == 0 && self.capsules.count > 1 )
	{
		[self.capsules removeObjectAtIndex: editedCapsule];
		if( editedCapsule > 0 )
			editedCapsule--;
		selectedRange = NSMakeRange( [self.capsules[editedCapsule] name].length, 0 );
		trackingSelectedRange = ULISignedRangeFromUnsigned( selectedRange );
	
		[self setNeedsDisplay: YES];
	}
	else if( selectedRange.length == 0 && (selectedRange.location > 0) )
	{
		selectedRange = [oldName rangeOfComposedCharacterSequenceAtIndex: selectedRange.location -1];
		
		NSString			*	newName = [oldName stringByReplacingCharactersInRange: selectedRange withString: @""];
		caps.name = newName;
		selectedRange.length = 0;
		trackingSelectedRange = ULISignedRangeFromUnsigned( selectedRange );
		
		[self setNeedsDisplayInRect: [self rectForCapsuleAtIndex: editedCapsule]];
	}
	else
	{
		NSString			*	newName = [oldName stringByReplacingCharactersInRange: selectedRange withString: @""];
		caps.name = newName;
		selectedRange.length = 0;
		trackingSelectedRange = ULISignedRangeFromUnsigned( selectedRange );
	
		[self setNeedsDisplayInRect: [self rectForCapsuleAtIndex: editedCapsule]];
	}
	
	[self showInsertionMark];
}


-(void)	deleteForward: (id)sender
{
	ULIThikryaCapsule	*	caps = self.capsules[editedCapsule];
	NSString			*	oldName = caps.name;
	if( oldName.length == 0 && self.capsules.count > 1 )
	{
		[self.capsules removeObjectAtIndex: editedCapsule];
		if( editedCapsule >= self.capsules.count )
			editedCapsule = self.capsules.count -1;
		selectedRange = NSMakeRange( [self.capsules[editedCapsule] name].length, 0 );
		trackingSelectedRange = ULISignedRangeFromUnsigned( selectedRange );
		
		[self setNeedsDisplay: YES];
	}
	else if( selectedRange.length == 0 && (selectedRange.location < oldName.length) )
	{
		selectedRange = [oldName rangeOfComposedCharacterSequenceAtIndex: selectedRange.location];
		
		NSString			*	newName = [oldName stringByReplacingCharactersInRange: selectedRange withString: @""];
		caps.name = newName;
		selectedRange.length = 0;
		trackingSelectedRange = ULISignedRangeFromUnsigned( selectedRange );
		
		[self setNeedsDisplayInRect: [self rectForCapsuleAtIndex: editedCapsule]];
	}
	else
	{
		NSString			*	newName = [oldName stringByReplacingCharactersInRange: selectedRange withString: @""];
		caps.name = newName;
		selectedRange.length = 0;
		trackingSelectedRange = ULISignedRangeFromUnsigned( selectedRange );
		
		[self setNeedsDisplayInRect: [self rectForCapsuleAtIndex: editedCapsule]];
	}
	
	[self showInsertionMark];
}


-(void)	moveUpAndModifySelection:(id)sender
{
	trackingSelectedRange.length = -trackingSelectedRange.location;
	selectedRange = ULISignedRangeToUnsigned( trackingSelectedRange );
	
	[self setNeedsDisplayInRect: [self rectForCapsuleAtIndex: editedCapsule]];
	[self showInsertionMark];
}


-(void)	moveDownAndModifySelection:(id)sender
{
	ULIThikryaCapsule	*	caps = self.capsules[editedCapsule];
	trackingSelectedRange.length = caps.name.length -trackingSelectedRange.location;
	selectedRange = ULISignedRangeToUnsigned( trackingSelectedRange );
	
	[self setNeedsDisplayInRect: [self rectForCapsuleAtIndex: editedCapsule]];
	[self showInsertionMark];
}


-(void)	moveLeftAndModifySelection:(id)sender
{
	ULIThikryaCapsule	*	caps = self.capsules[editedCapsule];
	if( selectedRange.location > 0 )
	{
		trackingSelectedRange.length -= 1;
		NSInteger	newLoc = trackingSelectedRange.location + trackingSelectedRange.length;
		newLoc = [caps.name rangeOfComposedCharacterSequenceAtIndex: newLoc].location;	// Make sure we didn't just jump half a 4-byte Unicode character backwards.
		trackingSelectedRange.length = newLoc -trackingSelectedRange.location;
		selectedRange = ULISignedRangeToUnsigned( trackingSelectedRange );
		
		[self setNeedsDisplayInRect: [self rectForCapsuleAtIndex: editedCapsule]];
	}
	
	[self showInsertionMark];
}


-(void)	moveRightAndModifySelection:(id)sender
{
	ULIThikryaCapsule	*	caps = self.capsules[editedCapsule];
	if( (selectedRange.location +selectedRange.length) < caps.name.length )
	{
		NSInteger	newLoc = trackingSelectedRange.location + trackingSelectedRange.length;
		NSRange		composedRange = [caps.name rangeOfComposedCharacterSequenceAtIndex: newLoc];
		newLoc = composedRange.location + composedRange.length;	// Make sure we didn't just jump half a 4-byte Unicode character forward.
		trackingSelectedRange.length = newLoc -trackingSelectedRange.location;
		selectedRange = ULISignedRangeToUnsigned( trackingSelectedRange );
		
		[self setNeedsDisplayInRect: [self rectForCapsuleAtIndex: editedCapsule]];
	}
	
	[self showInsertionMark];
}


-(void)	moveLeft:(id)sender
{
	ULIThikryaCapsule	*	caps = self.capsules[editedCapsule];
	if( selectedRange.length > 0 )
	{
		selectedRange.length = 0;
		trackingSelectedRange = ULISignedRangeFromUnsigned( selectedRange );
		
		[self setNeedsDisplayInRect: [self rectForCapsuleAtIndex: editedCapsule]];
	}
	else if( selectedRange.location > 0 )
	{
		selectedRange.location--;
		selectedRange.location = [caps.name rangeOfComposedCharacterSequenceAtIndex: selectedRange.location].location;	// Make sure we didn't just jump half a 4-byte Unicode character backwards.
		trackingSelectedRange = ULISignedRangeFromUnsigned( selectedRange );
		
		[self setNeedsDisplayInRect: [self rectForCapsuleAtIndex: editedCapsule]];
	}
	else if( selectedRange.location == 0 && editedCapsule > 0 )
	{
		[self setNeedsDisplayInRect: [self rectForCapsuleAtIndex: editedCapsule]];
		
		editedCapsule --;
		selectedRange.length = 0;
		selectedRange.location = [self.capsules[editedCapsule] name].length;
		trackingSelectedRange = ULISignedRangeFromUnsigned( selectedRange );
		
		[self setNeedsDisplayInRect: [self rectForCapsuleAtIndex: editedCapsule]];
	}
	
	[self showInsertionMark];
}


-(void)	moveRight:(id)sender
{
	ULIThikryaCapsule	*	caps = self.capsules[editedCapsule];
	if( selectedRange.length > 0 )
	{
		selectedRange.location += selectedRange.length;
		selectedRange.length = 0;
		trackingSelectedRange = ULISignedRangeFromUnsigned( selectedRange );
		
		[self setNeedsDisplayInRect: [self rectForCapsuleAtIndex: editedCapsule]];
	}
	else if( (selectedRange.location +selectedRange.length) < caps.name.length )
	{
		NSRange	sequenceRange = [caps.name rangeOfComposedCharacterSequenceAtIndex: selectedRange.location];	// Determine length of character in case it was a 4-byte sequence like an Emoji.
		selectedRange.location = sequenceRange.location +sequenceRange.length;
		trackingSelectedRange = ULISignedRangeFromUnsigned( selectedRange );
		
		[self setNeedsDisplayInRect: [self rectForCapsuleAtIndex: editedCapsule]];
	}
	else if( editedCapsule < (self.capsules.count -1) )
	{
		[self setNeedsDisplayInRect: [self rectForCapsuleAtIndex: editedCapsule]];
		
		editedCapsule ++;
		selectedRange.location = 0;
		selectedRange.length = 0;
		trackingSelectedRange = ULISignedRangeFromUnsigned( selectedRange );
		
		[self setNeedsDisplayInRect: [self rectForCapsuleAtIndex: editedCapsule]];
	}
	
	[self showInsertionMark];
}


-(void)	insertTab:(id)sender
{
	[self moveDown: sender];
}


-(void)	insertBacktab:(id)sender
{
	[self moveUp: sender];
}


-(void)	moveUp:(id)sender
{
	if( editedCapsule > 0 )
	{
		[self setNeedsDisplayInRect: [self rectForCapsuleAtIndex: editedCapsule]];
		
		editedCapsule --;
		if( (selectedRange.location +selectedRange.length) >= [self.capsules[editedCapsule] name].length )
		{
			selectedRange.location = [self.capsules[editedCapsule] name].length;
			selectedRange.length = 0;
		}
		else
		{
			ULIThikryaCapsule	*	caps = self.capsules[editedCapsule];
			selectedRange.location = [caps.name rangeOfComposedCharacterSequenceAtIndex: selectedRange.location].location;	// Make sure we didn't just jump into the middle of a 4-byte Unicode character.
		}
		trackingSelectedRange = ULISignedRangeFromUnsigned( selectedRange );
	}
	
	[self showInsertionMark];
	[self setNeedsDisplayInRect: [self rectForCapsuleAtIndex: editedCapsule]];
}


-(void)	moveDown:(id)sender
{
	if( editedCapsule < (self.capsules.count -1) )
	{
		[self setNeedsDisplayInRect: [self rectForCapsuleAtIndex: editedCapsule]];
		
		editedCapsule ++;
		if( (selectedRange.location +selectedRange.length) >= [self.capsules[editedCapsule] name].length )
		{
			selectedRange.location = [self.capsules[editedCapsule] name].length;
			selectedRange.length = 0;
		}
		else
		{
			ULIThikryaCapsule	*	caps = self.capsules[editedCapsule];
			selectedRange.location = [caps.name rangeOfComposedCharacterSequenceAtIndex: selectedRange.location].location;	// Make sure we didn't just jump into the middle of a 4-byte Unicode character.
		}
		trackingSelectedRange = ULISignedRangeFromUnsigned( selectedRange );
	}
	
	[self showInsertionMark];
	[self setNeedsDisplayInRect: [self rectForCapsuleAtIndex: editedCapsule]];
}


-(void)	insertNewline:(id)sender
{
	if( selectedRange.location == 0 && selectedRange.length == 0 )
	{
		[self.capsules insertObject: [ULIThikryaCapsule new] atIndex: editedCapsule];
		editedCapsule++;
		selectedRange = NSMakeRange( 0, 0 );
	}
	else
	{
		[self.capsules insertObject: [ULIThikryaCapsule new] atIndex: editedCapsule +1];
		editedCapsule++;
		selectedRange = NSMakeRange( [self.capsules[editedCapsule] name].length, 0 );
	}
	trackingSelectedRange = ULISignedRangeFromUnsigned( selectedRange );
	
	[self showInsertionMark];
	[self setNeedsDisplay: YES];
}


-(void)	insertText: (NSString*)insertString
{
	ULIThikryaCapsule	*	caps = self.capsules[editedCapsule];
	
	NSString			*	oldName = caps.name;
	NSString			*	newName = [oldName stringByReplacingCharactersInRange: selectedRange withString: insertString];
	caps.name = newName;
	selectedRange.length = 0;
	selectedRange.location += insertString.length;
	trackingSelectedRange = ULISignedRangeFromUnsigned( selectedRange );
	
	[self showInsertionMark];
	[self setNeedsDisplayInRect: [self rectForCapsuleAtIndex: editedCapsule]];
}


-(NSRange)	markedRange
{
	return selectedRange;
}


-(BOOL)	hasMarkedText
{
	return NO;
}


-(NSRange)	selectedRange
{
	return selectedRange;
}


-(void)	setMarkedText:(id)inString
        selectedRange:(NSRange)inSelectedRange
     replacementRange:(NSRange)inReplacementRange
{
//	selectedRange = inSelectedRange;
	
}


-(void)	unmarkText
{

}


-(NSArray *)	validAttributesForMarkedText
{
	return @[];
}


-(NSAttributedString *)	attributedSubstringForProposedRange:(NSRange)aRange
                                                actualRange:(NSRangePointer)actualRange
{
	NSString*	str = [self.capsules[editedCapsule] name];
	if( (aRange.location +aRange.length) > str.length )
		return nil;
	return [[NSAttributedString alloc] initWithString: [str substringWithRange: aRange] attributes: @{}];
}


-(void)	insertText: (id)aString replacementRange: (NSRange)replacementRange
{
	BOOL	moveCursor = NO;
	if( replacementRange.location == NSNotFound )
	{
		replacementRange = selectedRange;
		moveCursor = YES;
	}
	NSString*	str = [self.capsules[editedCapsule] name];
	str = [str stringByReplacingCharactersInRange: replacementRange withString: aString];
	[(ULIThikryaCapsule*)self.capsules[editedCapsule] setName: str];
	
	if( moveCursor )
	{
		selectedRange.location += [aString length];
		selectedRange.length = 0;
		trackingSelectedRange = ULISignedRangeFromUnsigned( selectedRange );
	}
	
	[self setNeedsDisplayInRect: [self rectForCapsuleAtIndex: editedCapsule]];
	
	[self showInsertionMark];
}


-(NSUInteger)	characterIndexForPoint:(NSPoint)aPoint
{
	return NSNotFound;
}


-(NSRect)	firstRectForCharacterRange: (NSRange)aRange actualRange: (NSRangePointer)actualRange
{
	return NSZeroRect;
}


-(void)	doCommandBySelector: (SEL)aSelector
{
	if( [self respondsToSelector: aSelector] )
	{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    	// We know aSelector is a void return, and this warning complains about not knowing
		//	the return type, so it's erroneous in this case. If it wasn't (e.g. aSelector
		//	was 'new' or 'copy'), we'd have to somehow explicitly release it.
		[self performSelector: aSelector withObject: self];
#pragma clang diagnostic pop
	}
	else
		NSLog( @"%@", NSStringFromSelector(aSelector) );
}


-(BOOL)	isFlipped
{
	return YES;
}


-(BOOL)	acceptsFirstResponder
{
	return YES;
}


-(BOOL)	becomeFirstResponder
{
	isFirstResponder = YES;
	[self setNeedsDisplay: YES];
	
	if( !insertionMarkTimer )
	{
		insertionMarkTimer = [NSTimer scheduledTimerWithTimeInterval: 0.5 target: self selector: @selector(toggleInsertionMark:) userInfo: nil repeats: YES];
		insertionMarkVisible = YES;
	}
	
	return YES;
}


-(BOOL)	resignFirstResponder
{
	isFirstResponder = NO;
	[self setNeedsDisplay: YES];
	
	[insertionMarkTimer invalidate];
	insertionMarkTimer = nil;
	insertionMarkVisible = NO;

	return YES;
}


-(void)	windowActivationDidChange: (NSNotification*)notif
{
	[self setNeedsDisplay: YES];
	
	if( self.window.isKeyWindow && isFirstResponder )
	{
		if( !insertionMarkTimer )
		{
			insertionMarkTimer = [NSTimer scheduledTimerWithTimeInterval: 0.5 target: self selector: @selector(toggleInsertionMark:) userInfo: nil repeats: YES];
			insertionMarkVisible = YES;
		}
	}
	else
	{
		[insertionMarkTimer invalidate];
		insertionMarkTimer = nil;
		insertionMarkVisible = NO;
	}
}


-(void)	viewDidMoveToWindow
{
	if( self.lastWindowWeWereIn != self.window )
	{
		if( self.lastWindowWeWereIn )
		{
			[[NSNotificationCenter defaultCenter] removeObserver: self name: NSWindowDidBecomeMainNotification object: self.lastWindowWeWereIn];
			[[NSNotificationCenter defaultCenter] removeObserver: self name: NSWindowDidResignMainNotification object: self.lastWindowWeWereIn];
			[[NSNotificationCenter defaultCenter] removeObserver: self name: NSWindowDidBecomeKeyNotification object: self.lastWindowWeWereIn];
			[[NSNotificationCenter defaultCenter] removeObserver: self name: NSWindowDidResignKeyNotification object: self.lastWindowWeWereIn];
			[insertionMarkTimer invalidate];
			insertionMarkTimer = nil;
			insertionMarkVisible = NO;
			self.lastWindowWeWereIn = nil;
		}
		
		if( self.window )
		{
			self.lastWindowWeWereIn = self.window;
			[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(windowActivationDidChange:) name: NSWindowDidBecomeMainNotification object: self.window];
			[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(windowActivationDidChange:) name: NSWindowDidResignMainNotification object: self.window];
			[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(windowActivationDidChange:) name: NSWindowDidBecomeKeyNotification object: self.window];
			[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(windowActivationDidChange:) name: NSWindowDidResignKeyNotification object: self.window];
			insertionMarkTimer = [NSTimer scheduledTimerWithTimeInterval: 0.5 target: self selector: @selector(toggleInsertionMark:) userInfo: nil repeats: YES];
			insertionMarkVisible = YES;
		}
		[self setNeedsDisplay: YES];
	}
}

@end


