#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <math.h>
#import <objc/message.h>

// The Logos hook below adds methods to this private UIKit controller.
@interface CCUIModularControlCenterOverlayViewController : UIViewController
- (void)ccios18_handleLongPress:(UILongPressGestureRecognizer *)gesture;
- (void)ccios18_setInlineEditing:(BOOL)editing;
- (void)ccios18_refreshInlineEditor;
- (void)ccios18_removeInlineControl:(UIButton *)sender;
- (void)ccios18_showInlineAddControls;
- (void)ccios18_inlineModulePanned:(UIPanGestureRecognizer *)gesture;
- (void)ccios18_inlineModulePinched:(UIPinchGestureRecognizer *)gesture;
- (void)ccios18_resizeHandlePanned:(UIPanGestureRecognizer *)gesture;
- (void)ccios18_finishInlineEditing;
@end


typedef struct CCUILayoutSize { NSUInteger width; NSUInteger height; } CCUILayoutSize;
typedef struct CCUILayoutPoint { NSUInteger x; NSUInteger y; } CCUILayoutPoint;
typedef struct CCUILayoutRect { CCUILayoutPoint origin; CCUILayoutSize size; } CCUILayoutRect;
static NSArray<UIViewController *> *CCiOS18InlineModules(UIViewController *overlay);
static NSString *CCiOS18IdentifierFromObject(id object, NSUInteger depth);
static BOOL CCiOS18ClassContains(id object, NSString *part);

