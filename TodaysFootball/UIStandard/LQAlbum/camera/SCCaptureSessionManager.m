//
//  SCCaptureSessionManager.m
//  SCCaptureCameraDemo
//
//  Created by Aevitx on 14-1-16.
//  Copyright (c) 2014年 Aevitx. All rights reserved.
//

#import "SCCaptureSessionManager.h"
#import <ImageIO/ImageIO.h>
#define kCapturedPhotoSuccessfully              @"caputuredPhotoSuccessfully"
@interface SCCaptureSessionManager ()

@property (nonatomic, strong) UIView *preview;

// 是否前置摄像头，默认为 NO。用于解决前置摄像头镜像问题。添加于 2015.11.6 12:15 余洋确认
@property (nonatomic, assign) BOOL    isFrontCamera;

@end

@implementation SCCaptureSessionManager


#pragma mark configure
- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _scaleNum    = 1.f;
        _preScaleNum = 1.f;
        _outPutImgSquare = 800;
    }
    return self;
}

- (void)dealloc {
    [_session stopRunning];
    self.previewLayer = nil;
    self.session = nil;
    self.stillImageOutput = nil;
}

- (void)configureWithParentLayer:(UIView*)parent previewRect:(CGRect)preivewRect
{
    self.preview = parent;
    //1、队列
    [self createQueue];
    //2、session
    [self addSession];
    //3、previewLayer
   
    //self.view.bounds
    [self addVideoPreviewLayerWithRect: preivewRect];
    
    [parent.layer addSublayer:_previewLayer];
    //4、input
    [self addVideoInputFrontCamera:self.isOnlyHasFrontCamera];
    //5、output
    [self addStillImageOutput];
}

//创建一个队列，防止阻塞主线程
- (void)createQueue
{
	dispatch_queue_t sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL);
    self.sessionQueue = sessionQueue;
}


// session
- (void)addSession {
    AVCaptureSession *tmpSession = [[AVCaptureSession alloc] init];
    self.session = tmpSession;
    //设置质量
  _session.sessionPreset = AVCaptureSessionPresetPhoto;
}
/**
 *  相机的实时预览页面
 *
 *  @param previewRect 预览页面的frame
 */
- (void)addVideoPreviewLayerWithRect:(CGRect)previewRect {
    
    AVCaptureVideoPreviewLayer *preview = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_session];
    preview.videoGravity = AVLayerVideoGravityResizeAspectFill;
    preview.frame = previewRect;
    self.previewLayer = preview;
}
/**
 *  判断是否有只有前置没有后置摄像头
 *
 *  @return BOOL 是否只有前置摄像头
 */
-(BOOL)isOnlyHasFrontCamera{

    NSArray *devices = [AVCaptureDevice devices];
    AVCaptureDevice *frontCamera;
    AVCaptureDevice *backCamera;
    
    for (AVCaptureDevice *device in devices) {
        
        if ([device hasMediaType:AVMediaTypeVideo]) {
            if ([device position] == AVCaptureDevicePositionBack) {
                backCamera = device;
            }  else {
                frontCamera = device;
            }
        }
    }
    
    if (frontCamera&&!backCamera) {
        return YES;
    }else {
        return NO;
    }
}

/**
 *  添加输入设备
 *
 *  @param front 前或后摄像头 //注意，front手动设为NO时，会有逻辑错误，错误出现在只有前置摄像头时
 */
- (void)addVideoInputFrontCamera:(BOOL)front {
    
    NSArray *devices = [AVCaptureDevice devices];
    AVCaptureDevice *frontCamera;
    AVCaptureDevice *backCamera;
    
    for (AVCaptureDevice *device in devices) {
       
        if ([device hasMediaType:AVMediaTypeVideo]) {
            if ([device position] == AVCaptureDevicePositionBack) {
                backCamera = device;
            }  else {
                frontCamera = device;
            }
        }
    }

    NSError *error;
    if (front) {
        AVCaptureDeviceInput *frontFacingCameraDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:frontCamera error:&error];
        if (!error) {
            if ([_session canAddInput:frontFacingCameraDeviceInput]) {
                [_session addInput:frontFacingCameraDeviceInput];
                self.inputDevice = frontFacingCameraDeviceInput;
                
            } else {
               
            }
        }
    } else {
        AVCaptureDeviceInput *backFacingCameraDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:backCamera error:&error];
        if (!error) {
            if ([_session canAddInput:backFacingCameraDeviceInput]) {
                [_session addInput:backFacingCameraDeviceInput];
                self.inputDevice = backFacingCameraDeviceInput;
            } else {
                
            }
        }
    }
}

