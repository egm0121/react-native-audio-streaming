#import "RCTBridgeModule.h"
#import "RCTEventDispatcher.h"

#import "ReactNativeAudioStreaming.h"

#define LPN_AUDIO_BUFFER_SEC 20 // Can't use this with shoutcast buffer meta data

@import AVFoundation;
@import MediaPlayer;

@implementation ReactNativeAudioStreaming {

   NSMutableDictionary* _playerPool;
   NSMutableDictionary* _callbackPool;
}

-(NSMutableDictionary*) playerPool {
   if (!_playerPool) {
      _playerPool = [NSMutableDictionary new];
   }
   return _playerPool;
}

-(NSMutableDictionary*) callbackPool {
   if (!_callbackPool) {
      _callbackPool = [NSMutableDictionary new];
   }
   return _callbackPool;
}
-(STKAudioPlayer*) playerForKey:(nonnull NSNumber*)key {
   return [[self playerPool] objectForKey:key];
}
-(NSNumber*) keyForPlayer:(nonnull STKAudioPlayer*)player {
   return [[[self playerPool] allKeysForObject:player] firstObject];
}
-(RCTResponseSenderBlock) callbackForKey:(nonnull NSNumber*)key {
   return [[self callbackPool] objectForKey:key];
}

@synthesize bridge = _bridge;

RCT_EXPORT_MODULE()
- (dispatch_queue_t)methodQueue
{
   return dispatch_get_main_queue();
}

- (ReactNativeAudioStreaming *)init
{
   self = [super init];
   if (self) {
      [self setSharedAudioSessionCategory];

      //@TODO: resume all functionality with remote control + audio interruption notifications
      [self registerAudioInterruptionNotifications];
      [self registerRemoteControlEvents];
      self.lastUrlString = @"";

      NSLog(@"ReactNativeAudioStreaming initialized");
   }

   return self;
}


-(void) tick:(NSTimer*)timer
{
   if (!self.audioPlayer) {
      return;
   }

   if (self.audioPlayer.currentlyPlayingQueueItemId != nil && self.audioPlayer.state == STKAudioPlayerStatePlaying) {
      NSNumber *progress = [NSNumber numberWithFloat:self.audioPlayer.progress];
      NSNumber *duration = [NSNumber numberWithFloat:self.audioPlayer.duration];
      NSString *url = [NSString stringWithString:self.audioPlayer.currentlyPlayingQueueItemId];

      [self.bridge.eventDispatcher sendDeviceEventWithName:@"AudioBridgeEvent" body:@{
                                                                                 @"status": @"STREAMING",
                                                                                 @"progress": progress,
                                                                                 @"duration": duration,
                                                                                 @"url": url,
                                                                                 }];
   }
}


- (void)dealloc
{

   [self unregisterAudioInterruptionNotifications];
   [self unregisterRemoteControlEvents];
}


#pragma mark - Pubic API

RCT_EXPORT_METHOD(playWithKey:(nonnull NSNumber*) key andStream:(NSString *) streamUrl )
{

   [self activate];

   STKAudioPlayer* player = [self playerForKey:key];
   if (player) {
      [player pause];
   }

   [player play:streamUrl];

}
RCT_EXPORT_METHOD(createPlayer:(nonnull NSNumber*)key)
{

   [self activate];

   STKAudioPlayer* audioPlayer = [[STKAudioPlayer alloc] initWithOptions:(STKAudioPlayerOptions){
      .flushQueueOnSeek = YES,
      .enableVolumeMixer = YES
   }];
   [audioPlayer setDelegate:self];

   [[self playerPool] setObject:audioPlayer forKey:key];
}


RCT_EXPORT_METHOD(seekToTimeWithKey:(nonnull NSNumber*) key andSeconds:(nonnull NSNumber*) seconds)
{
   STKAudioPlayer* player = [self playerForKey:key];
   if (player) {
      [player seekToTime:[seconds doubleValue]];
   }
}

