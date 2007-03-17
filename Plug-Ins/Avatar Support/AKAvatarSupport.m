//
//  AKAvatarSupport.m
//  Avatar Support
//
//  Created by Alexander Kempgen on 27.02.07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

//Avatar Support Header
#import "AKAvatarSupport.h"

//MVChatPlugin and MVChatPluginReloadSupport
#import "MVChatPluginManager.h"
//MVChatPluginDirectChatSupport
@class JVDirectChatPanel;
//MVChatPluginChatConnectionSupport
#import "MVChatConnection.h"

//For Growl output
#import "/Users/Alex/dev/svn/colloquy/Controllers/JVNotificationController.h"

//some classes
#import "JVChatMessage.h"
#import "MVChatUser.h"
#import "JVChatRoomMember.h"

//the chat view controller protocol
@protocol JVChatViewController;

//The Subcode (CTCP) string that we react to
NSString *AKAvatarSupportCTCPCommand = @"AVATAR";
//Where we store our avatars
NSString *cacheDir = @"~/Library/Caches/info.colloquy.avatarSupport/";


@implementation AKAvatarSupport

#pragma mark -
#pragma mark MVChatPlugin

- (id) initWithManager:(MVChatPluginManager *)manager
{
	self = [super init];
	//NSLog(@"Avatar Support: ** Plugin loaded");
	return self;
}

- (void) dealloc
{
	[super dealloc];
}

#pragma mark -
#pragma mark MVChatPluginReloadSupport

- (void) load
{
	if ([[NSFileManager defaultManager] fileExistsAtPath: [cacheDir stringByExpandingTildeInPath]] == NO)
	{
		[[NSFileManager defaultManager] createDirectoryAtPath: [cacheDir stringByExpandingTildeInPath] attributes: nil];
		NSLog(@"Avatar Support: ** Cache directory created at %@.", cacheDir);
	}
}

- (void) unload
{
	
}

#pragma mark -
#pragma mark MVChatPluginDirectChatSupport

- (void) processIncomingMessage:(JVMutableChatMessage *)message inView:(id <JVChatViewController>)view
{
	//TODO: use this if to put the user object into a var, call addavatartouser after the if (#1)
	if([[message sender] isMemberOfClass:[JVChatRoomMember class]])
	{
		//NSLog(@"Avatar Support: -- %@ (class), user: %@/%@: %@ (class)", [[[message sender] class] description], [[(JVChatRoomMember *)[message sender] user] serverAddress], [[(JVChatRoomMember *)[message sender] user] nickname], [[[[message sender] user] class] description]);
		
		//TODO: check for buddies, unless this works for them too (doesnt, *.quakenet.org bug)
		if ([[[(JVChatRoomMember *)[message sender] user] attributes] objectForKey:@"MVChatUserPictureAttribute"] == nil)
		{
			//NSLog(@"Avatar Support: -- nil: %@", [[[[(JVChatRoomMember *)[message sender] user] attributes] objectForKey:@"MVChatUserPictureAttribute"] description]);
			[self addAvatarToUser:[(JVChatRoomMember *)[message sender] user]];
		}
		else
		{
			//NSLog(@"Avatar Support: -- nicht nil: %@", [[[[(JVChatRoomMember *)[message sender] user] attributes] objectForKey:@"MVChatUserPictureAttribute"] description]);
			//TODO: remove this
			[[JVNotificationController defaultController] performNotification:@"JVPluginNotification" withContextInfo:[NSDictionary dictionaryWithObjectsAndKeys:[[[(JVChatRoomMember *)[message sender] user] attributes] objectForKey:@"MVChatUserPictureAttribute"],@"image",@"Avatar Support",@"title",[NSString stringWithFormat:@"%@ already has an Avatar.", [[(JVChatRoomMember *)[message sender] user] nickname]],@"description",nil]];
		}
	}
	else
	{
		//TODO: this is for direct chats, see comment #1 above
		//NSLog(@"Avatar Support: -- %@/%@: %@ (class)", [(MVChatUser *)[message sender] serverAddress], [(MVChatUser *)[message sender] nickname], [[[message sender] class] description]);
		
		//TODO: check for buddies, unless this works for them too (doesnt)
		if ([[(MVChatUser *)[message sender] attributes] objectForKey:@"MVChatUserPictureAttribute"] == nil)
		{
			//NSLog(@"Avatar Support: -- nil: %@", [[[(MVChatUser *)[message sender] attributes] objectForKey:@"MVChatUserPictureAttribute"] description]);
			[self addAvatarToUser:(MVChatUser *)[message sender]];
		}
		else
		{
			//NSLog(@"Avatar Support: --nicht nil: %@", [[[(MVChatUser *)[message sender] attributes] objectForKey:@"MVChatUserPictureAttribute"] description]);
			//TODO: remove this
			[[JVNotificationController defaultController] performNotification:@"JVPluginNotification" withContextInfo:[NSDictionary dictionaryWithObjectsAndKeys:[[(MVChatUser *)[message sender] attributes] objectForKey:@"MVChatUserPictureAttribute"],@"image",@"Avatar Support",@"title",[NSString stringWithFormat:@"%@ already has an Avatar.", [(MVChatUser *)[message sender] nickname]],@"description",nil]];
		}
	}
}

