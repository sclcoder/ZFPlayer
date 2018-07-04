
//  ZFOrentationObserver.m
//  ZFPlayer
//
// Copyright (c) 2016年 任子丰 ( http://github.com/renzifeng )
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "ZFOrientationObserver.h"
// 屏幕的宽
#define ScreenWidth                 [[UIScreen mainScreen] bounds].size.width
// 屏幕的高
#define ScreenHeight                [[UIScreen mainScreen] bounds].size.height

@interface UIWindow (CurrentViewController)

/*!
 @method currentViewController
 @return Returns the topViewController in stack of topMostController.
 */
+ (UIViewController*)zf_currentViewController;

@end

@implementation UIWindow (CurrentViewController)

+ (UIViewController*)zf_currentViewController; {
    UIWindow *window = [[UIApplication sharedApplication].delegate window];
    UIViewController *topViewController = [window rootViewController];
    while (true) {
        if (topViewController.presentedViewController) {
            topViewController = topViewController.presentedViewController;
        } else if ([topViewController isKindOfClass:[UINavigationController class]] && [(UINavigationController*)topViewController topViewController]) {
            topViewController = [(UINavigationController *)topViewController topViewController];
        } else if ([topViewController isKindOfClass:[UITabBarController class]]) {
            UITabBarController *tab = (UITabBarController *)topViewController;
            topViewController = tab.selectedViewController;
        } else {
            break;
        }
    }
    return topViewController;
}

@end

static UIWindow *kWindow;

@interface ZFOrientationObserver ()

@property (nonatomic, weak) UIView *view;

@property (nonatomic, assign, getter=isFullScreen) BOOL fullScreen;

@property (nonatomic, assign) BOOL shouldAutorotate;

@property (nonatomic, strong) UIView *cell;

@property (nonatomic, assign) NSInteger playerViewTag;

@property (nonatomic, assign) ZFRotateType roateType;

@end

@implementation ZFOrientationObserver

- (instancetype)init {
    self = [super init];
    if (self) {
        _duration = 0.25;
        _fullScreenMode = ZFFullScreenModeLandscape;
        kWindow = [(id)[UIApplication sharedApplication].delegate valueForKey:@"window"];
    }
    return self;
}

- (instancetype)initWithRotateView:(UIView *)rotateView containerView:(UIView *)containerView {
    if ([self init]) {
        _roateType = ZFRotateTypeNormal;
        _view = rotateView;
        _containerView = containerView;
    }
    return self;
}

- (void)cellModelRotateView:(UIView *)rotateView rotateViewAtCell:(UIView *)cell playerViewTag:(NSInteger)playerViewTag {
    self.roateType = ZFRotateTypeCell;
    self.view = rotateView;
    self.cell = cell;
    self.playerViewTag = playerViewTag;
}

- (void)cellSmallModelRotateView:(UIView *)rotateView containerView:(UIView *)containerView {
    self.roateType = ZFRotateTypeCellSmall;
    self.view = rotateView;
    self.containerView = containerView;
}

- (void)dealloc {
    [self removeDeviceOrientationObserver];
}

- (void)addDeviceOrientationObserver {
    if (![UIDevice currentDevice].generatesDeviceOrientationNotifications) {
        [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    }
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDeviceOrientationChange) name:UIDeviceOrientationDidChangeNotification object:nil];
}

