#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <math.h>
#import <objc/message.h>

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


// MARK: - Inline Control Center editing (iOS 15)
//
// Long-press enters edit mode inside Control Center. Native module controllers
// remain in place; edits are persisted through Apple's CCSModuleSettingsProvider.

static const NSInteger kCCiOS18InlineRemoveTag = 180020;
static const NSInteger kCCiOS18InlineDoneTag = 180021;
static const NSInteger kCCiOS18InlineAddTag = 180022;
static char kCCiOS18LongPressGestureKey;
static char kCCiOS18InlinePanGestureKey;
static char kCCiOS18InlineEditingKey;
static char kCCiOS18InlineOverlayKey;
static char kCCiOS18InlineDragSnapshotKey;
static char kCCiOS18InlineDragSourceKey;
static char kCCiOS18InlineDragIdentifierKey;
static __weak UIViewController *gCCiOS18InlineEditingOverlay = nil;

@interface CCiOS18LongPressDelegate : NSObject <UIGestureRecognizerDelegate>
@end

@implementation CCiOS18LongPressDelegate
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
        UIViewController *overlay = objc_getAssociatedObject(gestureRecognizer, &kCCiOS18InlineOverlayKey);
        if (!overlay || ![objc_getAssociatedObject(overlay, &kCCiOS18InlineEditingKey) boolValue]) return NO;
    }
    UIView *view = touch.view;
    while (view) {
        if ([view isKindOfClass:[UISlider class]] ||
            CCiOS18ClassContains(view, @"Slider") ||
            CCiOS18ClassContains(view, @"ScrollView")) return NO;
        view = view.superview;
    }
    return YES;
}
@end

static CCiOS18LongPressDelegate *CCiOS18SharedLongPressDelegate(void) {
    static CCiOS18LongPressDelegate *delegate;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ delegate = [CCiOS18LongPressDelegate new]; });
    return delegate;
}

static id CCiOS18SafeValue(id object, NSString *key) {
    if (!object || !key.length) return nil;
    @try { return [object valueForKey:key]; }
    @catch (__unused NSException *exception) { return nil; }
}

static NSString *CCiOS18IdentifierFromObject(id object, NSUInteger depth) {
    if (!object || depth > 2) return nil;
    if ([object isKindOfClass:[NSString class]]) {
        NSString *value = object;
        if ([value containsString:@"."] && value.length < 256) return value;
        return nil;
    }
    if ([object isKindOfClass:[NSDictionary class]]) {
        for (NSString *key in @[@"moduleIdentifier", @"identifier", @"moduleID", @"bundleIdentifier"]) {
            NSString *value = CCiOS18IdentifierFromObject(object[key], depth + 1);
            if (value.length) return value;
        }
        return nil;
    }
    for (NSString *key in @[@"moduleIdentifier", @"_moduleIdentifier", @"identifier",
                             @"moduleInfo", @"moduleMetadata", @"contentModule", @"module"]) {
        id value = CCiOS18SafeValue(object, key);
        NSString *identifier = CCiOS18IdentifierFromObject(value, depth + 1);
        if (identifier.length) return identifier;
    }
    return nil;
}

static void CCiOS18CollectInlineModules(UIViewController *controller,
                                        UIViewController *root,
                                        NSMutableArray<UIViewController *> *result) {
    if (!controller || controller == root) {
        for (UIViewController *child in controller.childViewControllers) {
            CCiOS18CollectInlineModules(child, root, result);
        }
        return;
    }
    BOOL isModuleView = controller.isViewLoaded &&
        CCiOS18TreeContainsClassPart(controller.view, @"CCUIContentModuleContentContainerView");
    if (isModuleView && CCiOS18IdentifierFromObject(controller, 0).length) {
        [result addObject:controller];
        return;
    }
    for (UIViewController *child in controller.childViewControllers) {
        CCiOS18CollectInlineModules(child, root, result);
    }
}

static NSArray<UIViewController *> *CCiOS18InlineModules(UIViewController *overlay) {
    NSMutableArray *result = [NSMutableArray new];
    CCiOS18CollectInlineModules(overlay, overlay, result);
    return result;
}

