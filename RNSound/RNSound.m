#import "RNSound.h"

#if __has_include("RCTUtils.h")
    #import "RCTUtils.h"
#else
    #import <React/RCTUtils.h>
#endif

@implementation RNSound {
  NSMutableDictionary* _playerPool;
  NSMutableArray* _interruptedPlayerPool;
  NSMutableDictionary* _callbackPool;
}

-(NSMutableDictionary*) playerPool {
  if (!_playerPool) {
    _playerPool = [NSMutableDictionary new];
  }
  return _playerPool;
}


-(NSMutableArray*) interruptedPlayerPool {
    if (!_interruptedPlayerPool) {
        _interruptedPlayerPool = [NSMutableArray new];
    }
    return _interruptedPlayerPool;
}

-(NSMutableDictionary*) callbackPool {
  if (!_callbackPool) {
    _callbackPool = [NSMutableDictionary new];
  }
  return _callbackPool;
}

-(AVAudioPlayer*) playerForKey:(nonnull NSNumber*)key {
  return [[self playerPool] objectForKey:key];
}

-(NSNumber*) keyForPlayer:(nonnull AVAudioPlayer*)player {
  return [[[self playerPool] allKeysForObject:player] firstObject];
}

-(RCTResponseSenderBlock) callbackForKey:(nonnull NSNumber*)key {
  return [[self callbackPool] objectForKey:key];
}

-(NSString *) getDirectory:(int)directory {
  return [NSSearchPathForDirectoriesInDomains(directory, NSUserDomainMask, YES) firstObject];
}

-(void) audioPlayerDidFinishPlaying:(AVAudioPlayer*)player
                       successfully:(BOOL)flag {
  NSNumber* key = [self keyForPlayer:player];
  if (key == nil) return;

  @synchronized(key) {
    RCTResponseSenderBlock callback = [self callbackForKey:key];
    if (callback) {
      callback(@[@(flag)]);
      [[self callbackPool] removeObjectForKey:key];
    }
  }
}

- (void) handleInterruption: (NSNotification*)notification {
    NSDictionary *userInfo = notification.userInfo;
    if (!userInfo) return;
    NSNumber *typeValue = [userInfo objectForKey:AVAudioSessionInterruptionTypeKey];
     if (!typeValue) return;
    AVAudioSessionInterruptionType type = [typeValue integerValue];
    if (type == AVAudioSessionInterruptionTypeBegan) {
        // Interruption began, all sounds playing will be added to a list of interrupted sounds
        [[self playerPool] enumerateKeysAndObjectsUsingBlock:^(NSNumber*  _Nonnull key, AVAudioPlayer*  _Nonnull player, BOOL * _Nonnull stop) {
            if (player.isPlaying) {
                [player pause];
                [[self interruptedPlayerPool] addObject:player];
            }
        }];
    } else if (type == AVAudioSessionInterruptionTypeEnded) {
        NSError *error;
        
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setCategory: AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionMixWithOthers  error: nil];
        bool success = [session setActive: YES error: &error];

        NSAssert(success, @"RNSound.handleInterruption failed in AVAudioSessionInterruptionTypeEnded block. This is a bug");
        
        NSNumber *optionsValue = [userInfo objectForKey:AVAudioSessionInterruptionOptionKey];
        if (!optionsValue) return;
        AVAudioSessionInterruptionOptions options = [optionsValue integerValue];
        
        [[self interruptedPlayerPool] enumerateKeysAndObjectsUsingBlock:^(NSNumber*  _Nonnull key, AVAudioPlayer*  _Nonnull player, BOOL * _Nonnull stop) {
            if (options == AVAudioSessionInterruptionOptionShouldResume) {
                // if playback was interrupted, resume playback if resumable
                [player play];
            } else {
                // otherwise, player did not finish playing
                [self audioPlayerDidFinishPlaying:player successfully:false];
            }
        }];
        [[self interruptedPlayerPool] removeAllObjects];
    }
}

RCT_EXPORT_MODULE();

-(NSDictionary *)constantsToExport {
  return @{@"IsAndroid": [NSNumber numberWithBool:NO],
           @"MainBundlePath": [[NSBundle mainBundle] bundlePath],
           @"NSDocumentDirectory": [self getDirectory:NSDocumentDirectory],
           @"NSLibraryDirectory": [self getDirectory:NSLibraryDirectory],
           @"NSCachesDirectory": [self getDirectory:NSCachesDirectory],
           };
}

RCT_EXPORT_METHOD(enable:(BOOL)enabled) {
  AVAudioSession *session = [AVAudioSession sharedInstance];
  [session setCategory: AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionMixWithOthers  error: nil];
  [session setActive: enabled error: nil];
    if (enabled) {
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(handleInterruption:)
                                                     name: AVAudioSessionInterruptionNotification
                                                   object: session];
    } else {
        [[NSNotificationCenter defaultCenter] removeObserver: self
                                                        name: AVAudioSessionInterruptionNotification
                                                      object: session];
    }
}