RCT_EXPORT_METHOD(goForwardWithKey:(nonnull NSNumber*) key andSeconds:(nonnull NSNumber *) seconds)
{
   STKAudioPlayer* player = [self playerForKey:key];
   if (!player) {
      return;
   }

   double newtime = player.progress + [seconds doubleValue];

   if (player.duration < newtime) {
      [player stop];
   }
   else {
      [player seekToTime:newtime];
   }
}

RCT_EXPORT_METHOD(goBackWithKey:(nonnull NSNumber*) key andSeconds:(nonnull NSNumber *) seconds)
{
   STKAudioPlayer* player = [self playerForKey:key];
   if (!player) {
      return;
   }

   double newtime = player.progress - [seconds doubleValue];;

   if (player < 0) {
      [player seekToTime:0.0];
   }
   else {
      [player seekToTime:newtime];
   }
}
RCT_EXPORT_METHOD(setPanWithKey:(nonnull NSNumber*)key andPan: (nonnull NSNumber*) pan)
{
   STKAudioPlayer* player = [self playerForKey:key];
   if (player) {
      [player setPan: [pan intValue] ];
   }

}

RCT_EXPORT_METHOD(setVolumeWithKey:(nonnull NSNumber*)key andVolume: (nonnull NSNumber*) volume)
{
   STKAudioPlayer* player = [self playerForKey:key];
   if (player) {

      [player setVolume: [volume floatValue] ];
   }
}

RCT_EXPORT_METHOD(pauseWithKey:(nonnull NSNumber*)key)
{
   STKAudioPlayer* player = [self playerForKey:key];
   if (player) {
      [player pause];
   }
}
RCT_EXPORT_METHOD(resumeWithKey:(nonnull NSNumber*)key)
{
   STKAudioPlayer* player = [self playerForKey:key];
   if (player) {
      [player resume];
   }

}
RCT_EXPORT_METHOD(getVolumeWithKey:(nonnull NSNumber*)key andCallback: (RCTResponseSenderBlock) callback)
{
   STKAudioPlayer* player = [self playerForKey:key];
   if (player) {
      NSNumber *volume = [NSNumber numberWithFloat:player.volume];
      callback(@[[NSNull null], @{ @"volume": volume}]);
   }

}
RCT_EXPORT_METHOD(getPanWithKey:(nonnull NSNumber*)key andCallback: (RCTResponseSenderBlock) callback)
{
   STKAudioPlayer* player = [self playerForKey:key];
   if (player) {
      NSNumber *pan = [NSNumber numberWithInt:player.pan];
      callback(@[[NSNull null], @{ @"pan": pan}]);
   }

}
RCT_EXPORT_METHOD(stopWithKey:(nonnull NSNumber*)key)
{
   STKAudioPlayer* player = [self playerForKey:key];
   if (player) {
      [player stop];
   }

}
RCT_EXPORT_METHOD(destroyWithKey:(nonnull NSNumber*)key)
{
   STKAudioPlayer* player = [self playerForKey:key];
   if (player) {
      [player stop];
      [[self callbackPool] removeObjectForKey:player];

   }
   [self deactivate];

}
RCT_EXPORT_METHOD(getStatusWithKey:(nonnull NSNumber*)key andCallback: (RCTResponseSenderBlock) callback)
{
   STKAudioPlayer* player = [self playerForKey:key];
   NSString *status = @"STOPPED";
   NSNumber *duration = [NSNumber numberWithFloat:player.duration];
   NSNumber *progress = [NSNumber numberWithFloat:player.progress];

   if (!player) {
      status = @"ERROR";
   }
   else if ([player state] == STKAudioPlayerStatePlaying) {
      status = @"PLAYING";
   }
   else if ([player state] == STKAudioPlayerStatePaused) {
      status = @"PAUSED";
   }
   else if ([player state] == STKAudioPlayerStateBuffering) {
      status = @"BUFFERING";
   }

   callback(@[[NSNull null], @{@"status": status, @"progress": progress, @"duration": duration}]);
}

#pragma mark - StreamingKit Audio Player


