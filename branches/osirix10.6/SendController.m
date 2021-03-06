/*=========================================================================
  Program:   OsiriX

  Copyright (c) OsiriX Team
  All rights reserved.
  Distributed under GNU - LGPL
  
  See http://www.osirix-viewer.com/copyright.html for details.

     This software is distributed WITHOUT ANY WARRANTY; without even
     the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
     PURPOSE.
=========================================================================*/

#import "BrowserController.h"
#import "SendController.h"
#import "Wait.h"
#import <OsiriX/DCMNetServiceDelegate.h>
#import <OsiriX/DCM.h>
#import "PluginFilter.h"
#import "PluginManager.h"
#import "DCMTKStoreSCU.h"
#import "MutableArrayCategory.h"
#import "Notifications.h"
#import "QueryController.h"
#import "DicomStudy.h"
#import "ThreadsManager.h"
#import "NSThread+N2.h"
#import "NSUserDefaults+OsiriX.h"

static volatile int sendControllerObjects = 0;

@implementation SendController

+(int) sendControllerObjects
{
	return sendControllerObjects;
}

+ (void) sendFiles:(NSArray *) files toNode: (NSDictionary*) node
{
	return [SendController sendFiles: files toNode: node usingSyntax: SendExplicitLittleEndian];
}

+ (void) sendFiles:(NSArray *) files toNode: (NSDictionary*) node usingSyntax: (int) syntax
{
	BOOL s = [[NSUserDefaults standardUserDefaults] boolForKey: @"sendROIs"];

	[[NSUserDefaults standardUserDefaults] setBool: YES forKey: @"sendROIs"];
	[[NSUserDefaults standardUserDefaults] setInteger: syntax forKey:@"syntaxListOffis"];
	
	SendController *sendController = [[SendController alloc] initWithFiles: files];
	
	[sendController sendToNode: node objects: nil];
	
	[[NSUserDefaults standardUserDefaults] setBool: s forKey: @"sendROIs"];
}

+ (void) sendFiles: (NSArray *) files
{
	if( [[NSUserDefaults standardUserDefaults] boolForKey: @"DICOMSENDALLOWED"] == NO)
	{
		NSRunCriticalAlertPanel(NSLocalizedString(@"DICOM Send",nil),NSLocalizedString( @"DICOM Sending is not activated. Contact your PACS manager for more information about DICOM Send.",nil),NSLocalizedString( @"OK",nil), nil, nil);
		return;
	}

	if( [files  count])
	{
		if( [[DCMNetServiceDelegate DICOMServersListSendOnly: YES QROnly: NO] count] > 0)
		{
			SendController *sendController = [[SendController alloc] initWithFiles:files];
			[NSApp beginSheet: [sendController window] modalForWindow:[NSApp mainWindow] modalDelegate:sendController didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
		}
		else
		{
			NSRunCriticalAlertPanel(NSLocalizedString(@"DICOM Send",nil),NSLocalizedString( @"No DICOM destinations available. See Preferences to add DICOM locations.",nil),NSLocalizedString( @"OK",nil), nil, nil);
		}
	}
	else
	{
		NSRunCriticalAlertPanel(NSLocalizedString(@"DICOM Send",nil),NSLocalizedString( @"No files are selected...",nil),NSLocalizedString( @"OK",nil), nil, nil);
	}
}

- (id)initWithFiles:(NSArray *)files
{
	if (self = [super initWithWindowNibName:@"Send"])
	{
		NSLog( @"SendController initWithFiles: %d files", (int) files.count);
		
		sendControllerObjects++;
		
		_abort = NO;
		_files = [files copy];
		
		[self setNumberFiles: [NSString stringWithFormat: @"%d", [_files  count]]];
		
		_serverIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"lastSendServer"];	
		
		if( _serverIndex >= [[DCMNetServiceDelegate DICOMServersListSendOnly:YES QROnly: NO] count])
			_serverIndex = 0;
		
		_keyImageIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"lastSendWhat"];
		
		_readyForRelease = NO;
		_lock = [[NSRecursiveLock alloc] init];
		
		[[NSNotificationCenter defaultCenter] addObserver: self
												selector: @selector( updateDestinationPopup:)
												name: OsirixServerArrayChangedNotification
												object: nil];
		
		[[NSNotificationCenter defaultCenter] addObserver: self
												selector: @selector( updateDestinationPopup:)
												name: @"DCMNetServicesDidChange"
												object: nil];
	}
	return self;
}