typedef struct CCiOS18GridSize { NSUInteger width; NSUInteger height; } CCiOS18GridSize;
typedef struct CCiOS18GridPoint { NSUInteger x; NSUInteger y; } CCiOS18GridPoint;
typedef struct CCiOS18GridRect { CCiOS18GridPoint origin; CCiOS18GridSize size; } CCiOS18GridRect;
static NSMutableDictionary<NSString *, NSValue *> *gCCiOS18BaseGridSizes;
static NSMutableDictionary<NSString *, NSValue *> *gCCiOS18NativeGridRects;
static NSMutableDictionary<NSString *, NSArray<NSNumber *> *> *gCCiOS18CustomGridSizes;
static NSMutableDictionary<NSString *, NSArray<NSNumber *> *> *gCCiOS18CustomGridOrigins;
static const NSUInteger kCCiOS18GridColumns = 4;
static const NSUInteger kCCiOS18GridRows = 64;
static CGFloat const kCCiOS18GridCell = 67.0;
static CGFloat const kCCiOS18GridGap = 12.0;
static NSString * const kCCiOS18GridPrefsDomain = @"com.le17y17abd-eng.ccios18";
static void CCiOS18LoadGridPreferences(void) {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kCCiOS18GridPrefsDomain] ?: [NSUserDefaults standardUserDefaults];
    NSDictionary *sizes = [defaults dictionaryForKey:@"CCiOS18ModuleGridSizes"];
    NSDictionary *origins = [defaults dictionaryForKey:@"CCiOS18ModuleGridOrigins"];
    gCCiOS18CustomGridSizes = [sizes mutableCopy] ?: [NSMutableDictionary new];
    gCCiOS18CustomGridOrigins = [origins mutableCopy] ?: [NSMutableDictionary new];
    if (!gCCiOS18BaseGridSizes) gCCiOS18BaseGridSizes = [NSMutableDictionary new];
    if (!gCCiOS18NativeGridRects) gCCiOS18NativeGridRects = [NSMutableDictionary new];
}
static void CCiOS18SaveGridPreferences(void) {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kCCiOS18GridPrefsDomain] ?: [NSUserDefaults standardUserDefaults];
    [defaults setObject:[gCCiOS18CustomGridSizes copy] ?: @{} forKey:@"CCiOS18ModuleGridSizes"];
    [defaults setObject:[gCCiOS18CustomGridOrigins copy] ?: @{} forKey:@"CCiOS18ModuleGridOrigins"];
    [defaults synchronize];
}
static UIViewController *CCiOS18FindCollectionController(UIViewController *root) {
    if (!root) return nil;
    if (CCiOS18ClassContains(root, @"CCUIModuleCollectionViewController")) return root;
    for (UIViewController *child in root.childViewControllers) {
        UIViewController *found = CCiOS18FindCollectionController(child);
        if (found) return found;
    }
    return nil;
}
static BOOL CCiOS18GridRectsOverlap(CCiOS18GridRect a, CCiOS18GridRect b) {
    return a.origin.x < b.origin.x + b.size.width && b.origin.x < a.origin.x + a.size.width &&
           a.origin.y < b.origin.y + b.size.height && b.origin.y < a.origin.y + a.size.height;
}
static BOOL CCiOS18GridRectFits(CCiOS18GridRect rect) {
    return rect.size.width > 0 && rect.size.height > 0 &&
           rect.origin.x + rect.size.width <= kCCiOS18GridColumns &&
           rect.origin.y + rect.size.height <= kCCiOS18GridRows;
}
static BOOL CCiOS18ApplyGridResize(NSString *sourceID, CCiOS18GridSize newSize, UIViewController *overlay) {
    if (!sourceID.length || !overlay) return NO;
    NSMutableDictionary<NSString *, NSValue *> *layout = [NSMutableDictionary new];
    for (UIViewController *module in CCiOS18InlineModules(overlay)) {
        NSString *identifier = CCiOS18IdentifierFromObject(module, 0);
        NSValue *nativeValue = identifier.length ? gCCiOS18NativeGridRects[identifier] : nil;
        if (!nativeValue) continue;
        CCiOS18GridRect rect = {}; [nativeValue getValue:&rect];
        NSArray *savedOrigin = gCCiOS18CustomGridOrigins[identifier];
        NSArray *savedSize = gCCiOS18CustomGridSizes[identifier];
        if (savedOrigin.count >= 2) rect.origin = (CCiOS18GridPoint){[savedOrigin[0] unsignedIntegerValue], [savedOrigin[1] unsignedIntegerValue]};
        if (savedSize.count >= 2) rect.size = (CCiOS18GridSize){[savedSize[0] unsignedIntegerValue], [savedSize[1] unsignedIntegerValue]};
        if (CCiOS18GridRectFits(rect)) layout[identifier] = [NSValue value:&rect withObjCType:@encode(CCiOS18GridRect)];
    }
    NSValue *sourceValue = layout[sourceID];
    if (!sourceValue) return NO;
    CCiOS18GridRect source = {}; [sourceValue getValue:&source];
    source.size = newSize;
    if (!CCiOS18GridRectFits(source)) return NO;
    layout[sourceID] = [NSValue value:&source withObjCType:@encode(CCiOS18GridRect)];
    NSMutableArray<NSString *> *ids = [layout.allKeys mutableCopy];
    [ids removeObject:sourceID];
    [ids sortUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        CCiOS18GridRect ra = {}, rb = {}; [layout[a] getValue:&ra]; [layout[b] getValue:&rb];
        if (ra.origin.y != rb.origin.y) return ra.origin.y < rb.origin.y ? NSOrderedAscending : NSOrderedDescending;
        if (ra.origin.x != rb.origin.x) return ra.origin.x < rb.origin.x ? NSOrderedAscending : NSOrderedDescending;
        return [a compare:b];
    }];
    NSMutableArray<NSString *> *placed = [NSMutableArray arrayWithObject:sourceID];
    for (NSString *identifier in ids) {
        CCiOS18GridRect candidate = {}; [layout[identifier] getValue:&candidate];
        BOOL collision = NO;
        for (NSString *blockerID in placed) {
            CCiOS18GridRect blocker = {}; [layout[blockerID] getValue:&blocker];
            if (CCiOS18GridRectsOverlap(candidate, blocker)) { collision = YES; break; }
        }
        if (collision) {
            BOOL found = NO; NSUInteger bestDistance = NSUIntegerMax; CCiOS18GridRect best = {};
            CCiOS18GridRect original = candidate;
            for (NSUInteger y = 0; y + candidate.size.height <= kCCiOS18GridRows; y++) {
                for (NSUInteger x = 0; x + candidate.size.width <= kCCiOS18GridColumns; x++) {
                    CCiOS18GridRect trial = candidate; trial.origin = (CCiOS18GridPoint){x,y};
                    BOOL fits = YES;
                    for (NSString *blockerID in placed) {
                        CCiOS18GridRect blocker = {}; [layout[blockerID] getValue:&blocker];
                        if (CCiOS18GridRectsOverlap(trial, blocker)) { fits = NO; break; }
                    }
                    if (!fits) continue;
                    NSUInteger dx = x > original.origin.x ? x-original.origin.x : original.origin.x-x;
                    NSUInteger dy = y > original.origin.y ? y-original.origin.y : original.origin.y-y;
                    NSUInteger distance = dx + dy;
                    if (!found || distance < bestDistance || (distance == bestDistance && y < best.origin.y)) {
                        found = YES; bestDistance = distance; best = trial;
                    }
                }
            }
            if (!found) return NO;
            candidate = best;
            layout[identifier] = [NSValue value:&candidate withObjCType:@encode(CCiOS18GridRect)];
        }
        [placed addObject:identifier];
    }
    for (NSString *identifier in layout) {
        CCiOS18GridRect rect = {}; [layout[identifier] getValue:&rect];
        gCCiOS18CustomGridOrigins[identifier] = @[@(rect.origin.x), @(rect.origin.y)];
    }
    gCCiOS18CustomGridSizes[sourceID] = @[@(newSize.width), @(newSize.height)];
    CCiOS18SaveGridPreferences();
    for (UIViewController *module in CCiOS18InlineModules(overlay)) {
        if (![CCiOS18IdentifierFromObject(module, 0) isEqualToString:sourceID]) continue;
        id contentModule = nil; id context = nil;
        @try { contentModule = [module valueForKey:@"module"]; context = [contentModule valueForKey:@"contentModuleContext"]; } @catch (__unused NSException *e) {}
        SEL request = NSSelectorFromString(@"requestLayoutSizeUpdate");
        if ([context respondsToSelector:request]) ((void (*)(id, SEL))objc_msgSend)(context, request);
        break;
    }
    UIViewController *collection = CCiOS18FindCollectionController(overlay);
    [collection.view setNeedsLayout];
    [collection.view layoutIfNeeded];
    return YES;
}

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


