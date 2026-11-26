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


/* CCAster compact connectivity transplant.
 * Original Apple child controls are used for airplane and Wi-Fi.
 * AirDrop and Bluetooth use CCAster's snapshot proxies and forward taps to
 * the original CCUIRoundButton controls. The mini cluster and expansion
 * control follow CCAster's source implementation.
 */
static BOOL gCCAEnabled = YES;
static BOOL gCCAEditModeActive = NO;

static NSInteger const kCCAConnectivityMiniClusterTag = 181032;
static NSInteger const kCCAConnectivityExpandButtonTag = 181033;
static NSInteger const kCCAConnectivityCompactAirDropTag = 181034;
static NSInteger const kCCAConnectivityCompactBluetoothTag = 181035;
static const void *kCCAConnectivityForwardControlKey = &kCCAConnectivityForwardControlKey;
static const void *kCCAConnectivityProxyPreparedKey = &kCCAConnectivityProxyPreparedKey;
static const void *kCCAConnectivityProxyRefreshScheduledKey = &kCCAConnectivityProxyRefreshScheduledKey;

static UIView *CCAFindSubviewWithClassName(UIView *root, NSString *className) {
    if (!root) return nil;
    if ([NSStringFromClass(root.class) isEqualToString:className]) return root;
    for (UIView *subview in root.subviews) {
        UIView *match = CCAFindSubviewWithClassName(subview, className);
        if (match) return match;
    }
    return nil;
}



static UIViewController *CCAConnectivityChild(UIViewController *controller, NSString *className) {
    NSMutableArray<UIViewController *> *queue = [NSMutableArray arrayWithArray:controller.childViewControllers];
    while (queue.count) {
        UIViewController *candidate = queue.firstObject;
        [queue removeObjectAtIndex:0];
        if ([NSStringFromClass(candidate.class) isEqualToString:className]) return candidate;
        [queue addObjectsFromArray:candidate.childViewControllers];
    }
    return nil;
}

static UIImage *CCAConnectivityControlSnapshot(UIViewController *child, CGSize targetSize) {
    if (!child.view || targetSize.width < 1.0 || targetSize.height < 1.0) return nil;
    if (![objc_getAssociatedObject(child, kCCAConnectivityProxyPreparedKey) boolValue]) {
        [child beginAppearanceTransition:YES animated:NO];
        [child endAppearanceTransition];
        objc_setAssociatedObject(child, kCCAConnectivityProxyPreparedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    BOOL childWasHidden = child.view.hidden;
    CGFloat childAlpha = child.view.alpha;
    child.view.hidden = NO;
    child.view.alpha = 1.0;
    [child.view setNeedsLayout];
    [child.view layoutIfNeeded];
    UIView *roundButton = CCAFindSubviewWithClassName(child.view, @"CCUIRoundButton");
    if (!roundButton) {
        child.view.hidden = childWasHidden;
        child.view.alpha = childAlpha;
        return nil;
    }
    CGSize sourceSize = roundButton.bounds.size;
    if (sourceSize.width < 1.0 || sourceSize.height < 1.0) sourceSize = roundButton.frame.size;
    if (sourceSize.width < 1.0 || sourceSize.height < 1.0) {
        child.view.hidden = childWasHidden;
        child.view.alpha = childAlpha;
        return nil;
    }
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.opaque = NO;
    format.scale = UIScreen.mainScreen.scale;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:targetSize format:format];
    UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        CGContextSaveGState(context.CGContext);
        CGContextScaleCTM(context.CGContext, targetSize.width / sourceSize.width, targetSize.height / sourceSize.height);
        BOOL drawn = [roundButton drawViewHierarchyInRect:(CGRect){CGPointZero, sourceSize} afterScreenUpdates:YES];
        if (!drawn) [roundButton.layer renderInContext:context.CGContext];
        CGContextRestoreGState(context.CGContext);
    }];
    child.view.hidden = childWasHidden;
    child.view.alpha = childAlpha;
    return image;
}

