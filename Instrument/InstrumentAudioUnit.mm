//
//  InstrumentAudioUnit.m
//  Instrument macOS
//
//  Created by Antonio Malara on 14/01/2018.
//

#import <AVFoundation/AVFoundation.h>

#import "InstrumentAudioUnit.h"
#import "InstrumentRenderer.h"

static void PrepareOutputBuffers(AVAudioFrameCount frameCount,
                                 const AudioBufferList *originalAudioBufferList,
                                 AudioBufferList *outputData);

static AUParameter * BoolParam(NSString                   * identifier,
                               NSString                   * name,
                               AUParameterAddress         * address,
                               AUImplementorValueObserver   observer,
                               AUImplementorValueProvider   provider)
{
    AUParameter *
    param = [AUParameterTree createParameterWithIdentifier:identifier
                                                      name:name
                                                   address:*address
                                                       min:0
                                                       max:1
                                                      unit:kAudioUnitParameterUnit_Boolean
                                                  unitName:nil
                                                     flags:kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
                                              valueStrings:nil
                                       dependentParameters:nil];
    
    param.implementorValueObserver = observer;
    param.implementorValueProvider = provider;

    *address = *address + 1;
    
    return param;
}

@implementation InstrumentAudioUnit
{
    AUParameterTree      * parameterTree;
    
    AUAudioUnitBusArray  * outputBusArray;
    AUAudioUnitBus       * outputBus;
    AVAudioPCMBuffer     * pcmBuffer;
    NSArray<NSNumber *>  * channelCapabilities;
    
    AudioBufferList     ** outputBufferList; // Hack for iOS
    
    InstrumentRenderer     renderer;
}

