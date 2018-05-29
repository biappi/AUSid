//
//  InstrumentRenderer.h
//  AUSid
//
//  Created by Antonio Malara on 14/01/2018.
//

#ifndef InstrumentRenderer_h
#define InstrumentRenderer_h

#import <vector>
#import "EventRenderer.h"
#import "sid.h"

uint8_t frequenciesLow[] = {
    0x17, 0x27, 0x39, 0x4b, 0x5f, 0x74, 0x8a, 0xa1, 0xba, 0xd4, 0xf0, 0x0e,
    0x2d, 0x4e, 0x71, 0x96, 0xbe, 0xe8, 0x14, 0x43, 0x74, 0xa9, 0xe1, 0x1c,
    0x5a, 0x9c, 0xe2, 0x2d, 0x7c, 0xcf, 0x28, 0x85, 0xe8, 0x52, 0xc1, 0x37,
    0xb4, 0x39, 0xc5, 0x5a, 0xf7, 0x9e, 0x4f, 0x0a, 0xd1, 0xa3, 0x82, 0x6e,
    0x68, 0x71, 0x8a, 0xb3, 0xee, 0x3c, 0x9e, 0x15, 0xa2, 0x46, 0x04, 0xdc,
    0xd0, 0xe2, 0x14, 0x67, 0xdd, 0x79, 0x3c, 0x29, 0x44, 0x8d, 0x08, 0xb8,
    0xa1, 0xc5, 0x28, 0xcd, 0xba, 0xf1, 0x78, 0x53, 0x87, 0x1a, 0x10, 0x71,
    0x42, 0x89, 0x4f, 0x9b, 0x74, 0xe2, 0xf0, 0xa6, 0x0e, 0x33, 0x20, 0xff,
};

uint8_t frequenciesHigh[] = {
    0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x02,
    0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x03, 0x03, 0x03, 0x03, 0x03, 0x04,
    0x04, 0x04, 0x04, 0x05, 0x05, 0x05, 0x06, 0x06, 0x06, 0x07, 0x07, 0x08,
    0x08, 0x09, 0x09, 0x0a, 0x0a, 0x0b, 0x0c, 0x0d, 0x0d, 0x0e, 0x0f, 0x10,
    0x11, 0x12, 0x13, 0x14, 0x15, 0x17, 0x18, 0x1a, 0x1b, 0x1d, 0x1f, 0x20,
    0x22, 0x24, 0x27, 0x29, 0x2b, 0x2e, 0x31, 0x34, 0x37, 0x3a, 0x3e, 0x41,
    0x45, 0x49, 0x4e, 0x52, 0x57, 0x5c, 0x62, 0x68, 0x6e, 0x75, 0x7c, 0x83,
    0x8b, 0x93, 0x9c, 0xa5, 0xaf, 0xb9, 0xc4, 0xd0, 0xdd, 0xea, 0xf8, 0xff,
};


class InstrumentRenderer : public EventRenderer {

private:
	bool noise         = false;
	bool pulse         = false;
	bool saw           = true;
	bool tri           = false;
	
	uint8_t attack     = 0x0;
	uint8_t decay      = 0x0;
	uint8_t sustain    = 0xf;
	uint8_t release    = 0x0;
	
	float   pulseWidth = (float(2048) / float(0x0fff));
	
	float   cutoff     = (float(2048) / float(0x0fff));
	uint8_t resonance  = 0;
	uint8_t filterMode = 0;

public:
	
    uint8_t waveform() {
        return
            (noise ? 0b10000000 : 0) |
            (pulse ? 0b01000000 : 0) |
            (saw   ? 0b00100000 : 0) |
            (tri   ? 0b00010000 : 0);
    }
    
    uint8_t ad() { return (attack  & 0xf) << 4 | (decay   & 0xf); }
    uint8_t sr() { return (sustain & 0xf) << 4 | (release & 0xf); }
    
