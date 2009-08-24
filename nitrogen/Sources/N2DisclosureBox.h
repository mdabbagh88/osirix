//
//  N2DisclosureBox.h
//  Nitrogen Framework
//
//  Created by Joris Heuberger on 30/03/07.
//  Edited by Alessandro Volz since 21/05/09.
//  Copyright 2009 OsiriX Team. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class N2DisclosureButtonCell;

extern NSString* N2DisclosureBoxDidToggle;
extern NSString* N2DisclosureBoxWillExpand;
extern NSString* N2DisclosureBoxDidExpand;
extern NSString* N2DisclosureBoxWillCollapse;
extern NSString* N2DisclosureBoxDidCollapse;

@interface N2DisclosureBox : NSBox {
	BOOL _showingExpanded;
	IBOutlet NSView* _content;
	CGFloat _contentHeight;
}

@property BOOL enabled;
@property(readonly) N2DisclosureButtonCell* titleCell;

-(id)initWithTitle:(NSString*)title content:(NSView*)view;
-(void)toggle:(id)sender;
-(void)expand:(id)sender;
-(void)collapse:(id)sender;
-(BOOL)isExpanded;

@end
