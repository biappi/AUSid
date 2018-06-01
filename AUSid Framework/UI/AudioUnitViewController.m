//
//  AudioUnitViewController.m
//  AUSid Framework
//
//  Created by Antonio Malara on 30/05/2018.
//

#import "AudioUnitViewController.h"
#import "InstrumentAudioUnit.h"

@interface AudioUnitViewController ()
@property(nonatomic, strong) InstrumentAudioUnit * audioUnit;
@end

@implementation AudioUnitViewController

- (nullable AUAudioUnit *)createAudioUnitWithComponentDescription:(AudioComponentDescription)desc
                                                            error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    return self.audioUnit = [[InstrumentAudioUnit alloc] initWithComponentDescription:desc error:error];
}

- (NSBundle *)nibBundle {
    return [NSBundle bundleForClass:[AudioUnitViewController class]];
}

@end