    uint8_t pulseWidthLow()  { return  uint16_t(pulseWidth * 0x0fff)       & 0xff; }
    uint8_t pulseWidthHigh() { return (uint16_t(pulseWidth * 0x0fff) >> 8) & 0xff; }
    
    uint8_t filterReg() {
        if (filterMode == 0) return 0;
        return 1 << ((filterMode - 1) + 4);
    }
	
	void setNoise      (bool    newValue) { noise      = newValue; };
	void setPulse      (bool    newValue) { pulse      = newValue; };
	void setSaw        (bool    newValue) { saw        = newValue; };
	void setTri        (bool    newValue) { tri        = newValue; };

	void setAttack     (uint8_t newValue) { attack     = newValue; };
	void setDecay      (uint8_t newValue) { decay      = newValue; };
	void setSustain    (uint8_t newValue) { sustain    = newValue; };
	void setRelease    (uint8_t newValue) { release    = newValue; };
	
	void setPulseWidth (float   newValue) { pulseWidth = newValue; };
	
	void setFilterMode (uint8_t newValue) { filterMode = newValue; };

public:
	
	bool    getNoise      () { return noise;      };
	bool    getPulse      () { return pulse;      };
	bool    getSaw        () { return saw;        };
	bool    getTri        () { return tri;        };
	
	uint8_t getAttack     () { return attack;     };
	uint8_t getDecay      () { return decay;      };
	uint8_t getSustain    () { return sustain;    };
	uint8_t getRelease    () { return release;    };
	
	float   getPulseWidth () { return pulseWidth; };
	
	uint8_t getFilterMode () { return filterMode; };

public:
	
    void init(int channelCount, double inSampleRate) {
        sampleRate = float(inSampleRate);
        
        sid.set_sampling_parameters(985248, SAMPLE_FAST, inSampleRate);
        sid.reset();
		
        sid.write(24, 0x0f); // volume
    }
    
    virtual void handleEvent(AUParameterEvent const& event) override {
//        setParameter(event.parameterAddress, event.value);
    }
    
    virtual void handleEvent(AUMIDIEvent const& midiEvent) override {
        if (midiEvent.length != 3)
            return;
        
        uint8_t status  = midiEvent.data[0] & 0xF0;
        
        switch (status) {
                
            case 0x80 : { // note off
                uint8_t note = midiEvent.data[1];
                if (note > 127) break;

                sid.write( 4, waveform() & ~1); // * DING *
                
                break;
            }
                
            case 0x90 : { // note on
                uint8_t note  = midiEvent.data[1];
                uint8_t veloc = midiEvent.data[2];
				
                if (note > 127 || veloc > 127) break;
                
                sid.write( 0, frequenciesLow  [note - 24]);
                sid.write( 1, frequenciesHigh [note - 24]);
                sid.write( 2, pulseWidthLow  ());
                sid.write( 3, pulseWidthHigh ());
                sid.write( 5, ad());
                sid.write( 6, sr());

//                sid.write( 4, 0b00100000); // * DING *
                sid.write( 4, waveform() | 1); // * DING *
                
                break;
            }
        }
    }
    
    void processAudio(AUAudioFrameCount   frameCount,
                      AUAudioFrameCount   bufferOffset,
                      AudioBufferList   * outBufferListPtr) override
    {
        float* outL = (float*)outBufferListPtr->mBuffers[0].mData + bufferOffset;
        float* outR = (float*)outBufferListPtr->mBuffers[1].mData + bufferOffset;
        
        cycle_count delta_t = (int)roundf(985248.0f / sampleRate * frameCount);
        sid.clock(delta_t, sidbuffer, sizeof(sidbuffer), 1);
        
        for (AUAudioFrameCount i = 0; i < frameCount; i++) {
            float s = sidbuffer[i] / (float)0xffff;
            
            *outL++ = s;
            *outR++ = s;
        }
    }
    
private:
    
    float sampleRate = 44100.0;
    
    SID sid;
    short sidbuffer[1024*1024];
};

#endif /* InstrumentRenderer_h */
