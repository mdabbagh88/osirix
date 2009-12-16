//
//  N2GridLayout.mm
//  Nitrogen
//
//  Created by Alessandro Volz on 11.11.09.
//  Copyright 2009 OsiriX Team. All rights reserved.
//

#import "N2ColumnLayout.h"
#import "N2CellDescriptor.h"
#import "NSView+N2.h"
#import "N2Operators.h"
#include <algorithm>
#include <cmath>
#include <iostream> // TODO: remove

@implementation N2ColumnLayout

-(id)initForView:(N2View*)view columnDescriptors:(NSArray*)columnDescriptors controlSize:(NSControlSize)controlSize {
	self = [super initWithView:view controlSize:controlSize];
	
	_columnDescriptors = [columnDescriptors retain];
	_rows = [[NSMutableArray alloc] initWithCapacity:8];
	
	return self;
}

-(id)initForView:(N2View*)view controlSize:(NSControlSize)controlSize {
	return [self initForView:view columnDescriptors:NULL controlSize:controlSize];
}

-(void)dealloc {
	[_rows release];
	[_columnDescriptors release];
	[super dealloc];
}

-(NSArray*)rowAtIndex:(NSUInteger)index {
	return [_rows objectAtIndex:index];
}

-(NSUInteger)appendRow:(NSArray*)row {
	NSUInteger i = [_rows count];
	[self insertRow:row atIndex:i];
	return i;
}

-(void)insertRow:(NSArray*)row atIndex:(NSUInteger)index {
//	if (_columnDescriptors)
//		if ([line count] != [_columnDescriptors count])
//			[NSException raise:NSGenericException format:@"The number of views in a line must match the number of columns"];
//		else if ([_lines count] && [[_lines lastObject] count] != [line count])
//			[NSException raise:NSGenericException format:@"The number of views in a line must match the number of views in all other lines"];
	
	NSUInteger colNumber = 0;
	NSMutableArray* cells = [NSMutableArray arrayWithCapacity:[row count]];
	for (id cell in row) {
		if ([cell isKindOfClass:[NSView class]])
			cell = [(_columnDescriptors? [[[_columnDescriptors objectAtIndex:colNumber] copy] autorelease] : [N2CellDescriptor descriptor]) view:cell];
		[cells addObject:cell];
		colNumber += [cell colSpan];
		[_view addSubview:[cell view]];
	}

	[_rows insertObject:cells atIndex:index];
	
	[self layOut];
}

-(void)removeRowAtIndex:(NSUInteger)index {
	for (N2CellDescriptor* cell in [_rows objectAtIndex:index])
		[[cell view] removeFromSuperview];
	[_rows removeObjectAtIndex:index];
}

-(void)removeAllRows {
	for (int i = [_rows count]-1; i >= 0; --i)
		[self removeRowAtIndex:i];
}

typedef struct ConstrainedFloat {
	CGFloat value;
	N2MinMax constraint;
} ConstrainedFloat;

