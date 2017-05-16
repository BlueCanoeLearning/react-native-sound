// Type definitions for react-native-sound0.10.1
// Project: https://github.com/zmxv/react-native-sound
// Definitions by: Josh Baxley <https://github.com/joshbax>
// Definitions: https://github.com/DefinitelyTyped/DefinitelyTyped
// TypeScript Version: 2.3.2

declare module "react-native-sound" {
    import React from "react";
    import { ImageURISource } from "react-native";

    export interface SoundProperties {
        duration: number;
        numberOfChannels: number;
    }

    export type onSoundLoad = (error: any, properties?: SoundProperties) => void;
    export type onPlayEnd = (success: boolean) => void;
    export type onGetCurrentTime = (seconds: number, isPlaying: boolean) => void;

    export type SoundCategory = "Ambient" |
                                "SoloAmbient" |
                                "Playback" |
                                "Record" |
                                "PlayAndRecord" |
                                "AudioProcessing" |
                                "MultiRoute";

    export default class Sound {

        public static MAIN_BUNDLE: string;
        public static DOCUMENT: string;
        public static LIBRARY: string;
        public static CACHES: string;

        /**
         * `value` {string} Sets AVAudioSession category, which allows playing sound in background, stop sound playback when phone is locked, etc.
         * Parameter options: "Ambient", "SoloAmbient", "Playback", "Record", "PlayAndRecord", "AudioProcessing", "MultiRoute".
         *
         * More info about each category can be found in https://developer.apple.com/library/ios/documentation/AVFoundation/Reference/AVAudioSession_ClassReference/#//apple_ref/doc/constant_group/Audio_Session_Categories
         *
         * `mixWithOthers` {boolean} can be set to true to force mixing with other audio sessions.
         * To play sound in the background, make sure to add the following to the Info.plist file.
         */
        public static setCategory(category: SoundCategory, mixWithOthers?: boolean): void;

        /**
         * `filename` {string | ImageURISource} Either absolute or relative path to the sound file or opaque value returned from require()
         *
         * `basePath` {?string} Optional base path of the file.
         * Omit this or pass '' if filename is an absolute path.
         * Otherwise, you may use one of the predefined directories: Sound.MAIN_BUNDLE, Sound.DOCUMENT, Sound.LIBRARY, Sound.CACHES.
         *
         * `onLoad` {?function(error, props)} Optional callback function.
         * If the file is successfully loaded, the first parameter error is null, and props contains an object with two properties:
         * duration (in seconds) and numberOfChannels (1 for mono and 2 for stereo sound), both of which can also be accessed from the Sound instance object.
         *
         * If an initialization error is encountered (e.g. file not found), error will be an object containing code, description, and the stack trace.
         */
        constructor(fileName: (string | ImageURISource), path?: string, onLoad: onSoundLoad);

        /**
         * Return `true` if the sound has been loaded.
         */
        public isLoaded(): boolean;

        /**
         * `onEnd` {?function(successfully)} Optional callback function that gets called when the playback finishes successfully or an audio decoding error interrupts it.
         */
        public play(onEnd?: onPlayEnd): void;

        /**
         * `callback` {?function()} Optional callback function that gets called when the sound has been paused.
         *
         * Pause the sound.
         */
        public pause(callback?: () => void): void;

        /**
         * `callback` {?function()} Optional callback function that gets called when the sound has been stopped.
         *
         * Stop playback and set the seek position to 0.
         */
        public stop(callback?: () => void): void;

        /**
         * Release the audio player resource associated with the instance.
         */
        public release(): void;

        /**
         * Return the duration in seconds, or `-1` before the sound gets loaded.
         */
        public getDuration(): number;

        /**
         * `value` {number} Set the volume, ranging from `0.0` (silence) through `1.0` (full volume).
         */
        public setVolume(volume: number): void;

        /**
         * Return the stereo pan position of the audio player (not the system-wide pan),
         * ranging from `-1.0` (full left) through `1.0` (full right). The default value is `0.0` (center).
         */
        public getPan(): number;

        /**
         * `value` {number} Set the pan, ranging from `-1.0` (full left) through `1.0` (full right).
         */
        public setPan(pan: number): void;

        /**
         * Return the loop count of the audio player.
         * The default is `0` which means to play the sound once.
         * A positive number specifies the number of times to return to the start and play again.
         * A negative number indicates an indefinite loop.
         */
        public getNumberOfLoops(): number;

        /**
         * `value` {number} Set the loop count. `0` means to play the sound once.
         * A positive number specifies the number of times to return to the start and play again (iOS only).
         * A negative number indicates an indefinite loop (iOS and Android).
         */
        public setNumberOfLoops(loops: number): void;

        /**
         * `callback` {function(seconds, isPlaying)}
         * Callback will receive the current playback position in seconds and whether the sound is being played.
         */
        public getCurrentTime(callback: onGetCurrentTime): void;

        /**
         * value {number} Seek to a particular playback point in seconds.
         */
        public setCurrentTime(time: number): void;

        /**
         * value {number} Speed of the audio playback (iOS Only).
         */
        public setSpeed(value: number): void;
    }
}