- (void) processOutgoingMessage:(JVMutableChatMessage *)message inView:(id <JVChatViewController>)view
{
	//TODO: do we need to implement this?
}

#pragma mark -
#pragma mark MVChatPluginChatConnectionSupport

- (BOOL) processSubcodeRequest:(NSString *)command withArguments:(NSData *)arguments fromUser:(MVChatUser *)chatUser
{
	if ([[command uppercaseString] isEqualToString:@"AVATEST"])
	{
		//TODO: remove NSLog
		NSLog(@"Avatar Support: <- Bogus request event for %@.", [chatUser nickname]);
		[self requestAvatarFromUser:chatUser];
		return YES;
	}
	if ([[command uppercaseString] isEqualToString:AKAvatarSupportCTCPCommand])
	{
		//TODO: remove NSLog
		NSLog(@"Avatar Support: -> request by %@.", [chatUser nickname]);
//		if (weWantToSendAvatarToUser:chatUser)
//		{
			[self offerAvatarToUser:chatUser];
			return YES;
//		}
	}
	return NO;
}

- (BOOL) processSubcodeReply:(NSString *)command withArguments:(NSData *)arguments fromUser:(MVChatUser *)chatUser
{
	if ([[command uppercaseString] isEqualToString:AKAvatarSupportCTCPCommand])
	{
		NSArray *argumentArray = [[[[NSString alloc] initWithData:arguments encoding:[[chatUser connection] encoding]] autorelease] componentsSeparatedByString:@" "];
		
		//TODO: remove NSLog
		NSLog(@"Avatar Support: <- reply from %@ with arguments %@.", [chatUser nickname], [argumentArray description]);
		
//		if (weWantToReceiveAvatarFromUser:chatUser)
//		{
			//NSLog(@"Avatar Support: <- accepting avatar from %@.", [chatUser nickname]);
			NSImage *receivedImage = [NSImage alloc];
			
			//TODO: do some checks first: filezise, evil filetypes...
			if ([receivedImage initWithContentsOfURL:[NSURL URLWithString:[argumentArray objectAtIndex:0]]])
			{
				[self saveAvatar:receivedImage forUser:chatUser];
				[self addAvatarToUser:chatUser];
				[[JVNotificationController defaultController] performNotification:@"JVPluginNotification" withContextInfo:[NSDictionary dictionaryWithObjectsAndKeys:[[chatUser attributes] objectForKey:@"MVChatUserPictureAttribute"],@"image",@"Avatar Support",@"title",[NSString stringWithFormat:@"Received Avatar from user %@.", [chatUser nickname]],@"description",nil]];
				return YES;
			}
//			else
//			{
//				if (filesizeisokay)
//				{
					//NSLog(@"Avatar Support: <- dcc file transfer request for %@ required.", [chatUser nickname]);
					//[18:39] <xenon> there is, just dont add it to the MVFileTransferManager
					//MVFileTransferController
					//MVFileTransfer
					//filetransfer <- requestAvatarFromUser:chatUser
					//filetransferdelegate: [self addAvatarToUser:chatUser];
					//return YES;
//				}
//			}
//		}
	}
	return NO;
}

