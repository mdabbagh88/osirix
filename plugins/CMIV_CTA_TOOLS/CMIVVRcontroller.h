
/*=========================================================================
CMIVVRcontroller

Show different segment with different property like color, opacity.
This technique can only use nearest interpolation. Hopefully in the
future this feature will be improved.

Author: Chunliang Wang (chunliang.wang@imv.liu.se)


Program:  CMIV CTA image processing Plugin for OsiriX

This file is part of CMIV CTA image processing Plugin for OsiriX.

Copyright (c) 2007,
Center for Medical Image Science and Visualization (CMIV),
Link�ping University, Sweden, http://www.cmiv.liu.se/

CMIV CTA image processing Plugin for OsiriX is free software;
you can redistribute it and/or modify it under the terms of the
GNU General Public License as published by the Free Software 
Foundation, either version 3 of the License, or (at your option)
any later version.

CMIV CTA image processing Plugin for OsiriX is distributed in
the hope that it will be useful, but WITHOUT ANY WARRANTY; 
without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=========================================================================*/
#import <Cocoa/Cocoa.h>
#import "PluginFilter.h"
#import "CMIV_CTA_TOOLS.h"
#import "VRView.h"
#import "ColorTransferView.h"
#define id Id
#include <vtkColorTransferFunction.h>
#include <vtkRenderer.h>
#include <vtkVolumeCollection.h>
#include <vtkVolume.h>
#include <vtkVolumeProperty.h>
#include <vtkVolumeMapper.h>
#include <vtkImageData.h>
#undef id


@interface CMIVVRcontroller : NSObject
{
	IBOutlet NSWindow	*window;   
	IBOutlet NSColorWell *colorControl;
    IBOutlet ColorTransferView *colorViewer;
    IBOutlet NSSlider *opacitySlider;
    IBOutlet NSTableView *segmentList;
    IBOutlet VRView *vrViewer;
    IBOutlet NSSlider *wlSlider;
    IBOutlet NSSlider *wwSlider;
    IBOutlet NSButton *wlwwForAll;
	int imageWidth,imageHeight,imageAmount; 	
	ViewerController     *originalViewController;
	float  wholeVolumeWL,wholeVolumeWW;
	NSMutableArray      *propertyDictList;	
	NSMutableDictionary *curProperyDict;
	NSMutableArray      *toolbarList;
	NSMutableArray      *clutViewPoints;
	NSMutableArray      *clutViewColors;
	
	float          *originalVolumeData;
	vtkRenderer *renderOfVRView;
	vtkVolumeCollection *volumeCollectionOfVRView;
	vtkVolume   *volumeOfVRView;
	vtkVolumeProperty *volumePropteryOfVRView,*myVolumeProperty;
	vtkColorTransferFunction *myColorTransferFunction;
	vtkPiecewiseFunction	*myOpacityTransferFunction;
	vtkPiecewiseFunction	*myGradientTransferFunction;
	vtkVolumeMapper *volumeMapper;
	vtkImageData *volumeImageData;
	vtkCamera *aCamera;
	float verticalAngleForVR;
	float osirixOffset;
	unsigned short* realVolumedata;
	long maxMovieIndex;
	int  isSegmentVR;
	CMIV_CTA_TOOLS* parent;	
}
- (IBAction)capureImage:(id)sender;
- (IBAction)endPanel:(id)sender;
- (IBAction)setColorProtocol:(id)sender;
- (IBAction)setOpacity:(id)sender;
- (IBAction)setWLWW:(id)sender;
- (IBAction)selectASegment:(id)sender;
- (IBAction)changeVRDirection:(id)sender;
- (IBAction)setBackgroundColor:(id)sender;

- (int) initVRViewForSegmentalVR;
- (int) initVRViewForDynamicVR;
- (int) showVRPanel:(ViewerController *) vc :(CMIV_CTA_TOOLS*) owner;
- (void) applyCLUT;
- (void) applyOpacity;
- (void)restoreCLUTFromPropertyList:(int)index;
- (void)applyCLUTToPropertyList:(int)index;
- (void)reHideToolbar;
	// Table view data source methods
- (int)numberOfRowsInTableView:(NSTableView *)aTableView;
- (id)tableView:(NSTableView *)aTableView
    objectValueForTableColumn:(NSTableColumn *)aTableColumn
			row:(int)rowIndex;

//to cheat VRView
- (float) minimumValue;
- (float) maximumValue;
- (ViewerController*) viewer2D;
-(NSImage*) imageForFrame:(NSNumber*) cur maxFrame:(NSNumber*) max;
-(NSImage*) imageForVR:(NSNumber*) cur maxFrame:(NSNumber*) max;
@end