/**
 *  添加输出设备
 */
- (void)addStillImageOutput {
    AVCaptureStillImageOutput *tmpOutput = [[AVCaptureStillImageOutput alloc] init];
    NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:AVVideoCodecJPEG,AVVideoCodecKey,nil];//输出jpeg
    tmpOutput.outputSettings = outputSettings;
    
//    AVCaptureConnection *videoConnection = [self findVideoConnection];
    [_session addOutput:tmpOutput];
    self.stillImageOutput = tmpOutput;
}

#pragma mark - actions
/**
 *  @brief  拍照
 *
 *  @param block 拍照完成block
 */
- (void)takePicture:(DidCapturePhotoBlock)block
{
    AVCaptureConnection *videoConnection = [self findVideoConnection];
    [videoConnection setVideoScaleAndCropFactor:_scaleNum];
    NSLog(@"about to request a capture from: %@", _stillImageOutput);
    
    
    [_stillImageOutput captureStillImageAsynchronouslyFromConnection:videoConnection
                                                   completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
                                                       
                                                       CFDictionaryRef exifAttachments = CMGetAttachment(imageDataSampleBuffer, kCGImagePropertyExifDictionary, NULL);
                                                       if (exifAttachments) {
                                                           NSLog(@"attachements: %@", exifAttachments);
                                                       } else {
                                                           NSLog(@"no attachments");
                                                       }
                                                       
                                                       //将buffer内容转成Data
                                                       NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                                                       //用Data生成image
                                                       UIImage *image = [[UIImage alloc] initWithData:imageData];
                                                       NSLog(@"originImage:%@", [NSValue valueWithCGSize:image.size]);
                                                       
                                                       CGFloat imageWidth  = image.size.width;
                                                       CGFloat imageHeight = image.size.height;
                                                       
                                                       //因为切割位置为图片中心位置的正方形，所以y坐标为(图片高 - 图片宽)/2
                                                       CGFloat cropY = (imageHeight - imageWidth) / 2;
                                                       
                                                       //获得的图片比实时预览取景框中的图像大一圈，将这一圈作为边界裁剪掉
                                                       CGFloat border = imageWidth * 0.13;
                                                       
                                                       //限制设置的压缩尺寸
                                                       if (self.outPutImgSquare >= imageWidth) {
                                                           self.outPutImgSquare = imageWidth;
                                                       }
                                                       
                                                       //因为获得的图片中的UIImageOrientation属性为UIImageOrientationRight
                                                       //所以需要获取的区域坐标应该按横向的方式来取
                                                       CGRect cropFrame = CGRectMake(cropY + border, border, imageWidth - border * 2, imageWidth - border * 2);
                                                       
                                                       //截取需要的区域，并保持图片的UIImageOrientation属性不变
                                                       //后面对图片进行压缩时会进行相关处理，把图片转正
                                                       CGImageRef imageRef = CGImageCreateWithImageInRect([image CGImage], cropFrame);
                                                       
                                                       // 前置相机镜像问题
                                                       UIImageOrientation imageOrientation = self.isFrontCamera ? UIImageOrientationLeftMirrored : UIImageOrientationRight;
                                                       UIImage *croppedImage = [UIImage imageWithCGImage:imageRef scale:1 orientation:imageOrientation];
                                                       CGImageRelease(imageRef);
                                                       
                                                       //设置需要压缩的大小
                                                       CGSize size = CGSizeMake(self.outPutImgSquare, self.outPutImgSquare);
                                                       
                                                       //压缩图片
                                                       UIImage *scaledImage = [croppedImage resizedImageWithContentMode:UIViewContentModeScaleAspectFill
                                                                                                                 bounds:size
                                                                                                   interpolationQuality:kCGInterpolationHigh];
                                                       
                                                       //如果屏幕旋转了，将图像旋转正
                                                       //如果应用设置了不支持旋转屏，这段可以不要
                                                       UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
                                                       if (orientation != UIDeviceOrientationPortrait) {
                                                           CGFloat degree = 0;
                                                           if (orientation == UIDeviceOrientationPortraitUpsideDown) {
                                                               degree = 180;// M_PI;
                                                           } else if (orientation == UIDeviceOrientationLandscapeLeft) {
                                                               degree = -90;// -M_PI_2;
                                                           } else if (orientation == UIDeviceOrientationLandscapeRight) {
                                                               degree = 90;// M_PI_2;
                                                           }
                                                           scaledImage = [scaledImage rotatedByDegrees:degree];
                                                       }
                                                       if (block) {
                                                           block(scaledImage);
                                                       } else if ([_delegate respondsToSelector:@selector(didCapturePhoto:)]) {
                                                           [_delegate didCapturePhoto:scaledImage];
                                                       } else {
                                                           [[NSNotificationCenter defaultCenter] postNotificationName:kCapturedPhotoSuccessfully object:scaledImage];
                                                       }
                                                   }];
}

