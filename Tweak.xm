#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <math.h>

// CCiOS18 — iOS 15 native Control Center visual layer.
// Original Apple modules and their actions are retained.

static const NSInteger kCCiOS18BackdropTag = 180018;

static BOOL CCiOS18ClassContains(id object, NSString *part) {
    if (!object) return NO;
    return [NSStringFromClass([object class]) rangeOfString:part options:NSCaseInsensitiveSearch].location != NSNotFound;
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
        backdrop = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterialDark]];
        backdrop.tag = kCCiOS18BackdropTag;
        backdrop.userInteractionEnabled = NO;
        backdrop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [root insertSubview:backdrop atIndex:0];

        UIView *tint = [[UIView alloc] initWithFrame:backdrop.bounds];
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
    if (w < 100.0 && h < 100.0 && fabs(w - h) < 8.0) return minSide * 0.5;
    if (w > 150.0 && h > 150.0) return MIN(30.0, minSide * 0.24);
    return MIN(24.0, minSide * 0.27);
}

static void CCiOS18StyleSliderViews(UIView *container) {
    for (UIView *view in container.subviews) {
        BOOL slider = CCiOS18ClassContains(view, @"CCUIContinuousSliderView") ||
                      CCiOS18ClassContains(view, @"CCUISteppedSliderView");
        BOOL material = CCiOS18ClassContains(view, @"MTMaterialView");
        if (slider || material) {
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
        UIView *container = (UIView *)self;
        BOOL hasSlider = CCiOS18TreeContainsClassPart(container, @"CCUIContinuousSliderView") ||
                         CCiOS18TreeContainsClassPart(container, @"CCUISteppedSliderView");
        CGFloat radius = CCiOS18RadiusForContainer(container, hasSlider);

        container.layer.cornerRadius = radius;
        if (@available(iOS 13.0, *)) container.layer.cornerCurve = kCACornerCurveContinuous;
        container.layer.borderWidth = 0.8;
        container.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.19].CGColor;
        container.layer.masksToBounds = YES;
        container.clipsToBounds = YES;

        UIColor *currentBackground = container.backgroundColor;
        if (!currentBackground || CGColorGetAlpha(currentBackground.CGColor) > 0.85) {
            container.backgroundColor = [UIColor colorWithWhite:0.16 alpha:0.18];
        }
        CCiOS18StyleSliderViews(container);
    } @catch (NSException *exception) {
        NSLog(@"[CCiOS18] Module styling exception: %@", exception);
    }
}

%end

%hook CCUIModularControlCenterOverlayViewController

- (void)viewDidLayoutSubviews {
    %orig;
    @try {
        CCiOS18InstallBackdrop([(UIViewController *)self view]);
    } @catch (NSException *exception) {
        NSLog(@"[CCiOS18] Backdrop exception: %@", exception);
    }
}

%end

// iOS 15 ConnectivityModule exposes the six native controllers as named
// properties and keeps separate portrait/landscape controller arrays.
// Use those native objects directly; never create replacement buttons.
@interface CCUIConnectivityModuleViewController : UIViewController
- (BOOL)isExpanded;
- (BOOL)_isPortrait;
- (NSArray *)portraitButtonViewControllers;
- (NSArray *)landscapeButtonViewControllers;
- (UIViewController *)airplaneButton;
- (UIViewController *)airDropButton;
- (UIViewController *)wifiButton;
- (UIViewController *)cellularDataButton;
- (UIViewController *)bluetoothButton;
- (UIViewController *)hotspotButton;
@end

static void CCiOS18PlaceNativeButton(UIView *host, UIView *button, CGRect hostFrame) {
    if (!host || !button || !button.superview) return;
    UIView *parent = button.superview;
    CGRect frame = (parent == host) ? hostFrame : [host convertRect:hostFrame toView:parent];
    button.hidden = NO;
    button.alpha = 1.0;
    button.frame = frame;
}

