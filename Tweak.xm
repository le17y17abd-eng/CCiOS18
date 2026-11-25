#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <math.h>

// CCiOS18 0.3.0 — native iOS 15 Control Center restyle.
// All controls remain Apple's original views; no replacement buttons are inserted.

static const NSInteger kCCiOS18BackdropTag = 180018;
static const void *kCCiOS18ContainerStyleKey = &kCCiOS18ContainerStyleKey;

static BOOL CCiOS18ClassContains(UIView *view, NSString *part) {
    return view && [NSStringFromClass(view.class) rangeOfString:part options:NSCaseInsensitiveSearch].location != NSNotFound;
}

static BOOL CCiOS18TreeContainsClassPart(UIView *view, NSString *part) {
    if (!view) return NO;
    if (CCiOS18ClassContains(view, part)) return YES;
    for (UIView *child in view.subviews) {
        if (CCiOS18TreeContainsClassPart(child, part)) return YES;
    }
    return NO;
}

static void CCiOS18InstallBackdrop(UIView *root) {
    if (!root || CGRectIsEmpty(root.bounds)) return;

    UIVisualEffectView *backdrop = (UIVisualEffectView *)[root viewWithTag:kCCiOS18BackdropTag];
    if (!backdrop) {
        UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterialDark];
        backdrop = [[UIVisualEffectView alloc] initWithEffect:effect];
        backdrop.tag = kCCiOS18BackdropTag;
        backdrop.userInteractionEnabled = NO;
        backdrop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [root insertSubview:backdrop atIndex:0];

        UIView *tint = [[UIView alloc] initWithFrame:backdrop.bounds];
        tint.tag = kCCiOS18BackdropTag + 1;
        tint.backgroundColor = [UIColor colorWithWhite:0.025 alpha:0.12];
        tint.userInteractionEnabled = NO;
        tint.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [backdrop.contentView addSubview:tint];
    }
    backdrop.frame = root.bounds;
    backdrop.alpha = 1.0;
}

static CGFloat CCiOS18RadiusForContainer(UIView *view, BOOL hasSlider) {
    CGFloat w = CGRectGetWidth(view.bounds);
    CGFloat h = CGRectGetHeight(view.bounds);
    CGFloat minSide = MIN(w, h);
    if (minSide <= 0) return 18.0;

    if (hasSlider) return minSide * 0.5;

    // Keep small native controls circular, and use continuous card corners for larger modules.
    if (w < 100.0 && h < 100.0 && fabs(w - h) < 8.0) return minSide * 0.5;
    if (w > 150.0 && h > 150.0) return MIN(30.0, minSide * 0.24);
    return MIN(24.0, minSide * 0.27);
}

static void CCiOS18StyleSliderViews(UIView *container) {
    for (UIView *view in container.subviews) {
        BOOL continuous = CCiOS18ClassContains(view, @"CCUIContinuousSliderView");
        BOOL stepped = CCiOS18ClassContains(view, @"CCUISteppedSliderView");
        BOOL material = CCiOS18ClassContains(view, @"MTMaterialView");

        if (continuous || stepped || material) {
            CGFloat radius = MIN(CGRectGetWidth(view.bounds), CGRectGetHeight(view.bounds)) * 0.5;
            if (radius > 0) {
                view.layer.cornerRadius = radius;
                if (@available(iOS 13.0, *)) view.layer.cornerCurve = kCACornerCurveContinuous;
                view.clipsToBounds = YES;
            }
        }
        CCiOS18StyleSliderViews(view);
    }
}

%hook CCUIContentModuleContentContainerView

- (void)layoutSubviews {
    %orig;

    @try {
        BOOL hasSlider = CCiOS18TreeContainsClassPart(self, @"CCUIContinuousSliderView") ||
                         CCiOS18TreeContainsClassPart(self, @"CCUISteppedSliderView");
        CGFloat radius = CCiOS18RadiusForContainer(self, hasSlider);

        self.layer.cornerRadius = radius;
        if (@available(iOS 13.0, *)) self.layer.cornerCurve = kCACornerCurveContinuous;
        self.layer.borderWidth = 0.8;
        self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.19].CGColor;
        self.layer.masksToBounds = YES;
        self.clipsToBounds = YES;

        // Subtle translucent surface, while retaining the native module's content and actions.
        if (!self.backgroundColor || CGColorGetAlpha(self.backgroundColor.CGColor) > 0.85) {
            self.backgroundColor = [UIColor colorWithWhite:0.16 alpha:0.18];
        }
        CCiOS18StyleSliderViews(self);
    } @catch (NSException *exception) {
        NSLog(@"[CCiOS18] Module styling exception: %@", exception);
    }
}

%end

%hook CCUIModularControlCenterOverlayViewController

- (void)viewDidLayoutSubviews {
    %orig;
    @try {
        CCiOS18InstallBackdrop(self.view);
    } @catch (NSException *exception) {
        NSLog(@"[CCiOS18] Backdrop exception: %@", exception);
    }
}

%end