- (void)removeDeviceOrientationObserver {
    if (![UIDevice currentDevice].generatesDeviceOrientationNotifications) {
        [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
    self.shouldAutorotate = NO;
}

- (void)handleDeviceOrientationChange {
    if (self.fullScreenMode == ZFFullScreenModePortrait) return;
    if (UIDeviceOrientationIsValidInterfaceOrientation([UIDevice currentDevice].orientation)) {
        _currentOrientation = (UIInterfaceOrientation)[UIDevice currentDevice].orientation;
    } else {
        _currentOrientation = UIInterfaceOrientationUnknown;
        return;
    }
    
    UIInterfaceOrientation currentOrientation = [UIApplication sharedApplication].statusBarOrientation;
    // Determine that if the current direction is the same as the direction you want to rotate, do nothing
    if (_currentOrientation == currentOrientation && ![self isNeedAdaptiveiOS8Rotation]) return;
    
    switch (_currentOrientation) {
        case UIInterfaceOrientationPortrait: {
            [self enterLandscapeFullScreen:UIInterfaceOrientationPortrait animated:YES];
        }
            break;
        case UIInterfaceOrientationLandscapeLeft: {
            [self enterLandscapeFullScreen:UIInterfaceOrientationLandscapeLeft animated:YES];
        }
            break;
        case UIInterfaceOrientationLandscapeRight: {
            [self enterLandscapeFullScreen:UIInterfaceOrientationLandscapeRight animated:YES];
        }
            break;
        default: break;
    }
}

- (void)enterLandscapeFullScreen:(UIInterfaceOrientation)orientation animated:(BOOL)animated {
    if (self.fullScreenMode == ZFFullScreenModePortrait) return;
    UIView *superview = nil;
    CGRect frame;
    self.shouldAutorotate = [self isNeedAdaptiveiOS8Rotation];
    if ([self isNeedAdaptiveiOS8Rotation]) {
        
        if (UIInterfaceOrientationIsLandscape(orientation)) {
            if (self.fullScreen) return;
            superview = kWindow;
            self.fullScreen = YES;
        } else {
            if (!self.fullScreen) return;
            if (self.roateType == ZFRotateTypeCell) {
                superview = [self.cell viewWithTag:self.playerViewTag];
            } else {
                superview = self.containerView;
            }
            self.fullScreen = NO;
        }
        if (self.orientationWillChange) self.orientationWillChange(self, self.isFullScreen);
        self.view.frame = superview.bounds;
        [superview addSubview:self.view];
        [UIView animateWithDuration:animated?self.duration:0 animations:^{
            [self interfaceOrientation:orientation];
            self.view.frame = superview.bounds;
            [self.view layoutIfNeeded];
        } completion:^(BOOL finished) {
            if (self.orientationDidChanged) self.orientationDidChanged(self, self.isFullScreen);
        }];
        return;
    }
    
    if (UIInterfaceOrientationIsLandscape(orientation)) {
        superview = kWindow;
        if (!self.isFullScreen) { /// It's not set from the other side of the screen to this side
            self.view.frame = [self.view convertRect:self.view.frame toView:superview];
        }
        self.fullScreen = YES;
        /// 先加到window上，效果更好一些
        [superview addSubview:_view];
    } else {
        if (self.roateType == ZFRotateTypeCell) {
            superview = [self.cell viewWithTag:self.playerViewTag];
        } else {
            superview = self.containerView;
        }
        self.fullScreen = NO;
    }
    
    frame = [superview convertRect:superview.bounds toView:kWindow];
    _currentOrientation = orientation;
    
    [UIApplication sharedApplication].statusBarOrientation = orientation;
    /// 处理键盘
    NSInteger windowCount = [[[UIApplication sharedApplication] windows] count];
    if(windowCount > 1) {
        UIWindow *keyboardWindow = [[[UIApplication sharedApplication] windows] objectAtIndex:(windowCount-1)];
        if (UIInterfaceOrientationIsLandscape(orientation)) {
            keyboardWindow.bounds = CGRectMake(0, 0, MAX(ScreenHeight, ScreenWidth), MIN(ScreenHeight, ScreenWidth));
        } else {
            keyboardWindow.bounds = CGRectMake(0, 0, MIN(ScreenHeight, ScreenWidth), MAX(ScreenHeight, ScreenWidth));
        }
        keyboardWindow.transform = [self getTransformRotationAngle:orientation];
    }

    if (self.orientationWillChange) self.orientationWillChange(self, self.isFullScreen);
    [UIView animateWithDuration:animated?self.duration:0 animations:^{
        self.view.transform = [self getTransformRotationAngle:orientation];
        [UIView animateWithDuration:animated?self.duration:0 animations:^{
            self.view.frame = frame;
            [self.view layoutIfNeeded];
        }];
    } completion:^(BOOL finished) {
        [superview addSubview:self.view];
        self.view.frame = superview.bounds;
        if (self.orientationDidChanged) self.orientationDidChanged(self, self.isFullScreen);
    }];
}

/**
 *  强制屏幕转屏
 *
 *  @param orientation 屏幕方向
 */
- (void)interfaceOrientation:(UIInterfaceOrientation)orientation {
    if ([[UIDevice currentDevice] respondsToSelector:@selector(setOrientation:)]) {
        SEL selector = NSSelectorFromString(@"setOrientation:");
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[UIDevice instanceMethodSignatureForSelector:selector]];
        [invocation setSelector:selector];
        [invocation setTarget:[UIDevice currentDevice]];
        int val = orientation;
        [invocation setArgument:&val atIndex:2];
        [invocation invoke];
    }
}

- (BOOL)isNeedAdaptiveiOS8Rotation {
    NSArray<NSString *> *versionStrArr = [[UIDevice currentDevice].systemVersion componentsSeparatedByString:@"."];
    int firstVer = [[versionStrArr objectAtIndex:0] intValue];
    int secondVer = [[versionStrArr objectAtIndex:1] intValue];
    if (firstVer == 8) {
        if (secondVer >= 1 && secondVer <= 3) {
            return YES;
        }
    }
    return NO;
}

/// Gets the rotation Angle of the transformation.
- (CGAffineTransform)getTransformRotationAngle:(UIInterfaceOrientation)orientation {
    if (UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation) && orientation == UIInterfaceOrientationPortrait) {
        return CGAffineTransformIdentity;
    }
    if (orientation == UIInterfaceOrientationPortrait) {
        return CGAffineTransformIdentity;
    } else if (orientation == UIInterfaceOrientationLandscapeLeft){
        return CGAffineTransformMakeRotation(-M_PI_2);
    } else if(orientation == UIInterfaceOrientationLandscapeRight){
        return CGAffineTransformMakeRotation(M_PI_2);
    }
    return CGAffineTransformIdentity;
}