static NSArray<NSString *> *CCiOS18CurrentEnabledModuleOrder(void) {
    @try {
        Class providerClass = NSClassFromString(@"CCSModuleSettingsProvider");
        SEL sharedSelector = NSSelectorFromString(@"sharedProvider");
        if (!providerClass || ![providerClass respondsToSelector:sharedSelector]) return nil;
        id provider = ((id (*)(id, SEL))objc_msgSend)(providerClass, sharedSelector);
        SEL orderSelector = NSSelectorFromString(@"orderedUserEnabledModuleIdentifiers");
        if (![provider respondsToSelector:orderSelector]) return nil;
        id value = ((id (*)(id, SEL))objc_msgSend)(provider, orderSelector);
        return [value isKindOfClass:[NSArray class]] ? [value copy] : nil;
    } @catch (NSException *exception) {
        NSLog(@"[CCiOS18] Could not read module order: %@", exception);
        return nil;
    }
}

static BOOL CCiOS18SaveModuleOrder(NSArray<NSString *> *order) {
    if (!order) return NO;
    @try {
        Class providerClass = NSClassFromString(@"CCSModuleSettingsProvider");
        SEL sharedSelector = NSSelectorFromString(@"sharedProvider");
        id provider = providerClass && [providerClass respondsToSelector:sharedSelector]
            ? ((id (*)(id, SEL))objc_msgSend)(providerClass, sharedSelector) : nil;
        SEL saveSelector = NSSelectorFromString(@"setAndSaveOrderedUserEnabledModuleIdentifiers:");
        if (!provider || ![provider respondsToSelector:saveSelector]) return NO;
        ((void (*)(id, SEL, id))objc_msgSend)(provider, saveSelector, [order copy]);
        return YES;
    } @catch (NSException *exception) {
        NSLog(@"[CCiOS18] Saving inline module order failed: %@", exception);
        return NO;
    }
}

static NSString *CCiOS18ReadableModuleName(NSString *identifier) {
    NSDictionary *known = @{
        @"com.apple.control-center.FlashlightModule": @"Flashlight",
        @"com.apple.mobiletimer.controlcenter.timer": @"Timer",
        @"com.apple.control-center.CalculatorModule": @"Calculator",
        @"com.apple.control-center.CameraModule": @"Camera",
        @"com.apple.control-center.ScreenRecordingModule": @"Screen Recording",
        @"com.apple.control-center.LowPowerModule": @"Low Power Mode",
        @"com.apple.control-center.DarkModeModule": @"Dark Mode",
        @"com.apple.control-center.TextSizeModule": @"Text Size",
        @"com.apple.control-center.HearingAidsModule": @"Hearing",
        @"com.apple.control-center.CodeScannerModule": @"Code Scanner"
    };
    NSString *name = known[identifier];
    if (name.length) return name;
    NSString *last = [[identifier componentsSeparatedByString:@"."] lastObject] ?: identifier;
    last = [last stringByReplacingOccurrencesOfString:@"ControlCenterModule" withString:@""];
    last = [last stringByReplacingOccurrencesOfString:@"Module" withString:@""];
    last = [last stringByReplacingOccurrencesOfString:@"-" withString:@" "];
    last = [last stringByReplacingOccurrencesOfString:@"_" withString:@" "];
    return last.length ? last : identifier;
}

static NSArray<NSDictionary<NSString *, NSString *> *> *CCiOS18AvailableInlineModules(void) {
    // Identifiers verified against the iOS Control Center module-order plist.
    // Only offer known iOS 15 modules; unsupported IDs can leave stale entries
    // in the settings provider and make the native collection fail to rebuild.
    return @[
        @{@"id": @"com.apple.control-center.FlashlightModule", @"name": @"Flashlight"},
        @{@"id": @"com.apple.mobiletimer.controlcenter.timer", @"name": @"Timer"},
        @{@"id": @"com.apple.control-center.CalculatorModule", @"name": @"Calculator"},
        @{@"id": @"com.apple.control-center.CameraModule", @"name": @"Camera"},
        @{@"id": @"com.apple.Home.ControlCenter", @"name": @"Home"},
        @{@"id": @"com.apple.control-center.ConnectivityModule", @"name": @"Connectivity"},
        @{@"id": @"com.apple.mediaremote.controlcenter.nowplaying", @"name": @"Now Playing"},
        @{@"id": @"com.apple.control-center.OrientationLockModule", @"name": @"Orientation Lock"},
        @{@"id": @"com.apple.control-center.DoNotDisturbModule", @"name": @"Do Not Disturb"},
        @{@"id": @"com.apple.control-center.DisplayModule", @"name": @"Display"},
        @{@"id": @"com.apple.control-center.AudioModule", @"name": @"Volume"},
        @{@"id": @"com.apple.mediaremote.controlcenter.airplaymirroring", @"name": @"Screen Mirroring"}
    ];
}