- (void)audioPlayer:(STKAudioPlayer *)player didStartPlayingQueueItemId:(NSObject *)queueItemId
{
   NSLog(@"AudioPlayer is playing");
}

- (void)audioPlayer:(STKAudioPlayer *)player didFinishPlayingQueueItemId:(NSObject *)queueItemId withReason:(STKAudioPlayerStopReason)stopReason andProgress:(double)progress andDuration:(double)duration
{
   NSLog(@"AudioPlayer has stopped - is end of track? reason :%ld  is EOF : %d",(long) stopReason, stopReason == STKAudioPlayerStopReasonEof);

   [self.bridge.eventDispatcher sendDeviceEventWithName:@"AudioPlaybackStopEvent"
                                                   body:@{@"progress":[NSNumber numberWithFloat:player.progress],
                                                          @"duration":[NSNumber numberWithFloat:player.duration],
                                                          @"reason" :[NSNumber numberWithLong:stopReason] ,
                                                          @"playerId" : [self keyForPlayer:player]}];
}

- (void)audioPlayer:(STKAudioPlayer *)player didFinishBufferingSourceWithQueueItemId:(NSObject *)queueItemId
{
   NSLog(@"AudioPlayer finished buffering");

}

- (void)audioPlayer:(STKAudioPlayer *)player unexpectedError:(STKAudioPlayerErrorCode)errorCode {
   NSLog(@"AudioPlayer unexpected Error with code %d", errorCode);
}

- (void)audioPlayer:(STKAudioPlayer *)audioPlayer didReadStreamMetadata:(NSDictionary *)dictionary {
   NSLog(@"AudioPlayer SONG NAME  %@", dictionary[@"StreamTitle"]);

   self.currentSong = dictionary[@"StreamTitle"];
   [self.bridge.eventDispatcher sendDeviceEventWithName:@"AudioBridgeEvent" body:@{
                                                                                   @"status": @"METADATA_UPDATED",
                                                                                   @"key": @"StreamTitle",
                                                                                   @"value": dictionary[@"StreamTitle"]
                                                                                   }];
}

- (void)audioPlayer:(STKAudioPlayer *)player stateChanged:(STKAudioPlayerState)state previousState:(STKAudioPlayerState)previousState
{
   NSLog(@"stateChanged for player %@",[self keyForPlayer:player]);
   NSNumber *duration = [NSNumber numberWithFloat:player.duration];
   NSNumber *progress = [NSNumber numberWithFloat:player.progress];
   NSString *prevState = @"";
   switch (previousState){
      case STKAudioPlayerStatePlaying :
         prevState = @"PLAYING";
         break;
      case STKAudioPlayerStatePaused :
         prevState = @"PAUSED";
         break;
      case STKAudioPlayerStateStopped :
         prevState = @"STOPPED";
         break;
      case STKAudioPlayerStateBuffering:
         prevState = @"BUFFERING";
         break;
      case STKAudioPlayerStateError :
         prevState = @"ERROR";
         break;
   }
   switch (state) {
      case STKAudioPlayerStatePlaying:
         [self.bridge.eventDispatcher sendDeviceEventWithName:@"AudioBridgeEvent"
                                                         body:@{@"status": @"PLAYING",@"prevStatus":prevState, @"progress": progress, @"duration": duration , @"playerId" : [self keyForPlayer:player]}];
         break;

      case STKAudioPlayerStatePaused:
         [self.bridge.eventDispatcher sendDeviceEventWithName:@"AudioBridgeEvent"
                                                         body:@{@"status": @"PAUSED",@"prevStatus":prevState, @"progress": progress, @"duration": duration , @"playerId" : [self keyForPlayer:player]}];
         break;

      case STKAudioPlayerStateStopped:
         [self.bridge.eventDispatcher sendDeviceEventWithName:@"AudioBridgeEvent"
                                                         body:@{@"status": @"STOPPED", @"prevStatus":prevState,@"progress": progress, @"duration": duration, @"playerId" : [self keyForPlayer:player]}];
         break;

      case STKAudioPlayerStateBuffering:
         [self.bridge.eventDispatcher sendDeviceEventWithName:@"AudioBridgeEvent"
                                                         body:@{@"status": @"BUFFERING",@"prevStatus":prevState, @"playerId" : [self keyForPlayer:player]}];
         break;

      case STKAudioPlayerStateError:
         [self.bridge.eventDispatcher sendDeviceEventWithName:@"AudioBridgeEvent"
                                                         body:@{@"status": @"ERROR",@"prevStatus":prevState, @"playerId" : [self keyForPlayer:player]}];
         break;

      default:
         break;
   }
}