- (AVCaptureVideoOrientation)avOrientationForDeviceOrientation:(UIDeviceOrientation)deviceOrientation
{
	AVCaptureVideoOrientation result = (AVCaptureVideoOrientation)deviceOrientation;
	if ( deviceOrientation == UIDeviceOrientationLandscapeLeft )
		result = AVCaptureVideoOrientationLandscapeRight;
	else if ( deviceOrientation == UIDeviceOrientationLandscapeRight )
		result = AVCaptureVideoOrientationLandscapeLeft;
	return result;
}

/**
 *  切换前后摄像头
 *
 *  @param isFrontCamera YES:前摄像头  NO:后摄像头
 */
- (void)switchCamera:(BOOL)isFrontCamera {
    if (!_inputDevice) {
        return;
    }
    self.isFrontCamera = isFrontCamera;
    [_session beginConfiguration];
    [_session removeInput:_inputDevice];
    [self addVideoInputFrontCamera:isFrontCamera];
    [_session commitConfiguration];
}
/**
 *  拉近拉远镜头
 *
 *  @param scale 拉伸倍数
 */
- (void)pinchCameraViewWithScalNum:(CGFloat)scale {
    _scaleNum = scale;
    if (_scaleNum < MIN_PINCH_SCALE_NUM) {
        _scaleNum = MIN_PINCH_SCALE_NUM;
    } else if (_scaleNum > MAX_PINCH_SCALE_NUM) {
        _scaleNum = MAX_PINCH_SCALE_NUM;
    }
    [self doPinch];
    _preScaleNum = scale;
}

- (void)pinchCameraView:(UIPinchGestureRecognizer *)gesture {
    
    BOOL allTouchesAreOnThePreviewLayer = YES;
	NSUInteger numTouches = [gesture numberOfTouches], i;
	for ( i = 0; i < numTouches; ++i ) {
		CGPoint location = [gesture locationOfTouch:i inView:_preview];
		CGPoint convertedLocation = [_previewLayer convertPoint:location fromLayer:_previewLayer.superlayer];
		if ( ! [_previewLayer containsPoint:convertedLocation] ) {
			allTouchesAreOnThePreviewLayer = NO;
			break;
		}
	}
	if ( allTouchesAreOnThePreviewLayer ) {
		_scaleNum = _preScaleNum * gesture.scale;
        
        if (_scaleNum < MIN_PINCH_SCALE_NUM) {
            _scaleNum = MIN_PINCH_SCALE_NUM;
        } else if (_scaleNum > MAX_PINCH_SCALE_NUM) {
            _scaleNum = MAX_PINCH_SCALE_NUM;
        }
        
        [self doPinch];
	}
    
    if ([gesture state] == UIGestureRecognizerStateEnded ||
        [gesture state] == UIGestureRecognizerStateCancelled ||
        [gesture state] == UIGestureRecognizerStateFailed) {
    }
}