- (void)enterPortraitFullScreen:(BOOL)fullScreen animated:(BOOL)animated {
    if (self.fullScreenMode == ZFFullScreenModeLandscape) return;
    UIView *superview = nil;
    if (fullScreen) {
        superview = kWindow;
        self.view.frame = [self.view convertRect:self.view.frame toView:superview];
        [superview addSubview:self.view];
        self.fullScreen = YES;
        if (self.orientationWillChange) {
            self.orientationWillChange(self, self.isFullScreen);
        }
    } else {
        if (self.roateType == ZFRotateTypeCell) {
            superview = [self.cell viewWithTag:self.playerViewTag];
        } else {
            superview = self.containerView;
        }
        self.fullScreen = NO;
        if (self.orientationWillChange) {
            self.orientationWillChange(self, self.isFullScreen);
        }
    }
    CGRect frame = [superview convertRect:superview.bounds toView:kWindow];
    [UIView animateWithDuration:animated?self.duration:0 animations:^{
        self.view.frame = frame;
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {
        [superview addSubview:self.view];
        self.view.frame = superview.bounds;
        if (self.orientationDidChanged) {
            self.orientationDidChanged(self, self.isFullScreen);
        }
    }];
}

- (void)exitFullScreenWithAnimated:(BOOL)animated {
    if (self.fullScreenMode == ZFFullScreenModeLandscape) {
        [self enterLandscapeFullScreen:UIInterfaceOrientationPortrait animated:animated];
    } else if (self.fullScreenMode == ZFFullScreenModePortrait) {
        [self enterPortraitFullScreen:NO animated:animated];
    }
}

- (void)setLockedScreen:(BOOL)lockedScreen {
    _lockedScreen = lockedScreen;
    if (lockedScreen) {
        [self removeDeviceOrientationObserver];
    } else {
        [self addDeviceOrientationObserver];
    }
}

- (void)setFullScreen:(BOOL)fullScreen {
    _fullScreen = fullScreen;
    [[UIWindow zf_currentViewController] setNeedsStatusBarAppearanceUpdate];
}

- (void)setStatusBarHidden:(BOOL)statusBarHidden {
    _statusBarHidden = statusBarHidden;
    [[UIWindow zf_currentViewController] setNeedsStatusBarAppearanceUpdate];
}

@end