#pragma mark - Audio Session

- (void)activate
{
   NSError *categoryError = nil;

   [[AVAudioSession sharedInstance] setActive:YES error:&categoryError];
   [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&categoryError];

   if (categoryError) {
      NSLog(@"Error setting category! %@", [categoryError description]);
   }
}

- (void)deactivate
{
   NSError *categoryError = nil;

   [[AVAudioSession sharedInstance] setActive:NO error:&categoryError];

   if (categoryError) {
      NSLog(@"Error setting category! %@", [categoryError description]);
   }
}

- (void)setSharedAudioSessionCategory
{
   NSError *categoryError = nil;
   self.isPlayingWithOthers = [[AVAudioSession sharedInstance] isOtherAudioPlaying];

   [[AVAudioSession sharedInstance] setActive:NO error:&categoryError];
   //[[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient error:&categoryError];
   [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&categoryError];

   if (categoryError) {
      NSLog(@"Error setting category! %@", [categoryError description]);
   }
}

- (void)registerAudioInterruptionNotifications
{
   // Register for audio interrupt notifications
   [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(onAudioInterruption:)
                                                name:AVAudioSessionInterruptionNotification
                                              object:nil];
   // Register for route change notifications
   [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(onRouteChangeInterruption:)
                                                name:AVAudioSessionRouteChangeNotification
                                              object:nil];
}

- (void)unregisterAudioInterruptionNotifications
{
   [[NSNotificationCenter defaultCenter] removeObserver:self
                                                   name:AVAudioSessionRouteChangeNotification
                                                 object:nil];
   [[NSNotificationCenter defaultCenter] removeObserver:self
                                                   name:AVAudioSessionInterruptionNotification
                                                 object:nil];
}

- (void)onAudioInterruption:(NSNotification *)notification
{
   // Get the user info dictionary
   NSDictionary *interruptionDict = notification.userInfo;

   // Get the AVAudioSessionInterruptionTypeKey enum from the dictionary
   NSInteger interuptionType = [[interruptionDict valueForKey:AVAudioSessionInterruptionTypeKey] integerValue];

   // Decide what to do based on interruption type
   switch (interuptionType)
   {
      case AVAudioSessionInterruptionTypeBegan:
         NSLog(@"Audio Session Interruption case started.");
         [self.bridge.eventDispatcher sendDeviceEventWithName:@"AudioSessionInterruptionEvent"
                                                         body:@{@"reason": @"AVAudioSessionInterruptionTypeBegan",
                                                                @"interruptionType":[NSNumber numberWithLong:interuptionType]}];
         break;

      case AVAudioSessionInterruptionTypeEnded:
         NSLog(@"Audio Session Interruption case ended.");
         self.isPlayingWithOthers = [[AVAudioSession sharedInstance] isOtherAudioPlaying];
         [self.bridge.eventDispatcher sendDeviceEventWithName:@"AudioSessionInterruptionEvent"
                                                         body:@{@"reason": @"AVAudioSessionInterruptionTypeEnded",
                                                                @"isPlayingWithOthers":[NSNumber numberWithBool: self.isPlayingWithOthers],
                                                                @"interruptionType":[NSNumber numberWithLong:interuptionType]}];

         break;

      default:
         [self.bridge.eventDispatcher sendDeviceEventWithName:@"AudioSessionInterruptionEvent"
                                                         body:@{@"reason": @"default",
                                                                @"interruptionType":[NSNumber numberWithLong:interuptionType]}];
         NSLog(@"Audio Session Interruption Notification case default.");
         break;
   }
}