- (void)doPinch {
    AVCaptureConnection *videoConnection = [self findVideoConnection];
    CGFloat maxScale = videoConnection.videoMaxScaleAndCropFactor;//videoScaleAndCropFactor这个属性取值范围是1.0-videoMaxScaleAndCropFactor。iOS5+才可以用
    if (_scaleNum > maxScale) {
        _scaleNum = maxScale;
    }
    
    [CATransaction begin];
    [CATransaction setAnimationDuration:.025];
    [_previewLayer setAffineTransform:CGAffineTransformMakeScale(_scaleNum, _scaleNum)];
    [CATransaction commit];
}

/**
 切换闪光灯模式
 *  （切换顺序：最开始是auto，然后是off，最后是on，一直循环）
 @param sender 闪光灯按钮
 */
- (void)switchFlashMode:(UIButton*)sender {
    
    Class captureDeviceClass = NSClassFromString(@"AVCaptureDevice");
    if (!captureDeviceClass) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:(@"提示信息") message:(@"您的设备没有拍照功能") delegate:nil cancelButtonTitle:(@"Sure") otherButtonTitles: nil];
        [alert show];
        return;
    }
    
    NSString *imgStr = @"";
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    [device lockForConfiguration:nil];
    if ([device hasFlash]) {
            if (device.flashMode == AVCaptureFlashModeOff) {
                device.flashMode = AVCaptureFlashModeOn;
                imgStr = @"SCCamera.bundle/find_friends_photo_light";
                
            } else if (device.flashMode == AVCaptureFlashModeOn) {
                device.flashMode = AVCaptureFlashModeAuto;
                imgStr = @"SCCamera.bundle/find_friends_photo_light_auto";
                
            } else if (device.flashMode == AVCaptureFlashModeAuto) {
                device.flashMode = AVCaptureFlashModeOff;
                imgStr = @"SCCamera.bundle/find_friends_photo_light_none";
                
            }
        if (sender) {
            [sender setImage:imageWithName(imgStr) forState:UIControlStateNormal];
        }
        
    } else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:(@"提示信息") message:(@"您的设备没有闪光灯功能") delegate:nil cancelButtonTitle:(@"取消") otherButtonTitles: nil];
        [alert show];
    }
    [device unlockForConfiguration];
}

/**
 *  点击后对焦
 *
 *  @param devicePoint 点击的point
 */
- (void)focusInPoint:(CGPoint)devicePoint {
    devicePoint = [self convertToPointOfInterestFromViewCoordinates:devicePoint];
	[self focusWithMode:AVCaptureFocusModeAutoFocus exposeWithMode:AVCaptureExposureModeContinuousAutoExposure atDevicePoint:devicePoint monitorSubjectAreaChange:YES];
}

- (void)focusWithMode:(AVCaptureFocusMode)focusMode exposeWithMode:(AVCaptureExposureMode)exposureMode atDevicePoint:(CGPoint)point monitorSubjectAreaChange:(BOOL)monitorSubjectAreaChange {
    
	dispatch_async(_sessionQueue, ^{
		AVCaptureDevice *device = [_inputDevice device];
		NSError *error = nil;
		if ([device lockForConfiguration:&error])
		{
			if ([device isFocusPointOfInterestSupported] && [device isFocusModeSupported:focusMode])
			{
				[device setFocusMode:focusMode];
				[device setFocusPointOfInterest:point];
			}
			if ([device isExposurePointOfInterestSupported] && [device isExposureModeSupported:exposureMode])
			{
				[device setExposureMode:exposureMode];
				[device setExposurePointOfInterest:point];
			}
			[device setSubjectAreaChangeMonitoringEnabled:monitorSubjectAreaChange];
			[device unlockForConfiguration];
		}
		else
		{
			NSLog(@"%@", error);
		}
	});
}