static UIButton *CCiOS18MakeInlineButton(NSString *title, NSInteger tag, UIColor *color) {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tag = tag;
    button.backgroundColor = color;
    button.tintColor = UIColor.whiteColor;
    button.layer.cornerRadius = 15.0;
    button.layer.masksToBounds = YES;
    button.titleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    [button setTitle:title forState:UIControlStateNormal];
    return button;
}

%hook CCUIModularControlCenterOverlayViewController

- (void)viewDidLayoutSubviews {
    %orig;
    @try {
        UIView *root = [(UIViewController *)self view];
        CCiOS18InstallBackdrop(root);

        UILongPressGestureRecognizer *longPress =
            (UILongPressGestureRecognizer *)objc_getAssociatedObject(self, &kCCiOS18LongPressGestureKey);
        if (!longPress) {
            longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(ccios18_handleLongPress:)];
            longPress.minimumPressDuration = 0.55;
            longPress.cancelsTouchesInView = YES;
            longPress.delaysTouchesBegan = NO;
            longPress.delegate = CCiOS18SharedLongPressDelegate();
            [root addGestureRecognizer:longPress];
            objc_setAssociatedObject(self, &kCCiOS18LongPressGestureKey, longPress, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        if ([objc_getAssociatedObject(self, &kCCiOS18InlineEditingKey) boolValue]) {
            [self ccios18_refreshInlineEditor];
        }
    } @catch (NSException *exception) {
        NSLog(@"[CCiOS18] Inline editor layout exception: %@", exception);
    }
}

%new
- (void)ccios18_handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    if ([objc_getAssociatedObject(self, &kCCiOS18InlineEditingKey) boolValue]) return;
    [self ccios18_setInlineEditing:YES];
}

