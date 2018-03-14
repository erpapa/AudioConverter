//
//  AudioConverter.m
//  AudioConverter
//
//  Created by erpapa on 2017/6/13.
//  Copyright © 2017年 erpapa. All rights reserved.
//

#import <CoreMedia/CoreMedia.h>
#import <AVFoundation/AVFoundation.h>
#import "AudioConverter.h"
#import "amrFileCodec.h"
#import "lame.h"

@implementation AudioConverter

+ (void)checkFilePath:(NSString *)filePath
{
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:NULL];
    } else {
        NSString *dirPath = [filePath stringByDeletingLastPathComponent];
        BOOL isDir = NO;
        BOOL isExit = [[NSFileManager defaultManager] fileExistsAtPath:dirPath isDirectory:&isDir];
        if (isExit == NO || isDir == NO) {
            [[NSFileManager defaultManager] createDirectoryAtPath:dirPath withIntermediateDirectories:YES attributes:nil error:NULL];
        }
    }
}

/*
 * 1.m4a->pcm(wav)
 */
+ (BOOL)convertM4a:(NSString *)srcPath toPcm:(NSString *)destPath completionHandler:(void (^)(void))handler
{
    if ([[NSFileManager defaultManager] fileExistsAtPath:srcPath] == NO) {
        return NO;
    }
    
    NSURL *originalUrl = [NSURL fileURLWithPath:srcPath];
    AVURLAsset *songAsset = [AVURLAsset URLAssetWithURL:originalUrl options:nil];
    NSArray *tracks = [songAsset tracksWithMediaType:AVMediaTypeAudio];
    if (tracks == 0) {
        NSLog (@"no audio tranks!");
        return NO;
    }
    AVAssetTrack *soundTrack = [tracks firstObject];
    CMTime startTime = CMTimeMake (0, soundTrack.naturalTimeScale);
    
    //读取原始文件信息
    NSError *error = nil;
    AVAssetReader *assetReader = [AVAssetReader assetReaderWithAsset:songAsset error:&error];
    if (error) {
        NSLog (@"error: %@", error);
        return NO;
    }
    
    AVAssetReaderOutput *assetReaderOutput = [AVAssetReaderAudioMixOutput
                                              assetReaderAudioMixOutputWithAudioTracks:songAsset.tracks
                                              audioSettings: nil];
    if ([assetReader canAddOutput:assetReaderOutput]) {
        [assetReader addOutput:assetReaderOutput];
    } else {
        NSLog (@"can't add reader output!");
        return NO;
    }
    
    [self checkFilePath:destPath];
    NSURL *destUrl = [NSURL fileURLWithPath:destPath];
    AVAssetWriter *assetWriter = [AVAssetWriter assetWriterWithURL:destUrl
                                                          fileType:AVFileTypeCoreAudioFormat
                                                             error:&error];
    if (error) {
        NSLog (@"error: %@", error);
        return NO;
    }
    AudioChannelLayout channelLayout;
    memset(&channelLayout, 0, sizeof(AudioChannelLayout));
    channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;
    NSDictionary *outputSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithInt:kAudioFormatLinearPCM], AVFormatIDKey,
                                    [NSNumber numberWithFloat:48000.0], AVSampleRateKey,
                                    [NSNumber numberWithInt:2], AVNumberOfChannelsKey,
                                    [NSData dataWithBytes:&channelLayout length:sizeof(AudioChannelLayout)], AVChannelLayoutKey,
                                    [NSNumber numberWithInt:16], AVLinearPCMBitDepthKey,
                                    [NSNumber numberWithBool:NO], AVLinearPCMIsNonInterleaved,
                                    [NSNumber numberWithBool:NO],AVLinearPCMIsFloatKey,
                                    [NSNumber numberWithBool:NO], AVLinearPCMIsBigEndianKey,
                                    nil];
    AVAssetWriterInput *assetWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio
                                                                              outputSettings:outputSettings];
    if ([assetWriter canAddInput:assetWriterInput]) {
        [assetWriter addInput:assetWriterInput];
    } else {
        NSLog (@"can't add asset writer input!");
        return NO;
    }
    
    assetWriterInput.expectsMediaDataInRealTime = NO;
    
    [assetWriter startWriting];
    [assetReader startReading];
    [assetWriter startSessionAtSourceTime:startTime];
    
    __block UInt64 convertedByteCount = 0;
    
    dispatch_queue_t mediaInputQueue = dispatch_queue_create("convertAudioQueue", NULL);
    [assetWriterInput requestMediaDataWhenReadyOnQueue:mediaInputQueue
                                            usingBlock: ^
     {
         while (assetWriterInput.readyForMoreMediaData) {
             CMSampleBufferRef nextBuffer = [assetReaderOutput copyNextSampleBuffer];
             if (nextBuffer) {
                 // append buffer
                 [assetWriterInput appendSampleBuffer: nextBuffer];
                 NSLog (@"appended a buffer (%zu bytes)",
                        CMSampleBufferGetTotalSampleSize (nextBuffer));
                 convertedByteCount += CMSampleBufferGetTotalSampleSize (nextBuffer);
             } else {
                 [assetWriterInput markAsFinished];
                 [assetWriter finishWritingWithCompletionHandler:handler];
                 [assetReader cancelReading];
                 NSDictionary *outputFileAttributes = [[NSFileManager defaultManager]
                                                       attributesOfItemAtPath:[destUrl path]
                                                       error:nil];
                 NSLog (@"%@ fileSize:%lld",destPath.lastPathComponent,[outputFileAttributes fileSize]);
                 break;
             }
         }
         
     }];
    return YES;
}