// Native Control Center grid integration: store actual 1x1/2x1/2x2 footprints,
// rather than scaling a module's UIView transform.
%hook CCUIModuleCollectionViewController
- (CCUILayoutSize)moduleLayoutSizeForContentModuleContext:(id)context forOrientation:(NSInteger)orientation {
    CCUILayoutSize size = %orig;
    NSString *identifier = [context respondsToSelector:@selector(moduleIdentifier)] ? ((id (*)(id, SEL))objc_msgSend)(context, @selector(moduleIdentifier)) : nil;
    if (identifier.length) {
        CCiOS18GridSize base = {size.width, size.height};
        if (!gCCiOS18BaseGridSizes[identifier]) gCCiOS18BaseGridSizes[identifier] = [NSValue value:&base withObjCType:@encode(CCiOS18GridSize)];
        NSArray *custom = gCCiOS18CustomGridSizes[identifier];
        if (custom.count >= 2) { size.width = [custom[0] unsignedIntegerValue]; size.height = [custom[1] unsignedIntegerValue]; }
    }
    return size;
}
- (CCUILayoutRect)layoutView:(id)layoutView layoutRectForSubview:(UIView *)subview {
    CCUILayoutRect rect = %orig;
    NSDictionary *containers = nil;
    @try { containers = [(id)self valueForKey:@"moduleContainerViewByIdentifier"]; } @catch (__unused NSException *e) {}
    __block NSString *identifier = nil;
    [containers enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
        UIView *candidate = [value isKindOfClass:[UIView class]] ? value : ([value respondsToSelector:@selector(view)] ? [value view] : nil);
        if (candidate == subview) { identifier = key; *stop = YES; }
    }];
    if (identifier.length) {
        CCiOS18GridSize base = {rect.size.width, rect.size.height};
        if (!gCCiOS18BaseGridSizes[identifier]) gCCiOS18BaseGridSizes[identifier] = [NSValue value:&base withObjCType:@encode(CCiOS18GridSize)];
        CCiOS18GridRect saved = {{rect.origin.x, rect.origin.y},{rect.size.width,rect.size.height}};
        gCCiOS18NativeGridRects[identifier] = [NSValue value:&saved withObjCType:@encode(CCiOS18GridRect)];
        NSArray *origin = gCCiOS18CustomGridOrigins[identifier];
        NSArray *size = gCCiOS18CustomGridSizes[identifier];
        if (origin.count >= 2) { rect.origin.x = [origin[0] unsignedIntegerValue]; rect.origin.y = [origin[1] unsignedIntegerValue]; }
        if (size.count >= 2) { rect.size.width = [size[0] unsignedIntegerValue]; rect.size.height = [size[1] unsignedIntegerValue]; }
    }
    return rect;
}
%end

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
static const NSInteger kCCiOS18InlineResizeTag = 180023;
static char kCCiOS18LongPressGestureKey;
static char kCCiOS18InlinePanGestureKey;
static char kCCiOS18InlineEditingKey;
static char kCCiOS18InlineOverlayKey;
static char kCCiOS18InlineDragSnapshotKey;
static char kCCiOS18InlineDragSourceKey;
static char kCCiOS18InlineDragIdentifierKey;
static char kCCiOS18InlineDragOffsetKey;
static char kCCiOS18InlineScrollEnabledKey;
static char kCCiOS18InlineScrollOffsetKey;
static char kCCiOS18InlineScrollPanEnabledKey;
static char kCCiOS18InlinePinchGestureKey;
static char kCCiOS18InlinePinchBaseScaleKey;
static char kCCiOS18InlineResizePanKey;
static char kCCiOS18InlineResizeBaseScaleKey;

@interface CCiOS18LongPressDelegate : NSObject <UIGestureRecognizerDelegate>
@end

