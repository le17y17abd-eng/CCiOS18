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

// Connectivity layout: keep Apple's six real view controllers and their actions.
// Only their compact-mode frames are adjusted. Expanded mode remains 100% native.
@interface CCUIConnectivityModuleViewController : UIViewController
- (BOOL)isExpanded;
- (NSArray *)buttonViewControllers;
@end

static NSString *CCiOS18ConnectivityKind(UIViewController *controller) {
    NSString *name = NSStringFromClass([controller class]).lowercaseString;
    if ([name containsString:@"airdrop"]) return @"airdrop";
    if ([name containsString:@"airplane"]) return @"airplane";
    if ([name containsString:@"wifi"]) return @"wifi";
    if ([name containsString:@"cellulardata"]) return @"cellular";
    if ([name containsString:@"bluetooth"]) return @"bluetooth";
    if ([name containsString:@"hotspot"]) return @"hotspot";
    return nil;
}

static void CCiOS18ApplyConnectivityLayout(CCUIConnectivityModuleViewController *module) {
    if (!module || module.isExpanded) return;

    NSArray *controllers = [module buttonViewControllers];
    if (![controllers isKindOfClass:[NSArray class]] || controllers.count < 6) return;

    NSMutableDictionary *buttons = [NSMutableDictionary dictionary];
    for (id item in controllers) {
        if (![item isKindOfClass:[UIViewController class]]) continue;
        NSString *kind = CCiOS18ConnectivityKind((UIViewController *)item);
        if (kind && ((UIViewController *)item).view) buttons[kind] = ((UIViewController *)item).view;
    }

    // Fail closed: if this iOS build exposes a different controller set, leave Apple's layout untouched.
    NSArray *required = @[@"airplane", @"airdrop", @"wifi", @"cellular", @"bluetooth", @"hotspot"];
    for (NSString *kind in required) if (!buttons[kind]) return;

    UIView *host = module.view;
    CGRect bounds = host.bounds;
    CGFloat width = CGRectGetWidth(bounds);
    CGFloat height = CGRectGetHeight(bounds);
    if (width < 100.0 || height < 90.0) return;

    CGFloat side = MIN(width, height);
    CGFloat margin = MAX(4.0, side * 0.035);
    CGFloat columnGap = MAX(3.0, side * 0.025);
    CGFloat rowGap = MAX(4.0, side * 0.035);
    CGFloat largeHeight = (height - (margin * 2.0) - rowGap) * 0.61;
    CGFloat smallHeight = height - (margin * 2.0) - rowGap - largeHeight;
    CGFloat largeWidth = (width - (margin * 2.0) - (columnGap * 2.0)) / 3.0;
    CGFloat smallWidth = MIN(largeWidth * 0.72, (width - (margin * 2.0) - (columnGap * 2.0)) / 3.0);
    CGFloat smallGap = (width - (smallWidth * 3.0)) / 4.0;

    NSArray *largeKinds = @[@"airplane", @"airdrop", @"wifi"];
    for (NSUInteger index = 0; index < largeKinds.count; index++) {
        CGFloat x = margin + index * (largeWidth + columnGap);
        UIView *button = buttons[largeKinds[index]];
        button.hidden = NO;
        button.alpha = 1.0;
        button.frame = CGRectMake(x, margin, largeWidth, largeHeight);
    }

    NSArray *smallKinds = @[@"cellular", @"bluetooth", @"hotspot"];
    for (NSUInteger index = 0; index < smallKinds.count; index++) {
        CGFloat x = smallGap + index * (smallWidth + smallGap);
        UIView *button = buttons[smallKinds[index]];
        button.hidden = NO;
        button.alpha = 1.0;
        button.frame = CGRectMake(x, margin + largeHeight + rowGap, smallWidth, smallHeight);
    }
}

%group CCiOS18Connectivity

%hook CCUIConnectivityModuleViewController

- (void)viewDidLayoutSubviews {
    %orig;
    @try {
        // Apply after Apple's own Auto Layout pass; otherwise the native
        // connectivity layout immediately restores all six tiles to equal size.
        CCiOS18ApplyConnectivityLayout(self);
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