RCT_EXPORT_METHOD(setCategory:(NSString *)categoryName
    mixWithOthers:(BOOL)mixWithOthers) {
  AVAudioSession *session = [AVAudioSession sharedInstance];
  NSString *category = nil;

  if ([categoryName isEqual: @"Ambient"]) {
    category = AVAudioSessionCategoryAmbient;
  } else if ([categoryName isEqual: @"SoloAmbient"]) {
    category = AVAudioSessionCategorySoloAmbient;
  } else if ([categoryName isEqual: @"Playback"]) {
    category = AVAudioSessionCategoryPlayback;
  } else if ([categoryName isEqual: @"Record"]) {
    category = AVAudioSessionCategoryRecord;
  } else if ([categoryName isEqual: @"PlayAndRecord"]) {
    category = AVAudioSessionCategoryPlayAndRecord;
  } 
  #if TARGET_OS_IOS
  else if ([categoryName isEqual: @"AudioProcessing"]) {
      category = AVAudioSessionCategoryAudioProcessing;
  }
  #endif
    else if ([categoryName isEqual: @"MultiRoute"]) {
    category = AVAudioSessionCategoryMultiRoute;
  }

  if (category) {
    if (mixWithOthers) {
        [session setCategory: category withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionMixWithOthers error: nil];
    } else {
      [session setCategory: category error: nil];
    }
  }
}

RCT_EXPORT_METHOD(enableInSilenceMode:(BOOL)enabled) {
  AVAudioSession *session = [AVAudioSession sharedInstance];
  [session setCategory: AVAudioSessionCategoryPlayback error: nil];
  [session setActive: enabled error: nil];
}

RCT_EXPORT_METHOD(prepare:(NSString*)fileName withKey:(nonnull NSNumber*)key
                  withCallback:(RCTResponseSenderBlock)callback) {
  NSError* error;
  NSURL* fileNameUrl;
  AVAudioPlayer* player;
  
  if ([fileName hasPrefix:@"http"]) {
    fileNameUrl = [NSURL URLWithString:[fileName stringByRemovingPercentEncoding]];
  }
  else {
    fileNameUrl = [NSURL fileURLWithPath:[fileName stringByRemovingPercentEncoding]];
  }
    
  if (fileNameUrl) {
    player = [[AVAudioPlayer alloc]
              initWithData:[[NSData alloc] initWithContentsOfURL:fileNameUrl]
              error:&error];
  }
    
  if (player) {
    player.delegate = self;
    player.enableRate = YES;
    [player prepareToPlay];
    [[self playerPool] setObject:player forKey:key];
    callback(@[[NSNull null], @{@"duration": @(player.duration),
                                @"numberOfChannels": @(player.numberOfChannels)}]);
  } else {
    callback(@[RCTJSErrorFromNSError(error)]);
  }
}

RCT_EXPORT_METHOD(play:(nonnull NSNumber*)key withCallback:(RCTResponseSenderBlock)callback) {
  AVAudioPlayer* player = [self playerForKey:key];
  if (player) {
    [[self callbackPool] setObject:[callback copy] forKey:key];
    [player play];
  } else {
      NSLog(@"[SOUND].play has no AVAudioPlayer");
  }
}

RCT_EXPORT_METHOD(pause:(nonnull NSNumber*)key withCallback:(RCTResponseSenderBlock)callback) {
  AVAudioPlayer* player = [self playerForKey:key];
  if (player) {
    [player pause];
    callback(@[]);
  }
}

RCT_EXPORT_METHOD(stop:(nonnull NSNumber*)key withCallback:(RCTResponseSenderBlock)callback) {
    AVAudioPlayer* player = [self playerForKey:key];
    if (player) {
        [player stop];
        player.currentTime = 0;
        callback(@[]);
        [self audioPlayerDidFinishPlaying:player successfully:false];
    }
}

RCT_EXPORT_METHOD(release:(nonnull NSNumber*)key) {
  AVAudioPlayer* player = [self playerForKey:key];
  if (player) {
    [player stop];
    [[self callbackPool] removeObjectForKey:player];
    [[self playerPool] removeObjectForKey:key];
  }
}

RCT_EXPORT_METHOD(setVolume:(nonnull NSNumber*)key withValue:(nonnull NSNumber*)value) {
  AVAudioPlayer* player = [self playerForKey:key];
  if (player) {
    player.volume = [value floatValue];
  }
}

RCT_EXPORT_METHOD(setPan:(nonnull NSNumber*)key withValue:(nonnull NSNumber*)value) {
  AVAudioPlayer* player = [self playerForKey:key];
  if (player) {
    player.pan = [value floatValue];
  }
}

RCT_EXPORT_METHOD(setNumberOfLoops:(nonnull NSNumber*)key withValue:(nonnull NSNumber*)value) {
  AVAudioPlayer* player = [self playerForKey:key];
  if (player) {
    player.numberOfLoops = [value intValue];
  }
}

RCT_EXPORT_METHOD(setSpeed:(nonnull NSNumber*)key withValue:(nonnull NSNumber*)value) {
  AVAudioPlayer* player = [self playerForKey:key];
  if (player) {
    player.rate = [value floatValue];
  }
}


RCT_EXPORT_METHOD(setCurrentTime:(nonnull NSNumber*)key withValue:(nonnull NSNumber*)value) {
  AVAudioPlayer* player = [self playerForKey:key];
  if (player) {
    player.currentTime = [value doubleValue];
  }
}

RCT_EXPORT_METHOD(getCurrentTime:(nonnull NSNumber*)key
                  withCallback:(RCTResponseSenderBlock)callback) {
  AVAudioPlayer* player = [self playerForKey:key];
  if (player) {
    callback(@[@(player.currentTime), @(player.isPlaying)]);
  } else {
    callback(@[@(-1), @(false)]);
  }
}

@end
