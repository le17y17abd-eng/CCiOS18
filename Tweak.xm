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


// Native compact connectivity layout. Unlike CCAster's compact proxy cluster,
// this keeps Apple's six real child controllers visible and interactive.
static UIViewController *CCiOS18ConnectivityChild(UIViewController *parent, NSString *className) {
    NSMutableArray<UIViewController *> *queue = [NSMutableArray arrayWithArray:parent.childViewControllers ?: @[]];
    while (queue.count) {
        UIViewController *candidate = queue.firstObject;
        [queue removeObjectAtIndex:0];
        if ([NSStringFromClass(candidate.class) isEqualToString:className]) return candidate;
        [queue addObjectsFromArray:candidate.childViewControllers ?: @[]];
    }
    return nil;
}

static void CCiOS18PlaceSmallNativeControl(UIViewController *child, CGPoint center, CGSize targetSize) {
    UIView *view = child.view;
    if (!view || CGRectGetWidth(view.bounds) < 1.0 || CGRectGetHeight(view.bounds) < 1.0) return;
    view.transform = CGAffineTransformIdentity;
    CGFloat sx = targetSize.width / CGRectGetWidth(view.bounds);
    CGFloat sy = targetSize.height / CGRectGetHeight(view.bounds);
    CGFloat scale = MIN(sx, sy);
    view.transform = CGAffineTransformMakeScale(scale, scale);
    view.center = center;
    view.hidden = NO;
    view.alpha = 1.0;
    view.userInteractionEnabled = YES;
}

static void CCiOS18LayoutConnectivity(UIViewController *controller) {
    UIView *root = controller.view;
    if (!root) return;
    BOOL compact = CGRectGetWidth(root.bounds) < 190.0 && CGRectGetHeight(root.bounds) < 190.0;
    NSArray<NSString *> *names = @[
        @"CCUIConnectivityAirplaneViewController",
        @"CCUIConnectivityWifiViewController",
        @"CCUIConnectivityAirDropViewController",
        @"CCUIConnectivityCellularDataViewController",
        @"CCUIConnectivityBluetoothViewController",
        @"CCUIConnectivityHotspotViewController"
    ];
    NSMutableDictionary<NSString *, UIViewController *> *children = [NSMutableDictionary dictionary];
    for (NSString *name in names) {
        UIViewController *child = CCiOS18ConnectivityChild(controller, name);
        if (child) children[name] = child;
    }

    if (!compact) {
        // %orig has already laid out the expanded Apple interface.
        for (UIViewController *child in children.allValues) {
            child.view.transform = CGAffineTransformIdentity;
            child.view.hidden = NO;
            child.view.alpha = 1.0;
        }
        return;
    }

    CGFloat side = MIN(CGRectGetWidth(root.bounds), CGRectGetHeight(root.bounds));
    CGFloat inset = MAX(6.0, round(side * 0.085));
    CGFloat gap = MAX(4.0, round(side * 0.045));
    CGFloat cell = floor((side - inset * 2.0 - gap) * 0.5);
    CGFloat originX = round((CGRectGetWidth(root.bounds) - (cell * 2.0 + gap)) * 0.5);
    CGFloat originY = round((CGRectGetHeight(root.bounds) - (cell * 2.0 + gap)) * 0.5);

    CGRect airplane = CGRectMake(originX, originY, cell, cell);
    CGRect wifi = CGRectMake(originX + cell + gap, originY, cell, cell);
    CGRect airDrop = CGRectMake(originX, originY + cell + gap, cell, cell);
    CGRect miniArea = CGRectMake(originX + cell + gap, originY + cell + gap, cell, cell);

    NSDictionary<NSString *, NSValue *> *largeFrames = @{
        @"CCUIConnectivityAirplaneViewController": [NSValue valueWithCGRect:airplane],
        @"CCUIConnectivityWifiViewController": [NSValue valueWithCGRect:wifi],
        @"CCUIConnectivityAirDropViewController": [NSValue valueWithCGRect:airDrop]
    };
    [UIView performWithoutAnimation:^{
        [largeFrames enumerateKeysAndObjectsUsingBlock:^(NSString *name, NSValue *value, __unused BOOL *stop) {
            UIView *view = children[name].view;
            if (!view) return;
            view.transform = CGAffineTransformIdentity;
            view.frame = value.CGRectValue;
            view.hidden = NO;
            view.alpha = 1.0;
            view.userInteractionEnabled = YES;
        }];

        CGFloat mini = floor(cell * 0.43);
        CGFloat topY = CGRectGetMinY(miniArea) + cell * 0.28;
        CGFloat bottomY = CGRectGetMinY(miniArea) + cell * 0.73;
        CGFloat leftX = CGRectGetMinX(miniArea) + cell * 0.28;
        CGFloat rightX = CGRectGetMinX(miniArea) + cell * 0.72;
        CCiOS18PlaceSmallNativeControl(children[@"CCUIConnectivityCellularDataViewController"],
                                       CGPointMake(leftX, topY), CGSizeMake(mini, mini));
        CCiOS18PlaceSmallNativeControl(children[@"CCUIConnectivityBluetoothViewController"],
                                       CGPointMake(rightX, topY), CGSizeMake(mini, mini));
        CCiOS18PlaceSmallNativeControl(children[@"CCUIConnectivityHotspotViewController"],
                                       CGPointMake(CGRectGetMidX(miniArea), bottomY), CGSizeMake(mini, mini));
    }];
}

%hook CCUIConnectivityModuleViewController

- (void)viewDidLayoutSubviews {
    %orig;
    @try {
        UIViewController *controller = (UIViewController *)(id)self;
        CCiOS18LayoutConnectivity(controller);
        static const void *kCCiOS18ConnectivityDeferredKey = &kCCiOS18ConnectivityDeferredKey;
        BOOL compact = CGRectGetWidth(controller.view.bounds) < 190.0 &&
                       CGRectGetHeight(controller.view.bounds) < 190.0;
        if (compact && ![objc_getAssociatedObject(controller, kCCiOS18ConnectivityDeferredKey) boolValue]) {
            objc_setAssociatedObject(controller, kCCiOS18ConnectivityDeferredKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            __weak UIViewController *weakController = controller;
            dispatch_async(dispatch_get_main_queue(), ^{
                UIViewController *strongController = weakController;
                if (!strongController) return;
                objc_setAssociatedObject(strongController, kCCiOS18ConnectivityDeferredKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                CCiOS18LayoutConnectivity(strongController);
            });
        }
    } @catch (NSException *exception) {
        NSLog(@"[CCiOS18] Connectivity layout exception: %@", exception);
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