-(NSArray*)computeSizesForWidth:(CGFloat)widthWithMarginAndBorder {
	NSUInteger rowsCount = [_rows count];
	NSUInteger colsCount = [_columnDescriptors count];
	
	if (!rowsCount)
		return NULL;
	
	ConstrainedFloat widths[colsCount][colsCount];
	for (NSUInteger i = 0; i < colsCount; ++i)
		for (NSUInteger j = 0; j < colsCount; ++j) {
			widths[j][i].value = 0;
			widths[j][i].constraint = N2MakeMinMax();
		}
	for (NSArray* row in _rows) {
		NSUInteger colNumber = 0;
		for (N2CellDescriptor* cell in row) {
			NSUInteger span = [cell colSpan];
			
			widths[span-1][colNumber].constraint = N2ComposeMinMax(widths[span-1][colNumber].constraint, [cell widthConstraints]);
			widths[span-1][colNumber].value = std::max(widths[span-1][colNumber].value, [cell optimalSize].width);
			
			colNumber += span;
		}
	}
	
	CGFloat width = widthWithMarginAndBorder - _margin.size.width - _separation.width*std::max((int)colsCount-1, 0);
	
	if (!_forcesSuperviewWidth && widthWithMarginAndBorder != CGFLOAT_MAX) {
		widths[colsCount-1][0].constraint = N2MakeMinMax(width);
		widths[colsCount-1][0].value = width;
	}
	
	for (NSUInteger span = 1; span <= colsCount; ++span)
		for (NSUInteger from = 0; from <= colsCount-span; ++from)
			if (widths[span-1][from].value) {
				while (true) {
					ConstrainedFloat subWidth = {0, N2MakeMinMax()};
					for (NSUInteger i = from; i < from+span; ++i) {
						subWidth.value += widths[0][i].value;
						subWidth.constraint = subWidth.constraint + widths[0][i].constraint;
					}

					subWidth.value = std::max(widths[span-1][from].value, subWidth.value);
					subWidth.constraint = N2ComposeMinMax(widths[span-1][from].constraint, subWidth.constraint);
					subWidth.value = N2MinMaxConstrainedValue(subWidth.constraint, subWidth.value);
					
					widths[span-1][from] = subWidth;
					
					CGFloat currentWidth = 0, targetWidth = subWidth.value - (span-1)*_separation.width;
					for (NSUInteger i = from; i < from+span; ++i)
						currentWidth += widths[0][i].value = N2MinMaxConstrainedValue(widths[0][i].constraint, widths[0][i].value);
					
					if (std::floor(currentWidth+0.5) == std::floor(subWidth.value+0.5) || subWidth.value <= 0)
						break;
					
					CGFloat deltaWidth = targetWidth-currentWidth; // if (deltaWidth > 0) increase
					if (deltaWidth*deltaWidth < 0.7)
						break;
					
					BOOL colFixed[colsCount];
					int unfixedColsCount = 0;
					CGFloat unfixedRefWidth = 0;
					for (NSUInteger i = from; i < from+span; ++i)
						if (!(colFixed[i] = !((deltaWidth > 0 && widths[0][i].value < widths[0][i].constraint.max) || (deltaWidth < 0 && widths[0][i].value > widths[0][i].constraint.min)))) {
							++unfixedColsCount;
							unfixedRefWidth += widths[0][i].value;
						}
					
					if (!unfixedColsCount)
						break;
					
					for (NSUInteger i = from; i < from+span; ++i)
						if (!colFixed[i])
							widths[0][i].value *= 1+deltaWidth/unfixedRefWidth;
				}
			}
	
	// views are as wide as the cells
//	for (NSUInteger span = 1; span <= colsCount; ++span)
//		for (NSUInteger from = 0; from <= colsCount-span; ++from) {
//			ConstrainedFloat subWidth = {0, N2MakeMinMax()};
//			for (NSUInteger i = from; i < from+span; ++i) {
//				subWidth.value = subWidth.value + widths[0][i].value;
//				subWidth.constraint = subWidth.constraint + widths[0][i].constraint;
//			}
//			
//			widths[span-1][from].value = std::max(widths[span-1][from].value, subWidth.value);
//			widths[span-1][from].constraint = N2ComposeMinMax(widths[span-1][from].constraint, subWidth.constraint);
//		}
	
	// get cell sizes and row heights
	NSSize sizes[rowsCount][colsCount];
	memset(sizes, 0, sizeof(NSSize)*rowsCount*colsCount);
//	CGFloat rowHeights[rowsCount];
	for (NSUInteger r = 0; r < rowsCount; ++r) {
		NSArray* row = [_rows objectAtIndex:r];
		NSUInteger colNumber = 0;
//		rowHeights[l] = 0;
		for (N2CellDescriptor* cell in row) {
			NSUInteger span = [cell colSpan];
			
			CGFloat spannedWidth = -_separation.width;
			for (NSUInteger i = colNumber; i < colNumber+span; ++i)
				spannedWidth += widths[0][i].value + _separation.width;
			
			sizes[r][colNumber] = [cell optimalSizeForWidth:spannedWidth];
//			rowHeights[l] = std::max(rowHeights[l], sizes[l][i].height);
			NSSize test = sizes[r][colNumber];
			
			colNumber += span;
		}
	}
	
	NSMutableArray* resultSizes = [NSMutableArray arrayWithCapacity:rowsCount];
	for (NSUInteger r = 0; r < rowsCount; ++r) {
		NSMutableArray* resultRowSizes = [NSMutableArray arrayWithCapacity:colsCount];
		for (NSUInteger i = 0; i < colsCount; ++i)
			[resultRowSizes addObject:[NSValue valueWithSize:sizes[r][i]]];
		[resultSizes addObject:resultRowSizes];
	}
	NSMutableArray* resultColWidths = [NSMutableArray arrayWithCapacity:colsCount];
	for (NSUInteger i = 0; i < colsCount; ++i)
		[resultColWidths addObject:[NSNumber numberWithFloat:widths[0][i].value]];
	return [NSArray arrayWithObjects: resultColWidths, resultSizes, NULL];
}