#pragma mark -
#pragma mark Plugin Methods


- (void) requestAvatarFromUser:(MVChatUser *)chatUser
{
	//TODO: remove NSLog
	NSLog(@"Avatar Support: <- request from %@.", [chatUser nickname]);
	[chatUser sendSubcodeRequest:AKAvatarSupportCTCPCommand withArguments:@"?"];
}

- (void) offerAvatarToUser:(MVChatUser *)chatUser
{
	//TODO: remove NSLog
	NSLog(@"Avatar Support: -> reply to %@.", [chatUser nickname]);
	[chatUser sendSubcodeReply:AKAvatarSupportCTCPCommand withArguments:@"http://alex.speanet.info/stuff/AKAvatarSupportIcon.png"];
}

- (void) saveAvatar:(NSImage *)theImage forUser:(MVChatUser *)chatUser
{
	//TODO: add filetype extensions somehow, overwrite rules
	if([[theImage TIFFRepresentation] writeToFile:[[[cacheDir stringByExpandingTildeInPath] stringByAppendingPathComponent:[chatUser serverAddress]] stringByAppendingPathComponent:[chatUser nickname]] atomically: NO])
	{
		NSLog(@"Avatar Support: <- image written for %@/%@.", [chatUser serverAddress], [chatUser nickname]);
	}
}

- (void) addAvatarToUser:(MVChatUser *)chatUser
{
	if([self avatarForUser:chatUser])
	{
	//TODO: handle buddies differnetly (ask: "add as buddy icon?")
	
	//TODO This has no actual effect in the app yet
	[chatUser setAttribute:[self avatarForUser:chatUser] forKey:@"MVChatUserPictureAttribute"];
	
	//TODO: remove this later, its enough to growl on "received avatar"
	[[JVNotificationController defaultController] performNotification:@"JVPluginNotification" withContextInfo:[NSDictionary dictionaryWithObjectsAndKeys:[[chatUser attributes] objectForKey:@"MVChatUserPictureAttribute"],@"image",@"Avatar Support",@"title",[NSString stringWithFormat:@"Avatar added for user %@.", [chatUser nickname]],@"description",nil]];
	}
}

- (NSImage *) avatarForUser:(MVChatUser *)chatUser
{
	/*if ([[NSFileManager defaultManager] fileExistsAtPath: [[[[cacheDir stringByExpandingTildeInPath] stringByAppendingPathComponent:[chatUser serverAddress]] stringByAppendingPathComponent:[chatUser nickname]] stringByAppendingPathExtension:@"png"]])
	{
		NSLog(@"Avatar Support: -- Avatar exists for user %@", [chatUser nickname]);
	}*/
		
	//TODO: what about file type extenstions?
	return [[NSImage alloc]initWithContentsOfFile: [[[cacheDir stringByExpandingTildeInPath] stringByAppendingPathComponent:[chatUser serverAddress]] stringByAppendingPathComponent:[chatUser nickname]]];
}

/*
TODO:
context menu, command line interface
file transfer support (send/receive)
local user defineable avatar
custom avatars for users
actual file management (with file extensions -> nsdictionary, lazy nsimages)
...
(fix colloquys buddies/ bubbles style)
*/

/*
Context Menu:
Avatar >
Request Avatar
Offer Avatar
Manually Select Avatar
-
clear cache
-
set my avatar
*/

@end