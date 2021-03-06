//
//  PEAGLView.m
//  FFmpegPlayTest
//
//  Created by Jack on 11/1/12.
//  Copyright (c) 2012 Jack. All rights reserved.
//

#import "VideoScreen.h"
#import "RendererFactory.h"
#import <MediaPlayer/MediaPlayer.h>
#import <QuartzCore/CADisplayLink.h>
//#import "RendererProtocol.h"
//#import "ES1Renderer.h"
//#import "ES2Renderer.h"


@interface VideoScreen () <RendererDelegate>
{
    id _displayLink;
    NSTimer* _animationTimer;
    BOOL _useES1;
    id<Renderer> _renderer;
    NSTimeInterval _startTime;
    NSTimeInterval _currentTime;
    VideoPicture* _curPicture;
    
    
    NSInteger _frameCount;
}

@end
//------------------------------------------------------------------------

@implementation VideoScreen
@synthesize source=_source;
@synthesize supportDisplayLink=_supportDisplayLink;
@synthesize frameInterval=_frameInterval;
@synthesize state=_state;
@synthesize delegate=_delegate;

+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

#pragma mark  Initialize 
//------------------------------------------------------------------------
- (id) initWithSource: (id<VideoScreenSource>) source
             delegate: (id<VideoScreenDelegate>) delegate
          scalingMode: (NSInteger) scalingMode
{
    self = [self initWithSource: source delegate:delegate];
    if (self) {
        [self setScalingMode:scalingMode];
    }
    return self;
}

//------------------------------------------------------------------------
- (id) initWithSource: (id<VideoScreenSource>) source
             delegate:(id<VideoScreenDelegate>)delegate
{
    self = [super init];
    if (self) {
        _delegate = delegate;
        _source = source;
        _state = kScreenStateUnknown;
        _supportDisplayLink = NO;
        _displayLink = nil;
        _animationTimer = nil;
        _frameInterval = 1;
        _scalingMode = MPMovieScalingModeAspectFit;
        
        _frameCount = 0;
        if(![self initRenderer])
            return nil;
        
        NSString *reqSysVer = @"3.1";
        NSString *curSysVer = [[UIDevice currentDevice] systemVersion];
        if ([curSysVer compare: reqSysVer options:NSNumericSearch] != NSOrderedAscending) {
            _supportDisplayLink = YES;
        }        
        
        _state = kScreenStateStopped;
    }
    return self;
}

//------------------------------------------------------------------------
- (void) initEAGLlayer
{
    CAEAGLLayer* eaglLayer = (CAEAGLLayer*) self.layer;
    eaglLayer.opaque = TRUE;
    eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool:NO], kEAGLDrawablePropertyRetainedBacking,
                                    kEAGLColorFormatRGB565,      kEAGLDrawablePropertyColorFormat,nil];
    
}

//------------------------------------------------------------------------
/**
 Renderer need two type of information to init
 (1) Description of input video:
    + size of video frame : for scaling calculation
    + Pixel format: for textture buffer generation
 
 input video information can be obtained from _source
 
 (2) Description of view port where to render video pictures
    + Size of view port
    + Layer object : to generate backing colorBuffer
    + Scaling mode
 
 Size and layer object is the layer object of [self], 
 Scaling mode is set by client object ( MoviePlayerController)
 */

- (BOOL) initRenderer
{
    BOOL ret = YES;
    [self initEAGLlayer];
    
    _renderer = [RendererFactory createRendererWithDelegate: self
                                                  videoSource:_source
                                                       screen: self];
    if (!_renderer) {
        NSLog(@"Can not create renderer");
        ret = NO;
        goto finish;
    }
  
    
finish:
    if (!ret && _renderer)
        _renderer = nil;
    
    return ret;
}

//---------------------------------------------------------------------
#pragma mark UIView methods
- (void)layoutSubviews
{
    if ([_renderer prepareTexture]) {
        //[self updateScreen:_displayLink];
    }
    // CAEAGLLayer changeds, so we need to update renderer's
    // setting and texture here.
}

//---------------------------------------------------------------------
- (void) willMoveToSuperview:(UIView *)newSuperview
{
    
}

//---------------------------------------------------------------------
- (void) didMoveToSuperview
{
    if ([_delegate respondsToSelector:@selector(screenDidShow:)]) {
        [_delegate screenDidShow:self];
    }
}

//---------------------------------------------------------------------
#pragma mark Utilities methods
- (void) setCurrentPicture: (VideoPicture*) picture
{
    
}

- (NSInteger) screenScalingMode
{
    switch (_scalingMode) {
        case MPMovieScalingModeNone:
            return kRendererScaleModeNon;
            break;
        case MPMovieScalingModeAspectFit:
            return kRendererScaleModeAspectFit;
            break;
        case MPMovieScalingModeAspectFill:
            return kRendererScaleModeAspectFill;
            break;
        case MPMovieScalingModeFill:
            return kRendererScaleModeScale;
            break;
        default:
            return kRendererScaleModeDefault;
            break;
    }
}
//---------------------------------------------------------------------
#pragma mark Screen Properties