- (instancetype)initWithComponentDescription:(AudioComponentDescription)componentDescription
                                     options:(AudioComponentInstantiationOptions)options
                                       error:(NSError **)outError
{
    if ((self = [super initWithComponentDescription:componentDescription
                                            options:options
                                              error:outError]) == nil)
    {
        return nil;
    }
    
    outputBufferList = (AudioBufferList **)malloc(sizeof(AudioBufferList *));
    *outputBufferList = NULL;
    
    // Initialize a default format for the busses.
    AVAudioFormat *defaultFormat = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100. channels:2];
    
    // Create a DSP kernel to handle the signal processing.
    renderer.init(defaultFormat.channelCount, defaultFormat.sampleRate);
    
    __block auto *instrumentRenderer = &renderer;

    AUParameterAddress address = 0;

    auto attackTimes       = @[ @"2 ms",   @"8 ms",   @"16 ms",  @"24 ms",
                                @"38 ms",  @"56 ms",  @"68 ms",  @"80 ms",
                                @"100 ms", @"250 ms", @"500 ms", @"800 ms",
                                @"1 s",    @"3 s",    @"5 s",    @"8 s"  ];
    
    auto decayReleaseTimes = @[ @"6 ms",   @"24 ms",  @"48 ms",  @"72 ms",
                                @"114 ms", @"168 ms", @"204 ms", @"240 ms",
                                @"300 ms", @"750 ms", @"1.5 s",  @"2.4 s",
                                @"3 s",    @"9 s",    @"15 s",   @"24 s" ];

    auto noiseParam = BoolParam(@"noise",
                                @"Noise",
                                &address,
                                ^(AUParameter * _Nonnull param, AUValue value) {
                                    instrumentRenderer->setNoise(value != 0);
                                },
                                ^AUValue(AUParameter * _Nonnull param) {
                                    return instrumentRenderer->getNoise() ? 1.f : 0.f;
                                });

    auto pulseParam = BoolParam(@"pulse",
                                @"Pulse",
                                &address,
                                ^(AUParameter * _Nonnull param, AUValue value) {
                                    instrumentRenderer->setPulse(value != 0);
                                },
                                ^AUValue(AUParameter * _Nonnull param) {
                                    return instrumentRenderer->getPulse() ? 1.f : 0.f;
                                });

    auto sawParam   = BoolParam(@"saw",
                                @"Saw",
                                &address,
                                ^(AUParameter * _Nonnull param, AUValue value) {
                                    instrumentRenderer->setSaw(value != 0);
                                },
                                ^AUValue(AUParameter * _Nonnull param) {
                                    return instrumentRenderer->getSaw() ? 1.f : 0.f;
                                });

    auto triParam   = BoolParam(@"tri",
                                @"Tri",
                                &address,
                                ^(AUParameter * _Nonnull param, AUValue value) {
                                    instrumentRenderer->setTri(value != 0);
                                },
                                ^AUValue(AUParameter * _Nonnull param) {
                                    return instrumentRenderer->getTri() ? 1.f : 0.f;
                                });

    auto attackParam = [AUParameterTree createParameterWithIdentifier:@"attack"
                                                                 name:@"Attack"
                                                              address:address++
                                                                  min:0x0
                                                                  max:0xf
                                                                 unit:kAudioUnitParameterUnit_Indexed
                                                             unitName:nil
                                                                flags:kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
                                                         valueStrings:attackTimes
                                                  dependentParameters:nil];
    
    attackParam.implementorValueObserver = ^(AUParameter * _Nonnull param, AUValue value) {
        instrumentRenderer->setAttack(roundf(value));
    };
    
    attackParam.implementorValueProvider = ^AUValue(AUParameter * _Nonnull param) {
        return instrumentRenderer->getAttack();
    };

    auto decayParam = [AUParameterTree createParameterWithIdentifier:@"decay"
                                                                name:@"Decay"
                                                             address:address++
                                                                 min:0x0
                                                                 max:0xf
                                                                unit:kAudioUnitParameterUnit_Indexed
                                                            unitName:nil
                                                               flags:kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
                                                        valueStrings:decayReleaseTimes
                                                 dependentParameters:nil];
    
    decayParam.implementorValueObserver = ^(AUParameter * _Nonnull param, AUValue value) {
        instrumentRenderer->setDecay(roundf(value));
    };
    
    decayParam.implementorValueProvider = ^AUValue(AUParameter * _Nonnull param) {
        return instrumentRenderer->getDecay();
    };
    
    auto sustainParam = [AUParameterTree createParameterWithIdentifier:@"sustain"
                                                                  name:@"Sustain"
                                                               address:address++
                                                                   min:0x0
                                                                   max:0xf
                                                                  unit:kAudioUnitParameterUnit_Generic
                                                              unitName:nil
                                                                 flags:kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
                                                          valueStrings:nil
                                                   dependentParameters:nil];
    
    sustainParam.implementorValueObserver = ^(AUParameter * _Nonnull param, AUValue value) {
		instrumentRenderer->setSustain(roundf(value));
    };
    
    sustainParam.implementorValueProvider = ^AUValue(AUParameter * _Nonnull param) {
        return instrumentRenderer->getSustain();
    };
    
    auto releaseParam = [AUParameterTree createParameterWithIdentifier:@"release"
                                                                  name:@"Release"
                                                               address:address++
                                                                   min:0x0
                                                                   max:0xf
                                                                  unit:kAudioUnitParameterUnit_Indexed
                                                              unitName:nil
                                                                 flags:kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
                                                          valueStrings:decayReleaseTimes
                                                   dependentParameters:nil];
    
    releaseParam.implementorValueObserver = ^(AUParameter * _Nonnull param, AUValue value) {
        instrumentRenderer->setRelease(roundf(value));
    };
    
    releaseParam.implementorValueProvider = ^AUValue(AUParameter * _Nonnull param) {
        return instrumentRenderer->getRelease();
    };

    auto pulseWidthParam = [AUParameterTree createParameterWithIdentifier:@"pulseWidth"
                                                                     name:@"Pulse Width"
                                                                  address:address++
                                                                      min:0
                                                                      max:100
                                                                     unit:kAudioUnitParameterUnit_Percent
                                                                 unitName:nil
                                                                    flags:kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
                                                             valueStrings:nil
                                                      dependentParameters:nil];
    
    pulseWidthParam.implementorValueObserver = ^(AUParameter * _Nonnull param, AUValue value) {
        instrumentRenderer->setPulseWidth(value / 100.f);
    };
    
    pulseWidthParam.implementorValueProvider = ^AUValue(AUParameter * _Nonnull param) {
        return instrumentRenderer->getPulseWidth() * 100.f;
    };
    
    auto filterModes = @[ @"Off", @"Low Pass", @"High Pass", @"Band Pass" ];
    
    auto filterModeParam = [AUParameterTree createParameterWithIdentifier:@"filterMode"
                                                                     name:@"Filter Mode"
                                                                  address:address++
                                                                      min:0
                                                                      max:filterModes.count - 1
                                                                     unit:kAudioUnitParameterUnit_Indexed
                                                                 unitName:nil
                                                                    flags:kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
                                                             valueStrings:filterModes
                                                      dependentParameters:nil];
    
    filterModeParam.implementorValueObserver = ^(AUParameter * _Nonnull param, AUValue value) {
        instrumentRenderer->setFilterMode(roundf(value));
    };
    
    filterModeParam.implementorValueProvider = ^AUValue(AUParameter * _Nonnull param) {
        return instrumentRenderer->getFilterMode();
    };
    
    // Create the parameter tree.
    auto params = @[ noiseParam,  pulseParam,   sawParam,   triParam,
                     attackParam, sustainParam, decayParam, releaseParam,
                     pulseWidthParam, filterModeParam ];

    for (AUParameter *  param in params) {
        param.value = param.implementorValueProvider(param);
    }
    
    parameterTree = [AUParameterTree createTreeWithChildren:params];
    
    // Create the output bus.
    outputBus = [[AUAudioUnitBus alloc] initWithFormat:defaultFormat error:nil];
	
    outputBus.maximumChannelCount = 2;
    
    // Create the input and output bus arrays.
    outputBusArray = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self
                                                            busType:AUAudioUnitBusTypeOutput
                                                             busses:@[outputBus]];
	
	channelCapabilities   = @[ @0, @2 ];
	
    self.maximumFramesToRender = 512;
	
    return self;
}