-(void)layOutImpl {
	NSUInteger rowsCount = [_rows count];
	NSUInteger colsCount = [_columnDescriptors count];

	NSSize size = [_view frame].size;
	
	NSArray* sizesData = [self computeSizesForWidth:size.width];
	CGFloat colWidth[colsCount];
	for (NSUInteger i = 0; i < colsCount; ++i)
		colWidth[i] = [[[sizesData objectAtIndex:0] objectAtIndex:i] floatValue];
	NSSize sizes[rowsCount][colsCount];
	CGFloat rowHeights[rowsCount];
	for (NSUInteger r = 0; r < rowsCount; ++r) {
		NSArray* rowsizes = [[sizesData objectAtIndex:1] objectAtIndex:r];
		rowHeights[r] = 0;
		for (NSUInteger i = 0; i < colsCount; ++i) {
			sizes[r][i] = [[rowsizes objectAtIndex:i] sizeValue];
			rowHeights[r] = std::max(rowHeights[r], sizes[r][i].height);
		}
	}
		
	// apply computed column widths
	
	CGFloat y = _margin.origin.y;
	if (!_forcesSuperviewHeight) {
		CGFloat height = _margin.size.height-_separation.height;
		for (NSUInteger r = 0; r < rowsCount; ++r)
			height += rowHeights[r]+_separation.height;
		y += ([_view bounds].size.height - height)/2;
	}
	
	CGFloat maxX = 0;
	for (NSInteger r = rowsCount-1; r >= 0; --r) {
		NSArray* row = [_rows objectAtIndex:r];
		
		CGFloat x = _margin.origin.x;
		NSUInteger colNumber = 0;
		for (N2CellDescriptor* cell in row) {
			NSUInteger span = [cell colSpan];
			CGFloat spannedWidth = -_separation.width;
			for (NSUInteger i = colNumber; i < colNumber+span; ++i)
				spannedWidth += colWidth[i]+_separation.width;
			
			NSPoint origin = NSMakePoint(x, y);
			NSSize size = sizes[r][colNumber];
			NSRect sizeAdjust = [[cell view] respondsToSelector:@selector(sizeAdjust)]? [(id<SizeAdjusting>)[cell view] sizeAdjust] : NSZeroRect;
			
			/*if (size.width < spannedWidth)*/ size.width = spannedWidth; ////// TODO: CHANGE HERE!!!!!!! darn
			size.width = std::ceil(size.width);
			size.height = std::ceil(size.height);
			
			NSSize extraSpace = NSMakeSize(spannedWidth, rowHeights[r]) - size;
			N2Alignment alignment = [cell alignment];
			if (alignment&N2Top)
				origin.y += extraSpace.height;
			else if (alignment&N2Bottom)
				origin.y += 0;
			else
				origin.y += extraSpace.height/2;
			if (alignment&N2Right)
				origin.x += extraSpace.width;
			else if (alignment&N2Left)
				origin.x += 0;
			else
				origin.x += extraSpace.width/2;
			
			[[cell view] setFrame:NSMakeRect(origin+sizeAdjust.origin, size+sizeAdjust.size)];
			
			x += spannedWidth+_separation.width;
			colNumber += span;
		}
		x += _margin.size.width-_margin.origin.x - _separation.width;
		
		maxX = std::max(maxX, x);
		y += rowHeights[r]+_separation.height;
	}
	y += _margin.size.height-_margin.origin.y - _separation.height;
	
	// superview size
	if (_forcesSuperviewWidth || _forcesSuperviewHeight) {
		// compute
		NSSize newSize = size;
		if (_forcesSuperviewWidth)
			newSize.width = maxX;
		if (_forcesSuperviewHeight)
			newSize.height = y;
		// apply
		NSWindow* window = [_view window];
		if (_view == [window contentView]) {
			NSRect frame = [window frame];
			NSSize oldFrameSize = frame.size;
			frame.size = [window frameRectForContentRect:NSMakeRect(NSZeroPoint, newSize)].size;
			frame.origin = frame.origin - (frame.size - oldFrameSize);
			[window setFrame:frame display:YES];
		} else
			[_view setFrameSize:newSize];
	}
}