static void CCiOS18ApplyNativeConnectivityLayout(CCUIConnectivityModuleViewController *module) {
    if (!module || [module isExpanded]) return;

    UIView *host = module.view;
    if (!host || CGRectIsEmpty(host.bounds)) return;

    // Confirm the native compact-mode array is ready before changing geometry.
    NSArray *nativeOrder = [module _isPortrait] ? [module portraitButtonViewControllers]
                                                : [module landscapeButtonViewControllers];
    if (![nativeOrder isKindOfClass:[NSArray class]] || nativeOrder.count < 6) return;

    UIViewController *airplane = [module airplaneButton];
    UIViewController *airdrop = [module airDropButton];
    UIViewController *wifi = [module wifiButton];
    UIViewController *cellular = [module cellularDataButton];
    UIViewController *bluetooth = [module bluetoothButton];
    UIViewController *hotspot = [module hotspotButton];

    NSArray *nativeButtons = @[airplane ?: (id)[NSNull null],
                               airdrop ?: (id)[NSNull null],
                               wifi ?: (id)[NSNull null],
                               cellular ?: (id)[NSNull null],
                               bluetooth ?: (id)[NSNull null],
                               hotspot ?: (id)[NSNull null]];
    for (id item in nativeButtons) {
        if (item == [NSNull null] || ![nativeOrder containsObject:item]) return;
    }

    CGFloat width = CGRectGetWidth(host.bounds);
    CGFloat height = CGRectGetHeight(host.bounds);
    if (width < 100.0 || height < 90.0) return;

    CGFloat margin = MAX(4.0, MIN(width, height) * 0.035);
    CGFloat columnGap = MAX(4.0, width * 0.025);
    CGFloat rowGap = MAX(4.0, height * 0.035);
    CGFloat usableWidth = width - 2.0 * margin;
    CGFloat largeWidth = (usableWidth - 2.0 * columnGap) / 3.0;
    CGFloat usableHeight = height - 2.0 * margin - rowGap;
    CGFloat largeHeight = usableHeight * 0.60;
    CGFloat smallHeight = usableHeight - largeHeight;
    CGFloat smallWidth = largeWidth * 0.72;
    CGFloat smallGap = (width - 3.0 * smallWidth) / 4.0;

    NSArray *largeButtons = @[airplane, airdrop, wifi];
    for (NSUInteger i = 0; i < largeButtons.count; i++) {
        CGFloat x = margin + i * (largeWidth + columnGap);
        CGRect frame = CGRectMake(x, margin, largeWidth, largeHeight);
        CCiOS18PlaceNativeButton(host, ((UIViewController *)largeButtons[i]).view, frame);
    }

    NSArray *smallButtons = @[cellular, bluetooth, hotspot];
    for (NSUInteger i = 0; i < smallButtons.count; i++) {
        CGFloat x = smallGap + i * (smallWidth + smallGap);
        CGRect frame = CGRectMake(x, margin + largeHeight + rowGap, smallWidth, smallHeight);
        CCiOS18PlaceNativeButton(host, ((UIViewController *)smallButtons[i]).view, frame);
    }
}

%group CCiOS18Connectivity

%hook CCUIConnectivityModuleViewController

- (void)viewWillLayoutSubviews {
    %orig;
    @try {
        // Apple's native compact layout is complete here. Apply to its actual
        // six named button controllers, in the same lifecycle used by
        // established Control Center layout tweaks.
        CCiOS18ApplyNativeConnectivityLayout(self);
    } @catch (NSException *exception) {
        NSLog(@"[CCiOS18] Connectivity layout exception: %@", exception);
    }
}

%end
%end

static void CCiOS18BundleDidLoad(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    NSDictionary *info = (__bridge NSDictionary *)userInfo;
    NSArray *classes = info[NSLoadedClasses];
    if ([classes containsObject:@"CCUIConnectivityModuleViewController"]) {
        %init(CCiOS18Connectivity);
    }
}

%ctor {
    CFNotificationCenterAddObserver(CFNotificationCenterGetLocalCenter(),
                                    NULL,
                                    CCiOS18BundleDidLoad,
                                    (CFStringRef)NSBundleDidLoadNotification,
                                    NULL,
                                    CFNotificationSuspensionBehaviorCoalesce);
    %init;
}
