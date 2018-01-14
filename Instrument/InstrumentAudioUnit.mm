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

@implementation InstrumentAudioUnit
{
    AUParameterTree      * parameterTree;
    
    AUAudioUnitBusArray  * outputBusArray;
    AUAudioUnitBus       * outputBus;
    AVAudioPCMBuffer     * pcmBuffer;
    
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
    
    AudioUnitParameterOptions flags = kAudioUnitParameterFlag_IsWritable |
    kAudioUnitParameterFlag_IsReadable |
    kAudioUnitParameterFlag_DisplayLogarithmic;
    
    AUParameter *
    attackParam = [AUParameterTree createParameterWithIdentifier:@"attack"
                                                            name:@"Attack"
                                                         address:InstrumentParamAttack
                                                             min:0.001
                                                             max:10.0
                                                            unit:kAudioUnitParameterUnit_Seconds
                                                        unitName:nil
                                                           flags:flags
                                                    valueStrings:nil
                                             dependentParameters:nil];
    
    AUParameter *
    releaseParam = [AUParameterTree createParameterWithIdentifier:@"release"
                                                             name:@"Release"
                                                          address:InstrumentParamRelease
                                                              min:0.001
                                                              max:10.0
                                                             unit:kAudioUnitParameterUnit_Seconds
                                                         unitName:nil
                                                            flags:flags
                                                     valueStrings:nil
                                              dependentParameters:nil];
    
    // Initialize the parameter values.
    attackParam.value = 0.01;
    releaseParam.value = 0.1;
    
    renderer.setParameter(InstrumentParamAttack, attackParam.value);
    renderer.setParameter(InstrumentParamRelease, releaseParam.value);
    
    // Create the parameter tree.
    parameterTree = [AUParameterTree createTreeWithChildren:@[attackParam, releaseParam]];
    
    // Create the output bus.
    outputBus = [[AUAudioUnitBus alloc] initWithFormat:defaultFormat error:nil];
    outputBus.maximumChannelCount = 2;
    
    // Create the input and output bus arrays.
    outputBusArray = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self
                                                            busType:AUAudioUnitBusTypeOutput
                                                             busses:@[outputBus]];
    
    // Make a local pointer to the kernel to avoid capturing self.
    __block auto *instrumentRendrer = &renderer;
    
    // implementorValueObserver is called when a parameter changes value.
    parameterTree.implementorValueObserver = ^(AUParameter *param, AUValue value) {
        instrumentRendrer->setParameter(param.address, value);
    };
    
    // implementorValueProvider is called when the value needs to be refreshed.
    parameterTree.implementorValueProvider = ^(AUParameter *param) {
        return instrumentRendrer->getParameter(param.address);
    };
    
    // A function to provide string representations of parameter values.
    parameterTree.implementorStringFromValueCallback = ^(AUParameter *param,
                                                         const AUValue *__nullable valuePtr)
    {
        AUValue value = valuePtr == nil ? param.value : *valuePtr;
        
        switch (param.address) {
            case InstrumentParamAttack:
            case InstrumentParamRelease:
                return [NSString stringWithFormat:@"%.3f", value];
                
            default:
                return @"?";
        }
    };
    
    self.maximumFramesToRender = 512;
    
    return self;
}

- (void)dealloc {
    free(outputBufferList);
}

#pragma mark - AUAudioUnit (Overrides)

- (AUAudioUnitBusArray *)outputBusses {
    return outputBusArray;
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

