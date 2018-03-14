//
//  AudioConverter.h
//  AudioConverter
//
//  Created by erpapa on 2017/6/13.
//  Copyright © 2017年 erpapa. All rights reserved.
//

#import <Foundation/Foundation.h>

//! Project version number for AudioConverter.
FOUNDATION_EXPORT double AudioConverterVersionNumber;

//! Project version string for AudioConverter.
FOUNDATION_EXPORT const unsigned char AudioConverterVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <AudioConverter/PublicHeader.h>

@interface AudioConverter : NSObject

/*
 * 1.m4a->pcm(wav)
 */
+ (BOOL)convertM4a:(NSString *)srcPath toPcm:(NSString *)destPath completionHandler:(void (^)(void))handler;

/*
 * 2.pcm->m4a
 */
+ (BOOL)convertPcm:(NSString *)srcPath toM4a:(NSString *)destPath completionHandler:(void (^)(NSError *error))handler;

/*
 * 3.amr->wav
 */
+ (void)convertAmr:(NSString *)srcPath toWav:(NSString *)destPath completionHandler:(void (^)(BOOL success))handler;

/*
 * 4.wav->amr
 */
+ (void)convertWav:(NSString *)srcPath toAmr:(NSString *)destPath completionHandler:(void (^)(BOOL success))handler;

/*
 * 5.wav->mp3
 */
+ (void)convertWav:(NSString *)srcPath toMp3:(NSString *)destPath completionHandler:(void (^)(BOOL success))handler;

/*
 * 6.mp3->wav
 */
+ (BOOL)convertMp3:(NSString *)srcPath toWav:(NSString *)destPath completionHandler:(void (^)(void))handler;

@end