static UIButton *CCAConnectivitySnapshotProxy(UIView *root, NSInteger tag, CGRect frame, UIViewController *child) {
    UIButton *proxy = (UIButton *)[root viewWithTag:tag];
    if (!proxy) {
        proxy = [UIButton buttonWithType:UIButtonTypeCustom];
        proxy.tag = tag;
        proxy.imageView.contentMode = UIViewContentModeScaleAspectFit;
        [proxy addTarget:[CCiOS18ConnectivityCoordinator shared] action:@selector(connectivityProxyTapped:) forControlEvents:UIControlEventTouchUpInside];
        [root addSubview:proxy];
    }
    UIView *roundButton = CCAFindSubviewWithClassName(child.view, @"CCUIRoundButton");
    if ([roundButton isKindOfClass:[UIControl class]]) objc_setAssociatedObject(proxy, kCCAConnectivityForwardControlKey, roundButton, OBJC_ASSOCIATION_ASSIGN);
    proxy.frame = frame;
    proxy.hidden = NO;
    proxy.clipsToBounds = NO;
    if (tag == kCCAConnectivityCompactAirDropTag) {
        CFPropertyListRef rawMode = CFPreferencesCopyAppValue(CFSTR("DiscoverableMode"), CFSTR("com.apple.sharingd"));
        NSString *mode = CFBridgingRelease(rawMode);
        BOOL receiving = mode.length && [mode rangeOfString:@"Off" options:NSCaseInsensitiveSearch].location == NSNotFound;
        proxy.backgroundColor = receiving ? [UIColor colorWithRed:0.61 green:0.14 blue:0.96 alpha:1.0]
                                          : [UIColor colorWithWhite:1.0 alpha:0.14];
        proxy.layer.cornerRadius = CGRectGetHeight(frame) * 0.5;
        proxy.layer.cornerCurve = kCACornerCurveContinuous;
        proxy.layer.masksToBounds = YES;
    }
    UIImage *snapshot = CCAConnectivityControlSnapshot(child, frame.size);
    if (snapshot) [proxy setImage:snapshot forState:UIControlStateNormal];
    if (tag == kCCAConnectivityCompactAirDropTag) {
        UIView *roundButton = CCAFindSubviewWithClassName(child.view, @"CCUIRoundButton");
        NSMutableArray<UIView *> *queue = roundButton ? [NSMutableArray arrayWithObject:roundButton] : [NSMutableArray array];
        UIImage *glyph = nil;
        while (queue.count && !glyph) {
            UIView *candidate = queue.firstObject;
            [queue removeObjectAtIndex:0];
            if ([candidate isKindOfClass:[UIImageView class]] && ((UIImageView *)candidate).image && candidate.alpha > 0.01 && !candidate.hidden) {
                glyph = ((UIImageView *)candidate).image;
                break;
            }
            [queue addObjectsFromArray:candidate.subviews];
        }
        if (glyph) {
            [proxy setImage:[glyph imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
            proxy.tintColor = UIColor.whiteColor;
            proxy.imageView.contentMode = UIViewContentModeScaleAspectFit;
            proxy.imageView.transform = CGAffineTransformMakeScale(0.56, 0.56);
        }
    }
    return proxy;
}

static UIButton *CCAConnectivitySnapshotProxy(UIView *root, NSInteger tag, CGRect frame, UIViewController *child) {
    UIButton *proxy = (UIButton *)[root viewWithTag:tag];
    if (!proxy) {
        proxy = [UIButton buttonWithType:UIButtonTypeCustom];
        proxy.tag = tag;
        proxy.imageView.contentMode = UIViewContentModeScaleAspectFit;
        [proxy addTarget:[CCiOS18ConnectivityCoordinator shared] action:@selector(connectivityProxyTapped:) forControlEvents:UIControlEventTouchUpInside];
        [root addSubview:proxy];
    }
    UIView *roundButton = CCAFindSubviewWithClassName(child.view, @"CCUIRoundButton");
    if ([roundButton isKindOfClass:[UIControl class]]) objc_setAssociatedObject(proxy, kCCAConnectivityForwardControlKey, roundButton, OBJC_ASSOCIATION_ASSIGN);
    proxy.frame = frame;
    proxy.hidden = NO;
    proxy.clipsToBounds = NO;
    if (tag == kCCAConnectivityCompactAirDropTag) {
        CFPropertyListRef rawMode = CFPreferencesCopyAppValue(CFSTR("DiscoverableMode"), CFSTR("com.apple.sharingd"));
        NSString *mode = CFBridgingRelease(rawMode);
        BOOL receiving = mode.length && [mode rangeOfString:@"Off" options:NSCaseInsensitiveSearch].location == NSNotFound;
        proxy.backgroundColor = receiving ? [UIColor colorWithRed:0.61 green:0.14 blue:0.96 alpha:1.0]
                                          : [UIColor colorWithWhite:1.0 alpha:0.14];
        proxy.layer.cornerRadius = CGRectGetHeight(frame) * 0.5;
        proxy.layer.cornerCurve = kCACornerCurveContinuous;
        proxy.layer.masksToBounds = YES;
    }
    UIImage *snapshot = CCAConnectivityControlSnapshot(child, frame.size);
    if (snapshot) [proxy setImage:snapshot forState:UIControlStateNormal];
    if (tag == kCCAConnectivityCompactAirDropTag) {
        UIView *roundButton = CCAFindSubviewWithClassName(child.view, @"CCUIRoundButton");
        NSMutableArray<UIView *> *queue = roundButton ? [NSMutableArray arrayWithObject:roundButton] : [NSMutableArray array];
        UIImage *glyph = nil;
        while (queue.count && !glyph) {
            UIView *candidate = queue.firstObject;
            [queue removeObjectAtIndex:0];
            if ([candidate isKindOfClass:[UIImageView class]] && ((UIImageView *)candidate).image && candidate.alpha > 0.01 && !candidate.hidden) {
                glyph = ((UIImageView *)candidate).image;
                break;
            }
            [queue addObjectsFromArray:candidate.subviews];
        }
        if (glyph) {
            [proxy setImage:[glyph imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
            proxy.tintColor = UIColor.whiteColor;
            proxy.imageView.contentMode = UIViewContentModeScaleAspectFit;
            proxy.imageView.transform = CGAffineTransformMakeScale(0.56, 0.56);
        }
    }
    return proxy;
}

typedef struct {
    CGFloat inset;
    CGFloat gap;
    CGFloat cell;
    CGRect topLeft;
    CGRect topRight;
    CGRect bottomLeft;
    CGRect bottomRight;
} CCAConnectivityCompactMetrics;

static CCAConnectivityCompactMetrics CCAConnectivityCompactMetricsForBounds(CGRect bounds) {
    CGFloat side = MIN(CGRectGetWidth(bounds), CGRectGetHeight(bounds));
    CGFloat inset = MAX(6.0, round(side * 0.103));
    CGFloat gap = MAX(4.0, round(side * 0.055));
    CGFloat cell = floor((side - inset * 2.0 - gap) * 0.5);
    CGFloat originX = round((CGRectGetWidth(bounds) - (cell * 2.0 + gap)) * 0.5);
    CGFloat originY = round((CGRectGetHeight(bounds) - (cell * 2.0 + gap)) * 0.5);
    CGRect topLeft = CGRectMake(originX, originY, cell, cell);
    CGRect topRight = CGRectMake(originX + cell + gap, originY, cell, cell);
    CGRect bottomLeft = CGRectMake(originX, originY + cell + gap, cell, cell);
    CGRect bottomRight = CGRectMake(originX + cell + gap, originY + cell + gap, cell, cell);
    return (CCAConnectivityCompactMetrics){inset, gap, cell, topLeft, topRight, bottomLeft, bottomRight};
}


@implementation CCiOS18ConnectivityCoordinator
+ (instancetype)shared {
    static CCiOS18ConnectivityCoordinator *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [CCiOS18ConnectivityCoordinator new]; });
    return instance;
}
- (void)expandConnectivityFromMiniCluster:(UIButton *)sender {
    if (!gCCAEnabled || gCCAEditModeActive) return;
    UIViewController *overlay = sender.window.rootViewController;
    while (overlay.presentedViewController) overlay = overlay.presentedViewController;
    SEL expand = NSSelectorFromString(@"expandModuleWithIdentifier:");
    UIViewController *collection = overlay;
    for (UIViewController *candidate = overlay; candidate; candidate = candidate.parentViewController) {
        if ([candidate respondsToSelector:expand]) { collection = candidate; break; }
    }
    if (![collection respondsToSelector:expand]) {
        NSMutableArray *queue = [NSMutableArray arrayWithArray:overlay.childViewControllers ?: @[]];
        while (queue.count) {
            UIViewController *candidate = queue.firstObject;
            [queue removeObjectAtIndex:0];
            if ([candidate respondsToSelector:expand]) { collection = candidate; break; }
            [queue addObjectsFromArray:candidate.childViewControllers ?: @[]];
        }
    }
    if (![collection respondsToSelector:expand]) return;
    ((void (*)(id, SEL, id))objc_msgSend)(collection, expand, @"com.apple.control-center.ConnectivityModule");
}
- (void)connectivityProxyTapped:(UIControl *)sender {
    UIControl *nativeControl = objc_getAssociatedObject(sender, kCCAConnectivityForwardControlKey);
    if (nativeControl) [nativeControl sendActionsForControlEvents:UIControlEventTouchUpInside];
}
@end

@interface CCiOS18ConnectivityCoordinator : NSObject
+ (instancetype)shared;
- (void)expandConnectivityFromMiniCluster:(UIButton *)sender;
- (void)connectivityProxyTapped:(UIControl *)sender;
@end

static void CCAConfigureConnectivityLayout(UIViewController *controller) {
    if (!gCCAEnabled || !controller.view) return;
    UIView *root = controller.view;
    NSArray<NSString *> *classes = @[
        @"CCUIConnectivityAirplaneViewController", @"CCUIConnectivityCellularDataViewController",
        @"CCUIConnectivityWifiViewController", @"CCUIConnectivityBluetoothViewController",
        @"CCUIConnectivityAirDropViewController", @"CCUIConnectivityHotspotViewController"
    ];
    NSMutableDictionary<NSString *, UIViewController *> *children = [NSMutableDictionary dictionary];
    for (NSString *name in classes) {
        UIViewController *child = CCAConnectivityChild(controller, name);
        if (child) children[name] = child;
    }
    BOOL compact = CGRectGetWidth(root.bounds) < 190.0 && CGRectGetHeight(root.bounds) < 190.0;
    UIButton *expand = (UIButton *)[root viewWithTag:kCCAConnectivityExpandButtonTag];
    UIView *miniCluster = [root viewWithTag:kCCAConnectivityMiniClusterTag];
    if (!compact) {
        [UIView performWithoutAnimation:^{
            for (UIViewController *child in children.allValues) {
                child.view.transform = CGAffineTransformIdentity;
                child.view.hidden = NO;
                child.view.alpha = 1.0;
            }
            expand.hidden = YES;
            miniCluster.hidden = YES;
            [root viewWithTag:kCCAConnectivityCompactAirDropTag].hidden = YES;
            [root viewWithTag:kCCAConnectivityCompactBluetoothTag].hidden = YES;
        }];
        return;
    }

    CCAConnectivityCompactMetrics compactMetrics = CCAConnectivityCompactMetricsForBounds(root.bounds);
    NSDictionary<NSString *, NSValue *> *largeFrames = @{
        @"CCUIConnectivityAirplaneViewController": [NSValue valueWithCGRect:compactMetrics.topLeft],
        @"CCUIConnectivityWifiViewController": [NSValue valueWithCGRect:compactMetrics.bottomLeft],
    };
    [UIView performWithoutAnimation:^{
        [largeFrames enumerateKeysAndObjectsUsingBlock:^(NSString *name, NSValue *frameValue, __unused BOOL *stop) {
            UIView *view = children[name].view;
            view.transform = CGAffineTransformIdentity;
            view.frame = frameValue.CGRectValue;
            view.hidden = NO;
            view.alpha = 1.0;
            if (view.superview) [view.superview bringSubviewToFront:view];
        }];
        children[@"CCUIConnectivityCellularDataViewController"].view.hidden = YES;
        children[@"CCUIConnectivityHotspotViewController"].view.hidden = YES;
        children[@"CCUIConnectivityAirDropViewController"].view.hidden = YES;
        children[@"CCUIConnectivityBluetoothViewController"].view.hidden = YES;
    }];

    CGFloat naturalMiniCell = floor(compactMetrics.cell * 0.444);
    CGFloat naturalMiniGap = compactMetrics.cell - naturalMiniCell * 2.0;
    CGFloat requestedMiniGap = MAX(2.0, naturalMiniGap - 3.0);
    CGFloat miniCell = floor((compactMetrics.cell - requestedMiniGap) * 0.5);
    CGFloat miniGap = compactMetrics.cell - miniCell * 2.0;
    if (!miniCluster) {
        miniCluster = [[UIView alloc] initWithFrame:compactMetrics.bottomRight];
        miniCluster.tag = kCCAConnectivityMiniClusterTag;
        miniCluster.userInteractionEnabled = NO;
        NSArray<NSString *> *symbols = @[@"antenna.radiowaves.left.and.right", @"bluetooth", @"personalhotspot", @"network"];
        NSArray<UIColor *> *colors = @[
            [UIColor colorWithRed:0.26 green:0.66 blue:1.0 alpha:0.48],
            [UIColor colorWithRed:0.36 green:0.20 blue:1.0 alpha:1.0],
            [UIColor.whiteColor colorWithAlphaComponent:0.30],
            [UIColor.whiteColor colorWithAlphaComponent:0.30]
        ];
        for (NSUInteger index = 0; index < 4; index++) {
            CGFloat x = (index % 2) * (miniCell + miniGap), y = (index / 2) * (miniCell + miniGap);
            UIView *tile = [[UIView alloc] initWithFrame:CGRectMake(x, y, miniCell, miniCell)];
            tile.backgroundColor = [colors[index] colorWithAlphaComponent:index == 1 ? 0.85 : 0.18];
            tile.layer.cornerRadius = miniCell * 0.5;
            UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:9.0 weight:UIImageSymbolWeightSemibold];
            UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbols[index] withConfiguration:configuration]];
            icon.frame = tile.bounds; icon.contentMode = UIViewContentModeCenter; icon.tintColor = colors[index];
            [tile addSubview:icon];
            if (index == 1) tile.hidden = YES;
            [miniCluster addSubview:tile];
        }
        [root addSubview:miniCluster];
    }
    miniCluster.hidden = NO;
    miniCluster.frame = compactMetrics.bottomRight;
    [miniCluster.subviews enumerateObjectsUsingBlock:^(UIView *tile, NSUInteger index, __unused BOOL *stop) {
        CGFloat x = (index % 2) * (miniCell + miniGap), y = (index / 2) * (miniCell + miniGap);
        tile.frame = CGRectMake(x, y, miniCell, miniCell);
        tile.layer.cornerRadius = miniCell * 0.5;
        tile.subviews.firstObject.frame = tile.bounds;
    }];
    UIButton *airDropProxy = CCAConnectivitySnapshotProxy(root, kCCAConnectivityCompactAirDropTag, compactMetrics.topRight,
                                                          children[@"CCUIConnectivityAirDropViewController"]);
    CGRect bluetoothFrame = CGRectMake(CGRectGetMinX(compactMetrics.bottomRight) + miniCell + miniGap,
                                       CGRectGetMinY(compactMetrics.bottomRight), miniCell, miniCell);
    UIButton *bluetoothProxy = CCAConnectivitySnapshotProxy(root, kCCAConnectivityCompactBluetoothTag, bluetoothFrame,
                                                             children[@"CCUIConnectivityBluetoothViewController"]);
    if (![objc_getAssociatedObject(controller, kCCAConnectivityProxyRefreshScheduledKey) boolValue]) {
        objc_setAssociatedObject(controller, kCCAConnectivityProxyRefreshScheduledKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        __weak UIViewController *weakController = controller;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.55 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIViewController *strongController = weakController;
            if (!strongController) return;
            CCAConfigureConnectivityLayout(strongController);
        });
    }
    if (!expand) {
        expand = [UIButton buttonWithType:UIButtonTypeCustom];
        expand.tag = kCCAConnectivityExpandButtonTag;
        expand.accessibilityLabel = @"More Connectivity Controls";
        expand.accessibilityHint = @"Opens all connectivity controls";
        expand.isAccessibilityElement = YES;
        [expand addTarget:[CCiOS18ConnectivityCoordinator shared] action:@selector(expandConnectivityFromMiniCluster:) forControlEvents:UIControlEventTouchUpInside];
        [root addSubview:expand];
    }
    expand.hidden = gCCAEditModeActive;
    expand.userInteractionEnabled = !gCCAEditModeActive;
    expand.frame = CGRectInset(compactMetrics.bottomRight, -compactMetrics.gap * 0.5, -compactMetrics.gap * 0.5);
    [root bringSubviewToFront:miniCluster];
    [root bringSubviewToFront:airDropProxy];
    [root bringSubviewToFront:bluetoothProxy];
    [root bringSubviewToFront:expand];
}

%hook CCUIConnectivityModuleViewController
- (void)viewDidLayoutSubviews {
    %orig;
    @try {
        UIViewController *controller = (UIViewController *)(id)self;
        CCAConfigureConnectivityLayout(controller);
        static const void *kCCAConnectivityDeferredLayoutKey = &kCCAConnectivityDeferredLayoutKey;
        BOOL compact = CGRectGetWidth(controller.view.bounds) < 190.0 &&
                       CGRectGetHeight(controller.view.bounds) < 190.0;
        if (compact && ![objc_getAssociatedObject(controller, kCCAConnectivityDeferredLayoutKey) boolValue]) {
            objc_setAssociatedObject(controller, kCCAConnectivityDeferredLayoutKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            __weak UIViewController *weakController = controller;
            dispatch_async(dispatch_get_main_queue(), ^{
                UIViewController *strongController = weakController;
                if (!strongController) return;
                objc_setAssociatedObject(strongController, kCCAConnectivityDeferredLayoutKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                CCAConfigureConnectivityLayout(strongController);
            });
        }
    } @catch (NSException *exception) {
        NSLog(@"[CCiOS18] CCAster connectivity layout exception: %@", exception);
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
