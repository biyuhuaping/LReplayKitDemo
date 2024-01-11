//
//  ViewController.m
//  LReplayKitDemo
//
//  Created by liumingfei on 2021/11/24.
//

#import "ViewController.h"
#import <ReplayKit/ReplayKit.h>

@interface ViewController ()<RPScreenRecorderDelegate, RPPreviewViewControllerDelegate>

@property (nonatomic, retain) NSTimer *coutTimer;
@property (nonatomic, assign) IBOutlet UILabel *timerLab;
@property (nonatomic, assign) IBOutlet UIButton *eventBtn;
@property (nonatomic, assign) NSInteger cCount;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (IBAction)startOrStopRecord:(id)sender {
    [self startRecord];
}

#pragma mark - 开始/结束录制
//开始录制
- (void)startRecord{
    if ([RPScreenRecorder sharedRecorder].recording==YES) {
        NSLog(@"正在录制，录制结束");
        [self stopRecordAndShowVideoPreviewController:YES];
        [self.coutTimer setFireDate:[NSDate distantFuture]];
        [self.eventBtn setTitle:@"重新录制" forState:UIControlStateNormal];
        return;
    }
    if ([[RPScreenRecorder sharedRecorder] isAvailable]) {
        NSLog(@"录制开始初始化");
        [RPScreenRecorder sharedRecorder].delegate = self;
        [RPScreenRecorder sharedRecorder].microphoneEnabled = YES;
        [[RPScreenRecorder sharedRecorder] startRecordingWithHandler:^(NSError *error){
            if (error) {
                NSLog(@"开始录制失败 %@",error);
            }else{
                NSLog(@"开始录制");
                self.cCount = 0;
                [self.coutTimer setFireDate:[NSDate distantPast]];
                [self.eventBtn setTitle:@"结束录制" forState:UIControlStateNormal];
            }
        }];
    }
}

//结束录制
- (void)stopRecordAndShowVideoPreviewController:(BOOL)isShow{
    NSLog(@"准备结束录制");
    [[RPScreenRecorder sharedRecorder] stopRecordingWithHandler:^(RPPreviewViewController *previewViewController, NSError *  error){
        if (error) {
            NSLog(@"结束录制失败 %@", error);
        } else {
            NSLog(@"录制完成");
            /// 录制视频地址
            NSURL *sourceURL = [previewViewController valueForKey:@"movieURL"];
            
            /// 视频转存
            /// 转存路径获取
            NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)lastObject];
            NSString *picPath = [documentsDirectory stringByAppendingPathComponent:@"video"];
            if (![[NSFileManager defaultManager] fileExistsAtPath:picPath]) {
                [[NSFileManager defaultManager] createDirectoryAtPath:picPath withIntermediateDirectories:YES attributes:nil error:nil];
            }
            NSString *imageID = @"tmp.mp4";
            NSString *filePath = [picPath stringByAppendingPathComponent:imageID];
            if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
                [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
            }
            
            ///CMPersistentTrackID
            AVMutableComposition *mixComposition = [AVMutableComposition composition];
            
            AVURLAsset *fileAsset = [[AVURLAsset alloc]initWithURL:sourceURL options:nil];
            if ([fileAsset tracksWithMediaType:AVMediaTypeAudio].count > 0 && [fileAsset tracksWithMediaType:AVMediaTypeVideo].count > 0) {
                for (AVAssetTrack *mAVAssetTrack in [fileAsset tracks]) {
                    if ([@"vide" isEqualToString:mAVAssetTrack.mediaType]){
                        NSError *error;
                        AVMutableCompositionTrack *videoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:(kCMPersistentTrackID_Invalid)];
                        [videoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, fileAsset.duration) ofTrack:mAVAssetTrack atTime:kCMTimeZero error:&error];
                    } else if ([@"soun" isEqualToString:mAVAssetTrack.mediaType]) {
                        NSError *error;
                        AVMutableCompositionTrack *audioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:(kCMPersistentTrackID_Invalid)];
                        [audioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, fileAsset.duration) ofTrack:mAVAssetTrack atTime:kCMTimeZero error:&error];
                    }
                }
            }
            
            AVAssetExportSession *assetExport = [[AVAssetExportSession alloc]initWithAsset:mixComposition presetName:AVAssetExportPreset1280x720];
            assetExport.outputFileType = AVFileTypeMPEG4;
            assetExport.outputURL = [NSURL fileURLWithPath:filePath];
            assetExport.shouldOptimizeForNetworkUse = false;
            [assetExport exportAsynchronouslyWithCompletionHandler:^{
                if (assetExport.status == AVAssetExportSessionStatusCompleted) {
                    NSLog(@"转存成功：%@",filePath);
                } else {
                    NSLog(@"转存失败");
                }
            }];
            /// 视频预览
            if (isShow) {
                previewViewController.previewControllerDelegate = self;
                [self presentViewController:previewViewController animated:YES completion:nil];
            }
        }
    }];
}

#pragma mark - 录制事件回调
// 录屏结束, 显示出预览画面
- (void)screenRecorder:(RPScreenRecorder *)screenRecorder didStopRecordingWithPreviewViewController:(nullable RPPreviewViewController *)previewViewController error:(nullable NSError *)error {
    NSLog(@"录屏结束, 显示出预览画面");
}

// [RPScreenRecorder sharedRecorder].isAvailable, 状态变化会抛这个回调
- (void)screenRecorderDidChangeAvailability:(RPScreenRecorder *)screenRecorder {
    NSLog(@"[RPScreenRecorder sharedRecorder].isAvailable状态改变, %d",[RPScreenRecorder sharedRecorder].isAvailable);
}

#pragma mark - RPPreviewViewControllerDelegate 预览视图回调
// 预览视图编辑结束, 取消/存储
- (void)previewControllerDidFinish:(RPPreviewViewController *)previewController {
    [previewController dismissViewControllerAnimated:YES completion:nil];
}

// 预览页面点击保存,取消,复制,AirDrop等,会进入此回调,不需要做什么逻辑,只是把事件回调回来
- (void)previewController:(RPPreviewViewController *)previewController didFinishWithActivityTypes:(NSSet <NSString *> *)activityTypes {
    if ([activityTypes containsObject:@"com.apple.UIKit.activity.SaveToCameraRoll"]) {
        NSLog(@"保存到系统相册");
    }
    if ([activityTypes containsObject:@"com.apple.UIKit.activity.CopyToPasteboard"]) {
        NSLog(@"复制到粘贴板");
    }
    if ([activityTypes containsObject:@"com.apple.UIKit.activity.AirDrop"]) {
        NSLog(@"AirDrop发送成功");
    }
}

#pragma mark -
- (void)timerEvent {
    self.cCount += 1;
}

- (NSTimer *)coutTimer {
    if (!_coutTimer) {
        _coutTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(timerEvent) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:_coutTimer forMode:NSRunLoopCommonModes];
    }
    return _coutTimer;
}

- (void)setCCount:(NSInteger)cCount {
    _cCount = cCount;
    self.timerLab.text = [NSString stringWithFormat:@"%02ld:%02ld",cCount/60,cCount%60];
}

@end