- (NSInteger) frameInterval
{
    return _frameInterval;
}
//---------------------------------------------------------------------
- (void) setFrameInterval:(NSInteger)frameInterval
{
    if (frameInterval > 1) {
        _frameInterval = frameInterval;
        // TODO: Consider paused status
        if ([self isRuning]) {
            [self stop];
            [self start];
        }
    }
}
//---------------------------------------------------------------------
#pragma mark RendererDelegate
- (void) finishFrameByRenderer:(id<Renderer>)renderer
{
    [_source finishFrameForScreen:self];
    _curPicture = nil;
}

//---------------------------------------------------------------------
#pragma mark Display Video

/**
 TODO:
 This method is called at displayLink refresh rate to update texture,
 so this function should do the following:
 
 (1) Get current clock time of video screen
 (2) Invoke source methods to get video frame, given the obtained clock time
 (3) Set new received picture as current picture (release the old one)
 (4) Invoke renderer to render the received picture
 
 
 Q: Do we need to be notified that renderer finished rendering the frame?
 A: No, be cause render to frame is running in the same thread as this one
 (we use current run loop when we create the displaylink), so this method
 exit only when renderer finish its job rendering the frame.
 */
- (void) updateScreen:(id)sender
{
    
    // TODO: need re-enable this
//    if ((_state != kScreenStateRunning) && (_state)) {
//        return;
//    }

//    CADisplayLink* displayLink = (CADisplayLink*) sender;
//*
//    static double lastLastPts = 0;
//    static double lastPts = 0;
//    lastLastPts = lastPts;
//    lastPts = [displayLink timestamp];
//    if (displayLink) {
//        NSLog(@"Time between last two timestamp: %f", lastPts - lastLastPts);
//        //sleep(arc4random_uniform(2));
//    }
//*/
//
//    NSLog(@"Updating video screen");
    _curPicture = [_source getPictureForScreen: self
                                   screenClock: [self currentTimeSinceStart ]];
    if (_curPicture) {
        //usleep(15000);
        [_renderer render:_curPicture];
        _frameCount++;
        //NSLog(@"Frame rate: %.2f", _frameCount/[self currentTimeSinceStart]);
    }
}

//---------------------------------------------------------------------
#pragma mark Controllable protocol
//---------------------------------------------------------------------
- (void) pause
{
    if (_state == kScreenStateRunning) {
        [_displayLink setPaused:YES];
        _state = kScreenStatePaused;
        NSLog(@"Video Screen Paused");
    }
}
- (void) resume
{
    if (_state == kScreenStatePaused) {
        [_displayLink setPaused:NO];
        _state = kScreenStateRunning;
        NSLog(@"Video Screen Resumed");
    }
}
//---------------------------------------------------------------------
- (BOOL) isReady
{
    return _state != kScreenStateUnknown;
}
//---------------------------------------------------------------------
- (void) start
{
    // If screen is initialized but not running
    if((_state != kScreenStateRunning) && (_state != kScreenStatePaused))
    {
        // Start screen refresh by displaylink or nstimer
        if (_supportDisplayLink) {
            _displayLink = [CADisplayLink displayLinkWithTarget:self
                                                       selector:@selector(updateScreen:)];
            [_displayLink setFrameInterval: _frameInterval];
            //[_displayLink setFrameInterval: 60];
            [_displayLink addToRunLoop:[NSRunLoop currentRunLoop]
                               forMode:NSDefaultRunLoopMode];
        }else{
            _animationTimer = [NSTimer scheduledTimerWithTimeInterval:((1.0 / 60.0) * (double) _frameInterval)
                                                               target:self
                                                             selector:@selector(updateScreen:)
                                                             userInfo:nil
                                                              repeats:YES];
        }
        
        _startTime = CACurrentMediaTime();
        
        // Set running flag ON
        _state = kScreenStateRunning;
        NSLog(@"Video Screen Started at: %f", _startTime);
    }
    
    
}
//---------------------------------------------------------------------
- (void) stop
{
    if ((_state == kScreenStateRunning) || (_state == kScreenStatePaused)) {
        if (_supportDisplayLink) {
            [_displayLink invalidate];
            _displayLink = nil;
        }else{
            [_animationTimer invalidate];
            _animationTimer = nil;
        }
        _state = kScreenStateStopped;
        NSLog(@"Video Screen Stopped");
    }
}
//---------------------------------------------------------------------
- (BOOL) isRuning
{
    return (_state == kScreenStateRunning);
}

//---------------------------------------------------------------------
#pragma mark VideoScreen Protocol
@synthesize scalingMode=_scalingMode;
- (id<EAGLDrawable>) viewPort
{
    return ((CAEAGLLayer*) self.layer);
}

//---------------------------------------------------------------------
#pragma mark Clock protocol
- (NSTimeInterval) startTime
{
    return _startTime;
}
//---------------------------------------------------------------------
/**
 Current time of video screen is the time of last display frame.
 */
- (NSTimeInterval) currentTimeSinceStart
{
    return CACurrentMediaTime() - _startTime;
}

@end