%new
- (void)ccios18_setInlineEditing:(BOOL)editing {
    UIView *root = [(UIViewController *)self view];
    objc_setAssociatedObject(self, &kCCiOS18InlineEditingKey, @(editing), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (editing) gCCiOS18InlineEditingOverlay = (UIViewController *)self;
    else if (gCCiOS18InlineEditingOverlay == (UIViewController *)self) gCCiOS18InlineEditingOverlay = nil;

    for (UIViewController *module in CCiOS18InlineModules((UIViewController *)self)) {
        if (editing) {
            UIPanGestureRecognizer *pan = objc_getAssociatedObject(module.view, &kCCiOS18InlinePanGestureKey);
            if (!pan) {
                pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(ccios18_inlineModulePanned:)];
                pan.minimumNumberOfTouches = 1;
                pan.maximumNumberOfTouches = 1;
                pan.cancelsTouchesInView = NO;
                pan.delegate = CCiOS18SharedLongPressDelegate();
                objc_setAssociatedObject(pan, &kCCiOS18InlineOverlayKey, self, OBJC_ASSOCIATION_ASSIGN);
                [module.view addGestureRecognizer:pan];
                objc_setAssociatedObject(module.view, &kCCiOS18InlinePanGestureKey, pan, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            module.view.layer.borderWidth = 1.4;
            module.view.layer.borderColor = [UIColor colorWithRed:0.95 green:0.28 blue:0.27 alpha:0.9].CGColor;
            module.view.layer.cornerRadius = 17.0;
        } else {
            module.view.layer.borderWidth = 0.0;
            module.view.layer.borderColor = nil;
            UIPanGestureRecognizer *pan = objc_getAssociatedObject(module.view, &kCCiOS18InlinePanGestureKey);
            pan.enabled = NO;
            pan.enabled = YES;
        }
    }

    UIButton *done = (UIButton *)[root viewWithTag:kCCiOS18InlineDoneTag];
    UIButton *add = (UIButton *)[root viewWithTag:kCCiOS18InlineAddTag];
    if (editing) {
        if (!done) {
            done = CCiOS18MakeInlineButton(@"Done", kCCiOS18InlineDoneTag,
                [UIColor colorWithRed:0.18 green:0.66 blue:0.36 alpha:0.96]);
            [done addTarget:self action:@selector(ccios18_finishInlineEditing) forControlEvents:UIControlEventTouchUpInside];
            [root addSubview:done];
        }
        if (!add) {
            add = CCiOS18MakeInlineButton(@"+ Add Controls", kCCiOS18InlineAddTag,
                [UIColor colorWithWhite:0.16 alpha:0.96]);
            add.layer.borderWidth = 0.7;
            add.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.3].CGColor;
            [add addTarget:self action:@selector(ccios18_showInlineAddControls) forControlEvents:UIControlEventTouchUpInside];
            [root addSubview:add];
        }
        done.hidden = NO;
        add.hidden = NO;
        done.frame = CGRectMake(CGRectGetWidth(root.bounds) - 82.0, root.safeAreaInsets.top + 8.0, 70.0, 34.0);
        [add sizeToFit];
        add.frame = CGRectMake((CGRectGetWidth(root.bounds) - 142.0) * 0.5,
            CGRectGetHeight(root.bounds) - MAX(root.safeAreaInsets.bottom, 12.0) - 52.0, 142.0, 36.0);
        [self ccios18_refreshInlineEditor];
    } else {
        [done removeFromSuperview];
        [add removeFromSuperview];
        for (UIView *view in [root.subviews copy]) {
            if (view.tag == kCCiOS18InlineRemoveTag) [view removeFromSuperview];
        }
    }
}

%new
- (void)ccios18_refreshInlineEditor {
    if (![objc_getAssociatedObject(self, &kCCiOS18InlineEditingKey) boolValue]) return;
    UIView *root = [(UIViewController *)self view];
    NSArray<UIViewController *> *modules = CCiOS18InlineModules((UIViewController *)self);
    NSMutableSet *validIdentifiers = [NSMutableSet new];
    for (UIViewController *module in modules) {
        NSString *identifier = CCiOS18IdentifierFromObject(module, 0);
        if (identifier.length) [validIdentifiers addObject:identifier];
    }
    for (UIView *view in [root.subviews copy]) {
        if (view.tag == kCCiOS18InlineRemoveTag &&
            ![validIdentifiers containsObject:view.accessibilityIdentifier]) [view removeFromSuperview];
    }
    for (UIViewController *module in modules) {
        NSString *identifier = CCiOS18IdentifierFromObject(module, 0);
        if (!identifier.length) continue;
        UIButton *remove = nil;
        for (UIView *candidate in root.subviews) {
            if (candidate.tag == kCCiOS18InlineRemoveTag &&
                [candidate.accessibilityIdentifier isEqualToString:identifier]) {
                remove = (UIButton *)candidate;
                break;
            }
        }
        if (!remove) {
            remove = [UIButton buttonWithType:UIButtonTypeSystem];
            remove.tag = kCCiOS18InlineRemoveTag;
            remove.accessibilityIdentifier = identifier;
            remove.backgroundColor = [UIColor colorWithRed:0.94 green:0.22 blue:0.22 alpha:1.0];
            remove.tintColor = UIColor.whiteColor;
            remove.layer.cornerRadius = 12.0;
            remove.layer.borderWidth = 1.0;
            remove.layer.borderColor = UIColor.whiteColor.CGColor;
            [remove setImage:[UIImage systemImageNamed:@"minus"] forState:UIControlStateNormal];
            [remove addTarget:self action:@selector(ccios18_removeInlineControl:) forControlEvents:UIControlEventTouchUpInside];
            [root addSubview:remove];
        }
        CGRect frame = [module.view convertRect:module.view.bounds toView:root];
        remove.frame = CGRectMake(CGRectGetMinX(frame) - 7.0, CGRectGetMinY(frame) - 7.0, 25.0, 25.0);
        remove.hidden = NO;
        [root bringSubviewToFront:remove];
    }
    UIButton *done = (UIButton *)[root viewWithTag:kCCiOS18InlineDoneTag];
    UIButton *add = (UIButton *)[root viewWithTag:kCCiOS18InlineAddTag];
    if (done) [root bringSubviewToFront:done];
    if (add) [root bringSubviewToFront:add];
}

%new
- (void)ccios18_removeInlineControl:(UIButton *)sender {
    NSString *identifier = sender.accessibilityIdentifier;
    NSArray<NSString *> *current = CCiOS18CurrentEnabledModuleOrder();
    if (!identifier.length || !current.count) return;
    NSMutableArray *updated = [current mutableCopy];
    [updated removeObject:identifier];
    if (updated.count && CCiOS18SaveModuleOrder(updated)) {
        [sender removeFromSuperview];
        [self ccios18_refreshInlineEditor];
    }
}

%new
- (void)ccios18_showInlineAddControls {
    NSArray<NSString *> *current = CCiOS18CurrentEnabledModuleOrder();
    if (!current) return;
    NSMutableArray<NSDictionary *> *available = [NSMutableArray new];
    for (NSDictionary *item in CCiOS18AvailableInlineModules()) {
        if (![current containsObject:item[@"id"]]) [available addObject:item];
    }
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Add Controls"
        message:@"Choose a control to add to Control Center." preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSDictionary *item in available) {
        [sheet addAction:[UIAlertAction actionWithTitle:item[@"name"] style:UIAlertActionStyleDefault
            handler:^(__unused UIAlertAction *action) {
                NSMutableArray *updated = [current mutableCopy];
                [updated addObject:item[@"id"]];
                if (CCiOS18SaveModuleOrder(updated)) {
                    [self ccios18_refreshInlineEditor];
                    [self.view setNeedsLayout];
                }
            }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    UIPopoverPresentationController *popover = sheet.popoverPresentationController;
    if (popover) {
        popover.sourceView = self.view;
        popover.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMaxY(self.view.bounds) - 55.0, 1.0, 1.0);
    }
    [(UIViewController *)self presentViewController:sheet animated:YES completion:nil];
}

%new
- (void)ccios18_inlineModulePanned:(UIPanGestureRecognizer *)gesture {
    UIView *moduleView = gesture.view;
    UIViewController *overlay = (UIViewController *)self;
    UIView *root = overlay.view;
    NSString *identifier = CCiOS18IdentifierFromObject(moduleView.nextResponder, 0);
    if (!identifier.length) {
        for (UIViewController *module in CCiOS18InlineModules(overlay)) {
            if (module.view == moduleView) { identifier = CCiOS18IdentifierFromObject(module, 0); break; }
        }
    }
    if (!identifier.length) return;

    if (gesture.state == UIGestureRecognizerStateBegan) {
        objc_setAssociatedObject(overlay, &kCCiOS18InlineDragIdentifierKey, identifier, OBJC_ASSOCIATION_COPY_NONATOMIC);
        objc_setAssociatedObject(overlay, &kCCiOS18InlineDragSourceKey, moduleView, OBJC_ASSOCIATION_ASSIGN);
        CGRect frame = [moduleView convertRect:moduleView.bounds toView:root];
        UIView *snapshot = [moduleView snapshotViewAfterScreenUpdates:NO];
        snapshot.frame = frame;
        snapshot.layer.shadowColor = UIColor.blackColor.CGColor;
        snapshot.layer.shadowOpacity = 0.25;
        snapshot.layer.shadowRadius = 12.0;
        snapshot.layer.shadowOffset = CGSizeMake(0, 5);
        [root addSubview:snapshot];
        moduleView.alpha = 0.22;
        objc_setAssociatedObject(overlay, &kCCiOS18InlineDragSnapshotKey, snapshot, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        UIView *snapshot = objc_getAssociatedObject(overlay, &kCCiOS18InlineDragSnapshotKey);
        if (snapshot) snapshot.center = [gesture locationInView:root];
    } else if (gesture.state == UIGestureRecognizerStateEnded ||
               gesture.state == UIGestureRecognizerStateCancelled ||
               gesture.state == UIGestureRecognizerStateFailed) {
        NSString *dragged = objc_getAssociatedObject(overlay, &kCCiOS18InlineDragIdentifierKey);
        UIView *snapshot = objc_getAssociatedObject(overlay, &kCCiOS18InlineDragSnapshotKey);
        UIView *source = objc_getAssociatedObject(overlay, &kCCiOS18InlineDragSourceKey);
        CGPoint drop = snapshot ? snapshot.center : [gesture locationInView:root];
        UIViewController *targetModule = nil;
        CGFloat bestDistance = CGFLOAT_MAX;
        for (UIViewController *candidate in CCiOS18InlineModules(overlay)) {
            if (candidate.view == source) continue;
            CGPoint center = [candidate.view.superview convertPoint:candidate.view.center toView:root];
            CGFloat distance = hypot(center.x - drop.x, center.y - drop.y);
            if (distance < bestDistance) { bestDistance = distance; targetModule = candidate; }
        }
        NSArray<NSString *> *current = CCiOS18CurrentEnabledModuleOrder();
        if (dragged.length && targetModule && bestDistance < 180.0 && current.count > 1) {
            NSString *target = CCiOS18IdentifierFromObject(targetModule, 0);
            NSMutableArray *updated = [current mutableCopy];
            [updated removeObject:dragged];
            NSUInteger targetIndex = [updated indexOfObject:target];
            if (targetIndex == NSNotFound) targetIndex = updated.count;
            else [updated insertObject:dragged atIndex:targetIndex];
            if (targetIndex == updated.count) [updated addObject:dragged];
            CCiOS18SaveModuleOrder(updated);
        }
        source.alpha = 1.0;
        [snapshot removeFromSuperview];
        objc_setAssociatedObject(overlay, &kCCiOS18InlineDragIdentifierKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(overlay, &kCCiOS18InlineDragSnapshotKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(overlay, &kCCiOS18InlineDragSourceKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self ccios18_refreshInlineEditor];
    }
}

%new
- (void)ccios18_finishInlineEditing {
    [self ccios18_setInlineEditing:NO];
}

%end

// Keep the native connectivity module and its original button actions.
// Only refine the individual Airplane/Wi-Fi/Bluetooth/Cellular/AirDrop/Hotspot
// button surfaces; iOS remains responsible for their state and behavior.
%hook CCUIConnectivityButtonViewController

- (void)viewDidLayoutSubviews {
    %orig;
    @try {
        UIView *buttonView = [(UIViewController *)self view];
        if (!buttonView || CGRectIsEmpty(buttonView.bounds)) return;

        CGFloat side = MIN(CGRectGetWidth(buttonView.bounds), CGRectGetHeight(buttonView.bounds));
        CGFloat radius = side > 0 ? MIN(18.0, side * 0.28) : 14.0;
        buttonView.layer.cornerRadius = radius;
        if (@available(iOS 13.0, *)) {
            buttonView.layer.cornerCurve = kCACornerCurveContinuous;
        }
        buttonView.layer.borderWidth = 0.65;
        buttonView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.14].CGColor;
        buttonView.layer.masksToBounds = YES;
    } @catch (NSException *exception) {
        NSLog(@"[CCiOS18] Connectivity button styling exception: %@", exception);
    }
}

%end
 
// Media controls keep Apple's transport/session actions. This pass only
// rounds the album artwork and gives it a subtle glass edge.
static void CCiOS18StyleMediaArtwork(UIView *view) {
    if (!view) return;
    for (UIView *child in view.subviews) {
        if ([child isKindOfClass:[UIImageView class]]) {
            UIImageView *imageView = (UIImageView *)child;
            CGSize size = imageView.bounds.size;
            BOOL artworkSized = size.width >= 64.0 && size.height >= 64.0;
            BOOL artworkNamed = [NSStringFromClass([imageView class]) rangeOfString:@"Artwork" options:NSCaseInsensitiveSearch].location != NSNotFound;
            if (artworkSized || artworkNamed) {
                imageView.layer.cornerRadius = 12.0;
                if (@available(iOS 13.0, *)) imageView.layer.cornerCurve = kCACornerCurveContinuous;
                imageView.layer.borderWidth = 0.6;
                imageView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.16].CGColor;
                imageView.clipsToBounds = YES;
            }
        }
        CCiOS18StyleMediaArtwork(child);
    }
}

%hook CCUIMediaControlsViewController

- (void)viewDidLayoutSubviews {
    %orig;
    @try {
        CCiOS18StyleMediaArtwork([(UIViewController *)self view]);
    } @catch (NSException *exception) {
        NSLog(@"[CCiOS18] Media artwork styling exception: %@", exception);
    }
}

%end
