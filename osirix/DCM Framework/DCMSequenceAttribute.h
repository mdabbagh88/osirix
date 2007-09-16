//
//  DCMSequenceAttribute.h
//  OsiriX
//
//  Created by Lance Pysher on Fri Jun 11 2004.

/*=========================================================================
  Program:   OsiriX

  Copyright (c) OsiriX Team
  All rights reserved.
  Distributed under GNU - GPL
  
  See http://www.osirix-viewer.com/copyright.html for details.

     This software is distributed WITHOUT ANY WARRANTY; without even
     the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
     PURPOSE.
=========================================================================*/

#import <Foundation/Foundation.h>
#import "DCMAttribute.h"


@interface DCMSequenceAttribute : DCMAttribute {

	NSMutableArray *sequenceItems;
}

@property(retain) NSMutableArray *sequenceItems;
@property(readonly) NSArray *sequence;

//for structured reporting
+ (id)contentSequence;
+ (id)conceptNameCodeSequenceWithCodeValue:(NSString *)codeValue 
		codeSchemeDesignator:(NSString *)csd  
		codeMeaning:(NSString *)cm;

+ (id)sequenceAttributeWithName:(NSString *)name;
- (void)addItem:(id)item;
- (void)addItem:(id)item offset:(long)offset;

@end