/*
 * 2.pcm->m4a
 */
+ (BOOL)convertPcm:(NSString *)srcPath toM4a:(NSString *)destPath completionHandler:(void (^)(NSError *error))handler
{
    if ([[NSFileManager defaultManager] fileExistsAtPath:srcPath] == NO) {
        return NO;
    }
    
    NSURL *originalUrl = [NSURL fileURLWithPath:srcPath];
    AVURLAsset *songAsset = [AVURLAsset URLAssetWithURL:originalUrl options:nil];
    NSArray *tracks = [songAsset tracksWithMediaType:AVMediaTypeAudio];
    if (tracks == 0) {
        NSLog (@"no audio tranks!");
        return NO;
    }
    
    [self checkFilePath:destPath];
    NSURL *exportUrl = [NSURL fileURLWithPath:destPath];
    AVAssetExportSession *exporter = [AVAssetExportSession exportSessionWithAsset:songAsset presetName: AVAssetExportPresetAppleM4A];
    exporter.outputFileType = AVFileTypeAppleM4A; //@"com.apple.m4a-audio";
    exporter.outputURL = exportUrl;
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        if (exporter.status == AVAssetExportSessionStatusCompleted) {
            if (handler) {
                handler(nil);
            }
        } else {
            if (handler) {
                handler(exporter.error);
            }
        }
    }];
    return YES;
}

/*
 * 3.amr->wav
 */
+ (void)convertAmr:(NSString *)srcPath toWav:(NSString *)destPath completionHandler:(void (^)(BOOL success))handler
{
    if ([[NSFileManager defaultManager] fileExistsAtPath:srcPath] == NO) {
        if (handler) {
            handler(NO);
        }
    }
    
    [self checkFilePath:destPath];
    dispatch_queue_t mediaInputQueue = dispatch_queue_create("convertAudioQueue", NULL);
    dispatch_async(mediaInputQueue, ^{
        int result = DecodeAMRFileToWAVEFile([srcPath cStringUsingEncoding:NSUTF8StringEncoding], [destPath cStringUsingEncoding:NSUTF8StringEncoding]);
        if (handler) {
            handler(result);
        }
    });
}

/*
 * 4.wav->amr
 */