- (void)subjectAreaDidChange:(NSNotification *)notification {
    
	CGPoint devicePoint = CGPointMake(.5, .5);
	[self focusWithMode:AVCaptureFocusModeContinuousAutoFocus exposeWithMode:AVCaptureExposureModeContinuousAutoExposure atDevicePoint:devicePoint monitorSubjectAreaChange:NO];
}

/**
 *  外部的point转换为camera需要的point(外部point/相机页面的frame)
 *
 *  @param viewCoordinates 外部的point
 *
 *  @return 相对位置的point
 */
- (CGPoint)convertToPointOfInterestFromViewCoordinates:(CGPoint)viewCoordinates {
    CGPoint pointOfInterest = CGPointMake(.5f, .5f);
    CGSize frameSize = _previewLayer.bounds.size;
    
    AVCaptureVideoPreviewLayer *videoPreviewLayer = self.previewLayer;
    
    if([[videoPreviewLayer videoGravity]isEqualToString:AVLayerVideoGravityResize]) {
        pointOfInterest = CGPointMake(viewCoordinates.y / frameSize.height, 1.f - (viewCoordinates.x / frameSize.width));
    } else {
        CGRect cleanAperture;
        for(AVCaptureInputPort *port in [[self.session.inputs lastObject]ports]) {
            if([port mediaType] == AVMediaTypeVideo) {
                cleanAperture = CMVideoFormatDescriptionGetCleanAperture([port formatDescription], YES);
                CGSize apertureSize = cleanAperture.size;
                CGPoint point = viewCoordinates;
                
                CGFloat apertureRatio = apertureSize.height / apertureSize.width;
                CGFloat viewRatio = frameSize.width / frameSize.height;
                CGFloat xc = .5f;
                CGFloat yc = .5f;
                
                if([[videoPreviewLayer videoGravity]isEqualToString:AVLayerVideoGravityResizeAspect]) {
                    if(viewRatio > apertureRatio) {
                        CGFloat y2 = frameSize.height;
                        CGFloat x2 = frameSize.height * apertureRatio;
                        CGFloat x1 = frameSize.width;
                        CGFloat blackBar = (x1 - x2) / 2;
                        if(point.x >= blackBar && point.x <= blackBar + x2) {
                            xc = point.y / y2;
                            yc = 1.f - ((point.x - blackBar) / x2);
                        }
                    } else {
                        CGFloat y2 = frameSize.width / apertureRatio;
                        CGFloat y1 = frameSize.height;
                        CGFloat x2 = frameSize.width;
                        CGFloat blackBar = (y1 - y2) / 2;
                        if(point.y >= blackBar && point.y <= blackBar + y2) {
                            xc = ((point.y - blackBar) / y2);
                            yc = 1.f - (point.x / x2);
                        }
                    }
                } else if([[videoPreviewLayer videoGravity]isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
                    if(viewRatio > apertureRatio) {
                        CGFloat y2 = apertureSize.width * (frameSize.width / apertureSize.height);
                        xc = (point.y + ((y2 - frameSize.height) / 2.f)) / y2;
                        yc = (frameSize.width - point.x) / frameSize.width;
                    } else {
                        CGFloat x2 = apertureSize.height * (frameSize.height / apertureSize.width);
                        yc = 1.f - ((point.x + ((x2 - frameSize.width) / 2)) / x2);
                        xc = point.y / frameSize.height;
                    }
                    
                }
                pointOfInterest = CGPointMake(xc, yc);
                break;
            }
        }
    }
    
    return pointOfInterest;
}


#pragma mark ---------------private--------------
- (AVCaptureConnection*)findVideoConnection {
    AVCaptureConnection *videoConnection = nil;
	for (AVCaptureConnection *connection in _stillImageOutput.connections) {
		for (AVCaptureInputPort *port in connection.inputPorts) {
			if ([[port mediaType] isEqual:AVMediaTypeVideo]) {
				videoConnection = connection;
				break;
			}
		}
		if (videoConnection) {
            break;
        }
	}
    return videoConnection;
}



@end