- (void) windowDidLoad
{
	if 	([_files  count])
	{
		[self updateDestinationPopup: nil];
		
		int count = [[DCMNetServiceDelegate DICOMServersListSendOnly:YES QROnly:NO] count];
		if (_serverIndex < count)
			[newServerList selectItemAtIndex: _serverIndex];
			
//		[DICOMSendTool selectCellWithTag: _serverToolIndex];
		[keyImageMatrix selectCellWithTag: _keyImageIndex];
		
		[self selectServer: newServerList];
	}

}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	sendControllerObjects--;
	
	NSLog(@"SendController Released");
	[_destinationServer release];
	[_files release];
	[_numberFiles release];
	[_lock lock];
	[_lock unlock];
	[_lock release];
	
	[super dealloc];
}

- (void)releaseSelfWhenDone:(id)sender
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
	[_lock lock];
	[_lock unlock];
    
	[self performSelectorOnMainThread: @selector( autorelease) withObject: nil waitUntilDone: NO];
    
    [pool release];
}

- (NSString *)numberFiles{
	return _numberFiles;
}

- (void)setNumberFiles:(NSString *)numberFiles
{
	[_numberFiles release];
	_numberFiles = [numberFiles retain];
}

- (id)server
{
	if( _destinationServer)
		return _destinationServer;
	
	return [self serverAtIndex:_serverIndex];
}


#pragma mark Accessors functions

- (id)serverAtIndex:(int)index
{
	NSArray *serversArray = [DCMNetServiceDelegate DICOMServersListSendOnly: YES QROnly:NO];
	
	if(	index > -1 && index < [serversArray count]) return [serversArray objectAtIndex:index];
	
	return nil;
}

- (IBAction)selectServer: (id)sender
{
	//NSLog(@"select server: %@", [sender description]);
	_serverIndex = [sender indexOfSelectedItem];
	
	[[NSUserDefaults standardUserDefaults] setInteger:_serverIndex forKey:@"lastSendServer"];
	
	if ([[self server] isKindOfClass:[NSDictionary class]])
	{
		int preferredTS = [[[self server] objectForKey:@"TransferSyntax"] intValue];
		
		[[NSUserDefaults standardUserDefaults] setInteger: preferredTS forKey:@"syntaxListOffis"];
	}	
	
	[addressAndPort setStringValue: [NSString stringWithFormat:@"%@ : %@", [[self server] objectForKey:@"Address"], [[self server] objectForKey:@"Port"]]];
}

- (int) keyImageIndex
{
	return _keyImageIndex;
}

- (void) setKeyImageIndex:(int)index
{
	_keyImageIndex = index;
	[[NSUserDefaults standardUserDefaults] setInteger:index forKey:@"lastSendWhat"];
}

#pragma mark sheet functions

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode  contextInfo:(void  *)contextInfo
{
}

- (IBAction) endSelectServer:(id) sender
{	
	[[self window] orderOut:sender];
	[NSApp endSheet: [self window] returnCode:[sender tag]];
	NSArray *objectsToSend = _files;
	
	if( [sender tag])   //User clicks OK Button
    {		
		if (_keyImageIndex == 1)
		{
			NSPredicate *predicate = [NSPredicate predicateWithFormat:@"isKeyImage == YES"];
			objectsToSend = [_files filteredArrayUsingPredicate:predicate];
		}
		
		if (_keyImageIndex == 2)
		{
			NSPredicate *predicate = [NSPredicate predicateWithFormat:@"modality CONTAINS[c] %@", @"SC"];
			objectsToSend = [objectsToSend filteredArrayUsingPredicate:predicate];
		}

		NSMutableArray	*files2Send = [objectsToSend valueForKey: @"completePath"];
		
		if( files2Send != nil && [files2Send count] > 0)
		{
			if( files2Send)
				[self sendToNode: [self server] objects: objectsToSend];
			else
				[self autorelease];
		}
		else
		{
			NSRunAlertPanel(NSLocalizedString(@"DICOM Send",nil),NSLocalizedString( @"There are no files of selected type to send.",nil),NSLocalizedString( @"OK",nil), nil, nil);
			
			[self autorelease];
		}
	}
	else // Cancel
		[self autorelease];
}