+ (void)convertWav:(NSString *)srcPath toAmr:(NSString *)destPath completionHandler:(void (^)(BOOL success))handler
{
    if ([[NSFileManager defaultManager] fileExistsAtPath:srcPath] == NO) {
        if (handler) {
            handler(NO);
        }
    }
    [self checkFilePath:destPath];
    dispatch_queue_t mediaInputQueue = dispatch_queue_create("convertAudioQueue", NULL);
    dispatch_async(mediaInputQueue, ^{
        int result = EncodeWAVEFileToAMRFile([srcPath cStringUsingEncoding:NSUTF8StringEncoding], [destPath cStringUsingEncoding:NSUTF8StringEncoding], 1, 16);
        if (handler) {
            handler(result);
        }
    });
}

/*
 * 5.wav->mp3
 */
// 获取录音设置
+ (NSDictionary*)GetAudioRecorderSettingDict{
    NSDictionary *recordSetting = [[NSDictionary alloc] initWithObjectsAndKeys:
                                   [NSNumber numberWithFloat: 8000.0],AVSampleRateKey, //采样率
                                   [NSNumber numberWithInt: kAudioFormatLinearPCM],AVFormatIDKey,
                                   [NSNumber numberWithInt:16],AVLinearPCMBitDepthKey,//采样位数 默认 16
                                   [NSNumber numberWithInt:2], AVNumberOfChannelsKey,//通道的数目
                                   //                                   [NSNumber numberWithBool:NO],AVLinearPCMIsBigEndianKey,//大端还是小端 是内存的组织方式
                                   //                                   [NSNumber numberWithBool:NO],AVLinearPCMIsFloatKey,//采样信号是整数还是浮点数
                                   //                                   [NSNumber numberWithInt: AVAudioQualityMedium],AVEncoderAudioQualityKey,//音频编码质量
                                   nil];
    return recordSetting;
}

+ (void)convertWav:(NSString *)srcPath toMp3:(NSString *)destPath completionHandler:(void (^)(BOOL success))handler
{
    dispatch_queue_t mediaInputQueue = dispatch_queue_create("convertAudioQueue", NULL);
    dispatch_async(mediaInputQueue, ^{
        int state = 0;
        @try {
            int read, write;
            
            FILE *pcm = fopen([srcPath cStringUsingEncoding:NSASCIIStringEncoding], "rb");  //source
            fseek(pcm, 4*1024, SEEK_CUR);                                   //skip file header
            FILE *mp3 = fopen([destPath cStringUsingEncoding:NSASCIIStringEncoding], "wb");  //output
            
            const int PCM_SIZE = 8192;
            const int MP3_SIZE = 8192;
            short int pcm_buffer[PCM_SIZE*2];
            unsigned char mp3_buffer[MP3_SIZE];
            
            lame_t lame = lame_init(); // 初始化
            lame_set_num_channels(lame, 2); // 双声道
            lame_set_in_samplerate(lame, 8000); // 8k采样率
            lame_set_brate(lame, 16);  // 压缩的比特率为16
            lame_set_quality(lame, 2);  // mp3音质
            lame_init_params(lame);
            
            do {
                read = (int)fread(pcm_buffer, 2*sizeof(short int), PCM_SIZE, pcm);
                if (read == 0)
                    write = lame_encode_flush(lame, mp3_buffer, MP3_SIZE);
                else
                    write = lame_encode_buffer_interleaved(lame, pcm_buffer, read, mp3_buffer, MP3_SIZE);
                
                fwrite(mp3_buffer, write, 1, mp3);
                
            } while (read != 0);
            
            lame_close(lame);
            fclose(mp3);
            fclose(pcm);
            state = 1;
        }
        @catch (NSException *exception) {
            state = 0;
        }
        @finally {
            NSLog(@"state=%d",state);
            if (handler) {
                handler(state);
            }
        }
    });
}

/*
 * 6.mp3->wav
 */
+ (BOOL)convertMp3:(NSString *)srcPath toWav:(NSString *)destPath completionHandler:(void (^)(void))handler
{
    return [self convertM4a:srcPath toPcm:destPath completionHandler:handler];
}

@end