- (void)onRouteChangeInterruption:(NSNotification *)notification
{

   NSDictionary *interruptionDict = notification.userInfo;
   NSInteger routeChangeReason = [[interruptionDict valueForKey:AVAudioSessionRouteChangeReasonKey] integerValue];


   switch (routeChangeReason)
   {
      case AVAudioSessionRouteChangeReasonUnknown:
         NSLog(@"routeChangeReason : AVAudioSessionRouteChangeReasonUnknown");
         [self.bridge.eventDispatcher sendDeviceEventWithName:@"AudioRouteInterruptionEvent"
                                                         body:@{@"reason": @"AVAudioSessionRouteChangeReasonUnknown",
                                                                @"interruptionType":[NSNumber numberWithLong:routeChangeReason]}];
         break;

      case AVAudioSessionRouteChangeReasonNewDeviceAvailable:
         // A user action (such as plugging in a headset) has made a preferred audio route available.
         NSLog(@"routeChangeReason : AVAudioSessionRouteChangeReasonNewDeviceAvailable");
         [self.bridge.eventDispatcher sendDeviceEventWithName:@"AudioRouteInterruptionEvent"
                                                         body:@{@"reason": @"AVAudioSessionRouteChangeReasonNewDeviceAvailable",
                                                                @"interruptionType":[NSNumber numberWithLong:routeChangeReason]}];
         break;

      case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
         // The previous audio output path is no longer available.
         NSLog(@"routeChangeReason : AVAudioSessionRouteChangeReasonOldDeviceUnavailable");
         [self.bridge.eventDispatcher sendDeviceEventWithName:@"AudioRouteInterruptionEvent"
                                                         body:@{@"reason": @"AVAudioSessionRouteChangeReasonOldDeviceUnavailable",
                                                                @"interruptionType":[NSNumber numberWithLong:routeChangeReason]}];
         break;

      case AVAudioSessionRouteChangeReasonCategoryChange:
         // The category of the session object changed. Also used when the session is first activated.
         NSLog(@"routeChangeReason : AVAudioSessionRouteChangeReasonCategoryChange"); //AVAudioSessionRouteChangeReasonCategoryChange
         [self.bridge.eventDispatcher sendDeviceEventWithName:@"AudioRouteInterruptionEvent"
                                                         body:@{@"reason": @"AVAudioSessionRouteChangeReasonCategoryChange",
                                                                @"interruptionType":[NSNumber numberWithLong:routeChangeReason]}];
         break;

      case AVAudioSessionRouteChangeReasonOverride:
         // The output route was overridden by the app.
         NSLog(@"routeChangeReason : AVAudioSessionRouteChangeReasonOverride");
         [self.bridge.eventDispatcher sendDeviceEventWithName:@"AudioRouteInterruptionEvent"
                                                         body:@{@"reason": @"AVAudioSessionRouteChangeReasonOverride",
                                                                @"interruptionType":[NSNumber numberWithLong:routeChangeReason]}];
         break;

      case AVAudioSessionRouteChangeReasonWakeFromSleep:
         // The route changed when the device woke up from sleep.
         NSLog(@"routeChangeReason : AVAudioSessionRouteChangeReasonWakeFromSleep");
         [self.bridge.eventDispatcher sendDeviceEventWithName:@"AudioRouteInterruptionEvent"
                                                         body:@{@"reason": @"AVAudioSessionRouteChangeReasonWakeFromSleep",
                                                                @"interruptionType":[NSNumber numberWithLong:routeChangeReason]}];

         break;

      case AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory:
         // The route changed because no suitable route is now available for the specified category.
         NSLog(@"routeChangeReason : AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory");
         [self.bridge.eventDispatcher sendDeviceEventWithName:@"AudioRouteInterruptionEvent"
                                                         body:@{@"reason": @"AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory",
                                                                @"interruptionType":[NSNumber numberWithLong:routeChangeReason]}];

         break;
   }
}