-(NSSize)optimalSizeForWidth:(CGFloat)width {
	if (!_enabled) return [_view frame].size;
	
	NSUInteger rowsCount = [_rows count];
	NSUInteger colsCount = [_columnDescriptors count];
	
	NSArray* sizesData = [self computeSizesForWidth:width];
	CGFloat colWidth[colsCount];
	for (NSUInteger i = 0; i < colsCount; ++i)
		colWidth[i] = [[[sizesData objectAtIndex:0] objectAtIndex:i] floatValue];
	NSSize sizes[rowsCount][colsCount];
	CGFloat rowHeights[rowsCount];
	for (NSUInteger r = 0; r < rowsCount; ++r) {
		NSArray* rowsizes = [[sizesData objectAtIndex:1] objectAtIndex:r];
		rowHeights[r] = 0;
		for (NSUInteger i = 0; i < colsCount; ++i) {
			sizes[r][i] = [[rowsizes objectAtIndex:i] sizeValue];
			rowHeights[r] = std::max(rowHeights[r], sizes[r][i].height);
		}
	}
	
	// sum up sizes
	CGFloat y = _margin.origin.y;
	CGFloat maxX = 0;
	for (NSInteger r = rowsCount-1; r >= 0; --r) {
		NSArray* row = [_rows objectAtIndex:r];
		
		CGFloat x = _margin.origin.x;
		NSUInteger colNumber = 0;
		for (N2CellDescriptor* cell in row) {
			NSUInteger span = [cell colSpan];
			
			x += colWidth[colNumber]+_separation.width;
			
			colNumber += span;
		}
		x += _margin.size.width-_margin.origin.x - _separation.width;
		
		maxX = std::max(maxX, x);
		y += rowHeights[r]+_separation.height;
	}
	y += _margin.size.height-_margin.origin.y - _separation.height;
	
	return NSMakeSize(maxX, y);
}

-(NSSize)optimalSize {
	return [self optimalSizeForWidth:CGFLOAT_MAX];
}

#pragma mark Deprecated

-(NSArray*)lineAtIndex:(NSUInteger)index {
	return [self rowAtIndex:index];
}

-(NSUInteger)appendLine:(NSArray*)line {
	return [self appendRow:line];
}

-(void)insertLine:(NSArray*)line atIndex:(NSUInteger)index {
	[self insertRow:line atIndex:index];
}

-(void)removeLineAtIndex:(NSUInteger)index {
	[self removeRowAtIndex:index];
}

-(void)removeAllLines {
	[self removeAllRows];
}

@end
