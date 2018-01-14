//
//  EventRenderer.h
//  AUSid
//
//  Created by Antonio Malara on 14/01/2018.
//

#ifndef EventRenderer_h
#define EventRenderer_h

#import <AudioToolbox/AudioToolbox.h>

class EventRenderer {
public:
    virtual void processAudio(AUAudioFrameCount   frameCount,
                              AUAudioFrameCount   bufferOffset,
                              AudioBufferList   * outBufferListPtr) = 0;
    
    virtual void handleEvent(AUParameterEvent const& event) {}
    virtual void handleEvent(AUMIDIEvent      const& event) {}
    
    void renderWithEvents(AudioTimeStamp    const * timestamp,
                          AUAudioFrameCount         frameCount,
                          AURenderEvent     const * events,
                          AudioBufferList         * outputData)
    {
        AUEventSampleTime now = AUEventSampleTime(timestamp->mSampleTime);
        AUAudioFrameCount framesRemaining = frameCount;
        AURenderEvent const *event = events;
        
        while (framesRemaining > 0) {
            if (event) {
                // **** start late events late.
                auto timeZero      = AUEventSampleTime(0);
                auto headEventTime = event->head.eventSampleTime;
                
                AUAudioFrameCount const framesThisSegment = AUAudioFrameCount(std::max(timeZero, headEventTime - now));
                
                if (framesThisSegment > 0) {
                    AUAudioFrameCount const bufferOffset = frameCount - framesRemaining;
                    processAudio(framesThisSegment, bufferOffset, outputData);
                    
                    framesRemaining -= framesThisSegment;
                    now += AUEventSampleTime(framesThisSegment);
                }
                
                do {
                    handleEvent(*event);
                    event = event->head.next;
                } while (event && event->head.eventSampleTime <= now);
                // While event is not null and is simultaneous (or late).
            }
            else {
                AUAudioFrameCount const bufferOffset = frameCount - framesRemaining;
                processAudio(framesRemaining, bufferOffset, outputData);
                return;
            }
        }
    }
    
private:
    void handleEvent(AURenderEvent const& event) {
        switch (event.head.eventType) {
            case AURenderEventParameter:
            case AURenderEventParameterRamp:
                handleEvent(event.parameter);
                break;
                
            case AURenderEventMIDI:
                handleEvent(event.MIDI);
                break;
                
            case AURenderEventMIDISysEx:
                break;
        }
    }
};

#endif /* EventRenderer_h */