@implementation CCiOS18LongPressDelegate
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if ([otherGestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]] && [otherGestureRecognizer.view isKindOfClass:[UIScrollView class]]) return NO;
    return YES;
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
        UIViewController *overlay = objc_getAssociatedObject(gestureRecognizer, &kCCiOS18InlineOverlayKey);
        if (!overlay || ![objc_getAssociatedObject(overlay, &kCCiOS18InlineEditingKey) boolValue]) return NO;
    } else if ([gestureRecognizer isKindOfClass:[UIPinchGestureRecognizer class]]) {
        UIViewController *overlay = objc_getAssociatedObject(gestureRecognizer, &kCCiOS18InlineOverlayKey);
        if (!overlay || ![objc_getAssociatedObject(overlay, &kCCiOS18InlineEditingKey) boolValue]) return NO;
    } else {
        UIViewController *overlay = (UIViewController *)gestureRecognizer.view.nextResponder;
        if (overlay && [objc_getAssociatedObject(overlay, &kCCiOS18InlineEditingKey) boolValue]) return NO;
    }
    UIView *view = touch.view;
    while (view) {
        if ([view isKindOfClass:[UISlider class]] ||
            CCiOS18ClassContains(view, @"Slider")) return NO;
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

static NSArray<NSString *> *CCiOS18FixedModuleIdentifiers(void) {
    @try {
        Class providerClass = NSClassFromString(@"CCSModuleSettingsProvider");
        SEL fixedSelector = NSSelectorFromString(@"_defaultFixedModuleIdentifiers");
        if (providerClass && [providerClass respondsToSelector:fixedSelector]) {
            id value = ((id (*)(id, SEL))objc_msgSend)(providerClass, fixedSelector);
            if ([value isKindOfClass:[NSArray class]]) return [value copy];
        }
    } @catch (NSException *exception) {
        NSLog(@"[CCiOS18] Could not read fixed module identifiers: %@", exception);
    }
    return @[];
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

static void CCiOS18SetScrollViewsForEditing(UIView *view, BOOL editing) {
    if (!view) return;
    if ([view isKindOfClass:[UIScrollView class]]) {
        UIScrollView *scroll = (UIScrollView *)view;
        NSNumber *wasEnabled = objc_getAssociatedObject(scroll, &kCCiOS18InlineScrollEnabledKey);
        NSValue *savedOffset = objc_getAssociatedObject(scroll, &kCCiOS18InlineScrollOffsetKey);
        if (editing) {
            if (!wasEnabled) {
                objc_setAssociatedObject(scroll, &kCCiOS18InlineScrollEnabledKey, @(scroll.scrollEnabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                objc_setAssociatedObject(scroll, &kCCiOS18InlineScrollOffsetKey, [NSValue valueWithCGPoint:scroll.contentOffset], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            if (!objc_getAssociatedObject(scroll, &kCCiOS18InlineScrollPanEnabledKey)) {
                objc_setAssociatedObject(scroll, &kCCiOS18InlineScrollPanEnabledKey, @(scroll.panGestureRecognizer.enabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            scroll.panGestureRecognizer.enabled = NO;
            scroll.scrollEnabled = NO;
        } else if (wasEnabled) {
            NSNumber *panEnabled = objc_getAssociatedObject(scroll, &kCCiOS18InlineScrollPanEnabledKey);
            scroll.scrollEnabled = wasEnabled.boolValue;
            if (panEnabled) scroll.panGestureRecognizer.enabled = panEnabled.boolValue;
            if (savedOffset) [scroll setContentOffset:savedOffset.CGPointValue animated:NO];
            objc_setAssociatedObject(scroll, &kCCiOS18InlineScrollPanEnabledKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(scroll, &kCCiOS18InlineScrollEnabledKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(scroll, &kCCiOS18InlineScrollOffsetKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    for (UIView *child in view.subviews) CCiOS18SetScrollViewsForEditing(child, editing);
}

static CGFloat CCiOS18SavedScaleForIdentifier(NSString *identifier) {
    if (!identifier.length) return 1.0;
    NSString *key = [@"CCiOS18ModuleScale." stringByAppendingString:identifier];
    CGFloat scale = [[NSUserDefaults standardUserDefaults] floatForKey:key];
    return scale >= 0.70 && scale <= 1.40 ? scale : 1.0;
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
    if (editing) CCiOS18LoadGridPreferences();
    objc_setAssociatedObject(self, &kCCiOS18InlineEditingKey, @(editing), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSArray<NSString *> *editableOrder = CCiOS18CurrentEnabledModuleOrder();
    CCiOS18SetScrollViewsForEditing(root, editing);
    for (UIViewController *module in CCiOS18InlineModules((UIViewController *)self)) {
        NSString *identifier = CCiOS18IdentifierFromObject(module, 0);
        BOOL isUserEditable = identifier.length && [editableOrder containsObject:identifier];
        if (editing) {
            if (isUserEditable) {
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
                pan.enabled = YES;
                UIPinchGestureRecognizer *pinch = objc_getAssociatedObject(module.view, &kCCiOS18InlinePinchGestureKey);
                if (!pinch) {
                    pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(ccios18_inlineModulePinched:)];
                    pinch.cancelsTouchesInView = NO;
                    pinch.delegate = CCiOS18SharedLongPressDelegate();
                    objc_setAssociatedObject(pinch, &kCCiOS18InlineOverlayKey, self, OBJC_ASSOCIATION_ASSIGN);
                    [module.view addGestureRecognizer:pinch];
                    objc_setAssociatedObject(module.view, &kCCiOS18InlinePinchGestureKey, pinch, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                }
                pinch.enabled = NO; // Resizing is performed with the corner handle, not a two-finger pinch.
                module.view.transform = CGAffineTransformIdentity;
            }
            module.view.layer.borderWidth = 1.4;
            module.view.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.88].CGColor;
            module.view.layer.cornerRadius = 17.0;
        } else {
            module.view.layer.borderWidth = 0.0;
            module.view.layer.borderColor = nil;
            UIPanGestureRecognizer *pan = objc_getAssociatedObject(module.view, &kCCiOS18InlinePanGestureKey);
            pan.enabled = NO;
            UIPinchGestureRecognizer *pinch = objc_getAssociatedObject(module.view, &kCCiOS18InlinePinchGestureKey);
            pinch.enabled = NO;
            module.view.transform = CGAffineTransformIdentity;
        }
    }

    UIButton *done = (UIButton *)[root viewWithTag:kCCiOS18InlineDoneTag];
    UIButton *add = (UIButton *)[root viewWithTag:kCCiOS18InlineAddTag];
    if (editing) {
        if (!done) {
            done = [UIButton buttonWithType:UIButtonTypeSystem];
            done.tag = kCCiOS18InlineDoneTag;
            done.backgroundColor = UIColor.clearColor;
            done.tintColor = UIColor.whiteColor;
            UIImageSymbolConfiguration *checkConfig = [UIImageSymbolConfiguration configurationWithPointSize:23.0 weight:UIImageSymbolWeightSemibold];
            [done setImage:[[UIImage systemImageNamed:@"checkmark" withConfiguration:checkConfig] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
            done.accessibilityLabel = @"Done";
            done.accessibilityHint = @"Finish Control Center editing";
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
        done.frame = CGRectMake(root.safeAreaInsets.left + 14.0, root.safeAreaInsets.top + 7.0, 40.0, 40.0);
        [add sizeToFit];
        add.frame = CGRectMake((CGRectGetWidth(root.bounds) - 142.0) * 0.5,
            CGRectGetHeight(root.bounds) - MAX(root.safeAreaInsets.bottom, 12.0) - 52.0, 142.0, 36.0);
        [self ccios18_refreshInlineEditor];
    } else {
        [done removeFromSuperview];
        [add removeFromSuperview];
        for (UIView *view in [root.subviews copy]) {
            if (view.tag == kCCiOS18InlineRemoveTag || view.tag == kCCiOS18InlineResizeTag) [view removeFromSuperview];
        }
    }
}

%new
- (void)ccios18_refreshInlineEditor {
    if (![objc_getAssociatedObject(self, &kCCiOS18InlineEditingKey) boolValue]) return;
    UIView *root = [(UIViewController *)self view];
    NSArray<UIViewController *> *modules = CCiOS18InlineModules((UIViewController *)self);
    NSArray<NSString *> *editableOrder = CCiOS18CurrentEnabledModuleOrder();
    NSMutableSet *validIdentifiers = [NSMutableSet new];
    for (UIViewController *module in modules) {
        NSString *identifier = CCiOS18IdentifierFromObject(module, 0);
        if (identifier.length && [editableOrder containsObject:identifier]) [validIdentifiers addObject:identifier];
    }
    for (UIView *view in [root.subviews copy]) {
        if ((view.tag == kCCiOS18InlineRemoveTag || view.tag == kCCiOS18InlineResizeTag) &&
            ![validIdentifiers containsObject:view.accessibilityIdentifier]) [view removeFromSuperview];
    }
    for (UIViewController *module in modules) {
        NSString *identifier = CCiOS18IdentifierFromObject(module, 0);
        if (!identifier.length || ![editableOrder containsObject:identifier]) continue;
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
            remove.backgroundColor = [UIColor colorWithWhite:0.92 alpha:0.96];
            remove.tintColor = [UIColor colorWithWhite:0.22 alpha:1.0];
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

        UIView *resize = nil;
        for (UIView *candidate in root.subviews) {
            if (candidate.tag == kCCiOS18InlineResizeTag &&
                [candidate.accessibilityIdentifier isEqualToString:identifier]) { resize = candidate; break; }
        }
        if (!resize) {
            resize = [[UIView alloc] initWithFrame:CGRectZero];
            resize.tag = kCCiOS18InlineResizeTag;
            resize.accessibilityIdentifier = identifier;
            resize.backgroundColor = UIColor.clearColor;
            resize.clipsToBounds = NO;
            UIBlurEffect *grabberBlur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialLight];
            UIVisualEffectView *grabberMaterial = [[UIVisualEffectView alloc] initWithEffect:grabberBlur];
            grabberMaterial.tag = 180024;
            grabberMaterial.frame = resize.bounds;
            grabberMaterial.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            grabberMaterial.userInteractionEnabled = NO;
            [resize addSubview:grabberMaterial];
            CAShapeLayer *pill = [CAShapeLayer layer];
            pill.name = @"CCiOS18ResizePill";
            pill.fillColor = UIColor.clearColor.CGColor;
            pill.strokeColor = [UIColor.whiteColor colorWithAlphaComponent:0.82].CGColor;
            pill.lineWidth = 12.5;
            pill.lineCap = kCALineCapRound;
            pill.lineJoin = kCALineJoinRound;
            [resize.layer addSublayer:pill];
            UIPanGestureRecognizer *resizePan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(ccios18_resizeHandlePanned:)];
            resizePan.minimumNumberOfTouches = 1;
            resizePan.maximumNumberOfTouches = 1;
            resizePan.cancelsTouchesInView = YES;
            resizePan.delegate = CCiOS18SharedLongPressDelegate();
            objc_setAssociatedObject(resizePan, &kCCiOS18InlineOverlayKey, self, OBJC_ASSOCIATION_ASSIGN);
            [resize addGestureRecognizer:resizePan];
            objc_setAssociatedObject(resize, &kCCiOS18InlineResizePanKey, resizePan, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [root addSubview:resize];
        }
        UIBezierPath *cornerPath = [UIBezierPath bezierPath];
        [cornerPath moveToPoint:CGPointMake(20.29, 40.01)];
        [cornerPath addCurveToPoint:CGPointMake(40.01, 20.29)
                      controlPoint1:CGPointMake(31.20, 40.01)
                      controlPoint2:CGPointMake(40.01, 31.20)];
        UIVisualEffectView *grabberMaterial = (UIVisualEffectView *)[resize viewWithTag:180024];
        CAShapeLayer *materialMask = [CAShapeLayer layer];
        materialMask.path = cornerPath.CGPath;
        materialMask.fillColor = UIColor.clearColor.CGColor;
        materialMask.strokeColor = UIColor.blackColor.CGColor;
        materialMask.lineWidth = 12.0;
        materialMask.lineCap = kCALineCapRound;
        materialMask.lineJoin = kCALineJoinRound;
        grabberMaterial.layer.mask = materialMask;
        for (CALayer *layer in [resize.layer.sublayers copy]) {
            if ([layer.name isEqualToString:@"CCiOS18ResizePill"] && [layer isKindOfClass:[CAShapeLayer class]]) ((CAShapeLayer *)layer).path = cornerPath.CGPath;
        }
        resize.frame = CGRectMake(CGRectGetMaxX(frame) - 40.0, CGRectGetMaxY(frame) - 40.0, 40.0, 40.0);
        resize.hidden = NO;
        [root bringSubviewToFront:resize];
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
    NSArray<NSString *> *fixed = CCiOS18FixedModuleIdentifiers();
    for (NSDictionary *item in CCiOS18AvailableInlineModules()) {
        NSString *identifier = item[@"id"];
        if (![current containsObject:identifier] && ![fixed containsObject:identifier]) {
            [available addObject:item];
        }
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
        CGPoint finger = [gesture locationInView:root];
        CGPoint dragOffset = CGPointMake(CGRectGetMidX(frame) - finger.x, CGRectGetMidY(frame) - finger.y);
        objc_setAssociatedObject(overlay, &kCCiOS18InlineDragOffsetKey,
            [NSValue valueWithCGPoint:dragOffset], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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
        NSValue *offsetValue = objc_getAssociatedObject(overlay, &kCCiOS18InlineDragOffsetKey);
        CGPoint offset = offsetValue ? offsetValue.CGPointValue : CGPointZero;
        CGPoint finger = [gesture locationInView:root];
        if (snapshot) snapshot.center = CGPointMake(finger.x + offset.x, finger.y + offset.y);
    } else if (gesture.state == UIGestureRecognizerStateEnded ||
               gesture.state == UIGestureRecognizerStateCancelled ||
               gesture.state == UIGestureRecognizerStateFailed) {
        BOOL shouldCommitDrop = gesture.state == UIGestureRecognizerStateEnded;
        NSString *dragged = objc_getAssociatedObject(overlay, &kCCiOS18InlineDragIdentifierKey);
        UIView *snapshot = objc_getAssociatedObject(overlay, &kCCiOS18InlineDragSnapshotKey);
        UIView *source = objc_getAssociatedObject(overlay, &kCCiOS18InlineDragSourceKey);
        NSValue *offsetValue = objc_getAssociatedObject(overlay, &kCCiOS18InlineDragOffsetKey);
        CGPoint offset = offsetValue ? offsetValue.CGPointValue : CGPointZero;
        CGPoint currentFinger = [gesture locationInView:root];
        CGPoint drop = snapshot ? snapshot.center : CGPointMake(currentFinger.x + offset.x, currentFinger.y + offset.y);
        UIViewController *targetModule = nil;
        CGFloat bestDistance = CGFLOAT_MAX;
        NSArray<NSString *> *current = CCiOS18CurrentEnabledModuleOrder();
        CGRect sourceFrame = source ? [source convertRect:source.bounds toView:root] : CGRectZero;
        BOOL droppedBackOnSource = source && CGRectContainsPoint(sourceFrame, drop);
        if (!droppedBackOnSource) {
            for (UIViewController *candidate in CCiOS18InlineModules(overlay)) {
                NSString *candidateIdentifier = CCiOS18IdentifierFromObject(candidate, 0);
                if (candidate.view == source || ![current containsObject:candidateIdentifier]) continue;
                CGPoint center = [candidate.view.superview convertPoint:candidate.view.center toView:root];
                CGFloat distance = hypot(center.x - drop.x, center.y - drop.y);
                if (distance < bestDistance) { bestDistance = distance; targetModule = candidate; }
            }
        }
        if (shouldCommitDrop && dragged.length && targetModule && bestDistance < 180.0 && current.count > 1 && [current containsObject:dragged]) {
            NSString *target = CCiOS18IdentifierFromObject(targetModule, 0);
            NSMutableArray *updated = [current mutableCopy];
            [updated removeObject:dragged];
            NSUInteger targetIndex = [updated indexOfObject:target];
            if (targetIndex == NSNotFound) {
                targetIndex = updated.count;
            } else {
                CGRect targetFrame = [targetModule.view convertRect:targetModule.view.bounds toView:root];
                BOOL sameRow = fabs(drop.y - CGRectGetMidY(targetFrame)) <= CGRectGetHeight(targetFrame) * 0.45;
                BOOL insertAfter = sameRow ? drop.x > CGRectGetMidX(targetFrame) : drop.y > CGRectGetMidY(targetFrame);
                if (insertAfter) targetIndex++;
            }
            [updated insertObject:dragged atIndex:MIN(targetIndex, updated.count)];
            CCiOS18SaveModuleOrder(updated);
        }
        source.alpha = 1.0;
        [snapshot removeFromSuperview];
        objc_setAssociatedObject(overlay, &kCCiOS18InlineDragOffsetKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(overlay, &kCCiOS18InlineDragIdentifierKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(overlay, &kCCiOS18InlineDragSnapshotKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(overlay, &kCCiOS18InlineDragSourceKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self ccios18_refreshInlineEditor];
    }
}

%new
- (void)ccios18_resizeHandlePanned:(UIPanGestureRecognizer *)gesture {
    UIView *handle = gesture.view;
    if (!handle) return;
    NSString *identifier = handle.accessibilityIdentifier;
    UIViewController *module = nil;
    for (UIViewController *candidate in CCiOS18InlineModules((UIViewController *)self)) {
        if ([CCiOS18IdentifierFromObject(candidate, 0) isEqualToString:identifier]) { module = candidate; break; }
    }
    if (!module || !identifier.length) return;
    UIView *moduleView = module.view;
    if (gesture.state == UIGestureRecognizerStateBegan) {
        CGFloat base = CCiOS18SavedScaleForIdentifier(identifier);
        objc_setAssociatedObject(handle, &kCCiOS18InlineResizeBaseScaleKey, @(base), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        CCiOS18GridSize baseSize = {1,1};
        NSValue *baseValue = gCCiOS18BaseGridSizes[identifier]; if (baseValue) [baseValue getValue:&baseSize];
        NSArray *saved = gCCiOS18CustomGridSizes[identifier];
        CCiOS18GridSize start = saved.count >= 2 ? (CCiOS18GridSize){[saved[0] unsignedIntegerValue],[saved[1] unsignedIntegerValue]} : baseSize;
        CGPoint translation = [gesture translationInView:self.view];
        CGFloat step = kCCiOS18GridCell + kCCiOS18GridGap;
        CGFloat dx = translation.x / step, dy = translation.y / step;
        CCiOS18GridSize candidate = start;
        if (baseSize.width == 1 && baseSize.height == 1) {
            if (start.width == 1 && start.height == 1) {
                if (dy >= 0.65) candidate = (CCiOS18GridSize){2,2};
                else if (dx >= 0.65) candidate = (CCiOS18GridSize){2,1};
            } else if (start.width == 2 && start.height == 1) {
                if (dy >= 0.65) candidate = (CCiOS18GridSize){2,2};
                else if (dx <= -0.65) candidate = (CCiOS18GridSize){1,1};
            } else if (start.width == 2 && start.height == 2) {
                if (dy <= -0.65) candidate = (CCiOS18GridSize){2,1};
                if (dx <= -0.65 && dy <= -0.65) candidate = (CCiOS18GridSize){1,1};
            }
        } else if (baseSize.width == 2 && baseSize.height == 2) {
            if (dx >= 1.0) candidate = (CCiOS18GridSize){4,2};
        }
        CGFloat width = candidate.width * kCCiOS18GridCell + (candidate.width-1) * kCCiOS18GridGap;
        CGFloat height = candidate.height * kCCiOS18GridCell + (candidate.height-1) * kCCiOS18GridGap;
        CGRect frame = [moduleView convertRect:moduleView.bounds toView:self.view];
        frame.size = CGSizeMake(width,height);
        moduleView.frame = [self.view convertRect:frame toView:moduleView.superview];
        [self ccios18_refreshInlineEditor];
    } else if (gesture.state == UIGestureRecognizerStateEnded) {
        CCiOS18GridSize baseSize = {1,1};
        NSValue *baseValue = gCCiOS18BaseGridSizes[identifier]; if (baseValue) [baseValue getValue:&baseSize];
        NSArray *saved = gCCiOS18CustomGridSizes[identifier];
        CCiOS18GridSize start = saved.count >= 2 ? (CCiOS18GridSize){[saved[0] unsignedIntegerValue],[saved[1] unsignedIntegerValue]} : baseSize;
        CGPoint translation = [gesture translationInView:self.view];
        CGFloat step = kCCiOS18GridCell + kCCiOS18GridGap;
        CCiOS18GridSize candidate = start;
        CGFloat dx = translation.x / step, dy = translation.y / step;
        if (baseSize.width == 1 && baseSize.height == 1) {
            if (start.width == 1 && start.height == 1) {
                if (dy >= 0.65) candidate = (CCiOS18GridSize){2,2};
                else if (dx >= 0.65) candidate = (CCiOS18GridSize){2,1};
            } else if (start.width == 2 && start.height == 1) {
                if (dy >= 0.65) candidate = (CCiOS18GridSize){2,2};
                else if (dx <= -0.65) candidate = (CCiOS18GridSize){1,1};
            } else if (start.width == 2 && start.height == 2) {
                if (dy <= -0.65) candidate = (CCiOS18GridSize){2,1};
                if (dx <= -0.65 && dy <= -0.65) candidate = (CCiOS18GridSize){1,1};
            }
        } else if (baseSize.width == 2 && baseSize.height == 2) {
            if (dx >= 1.0) candidate = (CCiOS18GridSize){4,2};
        }
        if (candidate.width != start.width || candidate.height != start.height) {
            CCiOS18ApplyGridResize(identifier, candidate, (UIViewController *)self);
        }
        moduleView.transform = CGAffineTransformIdentity;
        objc_setAssociatedObject(handle, &kCCiOS18InlineResizeBaseScaleKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self ccios18_refreshInlineEditor];
    } else if (gesture.state == UIGestureRecognizerStateCancelled || gesture.state == UIGestureRecognizerStateFailed) {
        moduleView.transform = CGAffineTransformIdentity;
        [self ccios18_refreshInlineEditor];
    }
}

%new
- (void)ccios18_inlineModulePinched:(UIPinchGestureRecognizer *)gesture {
    UIView *moduleView = gesture.view;
    if (!moduleView) return;
    NSString *identifier = nil;
    for (UIViewController *candidate in CCiOS18InlineModules((UIViewController *)self)) {
        if (candidate.view == moduleView) { identifier = CCiOS18IdentifierFromObject(candidate, 0); break; }
    }
    if (!identifier.length) return;
    if (gesture.state == UIGestureRecognizerStateBegan) {
        objc_setAssociatedObject(moduleView, &kCCiOS18InlinePinchBaseScaleKey, @(CCiOS18SavedScaleForIdentifier(identifier)), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        CGFloat base = [objc_getAssociatedObject(moduleView, &kCCiOS18InlinePinchBaseScaleKey) doubleValue];
        if (base <= 0.0) base = 1.0;
        CGFloat scale = MAX(0.70, MIN(1.40, base * gesture.scale));
        moduleView.transform = CGAffineTransformMakeScale(scale, scale);
    } else if (gesture.state == UIGestureRecognizerStateEnded) {
        CGFloat scale = MAX(0.70, MIN(1.40, moduleView.transform.a));
        NSString *key = [@"CCiOS18ModuleScale." stringByAppendingString:identifier];
        [[NSUserDefaults standardUserDefaults] setFloat:scale forKey:key];
        [[NSUserDefaults standardUserDefaults] synchronize];
        objc_setAssociatedObject(moduleView, &kCCiOS18InlinePinchBaseScaleKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self ccios18_refreshInlineEditor];
    } else if (gesture.state == UIGestureRecognizerStateCancelled || gesture.state == UIGestureRecognizerStateFailed) {
        CGFloat base = [objc_getAssociatedObject(moduleView, &kCCiOS18InlinePinchBaseScaleKey) doubleValue];
        if (base <= 0.0) base = 1.0;
        moduleView.transform = CGAffineTransformMakeScale(base, base);
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
