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

// iOS 15 ConnectivityModule private interface.
// All six controllers remain Apple's original controllers.
@interface CCUIConnectivityModuleViewController : UIViewController
- (BOOL)isExpanded;
- (BOOL)_isPortrait;
- (NSArray *)portraitButtonViewControllers;
- (UIViewController *)airplaneButton;
- (UIViewController *)wifiButton;
- (UIViewController *)airDropButton;
- (UIViewController *)cellularDataButton;
- (UIViewController *)bluetoothButton;
- (UIViewController *)hotspotButton;
@end

static void CCiOS18PlaceConnectivityButton(UIViewController *controller, UIView *moduleView, CGRect frame) {
    if (!controller || !moduleView) return;
    UIView *buttonView = controller.view;
    UIView *parent = buttonView.superview;
    if (!buttonView || !parent) return;

    // Convert from module coordinates so Apple's scroll/container hierarchy is respected.
    buttonView.frame = [moduleView convertRect:frame toView:parent];
    buttonView.hidden = NO;
    buttonView.alpha = 1.0;
}

%group CCiOS18Connectivity

%hook CCUIConnectivityModuleViewController

- (void)viewWillLayoutSubviews {
    %orig;
    @try {
        // Keep Apple's expanded view and long-press menu completely untouched.
        if ([self isExpanded]) return;
        if (![self _isPortrait]) return;

        SEL selectors[] = {
            @selector(portraitButtonViewControllers),
            @selector(airplaneButton),
            @selector(wifiButton),
            @selector(airDropButton),
            @selector(cellularDataButton),
            @selector(bluetoothButton),
            @selector(hotspotButton)
        };
        for (NSUInteger i = 0; i < sizeof(selectors) / sizeof(SEL); i++) {
            if (![self respondsToSelector:selectors[i]]) return;
        }

        NSArray *portraitButtons = [self portraitButtonViewControllers];
        UIViewController *airplane = [self airplaneButton];
        UIViewController *wifi = [self wifiButton];
        UIViewController *airDrop = [self airDropButton];
        UIViewController *cellular = [self cellularDataButton];
        UIViewController *bluetooth = [self bluetoothButton];
        UIViewController *hotspot = [self hotspotButton];

        if (!portraitButtons || portraitButtons.count < 6 ||
            !airplane || !wifi || !airDrop || !cellular || !bluetooth || !hotspot) return;

        // Do not rearrange anything unless all six native Apple controllers belong to this module.
        NSArray *nativeButtons = @[airplane, wifi, airDrop, cellular, bluetooth, hotspot];
        for (UIViewController *button in nativeButtons) {
            if (![portraitButtons containsObject:button]) return;
        }

        UIView *moduleView = self.view;
        CGRect bounds = moduleView.bounds;
        CGFloat width = CGRectGetWidth(bounds);
        CGFloat height = CGRectGetHeight(bounds);
        if (width < 100.0 || height < 100.0) return;

        CGFloat inset = 4.0;
        CGFloat gap = 4.0;
        CGFloat cellWidth = (width - (2.0 * inset) - gap) / 2.0;
        CGFloat cellHeight = (height - (2.0 * inset) - gap) / 2.0;
        if (cellWidth < 24.0 || cellHeight < 24.0) return;

        CGFloat leftX = CGRectGetMinX(bounds) + inset;
        CGFloat rightX = leftX + cellWidth + gap;
        CGFloat topY = CGRectGetMinY(bounds) + inset;
        CGFloat bottomY = topY + cellHeight + gap;

        // iOS 18-inspired four-cell composition:
        // top-left Airplane, top-right Wi-Fi, bottom-left AirDrop.
        CCiOS18PlaceConnectivityButton(airplane, moduleView,
            CGRectMake(leftX, topY, cellWidth, cellHeight));
        CCiOS18PlaceConnectivityButton(wifi, moduleView,
            CGRectMake(rightX, topY, cellWidth, cellHeight));
        CCiOS18PlaceConnectivityButton(airDrop, moduleView,
            CGRectMake(leftX, bottomY, cellWidth, cellHeight));

        // Bottom-right cell: Cellular + Bluetooth on the first row,
        // Personal Hotspot centered underneath.
        CGFloat miniGap = 3.0;
        CGFloat miniWidth = (cellWidth - miniGap) / 2.0;
        CGFloat miniHeight = (cellHeight - miniGap) / 2.0;
        CGFloat miniBottomY = bottomY + miniHeight + miniGap;
        CGFloat centeredMiniX = rightX + (cellWidth - miniWidth) / 2.0;

        CCiOS18PlaceConnectivityButton(cellular, moduleView,
            CGRectMake(rightX, bottomY, miniWidth, miniHeight));
        CCiOS18PlaceConnectivityButton(bluetooth, moduleView,
            CGRectMake(rightX + miniWidth + miniGap, bottomY, miniWidth, miniHeight));
        CCiOS18PlaceConnectivityButton(hotspot, moduleView,
            CGRectMake(centeredMiniX, miniBottomY, miniWidth, miniHeight));

    } @catch (NSException *exception) {
        NSLog(@"[CCiOS18] Native connectivity layout exception: %@", exception);
    }
}

%end
%end

static void CCiOS18InstallConnectivityHooks(void) {
    static BOOL installed = NO;
    if (installed) return;
    if (!NSClassFromString(@"CCUIConnectivityModuleViewController")) return;
    installed = YES;
    %init(CCiOS18Connectivity);
}

static void CCiOS18ConnectivityBundleLoaded(CFNotificationCenterRef center, void *observer,
                                             CFStringRef name, const void *object,
                                             CFDictionaryRef userInfo) {
    NSDictionary *info = (__bridge NSDictionary *)userInfo;
    NSArray *loadedClasses = info[@"NSLoadedClasses"];
    if ([loadedClasses containsObject:@"CCUIConnectivityModuleViewController"]) {
        CCiOS18InstallConnectivityHooks();
    }
}

%ctor {
    CCiOS18InstallConnectivityHooks();
    CFNotificationCenterAddObserver(CFNotificationCenterGetLocalCenter(), NULL,
        CCiOS18ConnectivityBundleLoaded, (CFStringRef)NSBundleDidLoadNotification,
        NULL, CFNotificationSuspensionBehaviorCoalesce);
}
