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


// MARK: - Native Control Center module order editor (iOS 15)
//
// This editor changes the order saved by Apple's ControlCenterServices
// provider. It does not move or replace native module views, so each module
// keeps its original controls and behavior.

#import <objc/message.h>

static const NSInteger kCCiOS18EditorButtonTag = 180019;

static NSString *CCiOS18ReadableModuleName(NSString *identifier) {
    NSDictionary *known = @{
        @"com.apple.control-center.ConnectivityModule": @"Connectivity",
        @"com.apple.control-center.DisplayModule": @"Display",
        @"com.apple.control-center.DoNotDisturbModule": @"Focus",
        @"com.apple.control-center.MusicRecognitionModule": @"Music Recognition",
        @"com.apple.control-center.ScreenMirroringModule": @"Screen Mirroring",
        @"com.apple.control-center.AirPlayMirroringModule": @"Screen Mirroring",
        @"com.apple.control-center.HearingAidsModule": @"Hearing",
        @"com.apple.control-center.HomeControlCenterModule": @"Home",
        @"com.apple.control-center.LowPowerModule": @"Low Power Mode",
        @"com.apple.control-center.AccessibilityModule": @"Accessibility",
        @"com.apple.control-center.TextSizeModule": @"Text Size",
        @"com.apple.control-center.DarkModeModule": @"Dark Mode",
        @"com.apple.control-center.BrightnessModule": @"Brightness",
        @"com.apple.control-center.VolumeModule": @"Volume",
        @"com.apple.control-center.TimerModule": @"Timer",
        @"com.apple.control-center.CalculatorModule": @"Calculator",
        @"com.apple.control-center.CameraModule": @"Camera",
        @"com.apple.control-center.FlashlightModule": @"Flashlight",
        @"com.apple.control-center.CodeScannerModule": @"Code Scanner",
        @"com.apple.control-center.ScreenRecordingModule": @"Screen Recording"
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

@interface CCiOS18ModuleOrderEditor : UITableViewController
@property(nonatomic, strong) NSMutableArray<NSString *> *moduleIdentifiers;
- (instancetype)initWithModuleIdentifiers:(NSArray<NSString *> *)identifiers;
@end

@implementation CCiOS18ModuleOrderEditor

- (instancetype)initWithModuleIdentifiers:(NSArray<NSString *> *)identifiers {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        _moduleIdentifiers = identifiers ? [identifiers mutableCopy] : [NSMutableArray new];
        self.title = @"Arrange Controls";
        self.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.tableView.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.tableView.rowHeight = 58.0;
    self.tableView.editing = YES;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(ccios18_cancel)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(ccios18_save)];
    self.navigationItem.prompt = @"Drag the handles to change the order";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.moduleIdentifiers.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *reuse = @"CCiOS18ModuleOrderCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuse];
    NSString *identifier = self.moduleIdentifiers[indexPath.row];
    cell.textLabel.text = CCiOS18ReadableModuleName(identifier);
    cell.textLabel.textColor = [UIColor labelColor];
    cell.detailTextLabel.text = identifier;
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.showsReorderControl = YES;
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath {
    NSString *identifier = self.moduleIdentifiers[sourceIndexPath.row];
    [self.moduleIdentifiers removeObjectAtIndex:sourceIndexPath.row];
    [self.moduleIdentifiers insertObject:identifier atIndex:destinationIndexPath.row];
}

- (void)ccios18_cancel {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)ccios18_save {
    @try {
        Class providerClass = NSClassFromString(@"CCSModuleSettingsProvider");
        SEL sharedSelector = NSSelectorFromString(@"sharedProvider");
        id provider = nil;
        if (providerClass && [providerClass respondsToSelector:sharedSelector]) {
            provider = ((id (*)(id, SEL))objc_msgSend)(providerClass, sharedSelector);
        }
        SEL saveSelector = NSSelectorFromString(@"setAndSaveOrderedUserEnabledModuleIdentifiers:");
        if (!provider || ![provider respondsToSelector:saveSelector]) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Unable to Save" message:@"The iOS Control Center settings service is unavailable on this system." preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
            return;
        }
        ((void (*)(id, SEL, id))objc_msgSend)(provider, saveSelector, [self.moduleIdentifiers copy]);
        [self dismissViewControllerAnimated:YES completion:nil];
    } @catch (NSException *exception) {
        NSLog(@"[CCiOS18] Module order save exception: %@", exception);
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Save Failed" message:@"iOS could not save the new Control Center order. Your current layout was left unchanged." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

@end

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


%hook CCUIModularControlCenterOverlayViewController

- (void)viewDidLayoutSubviews {
    %orig;
    @try {
        UIView *root = [(UIViewController *)self view];
        CCiOS18InstallBackdrop(root);

        UIButton *editButton = (UIButton *)[root viewWithTag:kCCiOS18EditorButtonTag];
        if (!editButton) {
            editButton = [UIButton buttonWithType:UIButtonTypeSystem];
            editButton.tag = kCCiOS18EditorButtonTag;
            [editButton setTitle:@"Edit" forState:UIControlStateNormal];
            [editButton setImage:[UIImage systemImageNamed:@"slider.horizontal.3"] forState:UIControlStateNormal];
            editButton.tintColor = [UIColor whiteColor];
            editButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
            editButton.backgroundColor = [UIColor colorWithWhite:0.18 alpha:0.78];
            editButton.layer.cornerRadius = 15.0;
            editButton.layer.borderWidth = 0.7;
            editButton.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.24].CGColor;
            editButton.clipsToBounds = YES;
            editButton.translatesAutoresizingMaskIntoConstraints = NO;
            [editButton addTarget:self action:@selector(ccios18_openModuleOrderEditor) forControlEvents:UIControlEventTouchUpInside];
            [root addSubview:editButton];
            [NSLayoutConstraint activateConstraints:@[
                [editButton.trailingAnchor constraintEqualToAnchor:root.safeAreaLayoutGuide.trailingAnchor constant:-18.0],
                [editButton.topAnchor constraintEqualToAnchor:root.safeAreaLayoutGuide.topAnchor constant:10.0],
                [editButton.widthAnchor constraintEqualToConstant:76.0],
                [editButton.heightAnchor constraintEqualToConstant:34.0]
            ]];
        }
    } @catch (NSException *exception) {
        NSLog(@"[CCiOS18] Backdrop/editor button exception: %@", exception);
    }
}

%new
- (void)ccios18_openModuleOrderEditor {
    @try {
        NSArray *order = CCiOS18CurrentEnabledModuleOrder();
        if (!order || order.count == 0) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Controls Unavailable" message:@"Could not read the current Control Center module order from iOS." preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [(UIViewController *)self presentViewController:alert animated:YES completion:nil];
            return;
        }
        CCiOS18ModuleOrderEditor *editor = [[CCiOS18ModuleOrderEditor alloc] initWithModuleIdentifiers:order];
        UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:editor];
        navigation.modalPresentationStyle = UIModalPresentationFormSheet;
        [(UIViewController *)self presentViewController:navigation animated:YES completion:nil];
    } @catch (NSException *exception) {
        NSLog(@"[CCiOS18] Could not present module order editor: %@", exception);
    }
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
