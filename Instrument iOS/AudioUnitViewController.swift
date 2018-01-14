//
//  AudioUnitViewController.swift
//  Instrument iOS
//
//  Created by Antonio Malara on 14/01/2018.
//

import CoreAudioKit
import AVFoundation

public class AudioUnitViewController: AUViewController, AUAudioUnitFactory {
    var audioUnit: AUAudioUnit?
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        if audioUnit == nil {
            return
        }
        
        // Get the parameter tree and add observers for any parameters that the UI needs to keep in sync with the AudioUnit
    }
    
    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        audioUnit = try InstrumentAudioUnit(componentDescription: componentDescription, options: [])
        
        return audioUnit!
    }
    
}