- (void) sendToNode: (NSDictionary*) node objects:(NSArray*) objects
{
	if( objects == nil)
		objects = _files;
	
	[_lock lock];
	[NSThread detachNewThreadSelector: @selector(releaseSelfWhenDone:) toTarget: self withObject: nil];
	
	[_destinationServer release];
	_destinationServer = [node retain];
	
	sendROIs = [[NSUserDefaults standardUserDefaults] boolForKey:@"sendROIs"];
	
	NSThread* t = [[[NSThread alloc] initWithTarget:self selector:@selector( sendDICOMFilesOffis:) object: _files] autorelease];
	t.name = NSLocalizedString( @"Sending...", nil);
	t.supportsCancel = YES;
	t.progress = 0;
	t.status = [NSString stringWithFormat: NSLocalizedString( @"%d file(s)", nil), [_files count]];
	[[ThreadsManager defaultManager] addThreadAndStart: t];
}

#pragma mark Sending functions	

- (void) showErrorMessage:(NSException*) ne
{
	NSString	*message = [NSString stringWithFormat:@"%@\r\r%@\r%@", NSLocalizedString( @"DICOM StoreSCU operation failed.", nil), [ne name], [ne reason]];

	NSRunCriticalAlertPanel(NSLocalizedString(@"DICOM Send Error",nil), message, NSLocalizedString( @"OK",nil), nil, nil);
}

- (void) executeSend :(NSArray*) samePatientArray
{
	if( [NSThread currentThread].isCancelled)
		return;
	
    DicomDatabase* database = [DicomDatabase databaseForContext:[[samePatientArray objectAtIndex:0] managedObjectContext]];
    
	[NSThread currentThread].name = [NSString stringWithFormat: @"%@ %@", NSLocalizedString( @"Sending...", nil), [[samePatientArray lastObject] valueForKeyPath: @"series.study.name"]];
		
	if( sendROIs == NO)
	{
		@try
		{
			NSPredicate *predicate = nil;
			
			predicate = [NSPredicate predicateWithFormat:@"!(series.name CONTAINS[c] %@) AND !(series.id == %@)", @"OsiriX ROI SR", @"5002"];
			samePatientArray = [samePatientArray filteredArrayUsingPredicate:predicate];
			
			predicate = [NSPredicate predicateWithFormat:@"!(series.name CONTAINS[c] %@) AND !(series.id == %@)", @"OsiriX Report SR", @"5003"];
			samePatientArray = [samePatientArray filteredArrayUsingPredicate:predicate];
			
			predicate = [NSPredicate predicateWithFormat:@"!(series.name CONTAINS[c] %@) AND !(series.id == %@)", @"OsiriX Annotations SR", @"5004"];
			samePatientArray = [samePatientArray filteredArrayUsingPredicate:predicate];
		}
		
		@catch( NSException *e)
		{
			NSLog( @"***** executeSend exception: %@", e);
		}
	}
	
	NSArray	*files = [samePatientArray valueForKey: @"completePathResolved"];
	
	// Send the collected files from the same patient
	
	NSString *calledAET = [[self server] objectForKey:@"AETitle"];
	NSString *hostname = [[self server] objectForKey:@"Address"];
	NSString *destPort = [[self server] objectForKey:@"Port"];
	
    NSMutableDictionary* xp = [NSMutableDictionary dictionaryWithDictionary:[self server]];
    [xp setObject:database forKey:@"DicomDatabase"];
    
	storeSCU = [[DCMTKStoreSCU alloc] initWithCallingAET:[NSUserDefaults defaultAETitle] 
			calledAET:calledAET 
			hostname:hostname 
			port:[destPort intValue] 
			filesToSend:files
			transferSyntax: [[NSUserDefaults standardUserDefaults] integerForKey:@"syntaxListOffis"]
			compression: 1.0
			extraParameters:xp];
	
	@try
	{
		[storeSCU run:self];
	}
	
	@catch( NSException *ne)
	{
		[self performSelectorOnMainThread:@selector(showErrorMessage:) withObject:ne waitUntilDone: NO];
	}
	
	[storeSCU release];
	storeSCU = nil;
}