#pragma mark - Remote Control Events

- (void)registerRemoteControlEvents
{
    NSLog(@"registerRemoteControlEvents");
   MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
   [commandCenter.playCommand addTarget:self action:@selector(didReceivePlayCommand:)];
   [commandCenter.pauseCommand addTarget:self action:@selector(didReceivePauseCommand:)];
   [commandCenter.nextTrackCommand addTarget:self action:@selector(didReceiveNextTrackCommand:)];
   [commandCenter.previousTrackCommand addTarget:self action:@selector(didReceivePrevTrackCommand:)];
   [commandCenter.togglePlayPauseCommand addTarget:self action:@selector(didReceiveTogglePlayPauseCommand:)];
   commandCenter.playCommand.enabled = YES;
   commandCenter.pauseCommand.enabled = YES;
   commandCenter.stopCommand.enabled = NO;
   commandCenter.nextTrackCommand.enabled = YES;
   commandCenter.previousTrackCommand.enabled = YES;
}

- (MPRemoteCommandHandlerStatus)didReceivePlayCommand:(MPRemoteCommand *)event
{
   NSLog(@"didReceivePlayCommand");
   [self.bridge.eventDispatcher sendDeviceEventWithName:@"RemoteControlEvents" body:@{@"type": @"playCommand"}];
   return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)didReceivePauseCommand:(MPRemoteCommand *)event
{
   NSLog(@"didReceivePauseCommand");
   [self.bridge.eventDispatcher sendDeviceEventWithName:@"RemoteControlEvents" body:@{@"type": @"pauseCommand"}];
   return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)didReceiveTogglePlayPauseCommand:(MPRemoteCommand *)event
{
   NSLog(@"didReceiveTogglePlayPauseCommand");
   [self.bridge.eventDispatcher sendDeviceEventWithName:@"RemoteControlEvents" body:@{@"type": @"togglePlayPauseCommand"}];
   return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)didReceiveNextTrackCommand:(MPRemoteCommand *)event
{
   NSLog(@"didReceiveNextTrackCommand");
   [self.bridge.eventDispatcher sendDeviceEventWithName:@"RemoteControlEvents" body:@{@"type": @"nextTrackCommand"}];
   return MPRemoteCommandHandlerStatusSuccess;
}
- (MPRemoteCommandHandlerStatus)didReceivePrevTrackCommand:(MPRemoteCommand *)event
{
   NSLog(@"didReceivePrevTrackCommand");
   [self.bridge.eventDispatcher sendDeviceEventWithName:@"RemoteControlEvents" body:@{@"type": @"prevTrackCommand"}];
   return MPRemoteCommandHandlerStatusSuccess;
}
- (void)unregisterRemoteControlEvents
{
   MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
   [commandCenter.playCommand removeTarget:self];
   [commandCenter.pauseCommand removeTarget:self];
}

RCT_EXPORT_METHOD(setNowPlayingInfo:(NSString *) info andIcon: (NSString *)iconName)
{

   NSString* appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"];
  //IconHighRes
   
   NSDictionary *infoPlist = [[NSBundle mainBundle] infoDictionary];
   NSString *icon = [[infoPlist valueForKeyPath:@"CFBundleIcons.CFBundlePrimaryIcon.CFBundleIconFiles"] lastObject];
  
   MPMediaItemArtwork *artwork = [[MPMediaItemArtwork alloc] initWithImage:[UIImage imageNamed:iconName ? iconName : icon]];
   NSDictionary *nowPlayingInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                   info, MPMediaItemPropertyAlbumTitle,
                                   artwork, MPMediaItemPropertyArtwork,
                                   @"", MPMediaItemPropertyAlbumArtist,
                                   appName ? appName : @"", MPMediaItemPropertyTitle,
                                   [NSNumber numberWithFloat: 1.0f ], MPNowPlayingInfoPropertyPlaybackRate, nil];

   [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = nowPlayingInfo;
}

@end