- (void)dealloc {
    free(outputBufferList);
}

#pragma mark - AUAudioUnit (Overrides)

- (AUParameterTree *)parameterTree {
    return parameterTree;
}

- (AUAudioUnitBusArray *)outputBusses {
    return outputBusArray;
}

- (NSArray<NSNumber *> *)channelCapabilities {
	return channelCapabilities;
}

- (BOOL)allocateRenderResourcesAndReturnError:(NSError **)outError {
    if (![super allocateRenderResourcesAndReturnError:outError]) {
        return NO;
    }
    
    pcmBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:outputBus.format
                                              frameCapacity:self.maximumFramesToRender];
    *outputBufferList = (AudioBufferList *)pcmBuffer.audioBufferList;
    
    renderer.init(outputBus.format.channelCount, outputBus.format.sampleRate);
    
    return YES;
}

- (void)deallocateRenderResources {
    pcmBuffer = nil;
    [super deallocateRenderResources];
}

#pragma mark - AUAudioUnit (AUAudioUnitImplementation)

- (AUInternalRenderBlock)internalRenderBlock {
    /*
     Capture in locals to avoid ObjC member lookups. If "self" is captured in
     render, we're doing it wrong.
     */
    
    __block auto instrumentRenderer      = &renderer;
    __block auto originalAudioBufferList = outputBufferList;
    
    return ^AUAudioUnitStatus(AudioUnitRenderActionFlags * actionFlags,
                              const AudioTimeStamp       * timestamp,
                              AVAudioFrameCount            frameCount,
                              NSInteger                    outputBusNumber,
                              AudioBufferList            * outputData,
                              const AURenderEvent        * realtimeEventListHead,
                              AURenderPullInputBlock       pullInputBlock)
    {
        PrepareOutputBuffers(frameCount, *originalAudioBufferList, outputData);
        instrumentRenderer->renderWithEvents(timestamp, frameCount, realtimeEventListHead, outputData);
        
        return noErr;
    };
}

@end

static void PrepareOutputBuffers(AVAudioFrameCount frameCount,
                                 const AudioBufferList *originalAudioBufferList,
                                 AudioBufferList *outputData)
{
    UInt32 byteSize = frameCount * sizeof(float);
    
    for (UInt32 i = 0; i < outputData->mNumberBuffers; ++i) {
        outputData->mBuffers[i].mNumberChannels = originalAudioBufferList->mBuffers[i].mNumberChannels;
        outputData->mBuffers[i].mDataByteSize = byteSize;
        
        if (outputData->mBuffers[i].mData == nullptr) {
            outputData->mBuffers[i].mData = originalAudioBufferList->mBuffers[i].mData;
        }
        
        memset(outputData->mBuffers[i].mData, 0, byteSize);
    }
}