- (void) sendDICOMFilesOffis:(NSArray *) tempObjectsToSend 
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSMutableArray *samePatientArray = 0L;
    NSMutableArray *objectsToSend = 0L;
    NSString *calledAET = [[self server] objectForKey:@"AETitle"];
    
	[[DicomStudy dbModifyLock] lock];
	
	@try
	{
		NSSortDescriptor	*sort = [[[NSSortDescriptor alloc] initWithKey:@"series.study.patientUID" ascending:YES] autorelease];
		NSArray				*sortDescriptors = [NSArray arrayWithObject: sort];
		
		tempObjectsToSend = [tempObjectsToSend sortedArrayUsingDescriptors: sortDescriptors];
        
		if( calledAET == nil)
			calledAET = @"AETITLE";
		
		// Remove duplicated files 
		objectsToSend = [NSMutableArray arrayWithArray: tempObjectsToSend];
        
		NSMutableArray *paths = [NSMutableArray arrayWithArray: [objectsToSend valueForKey: @"completePathResolved"]];
		
		[paths removeDuplicatedStringsInSyncWithThisArray: objectsToSend];
		
		NSLog(@"Server destination: %@", [[self server] description]);	
				
		NSString *previousPatientUID = nil;
        
        samePatientArray = [NSMutableArray arrayWithCapacity: [objectsToSend count]];
		
		for( id loopItem in objectsToSend)
		{
			[[[BrowserController currentBrowser] managedObjectContext] lock];
			NSString *patientUID = [loopItem valueForKeyPath:@"series.study.patientUID"];
			[[[BrowserController currentBrowser] managedObjectContext] unlock];
			
			if( [previousPatientUID isEqualToString: patientUID])
			{
				[samePatientArray addObject: loopItem];
			}
			else
			{
				if( [samePatientArray count])
				{
					[[DicomStudy dbModifyLock] unlock];
					
					[self executeSend: samePatientArray];
					
					[[DicomStudy dbModifyLock] lock];
				}
				// Reset
				[samePatientArray removeAllObjects];
				[samePatientArray addObject: loopItem];
				
				previousPatientUID = [[patientUID copy] autorelease];
			}
		}
		
		
	}
	@catch (NSException *e)
	{
		NSLog( @"***** sendDICOMFilesOffis exception: %@", e);
	}
    
    [[DicomStudy dbModifyLock] unlock];
    
    if( [samePatientArray count])
        [self executeSend: samePatientArray];
    
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    [info setObject:[NSNumber numberWithInt:[objectsToSend count]] forKey:@"SendTotal"];
    [info setObject:[NSNumber numberWithInt:[objectsToSend count]] forKey:@"NumberSent"];
    [info setObject:[NSNumber numberWithBool:YES] forKey:@"Sent"];
    [info setObject:calledAET forKey:@"CalledAET"];
	
	[pool release];
	
	//need to unlock to allow release of self after send complete
	[_lock performSelectorOnMainThread:@selector(unlock) withObject:nil waitUntilDone: NO];
}

#pragma mark serversArray functions

- (void) updateDestinationPopup: (NSNotification *)note
{
	if( newServerList)
	{
		NSString *currentTitle = [[[newServerList selectedItem] title] retain];
		
		[newServerList removeAllItems];
		for( NSDictionary *d in [DCMNetServiceDelegate DICOMServersListSendOnly:YES QROnly:NO])
		{
			NSString *title = [NSString stringWithFormat:@"%@ - %@",[d objectForKey:@"AETitle"],[d objectForKey:@"Description"]];
			
			while( [newServerList indexOfItemWithTitle: title] != -1)
				title = [title stringByAppendingString: @" "];
				
			[newServerList addItemWithTitle: title];
		}
		
		for( NSMenuItem *d in [newServerList itemArray])
		{
			if( [[d title] isEqualToString: currentTitle])
				[newServerList selectItem: d];
		}
		
		[currentTitle release];
	}
}
@end
